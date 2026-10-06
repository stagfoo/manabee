/// A dictionary entry laid out like the back of a flash card: the word
/// with its reading and tags on the left, numbered senses on the right.
library;

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/speech.dart';
import '../theme.dart';
import 'common.dart';

class EntryDetail extends StatelessWidget {
  const EntryDetail(this.entry, {super.key, this.context_ = ''});

  final Entry entry;

  /// The sentence the word was found in, if any.
  final String context_;

  @override
  Widget build(BuildContext context) {
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry.hasKanji)
          Text(
            entry.reading,
            style: T.bodyMd.copyWith(color: C.textDim, fontSize: 12),
          ),
        Text(
          entry.word,
          style: T.jp.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        Text(entry.romaji, style: T.monoSm),
        const SizedBox(height: 12),
        if (entry.common) const Tag('common word', Color(0xFF8ABF6E)),
        if (entry.jlpt != null)
          Tag('jlpt ${entry.jlpt!.toLowerCase()}', const Color(0xFF909DC0)),
        if (entry.wanikani != null)
          Tag('wanikani level ${entry.wanikani}', const Color(0xFF909DC0)),
        const SizedBox(height: 8),
        _Link('Play audio', () async {
          final problem = await Speech.instance.say(
            entry.reading.isEmpty ? entry.word : entry.reading,
          );
          if (problem != null && context.mounted) toast(context, problem);
        }),
      ],
    );

    final senses = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < entry.senses.length && i < 6; i++) ...[
          if (entry.senses[i].partsOfSpeech.isNotEmpty)
            Text(
              entry.senses[i].partsOfSpeech.join(', '),
              style: T.bodyMd.copyWith(color: C.textDim, fontSize: 11),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 2),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${i + 1}. ',
                    style: const TextStyle(color: C.textDim),
                  ),
                  TextSpan(text: entry.senses[i].glosses.join('; ')),
                ],
              ),
              style: T.bodyMd.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
        // Only a sentence the word is really in (see findInSentence).
        if (findInSentence(entry, context_) != null) ...[
          const SizedBox(height: 4),
          Text('FROM THE PAGE', style: T.monoSm),
          const SizedBox(height: 4),
          Text(
            '「$context_」',
            style: T.jp.copyWith(fontSize: 13, color: C.textDim),
          ),
        ],
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 4, child: left),
        const SizedBox(width: 12),
        Expanded(flex: 6, child: senses),
      ],
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(this.label, this.color, {super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      label,
      style: T.bodyMd.copyWith(
        fontSize: 10,
        color: Colors.black,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _Link extends StatelessWidget {
  const _Link(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        label,
        style: T.bodyMd.copyWith(
          color: const Color(0xFFA8B8E8),
          decoration: TextDecoration.underline,
          decorationColor: const Color(0xFFA8B8E8),
          fontSize: 13,
        ),
      ),
    ),
  );
}
