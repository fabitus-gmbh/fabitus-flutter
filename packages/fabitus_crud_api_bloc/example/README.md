# fabitus_crud_api_bloc example

[`main.dart`](main.dart) is a small app showing all three cubits: a list built
from `LoadCubit` and `LoadBuilder`, an edit form built from `EntityCubit`, and a
paged table built from `PaginationCubit`.

Unlike the other packages in this repo it has no `dart run`: Flutter widgets need
a host app. The file is analyzed as part of the package, so it cannot drift out of
date - copy it into an app to see it move. The widget tests in
[`../test`](../test) exercise the same paths headlessly:

```sh
flutter test
```
