# fabitus-flutter

Mono repo for the Dart and Flutter libraries developed at Fabitus, set up as a
[Dart workspace](https://dart.dev/tools/pub/workspaces): all packages share one
dependency resolution and one `pubspec.lock` at the repo root.

## Packages

| Package | Description |
| --- | --- |
| [`fabitus_crud_api`](packages/fabitus_crud_api) | Spring Data style CRUD repositories, pagination and error handling, with in-memory, key-value and remote implementations. |
| [`fabitus_crud_api_bloc`](packages/fabitus_crud_api_bloc) | Cubits and widgets for driving `fabitus_crud_api` from Flutter: load, paginate, edit. |
| [`fabitus_crud_api_dio`](packages/fabitus_crud_api_dio) | Dio adapter for `fabitus_crud_api`: a ready made `CrudErrorMapper`. |
| [`fabitus_crud_api_views`](packages/fabitus_crud_api_views) | Headless lists and tables: infinite scroll, load more, paged tables, full list tables. |
| [`fabitus_feature_modules`](packages/fabitus_feature_modules) | Declare an app's features as modules with their own routes, navigation and role based access rights. |
| [`fabitus_problem_details`](packages/fabitus_problem_details) | RFC 9457 problem details for HTTP APIs, with tolerant parsing. |

## Layout

```
.
├── analysis_options.yaml      # shared lint rules, included by every package
├── pubspec.yaml               # workspace root, lists the members
├── pubspec.lock               # the single lock file for the whole workspace
├── .github/workflows/ci.yaml  # format + analyze + test
└── packages/
    ├── fabitus_crud_api/
    │   ├── analysis_options.yaml
    │   ├── pubspec.yaml       # resolution: workspace
    │   ├── lib/
    │   │   ├── fabitus_crud_api.dart   # public entry point (barrel)
    │   │   └── src/                    # implementation, not for direct import
    │   ├── test/
    │   └── example/
    └── fabitus_problem_details/
        └── ...                # same shape
```

`fabitus_crud_api`, `fabitus_problem_details` and `fabitus_feature_modules` are
independent of each other and free of Flutter: the first has no transport and no
opinion about a backend's error format, the second is that format on its own, the
third knows nothing about a router or a widget toolkit.

The Flutter and transport layers sit on top, and you depend on them only where
they apply: `fabitus_crud_api_dio` (Dio, plus the RFC 9457 reading),
`fabitus_crud_api_bloc` (Flutter and `flutter_bloc`) and
`fabitus_crud_api_views` (lists and tables over those cubits). The dio package
and the Flutter ones know nothing about each other - the bloc layer sees a typed
`CrudException` whoever produced it - and nothing in the view layer paints, so
your design system stays yours.

## Getting started

Requires Flutter 3.24 or newer (for the Dart 3.9 SDK it bundles). One package
depends on Flutter, so the workspace resolves through the Flutter SDK.

```sh
flutter pub get       # resolves every package in the workspace at once
dart analyze
dart format .
```

Run the tests of a single package from its directory - `dart test` for a pure
Dart package, `flutter test` for a Flutter one:

```sh
cd packages/fabitus_crud_api && dart test
cd packages/fabitus_crud_api_bloc && flutter test
```

## Adding a package

1. `mkdir -p packages/<name>/lib/src` and add a `pubspec.yaml` with
   `resolution: workspace`.
2. Add `packages/<name>` to the `workspace:` list in the root `pubspec.yaml`.
3. Add `analysis_options.yaml` containing `include: ../../analysis_options.yaml`.
4. Copy the root `LICENSE` into the package directory - pub.dev only detects a
   license file that sits next to the package's `pubspec.yaml`.
5. Run `dart pub get` in the repo root.

Flutter packages work the same way; they use `flutter pub get` and depend on
`flutter_lints` instead of `lints`.

See [CONTRIBUTING.md](CONTRIBUTING.md) for conventions.

## License

[MIT](LICENSE) © Fabitus GmbH. Every package carries its own copy of the
license file so it is picked up when the package is published.
