/// Cubits and widgets for driving `fabitus_crud_api` repositories from Flutter.
///
/// Three cubits, one per shape a screen comes in:
///
/// * [LoadCubit] - show one thing, whether a single entity or a whole list.
/// * [PaginationCubit] - walk a paged collection, as a table or an endless
///   scroll.
/// * [EntityCubit] - read, edit, save and delete one entity, with the draft and
///   the field errors a form needs.
///
/// All three take their data from a repository's [CrudResult], so a failure is
/// already a typed [CrudException] by the time it reaches the state.
///
/// They are `Cubit`s rather than `Bloc`s: every one of them has methods a caller
/// names directly, and no event needed transforming. The README says where a
/// `Bloc` is still the better answer.
library;

export 'src/entity/entity_cubit.dart';
export 'src/entity/entity_state.dart';
export 'src/load/load_cubit.dart';
export 'src/load/load_state.dart';
export 'src/pagination/pagination_cubit.dart';
export 'src/pagination/pagination_state.dart';
export 'src/widgets/crud_error_view.dart';
export 'src/widgets/load_builder.dart';
