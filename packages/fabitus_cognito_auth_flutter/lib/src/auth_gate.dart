import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shows one of three subtrees: while the session is restored, when nobody is
/// signed in, and when somebody is.
///
/// For an app without a router guard, or a part of one that should look
/// different when signed out:
///
/// ```dart
/// AuthGate(
///   restoring: (context) => const Splash(),
///   signedOut: (context) => const LoginPage(),
///   signedIn: (context, user) => HomePage(user: user),
/// );
/// ```
///
/// It rebuilds only when the answer changes. Signing in and the new password
/// challenge all happen within [signedOut], so a login page keeps its state -
/// and its text fields - through a failed attempt; a token refresh does not
/// rebuild [signedIn].
///
/// The cubit comes from the enclosing [BlocProvider] unless one is passed.
class AuthGate extends StatelessWidget {
  /// Creates a gate.
  const AuthGate({required this.signedOut, required this.signedIn, this.restoring, this.cubit, super.key});

  /// Shown when nobody is signed in, including while a sign in is in progress
  /// and during the new password challenge.
  final WidgetBuilder signedOut;

  /// Shown when somebody is signed in. [AuthUser] rather than the session,
  /// because the user stays the same across refreshes while the tokens do not;
  /// read the cubit for those.
  final Widget Function(BuildContext context, AuthUser user) signedIn;

  /// Shown while the stored session is restored. Nothing by default.
  final WidgetBuilder? restoring;

  /// The cubit to follow. Read from the enclosing provider when omitted.
  final AuthCubit? cubit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      bloc: cubit,
      buildWhen: (previous, current) =>
          previous.isRestored != current.isRestored ||
          previous.isAuthenticated != current.isAuthenticated ||
          previous.sessionOrNull?.user.subject != current.sessionOrNull?.user.subject,
      builder: (context, state) {
        if (!state.isRestored) return restoring?.call(context) ?? const SizedBox.shrink();
        return switch (state.sessionOrNull) {
          final session? => signedIn(context, session.user),
          null => signedOut(context),
        };
      },
    );
  }
}
