// A runnable tour of fabitus_problem_details: parse an RFC 9457 error body and
// pull a message and field errors out of it.
//
//   dart run example/main.dart
import 'dart:convert';

import 'package:fabitus_problem_details/fabitus_problem_details.dart';

/// What a Spring Boot backend returns for a rejected `POST /todos`.
const String responseBody = '''
{
  "type": "https://fabit.us/problem/constraint-violation",
  "title": "Constraint Violation",
  "status": 422,
  "detail": "The todo could not be saved",
  "instance": "/todos",
  "traceId": "8f1c2d3e",
  "violations": [
    {"field": "title", "message": "must not be blank"},
    {"field": "dueAt", "message": "must be in the future"}
  ]
}
''';

void main() {
  final problem = ProblemDetail.fromJson(jsonDecode(responseBody) as Map<String, dynamic>);

  // The one line to show the user when nothing more specific fits.
  print('message: ${problem.message}');

  // Field errors, ready to hang on form fields.
  print('title:   ${problem.violationFor('title')?.message}');
  print('dueAt:   ${problem.violationFor('dueAt')?.message}');
  print('all:     ${problem.violations.join(', ')}');

  // Members the standard does not define survive, so a trace id is not lost.
  print('traceId: ${problem.extensions['traceId']}');

  // A body that is not a problem detail is not forced into one.
  print('plain:   ${ProblemDetail.tryParse('502 Bad Gateway')}');
}
