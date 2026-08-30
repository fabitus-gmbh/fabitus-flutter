import 'package:uuid/uuid.dart';

/// Creates identifiers for entities that are persisted locally.
///
/// Remote backends usually assign the id themselves; local repositories such as
/// `InMemoryCrudRepository` need to generate one on `create`.
typedef IdGenerator<ID extends Object> = ID Function();

const Uuid _uuid = Uuid();

/// Returns a new random (version 4) UUID, for example
/// `6f3d1c0e-6b8a-4f2b-9d3e-1a2b3c4d5e6f`.
///
/// This is the default id for local repositories. Version 4 is the right
/// default for a client: it needs no coordination, so two devices that both
/// create entities offline will not collide.
String newUuid() => _uuid.v4();

/// The [IdGenerator] local repositories use when none is supplied.
///
/// Only [String] ids can be generated without configuration; every other id
/// type has to provide its own generator.
IdGenerator<ID> defaultIdGenerator<ID extends Object>() {
  if (ID == String) {
    return () => newUuid() as ID;
  }
  throw ArgumentError(
    'No default id generator for $ID. Pass generateId explicitly.',
  );
}
