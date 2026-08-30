import 'package:collection/collection.dart';

/// A single field level validation error.
///
/// Backends disagree on the wire format, so [ConstraintViolation.fromJson]
/// accepts the common spellings: `field`, `propertyPath` or `name` for the
/// field, and `message`, `defaultMessage` or `reason` for the text.
class ConstraintViolation {
  /// Creates a violation for [field] with the given [message].
  const ConstraintViolation({required this.field, required this.message});

  /// Reads a violation from its JSON representation.
  factory ConstraintViolation.fromJson(Map<String, dynamic> json) =>
      ConstraintViolation(
        field:
            (json['field'] ?? json['propertyPath'] ?? json['name'] ?? '')
                as String,
        message:
            (json['message'] ?? json['defaultMessage'] ?? json['reason'] ?? '')
                as String,
      );

  /// Name of the offending property, for example `title` or `address.zip`.
  final String field;

  /// Human readable description of what is wrong with [field].
  final String message;

  /// The JSON representation of this violation.
  Map<String, dynamic> toJson() => {'field': field, 'message': message};

  @override
  String toString() => '$field: $message';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstraintViolation &&
          other.field == field &&
          other.message == message;

  @override
  int get hashCode => Object.hash(field, message);
}

/// A machine readable error body as defined by RFC 9457 (formerly RFC 7807),
/// which is what Spring's `ProblemDetail` and Zalando's `problem` library emit.
///
/// Unknown members are kept in [extensions] so application specific fields are
/// not lost.
class ProblemDetail {
  /// Creates a problem detail.
  const ProblemDetail({
    this.type,
    this.title,
    this.status,
    this.detail,
    this.instance,
    this.violations = const [],
    this.extensions = const {},
  });

  /// Reads a problem detail from a decoded JSON body.
  ///
  /// Violations are read from `violations` or `errors`, whichever is present.
  factory ProblemDetail.fromJson(Map<String, dynamic> json) {
    const known = {
      'type',
      'title',
      'status',
      'detail',
      'instance',
      'violations',
      'errors',
    };
    final rawViolations = (json['violations'] ?? json['errors']);
    return ProblemDetail(
      type: json['type'] as String?,
      title: json['title'] as String?,
      status: (json['status'] as num?)?.toInt(),
      detail: json['detail'] as String?,
      instance: json['instance'] as String?,
      violations: rawViolations is List
          ? rawViolations
                .whereType<Map<String, dynamic>>()
                .map(ConstraintViolation.fromJson)
                .toList(growable: false)
          : const [],
      extensions: {
        for (final entry in json.entries)
          if (!known.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  /// Attempts to read a problem detail from an arbitrary decoded response body.
  ///
  /// Returns `null` when [body] is not a JSON object, which lets callers fall
  /// back to a plain status code based error.
  static ProblemDetail? tryParse(Object? body) {
    if (body is Map<String, dynamic>) {
      return ProblemDetail.fromJson(body);
    }
    if (body is Map) {
      return ProblemDetail.fromJson(
        body.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return null;
  }

  /// URI identifying the problem type, for example
  /// `https://fabit.us/problem/constraint-violation`.
  final String? type;

  /// Short, human readable summary of the problem type.
  final String? title;

  /// The HTTP status code the origin server generated for this occurrence.
  final int? status;

  /// Human readable explanation specific to this occurrence.
  final String? detail;

  /// URI identifying the specific occurrence of the problem.
  final String? instance;

  /// Field level validation errors, empty when the problem is not a validation
  /// failure.
  final List<ConstraintViolation> violations;

  /// Members of the body that are not part of the standard.
  final Map<String, dynamic> extensions;

  /// The most specific human readable message available, falling back through
  /// [detail], [title] and [type].
  String get message => detail ?? title ?? type ?? 'Unknown problem';

  /// The violation for [field], or `null` when the field has no violation.
  ConstraintViolation? violationFor(String field) =>
      violations.firstWhereOrNull((violation) => violation.field == field);

  /// The JSON representation of this problem detail.
  Map<String, dynamic> toJson() => {
    if (type != null) 'type': type,
    if (title != null) 'title': title,
    if (status != null) 'status': status,
    if (detail != null) 'detail': detail,
    if (instance != null) 'instance': instance,
    if (violations.isNotEmpty)
      'violations': violations.map((v) => v.toJson()).toList(growable: false),
    ...extensions,
  };

  @override
  String toString() => 'ProblemDetail($message)';
}
