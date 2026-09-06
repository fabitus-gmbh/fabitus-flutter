# fabitus_crud_api_views example

Four tabs, one per shape: a paged table with its own footer, an endless scroll, a
load-more list, and a table over the whole collection with a search field that
filters without a request.

Every pixel comes from [`main.dart`](main.dart) - the package supplies the
wiring, the column sizing and the sort interaction, and nothing else.

Like the other Flutter packages here it has no `dart run`: widgets need a host
app. The file is analyzed as part of the package, so it cannot drift out of date.
The widget tests exercise the same paths headlessly:

```sh
flutter test
```
