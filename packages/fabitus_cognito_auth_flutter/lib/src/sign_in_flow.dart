import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Switches between the sign in form, the new password form and the e-mail code
/// form.
///
/// The one decision every login page makes: show [newPassword] while Cognito
/// waits for a new password - including while it is on its way - [emailCode]
/// while it waits for a code from an e-mail, and [signIn] otherwise. Without an
/// [emailCode] builder the sign in form stays up for a code as well.
///
/// ```dart
/// SignInFlow(
///   signIn: (context) => SignInForm(builder: (context, form) => MySignInFields(form)),
///   newPassword: (context) => NewPasswordForm(builder: (context, form) => MyNewPasswordFields(form)),
/// );
/// ```
///
/// Rebuilds only when it switches, so each form keeps its state while it is
/// shown. The cubit comes from the enclosing [BlocProvider] unless one is
/// passed.
class SignInFlow extends StatelessWidget {
  /// Creates the flow.
  const SignInFlow({required this.signIn, required this.newPassword, this.emailCode, this.cubit, super.key});

  /// Shown unless Cognito waits for a new password.
  final WidgetBuilder signIn;

  /// Shown while Cognito waits for a new password.
  final WidgetBuilder newPassword;

  /// Shown while Cognito waits for the code it e-mailed, including while the
  /// answer or a resend is on its way. The sign in form is shown when omitted.
  final WidgetBuilder? emailCode;

  /// The cubit to follow. Read from the enclosing provider when omitted.
  final AuthCubit? cubit;

  /// Whether [state] belongs to the new password step.
  static bool isNewPasswordStep(AuthState state) => switch (state) {
    AuthNewPasswordRequired() || AuthInProgress(step: AuthStep.newPassword) => true,
    _ => false,
  };

  /// Whether [state] belongs to the e-mail code step.
  static bool isEmailCodeStep(AuthState state) => switch (state) {
    AuthEmailCodeRequired() ||
    AuthInProgress(step: AuthStep.submitEmailCode) ||
    AuthInProgress(step: AuthStep.resendEmailCode) => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      bloc: cubit,
      buildWhen: (previous, current) =>
          isNewPasswordStep(previous) != isNewPasswordStep(current) ||
          isEmailCodeStep(previous) != isEmailCodeStep(current),
      builder: (context, state) {
        if (isNewPasswordStep(state)) return newPassword(context);
        if (isEmailCodeStep(state)) return (emailCode ?? signIn)(context);
        return signIn(context);
      },
    );
  }
}
