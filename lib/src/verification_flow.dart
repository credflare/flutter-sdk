import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'capture_plan.dart';
import 'client.dart';
import 'contact_code_capture.dart';
import 'copy.dart';
import 'document_capture.dart';
import 'liveness_capture.dart';
import 'liveness_source.dart';
import 'location_capture.dart';
import 'location_source.dart';
import 'questionnaire.dart';
import 'requirements.dart';
import 'spec.generated.dart';
import 'spec_icon.dart';
import 'theme.dart';
import 'ui.dart';

typedef SessionProvider = Future<SessionDescriptor> Function();

class CredflareVerification extends StatefulWidget {
  final SessionProvider sessionProvider;
  final VoidCallback onClose;
  final void Function(Map<String, dynamic> session)? onSubmitted;
  final VoidCallback? onCancelled;
  final bool autoStart;
  final http.Client? httpClient;
  final LivenessSourceFactory livenessSource;
  final LocationSource locationSource;
  const CredflareVerification({
    super.key,
    required this.sessionProvider,
    required this.onClose,
    this.onSubmitted,
    this.onCancelled,
    this.autoStart = false,
    this.httpClient,
    this.livenessSource = CameraLivenessSource.new,
    this.locationSource = const GeolocatorLocationSource(),
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
    if (required.isNotEmpty)
      DocumentSection(copy(SpecCopyKey.documentsSectionRequired), required),
    for (final items in groups.values)
      DocumentSection(() {
        final count =
            items.first['remaining_required'] ??
            items.first['min_required'] ??
            1;
        return items.length == 1
            ? copy(SpecCopyKey.documentsSectionRequired)
            : count == 1
            ? copy(SpecCopyKey.documentsSectionOneOf)
            : copy(SpecCopyKey.documentsSectionCountOf, {'count': count});
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
  final _received = <String>[];
  final _answers = <String, Object?>{};

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

  String _errorMessage(Object error, String fallbackKey) {
    if (error is CredflareException && error.status == 401) {
      return copy(SpecCopyKey.errorsSessionExpired);
    }
    if (error is CredflareException && error.status != 0) return error.message;
    return copy(fallbackKey);
  }

  Map? get _profile => _info?['profile'] as Map?;

  bool get _allReceived =>
      _info != null &&
      _profile != null &&
      !_pendingReceipt &&
      !sessionOutstanding(_info!);

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
          _error = _errorMessage(error, SpecCopyKey.errorsStartFailed);
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

  Future<void> _refresh([String? received]) async {
    if (_loading) return;
    if (received != null) _received.add(received);
    setState(() {
      _document = null;
      _captureDirty = false;
      _captureBusy = false;
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
      if (_allReceived) widget.onSubmitted?.call(info);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is CredflareException && error.status == 401
              ? copy(SpecCopyKey.errorsSessionExpired)
              : copy(SpecCopyKey.errorsRefreshFailed);
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
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
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
      title: copy(SpecCopyKey.exitTitle),
      body: copy(SpecCopyKey.exitBody),
      stay: copy(SpecCopyKey.exitStay),
      leave: copy(SpecCopyKey.exitLeave),
    )) {
      widget.onCancelled?.call();
      widget.onClose();
    }
  }

  Future<void> _leaveDocument() async {
    if (!_captureDirty ||
        await _confirm(
          title: copy(SpecCopyKey.exitDiscardTitle),
          body: copy(SpecCopyKey.exitDiscardBody),
          stay: copy(SpecCopyKey.exitDiscardStay),
          leave: copy(SpecCopyKey.exitDiscardLeave),
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

  void _busy(bool busy) {
    if (mounted) setState(() => _captureBusy = busy);
  }

  List<Widget> _receivedItems(ThemeData theme) => [
    if (_received.isNotEmpty) const SizedBox(height: 20),
    for (final item in _received)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CredflareIcon(
              SpecIcons.received,
              size: 20,
              color: CredflareTheme.of(context)['success'],
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                item,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
  ];

  List<Widget> _receipt(
    ThemeData theme,
    String verifier, {
    bool hostSteps = false,
  }) => [
    const CredflareGlyph(SpecIcons.receivedIllustration, size: 64),
    CredflareTitle(copy(SpecCopyKey.receiptTitle)),
    const SizedBox(height: 8),
    CredflareBody(
      copy(hostSteps ? SpecCopyKey.receiptHostSteps : SpecCopyKey.receiptBody, {
        'verifier': verifier,
      }),
    ),
    ..._receivedItems(theme),
    if (_error != null) CredflareNotice(_error!),
    const SizedBox(height: 32),
    FilledButton(
      onPressed: widget.onClose,
      child: Text(
        copy(
          hostSteps ? SpecCopyKey.commonReturnToApp : SpecCopyKey.receiptDone,
        ),
      ),
    ),
  ];

  List<Widget> _body(ThemeData theme) {
    final profile = _profile;
    final docs = (profile?['document_requirements'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final pending = _info == null
        ? <VerificationRequirement>[]
        : verificationRequirements(_info!);
    final sdkStep = pending
        .where((item) => sdkVerificationTypes.contains(item.type))
        .firstOrNull;
    final questions = formQuestions(_info);
    final askQuestions = questions.isNotEmpty && canAskQuestions(questions);
    final hostSteps =
        profile == null ||
        (questions.isNotEmpty && !askQuestions) ||
        pending.any((item) => !sdkVerificationTypes.contains(item.type));
    final verifier = verifierName(_info);
    final message = _info?['custom_message'] as String?;
    if (_loading) {
      return [
        const SizedBox(height: 64),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 20),
        Semantics(
          liveRegion: true,
          child: CredflareBody(
            copy(
              _info == null
                  ? SpecCopyKey.commonLoading
                  : SpecCopyKey.introChecking,
            ),
          ),
        ),
      ];
    }
    if (_info == null) {
      return [
        const CredflareGlyph(SpecIcons.idCard),
        CredflareTitle(copy(SpecCopyKey.introTitle)),
        const SizedBox(height: 8),
        CredflareBody(copy(SpecCopyKey.introBody, {'verifier': verifier})),
        if (_error != null) CredflareNotice(_error!),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _start,
          child: Text(
            copy(
              _error == null
                  ? SpecCopyKey.introStart
                  : SpecCopyKey.commonTryAgain,
            ),
          ),
        ),
      ];
    }
    if (_pendingReceipt) {
      return [
        const CredflareGlyph(SpecIcons.upload),
        CredflareTitle(copy(SpecCopyKey.sendingSentTitle)),
        const SizedBox(height: 8),
        CredflareBody(copy(SpecCopyKey.sendingSentBody)),
        if (_error != null) CredflareNotice(_error!),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _refresh,
          child: Text(
            copy(
              _error == null
                  ? SpecCopyKey.sendingCheckAgain
                  : SpecCopyKey.commonTryAgain,
            ),
          ),
        ),
      ];
    }
    if (_allReceived) return _receipt(theme, verifier);
    if (_document != null) {
      final limits = _info!['upload_limits'] as Map;
      final name = _document!['document_type']['name'] as String;
      return [
        CredflareBackLink(
          label: copy(SpecCopyKey.documentsBack),
          onPressed: _captureBusy ? null : _leaveDocument,
        ),
        CredflareDocumentCapture(
          key: ValueKey(_document!['document_type']['id']),
          session: _session!,
          requirement: _document!,
          requesterName: verifier,
          maxFileSizeBytes: limits['max_file_size_bytes'] as int,
          allowedFileTypes: (limits['allowed_file_types'] as List)
              .cast<String>(),
          onSubmitted: (_) =>
              _refresh(copy(SpecCopyKey.receiptDocument, {'document': name})),
          onBusyChanged: _busy,
          onDirtyChanged: (dirty) => _captureDirty = dirty,
        ),
      ];
    }
    if (docs.isEmpty && askQuestions) {
      return [
        CredflareQuestionnaire(
          key: ValueKey(questions.map((q) => q['key']).join(',')),
          session: _session!,
          info: _info!,
          earlierAnswers: _answers,
          onSubmitted: (fields) {
            _answers.addAll(fields);
            _refresh(copy(SpecCopyKey.receiptAnswers));
          },
          onBusyChanged: _busy,
        ),
      ];
    }
    final channel = sdkStep == null
        ? null
        : ContactChannel.forType(sdkStep.type);
    if (docs.isEmpty && channel != null) {
      return [
        CredflareContactCodeCapture(
          key: ValueKey(channel),
          session: _session!,
          info: _info!,
          channel: channel,
          onSubmitted: () => _refresh(
            copy(
              channel == ContactChannel.email
                  ? SpecCopyKey.receiptEmail
                  : SpecCopyKey.receiptPhone,
            ),
          ),
          onLeave: () {
            widget.onCancelled?.call();
            widget.onClose();
          },
          onBusyChanged: _busy,
        ),
      ];
    }
    if (docs.isEmpty && sdkStep?.type == 'facial_verification') {
      return [
        CredflareLivenessCapture(
          session: _session!,
          info: _info!,
          settings: sdkStep!.facial,
          sourceFactory: widget.livenessSource,
          onSubmitted: () => _refresh(copy(SpecCopyKey.receiptSelfie)),
          onBusyChanged: _busy,
        ),
      ];
    }
    if (docs.isEmpty && sdkStep?.type == 'location_verification') {
      return [
        CredflareLocationCapture(
          session: _session!,
          info: _info!,
          settings: sdkStep!.location,
          source: widget.locationSource,
          onSubmitted: () => _refresh(copy(SpecCopyKey.receiptLocation)),
          onBusyChanged: _busy,
        ),
      ];
    }
    if (docs.isEmpty) return _receipt(theme, verifier, hostSteps: true);
    return [
      CredflareTitle(copy(SpecCopyKey.documentsTitle)),
      const SizedBox(height: 8),
      CredflareBody(
        copy(SpecCopyKey.documentsRequestedBy, {'verifier': verifier}),
      ),
      if (message != null && message.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(CredflareTheme.radius),
          ),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ],
      if (_error != null) CredflareNotice(_error!),
      for (final section in documentSections(docs)) ...[
        const SizedBox(height: 24),
        Text(
          section.label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        for (final doc in section.items) _card(doc, verifier),
      ],
      if (_nextSteps(pending, hostSteps, askQuestions) case final next?) ...[
        const SizedBox(height: 8),
        CredflareBody(copy(next), small: true),
      ],
    ];
  }

  String? _nextSteps(
    List<VerificationRequirement> pending,
    bool hostSteps,
    bool questions,
  ) {
    const capture = ['facial_verification', 'location_verification'];
    if (questions || pending.any((item) => !capture.contains(item.type))) {
      return SpecCopyKey.documentsHostStepsNext;
    }
    final order = <String>{for (final item in pending) item.type}.toList();
    return switch (order) {
      ['facial_verification'] => SpecCopyKey.documentsSelfieNext,
      ['location_verification'] => SpecCopyKey.documentsLocationNext,
      ['facial_verification', 'location_verification'] =>
        SpecCopyKey.documentsSelfieLocationNext,
      ['location_verification', 'facial_verification'] =>
        SpecCopyKey.documentsLocationSelfieNext,
      _ => hostSteps ? SpecCopyKey.documentsHostStepsNext : null,
    };
  }

  Widget _card(Map<String, dynamic> doc, String verifier) {
    final supported = isCaptureSupported(doc);
    final type = doc['document_type'] as Map;
    return CredflareCard(
      icon: type['two_sided'] == true ? SpecIcons.idCard : SpecIcons.document,
      title: type['name'] as String,
      subtitle: methodSummary(doc, verifier),
      onTap: supported
          ? () => setState(() {
              _document = doc;
              _error = null;
            })
          : null,
    );
  }

  Widget _page(BuildContext context) {
    final theme = Theme.of(context);
    final allReceived = _allReceived;
    final requester = _info?['requester'] as Map?;
    return PopScope(
      canPop: allReceived,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
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
              child: Text(copy(SpecCopyKey.commonClose)),
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
                constraints: const BoxConstraints(
                  maxWidth: CredflareTheme.maxContentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [..._body(theme), const CredflareSecuredBy()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
