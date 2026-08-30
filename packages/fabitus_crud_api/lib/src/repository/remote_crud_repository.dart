import '../core/crud_entity.dart';
import '../error/crud_exception.dart';
import '../error/crud_result.dart';
import '../paging/page.dart';
import '../paging/page_request.dart';
import 'crud_api.dart';
import 'crud_repository.dart';

/// A [CrudRepository] backed by a [CrudApi], typically a retrofit client.
///
/// It adds nothing but error handling: every call to the API is funnelled
/// through the repository's error mapper, so callers get a [CrudResult] instead
/// of an exception.
///
/// ```dart
/// final repository = RemoteCrudRepository<Todo, String>(
///   TodoApi(dio),
///   errorMapper: const DioCrudErrorMapper(),
/// );
/// ```
///
/// [findAll] and [count] fail with [CrudUnsupportedException], because a plain
/// [CrudApi] exposes no collection endpoint. Use [RemotePagingCrudRepository]
/// when the backend supports paging.
class RemoteCrudRepository<T extends CrudEntity<ID>, ID extends Object>
    extends BaseCrudRepository<T, ID> {
  /// Creates a repository delegating to [api].
  const RemoteCrudRepository(this.api, {super.errorMapper});

  /// The client this repository delegates to.
  final CrudApi<T, ID> api;

  @override
  Future<CrudResult<T>> findById(ID id) => guard(() => api.findById(id));

  @override
  Future<CrudResult<T>> create(T entity) => guard(() => api.create(entity));

  @override
  Future<CrudResult<T>> update(T entity) => guard(() async {
    final id = entity.id;
    if (id == null) {
      throw CrudValidationException('Cannot update a $T without an id');
    }
    return api.update(id, entity);
  });

  @override
  Future<CrudResult<void>> deleteById(ID id) => guard(() => api.deleteById(id));

  @override
  Future<CrudResult<List<T>>> findAll() async => CrudFailure<List<T>>(
    CrudUnsupportedException(
      '$runtimeType cannot list every $T because ${api.runtimeType} exposes no '
      'collection endpoint. Use a PagingCrudApi and RemotePagingCrudRepository.',
    ),
    StackTrace.current,
  );

  @override
  Future<CrudResult<int>> count() async => CrudFailure<int>(
    CrudUnsupportedException(
      '$runtimeType cannot count $T because ${api.runtimeType} exposes no '
      'collection endpoint. Use a PagingCrudApi and RemotePagingCrudRepository.',
    ),
    StackTrace.current,
  );
}

/// A [RemoteCrudRepository] for a backend that supports paging.
///
/// On top of [findPage] it can implement [findAll] and [count], by walking the
/// pages until the backend reports no further one. Both are convenience for
/// small collections - prefer [findPage] for anything a user scrolls through.
class RemotePagingCrudRepository<T extends CrudEntity<ID>, ID extends Object>
    extends RemoteCrudRepository<T, ID>
    implements PagingCrudRepository<T, ID> {
  /// Creates a repository delegating to [api].
  ///
  /// [pageSizeForFindAll] is the page size used when walking the collection in
  /// [findAll] and [count], and [maxPagesForFindAll] caps how many pages are
  /// read before giving up.
  const RemotePagingCrudRepository(
    PagingCrudApi<T, ID> super.api, {
    this.pageSizeForFindAll = 100,
    this.maxPagesForFindAll = 100,
    super.errorMapper,
  });

  /// The page size [findAll] and [count] read the collection with.
  final int pageSizeForFindAll;

  /// How many pages [findAll] and [count] read at most.
  ///
  /// A backend that keeps reporting a further page would otherwise make them
  /// loop forever; hitting this cap fails with [CrudUnsupportedException]
  /// instead, which is a bug you can see rather than an app that hangs.
  final int maxPagesForFindAll;

  PagingCrudApi<T, ID> get _pagingApi => api as PagingCrudApi<T, ID>;

  @override
  Future<CrudResult<Page<T>>> findPage(PageRequest pageRequest) =>
      guard(() => _pagingApi.findPage(pageRequest));

  @override
  Future<CrudResult<List<T>>> findAll() => guard(_readEveryPage);

  @override
  Future<CrudResult<int>> count() => guard(() async {
    final first = await _pagingApi.findPage(
      OffsetPageRequest(size: pageSizeForFindAll),
    );
    // A backend that reports the total saves us from walking the collection.
    if (first is OffsetPage<T> && first.totalElements != null) {
      return first.totalElements!;
    }
    return (await _readEveryPage()).length;
  });

  Future<List<T>> _readEveryPage() async {
    final entities = <T>[];
    PageRequest? request = OffsetPageRequest(size: pageSizeForFindAll);
    for (var read = 0; request != null; read++) {
      if (read >= maxPagesForFindAll) {
        throw CrudUnsupportedException(
          'Reading every $T stopped after $maxPagesForFindAll pages of '
          '$pageSizeForFindAll. Use findPage instead, or raise '
          'maxPagesForFindAll if the collection really is this large.',
        );
      }
      final page = await _pagingApi.findPage(request);
      entities.addAll(page.content);
      // An empty page ends the walk even if the backend claims another one.
      if (page.isEmpty) break;
      request = page.nextPageRequest(request);
    }
    return List<T>.unmodifiable(entities);
  }
}
