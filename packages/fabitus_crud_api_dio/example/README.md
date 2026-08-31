# fabitus_crud_api_dio example

Feeds `DioCrudErrorMapper` the three shapes it has to handle - a problem detail
body, a body that is not one, and a request that never arrived - and prints the
`CrudException` that comes out. No network involved.

```sh
dart run example/main.dart
```
