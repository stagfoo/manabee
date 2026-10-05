/// Reading direction, speech speed, and where the data comes from.
library;

import 'package:flutter/material.dart';

import '../services/speech.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.library(context);
    final s = lib.settings;
    return GridScaffold(
      onBack: () => Navigator.maybePop(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('Settings', style: T.headlineLg),
          const SizedBox(height: 16),
          _Card(
            children: [
              SwitchListTile(
                value: s.rightToLeft,
                onChanged: (v) {
                  s.rightToLeft = v;
                  lib.changed();
                },
                title: Text('Right-to-left pages', style: T.bodyLg),
                subtitle: Text(
                  'Swipe right for the next page, as in a printed manga.',
                  style: T.bodyMd.copyWith(color: C.textDim),
                ),
              ),
              ListTile(
                title: Text('Speech speed', style: T.bodyLg),
                subtitle: Slider(
                  value: s.speechRate,
                  min: 0.2,
                  max: 0.8,
                  divisions: 6,
                  label: s.speechRate.toStringAsFixed(2),
                  onChanged: (v) {
                    s.speechRate = v;
                    Speech.instance.setRate(v);
                    lib.changed();
                  },
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.volume_up_outlined, color: C.text),
                  onPressed: () async {
                    final problem = await Speech.instance.say(
                      'こんにちは、漫画を読みましょう',
                    );
                    if (problem != null && context.mounted) {
                      toast(context, problem);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('ABOUT', style: T.monoSm),
          const SizedBox(height: 8),
          _Card(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'OCR runs on the device with Google ML Kit (Japanese model). '
                  'Dictionary lookups come from jisho.org, which serves JMdict '
                  '© the Electronic Dictionary Research and Development Group '
                  '(CC BY-SA 4.0) — lookups need internet; saved words work offline.\n\n'
                  'Fonts: Outfit and Space Mono, SIL Open Font Licence 1.1.\n\n'
                  'Your manga, bubbles and words never leave this device.',
                  style: T.bodyMd.copyWith(color: C.textDim),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: C.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: C.border),
    ),
    child: Column(children: children),
  );
}
