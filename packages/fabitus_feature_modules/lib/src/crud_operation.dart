/// The operations access to a feature is granted for.
///
/// These are the four things a user can do to an entity, and therefore the four
/// things a role can be allowed to do. Purely presentational actions - cancel an
/// edit, close a dialog - are not operations: nobody needs a permission for
/// them, and putting them here would mean granting a permission that always
/// holds.
enum CrudOperation {
  /// Bring a new entity into existence.
  create,

  /// Look at an entity, or list them.
  read,

  /// Change an entity that already exists.
  update,

  /// Remove an entity.
  delete;

  /// The operations that only look, never change.
  static const Set<CrudOperation> readOnly = {CrudOperation.read};

  /// The operations that change something.
  static const Set<CrudOperation> writing = {CrudOperation.create, CrudOperation.update, CrudOperation.delete};
}
