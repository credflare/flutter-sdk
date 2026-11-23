import 'dart:async';
import 'package:flutter/material.dart';
import 'client.dart';
import 'copy.dart';
import 'location_source.dart';
import 'rejection.dart';
import 'requirements.dart';
import 'spec.generated.dart';
import 'theme.dart';
import 'ui.dart';

enum _Phase { consent, locating, found, sending }

class CredflareLocationCapture extends StatefulWidget {
  final CredflareSession session;
  final Map<String, dynamic> info;
  final LocationRequirementSettings settings;
  final LocationSource source;
  final VoidCallback onSubmitted;
  final ValueChanged<bool> onBusyChanged;
  final DateTime Function() now;

  /// Called instead of reporting an error when the submission is refused
  /// because the case closed, so nothing was recorded.
  final VoidCallback? onClosed;
  const CredflareLocationCapture({
    super.key,
    required this.session,
    required this.info,
    required this.settings,
    required this.source,
    required this.onSubmitted,
    required this.onBusyChanged,
    this.now = DateTime.now,
    this.onClosed,
  });
  @override
  State<CredflareLocationCapture> createState() => _LocationState();
}

class _LocationState extends State<CredflareLocationCapture> {
  _Phase _phase = _Phase.consent;
  LocationFix? _fix;
  String? _error;
  Rejection? _rejected;
  String? _progress;
  int _failures = 0;
  String _submitKey = requestKey();

  String get _verifier => verifierName(widget.info);

  bool _fresh(LocationFix fix) =>
      widget.now().difference(fix.fixTime).inSeconds <= widget.settings.maxAgeS;

  bool _accurate(LocationFix fix) =>
      fix.accuracy != null && fix.accuracy! <= widget.settings.maxAccuracyM;

  void _failed(String key) {
    _failures += 1;
    setState(() {
      _phase = _Phase.consent;
      _progress = null;
      _error =
          _failures >= SpecLocation.retryAttempts &&
              key != SpecCopyKey.locationPermissionDenied &&
              key != SpecCopyKey.locationMockDetected
          ? copy(SpecCopyKey.locationRetriesExhausted, {'verifier': _verifier})
          : copy(key);
    });
  }

  Future<void> _locate() async {
    if (_phase == _Phase.locating || _phase == _Phase.sending) return;
    setState(() {
      _phase = _Phase.locating;
      _rejected = null;
      _error = null;
      _progress = copy(SpecCopyKey.locationWaiting);
    });
    final LocationAccess access;
    try {
      access = await widget.source.requestAccess();
    } catch (_) {
      if (mounted) _failed(SpecCopyKey.locationUnavailable);
      return;
    }
    if (!mounted) return;
    if (access != LocationAccess.granted) {
      _failed(
        access == LocationAccess.denied
            ? SpecCopyKey.locationPermissionDenied
            : SpecCopyKey.locationUnavailable,
      );
      return;
    }
    var problem = SpecCopyKey.locationTimeout;
    for (var attempt = 0; attempt < SpecLocation.retryAttempts; attempt++) {
      LocationFix fix;
      try {
        fix = await widget.source.currentFix(
          const Duration(seconds: SpecLocation.fixTimeoutS),
        );
      } on LocationUnavailable {
        if (mounted) _failed(SpecCopyKey.locationUnavailable);
        return;
      } catch (_) {
        problem = SpecCopyKey.locationTimeout;
        continue;
      }
      if (!mounted) return;
      if (fix.isMock == true && widget.settings.mockLocation == 'reject') {
        _failed(SpecCopyKey.locationMockDetected);
        return;
      }
      if (_accurate(fix) && _fresh(fix)) {
        _submitKey = requestKey();
        setState(() {
          _fix = fix;
          _phase = _Phase.found;
          _progress = null;
        });
        return;
      }
      problem = widget.settings.reference != null
          ? SpecCopyKey.locationPlaceNotPrecise
          : SpecCopyKey.locationLowAccuracy;
      setState(() => _progress = copy(SpecCopyKey.locationWaitingAccuracy));
    }
    if (mounted) _failed(problem);
  }

  Future<void> _send() async {
    final fix = _fix!;
    if (!_fresh(fix)) {
      setState(() => _phase = _Phase.consent);
      await _locate();
      return;
    }
    setState(() {
      _phase = _Phase.sending;
      _error = null;
    });
    widget.onBusyChanged(true);
    try {
      await widget.session.submitLocation(fix, key: _submitKey);
      widget.onBusyChanged(false);
      widget.onSubmitted();
    } catch (error) {
      widget.onBusyChanged(false);
      if (error is CredflareException &&
          error.status == 409 &&
          widget.onClosed != null) {
        widget.onClosed!();
        return;
      }
      if (!mounted) return;
      final rejected = error is CredflareException && error.status == 422;
      setState(() {
        _phase = rejected ? _Phase.consent : _Phase.found;
        _rejected = rejected
            ? Rejection.from(
                error,
                info: widget.info,
                reference: widget.settings.reference,
              )
            : null;
        _error = rejected ? null : _sendError(error);
      });
    }
  }

  String _sendError(Object error) =>
      error is CredflareException && error.status != 0
      ? error.message
      : copy(SpecCopyKey.errorsSendLocationFailed);

  String _title() {
    final reference = widget.settings.reference;
    if (reference == null || reference.labels.length != 1) {
      return copy(SpecCopyKey.locationTitle);
    }
    return copy(
      reference.rule == 'outside'
          ? SpecCopyKey.locationPlaceTitleOutside
          : SpecCopyKey.locationPlaceTitleWithin,
      {'place': reference.labels.single},
    );
  }

  String? _need() {
    final reference = widget.settings.reference;
    if (reference == null || reference.labels.length < 2) return null;
    final outside = reference.rule == 'outside';
    final all = reference.match == 'all';
    final key = outside
        ? (all
              ? SpecCopyKey.locationPlaceNeedOutsideAll
              : SpecCopyKey.locationPlaceNeedOutsideAny)
        : (all
              ? SpecCopyKey.locationPlaceNeedWithinAll
              : SpecCopyKey.locationPlaceNeedWithinAny);
    return copy(key, {
      'place': reference.labels.first,
      'places': reference.labels.join(', '),
    });
  }

  List<Widget> _consent(ThemeData theme) {
    if (_rejected case final rejected?) {
      return [CredflareRejection(rejection: rejected, onAction: _locate)];
    }
    final need = _need();
    return [
      const CredflareGlyph(SpecIcons.location),
      CredflareTitle(_title()),
      if (need != null) ...[
        const SizedBox(height: 8),
        CredflareBody(need, color: theme.colorScheme.onSurface),
      ],
      const SizedBox(height: 8),
      CredflareBody(copy(SpecCopyKey.locationWhy, {'verifier': _verifier})),
      const SizedBox(height: 8),
      CredflareBody(copy(SpecCopyKey.locationWhatShared), small: true),
      const SizedBox(height: 4),
      CredflareBody(copy(SpecCopyKey.locationPermissionPrompt), small: true),
      if (_error != null) CredflareNotice(_error!),
      const SizedBox(height: 24),
      if (_phase == _Phase.locating) ...[
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: CredflareBody(_progress ?? copy(SpecCopyKey.locationWaiting)),
        ),
      ] else
        FilledButton(
          onPressed: _locate,
          child: Text(
            copy(
              _error == null
                  ? SpecCopyKey.locationShare
                  : SpecCopyKey.locationRetry,
            ),
          ),
        ),
    ];
  }

  Widget _row(ThemeData theme, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
      ],
    ),
  );

  List<Widget> _found(ThemeData theme) {
    final fix = _fix!;
    final time = TimeOfDay.fromDateTime(fix.fixTime.toLocal());
    return [
      const CredflareGlyph(SpecIcons.location),
      CredflareTitle(copy(SpecCopyKey.locationFoundTitle)),
      const SizedBox(height: 8),
      CredflareBody(copy(SpecCopyKey.locationFoundBody)),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(CredflareTheme.radius),
        ),
        child: Column(
          children: [
            _row(
              theme,
              copy(SpecCopyKey.locationAccuracyLabel),
              copy(SpecCopyKey.locationAccuracyValue, {
                'meters': fix.accuracy!.round(),
              }),
            ),
            _row(
              theme,
              copy(SpecCopyKey.locationCoordinatesLabel),
              '${fix.latitude.toStringAsFixed(5)}, ${fix.longitude.toStringAsFixed(5)}',
            ),
            _row(
              theme,
              copy(SpecCopyKey.locationTimeLabel),
              MaterialLocalizations.of(context).formatTimeOfDay(time),
            ),
          ],
        ),
      ),
      if (_error != null) CredflareNotice(_error!),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _phase == _Phase.found ? _send : null,
        child: Text(
          copy(
            _phase == _Phase.sending
                ? SpecCopyKey.sendingSending
                : SpecCopyKey.locationSend,
          ),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _phase == _Phase.found
            ? () => setState(() {
                _phase = _Phase.consent;
                _locate();
              })
            : null,
        child: Text(copy(SpecCopyKey.locationRetry)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _phase == _Phase.found || _phase == _Phase.sending
          ? _found(theme)
          : _consent(theme),
    );
  }
}
