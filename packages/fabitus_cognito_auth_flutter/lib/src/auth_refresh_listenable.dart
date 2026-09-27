import 'dart:async';

import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';
import 'package:flutter/foundation.dart';

/// Tells a router to re-run its redirect when somebody signs in or out.
///
/// go_router's `refreshListenable` wants a [Listenable]; the cubit offers a
/// stream. This bridges the two - and notifies only when the answer of a route
/// guard can change, that is when [AuthState.isAuthenticated] or
/// [AuthState.isRestored] flips. A token refresh replaces the session every
/// hour and is not worth re-running every redirect for.
///
/// ```dart
/// GoRouter(
///   refreshListenable: AuthRefreshListenable(auth),
///   redirect: (context, state) => guard(auth.state, state.uri),
///   ...
/// );
/// ```
///
/// Dispose it with the router.
class AuthRefreshListenable extends ChangeNotifier {
  /// Listens to [auth].
  AuthRefreshListenable(AuthCubit auth) : _last = _phaseOf(auth.state) {
    _subscription = auth.stream.listen((state) {
      final phase = _phaseOf(state);
      if (phase == _last) return;
      _last = phase;
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;
  (bool, bool) _last;

  static (bool, bool) _phaseOf(AuthState state) => (state.isRestored, state.isAuthenticated);

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
