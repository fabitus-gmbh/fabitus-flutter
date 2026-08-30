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

## Workflow

```sh
dart pub get                 # from the repo root, resolves all packages
dart format .
dart analyze --fatal-infos
cd packages/<name> && dart test
```

Branch off `main`, open a pull request, keep CI green.

## Dependencies

Add dependencies to the `pubspec.yaml` of the package that needs them, then run
`dart pub get` in the repo root. Only the root `pubspec.lock` is tracked in git.
