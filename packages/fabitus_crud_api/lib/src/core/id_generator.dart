import 'dart:math';

/// Creates identifiers for entities that are persisted locally.
///
/// Remote backends usually assign the id themselves; local repositories such as
/// `InMemoryCrudRepository` need to generate one on `create`.
typedef IdGenerator<ID extends Object> = ID Function();

const String _alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';

final Random _random = Random();

/// Returns a URL safe, random [String] id of [length] characters.
///
/// This is deliberately not a UUID: local ids only have to be unique within a
/// single store, and avoiding a dependency keeps this package dependency light.
/// Pass your own [IdGenerator] if you need RFC 4122 UUIDs.
String randomStringId({int length = 16}) {
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(_alphabet[_random.nextInt(_alphabet.length)]);
  }
  return buffer.toString();
}

/// The [IdGenerator] local repositories use when none is supplied.
///
/// Only [String] ids can be generated without configuration; every other id
/// type has to provide its own generator.
IdGenerator<ID> defaultIdGenerator<ID extends Object>() {
  if (ID == String) {
    return () => randomStringId() as ID;
  }
  throw ArgumentError(
    'No default id generator for $ID. Pass generateId explicitly.',
  );
}
