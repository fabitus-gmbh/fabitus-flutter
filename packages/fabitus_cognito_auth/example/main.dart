// Signs in to a real user pool, refreshes, and signs out.
//
//   dart run example/main.dart <user pool id> <app client id> <username> <password>
import 'dart:io';

import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';

Future<void> main(List<String> args) async {
  if (args.length != 4) {
    stderr.writeln('usage: dart run example/main.dart <user pool id> <app client id> <username> <password>');
    exitCode = 64;
    return;
  }

  final auth = AuthCubit(CognitoAuthClient(userPoolId: args[0], clientId: args[1]));
  await auth.restore();
  await auth.signIn(args[2], args[3]);

  if (auth.state case AuthNewPasswordRequired(:final requiredAttributes)) {
    stdout.write('A new password is required${requiredAttributes.isEmpty ? '' : ' (and $requiredAttributes)'}: ');
    await auth.submitNewPassword(stdin.readLineSync() ?? '');
  }

  switch (auth.state) {
    case AuthAuthenticated(:final session):
      print('Signed in as ${session.user.displayName}, groups ${session.user.groups}');
      print('Tokens expire at ${session.expiresAt.toLocal()}');
      final refreshed = await auth.refresh();
      print('Refreshed, now expiring at ${refreshed?.expiresAt.toLocal()}');
      await auth.signOut(revoke: true);
      print('Signed out: ${auth.state}');
    case final state:
      print('Not signed in: ${state.errorOrNull?.failure.name} (${state.errorOrNull?.message})');
      exitCode = 1;
  }
  await auth.close();
}
