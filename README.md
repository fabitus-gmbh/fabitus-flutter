# fabitus-flutter

Mono repo for the Dart and Flutter libraries developed at Fabitus, set up as a
[Dart workspace](https://dart.dev/tools/pub/workspaces): all packages share one
dependency resolution and one `pubspec.lock` at the repo root.

## Packages

| Package | Description |
| --- | --- |
| [`fabitus_crud_api`](packages/fabitus_crud_api) | Spring Data style CRUD repositories, pagination and error handling, with in-memory, key-value and remote implementations. |
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

The packages do not depend on each other. `fabitus_crud_api` has no opinion
about a backend's error format; `fabitus_problem_details` implements one, and
either README shows the few lines that bridge them.

## Getting started

Requires the Dart SDK 3.9 or newer (bundled with Flutter 3.35+).

```sh
dart pub get          # resolves every package in the workspace at once
dart analyze
dart format .
```

Run the tests of a single package from its directory:

```sh
cd packages/fabitus_crud_api && dart test
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
