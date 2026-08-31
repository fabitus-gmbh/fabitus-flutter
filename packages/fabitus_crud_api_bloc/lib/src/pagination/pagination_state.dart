import 'package:collection/collection.dart';
import 'package:fabitus_crud_api/fabitus_crud_api.dart';

/// How a [PaginationCubit] is doing.
enum PaginationStatus {
  /// No page has been requested yet.
  initial,

  /// A page is being loaded.
  loading,

  /// The last load succeeded.
  success,

  /// The last load failed.
  failure;

  /// Whether no page has been requested yet.
  bool get isInitial => this == PaginationStatus.initial;

  /// Whether a page is being loaded.
  bool get isLoading => this == PaginationStatus.loading;

  /// Whether the last load succeeded.
  bool get isSuccess => this == PaginationStatus.success;

  /// Whether the last load failed.
  bool get isFailure => this == PaginationStatus.failure;
}

/// The pages a [PaginationCubit] has loaded, and where in them the user is.
///
/// [pages] and [requests] are index aligned: `requests[i]` is what produced
/// `pages[i]`. Keeping the requests is what makes cursor pagination work -
/// a cursor only ever moves forward, so going back reads a page already held.
class PaginationState<T, F> {
  /// Creates a state. Prefer [PaginationState.initial] and [copyWith].
  const PaginationState({
    required this.status,
    required this.filter,
    required this.initialRequest,
    this.pages = const [],
    this.requests = const [],
    this.index = 0,
    this.error,
    this.stackTrace,
  });

  /// The state before anything has been loaded.
  const PaginationState.initial({required F filter, required PageRequest initialRequest})
    : this(status: PaginationStatus.initial, filter: filter, initialRequest: initialRequest);

  /// How the cubit is doing.
  final PaginationStatus status;

  /// The filter the pages were loaded with.
  final F filter;

  /// The request the first page is read with, and the template for page size and
  /// sort order.
  final PageRequest initialRequest;

  /// The pages loaded so far, oldest first.
  final List<Page<T>> pages;

  /// The request that produced each entry of [pages], index aligned.
  final List<PageRequest> requests;

  /// Which entry of [pages] the user is looking at.
  final int index;

  /// What went wrong on the last load, or `null`.
  final CrudException? error;

  /// Where it went wrong, or `null`.
  final StackTrace? stackTrace;

  /// The page the user is looking at, or `null` before the first load.
  Page<T>? get page => pages.elementAtOrNull(index);

  /// The entities on the current page.
  List<T> get items => page?.content ?? const [];

  /// Every entity loaded so far, across all pages.
  ///
  /// For an infinite scroll, which appends rather than replacing.
  List<T> get allItems => List.unmodifiable(pages.expand((page) => page.content));

  /// Whether a further page can be reached, whether already loaded or not.
  bool get hasNext => index + 1 < pages.length || (page?.hasNext ?? false);

  /// Whether there is a page before the current one.
  bool get hasPrevious => index > 0;

  /// Whether nothing was found at all.
  bool get isEmpty => pages.isNotEmpty && allItems.isEmpty;

  /// The total number of entities, when the backend reports it.
  int? get totalElements => switch (page) {
    OffsetPage<T>(:final totalElements) => totalElements,
    _ => null,
  };

  /// Field level errors from the last failure, empty when there are none.
  List<CrudViolation> get violations => error?.violations ?? const [];

  /// This state with the given fields replaced.
  ///
  /// [error] and [stackTrace] are cleared unless [keepError] is set, because
  /// almost every transition here is "something new happened, the old failure no
  /// longer applies".
  PaginationState<T, F> copyWith({
    PaginationStatus? status,
    F? filter,
    PageRequest? initialRequest,
    List<Page<T>>? pages,
    List<PageRequest>? requests,
    int? index,
    CrudException? error,
    StackTrace? stackTrace,
    bool keepError = false,
  }) => PaginationState<T, F>(
    status: status ?? this.status,
    filter: filter ?? this.filter,
    initialRequest: initialRequest ?? this.initialRequest,
    pages: pages ?? this.pages,
    requests: requests ?? this.requests,
    index: index ?? this.index,
    error: error ?? (keepError ? this.error : null),
    stackTrace: stackTrace ?? (keepError ? this.stackTrace : null),
  );

  @override
  String toString() =>
      'PaginationState<$T, $F>(status: ${status.name}, page: $index of '
      '${pages.length} loaded, items: ${allItems.length}, error: $error)';

  /// [stackTrace] is deliberately left out: two failures with the same error are
  /// the same state to a widget, and comparing stack traces by identity would
  /// rebuild on every retry that fails the same way.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginationState<T, F> &&
          other.status == status &&
          other.filter == filter &&
          other.initialRequest == initialRequest &&
          other.index == index &&
          other.error == error &&
          const ListEquality<Object?>().equals(other.pages, pages) &&
          const ListEquality<Object?>().equals(other.requests, requests);

  @override
  int get hashCode => Object.hash(
    status,
    filter,
    initialRequest,
    index,
    error,
    const ListEquality<Object?>().hash(pages),
    const ListEquality<Object?>().hash(requests),
  );
}
