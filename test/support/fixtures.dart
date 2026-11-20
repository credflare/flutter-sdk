import 'dart:convert';
import 'dart:io';

Map<String, dynamic> fixture(String name, {String root = 'test/fixtures'}) =>
    jsonDecode(File('$root/$name.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> captureSession(
  String method, {
  String documentMethod = 'camera',
  String environment = 'sandbox',
  String root = 'test/fixtures',
}) {
  final raw = fixture('session', root: root);
  final data = raw['data'] as Map<String, dynamic>;
  data['environment'] = environment;
  final requirement =
      (data['profile']['document_requirements'] as List).first
          as Map<String, dynamic>;
  requirement['capture_method'] = method;
  (requirement['document_type'] as Map)['capture_method'] = documentMethod;
  return raw;
}
