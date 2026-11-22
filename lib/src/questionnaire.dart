import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'client.dart';
import 'conditions.dart';
import 'copy.dart';
import 'rejection.dart';
import 'spec.generated.dart';
import 'ui.dart';

const countryCodes = [
  'AD',
  'AE',
  'AF',
  'AG',
  'AI',
  'AL',
  'AM',
  'AO',
  'AQ',
  'AR',
  'AS',
  'AT',
  'AU',
  'AW',
  'AX',
  'AZ',
  'BA',
  'BB',
  'BD',
  'BE',
  'BF',
  'BG',
  'BH',
  'BI',
  'BJ',
  'BL',
  'BM',
  'BN',
  'BO',
  'BQ',
  'BR',
  'BS',
  'BT',
  'BV',
  'BW',
  'BY',
  'BZ',
  'CA',
  'CC',
  'CD',
  'CF',
  'CG',
  'CH',
  'CI',
  'CK',
  'CL',
  'CM',
  'CN',
  'CO',
  'CR',
  'CU',
  'CV',
  'CW',
  'CX',
  'CY',
  'CZ',
  'DE',
  'DJ',
  'DK',
  'DM',
  'DO',
  'DZ',
  'EC',
  'EE',
  'EG',
  'EH',
  'ER',
  'ES',
  'ET',
  'FI',
  'FJ',
  'FK',
  'FM',
  'FO',
  'FR',
  'GA',
  'GB',
  'GD',
  'GE',
  'GF',
  'GG',
  'GH',
  'GI',
  'GL',
  'GM',
  'GN',
  'GP',
  'GQ',
  'GR',
  'GS',
  'GT',
  'GU',
  'GW',
  'GY',
  'HK',
  'HM',
  'HN',
  'HR',
  'HT',
  'HU',
  'ID',
  'IE',
  'IL',
  'IM',
  'IN',
  'IO',
  'IQ',
  'IR',
  'IS',
  'IT',
  'JE',
  'JM',
  'JO',
  'JP',
  'KE',
  'KG',
  'KH',
  'KI',
  'KM',
  'KN',
  'KP',
  'KR',
  'KW',
  'KY',
  'KZ',
  'LA',
  'LB',
  'LC',
  'LI',
  'LK',
  'LR',
  'LS',
  'LT',
  'LU',
  'LV',
  'LY',
  'MA',
  'MC',
  'MD',
  'ME',
  'MF',
  'MG',
  'MH',
  'MK',
  'ML',
  'MM',
  'MN',
  'MO',
  'MP',
  'MQ',
  'MR',
  'MS',
  'MT',
  'MU',
  'MV',
  'MW',
  'MX',
  'MY',
  'MZ',
  'NA',
  'NC',
  'NE',
  'NF',
  'NG',
  'NI',
  'NL',
  'NO',
  'NP',
  'NR',
  'NU',
  'NZ',
  'OM',
  'PA',
  'PE',
  'PF',
  'PG',
  'PH',
  'PK',
  'PL',
  'PM',
  'PN',
  'PR',
  'PS',
  'PT',
  'PW',
  'PY',
  'QA',
  'RE',
  'RO',
  'RS',
  'RU',
  'RW',
  'SA',
  'SB',
  'SC',
  'SD',
  'SE',
  'SG',
  'SH',
  'SI',
  'SJ',
  'SK',
  'SL',
  'SM',
  'SN',
  'SO',
  'SR',
  'SS',
  'ST',
  'SV',
  'SX',
  'SY',
  'SZ',
  'TC',
  'TD',
  'TF',
  'TG',
  'TH',
  'TJ',
  'TK',
  'TL',
  'TM',
  'TN',
  'TO',
  'TR',
  'TT',
  'TV',
  'TW',
  'TZ',
  'UA',
  'UG',
  'UM',
  'US',
  'UY',
  'UZ',
  'VA',
  'VC',
  'VE',
  'VG',
  'VI',
  'VN',
  'VU',
  'WF',
  'WS',
  'YE',
  'YT',
  'ZA',
  'ZM',
  'ZW',
];

const questionnaireTypes = [
  'text',
  'textarea',
  'email',
  'number',
  'date',
  'select',
  'tel',
  'phone',
  'single_select',
  'multi_select',
  'country',
  'consent',
];

/// The questions still to answer, or an empty list.
List<Map<String, dynamic>> formQuestions(Map? info) => [
  for (final item in (info?['profile'] as Map?)?['form_schema'] as List? ?? [])
    Map<String, dynamic>.from(item as Map),
];

/// Whether this SDK can ask every question in the list.
bool canAskQuestions(List<Map<String, dynamic>> questions) =>
    questions.every((q) => questionnaireTypes.contains(q['type'] ?? 'text'));

bool _blank(Object? v) => v == null || v == '' || (v is List && v.isEmpty);

String _number(num v) => v is double && v == v.truncateToDouble()
    ? v.toInt().toString()
    : v.toString();

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

bool _realDate(String value) {
  if (!RegExp(SpecRequirements.questionsDatePattern).hasMatch(value)) {
    return false;
  }
  final parts = value.split('-').map(int.parse).toList();
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  return date.year == parts[0] &&
      date.month == parts[1] &&
      date.day == parts[2];
}

String _flag(String code) =>
    String.fromCharCodes(code.codeUnits.map((c) => 0x1F1E6 + c - 0x41));

String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Asks the questions in `profile.form_schema`. Hidden questions are not
/// shown, not checked and not sent.
class CredflareQuestionnaire extends StatefulWidget {
  final CredflareSession session;
  final Map<String, dynamic> info;
  final Map<String, Object?> earlierAnswers;
  final ValueChanged<Map<String, Object?>> onSubmitted;
  final ValueChanged<bool> onBusyChanged;
  const CredflareQuestionnaire({
    super.key,
    required this.session,
    required this.info,
    required this.onSubmitted,
    required this.onBusyChanged,
    this.earlierAnswers = const {},
  });
  @override
  State<CredflareQuestionnaire> createState() => _QuestionnaireState();
}

class _QuestionnaireState extends State<CredflareQuestionnaire> {
  late final List<Map<String, dynamic>> _questions = formQuestions(widget.info);
  final _values = <String, Object?>{};
  final _text = <String, TextEditingController>{};
  final _errors = <String, String>{};
  bool _checked = false;
  bool _sending = false;
  Rejection? _rejected;
  String? _error;
  String _key = requestKey();

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _type(Map q) => q['type'] as String? ?? 'text';

  TextEditingController _controller(String key) =>
      _text.putIfAbsent(key, () => TextEditingController());

  Object? _answer(Map<String, dynamic> q) {
    final key = q['key'] as String;
    switch (_type(q)) {
      case 'consent':
        return _values[key] == true;
      case 'multi_select':
        final chosen = (_values[key] as Set<String>?) ?? {};
        return [
          for (final o in (q['options'] as List? ?? const []).cast<String>())
            if (chosen.contains(o)) o,
        ];
      case 'select' || 'single_select' || 'country' || 'date':
        return _values[key];
      case 'number':
        final raw = _controller(key).text.trim();
        if (raw.isEmpty) return null;
        if (!RegExp(SpecRequirements.questionsNumberPattern).hasMatch(raw)) {
          return raw;
        }
        return int.tryParse(raw) ?? double.parse(raw);
      default:
        final raw = _controller(key).text;
        return raw.trim().isEmpty ? null : raw.trim();
    }
  }

  /// Visible questions and the answers to send, evaluated in order so each
  /// show_if sees only the answers that will be sent.
  (List<Map<String, dynamic>>, Map<String, Object?>) _evaluate() {
    final context = Map<String, Object?>.from(widget.earlierAnswers);
    final visible = <Map<String, dynamic>>[];
    final fields = <String, Object?>{};
    for (final q in _questions) {
      final key = q['key'] as String;
      if (!questionVisible(q, context)) {
        context.remove(key);
        continue;
      }
      visible.add(q);
      final value = _answer(q);
      context[key] = value;
      if (!_blank(value)) fields[key] = value;
    }
    return (visible, fields);
  }

  String? _problem(Map<String, dynamic> q, Object? value) {
    final required = q['required'] == true;
    final type = _type(q);
    if (type == 'consent') {
      return required && value != true
          ? copy(SpecCopyKey.questionsConsentRequired)
          : null;
    }
    if (_blank(value)) {
      return required ? copy(SpecCopyKey.questionsRequired) : null;
    }
    switch (type) {
      case 'text' || 'textarea':
        if ((value as String).length >
            SpecRequirements.questionsTextMaxLength) {
          return copy(SpecCopyKey.questionsTextTooLong);
        }
      case 'number':
        if (value is! num) return copy(SpecCopyKey.questionsInvalidNumber);
        final min = q['min'];
        final max = q['max'];
        if (min is num && value < min) {
          return copy(SpecCopyKey.questionsNumberMin, {'min': _number(min)});
        }
        if (max is num && value > max) {
          return copy(SpecCopyKey.questionsNumberMax, {'max': _number(max)});
        }
      case 'date':
        if (!_realDate(value as String)) {
          return copy(SpecCopyKey.questionsInvalidDate);
        }
      case 'email':
        final text = value as String;
        if (text.length > SpecRequirements.questionsEmailMaxLength ||
            !_email.hasMatch(text)) {
          return copy(SpecCopyKey.questionsInvalidEmail);
        }
      case 'phone' || 'tel':
        if (!RegExp(
          SpecRequirements.questionsPhonePattern,
        ).hasMatch(value as String)) {
          return copy(SpecCopyKey.questionsInvalidPhone);
        }
    }
    return null;
  }

  void _validate(List<Map<String, dynamic>> visible) {
    _errors.clear();
    for (final q in visible) {
      final problem = _problem(q, _answer(q));
      if (problem != null) _errors[q['key'] as String] = problem;
    }
  }

  void _changed() {
    setState(() {
      if (_checked) _validate(_evaluate().$1);
    });
  }

  Future<void> _send() async {
    final (visible, fields) = _evaluate();
    setState(() {
      _checked = true;
      _validate(visible);
      _error = null;
    });
    if (_errors.isNotEmpty) return;
    setState(() => _sending = true);
    widget.onBusyChanged(true);
    try {
      await widget.session.submitAnswers(fields, key: _key);
      widget.onBusyChanged(false);
      widget.onSubmitted(fields);
    } catch (error) {
      widget.onBusyChanged(false);
      if (!mounted) return;
      final rejected = error is CredflareException && error.status == 422;
      setState(() {
        _sending = false;
        if (rejected) {
          _key = requestKey();
          _rejected = Rejection.from(error, info: widget.info);
          final errors = error.errors;
          if (errors is Map) {
            for (final entry in errors.entries) {
              final name = '${entry.key}';
              final field = name.startsWith('fields.')
                  ? name.substring(7)
                  : name;
              final messages = entry.value;
              if (messages is List && messages.isNotEmpty) {
                _errors[field] = '${messages.first}';
              }
            }
          }
        } else if (error is CredflareException && error.status == 401) {
          _error = copy(SpecCopyKey.errorsSessionExpired);
        } else if (error is CredflareException && error.status != 0) {
          _key = requestKey();
          _error = error.message;
        } else {
          _error = copy(SpecCopyKey.errorsSendAnswersFailed);
        }
      });
    }
  }

  Widget _label(ThemeData theme, Map<String, dynamic> q) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text.rich(
      TextSpan(
        text: q['label'] as String? ?? q['key'] as String,
        style: theme.textTheme.titleMedium,
        children: [
          if (q['required'] != true)
            TextSpan(
              text: '  ${copy(SpecCopyKey.questionsOptional)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    ),
  );

  Widget _errorText(ThemeData theme, String? error) => error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6, left: 12),
          child: Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        );

  Widget _field(ThemeData theme, Map<String, dynamic> q) {
    final key = q['key'] as String;
    final error = _errors[key];
    final options = (q['options'] as List? ?? const []).cast<String>();
    final enabled = !_sending;
    switch (_type(q)) {
      case 'consent':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              value: _values[key] == true,
              onChanged: enabled
                  ? (v) {
                      _values[key] = v == true;
                      _changed();
                    }
                  : null,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(q['label'] as String? ?? key),
              subtitle: q['required'] == true
                  ? null
                  : Text(copy(SpecCopyKey.questionsOptional)),
            ),
            _errorText(theme, error),
          ],
        );
      case 'multi_select':
        final chosen = (_values[key] as Set<String>?) ?? <String>{};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label(theme, q),
            Text(
              copy(SpecCopyKey.questionsChooseMany),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            for (final option in options)
              CheckboxListTile(
                value: chosen.contains(option),
                onChanged: enabled
                    ? (v) {
                        final next = {...chosen};
                        v == true ? next.add(option) : next.remove(option);
                        _values[key] = next;
                        _changed();
                      }
                    : null,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(option),
              ),
            _errorText(theme, error),
          ],
        );
      case 'select' || 'single_select' || 'country':
        final country = _type(q) == 'country';
        final items = country ? countryCodes : options;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label(theme, q),
            DropdownButtonFormField<String>(
              key: ValueKey('question-$key'),
              initialValue: _values[key] as String?,
              isExpanded: true,
              menuMaxHeight: 420,
              hint: Text(
                copy(
                  country
                      ? SpecCopyKey.questionsChooseCountry
                      : SpecCopyKey.questionsChooseOne,
                ),
              ),
              decoration: InputDecoration(errorText: error),
              items: [
                for (final item in items)
                  DropdownMenuItem(
                    value: item,
                    child: Text(
                      country ? '${_flag(item)}  $item' : item,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: enabled
                  ? (v) {
                      _values[key] = v;
                      _changed();
                    }
                  : null,
            ),
          ],
        );
      case 'date':
        final value = _values[key] as String?;
        final controller = _controller(key)..text = value ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label(theme, q),
            TextField(
              key: ValueKey('question-$key'),
              controller: controller,
              readOnly: true,
              enabled: enabled,
              decoration: InputDecoration(errorText: error),
              onTap: () async {
                final initial = value != null && _realDate(value)
                    ? DateTime.parse(value)
                    : DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100, 12, 31),
                );
                if (picked == null || !mounted) return;
                _values[key] = _formatDate(picked);
                _changed();
              },
            ),
          ],
        );
      default:
        final type = _type(q);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label(theme, q),
            TextField(
              key: ValueKey('question-$key'),
              controller: _controller(key),
              enabled: enabled,
              minLines: type == 'textarea' ? 3 : 1,
              maxLines: type == 'textarea' ? 6 : 1,
              keyboardType: switch (type) {
                'number' => const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                'email' => TextInputType.emailAddress,
                'phone' || 'tel' => TextInputType.phone,
                'textarea' => TextInputType.multiline,
                _ => TextInputType.text,
              },
              inputFormatters: [
                if (type == 'text' || type == 'textarea')
                  LengthLimitingTextInputFormatter(
                    SpecRequirements.questionsTextMaxLength,
                  ),
              ],
              autocorrect: type == 'text' || type == 'textarea',
              decoration: InputDecoration(errorText: error),
              onChanged: (_) => _changed(),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_rejected case final rejected?) {
      return CredflareRejection(
        rejection: rejected,
        onAction: () => setState(() => _rejected = null),
      );
    }
    final (visible, _) = _evaluate();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CredflareGlyph(SpecIcons.document),
        CredflareTitle(copy(SpecCopyKey.questionsTitle)),
        const SizedBox(height: 8),
        CredflareBody(
          copy(SpecCopyKey.questionsBody, {
            'verifier': verifierName(widget.info),
          }),
        ),
        for (final q in visible) ...[
          const SizedBox(height: 24),
          KeyedSubtree(key: ValueKey('q-${q['key']}'), child: _field(theme, q)),
        ],
        if (_error != null) CredflareNotice(_error!),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: Text(
            copy(
              _sending
                  ? SpecCopyKey.questionsSending
                  : SpecCopyKey.questionsSend,
            ),
          ),
        ),
      ],
    );
  }
}
