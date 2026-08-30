# Contributing

## Conventions

- **Package names** are prefixed with `fabitus_`, lower_snake_case.
- **Public API** is exported exclusively from `lib/<package_name>.dart`.
  Everything else lives under `lib/src/` and is never imported directly by
  consumers.
- **Versioning** follows [semantic versioning](https://semver.org). Every user
  visible change gets an entry in the package's `CHANGELOG.md`.
- **Formatting and lints** are enforced in CI: `dart format .` and
  `dart analyze --fatal-infos` must be clean.
- **Licensing**: everything in this repo is MIT licensed. Each package keeps a
  copy of the root `LICENSE` file, because pub.dev only detects a license that
  sits inside the package directory. Contributions are accepted under the same
  license.

## Code generation

Value types use [freezed](https://pub.dev/packages/freezed). The generated
`*.freezed.dart` files **are committed**, because these packages are consumed as
git dependencies: pub serves whatever the repository contains, and committing
the output is what frees consumers from running `build_runner` themselves.

After changing a `@freezed` class:

```sh
cd packages/<name>
dart run build_runner build     # or: watch, while iterating
```

Commit the regenerated files together with your change. CI regenerates on every
push and fails if the committed output has drifted.

Generated files are analyzed rather than excluded - they carry their own
`ignore_for_file: type=lint` header, so lints stay quiet while compile errors in
generated code remain visible. They also carry `// dart format off`, so
`dart format` leaves them alone.

> freezed 4 requires Dart 3.13. The packages here are pinned to the freezed 3.x
> line until the SDK constraint is raised.

## Workflow

```sh
dart pub get                 # from the repo root, resolves all packages
cd packages/<name> && dart run build_runner build
dart format .
dart analyze --fatal-infos
cd packages/<name> && dart test
```

Branch off `main`, open a pull request, keep CI green.

## Dependencies

Add dependencies to the `pubspec.yaml` of the package that needs them, then run
`dart pub get` in the repo root. Only the root `pubspec.lock` is tracked in git.
