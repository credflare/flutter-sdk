import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'client.dart';
import 'copy.dart';
import 'requirements.dart';
import 'spec.generated.dart';
import 'ui.dart';

/// What an applicant sees for a rejected request, read from the spec map.
class Rejection {
  final String? code;
  final String? title;
  final String message;
  final String action;
  final String verifier;
  final String? helpEmail;
  final String? helpUrl;
  const Rejection({
    required this.code,
    required this.title,
    required this.message,
    required this.action,
    required this.verifier,
    this.helpEmail,
    this.helpUrl,
  });

  /// Builds the screen copy for a rejection. A missing or unknown code shows
  /// the server message with the retry action.
  factory Rejection.from(
    CredflareException error, {
    required Map? info,
    LocationReference? reference,
  }) {
    final verifier = verifierName(info);
    final requester = info?['requester'] as Map?;
    String? contact(String key) {
      final value = requester?[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    final helpEmail = contact('help_email');
    final helpUrl = contact('help_url');
    final entry = SpecRejection.codes[error.code];
    if (entry == null) {
      return Rejection(
        code: error.code,
        title: null,
        message: error.message,
        action: 'retry',
        verifier: verifier,
        helpEmail: helpEmail,
        helpUrl: helpUrl,
      );
    }
    final places = reference?.labels ?? const <String>[];
    final placeKey = places.isEmpty
        ? null
        : reference!.rule == 'outside'
        ? entry.placeMessageOutside
        : entry.placeMessageWithin;
    final values = {'verifier': verifier, 'place': places.join(', ')};
    return Rejection(
      code: error.code,
      title: copy(entry.title, values),
      message: copy(placeKey ?? entry.message, values),
      action: entry.action,
      verifier: verifier,
      helpEmail: helpEmail,
      helpUrl: helpUrl,
    );
  }

  String get actionLabel => copy(SpecRejection.actionLabels[action]!);
  String get requestedBy =>
      copy(SpecRejection.requestedBy, {'verifier': verifier});
  String get help => copy(_helpKey, _helpValues);

  String get _helpKey => helpEmail != null
      ? SpecRejection.helpEmail
      : helpUrl != null
      ? SpecRejection.helpUrl
      : SpecRejection.help;

  Map<String, Object?> get _helpValues => {
    'verifier': verifier,
    'help_email': helpEmail,
    'help_url': helpUrl,
  };

  /// The help link, when the requester stored one: an email address as a
  /// mailto link, otherwise a web address.
  (String, Uri)? get helpLink => helpEmail != null
      ? ('{help_email}', Uri(scheme: 'mailto', path: helpEmail))
      : helpUrl != null
      ? ('{help_url}', Uri.parse(helpUrl!))
      : null;

  /// The help line split around its link so the link can be tapped.
  List<(String, Uri?)> get helpParts {
    final link = helpLink;
    final template = SpecCopy.en[_helpKey] ?? _helpKey;
    if (link == null) return [(help, null)];
    final (placeholder, uri) = link;
    final at = template.indexOf(placeholder);
    final values = Map.of(_helpValues)
      ..remove(placeholder.substring(1, placeholder.length - 1));
    String fill(String part) {
      var text = part;
      values.forEach((k, v) => text = text.replaceAll('{$k}', '$v'));
      return text;
    }

    return [
      (fill(template.substring(0, at)), null),
      (uri.scheme == 'mailto' ? uri.path : uri.toString(), uri),
      (fill(template.substring(at + placeholder.length)), null),
    ];
  }
}

class _HelpLine extends StatelessWidget {
  final Rejection rejection;
  const _HelpLine(this.rejection);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Text.rich(
      TextSpan(
        children: [
          for (final (text, uri) in rejection.helpParts)
            if (uri == null)
              TextSpan(text: text)
            else
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Semantics(
                  link: true,
                  child: InkWell(
                    onTap: () =>
                        launchUrl(uri, mode: LaunchMode.externalApplication),
                    child: Text(
                      text,
                      style: style?.copyWith(
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
      textAlign: TextAlign.center,
      style: style,
    );
  }
}

/// The rejection panel: title, message, who asked, where to get help and the
/// action button. [onAction] is null while the action is not yet available.
class CredflareRejection extends StatelessWidget {
  final Rejection rejection;
  final VoidCallback? onAction;
  final String? note;
  const CredflareRejection({
    super.key,
    required this.rejection,
    required this.onAction,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CredflareGlyph(SpecIcons.error, color: color),
          if (rejection.title != null) CredflareTitle(rejection.title!),
          const SizedBox(height: 8),
          CredflareBody(rejection.message, color: theme.colorScheme.onSurface),
          const SizedBox(height: 16),
          CredflareBody(rejection.requestedBy, small: true),
          const SizedBox(height: 4),
          _HelpLine(rejection),
          if (note != null) ...[
            const SizedBox(height: 16),
            CredflareBody(note!, small: true),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: onAction, child: Text(rejection.actionLabel)),
        ],
      ),
    );
  }
}
