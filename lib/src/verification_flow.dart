import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'capture_plan.dart';
import 'client.dart';
import 'document_capture.dart';
import 'theme.dart';

typedef SessionProvider = Future<SessionDescriptor> Function();

class CredflareVerification extends StatefulWidget {
  final SessionProvider sessionProvider;
  final VoidCallback onClose;
  final void Function(Map<String, dynamic> session)? onSubmitted;
  final VoidCallback? onCancelled;
  final bool autoStart;
  final http.Client? httpClient;
  const CredflareVerification({
    super.key,
    required this.sessionProvider,
    required this.onClose,
    this.onSubmitted,
    this.onCancelled,
    this.autoStart = false,
    this.httpClient,
  });
  @override
  State<CredflareVerification> createState() => _VerificationState();
}

class DocumentSection {
  final String label;
  final List<Map<String, dynamic>> items;
  const DocumentSection(this.label, this.items);
}

List<DocumentSection> documentSections(List<Map<String, dynamic>> docs) {
  final required = docs.where((doc) => doc['rule'] != 'any_of').toList();
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final doc in docs.where((doc) => doc['rule'] == 'any_of')) {
    final key =
        doc['group_key'] as String? ?? 'doc-${doc['document_type']['id']}';
    groups.putIfAbsent(key, () => []).add(doc);
  }
  return [
    if (required.isNotEmpty) DocumentSection('Required', required),
    for (final items in groups.values)
      DocumentSection(() {
        final count =
            items.first['remaining_required'] ??
            items.first['min_required'] ??
            1;
        return items.length == 1
            ? 'Required'
            : count == 1
            ? 'Provide one of these'
            : 'Provide $count of these';
      }(), items),
  ];
}

class _VerificationState extends State<CredflareVerification> {
  CredflareSession? _session;
  Map<String, dynamic>? _info;
  Map<String, dynamic>? _document;
  bool _loading = false;
  bool _captureBusy = false;
  bool _captureDirty = false;
  bool _pendingReceipt = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) _start();
  }

  @override
  void dispose() {
    _session?.close();
    super.dispose();
  }

  String _errorMessage(Object error, String fallback) {
    if (error is CredflareException && error.status == 401) {
      return 'Your session has expired. Close this screen and start again.';
    }
    if (error is CredflareException && error.status != 0) return error.message;
    return fallback;
  }

  Future<void> _start() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    CredflareSession? next;
    try {
      next = CredflareSession(
        await widget.sessionProvider(),
        client: widget.httpClient,
      );
      final info = await next.get();
      if (!mounted) {
        next.close();
        return;
      }
      _session?.close();
      setState(() {
        _session = next;
        _info = info;
        _document = null;
      });
    } catch (error) {
      next?.close();
      if (mounted) {
        setState(() {
          _error = _errorMessage(
            error,
            'We could not start. Check your connection and try again.',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _refresh([int? id]) async {
    if (_loading) return;
    setState(() {
      _document = null;
      _captureDirty = false;
      _pendingReceipt = true;
      _loading = true;
      _error = null;
    });
    try {
      final info = await _session!.get();
      if (!mounted) return;
      setState(() {
        _info = info;
        _pendingReceipt = false;
      });
      final profile = info['profile'] as Map?;
      if ((profile?['document_requirements'] as List? ?? []).isEmpty &&
          (profile?['form_schema'] as List? ?? []).isEmpty &&
          (profile?['verification_requirements'] as List? ?? []).isEmpty) {
        widget.onSubmitted?.call(info);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _errorMessage(
            error,
            'We could not check what is still needed. Try again.',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String stay,
    required String leave,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CredflareTheme.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(stay),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(leave),
              ),
            ],
          ),
        ),
      ),
    );
    return result == true && mounted;
  }

  Future<void> _leave() async {
    if (_loading || _captureBusy) return;
    if (await _confirm(
      title: 'Leave for now?',
      body:
          'Documents you already sent are kept. You can come back through the app that asked for them.',
      stay: 'Keep going',
      leave: 'Leave for now',
    )) {
      widget.onCancelled?.call();
      widget.onClose();
    }
  }

  Future<void> _leaveDocument() async {
    if (!_captureDirty ||
        await _confirm(
          title: 'Discard these photos and files?',
          body: 'You have not sent this document yet.',
          stay: 'Keep editing',
          leave: 'Discard',
        )) {
      setState(() {
        _document = null;
        _captureDirty = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: CredflareTheme.data(Theme.of(context).brightness),
    child: Builder(builder: _page),
  );

  Widget _title(ThemeData theme, String text) => Semantics(
    header: true,
    child: Text(text, style: theme.textTheme.headlineSmall),
  );

  Widget _muted(ThemeData theme, String text) => Text(
    text,
    style: theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );

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

  Widget _glyph(ThemeData theme, IconData icon) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 20),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Icon(icon, size: 56, color: theme.colorScheme.primary),
    ),
  );

  Widget _card(ThemeData theme, Map<String, dynamic> doc, String verifier) {
    final supported = isCaptureSupported(doc);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          foregroundColor: theme.colorScheme.onSurface,
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        onPressed: supported
            ? () => setState(() {
                _document = doc;
                _error = null;
              })
            : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc['document_type']['name'] as String,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    supported
                        ? methodSummary(doc)
                        : 'Not available in this app. Contact $verifier.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (supported)
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(ThemeData theme) {
    final profile = _info?['profile'] as Map?;
    final docs = (profile?['document_requirements'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final otherSteps =
        (profile?['form_schema'] as List? ?? []).isNotEmpty ||
        (profile?['verification_requirements'] as List? ?? []).isNotEmpty;
    final requester = (_info?['requester'] as Map?)?['name'] as String?;
    final verifier = requester ?? 'your verifier';
    final message = _info?['custom_message'] as String?;
    if (_loading) {
      return [
        const SizedBox(height: 64),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 20),
        Semantics(
          liveRegion: true,
          child: Text(
            _info == null ? 'Getting ready…' : 'Checking what is still needed…',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ];
    }
    if (_info == null) {
      return [
        _glyph(theme, Icons.description_outlined),
        _title(theme, 'Share your documents'),
        const SizedBox(height: 8),
        _muted(
          theme,
          'Choose a document, add each requested side, then review before sending.',
        ),
        if (_error != null) _notice(theme),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _start,
          child: Text(_error == null ? 'Start' : 'Try again'),
        ),
      ];
    }
    if (_pendingReceipt) {
      return [
        _title(theme, 'Your document was sent'),
        if (_error != null) _notice(theme),
        const SizedBox(height: 24),
        FilledButton(onPressed: _refresh, child: const Text('Check again')),
      ];
    }
    if (docs.isEmpty && !otherSteps) {
      return [
        _glyph(theme, Icons.inbox_outlined),
        _title(theme, 'Documents received'),
        const SizedBox(height: 8),
        _muted(
          theme,
          '${requester ?? 'Your verifier'} will review what you sent. You can close this screen.',
        ),
        const SizedBox(height: 32),
        FilledButton(onPressed: widget.onClose, child: const Text('Done')),
      ];
    }
    if (_document != null) {
      final limits = _info!['upload_limits'] as Map;
      return [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: _captureBusy ? null : _leaveDocument,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Documents'),
          ),
        ),
        CredflareDocumentCapture(
          key: ValueKey(_document!['document_type']['id']),
          session: _session!,
          requirement: _document!,
          requesterName: requester,
          maxFileSizeBytes: limits['max_file_size_bytes'] as int,
          allowedFileTypes: (limits['allowed_file_types'] as List)
              .cast<String>(),
          onSubmitted: _refresh,
          onBusyChanged: (busy) {
            if (mounted) setState(() => _captureBusy = busy);
          },
          onDirtyChanged: (dirty) => _captureDirty = dirty,
        ),
      ];
    }
    if (docs.isEmpty) {
      return [
        const SizedBox(height: 16),
        _title(theme, 'Documents received'),
        const SizedBox(height: 8),
        _muted(
          theme,
          '${requester != null ? "$requester's app" : 'The app'} will guide you through the remaining steps.',
        ),
        if (_error != null) _notice(theme),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: widget.onClose,
          child: const Text('Return to app'),
        ),
      ];
    }
    return [
      _title(theme, 'Documents requested'),
      const SizedBox(height: 8),
      _muted(theme, 'Requested by $verifier.'),
      if (message != null && message.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(CredflareTheme.radius),
          ),
          child: Text(message),
        ),
      ],
      if (_error != null) _notice(theme),
      for (final section in documentSections(docs)) ...[
        const SizedBox(height: 24),
        Text(
          section.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        for (final doc in section.items) _card(theme, doc, verifier),
      ],
    ];
  }

  Widget _page(BuildContext context) {
    final theme = Theme.of(context);
    final profile = _info?['profile'] as Map?;
    final allReceived =
        _info != null &&
        !_pendingReceipt &&
        (profile?['document_requirements'] as List? ?? []).isEmpty &&
        (profile?['form_schema'] as List? ?? []).isEmpty &&
        (profile?['verification_requirements'] as List? ?? []).isEmpty;
    final requester = _info?['requester'] as Map?;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: CredflareTheme.gutter,
        title: CredflareVerifierBar(
          name: requester?['name'] as String?,
          logoUrl: requester?['logo_url'] as String?,
          sandbox: _info?['environment'] == 'sandbox',
        ),
        actions: [
          TextButton(
            onPressed: _loading || _captureBusy
                ? null
                : allReceived
                ? widget.onClose
                : _leave,
            child: const Text('Close'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            CredflareTheme.gutter,
            8,
            CredflareTheme.gutter,
            CredflareTheme.gutter,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [..._body(theme), const CredflareSecuredBy()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
