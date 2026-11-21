import 'package:flutter/material.dart';
import 'spec.generated.dart';
import 'spec_icon.dart';
import 'theme.dart';

class CredflareTitle extends StatelessWidget {
  final String text;
  const CredflareTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall,
    ),
  );
}

class CredflareBody extends StatelessWidget {
  final String text;
  final bool small;
  final Color? color;
  const CredflareBody(this.text, {super.key, this.small = false, this.color});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: (small ? theme.textTheme.bodySmall : theme.textTheme.bodyLarge)
          ?.copyWith(color: color ?? theme.colorScheme.onSurfaceVariant),
    );
  }
}

class CredflareGlyph extends StatelessWidget {
  final SpecIcon icon;
  final double size;
  final Color? color;
  const CredflareGlyph(this.icon, {super.key, this.size = 56, this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 20),
    child: Center(
      child: CredflareIcon(
        icon,
        size: size,
        color: color ?? Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class CredflareNotice extends StatelessWidget {
  final String message;
  const CredflareNotice(this.message, {super.key});
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(SpecTokens.radiusMd.toDouble()),
          ),
          child: Column(
            children: [
              CredflareIcon(SpecIcons.error, color: color),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CredflareCard extends StatelessWidget {
  final SpecIcon icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const CredflareCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: SpecTokens.spacingSection * 1.0),
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(CredflareTheme.radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              children: [
                CredflareIcon(
                  icon,
                  size: 28,
                  color: onTap == null ? muted : theme.colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                if (onTap != null) ...[
                  const SizedBox(height: 4),
                  CredflareIcon(SpecIcons.chevronRight, color: muted, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CredflareBackLink extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const CredflareBackLink({super.key, required this.label, this.onPressed});
  @override
  Widget build(BuildContext context) => Center(
    child: TextButton.icon(
      onPressed: onPressed,
      icon: CredflareIcon(
        SpecIcons.chevronLeft,
        size: 20,
        color: onPressed == null
            ? Theme.of(context).disabledColor
            : Theme.of(context).colorScheme.primary,
      ),
      label: Text(label),
    ),
  );
}
