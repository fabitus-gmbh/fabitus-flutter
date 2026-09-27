import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Everything a sign in form needs to render, handed to [SignInForm.builder].
class SignInFormData {
  /// Creates the data. Built by [SignInForm]; construct one yourself only in
  /// a test or a widget preview.
  const SignInFormData({
    required this.username,
    required this.password,
    required this.isSubmitting,
    required this.submit,
    this.error,
  });

  /// The username field's controller. Owned by the form; do not dispose it.
  final TextEditingController username;

  /// The password field's controller. Owned by the form; do not dispose it.
  final TextEditingController password;

  /// Whether a sign in is on its way to Cognito - the moment for a spinner.
  final bool isSubmitting;

  /// Signs in with what the fields hold. `null` while [isSubmitting], which is
  /// what a disabled button wants. Wire it to the button and to the fields'
  /// `onSubmitted`.
  final VoidCallback? submit;

  /// Why the last attempt failed - or why the user is here at all, with
  /// [AuthFailure.sessionExpired]. `null` when there is nothing to say. Map
  /// `error.failure` to a message in your own words.
  final AuthException? error;

  /// Whether both fields hold something - for a button that stays disabled
  /// until they do. [submit] does not require it: an empty submit fails with
  /// [AuthFailure.missingCredentials], for a design that explains rather than
  /// disables.
  bool get hasInput => username.text.trim().isNotEmpty && password.text.isNotEmpty;
}

/// A sign in form that paints nothing: it owns the two text controllers and
/// the wiring to the [AuthCubit], and [builder] draws the fields.
///
/// ```dart
/// SignInForm(
///   builder: (context, form) => Column(
///     children: [
///       MyTextField(label: 'E-Mail', controller: form.username, autofillHints: const [AutofillHints.username]),
///       MyTextField(
///         label: 'Passwort',
///         controller: form.password,
///         obscureText: true,
///         autofillHints: const [AutofillHints.password],
///         onSubmitted: (_) => form.submit?.call(),
///       ),
///       if (form.error case final error?) MyError(describe(error.failure)),
///       MyButton(label: 'Anmelden', busy: form.isSubmitting, onPressed: form.submit),
///     ],
///   ),
/// );
/// ```
///
/// Wrap the fields in an `AutofillGroup` so password managers fill both.
///
/// The cubit comes from the enclosing [BlocProvider] unless one is passed.
class SignInForm extends StatefulWidget {
  /// Creates a sign in form.
  const SignInForm({required this.builder, this.cubit, this.initialUsername, super.key});

  /// Draws the form.
  final Widget Function(BuildContext context, SignInFormData form) builder;

  /// The cubit to sign in with. Read from the enclosing provider when omitted.
  final AuthCubit? cubit;

  /// What the username field starts with, such as the last user's email.
  final String? initialUsername;

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  late final TextEditingController _username = TextEditingController(text: widget.initialUsername);
  final TextEditingController _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    // hasInput follows the fields.
    _username.addListener(_changed);
    _password.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      bloc: widget.cubit,
      builder: (context, state) {
        final isSubmitting = state is AuthInProgress;
        final cubit = widget.cubit ?? context.read<AuthCubit>();
        return widget.builder(
          context,
          SignInFormData(
            username: _username,
            password: _password,
            isSubmitting: isSubmitting,
            submit: isSubmitting ? null : () => cubit.signIn(_username.text, _password.text),
            error: state is AuthUnauthenticated ? state.error : null,
          ),
        );
      },
    );
  }
}
