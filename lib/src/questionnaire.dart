import 'dart:convert';
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
  'founders',
];

/// The questions still to answer, or an empty list.
List<Map<String, dynamic>> formQuestions(Map? info) => [
  for (final item in (info?['profile'] as Map?)?['form_schema'] as List? ?? [])
    Map<String, dynamic>.from(item as Map),
];

/// Earlier answers of the case that the outstanding questions depend on.
Map<String, Object?> formAnswers(Map? info) {
  final answers = (info?['profile'] as Map?)?['form_answers'];
  return answers is Map ? Map<String, Object?>.from(answers) : {};
}

bool _supported(Map q) => questionnaireTypes.contains(q['type'] ?? 'text');

/// Whether this SDK can ask the questions in the list: every question of a
/// type it cannot ask is hidden by the earlier answers.
bool canAskQuestions(
  List<Map<String, dynamic>> questions, [
  Map<String, Object?> earlierAnswers = const {},
]) {
  final context = Map<String, Object?>.from(earlierAnswers);
  for (final q in questions) {
    final visible = questionVisible(q, context);
    if (!_supported(q) && visible) return false;
    if (!visible) context.remove(q['key']);
  }
  return true;
}

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

  /// Called instead of sending when the answers show a question of a type
  /// this SDK cannot ask, so the host app asks the questions.
  final VoidCallback? onUnsupported;
  const CredflareQuestionnaire({
    super.key,
    required this.session,
    required this.info,
    required this.onSubmitted,
    required this.onBusyChanged,
    this.earlierAnswers = const {},
    this.onUnsupported,
  });
  @override
  State<CredflareQuestionnaire> createState() => _QuestionnaireState();
}

class _QuestionnaireState extends State<CredflareQuestionnaire> {
  late final List<Map<String, dynamic>> _questions = formQuestions(widget.info);
  final _values = <String, Object?>{};
  final _text = <String, TextEditingController>{};
  final _founders = <String, List<TextEditingController>>{};
  final _errors = <String, String>{};
  bool _checked = false;
  bool _unsupportedShown = false;
  bool _sending = false;
  Rejection? _rejected;
  String? _error;
  String _key = requestKey();
  String? _keyFor;
  late final Map<String, Object?> _earlier = {
    ...widget.earlierAnswers,
    ...formAnswers(widget.info),
  };

  @override
  void initState() {
    super.initState();
    for (final q in _questions) {
      final key = q['key'] as String;
      if (!_earlier.containsKey(key)) continue;
      final value = _earlier[key];
      switch (_type(q)) {
        case 'consent':
          _values[key] = value == true;
        case 'multi_select':
          if (value is List) _values[key] = {for (final v in value) '$v'};
        case 'select' || 'single_select' || 'country' || 'date':
          if (value is String) _values[key] = value;
        case 'founders':
          if (value is Map) {
            _values[key] = value['includes_applicant'] == true;
            final names = value['names'];
            if (names is List && names.isNotEmpty) {
              _founders[key] = [
                for (final name in names) TextEditingController(text: '$name'),
              ];
            }
          }
        default:
          if (value is String || value is num) {
            _controller(key).text = '$value';
          }
      }
    }
  }

  @override
  void dispose() {
    for (final c in [..._text.values, ..._founders.values.expand((l) => l)]) {
      c.dispose();
    }
    super.dispose();
  }

  String _type(Map q) => q['type'] as String? ?? 'text';

  TextEditingController _controller(String key) =>
      _text.putIfAbsent(key, () => TextEditingController());

  List<TextEditingController> _names(String key) =>
      _founders.putIfAbsent(key, () => [TextEditingController()]);

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
      case 'founders':
        final includesMe = _values[key] == true;
        final names = [
          for (final c in _names(key))
            if (c.text.trim().isNotEmpty) c.text.trim(),
        ];
        if (!includesMe && names.isEmpty) return null;
        return {'includes_applicant': includesMe, 'names': names};
      case 'number':
        final raw = _controller(key).text.trim();
        if (raw.isEmpty) return null;
        if (!RegExp(SpecRequirements.questionsNumberPattern).hasMatch(raw)) {
          return raw;
        }
        final number = raw.contains('.')
            ? double.parse(raw)
            : int.tryParse(raw);
        return number != null && number.toString() == raw ? number : raw;
      default:
        final raw = _controller(key).text;
        return raw.trim().isEmpty ? null : raw.trim();
    }
  }

  /// Visible questions and the answers to send, evaluated in order so each
  /// show_if sees only the answers that will be sent.
  (List<Map<String, dynamic>>, Map<String, Object?>) _evaluate() {
    _unsupportedShown = false;
    final context = Map<String, Object?>.from(_earlier);
    final visible = <Map<String, dynamic>>[];
    final fields = <String, Object?>{};
    for (final q in _questions) {
      final key = q['key'] as String;
      if (!questionVisible(q, context)) {
        context.remove(key);
        continue;
      }
      if (!_supported(q)) {
        _unsupportedShown = true;
        context.remove(key);
        continue;
      }
      visible.add(q);
      final value = _answer(q);
      if (_blank(value)) {
        context.remove(key);
        if (_earlier.containsKey(key)) fields[key] = null;
      } else {
        context[key] = value;
        fields[key] = value;
      }
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
        if ((value as String).runes.length >
            SpecRequirements.questionsTextMaxLength) {
          return copy(SpecCopyKey.questionsTextTooLong);
        }
      case 'number':
        final number = value is num
            ? value
            : RegExp(
                SpecRequirements.questionsNumberPattern,
              ).hasMatch(value as String)
            ? num.parse(value)
            : null;
        if (number == null) return copy(SpecCopyKey.questionsInvalidNumber);
        final min = q['min'];
        final max = q['max'];
        if (min is num && number < min) {
          return copy(SpecCopyKey.questionsNumberMin, {'min': _number(min)});
        }
        if (max is num && number > max) {
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
    if (_unsupportedShown && widget.onUnsupported != null) {
      widget.onUnsupported!();
      return;
    }
    final payload = jsonEncode(fields);
    if (_keyFor != null && _keyFor != payload) _key = requestKey();
    _keyFor = payload;
    setState(() => _sending = true);
    widget.onBusyChanged(true);
    try {
      await widget.session.submitAnswers(fields, key: _key);
      widget.onBusyChanged(false);
      widget.onSubmitted(fields);
    } catch (error) {
      widget.onBusyChanged(false);
      if (error is CredflareException && error.status == 409) {
        widget.onSubmitted(fields);
        return;
      }
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
      case 'founders':
        final names = _names(key);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label(theme, q),
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
              title: Text(copy(SpecCopyKey.questionsFoundersIncludesMe)),
            ),
            for (final (i, name) in names.indexed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: ValueKey('question-$key-$i'),
                        controller: name,
                        enabled: enabled,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        decoration: InputDecoration(
                          labelText: copy(SpecCopyKey.questionsFoundersName),
                        ),
                        onChanged: (_) => _changed(),
                      ),
                    ),
                    if (names.length > 1)
                      TextButton(
                        onPressed: enabled
                            ? () {
                                final removed = names.removeAt(i);
                                _changed();
                                WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => removed.dispose(),
                                );
                              }
                            : null,
                        child: Text(copy(SpecCopyKey.questionsFoundersRemove)),
                      ),
                  ],
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: enabled
                    ? () {
                        names.add(TextEditingController());
                        _changed();
                      }
                    : null,
                child: Text(copy(SpecCopyKey.questionsFoundersAdd)),
              ),
            ),
            _errorText(theme, error),
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
                  firstDate: DateTime(0),
                  lastDate: DateTime(9999, 12, 31),
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
