import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'entity_state.dart';

/// Drives one entity through a [CrudRepository]: read it, edit it, save it,
/// delete it.
///
/// The methods are the API - `cubit.save()`, `cubit.delete()` - which is where a
/// `Cubit` beats a `Bloc` most clearly here. The original of this was a `Bloc`
/// with seven event classes whose handler did nothing but `event.map(...)` onto
/// seven methods; the events were pure indirection.
///
/// ```dart
/// final cubit = EntityCubit<Todo, String>(repository)..load(id);
///
/// // In the form:
/// cubit.edit((todo) => todo.copyWith(title: value));
/// // On submit:
/// await cubit.save();
/// ```
///
/// A failed save keeps the draft, so the user does not lose what they typed, and
/// [EntityState.violationFor] hands each field its own message.
class EntityCubit<T extends CrudEntity<ID>, ID extends Object> extends Cubit<EntityState<T>> {
  /// Creates a cubit over [repository].
  ///
  /// Pass [draft] to start on a create form: a blank entity the user fills in.
  EntityCubit(this.repository, {T? draft}) : super(EntityState<T>.initial(draft: draft));

  /// Where the entity is read from and written to.
  final CrudRepository<T, ID> repository;

  int _generation = 0;

  /// Reads the entity with [id] and makes it the draft.
  Future<void> load(ID id) async {
    final generation = ++_generation;
    emit(state.copyWith(status: EntityStatus.busy, action: EntityAction.load));

    final result = await repository.findById(id);
    if (generation != _generation || isClosed) return;

    switch (result) {
      case CrudSuccess<T>(:final data):
        emit(EntityState<T>(status: EntityStatus.success, action: EntityAction.load, entity: data, draft: data));
      case CrudFailure<T>(:final error, :final stackTrace):
        emit(_failure(EntityAction.load, error, stackTrace));
    }
  }

  /// Takes [entity] as both the stored value and the draft, without a round
  /// trip.
  ///
  /// For a master-detail screen where the list already has the entity.
  void select(T entity) =>
      emit(EntityState<T>(status: EntityStatus.success, action: EntityAction.load, entity: entity, draft: entity));

  /// Applies [change] to the draft.
  ///
  /// ```dart
  /// cubit.edit((todo) => todo.copyWith(title: value));
  /// ```
  ///
  /// Clears the error, so a violation disappears as soon as the field it is
  /// about is touched. Does nothing when there is no draft to change.
  void edit(T Function(T draft) change) {
    final draft = state.draft;
    if (draft == null) {
      crudLogger.warning('edit() ignored: $T has no draft to change yet');
      return;
    }
    emit(state.copyWith(draft: change(draft), status: EntityStatus.success));
  }

  /// Replaces the draft outright.
  void replaceDraft(T draft) => emit(state.copyWith(draft: draft, status: EntityStatus.success));

  /// Throws the edits away, putting the draft back to what the store has.
  void reset() => emit(
    EntityState<T>(status: EntityStatus.success, action: state.action, entity: state.entity, draft: state.entity),
  );

  /// Writes the draft: creates it when it has no id, updates it otherwise.
  ///
  /// On success both copies become what the store returned, so
  /// [EntityState.isDirty] is false again. On failure the draft is kept.
  Future<void> save() async {
    final draft = state.draft;
    if (draft == null) {
      crudLogger.warning('save() ignored: $T has no draft to write');
      return;
    }
    final generation = ++_generation;
    emit(state.copyWith(status: EntityStatus.busy, action: EntityAction.save));

    final result = await repository.save(draft);
    if (generation != _generation || isClosed) return;

    switch (result) {
      case CrudSuccess<T>(:final data):
        emit(EntityState<T>(status: EntityStatus.success, action: EntityAction.save, entity: data, draft: data));
      case CrudFailure<T>(:final error, :final stackTrace):
        emit(_failure(EntityAction.save, error, stackTrace));
    }
  }

  /// Deletes the entity.
  ///
  /// On success [EntityState.isDeleted] is set and both copies are dropped, so
  /// the screen can close itself. Does nothing when nothing is loaded.
  Future<void> delete() async {
    final id = state.entity?.id ?? state.draft?.id;
    if (id == null) {
      crudLogger.warning('delete() ignored: $T has no id to delete');
      return;
    }
    final generation = ++_generation;
    emit(state.copyWith(status: EntityStatus.busy, action: EntityAction.delete));

    final result = await repository.deleteById(id);
    if (generation != _generation || isClosed) return;

    if (result.isSuccess) {
      emit(EntityState<T>(status: EntityStatus.success, action: EntityAction.delete, isDeleted: true));
      return;
    }
    emit(_failure(EntityAction.delete, result.errorOrNull!, (result as CrudFailure<void>).stackTrace));
  }

  EntityState<T> _failure(EntityAction action, CrudException error, StackTrace stackTrace) =>
      state.copyWith(status: EntityStatus.failure, action: action, error: error, stackTrace: stackTrace);
}
