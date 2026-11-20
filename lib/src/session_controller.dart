import 'dart:async';
import 'package:flutter/foundation.dart';
import 'client.dart';

class CredflareSessionController extends ChangeNotifier {
  final Future<SessionDescriptor> Function() provider;
  CredflareSession? session;
  Map<String, dynamic>? info;
  Object? error;
  bool loading = false;
  bool _disposed = false;
  Future<Map<String, dynamic>>? _pending;

  CredflareSessionController({required this.provider});

  Future<Map<String, dynamic>> load() {
    if (_pending != null) return _pending!;
    final result = Completer<Map<String, dynamic>>();
    _pending = result.future;
    _load().then(result.complete, onError: result.completeError);
    return result.future;
  }

  Future<Map<String, dynamic>> _load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final descriptor = await provider();
      if (_disposed) throw StateError('Session controller has been disposed.');
      if (session == null) {
        session = CredflareSession(descriptor);
      } else {
        session!.replaceSession(descriptor);
      }
      final metadata = await session!.get();
      if (_disposed) throw StateError('Session controller has been disposed.');
      info = metadata;
      return metadata;
    } catch (failure) {
      error = failure;
      rethrow;
    } finally {
      loading = false;
      _pending = null;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    session?.close();
    super.dispose();
  }
}
