import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// One row of the password checklist: a rule, and whether the password meets
/// it.
typedef PasswordRequirementCheck = ({PasswordRequirement requirement, bool isMet});

/// Everything a new password form needs to render, handed to
/// [NewPasswordForm.builder].
class NewPasswordFormData {
  /// Creates the data. Built by [NewPasswordForm]; construct one yourself only
  /// in a test or a widget preview.
  const NewPasswordFormData({
    required this.newPassword,
    required this.confirmation,
    required this.checklist,
    required this.confirmationMatches,
    required this.isSubmitting,
    required this.submit,
    required this.cancel,
    this.policy,
    this.requiredAttributes = const [],
    this.error,
  });

  /// The new password field's controller. Owned by the form; do not dispose
  /// it.
  final TextEditingController newPassword;

  /// The confirmation field's controller. Owned by the form; do not dispose it.
  final TextEditingController confirmation;

  /// The policy the checklist follows, `null` when there is none.
  final PasswordPolicy? policy;

  /// One entry per rule of the [policy], in order, updated as the user types.
  /// Empty without a policy.
  final List<PasswordRequirementCheck> checklist;

  /// Whether the confirmation is identical to the new password and not empty.
  final bool confirmationMatches;

  /// Whether the new password is on its way to Cognito.
  final bool isSubmitting;

  /// Sends the new password. `null` until it meets every rule and the
  /// confirmation matches, and while [isSubmitting].
  final VoidCallback? submit;

  /// Gives up on the challenge and returns to the sign in form. `null` while
  /// [isSubmitting].
  final VoidCallback? cancel;

  /// User attributes the pool requires along with the password. Usually empty;
  /// see [NewPasswordForm.attributes].
  final List<String> requiredAttributes;

  /// Why the last new password was rejected, `null` on the first attempt. Map
  /// `error.failure` to a message in your own words.
  final AuthException? error;

  /// Whether the new password meets every rule of the [policy].
  bool get meetsPolicy => checklist.every((check) => check.isMet);
}

/// A new password form that paints nothing: it owns the password and
/// confirmation controllers, the live checklist and the wiring to the
/// [AuthCubit], and [builder] draws it.
///
/// ```dart
/// NewPasswordForm(
///   builder: (context, form) => Column(
///     children: [
///       MyTextField(label: 'Neues Passwort', controller: form.newPassword, obscureText: true),
///       for (final check in form.checklist) MyCheckRow(label: label(check.requirement), checked: check.isMet),
///       MyTextField(label: 'Passwort bestätigen', controller: form.confirmation, obscureText: true),
///       MyCheckRow(label: 'Passwörter stimmen überein', checked: form.confirmationMatches),
///       if (form.error case final error?) MyError(describe(error.failure)),
///       MyButton(label: 'Passwort speichern', busy: form.isSubmitting, onPressed: form.submit),
///       MyQuietButton(label: 'Zurück zur Anmeldung', onPressed: form.cancel),
///     ],
///   ),
/// );
/// ```
///
/// The checklist follows [policy], or the cubit's `passwordPolicy` when that is
/// omitted. The cubit comes from the enclosing [BlocProvider] unless one is
/// passed.
class NewPasswordForm extends StatefulWidget {
  /// Creates a new password form.
  const NewPasswordForm({required this.builder, this.cubit, this.policy, this.attributes, super.key});

  /// Draws the form.
  final Widget Function(BuildContext context, NewPasswordFormData form) builder;

  /// The cubit to answer the challenge through. Read from the enclosing
  /// provider when omitted.
  final AuthCubit? cubit;

  /// The policy for the checklist. Defaults to the cubit's `passwordPolicy`.
  final PasswordPolicy? policy;

  /// Supplies the attributes the pool requires along with the password, read
  /// when the user submits. Only needed when
  /// [NewPasswordFormData.requiredAttributes] is not empty.
  final Map<String, String> Function()? attributes;

  @override
  State<NewPasswordForm> createState() => _NewPasswordFormState();
}

class _NewPasswordFormState extends State<NewPasswordForm> {
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The checklist and the confirmation check follow the fields.
    _newPassword.addListener(_changed);
    _confirmation.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      bloc: widget.cubit,
      builder: (context, state) {
        final cubit = widget.cubit ?? context.read<AuthCubit>();
        final policy = widget.policy ?? cubit.passwordPolicy;
        final password = _newPassword.text;
        final checklist = [
          for (final requirement in policy?.requirements ?? const <PasswordRequirement>[])
            (requirement: requirement, isMet: policy!.isMet(requirement, password)),
        ];
        final confirmationMatches = PasswordPolicy.confirmationMatches(password, _confirmation.text);
        final isSubmitting = state is AuthInProgress;
        final canSubmit = !isSubmitting && confirmationMatches && checklist.every((check) => check.isMet);

        return widget.builder(
          context,
          NewPasswordFormData(
            newPassword: _newPassword,
            confirmation: _confirmation,
            policy: policy,
            checklist: checklist,
            confirmationMatches: confirmationMatches,
            isSubmitting: isSubmitting,
            submit: canSubmit
                ? () => cubit.submitNewPassword(password, attributes: widget.attributes?.call() ?? const {})
                : null,
            cancel: isSubmitting ? null : cubit.signOut,
            requiredAttributes: state is AuthNewPasswordRequired ? state.requiredAttributes : const [],
            error: state is AuthNewPasswordRequired ? state.error : null,
          ),
        );
      },
    );
  }
}
