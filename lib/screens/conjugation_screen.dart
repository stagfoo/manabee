/// A verb's conjugation map.
///
/// The form in focus sits in the middle with the forms built from it in a
/// ring around it; tap one to move in, tap a step of the route above to
/// move back out. Each line is a rule (る → ない), each node coloured by
/// how it sounds: plain, polite, or a spoken contraction. Opened from a
/// word met in a manga, it starts on that word's form with the route from
/// the dictionary form laid out — the conjugation you just met is the
/// lesson.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/conjugate.dart';
import '../models.dart';
import '../services/speech.dart';
import '../theme.dart';
import '../widgets/common.dart';

Color registerColour(Register r) => switch (r) {
  Register.plain => C.text,
  Register.polite => C.mint,
  Register.contraction => C.violet,
};

/// Opens [entry]'s map, starting on the form spelled [onPage] if it has
/// one. Does nothing for a word that isn't a verb.
void openConjugation(BuildContext context, Entry entry, {String onPage = ''}) {
  final verb = Verb.fromEntry(entry);
  if (verb == null) return;
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => ConjugationScreen(
        verb: verb,
        meaning: entry.shortMeaning,
        onPage: onPage,
      ),
    ),
  );
}

class ConjugationScreen extends StatefulWidget {
  const ConjugationScreen({
    super.key,
    required this.verb,
    this.meaning = '',
    this.onPage = '',
  });

  final Verb verb;
  final String meaning;

  /// The form the verb had where it was met: the map opens on it.
  final String onPage;

  @override
  State<ConjugationScreen> createState() => _ConjugationScreenState();
}

class _ConjugationScreenState extends State<ConjugationScreen> {
  late final VerbForm _root = conjugate(widget.verb);
  late VerbForm _focus;

  /// The form spelled out in the card and traced in the route: the focus,
  /// or one of its end-of-branch forms tapped in the ring.
  late VerbForm _selected;

  /// The form met on the page, if it's on the map.
  VerbForm? _met;

  @override
  void initState() {
    super.initState();
    _met = widget.onPage.isEmpty ? null : _root.find(widget.onPage);
    // On the form itself when it has more to show, else on what it hangs
    // off, so it's seen among its neighbours.
    final met = _met;
    _focus = met == null
        ? _root
        : met.children.isNotEmpty
        ? met
        : (met.parent ?? _root);
    _selected = met ?? _root;
  }

  Future<void> _say(VerbForm f) async {
    final problem = await Speech.instance.say(f.text.reading);
    if (problem != null && mounted) toast(context, problem);
  }

  /// A form with more below it becomes the centre; one at the end of a
  /// branch is only selected, so the ring stays put.
  void _go(VerbForm f) {
    setState(() {
      if (f.children.isNotEmpty || f.parent != _focus) _focus = f;
      _selected = f;
    });
    _say(f);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.verb;
    return GridScaffold(
      onBack: () => Navigator.maybePop(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  v.written,
                  style: T.jp.copyWith(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (v.written != v.reading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(v.reading, style: T.bodyMd),
                ),
            ],
          ),
          Text(
            [
              v.groupName,
              if (widget.meaning.isNotEmpty) widget.meaning,
            ].join('  ·  '),
            style: T.bodyMd.copyWith(color: C.textDim),
          ),
          const SizedBox(height: 12),
          _Route(path: _selected.path, onTap: _go),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, box) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(
                  scale: Tween(begin: 0.92, end: 1.0).animate(a),
                  child: child,
                ),
              ),
              child: _Ring(
                key: ValueKey(_focus.id),
                size: box.maxWidth,
                focus: _focus,
                met: _met,
                selected: _selected,
                onTap: _go,
                onCentre: () => _go(_focus),
              ),
            ),
          ),
          _Detail(form: _selected, met: _met, onSay: () => _say(_selected)),
          const SizedBox(height: 14),
          const _Legend(),
        ],
      ),
    );
  }
}

/// The steps from the dictionary form to the focus, each with its rule.
class _Route extends StatelessWidget {
  const _Route({required this.path, required this.onTap});

  final List<VerbForm> path;
  final ValueChanged<VerbForm> onTap;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    reverse: true,
    child: Row(
      children: [
        for (final (i, f) in path.indexed) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Text(
                    f.rule,
                    style: T.monoSm.copyWith(color: C.lime, fontSize: 10),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: C.textDim,
                  ),
                ],
              ),
            ),
          ActionChip(
            onPressed: () => onTap(f),
            backgroundColor: i == path.length - 1 ? C.elevated : C.surface,
            side: BorderSide(color: i == path.length - 1 ? C.lime : C.border),
            label: Text(
              f.text.written,
              style: T.jp.copyWith(
                fontSize: 14,
                color: registerColour(f.register),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// The focus in the middle, its forms around it.
class _Ring extends StatelessWidget {
  const _Ring({
    super.key,
    required this.size,
    required this.focus,
    required this.met,
    required this.selected,
    required this.onTap,
    required this.onCentre,
  });

  final double size;
  final VerbForm focus;
  final VerbForm? met;
  final VerbForm selected;
  final ValueChanged<VerbForm> onTap;
  final VoidCallback onCentre;

  static const double _node = 80;

  @override
  Widget build(BuildContext context) {
    final kids = focus.children;
    // An oval, taller than wide: a phone is, and nodes are wider than they
    // are tall, so this spaces ten of them without overlap.
    final height = size * (kids.length > 6 ? 1.25 : 1.0);
    final centre = Offset(size / 2, height / 2);
    final rx = size / 2 - _node / 2 - 2;
    final ry = height / 2 - 36;
    final shrink = kids.length == 1 ? 0.75 : 1.0;
    // Clockwise from the top; a crowded ring turned half a step, so no
    // node sits on the top or bottom where the oval is tightest.
    final turn = kids.length > 6 ? 0.5 : 0.0;
    final spots = [
      for (var i = 0; i < kids.length; i++)
        centre +
            Offset(
              math.cos(-math.pi / 2 + 2 * math.pi * (i + turn) / kids.length) *
                  rx *
                  shrink,
              math.sin(-math.pi / 2 + 2 * math.pi * (i + turn) / kids.length) *
                  ry *
                  shrink,
            ),
    ];
    final onRoute = met?.path.toSet() ?? const <VerbForm>{};
    return SizedBox(
      width: size,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _Lines(centre, spots, [
                for (final k in kids) onRoute.contains(k),
              ]),
            ),
          ),
          for (final (i, k) in kids.indexed)
            Positioned(
              left: spots[i].dx - _node / 2,
              top: spots[i].dy - 34,
              width: _node,
              height: 68,
              child: _Node(
                form: k,
                onRoute: onRoute.contains(k) || identical(k, selected),
                more: k.children.length,
                onTap: () => onTap(k),
              ),
            ),
          Positioned(
            left: centre.dx - 62,
            top: centre.dy - 46,
            width: 124,
            height: 92,
            child: _Node(
              form: focus,
              centre: true,
              onRoute: onRoute.contains(focus),
              onTap: onCentre,
            ),
          ),
          if (kids.isEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: height * 0.18,
              child: Text(
                'Nothing more hangs off this one.\n'
                'Tap a step above to go back.',
                textAlign: TextAlign.center,
                style: T.bodyMd.copyWith(color: C.textDim, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _Lines extends CustomPainter {
  _Lines(this.centre, this.spots, this.lit);

  final Offset centre;
  final List<Offset> spots;
  final List<bool> lit;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (i, s) in spots.indexed) {
      canvas.drawLine(
        centre,
        s,
        Paint()
          ..color = lit[i] ? C.lime : C.border
          ..strokeWidth = lit[i] ? 2.5 : 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_Lines old) => true;
}

class _Node extends StatelessWidget {
  const _Node({
    required this.form,
    required this.onTap,
    this.centre = false,
    this.onRoute = false,
    this.more = 0,
  });

  final VerbForm form;
  final VoidCallback onTap;
  final bool centre;
  final bool onRoute;

  /// How many forms hang off it: shown as a count, so it's clear which
  /// nodes open further.
  final int more;

  @override
  Widget build(BuildContext context) {
    final colour = registerColour(form.register);
    return Material(
      color: centre ? C.elevated : C.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: onRoute || centre ? C.lime : colour.withValues(alpha: 0.5),
          width: onRoute || centre ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  more > 0 ? '${form.label} +$more' : form.label,
                  style: T.monoSm.copyWith(fontSize: 9, color: C.textDim),
                ),
                Text(
                  form.text.written,
                  style: T.jp.copyWith(
                    fontSize: centre ? 20 : 15,
                    fontWeight: FontWeight.w700,
                    color: colour,
                  ),
                ),
                if (!centre && form.rule.isNotEmpty)
                  Text(
                    form.rule,
                    style: T.monoSm.copyWith(fontSize: 9, color: C.lime),
                  ),
                if (centre)
                  const Icon(
                    Icons.volume_up_rounded,
                    size: 16,
                    color: C.textDim,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The focus, spelled out: what it means, how it's read, how it's made.
class _Detail extends StatelessWidget {
  const _Detail({required this.form, required this.met, required this.onSay});

  final VerbForm form;
  final VerbForm? met;
  final VoidCallback onSay;

  @override
  Widget build(BuildContext context) {
    final parent = form.parent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    form.label.toUpperCase(),
                    if (form.register == Register.polite) 'POLITE',
                    if (form.register == Register.contraction &&
                        form.label != 'casual')
                      'CASUAL',
                    if (identical(form, met)) 'ON THE PAGE',
                  ].join(' · '),
                  style: T.monoSm.copyWith(
                    color: identical(form, met) ? C.lime : C.textDim,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  form.text.written,
                  style: T.jp.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: registerColour(form.register),
                  ),
                ),
                if (form.text.written != form.text.reading)
                  Text(form.text.reading, style: T.bodyMd),
                const SizedBox(height: 4),
                Text(form.meaning, style: T.bodyMd),
                if (parent != null) ...[
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${parent.text.written}  '),
                        TextSpan(
                          text: form.rule,
                          style: const TextStyle(color: C.lime),
                        ),
                      ],
                    ),
                    style: T.monoSm.copyWith(color: C.textDim),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Play',
            onPressed: onSay,
            icon: const Icon(Icons.volume_up_rounded, color: C.lime),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Register r, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: registerColour(r),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: T.bodyMd.copyWith(fontSize: 12)),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        dot(Register.plain, 'plain (casual)'),
        dot(Register.polite, 'polite'),
        dot(Register.contraction, 'spoken contraction'),
      ],
    );
  }
}

/// The verbs among your words, to open a map from — or any verb, looked
/// up.
class VerbListScreen extends StatefulWidget {
  const VerbListScreen({super.key, this.mangaId});

  /// Whose words: one book's, or every word (null).
  final String? mangaId;

  @override
  State<VerbListScreen> createState() => _VerbListScreenState();
}

class _VerbListScreenState extends State<VerbListScreen> {
  final _search = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _lookup(String q) async {
    if (q.trim().isEmpty) return;
    final found = await AppScope.dictionaryOf(context).lookup(q.trim());
    if (!mounted) return;
    final verb = found.where((e) => Verb.fromEntry(e) != null).firstOrNull;
    if (verb == null) {
      setState(() => _problem = 'No verb found for 「${q.trim()}」.');
      return;
    }
    setState(() => _problem = null);
    openConjugation(context, verb);
  }

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.library(context);
    final seen = <String>{};
    final verbs = [
      for (final w in lib.wordsFor(widget.mangaId))
        if (Verb.fromEntry(w.entry) case final v?)
          if (seen.add(v.written)) (w, v),
    ];
    return GridScaffold(
      onBack: () => Navigator.maybePop(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
        children: [
          Text('Verb maps', style: T.headlineMd),
          const SizedBox(height: 4),
          Text(
            'Every form of a verb, and how each is made from the last.',
            style: T.bodyMd.copyWith(color: C.textDim),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.search,
            style: T.bodyLg,
            decoration: const InputDecoration(
              hintText: 'Any verb: 食べる, あそぶ, to swim…',
              fillColor: Colors.transparent,
            ),
            onSubmitted: _lookup,
          ),
          if (_problem != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _problem!,
                style: T.bodyMd.copyWith(color: C.textDim),
              ),
            ),
          const SizedBox(height: 16),
          Text('YOUR VERBS · ${verbs.length}', style: T.monoSm),
          const SizedBox(height: 6),
          if (verbs.isEmpty)
            Text(
              'No verbs among your words yet. Save some while reading, or '
              'import a JLPT pack from the Words tab.',
              style: T.bodyMd.copyWith(color: C.textDim),
            ),
          for (final (w, v) in verbs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => openConjugation(context, w.entry, onPage: w.surface),
              title: Text(
                v.written,
                style: T.jp.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                [
                  if (v.written != v.reading) v.reading,
                  w.entry.shortMeaning,
                  if (w.surface.isNotEmpty) 'met as ${w.surface}',
                ].join('  ·  '),
                style: T.bodyMd.copyWith(color: C.textDim, fontSize: 12),
              ),
              trailing: Text(switch (v.group) {
                VerbGroup.godan => 'godan',
                VerbGroup.ichidan => 'ichidan',
                _ => 'irregular',
              }, style: T.monoSm),
            ),
        ],
      ),
    );
  }
}
