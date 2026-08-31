/// Dio adapter for `fabitus_crud_api`.
///
/// `fabitus_crud_api` has no transport dependency and no opinion about a
/// backend's error format, which leaves one thing for every Dio based app to
/// write: the [CrudErrorMapper]. This package is that thing, so you do not have
/// to.
///
/// ```dart
/// final repository = RemotePagingCrudRepository<Todo, String>(
///   TodoApi(dio),
///   errorMapper: const DioCrudErrorMapper(),
/// );
/// ```
library;

export 'src/dio_crud_error_mapper.dart';
export 'src/problem_detail_violations.dart';
