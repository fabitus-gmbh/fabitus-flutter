/// Flutter building blocks for `fabitus_cognito_auth`, with the design left to
/// you.
///
/// * [AuthRedirect] is the route guard - a plain function, for any router - and
///   [AuthRefreshListenable] tells the router when to ask it again.
/// * [AuthGate] shows one subtree while restoring, one signed out, one signed
///   in.
/// * [SignInFlow] switches between the two forms of a login page.
/// * [SignInForm] and [NewPasswordForm] own the text controllers, the password
///   checklist and the wiring to the `AuthCubit`, and hand your builder what
///   it needs to draw.
///
/// **Nothing here paints.** No text field, no button, no message: every word
/// and pixel comes from your builder. It builds on
/// `package:flutter/widgets.dart`, not `material.dart`, and depends on no
/// router.
library;

export 'src/auth_gate.dart';
export 'src/auth_redirect.dart';
export 'src/auth_refresh_listenable.dart';
export 'src/new_password_form.dart';
export 'src/sign_in_flow.dart';
export 'src/sign_in_form.dart';
