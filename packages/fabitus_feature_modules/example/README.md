# fabitus_feature_modules example

Declares four features of a small todo app, lets each register its own
dependencies into a stand-in locator, groups them under `Data` and
`Administration` the way a side navigation would, loads the access rights a
backend sent - which do not cover one of them - and prints the grouped
navigation and the permissions four different users get.

Note what happens to `Administration`: for anyone who is not an admin the whole
section disappears, heading included.

```sh
dart run example/main.dart
```
