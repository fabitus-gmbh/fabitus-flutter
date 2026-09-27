import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Switches between the sign in form and the new password form.
///
/// The one decision every login page makes: show [newPassword] while Cognito
/// waits for a new password - including while it is on its way - and [signIn]
/// otherwise.
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
  const SignInFlow({required this.signIn, required this.newPassword, this.cubit, super.key});

  /// Shown unless Cognito waits for a new password.
  final WidgetBuilder signIn;

  /// Shown while Cognito waits for a new password.
  final WidgetBuilder newPassword;

  /// The cubit to follow. Read from the enclosing provider when omitted.
  final AuthCubit? cubit;

  /// Whether [state] belongs to the new password step.
  static bool isNewPasswordStep(AuthState state) => switch (state) {
    AuthNewPasswordRequired() || AuthInProgress(step: AuthStep.newPassword) => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      bloc: cubit,
      buildWhen: (previous, current) => isNewPasswordStep(previous) != isNewPasswordStep(current),
      builder: (context, state) => isNewPasswordStep(state) ? newPassword(context) : signIn(context),
    );
  }
}
