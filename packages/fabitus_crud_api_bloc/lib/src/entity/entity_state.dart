import 'package:fabitus_crud_api/fabitus_crud_api.dart';

/// What an [EntityCubit] last tried to do.
enum EntityAction {
  /// Read the entity.
  load,

  /// Create or update it.
  save,

  /// Delete it.
  delete,
}

/// How an [EntityCubit] is doing.
enum EntityStatus {
  /// Nothing has happened yet.
  initial,

  /// An operation is running.
  busy,

  /// The last operation succeeded.
  success,

  /// The last operation failed.
  failure;

  /// Whether nothing has happened yet.
  bool get isInitial => this == EntityStatus.initial;

  /// Whether an operation is running.
  bool get isBusy => this == EntityStatus.busy;

  /// Whether the last operation succeeded.
  bool get isSuccess => this == EntityStatus.success;

  /// Whether the last operation failed.
  bool get isFailure => this == EntityStatus.failure;
}

/// One entity being looked at or edited.
///
/// Two copies are kept: [entity] as the store has it, and [draft] as the form
/// has it. That is what makes [isDirty] answerable, what lets [EntityCubit.reset]
/// undo an edit without a round trip, and what keeps the form filled after a
/// failed save.
class EntityState<T extends CrudEntity<Object>> {
  /// Creates a state. Prefer [EntityState.initial] and [copyWith].
  const EntityState({
    required this.status,
    this.entity,
    this.draft,
    this.action,
    this.error,
    this.stackTrace,
    this.isDeleted = false,
  });

  /// The state before anything has happened, optionally holding a [draft] to
  /// start editing - a blank entity for a create form.
  const EntityState.initial({T? draft}) : this(status: EntityStatus.initial, draft: draft);

  /// How the cubit is doing.
  final EntityStatus status;

  /// The entity as the store has it, `null` before it was read or created.
  final T? entity;

  /// The entity as the form has it.
  final T? draft;

  /// What was last attempted, `null` before anything was.
  final EntityAction? action;

  /// What went wrong, or `null`.
  final CrudException? error;

  /// Where it went wrong, or `null`.
  final StackTrace? stackTrace;

  /// Whether the entity was deleted, so the screen can close itself.
  final bool isDeleted;

  /// Whether the draft differs from what the store has.
  bool get isDirty => entity != draft;

  /// Whether there is a draft to submit.
  bool get hasDraft => draft != null;

  /// Whether the draft has never been stored.
  bool get isNew => draft?.id == null;

  /// Field level errors from the last failure, empty when there are none.
  List<CrudViolation> get violations => error?.violations ?? const [];

  /// The error for one form field, or `null` when that field has none.
  ///
  /// ```dart
  /// TextFormField(
  ///   decoration: InputDecoration(errorText: state.violationFor('title')?.message),
  /// );
  /// ```
  CrudViolation? violationFor(String field) => error?.violationFor(field);

  /// This state with the given fields replaced.
  ///
  /// [error] and [stackTrace] are cleared unless [keepError] is set: almost
  /// every transition here means the previous failure no longer applies. Pass
  /// [clearEntity] to drop [entity] and [draft], which deletion does.
  EntityState<T> copyWith({
    EntityStatus? status,
    T? entity,
    T? draft,
    EntityAction? action,
    CrudException? error,
    StackTrace? stackTrace,
    bool? isDeleted,
    bool keepError = false,
    bool clearEntity = false,
  }) => EntityState<T>(
    status: status ?? this.status,
    entity: clearEntity ? null : (entity ?? this.entity),
    draft: clearEntity ? null : (draft ?? this.draft),
    action: action ?? this.action,
    error: error ?? (keepError ? this.error : null),
    stackTrace: stackTrace ?? (keepError ? this.stackTrace : null),
    isDeleted: isDeleted ?? this.isDeleted,
  );

  @override
  String toString() =>
      'EntityState<$T>(status: ${status.name}, action: ${action?.name}, '
      'dirty: $isDirty, deleted: $isDeleted, error: $error)';

  /// [stackTrace] is deliberately left out, for the same reason it is in
  /// `CrudFailure`: two failures with the same error are the same state to a
  /// widget, and it would make the state impossible to write down in a test.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntityState<T> &&
          other.status == status &&
          other.entity == entity &&
          other.draft == draft &&
          other.action == action &&
          other.error == error &&
          other.isDeleted == isDeleted;

  @override
  int get hashCode => Object.hash(status, entity, draft, action, error, isDeleted);
}
