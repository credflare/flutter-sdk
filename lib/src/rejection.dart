import 'package:flutter/material.dart';
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
  const Rejection({
    required this.code,
    required this.title,
    required this.message,
    required this.action,
    required this.verifier,
  });

  /// Builds the screen copy for a rejection. A missing or unknown code shows
  /// the server message with the retry action.
  factory Rejection.from(
    CredflareException error, {
    required Map? info,
    LocationReference? reference,
  }) {
    final verifier = verifierName(info);
    final entry = SpecRejection.codes[error.code];
    if (entry == null) {
      return Rejection(
        code: error.code,
        title: null,
        message: error.message,
        action: 'retry',
        verifier: verifier,
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
    );
  }

  String get actionLabel => copy(SpecRejection.actionLabels[action]!);
  String get requestedBy =>
      copy(SpecRejection.requestedBy, {'verifier': verifier});
  String get help => copy(SpecRejection.help, {'verifier': verifier});
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
          CredflareBody(rejection.help, small: true),
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
