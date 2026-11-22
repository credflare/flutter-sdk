import 'package:flutter/material.dart';
import 'copy.dart';
import 'spec.generated.dart';

class CredflareTheme {
  static const gutter = 24.0;
  static const gap = 16.0;
  static const radius = 14.0;
  static const buttonHeight = 56.0;
  static const maxContentWidth = 600.0;
  static Map<String, Color> _palette(SpecPalette p) => {
    'primary': Color(p.primary),
    'onPrimary': Color(p.onPrimary),
    'surface': Color(p.surface),
    'ink': Color(p.ink),
    'muted': Color(p.muted),
    'soft': Color(p.soft),
    'border': Color(p.border),
    'accent': Color(p.accent),
    'success': Color(p.success),
    'error': Color(p.error),
    'warningSoft': Color(p.warningSoft),
    'warningInk': Color(p.warningInk),
  };
  static final light = _palette(SpecTokens.light);
  static final dark = _palette(SpecTokens.dark);
  static Map<String, Color> of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  static TextStyle _type(SpecTextStyle t) => TextStyle(
    fontSize: t.size,
    height: t.lineHeight / t.size,
    fontWeight: FontWeight.values[(t.weight ~/ 100) - 1],
  );

  static ThemeData data(Brightness brightness) {
    final p = brightness == Brightness.dark ? dark : light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: p['primary']!,
          brightness: brightness,
        ).copyWith(
          primary: p['primary'],
          onPrimary: p['onPrimary'],
          surface: p['surface'],
          onSurface: p['ink'],
          onSurfaceVariant: p['muted'],
          outline: p['border'],
          primaryContainer: p['soft'],
          onPrimaryContainer: p['primary'],
          error: p['error'],
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: p['surface'],
      fontFamily: 'packages/credflare_sdk/Ubuntu',
      textTheme: TextTheme(
        headlineSmall: _type(SpecTokens.typeTitle),
        titleMedium: _type(SpecTokens.typeSubtitle),
        bodyLarge: _type(SpecTokens.typeBody),
        bodyMedium: _type(SpecTokens.typeLabel),
        bodySmall: _type(SpecTokens.typeSmall),
        labelLarge: _type(SpecTokens.typeButton),
        labelSmall: _type(SpecTokens.typeChip),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p['surface'],
        foregroundColor: p['ink'],
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'packages/credflare_sdk/Ubuntu',
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: p['border']!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: p['border']!),
        ),
        errorMaxLines: 3,
        helperMaxLines: 3,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'packages/credflare_sdk/Ubuntu',
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class CredflareMark extends StatelessWidget {
  const CredflareMark({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        'assets/credflare-mark.png',
        package: 'credflare_sdk',
        width: 30,
        height: 30,
        excludeFromSemantics: true,
      ),
      const SizedBox(width: 10),
      Text(
        'Credflare',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class CredflareVerifierBar extends StatelessWidget {
  final String? name;
  final String? logoUrl;
  final bool sandbox;
  const CredflareVerifierBar({
    super.key,
    this.name,
    this.logoUrl,
    this.sandbox = false,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.brightness == Brightness.dark
        ? CredflareTheme.dark
        : CredflareTheme.light;
    return Row(
      children: [
        if (logoUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              logoUrl!,
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (name != null)
          Flexible(
            child: Text(
              name!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        if (sandbox) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: palette['warningSoft'],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              copy(SpecCopyKey.commonTestMode),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: palette['warningInk'],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class CredflareSecuredBy extends StatelessWidget {
  const CredflareSecuredBy({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 32),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Image.asset(
            'assets/credflare-mark.png',
            package: 'credflare_sdk',
            width: 14,
            height: 14,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          copy(SpecCopyKey.commonSecuredBy),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class CredflareSideGuide extends StatelessWidget {
  final String side;
  const CredflareSideGuide({super.key, required this.side});

  Widget _line(double widthFactor, Color color) => FractionallySizedBox(
    alignment: Alignment.centerLeft,
    widthFactor: widthFactor,
    child: Container(
      height: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final palette = Theme.of(context).brightness == Brightness.dark
        ? CredflareTheme.dark
        : CredflareTheme.light;
    final front = Row(
      children: [
        Expanded(
          flex: 34,
          child: FractionallySizedBox(
            heightFactor: 0.88,
            child: Container(
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, box) => Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: box.maxWidth * 0.42,
                      height: box.maxWidth * 0.42,
                      decoration: BoxDecoration(
                        color: colors.outline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: box.maxWidth * 0.74,
                      height: box.maxHeight * 0.3,
                      decoration: BoxDecoration(
                        color: colors.outline,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(99),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 66,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line(0.55, palette['accent']!),
              const SizedBox(height: 8),
              _line(0.9, colors.outline),
              const SizedBox(height: 8),
              _line(0.75, colors.outline),
              const SizedBox(height: 8),
              _line(0.6, colors.outline),
            ],
          ),
        ),
      ],
    );
    final back = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Transform.scale(
          scaleX: 1.2,
          child: Container(
            height: 14,
            color: colors.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 12),
        _line(0.85, colors.outline),
        const SizedBox(height: 8),
        _line(0.65, colors.outline),
        const Spacer(),
        SizedBox(
          height: 18,
          child: Row(
            children: [
              for (final width in [
                3,
                1,
                2,
                1,
                3,
                2,
                1,
                1,
                3,
                1,
                2,
                2,
                1,
                3,
              ]) ...[
                Container(
                  width: width.toDouble(),
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 2),
              ],
            ],
          ),
        ),
      ],
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: AspectRatio(
          aspectRatio: 1.586,
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                border: Border.all(color: colors.outline, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(color: colors.outline),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: side == 'front' ? front : back,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
