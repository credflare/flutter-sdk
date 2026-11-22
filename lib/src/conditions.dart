import 'dart:convert';
import 'spec.generated.dart';

final _date = RegExp(
  r'^\d{4}-\d{2}-\d{2}([T ][0-9:.]+(Z|[+-]\d{2}:?\d{2})?)?$',
);
final _numeric = RegExp(
  r'^[ \t\n\r\v\f]*[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?[ \t\n\r\v\f]*$',
);

bool _isList(Object? v) => v is List;
bool _isMap(Object? v) => v is Map || v is List;
bool _isScalar(Object? v) => v is String || v is num || v is bool;
bool _isNumeric(Object? v) =>
    (v is num && v.isFinite) || (v is String && _numeric.hasMatch(v));
double _number(Object? v) =>
    v is num ? v.toDouble() : double.parse((v as String).trim());

Iterable<Object?> _values(Object? v) => v is Map
    ? v.values
    : v is List
    ? v
    : const [];

int _size(Object? v) => v is Map
    ? v.length
    : v is List
    ? v.length
    : 0;

String _text(Object? v) {
  if (v == true) return '1';
  if (v == false || v == null) return '';
  if (v is double &&
      v.isFinite &&
      v == v.truncateToDouble() &&
      v.abs() < 1e21) {
    return v.toInt().toString();
  }
  return '$v';
}

bool? _boolean(Object? v) {
  if (v is bool) return v;
  if (_isMap(v)) return null;
  final s = _text(v).trim().toLowerCase();
  if (const ['1', 'true', 'on', 'yes'].contains(s)) return true;
  if (const ['0', 'false', 'off', 'no', ''].contains(s)) return false;
  return null;
}

bool _truthy(Object? v) =>
    _isMap(v) ? _size(v) > 0 : !(v == 0 || v == '' || v == '0' || v == false);

bool _loose(Object? a, Object? b) {
  if (a == null || b == null) {
    final other = a ?? b;
    if (other == null) return true;
    if (_isMap(other)) return _size(other) == 0;
    return _boolean(other) == false && (other is! String || other == '');
  }
  if (a is bool || b is bool) return _truthy(a) == _truthy(b);
  if (_isMap(a) || _isMap(b)) {
    if (!_isMap(a) || !_isMap(b)) return false;
    final x = _entries(a);
    final y = _entries(b);
    if (x.length != y.length) return false;
    return x.entries.every(
      (e) => y.containsKey(e.key) && _loose(e.value, y[e.key]),
    );
  }
  if (_isNumeric(a) && _isNumeric(b)) return _number(a) == _number(b);
  return _text(a) == _text(b);
}

Map<String, Object?> _entries(Object? v) => v is Map
    ? {for (final e in v.entries) '${e.key}': e.value}
    : {for (final (i, item) in (v as List).indexed) '$i': item};

bool _equals(Object? actual, Object? expected) {
  if (_isMap(actual) || _isMap(expected)) return _loose(actual, expected);
  if (actual is bool || expected is bool) {
    return _boolean(actual) == _boolean(expected);
  }
  if (_isNumeric(actual) && _isNumeric(expected)) {
    return _number(actual) == _number(expected);
  }
  return _text(actual) == _text(expected);
}

int? _time(String s) {
  var iso = s.replaceFirst(' ', 'T');
  if (!iso.contains('T')) iso += 'T00:00:00';
  if (!RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(iso)) iso += 'Z';
  iso = iso.replaceFirstMapped(
    RegExp(r'([+-]\d{2})(\d{2})$'),
    (m) => '${m[1]}:${m[2]}',
  );
  final parts = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(:(\d{2})(\.\d+)?)?(Z|[+-]\d{2}:\d{2})$',
  ).firstMatch(iso);
  if (parts == null) return null;
  final month = int.parse(parts[2]!);
  final day = int.parse(parts[3]!);
  final hour = int.parse(parts[4]!);
  final minute = int.parse(parts[5]!);
  final second = int.parse(parts[7] ?? '0');
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  if (hour > 24 || minute > 59 || second > 59) return null;
  if (hour == 24 && (minute > 0 || second > 0)) return null;
  return DateTime.tryParse(iso)?.millisecondsSinceEpoch;
}

int? _compare(Object? actual, Object? expected) {
  if (_isNumeric(actual) && _isNumeric(expected)) {
    return (_number(actual) - _number(expected)).sign.toInt();
  }
  if (actual is String &&
      expected is String &&
      _date.hasMatch(actual) &&
      _date.hasMatch(expected)) {
    final a = _time(actual);
    final b = _time(expected);
    return a == null || b == null ? null : (a - b).sign;
  }
  return null;
}

bool _within(Object? needle, Object? haystack) => _values(
  haystack,
).any((c) => !_isMap(c) && !_isMap(needle) && _equals(needle, c));

bool _contains(Object? actual, Object? expected) {
  if (_isMap(actual)) return _within(expected, actual);
  if (_isScalar(actual) && _isScalar(expected) && _text(expected) != '') {
    return _text(actual).toLowerCase().contains(_text(expected).toLowerCase());
  }
  return false;
}

bool _regex(Object? actual, Object? pattern) {
  if (!_isScalar(actual) ||
      pattern is! String ||
      pattern.length > SpecRequirements.showIfMaxPatternLength) {
    return false;
  }
  try {
    return RegExp(pattern, unicode: true).hasMatch(_text(actual));
  } on FormatException {
    return false;
  }
}

int _common(List<int> a, List<int> b) {
  var max = 0;
  var p1 = 0;
  var p2 = 0;
  for (var i = 0; i < a.length; i++) {
    for (var j = 0; j < b.length; j++) {
      var l = 0;
      while (i + l < a.length && j + l < b.length && a[i + l] == b[j + l]) {
        l++;
      }
      if (l > max) {
        max = l;
        p1 = i;
        p2 = j;
      }
    }
  }
  if (max == 0) return 0;
  return max +
      _common(a.sublist(0, p1), b.sublist(0, p2)) +
      _common(a.sublist(p1 + max), b.sublist(p2 + max));
}

/// Similarity of two texts as a percentage, counted in UTF-8 bytes.
double similarity(String a, String b) {
  final x = utf8.encode(a);
  final y = utf8.encode(b);
  return x.length + y.length == 0
      ? 0
      : _common(x, y) * 2 * 100 / (x.length + y.length);
}

bool _fuzzy(Object? actual, Object? expected) {
  if (!_isScalar(actual) || expected is! Map || !_isScalar(expected['text'])) {
    return false;
  }
  String normalize(Object? v) =>
      _text(v).toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  final score =
      expected['min_score'] ?? SpecRequirements.showIfFuzzyDefaultMinScore;
  if (!_isNumeric(score)) return false;
  return similarity(normalize(actual), normalize(expected['text'])) >=
      _number(score);
}

(bool, Object?) _resolve(String path, Object? context) {
  Object? value = context;
  for (final segment in path.split('.')) {
    final index = int.tryParse(segment);
    if (value is Map && value.containsKey(segment)) {
      value = value[segment];
    } else if (value is List &&
        index != null &&
        index >= 0 &&
        index < value.length &&
        '$index' == segment) {
      value = value[index];
    } else {
      return (false, null);
    }
  }
  return (true, value);
}

/// Evaluates one show_if condition against `{"form": answers}`.
bool testCondition(Map condition, Object? context) {
  final (exists, actual) = _resolve(
    condition['path'] as String? ?? '',
    context,
  );
  final expected = condition['value'];
  final missing = !exists || actual == null;
  final empty = missing || actual == '' || (actual is List && actual.isEmpty);
  switch (condition['op']) {
    case 'is_empty':
      return empty;
    case 'is_not_empty':
      return !empty;
  }
  if (missing) return false;
  bool cmp(bool Function(int) holds) {
    final c = _compare(actual, expected);
    return c != null && holds(c);
  }

  return switch (condition['op']) {
    'equals' => _equals(actual, expected),
    'not_equals' => !_equals(actual, expected),
    'gt' => cmp((c) => c > 0),
    'gte' => cmp((c) => c >= 0),
    'lt' => cmp((c) => c < 0),
    'lte' => cmp((c) => c <= 0),
    'contains' => _contains(actual, expected),
    'not_contains' => !_contains(actual, expected),
    'in' => _isList(expected) && _within(actual, expected),
    'not_in' => _isList(expected) && !_within(actual, expected),
    'regex' => _regex(actual, expected),
    'fuzzy_match' => _fuzzy(actual, expected),
    _ => false,
  };
}

/// Whether a show_if block matches the context.
bool showIfMatches(Map showIf, Object? context) {
  final results = [
    for (final c in showIf['conditions'] as List? ?? const [])
      testCondition(c as Map, context),
  ];
  return (showIf['match'] ?? SpecRequirements.showIfDefaultMatch) == 'any'
      ? results.contains(true)
      : !results.contains(false);
}

/// A question is shown when it has no show_if, the show_if has no conditions,
/// or its conditions match the answers given so far.
bool questionVisible(Map question, Map<String, Object?> answers) {
  final showIf = question['show_if'];
  if (showIf is! Map || (showIf['conditions'] as List? ?? const []).isEmpty) {
    return true;
  }
  return showIfMatches(showIf, {'form': answers});
}
