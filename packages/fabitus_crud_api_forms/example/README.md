# fabitus_crud_api_forms example

A list, an edit form and a create form. Shows the three fields bound through
`EntityFieldBuilder`, the actions read off `CrudFormScope`, and the
discard-changes dialog that the package asks for but does not draw.

Note the `BackButton`: it calls `Navigator.maybePop`, because that is what
consults the unsaved-edits guard - a plain `pop` would leave without asking.

Like the other Flutter packages here it has no `dart run`: widgets need a host
app. The file is analyzed as part of the package, so it cannot drift out of date.

```sh
flutter test
```
