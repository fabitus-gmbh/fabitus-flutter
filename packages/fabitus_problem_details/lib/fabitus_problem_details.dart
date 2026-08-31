/// RFC 9457 problem details for HTTP APIs.
///
/// One value type, [ProblemDetail], for the machine readable error body a REST
/// backend returns, plus the [ConstraintViolation]s that come with a validation
/// failure. Parsing is deliberately tolerant of the shapes Spring Boot and
/// Zalando's `problem` library emit.
///
/// The package knows nothing about HTTP clients: hand it a decoded body and it
/// gives you a value. See the README for how to wire it into a Dio interceptor
/// or into `fabitus_crud_api`'s error mapper.
library;

export 'src/problem_detail.dart';
