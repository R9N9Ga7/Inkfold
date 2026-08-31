import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/inkfold_theme.dart';
import '../domain/reading_preferences.dart';
import '../providers.dart';
import 'app_scaffold.dart';

final class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPreferences = ref.watch(readingPreferencesProvider);
    return AppScaffold(
      selectedIndex: 1,
      title: 'Settings',
      body: asyncPreferences.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (preferences) => _SettingsBody(preferences: preferences),
      ),
    );
  }
}

final class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.preferences});
  final ReadingPreferences preferences;

  Future<void> _save(WidgetRef ref, ReadingPreferences value) {
    return ref.read(databaseProvider).savePreferences(value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugins = ref.watch(pluginCatalogProvider).plugins;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 56),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const _SectionHeading(
                title: 'Appearance',
                subtitle: 'Choose how Inkfold looks outside the reading page.',
              ),
              const SizedBox(height: 16),
              SegmentedButton<AppAppearance>(
                segments: const <ButtonSegment<AppAppearance>>[
                  ButtonSegment(value: AppAppearance.system, icon: Icon(Icons.brightness_auto), label: Text('System')),
                  ButtonSegment(value: AppAppearance.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                  ButtonSegment(value: AppAppearance.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
                ],
                selected: <AppAppearance>{preferences.appAppearance},
                onSelectionChanged: (value) => _save(
                  ref,
                  preferences.copyWith(appAppearance: value.first),
                ),
              ),
              const SizedBox(height: 38),
              const Divider(),
              const SizedBox(height: 30),
              const _SectionHeading(
                title: 'Reading defaults',
                subtitle: 'These controls apply to every book and update immediately.',
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  for (final palette in ReaderPalette.values)
                    _PaletteChoice(
                      palette: palette,
                      selected: preferences.palette == palette,
                      onTap: () => _save(ref, preferences.copyWith(palette: palette)),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              _LabeledSlider(
                label: 'Text size',
                valueLabel: '${preferences.fontSize.round()} pt',
                value: preferences.fontSize,
                min: 15,
                max: 30,
                divisions: 15,
                onChanged: (value) => _save(ref, preferences.copyWith(fontSize: value)),
              ),
              _LabeledSlider(
                label: 'Line height',
                valueLabel: preferences.lineHeight.toStringAsFixed(2),
                value: preferences.lineHeight,
                min: 1.25,
                max: 2.1,
                divisions: 17,
                onChanged: (value) => _save(ref, preferences.copyWith(lineHeight: value)),
              ),
              _LabeledSlider(
                label: 'Reading width',
                valueLabel: '${preferences.pageWidth.round()} px',
                value: preferences.pageWidth,
                min: 520,
                max: 900,
                divisions: 19,
                onChanged: (value) => _save(ref, preferences.copyWith(pageWidth: value)),
              ),
              const SizedBox(height: 38),
              const Divider(),
              const SizedBox(height: 30),
              const _SectionHeading(
                title: 'Formats',
                subtitle: 'Reader plugins currently registered in this build.',
              ),
              const SizedBox(height: 12),
              for (final plugin in plugins)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: InkfoldTheme.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(Icons.description_outlined, color: InkfoldTheme.teal),
                  ),
                  title: Text(plugin.manifest.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('.${plugin.manifest.extensions.join('  .')}  •  v${plugin.manifest.version}'),
                  trailing: const Icon(Icons.check_circle, color: InkfoldTheme.teal),
                ),
              const SizedBox(height: 38),
              const Divider(),
              const SizedBox(height: 30),
              const _SectionHeading(
                title: 'About',
                subtitle: 'Inkfold 1.0.0  •  Local library  •  Plugin API 1',
              ),
              const SizedBox(height: 10),
              Text(
                'Licensed under PolyForm Noncommercial 1.0.0.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontFamily: 'Literata',
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

final class _PaletteChoice extends StatelessWidget {
  const _PaletteChoice({required this.palette, required this.selected, required this.onTap});
  final ReaderPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (palette) {
      ReaderPalette.day => ('Day', const Color(0xffffffff), const Color(0xff1e2524)),
      ReaderPalette.paper => ('Paper', const Color(0xfff4f0e7), const Color(0xff2d2922)),
      ReaderPalette.night => ('Night', const Color(0xff191d1c), const Color(0xffdce1da)),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        width: 142,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? InkfoldTheme.teal : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: background,
                border: Border.all(color: const Color(0x33000000)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Center(child: Text('Aa', style: TextStyle(color: foreground, fontFamily: 'Literata', fontSize: 11))),
            ),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

final class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      children: <Widget>[
        SizedBox(width: 112, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 62, child: Text(valueLabel, textAlign: TextAlign.end)),
      ],
    ),
  );
}
