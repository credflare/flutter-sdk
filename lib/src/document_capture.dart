import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart' as files;
import 'capture_plan.dart';
import 'client.dart';
import 'theme.dart';

class CredflareDocumentCapture extends StatefulWidget {
  final CredflareSession session;
  final Map<String, dynamic> requirement;
  final int maxFileSizeBytes;
  final List<String> allowedFileTypes;
  final void Function(int submissionId) onSubmitted;
  final void Function(bool busy)? onBusyChanged;
  final void Function(bool dirty)? onDirtyChanged;
  final String? requesterName;
  const CredflareDocumentCapture({
    super.key,
    required this.session,
    required this.requirement,
    required this.maxFileSizeBytes,
    required this.allowedFileTypes,
    required this.onSubmitted,
    this.onBusyChanged,
    this.onDirtyChanged,
    this.requesterName,
  });
  @override
  State<CredflareDocumentCapture> createState() => _DocumentCaptureState();
}

class _Capture {
  final Uint8List bytes;
  final String name;
  final String source;
  final String key = requestKey();
  int? fileId;
  _Capture(this.bytes, this.name, this.source);
  bool get isImage => [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
  ].contains(name.split('.').last.toLowerCase());
}

class _DocumentCaptureState extends State<CredflareDocumentCapture> {
  final _captures = <String, _Capture>{};
  int _index = 0;
  bool _editing = false;
  bool _busy = false;
  String? _sending;
  String? _error;
  String _submitKey = requestKey();
  List<CaptureStep> get _steps => captureSteps(widget.requirement);
  Map get _document => widget.requirement['document_type'] as Map;

  void _setBusy(bool value) {
    if (!mounted) return;
    setState(() {
      _busy = value;
    });
    widget.onBusyChanged?.call(value);
  }

  Future<void> _pick(CaptureStep step, String source) async {
    if (_busy) return;
    _setBusy(true);
    setState(() {
      _error = null;
    });
    try {
      files.XFile? selected;
      if (source == 'camera') {
        selected = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 95,
          requestFullMetadata: false,
        );
      } else {
        final types = widget.allowedFileTypes;
        selected = await files.openFile(
          acceptedTypeGroups: [
            files.XTypeGroup(
              label: 'Requested document',
              extensions: types,
              mimeTypes: [
                if (types.any(
                  (e) => ['jpg', 'png', 'webp', 'heic'].contains(e),
                ))
                  'image/*',
                if (types.contains('pdf')) 'application/pdf',
                if (types.contains('docx'))
                  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
              ],
              uniformTypeIdentifiers: [
                if (types.any(
                  (e) => ['jpg', 'png', 'webp', 'heic'].contains(e),
                ))
                  'public.image',
                if (types.contains('pdf')) 'com.adobe.pdf',
                if (types.contains('docx'))
                  'org.openxmlformats.wordprocessingml.document',
              ],
            ),
          ],
        );
      }
      if (selected == null) return;
      final extension = selected.name.split('.').last.toLowerCase();
      if (!widget.allowedFileTypes.contains(
        extension == 'jpeg' ? 'jpg' : extension,
      )) {
        throw StateError(
          'Choose a ${widget.allowedFileTypes.join(', ').toUpperCase()} file.',
        );
      }
      final length = await selected.length();
      if (length > widget.maxFileSizeBytes) {
        throw StateError(
          'This file is larger than ${formatSize(widget.maxFileSizeBytes)}. Choose a smaller file.',
        );
      }
      final bytes = await selected.readAsBytes();
      if (!mounted) return;
      setState(() {
        _captures[step.id] = _Capture(bytes, selected!.name, source);
        _submitKey = requestKey();
      });
      widget.onDirtyChanged?.call(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is PlatformException
              ? [
                      'camera_access_denied',
                      'camera_access_restricted',
                      'photo_access_denied',
                    ].contains(error.code)
                    ? 'Camera or photo access is off. Turn it on in Settings, then try again.'
                    : 'The camera or file picker is unavailable. Try again on another device.'
              : error is StateError
              ? error.message
              : 'Could not add this file. Try again.';
        });
      }
    } finally {
      _setBusy(false);
    }
  }

  void _next() => setState(() {
    _index = _editing ? _steps.length : _index + 1;
    _editing = false;
    _error = null;
  });

  Future<void> _send() async {
    if (_busy) return;
    _setBusy(true);
    setState(() {
      _error = null;
    });
    try {
      final evidence = <Map<String, dynamic>>[];
      final pending = _steps
          .where((step) => _captures[step.id]!.fileId == null)
          .length;
      var done = 0;
      for (final step in _steps) {
        final file = _captures[step.id]!;
        if (file.fileId == null) {
          done++;
          setState(() {
            _sending = pending > 1
                ? 'Uploading $done of $pending'
                : 'Uploading';
          });
          file.fileId =
              (await widget.session.upload(
                    bytes: file.bytes,
                    filename: file.name,
                    key: file.key,
                    documentTypeId: _document['id'] as int,
                    side: step.side,
                    source: file.source,
                  ))['id']
                  as int;
        }
        evidence.add({
          'file_id': file.fileId,
          'side': step.side,
          'source': file.source,
        });
      }
      setState(() {
        _sending = 'Sending';
      });
      final id = await widget.session.submit({
        'type': 'document_verification',
        'document_type_id': _document['id'],
        'evidence': evidence,
      }, key: _submitKey);
      if (mounted) widget.onSubmitted(id);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is CredflareException && error.status != 0
              ? error.message
              : 'Could not send this document. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = null;
        });
      }
      _setBusy(false);
    }
  }

  Widget _preview(_Capture file, String label, {double height = 230}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(CredflareTheme.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: file.isImage
          ? Image.memory(
              file.bytes,
              fit: BoxFit.contain,
              semanticLabel: '$label preview',
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 40,
                  color: colors.primary,
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    file.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _notice(ThemeData theme) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.error),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
      ),
    ),
  );

  String _instruction(List<CaptureStep> steps, CaptureStep step) {
    if (step.source == 'camera') {
      return 'Place the document on a flat surface. Keep all four corners visible and avoid reflections.';
    }
    if (step.source == 'either') {
      return 'Take a photo or choose a saved file of the ${step.side}.';
    }
    final kind = widget.allowedFileTypes.contains('pdf')
        ? 'photo, scan or PDF'
        : 'photo or scan';
    final firstUpload =
        capturePolicy(widget.requirement) == 'snapshot_and_upload' &&
        steps.indexWhere((item) => item.source == 'upload') == _index;
    return 'Choose a clear $kind of the ${step.side}.${firstUpload ? ' ${widget.requesterName ?? 'Your verifier'} also needs a saved file of each side.' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    List<CaptureStep> steps;
    try {
      steps = _steps;
    } on UnsupportedError {
      return Text(
        'This document cannot be collected in this app. Contact ${widget.requesterName ?? 'your verifier'}.',
      );
    }
    final total = steps.length + 1;
    final reviewing = _index >= steps.length;
    final position = reviewing ? total : _index + 1;
    final step = reviewing ? null : steps[_index];
    final selected = step == null ? null : _captures[step.id];
    final canUpload = step != null && step.source != 'camera';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _document['name'] as String,
          style: theme.textTheme.bodySmall?.copyWith(
            color: muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          header: true,
          child: Text(
            reviewing ? 'Review before sending' : step!.label,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        if (!reviewing) ...[
          const SizedBox(height: 2),
          Text(
            step!.sourceLabel,
            style: theme.textTheme.bodyLarge?.copyWith(color: muted),
          ),
        ],
        const SizedBox(height: 16),
        Semantics(
          label: 'Step $position of $total',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: position / total,
              minHeight: 4,
              backgroundColor: theme.colorScheme.primaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: Text(
            'Step $position of $total',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
        const SizedBox(height: 20),
        if (!reviewing && selected != null) ...[
          _preview(selected, step!.label),
          const SizedBox(height: 12),
          Text(
            'Check that all four corners are visible, the text is sharp and there is no glare.',
            style: theme.textTheme.bodyLarge?.copyWith(color: muted),
          ),
          if (selected.source == 'upload') ...[
            const SizedBox(height: 4),
            Text(
              selected.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
          if (_error != null) _notice(theme),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: _busy ? null : () => _pick(step, selected.source),
                child: Text(
                  selected.source == 'camera' ? 'Retake photo' : 'Change file',
                ),
              ),
              if (step.source == 'either')
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _pick(
                          step,
                          selected.source == 'camera' ? 'upload' : 'camera',
                        ),
                  child: Text(
                    selected.source == 'camera'
                        ? 'Use a file instead'
                        : 'Take a photo instead',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _next,
            child: Text(
              _editing || _index + 1 == steps.length ? 'Review' : 'Continue',
            ),
          ),
        ] else if (!reviewing) ...[
          Text(_instruction(steps, step!), style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          CredflareSideGuide(side: step.side),
          if (_error != null) _notice(theme),
          const SizedBox(height: 24),
          if (step.source != 'upload')
            FilledButton(
              onPressed: _busy ? null : () => _pick(step, 'camera'),
              child: const Text('Take photo'),
            ),
          if (step.source == 'either') const SizedBox(height: 12),
          if (step.source == 'upload')
            FilledButton(
              onPressed: _busy ? null : () => _pick(step, 'upload'),
              child: const Text('Choose a file'),
            ),
          if (step.source == 'either')
            OutlinedButton(
              onPressed: _busy ? null : () => _pick(step, 'upload'),
              child: const Text('Choose a file'),
            ),
          if (canUpload) ...[
            const SizedBox(height: 12),
            Text(
              '${widget.allowedFileTypes.join(', ').toUpperCase()}, up to ${formatSize(widget.maxFileSizeBytes)}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ] else ...[
          Text(
            'Check each photo and file before you send them.',
            style: theme.textTheme.bodyLarge?.copyWith(color: muted),
          ),
          const SizedBox(height: 16),
          for (final entry in steps) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${entry.label} · ${_captures[entry.id]!.source == 'camera' ? 'Camera photo' : 'Saved file'}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _index = steps.indexOf(entry);
                          _editing = true;
                          _error = null;
                        }),
                  child: const Text('Change'),
                ),
              ],
            ),
            _preview(_captures[entry.id]!, entry.label, height: 150),
            const SizedBox(height: 16),
          ],
          if (_error != null) _notice(theme),
          if (_sending != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                '$_sending…',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _send,
            child: _busy
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('Send document'),
                    ],
                  )
                : const Text('Send document'),
          ),
        ],
      ],
    );
  }
}

String formatSize(int bytes) {
  final value = (bytes / 1048576).toStringAsFixed(1);
  return '${value.endsWith('.0') ? value.substring(0, value.length - 2) : value} MB';
}
