import '../paging/page.dart';
import '../paging/page_request.dart';

/// The transport level contract a backend client fulfils.
///
/// Unlike a repository, a [CrudApi] throws instead of returning a
/// [CrudResult] - it is the raw client. Wrap it in a `RemoteCrudRepository` to
/// get the result based contract.
///
/// It is a plain `abstract class` on purpose, so a retrofit client can extend
/// it and inherit the signatures:
///
/// ```dart
/// @RestApi()
/// abstract class TodoApi extends PagingCrudApi<Todo, String> {
///   factory TodoApi(Dio dio, {String baseUrl}) = _TodoApi;
///
///   @GET('/todos')
///   @override
///   // Nullable so retrofit strips null query parameters.
///   Future<Page<Todo>> findPage(@Queries() PageRequest? pageRequest);
///
///   @GET('/todos/{id}')
///   @override
///   Future<Todo> findById(@Path('id') String id);
///
///   @POST('/todos')
///   @override
///   Future<Todo> create(@Body() Todo entity);
///
///   @PUT('/todos/{id}')
///   @override
///   Future<Todo> update(@Path('id') String id, @Body() Todo entity);
///
///   @DELETE('/todos/{id}')
///   @override
///   Future<void> deleteById(@Path('id') String id);
/// }
/// ```
abstract class CrudApi<T, ID> {
  /// `GET /resource/{id}`
  Future<T> findById(ID id);

  /// `POST /resource`
  Future<T> create(T entity);

  /// `PUT /resource/{id}`
  Future<T> update(ID id, T entity);

  /// `DELETE /resource/{id}`
  Future<void> deleteById(ID id);
}

/// A [CrudApi] whose backend also exposes a paged collection endpoint.
abstract class PagingCrudApi<T, ID> extends CrudApi<T, ID> {
  /// `GET /resource?page=..&size=..&sort=..`
  Future<Page<T>> findPage(PageRequest pageRequest);
}
