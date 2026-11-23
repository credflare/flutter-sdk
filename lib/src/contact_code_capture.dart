import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'client.dart';
import 'copy.dart';
import 'rejection.dart';
import 'spec.generated.dart';
import 'ui.dart';

enum _Phase { destination, sending, code, confirming }

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final _phoneStrip = RegExp(SpecRequirements.contactCodesPhoneStrip);
final _phone = RegExp(SpecRequirements.contactCodesPhonePattern);
final _code = RegExp('^[0-9]{${SpecRequirements.contactCodesCodeLength}}\$');

/// Normalizes a phone number the way the server does, or returns null when it
/// is not in international format.
String? normalizePhone(String input) {
  if (input.trim().length > SpecRequirements.contactCodesPhoneMaxLength) {
    return null;
  }
  final stripped = input.replaceAll(_phoneStrip, '');
  return _phone.hasMatch(stripped) ? stripped : null;
}

bool isEmailAddress(String input) {
  final value = input.trim();
  return value.length <= SpecRequirements.contactCodesEmailMaxLength &&
      _email.hasMatch(value);
}

/// Confirms an email address or phone number with a code sent to it.
class CredflareContactCodeCapture extends StatefulWidget {
  final CredflareSession session;
  final Map<String, dynamic> info;
  final ContactChannel channel;
  final VoidCallback onSubmitted;
  final ValueChanged<String?> onLeave;
  final ValueChanged<bool> onBusyChanged;

  /// Called with the rejection code while a rejection that only lets the
  /// applicant leave is shown, and with null when it is gone.
  final ValueChanged<String?>? onLeaveCodeChanged;
  final DateTime Function() now;
  const CredflareContactCodeCapture({
    super.key,
    required this.session,
    required this.info,
    required this.channel,
    required this.onSubmitted,
    required this.onLeave,
    required this.onBusyChanged,
    this.onLeaveCodeChanged,
    this.now = DateTime.now,
  });
  @override
  State<CredflareContactCodeCapture> createState() => _ContactCodeState();
}

class _ContactCodeState extends State<CredflareContactCodeCapture> {
  final _destination = TextEditingController();
  final _codeField = TextEditingController();
  final _codeFocus = FocusNode();
  _Phase _phase = _Phase.destination;
  String? _shownDestination;
  int? _sendsRemaining;
  int _minutes = SpecRequirements.contactCodesTtlMinutes;
  (String, int?, int)? _previous;
  bool _changeAfter = false;
  DateTime? _resendAt;
  DateTime? _waitUntil;
  Rejection? _rejected;
  String? _error;
  String? _fieldError;
  Timer? _ticker;

  bool get _email => widget.channel == ContactChannel.email;

  @override
  void initState() {
    super.initState();
    _codeField.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _destination.dispose();
    _codeField.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  int _secondsUntil(DateTime? at) {
    if (at == null) return 0;
    final ms = at.difference(widget.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  void _tick() {
    _ticker?.cancel();
    if (_secondsUntil(_resendAt) == 0 && _secondsUntil(_waitUntil) == 0) {
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {});
      if (_secondsUntil(_resendAt) == 0 && _secondsUntil(_waitUntil) == 0) {
        timer.cancel();
      }
    });
  }

  void _busy(bool busy) => widget.onBusyChanged(busy);

  set _rejection(Rejection? rejection) {
    _rejected = rejection;
    widget.onLeaveCodeChanged?.call(
      rejection?.action == 'leave' ? rejection!.code : null,
    );
  }

  DateTime _serverTime(DateTime at) {
    const longest = Duration(
      seconds: SpecRequirements.contactCodesResendSeconds,
    );
    final now = widget.now();
    final wait = at.difference(now);
    return now.add(
      wait.isNegative
          ? Duration.zero
          : wait > longest
          ? longest
          : wait,
    );
  }

  void _focusCode() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _codeFocus.requestFocus();
  });

  Future<void> _send() async {
    final target = _validDestination();
    if (target == null) return;
    setState(() {
      _phase = _Phase.sending;
      _rejection = null;
      _error = null;
      _fieldError = null;
    });
    _busy(true);
    try {
      final sent = await widget.session.requestContactCode(
        widget.channel,
        target,
      );
      _busy(false);
      if (!mounted) return;
      _codeField.clear();
      setState(() {
        _shownDestination = sent.destination;
        _sendsRemaining = sent.sendsRemaining;
        _minutes =
            (sent.expiresAt.difference(sent.resendAvailableAt).inSeconds +
                SpecRequirements.contactCodesResendSeconds) ~/
            60;
        _resendAt = _serverTime(sent.resendAvailableAt);
        _waitUntil = null;
        _previous = null;
        _changeAfter = false;
        _phase = _Phase.code;
      });
      _tick();
      _focusCode();
    } catch (error) {
      _busy(false);
      if (!mounted) return;
      _failed(
        error,
        _shownDestination == null ? _Phase.destination : _Phase.code,
        SpecCopyKey.errorsSendCodeFailed,
        target: target,
      );
    }
  }

  Future<void> _confirm() async {
    final code = _codeField.text.trim();
    if (!_code.hasMatch(code)) return;
    setState(() {
      _phase = _Phase.confirming;
      _rejection = null;
      _error = null;
    });
    _busy(true);
    try {
      await widget.session.confirmContactCode(widget.channel, code);
      _busy(false);
      widget.onSubmitted();
    } catch (error) {
      _busy(false);
      if (error is CredflareException && error.status == 409) {
        widget.onSubmitted();
        return;
      }
      if (!mounted) return;
      _failed(error, _Phase.code, SpecCopyKey.errorsConfirmCodeFailed);
    }
  }

  void _failed(Object error, _Phase back, String networkKey, {String? target}) {
    final rejected = error is CredflareException && error.status == 422;
    setState(() {
      _phase = back;
      if (rejected) {
        _rejection = Rejection.from(error, info: widget.info);
        if (_rejected!.action == 'wait') {
          _waitUntil = _waitFor(error);
          _resendAt = _waitUntil;
          if (_shownDestination == null && target != null) {
            _codeField.clear();
            if (_previous case (final shown, final remaining, final minutes)) {
              _shownDestination = shown;
              _sendsRemaining = remaining;
              _minutes = minutes;
              _changeAfter = true;
            } else {
              _shownDestination = target;
              _sendsRemaining = null;
              _minutes = SpecRequirements.contactCodesTtlMinutes;
            }
            _phase = _Phase.code;
            _focusCode();
          }
        }
      } else if (error is CredflareException && error.status == 401) {
        _error = copy(SpecCopyKey.errorsSessionExpired);
      } else if (error is CredflareException && error.status != 0) {
        _error = error.message;
      } else {
        _error = copy(networkKey);
      }
    });
    _tick();
  }

  DateTime _waitFor(CredflareException error) {
    final at = error.resendAvailableAt;
    if (at != null) return _serverTime(at);
    if (_resendAt != null && _secondsUntil(_resendAt) > 0) return _resendAt!;
    return widget.now().add(
      const Duration(seconds: SpecRequirements.contactCodesResendSeconds),
    );
  }

  String? _validDestination() {
    final input = _destination.text;
    final value = _email
        ? (isEmailAddress(input) ? input.trim() : null)
        : normalizePhone(input);
    if (value == null) {
      setState(
        () => _fieldError = copy(
          _email ? SpecCopyKey.emailInvalid : SpecCopyKey.phoneInvalid,
        ),
      );
    }
    return value;
  }

  void _act() {
    final rejected = _rejected;
    if (rejected == null) return;
    switch (rejected.action) {
      case 'leave':
        widget.onLeave(rejected.code);
      case 'new_code':
      case 'wait':
        _send();
      case 'reenter_code':
        _codeField.clear();
        setState(() {
          _rejection = null;
          _phase = _Phase.code;
        });
        _focusCode();
      default:
        setState(() => _rejection = null);
    }
  }

  List<Widget> _destinationStep(ThemeData theme) {
    final sending = _phase == _Phase.sending;
    return [
      CredflareTitle(
        copy(_email ? SpecCopyKey.emailTitle : SpecCopyKey.phoneTitle),
      ),
      const SizedBox(height: 8),
      CredflareBody(
        copy(_email ? SpecCopyKey.emailBody : SpecCopyKey.phoneBody, {
          'verifier': verifierName(widget.info),
        }),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _destination,
        enabled: !sending,
        keyboardType: _email ? TextInputType.emailAddress : TextInputType.phone,
        autofillHints: [
          _email ? AutofillHints.email : AutofillHints.telephoneNumber,
        ],
        autocorrect: false,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => _send(),
        onChanged: (_) {
          if (_fieldError != null) setState(() => _fieldError = null);
        },
        decoration: InputDecoration(
          labelText: copy(
            _email ? SpecCopyKey.emailLabel : SpecCopyKey.phoneLabel,
          ),
          hintText: _email ? copy(SpecCopyKey.emailPlaceholder) : null,
          helperText: _email ? null : copy(SpecCopyKey.phoneHint),
          errorText: _fieldError,
        ),
      ),
      if (_error != null) CredflareNotice(_error!),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: sending ? null : () => _send(),
        child: Text(
          copy(
            sending
                ? SpecCopyKey.contactCodeSending
                : _email
                ? SpecCopyKey.emailSend
                : SpecCopyKey.phoneSend,
          ),
        ),
      ),
    ];
  }

  List<Widget> _codeStep(ThemeData theme) {
    final confirming = _phase == _Phase.confirming;
    final remaining = _sendsRemaining;
    final wait = _secondsUntil(_resendAt);
    return [
      CredflareTitle(copy(SpecCopyKey.contactCodeTitle)),
      const SizedBox(height: 8),
      CredflareBody(
        copy(SpecCopyKey.contactCodeBody, {
          'destination': _shownDestination,
          'minutes': _minutes,
        }),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _codeField,
        focusNode: _codeFocus,
        enabled: !confirming,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(
            SpecRequirements.contactCodesCodeLength,
          ),
        ],
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _confirm(),
        decoration: InputDecoration(
          labelText: copy(SpecCopyKey.contactCodeLabel),
        ),
      ),
      if (_changeAfter) ...[
        const SizedBox(height: 8),
        CredflareBody(
          copy(
            _email
                ? SpecCopyKey.emailChangeAfter
                : SpecCopyKey.phoneChangeAfter,
          ),
          small: true,
        ),
      ],
      if (_error != null) CredflareNotice(_error!),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: confirming || !_code.hasMatch(_codeField.text)
            ? null
            : _confirm,
        child: Text(
          copy(
            confirming
                ? SpecCopyKey.contactCodeConfirming
                : SpecCopyKey.contactCodeConfirm,
          ),
        ),
      ),
      if (remaining != 0 && _rejected == null) ...[
        const SizedBox(height: 8),
        TextButton(
          onPressed: confirming || wait > 0 ? null : _send,
          child: Text(copy(SpecCopyKey.contactCodeResend)),
        ),
        if (wait > 0)
          CredflareBody(
            copy(SpecCopyKey.contactCodeResendIn, {'seconds': wait}),
            small: true,
          ),
        if (remaining != null) ...[
          const SizedBox(height: 4),
          CredflareBody(
            copy(SpecCopyKey.contactCodeSendsRemaining, {'count': remaining}),
            small: true,
          ),
        ],
      ],
      const SizedBox(height: 8),
      TextButton(
        onPressed: confirming
            ? null
            : () => setState(() {
                if (_shownDestination case final shown?) {
                  _previous = (shown, _sendsRemaining, _minutes);
                }
                _changeAfter = false;
                _phase = _Phase.destination;
                _shownDestination = null;
                _sendsRemaining = null;
                _rejection = null;
                _waitUntil = null;
                _error = null;
              }),
        child: Text(
          copy(_email ? SpecCopyKey.emailChange : SpecCopyKey.phoneChange),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rejected = _rejected;
    final codeScreen = _phase == _Phase.code || _phase == _Phase.confirming;
    Widget? panel;
    if (rejected != null) {
      final waiting = rejected.action == 'wait';
      final wait = waiting ? _secondsUntil(_waitUntil) : 0;
      panel = CredflareRejection(
        rejection: rejected,
        onAction: wait > 0 || (waiting && _sendsRemaining == 0) ? null : _act,
        note: wait > 0
            ? copy(SpecCopyKey.contactCodeResendIn, {'seconds': wait})
            : null,
      );
      if (rejected.action != 'wait' || !codeScreen) return panel;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (panel != null) ...[panel, const SizedBox(height: 32)],
        ...codeScreen ? _codeStep(theme) : _destinationStep(theme),
      ],
    );
  }
}
