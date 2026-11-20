import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'client.dart';

bool requiresSelfie(Map<String, dynamic> info) =>
    ((info['profile'] as Map?)?['verification_requirements'] as List? ?? [])
        .any((item) => item['verification_type'] == 'facial_verification');

class CredflareSelfieCapture extends StatefulWidget {
  final CredflareSession session;
  final Map<String, dynamic> info;
  final VoidCallback onSubmitted;
  final ValueChanged<bool> onBusyChanged;
  final ValueChanged<bool> onDirtyChanged;
  const CredflareSelfieCapture({
    super.key,
    required this.session,
    required this.info,
    required this.onSubmitted,
    required this.onBusyChanged,
    required this.onDirtyChanged,
  });
  @override
  State<CredflareSelfieCapture> createState() => _SelfieState();
}

class _SelfieState extends State<CredflareSelfieCapture> {
  Uint8List? _bytes;
  String? _name;
  int? _fileId;
  String _uploadKey = requestKey(), _submitKey = requestKey();
  bool _busy = false;
  String? _error;
  List<String> get _types =>
      ((widget.info['upload_limits'] as Map)['allowed_file_types'] as List)
          .cast<String>()
          .where(['jpg', 'png', 'webp'].contains)
          .toList();
  void _working(bool value) {
    if (!mounted) return;
    setState(() => _busy = value);
    widget.onBusyChanged(value);
  }

  Future<void> _capture() async {
    if (_busy) return;
    _working(true);
    setState(() => _error = null);
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (photo == null) return;
      final ext = photo.name
          .split('.')
          .last
          .toLowerCase()
          .replaceAll('jpeg', 'jpg');
      if (!_types.contains(ext)) {
        throw StateError('This photo format is not allowed by your verifier.');
      }
      final length = await photo.length();
      final limit =
          (widget.info['upload_limits'] as Map)['max_file_size_bytes'] as int;
      if (length == 0 || length > limit) {
        throw StateError('This photo is empty or too large. Retake it.');
      }
      final bytes = await photo.readAsBytes();
      if (bytes.isEmpty || bytes.length > limit) {
        throw StateError('This photo is empty or too large. Retake it.');
      }
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _name = photo.name;
        _fileId = null;
        _uploadKey = requestKey();
        _submitKey = requestKey();
      });
      widget.onDirtyChanged(true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PlatformException
              ? 'Camera access is unavailable. Check access in Settings and try again.'
              : error is StateError
              ? error.message
              : 'Could not take your selfie. Try again.',
        );
      }
    } finally {
      _working(false);
    }
  }

  Future<void> _send() async {
    if (_busy || _bytes == null) return;
    _working(true);
    setState(() => _error = null);
    try {
      _fileId ??=
          (await widget.session.upload(
                bytes: _bytes!,
                filename: _name!,
                key: _uploadKey,
                type: 'biometrics',
                source: 'camera',
              ))['id']
              as int;
      await widget.session.submit({
        'type': 'facial_verification',
        'image_file_id': _fileId,
      }, key: _submitKey);
      widget.onSubmitted();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is CredflareException && error.status != 0
              ? error.message
              : 'Could not send your selfie. Check your connection and try again.',
        );
      }
    } finally {
      _working(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requester =
        (widget.info['requester'] as Map?)?['name'] ?? 'your verifier';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            _bytes == null ? 'Take a selfie' : 'Review your selfie',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _bytes == null
              ? 'Face the camera in even lighting. Keep your whole face visible and remove anything covering it.'
              : 'Make sure your face is clear and fully visible before sharing.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (_bytes != null) ...[
          Image.memory(
            _bytes!,
            height: 280,
            cacheWidth: 1200,
            fit: BoxFit.contain,
            semanticLabel: 'Your selfie preview',
          ),
          TextButton(
            onPressed: _busy ? null : _capture,
            child: const Text('Retake selfie'),
          ),
          FilledButton(
            onPressed: _busy ? null : _send,
            child: Text(_busy ? 'Sending selfie…' : 'Send selfie'),
          ),
        ] else
          FilledButton(
            onPressed: _busy || _types.isEmpty ? null : _capture,
            child: const Text('Open front camera'),
          ),
        if (_types.isEmpty)
          const Text(
            'Your verifier has not enabled a supported selfie image format. Contact them to continue.',
          ),
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Your selfie will be sent to $requester for review.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
