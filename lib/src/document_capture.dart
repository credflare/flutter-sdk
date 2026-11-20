import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'client.dart';

class CredflareDocumentCapture extends StatefulWidget {
  final CredflareSession session;
  final Map<String, dynamic> requirement;
  final int maxFileSizeBytes;
  final List<String> allowedFileTypes;
  final void Function(int submissionId) onSubmitted;
  const CredflareDocumentCapture({
    super.key,
    required this.session,
    required this.requirement,
    required this.maxFileSizeBytes,
    required this.allowedFileTypes,
    required this.onSubmitted,
  });

  @override
  State<CredflareDocumentCapture> createState() => _DocumentCaptureState();
}

class _Capture {
  final Uint8List bytes;
  final String name;
  final String key = requestKey();
  int? fileId;
  _Capture(this.bytes, this.name);
}

class _DocumentCaptureState extends State<CredflareDocumentCapture> {
  final _images = <String, _Capture>{};
  bool _busy = false;
  String? _error;
  String _submitKey = requestKey();

  Map get _document => widget.requirement['document_type'] as Map;
  String get _policy =>
      widget.requirement['capture_method'] as String? ??
      (_document['capture_method'] == 'camera' ? 'either' : 'upload');
  List<String> get _sides =>
      (widget.requirement['requested_sides'] as List?)?.cast<String>() ??
      (_document['two_sided'] == true ? ['front', 'back'] : ['front']);

  Future<void> _capture(String side, ImageSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 95,
        requestFullMetadata: false,
      );
      if (image == null) return;
      final extension = image.name.split('.').last.toLowerCase();
      if (!widget.allowedFileTypes.contains(
        extension == 'jpeg' ? 'jpg' : extension,
      )) {
        throw StateError('This image type is not allowed by the workspace.');
      }
      final bytes = await image.readAsBytes();
      if (bytes.length > widget.maxFileSizeBytes) {
        throw StateError('This image exceeds the workspace upload limit.');
      }
      if (!mounted) return;
      setState(() {
        _images[side] = _Capture(bytes, image.name);
        _submitKey = requestKey();
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      for (final side in _sides) {
        final image = _images[side]!;
        image.fileId ??=
            (await widget.session.upload(
                  bytes: image.bytes,
                  filename: image.name,
                  key: image.key,
                  side: side,
                ))['id']
                as int;
      }
      final id = await widget.session.submit({
        'type': 'document_verification',
        'document_type_id': _document['id'],
        'file_id': _images['front']?.fileId ?? _images[_sides.first]!.fileId,
        if (_sides.contains('back') && _sides.length > 1)
          'back_file_id': _images['back']!.fileId,
      }, key: _submitKey);
      if (mounted) widget.onSubmitted(id);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!['upload', 'either'].contains(_policy)) {
      return const Text(
        'This requirement needs trusted capture, which is not available in this SDK yet.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _document['name'] as String,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final side in _sides) ...[
          Text('Document $side'),
          if (_images[side] != null)
            Image.memory(
              _images[side]!.bytes,
              height: 160,
              semanticLabel: 'Selected $side image',
            ),
          Wrap(
            spacing: 8,
            children: [
              if (_policy == 'either')
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _capture(side, ImageSource.camera),
                  child: const Text('Take photo'),
                ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _capture(side, ImageSource.gallery),
                child: Text(
                  _images[side] == null ? 'Choose image' : 'Replace image',
                ),
              ),
            ],
          ),
        ],
        if (_error != null) Text(_error!),
        FilledButton(
          onPressed: !_busy && _sides.every(_images.containsKey)
              ? _submit
              : null,
          child: Text(_busy ? 'Sending document…' : 'Submit document'),
        ),
      ],
    );
  }
}
