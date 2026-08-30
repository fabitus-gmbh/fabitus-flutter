import 'package:logging/logging.dart';

/// The logger this package reports to.
///
/// Every failure a repository turns into a [CrudFailure], and every exception a
/// [CrudEventListener] throws, is logged here before it is handled. Wire it up
/// once in your app:
///
/// ```dart
/// crudLogger.onRecord.listen(reportToCrashlytics);
/// ```
final Logger crudLogger = Logger('fabitus_crud_api');
