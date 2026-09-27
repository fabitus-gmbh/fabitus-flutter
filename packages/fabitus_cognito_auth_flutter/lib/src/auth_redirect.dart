import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';

/// The route guard: where to send the user, given who is signed in.
///
/// A plain function of the [AuthState] and the location, so it works with
/// whatever router you use and needs no dependency on one. With go_router:
///
/// ```dart
/// const guard = AuthRedirect(loginPath: '/login', homePath: '/files', publicPaths: {'/'});
///
/// GoRouter(
///   refreshListenable: AuthRefreshListenable(auth),
///   redirect: (context, state) => guard(auth.state, state.uri),
///   ...
/// );
/// ```
///
/// - Signed out, at a path that is neither the login nor public: to the login,
///   with the original location in the `from` query parameter.
/// - Signed in, at the login: back to `from`, or to [homePath].
/// - While the stored session is being restored: to [restoringPath] if you
///   have a splash screen, otherwise nowhere - the redirect runs again once
///   the restore settles, when the listenable fires.
///
/// Returns `null` for "stay".
class AuthRedirect {
  /// Creates a guard.
  const AuthRedirect({
    required this.loginPath,
    this.homePath = '/',
    this.publicPaths = const {},
    this.restoringPath,
    this.fromParameter = 'from',
  });

  /// Where signed out users go.
  final String loginPath;

  /// Where a user goes after signing in, when there is no `from` to return to.
  final String homePath;

  /// Paths anybody may see, signed in or not - a landing page, an imprint.
  /// Matched exactly.
  final Set<String> publicPaths;

  /// Where to wait while the stored session is being restored, such as a
  /// splash screen. `null` stays put.
  final String? restoringPath;

  /// The query parameter the original location travels in.
  final String fromParameter;

  /// Where to go from [location] in [state], or `null` to stay.
  String? call(AuthState state, Uri location) {
    final path = location.path;
    final atLogin = path == loginPath;
    final atSplash = path == restoringPath;

    if (!state.isRestored) {
      if (restoringPath == null || atSplash) return null;
      return _withFrom(restoringPath!, location);
    }

    if (state.isAuthenticated) {
      if (!atLogin && !atSplash) return null;
      return _returnTarget(location) ?? homePath;
    }

    if (atLogin || publicPaths.contains(path)) return null;
    return _withFrom(loginPath, atSplash ? _from(location) : location);
  }

  /// [target], remembering [location] - unless there is nothing worth
  /// remembering.
  String _withFrom(String target, Uri? location) {
    final from = location?.toString();
    if (from == null || from.isEmpty || from == '/' || location!.path == homePath) return target;
    return Uri(path: target, queryParameters: {fromParameter: from}).toString();
  }

  Uri? _from(Uri location) {
    final from = location.queryParameters[fromParameter];
    return from == null ? null : Uri.tryParse(from);
  }

  /// The `from` of [location], if it is a path inside the app. Anything else -
  /// `//evil.example`, `https://evil.example` - is ignored, so a crafted login
  /// link cannot send a freshly signed in user off site.
  String? _returnTarget(Uri location) {
    final from = location.queryParameters[fromParameter];
    if (from == null || !from.startsWith('/') || from.startsWith('//')) return null;
    final uri = Uri.tryParse(from);
    if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
    if (uri.path == loginPath || uri.path == restoringPath) return null;
    return from;
  }
}
