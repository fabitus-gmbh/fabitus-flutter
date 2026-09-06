import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Builds the item at [index] of the accumulated list.
typedef PagedItemBuilder<T> = Widget Function(BuildContext context, T item, int index);

/// Builds the "load more" control. [onPressed] is `null` while a page is
/// already on its way.
typedef LoadMoreBuilder = Widget Function(BuildContext context, VoidCallback? onPressed);

/// A list over a [PaginationCubit] that appends the next page as the user
/// reaches the end.
///
/// The pages accumulate - [PaginationState.allItems] - so the list only ever
/// grows, which is what an endless scroll means.
///
/// ```dart
/// CrudInfiniteList<Todo, void>(
///   itemBuilder: (context, todo, index) => MyTile(todo),
///   loadingBuilder: (context) => const MySpinner(),
/// );
/// ```
///
/// Loading the next page is triggered by the trailing item coming into view, so
/// it happens exactly when the user can see that there is more. Nothing is
/// requested twice: the cubit ignores a `nextPage` while one is in flight, and
/// this widget does not ask while it is loading.
///
/// The cubit comes from the enclosing [BlocProvider] unless one is passed.
class CrudInfiniteList<T, F> extends StatelessWidget {
  /// Renders everything [cubit] has read, and reads more on demand.
  const CrudInfiniteList({
    required this.itemBuilder,
    this.cubit,
    this.separatorBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.scrollController,
    this.cacheExtent,
    super.key,
  });

  /// Builds one item.
  final PagedItemBuilder<T> itemBuilder;

  /// The cubit to render. Read from the enclosing provider when omitted.
  final PaginationCubit<T, F>? cubit;

  /// Goes between two items. Nothing by default.
  final IndexedWidgetBuilder? separatorBuilder;

  /// The trailing item while the next page is on its way, and the whole body
  /// while the first page is.
  final WidgetBuilder? loadingBuilder;

  /// Replaces the body when the collection is empty.
  final WidgetBuilder? emptyBuilder;

  /// Replaces the body when the first page failed, and goes at the end when a
  /// later one did. [retry] tries again.
  final Widget Function(BuildContext context, CrudException error, VoidCallback retry)? errorBuilder;

  /// Passed to the underlying [ListView].
  final EdgeInsetsGeometry? padding;

  /// Passed to the underlying [ListView].
  final bool shrinkWrap;

  /// Passed to the underlying [ListView].
  final ScrollPhysics? physics;

  /// Passed to the underlying [ListView].
  final ScrollController? scrollController;

  /// How far beyond the viewport the list builds ahead, which is also how
  /// eagerly it reads the next page.
  ///
  /// The trailing item is what triggers a read, and a [ListView] builds items
  /// within its cache extent even though they are not visible yet - so this is
  /// the prefetch knob. Flutter's default is 250 logical pixels, enough that a
  /// first page too short to fill the screen is topped up without the user
  /// doing anything. `ScrollCacheExtent.pixels(0)` reads only once the end is
  /// genuinely on screen; `ScrollCacheExtent.viewport(1)` reads a screenful
  /// ahead.
  final ScrollCacheExtent? cacheExtent;

  @override
  Widget build(BuildContext context) => _PagedListBody<T, F>(
    cubit: cubit,
    itemBuilder: itemBuilder,
    separatorBuilder: separatorBuilder,
    loadingBuilder: loadingBuilder,
    emptyBuilder: emptyBuilder,
    errorBuilder: errorBuilder,
    padding: padding,
    shrinkWrap: shrinkWrap,
    physics: physics,
    scrollController: scrollController,
    cacheExtent: cacheExtent,
    loadMoreBuilder: null,
  );
}

/// A list over a [PaginationCubit] that appends the next page when the user asks
/// for it.
///
/// The same accumulating list as [CrudInfiniteList], with a control at the end
/// instead of a scroll trigger - for the screens where reading more should be a
/// decision rather than a side effect of scrolling.
///
/// ```dart
/// CrudLoadMoreList<Todo, void>(
///   itemBuilder: (context, todo, index) => MyTile(todo),
///   loadMoreBuilder: (context, onPressed) => TextButton(
///     onPressed: onPressed,          // null while a page is on its way
///     child: const Text('Load more'),
///   ),
/// );
/// ```
class CrudLoadMoreList<T, F> extends StatelessWidget {
  /// Renders everything [cubit] has read, and reads more when asked.
  const CrudLoadMoreList({
    required this.itemBuilder,
    required this.loadMoreBuilder,
    this.cubit,
    this.separatorBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.scrollController,
    this.cacheExtent,
    super.key,
  });

  /// Builds one item.
  final PagedItemBuilder<T> itemBuilder;

  /// Builds the control that reads the next page.
  ///
  /// Its callback is `null` while a page is already on its way, which is what a
  /// disabled button wants.
  final LoadMoreBuilder loadMoreBuilder;

  /// The cubit to render. Read from the enclosing provider when omitted.
  final PaginationCubit<T, F>? cubit;

  /// Goes between two items. Nothing by default.
  final IndexedWidgetBuilder? separatorBuilder;

  /// The whole body while the first page is on its way.
  final WidgetBuilder? loadingBuilder;

  /// Replaces the body when the collection is empty.
  final WidgetBuilder? emptyBuilder;

  /// Replaces the body when the first page failed, and goes at the end when a
  /// later one did. [retry] tries again.
  final Widget Function(BuildContext context, CrudException error, VoidCallback retry)? errorBuilder;

  /// Passed to the underlying [ListView].
  final EdgeInsetsGeometry? padding;

  /// Passed to the underlying [ListView].
  final bool shrinkWrap;

  /// Passed to the underlying [ListView].
  final ScrollPhysics? physics;

  /// Passed to the underlying [ListView].
  final ScrollController? scrollController;

  /// How far beyond the viewport the list builds ahead, which is also how
  /// eagerly it reads the next page.
  ///
  /// The trailing item is what triggers a read, and a [ListView] builds items
  /// within its cache extent even though they are not visible yet - so this is
  /// the prefetch knob. Flutter's default is 250 logical pixels, enough that a
  /// first page too short to fill the screen is topped up without the user
  /// doing anything. `ScrollCacheExtent.pixels(0)` reads only once the end is
  /// genuinely on screen; `ScrollCacheExtent.viewport(1)` reads a screenful
  /// ahead.
  final ScrollCacheExtent? cacheExtent;

  @override
  Widget build(BuildContext context) => _PagedListBody<T, F>(
    cubit: cubit,
    itemBuilder: itemBuilder,
    separatorBuilder: separatorBuilder,
    loadingBuilder: loadingBuilder,
    emptyBuilder: emptyBuilder,
    errorBuilder: errorBuilder,
    padding: padding,
    shrinkWrap: shrinkWrap,
    physics: physics,
    scrollController: scrollController,
    cacheExtent: cacheExtent,
    loadMoreBuilder: loadMoreBuilder,
  );
}

/// What both lists actually are. The only difference is whether the trailing
/// item reads the next page by itself.
class _PagedListBody<T, F> extends StatelessWidget {
  const _PagedListBody({
    required this.itemBuilder,
    required this.loadMoreBuilder,
    required this.cubit,
    required this.separatorBuilder,
    required this.loadingBuilder,
    required this.emptyBuilder,
    required this.errorBuilder,
    required this.padding,
    required this.shrinkWrap,
    required this.physics,
    required this.scrollController,
    required this.cacheExtent,
  });

  final PagedItemBuilder<T> itemBuilder;

  /// `null` means "read the next page when the trailer is built".
  final LoadMoreBuilder? loadMoreBuilder;

  final PaginationCubit<T, F>? cubit;
  final IndexedWidgetBuilder? separatorBuilder;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? emptyBuilder;
  final Widget Function(BuildContext context, CrudException error, VoidCallback retry)? errorBuilder;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ScrollController? scrollController;
  final ScrollCacheExtent? cacheExtent;

  bool get _autoLoads => loadMoreBuilder == null;

  @override
  Widget build(BuildContext context) {
    final cubit = this.cubit;
    return cubit == null
        ? BlocBuilder<PaginationCubit<T, F>, PaginationState<T, F>>(builder: _build)
        : BlocBuilder<PaginationCubit<T, F>, PaginationState<T, F>>(bloc: cubit, builder: _build);
  }

  Widget _build(BuildContext context, PaginationState<T, F> state) {
    final cubit = this.cubit ?? context.read<PaginationCubit<T, F>>();
    final items = state.allItems;
    final error = state.error;

    // Nothing on screen yet: the first page owns the whole body, whether it is
    // still coming or failed.
    if (items.isEmpty) {
      if (state.status.isFailure && error != null) {
        return errorBuilder?.call(context, error, cubit.refresh) ?? const SizedBox.shrink();
      }
      if (!state.status.isSuccess) {
        return loadingBuilder?.call(context) ?? const SizedBox.shrink();
      }
      return emptyBuilder?.call(context) ?? const SizedBox.shrink();
    }

    final trailer = _trailer(context, state, cubit);
    final count = items.length + (trailer == null ? 0 : 1);

    return ListView.separated(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      controller: scrollController,
      scrollCacheExtent: cacheExtent,
      itemCount: count,
      separatorBuilder: (context, index) => separatorBuilder?.call(context, index) ?? const SizedBox.shrink(),
      itemBuilder: (context, index) {
        if (index < items.length) return itemBuilder(context, items[index], index);

        // The trailer came into view, which is the signal an endless scroll
        // waits for. Scheduling it after the frame keeps the build pure.
        if (_autoLoads && !state.status.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!cubit.isClosed) cubit.nextPage();
          });
        }
        return trailer!;
      },
    );
  }

  /// What goes after the last item: a failure, a control, a spinner, or nothing.
  Widget? _trailer(BuildContext context, PaginationState<T, F> state, PaginationCubit<T, F> cubit) {
    final error = state.error;
    // A later page failing must not take the pages already read off the screen.
    if (state.status.isFailure && error != null) {
      return errorBuilder?.call(context, error, cubit.nextPage);
    }
    if (!state.hasNext) return null;
    if (loadMoreBuilder case final builder?) {
      return builder(context, state.status.isLoading ? null : cubit.nextPage);
    }
    return loadingBuilder?.call(context) ?? const SizedBox.shrink();
  }
}
