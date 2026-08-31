/// Spring Data style CRUD abstractions for Dart and Flutter.
///
/// The package is deliberately transport agnostic and free of code generation:
/// it defines the contracts ([CrudEntity], [CrudRepository],
/// [PagingCrudRepository], [CrudApi]), the value types they exchange
/// ([CrudResult], [CrudException], [Page], [PageRequest], [Sort]) and three
/// implementations - in memory, key-value backed and remote.
///
/// See the package README for wiring recipes.
library;

export 'src/core/crud_entity.dart';
export 'src/core/id_generator.dart' show IdGenerator, newUuid;
export 'src/core/logging.dart';
export 'src/error/crud_error_mapper.dart';
export 'src/error/crud_exception.dart';
export 'src/error/crud_result.dart';
export 'src/error/crud_violation.dart';
export 'src/paging/page.dart';
export 'src/paging/page_request.dart';
export 'src/paging/sort.dart';
export 'src/repository/collection_query.dart' show PropertyAccessor, jsonPropertyAccessor, pageOf, sortEntities;
export 'src/repository/crud_api.dart';
export 'src/repository/crud_repository.dart';
export 'src/repository/in_memory_crud_repository.dart';
export 'src/repository/key_value_crud_repository.dart';
export 'src/repository/key_value_store.dart';
export 'src/repository/remote_crud_repository.dart';
export 'src/service/crud_event.dart';
export 'src/service/crud_event_listener.dart';
export 'src/service/crud_service.dart';
