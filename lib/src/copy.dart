import 'spec.generated.dart';

String copy(String key, [Map<String, Object?> values = const {}]) {
  var text = SpecCopy.en[key] ?? key;
  values.forEach((name, value) => text = text.replaceAll('{$name}', '$value'));
  return text;
}

String verifierName(Map? info) {
  final name = (info?['requester'] as Map?)?['name'];
  return name is String && name.trim().isNotEmpty
      ? name.trim()
      : copy(SpecCopyKey.commonVerifierFallback);
}
