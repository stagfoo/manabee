# manabee 🐝

Read Japanese manga, OCR the speech bubbles, write your own translation on the
page, and turn the words into flash cards and games. Android, Flutter, personal
sideload. Design: `DESIGN.md` and `ui-design/`.

applicationId: **`com.manabee.manabee`** (org + name default — a regenerated
`android/` folder gets it right on its own).

## Features

**Library**
- Import a manga from page images or `.cbz` / `.zip` archives, with a cover and title
- Archives split into chapters automatically (one per archive, or one per folder inside)
- Pages sorted naturally (`2.jpg` before `10.jpg`) and copied into app storage
- Cover carousel with chapter progress, plus words-learned % per manga
- Chapter list with read state (unread / in progress / complete) and bubble counts
- Resume from the last page read; edit chapters and cover, or delete a manga

**Reader**
- Right-to-left paging (switchable in settings), pinch to zoom
- **On-device Japanese OCR**: drag a box over a speech bubble to read it
- **Scan page**: outline every text block on the page, tap one to read it
- Vertical text put back into right-to-left column order; editable OCR text for fixing mistakes
- **Tap a word to look it up**: the bubble's text is tappable character by character; a tap finds the longest dictionary word starting there (as is, or with conjugation and a trailing particle undone) and highlights it. Long-press one character and tap another to look up any span by hand. The bubble's text shows its **words spaced apart** and its **particles in purple** (が, は, を, に…), so a sentence's structure is visible before you tap anything; a particle right after a word is read as a particle (人**が**いっぱい, not 害), and the copula です stays whole. No up-front word splitting, which fails on hiragana-only text
- **Conjugations undone before lookup** (a small built-in deinflector, as in Yomichan): あそべるよ → strip よ → potential → 遊ぶ. Covers polite, past, te-form, negative, potential, passive, causative, volitional, たい, conditionals, ている/てる, ちゃう, adjectives, する/くる. The dictionary has no entries for conjugated forms, so this is what finds them
- The form seen on the page is kept with the word ("On the page: あそべる · potential") and highlighted in its sentence
- Dictionary entry in the sheet: kanji, reading, romaji, meanings, JLPT tag, audio
- **Translation bubbles**: write your own translation and place it on the page; long-press to place, long-press-drag to move
- Bubbles stay on their balloon at any zoom and screen size
- **Edit a bubble**: one sheet for its Japanese and your translation (pencil, or tap its text)
- **Fix what OCR missed**: look the piece up, then "Add「食」to bubble" appends it
- **Merge bubbles**: tap merge, then tap another bubble; text and regions combine in reading order (right column before left, top before bottom), whichever you tap first
- Japanese typed into the translation field is moved to the Japanese field
- Editing the text is on the pencil icon
- Chapter-complete page with a jump to the next chapter

**Words**
- One deck per manga, shown as ENGLISH · ROMAJI · FURIGANA · KANJI rows
- Dictionary search to add words by hand
- Bubbles view: every translation you've written, tap to jump to its page
- Saved words keep their full dictionary entry, so they work offline
- **Commonplace books**: word lists of your own with no pages (days of the week, a topic, words from a song). Make one from the Words tab, then add words from the dictionary in Japanese or English; added results turn mint. They study like any other deck and stay off the reading shelf

**Study**
- **Flash cards, scheduled like Anki** (SM-2): furigana / kanji / romaji front, full entry on the back
- **Again / Hard / Good / Easy**, each button showing when the card comes back (`1m`, `10m`, `1d`, `4d`)
- Learning steps of 1 and 10 minutes within the sitting, then day intervals that grow with each card's ease
- A forgotten card is relearned with its interval halved, not reset
- Daily queue: reviews due today (most overdue first), learning cards, and a ration of new cards (default 20/day, set in Settings, shared across decks)
- New / Learning / Review counts, Undo, and "study 10 more new cards" when you're done
- Review screen laid out like jlptbenkyo / Anki: the word big under its JLPT level, the answer added under a rule (reading, meanings, all senses, the bubble it came from), red / orange / green / blue grade buttons, Anki's `new + learning + review` counts
- Study tab: a "Due today" card with the counts and a Study button, words-learned progress, practice games below
- "Learned" means a card that has reached a week-long interval
- A word keeps its sentence only if it actually appears in it (conjugations count), with the word highlighted
- Confetti for finishing the day's cards, a quiz or a match board 🎉
- **Quiz**: multiple choice, alternating word → meaning and meaning → word (practice; doesn't change the schedule)
- **Match**: pair Japanese tiles with meanings, timed, with a miss count (practice)
- Study all words, one manga's, or one commonplace book's
- **Focus**: study a few words at a time instead of a deck that only grows — tick words (filtered by book) or tap **Next 20** for the next 20 not-yet-learned, then the 20 after. The focus set is a deck of its own, first among the chips; words left out keep their progress

**Other**
- Japanese text-to-speech using the phone's own voice, adjustable speed
- **Listen mode**: the deck as an audio playlist — each word in Japanese, a pause to recall it (adjustable "think time"), the meaning in English, a soft chime, next. Options: chime before or after each word, Japanese first or meaning first (English → recall the Japanese, with the Japanese hidden until it's said), say the meaning or not, Japanese twice, loop, shuffle. Practice only; it doesn't move the flash-card schedule
- Everything stored on-device in one JSON file; the dictionary is offline too, and only searching by English meaning goes online

## Install

Add `https://github.com/stagfoo/manabee` in
[Obtainium](https://github.com/ImranR98/Obtainium) and it will pick up every
release. Or download the APK from
[Releases](https://github.com/stagfoo/manabee/releases). Android 7.0+, arm64.

## How it works

| Tab | What's there |
| --- | --- |
| 🏠 **Library** | Cover carousel, chapter progress, how many of the focused manga's words you've learned. Tap a cover for its chapters; the last tile imports a new manga. |
| 💬 **Words** | One deck per manga. Each deck lists saved words (ENGLISH · ROMAJI · FURIGANA · KANJI), a dictionary search to add more, and a *Bubbles* view of every translation you've written. |
| 🗃 **Study** | Anki-style flash cards (Again / Hard / Good / Easy, SM-2), plus a multiple-choice quiz and a pair-matching game for practice, over all words or one manga's. |

### Importing

Cover image, title, then chapters, from either:
- **page images**: pick every page of one chapter. They're sorted naturally, so `2.jpg` comes before `10.jpg`.
- **.cbz / .zip**: one chapter per archive, or one per folder inside it.

Everything is **copied** into app storage. Picked files on Android are
temporary content URIs, and a manga shouldn't stop opening because its source
folder moved.

### Reading

The reader has two modes, because one drag can't mean two things:

- **OCR OFF** (reading): swipe to turn pages (right-to-left by default), pinch
  to zoom. **Long-press the page** to place a translation bubble there.
  **Long-press-drag a bubble** to move it.
- **OCR ON**: paging is paused and the page stays at its current zoom, so zoom
  in first for small balloons. **Drag a box over a speech balloon** to read it.
  **SCAN** finds every text block on the page and outlines it; tap one to read
  it.

A read bubble opens the sheet: its Japanese (tap to fix OCR mistakes), chips
for each word in it (tap to look one up), and the dictionary entry. **+** saves
the word to the manga's deck. **Translate bubble** writes your translation onto
the page.

Bubble positions are stored normalised to the page image, not in screen
pixels, so they stay on their balloon at any zoom level and on any screen.

### Where the data comes from

- **OCR**: Google ML Kit, on-device, with the Japanese model bundled (about
  half of the APK's ~50 MB), and it needs no network. Crops are
  upscaled and padded before recognition, and vertical text is put back into
  right-to-left column order (`lib/core/ocr_text.dart`).
- **Dictionary**: [JMdict](https://www.edrdg.org/jmdict/j_jmdict.html)
  (© EDRDG, CC BY-SA 4.0) via
  [jmdict-simplified](https://github.com/scriptin/jmdict-simplified), all
  ~219k entries, **offline** in `assets/dict/jmdict.db` (44 MB, ~16 MB in the
  APK). JLPT levels from
  [open-anki-jlpt-decks](https://github.com/jamsinclair/open-anki-jlpt-decks)
  (MIT) — a community reconstruction; the JLPT has published no list since
  2010. Words usually written in kana are shown in kana (ここ, not 此処).
  Rebuild with `python3 tool/build_dictionary.py`. Searching by English
  meaning still goes to [jisho.org](https://jisho.org), which has the index
  for that.
- **Finding words**: tap where a word starts (`lib/core/scan.dart`): the
  longest exact dictionary match from there, with conjugations undone
  (`lib/core/deinflect.dart`).
- **Audio**: the device's own text-to-speech voices — Japanese for words,
  English for meanings in Listen mode. If one isn't installed, the app says so
  instead of failing silently. The Listen chime is `assets/sounds/tone.wav`,
  generated by `tool/make_tone.py`.

Everything else (library, bubbles, words, progress) is one JSON file in app
storage: `library.json`, written atomically.

## Layout

```
lib/core/       pure Dart, fully unit-tested: kana→romaji, segmenter, page
                geometry, OCR text ordering, SM-2 scheduler + study session, quiz/match games,
                natural sort + archive grouping
lib/services/   thin plugin wrappers: store, importer, ocr, dictionary (+ jisho for English), speech
lib/screens/    UI
lib/widgets/    shared pieces (grid ground, header, word rows, entry detail)
```

## Building

```sh
flutter test
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

Signed with the committed `android/app/debug.keystore`, which is debug-only
and committed on purpose, so local and CI builds install over each other.
`android/app/proguard-rules.pro` keeps ML Kit's reflectively-loaded classes and
tells R8 the other scripts' recognisers are absent on purpose.

`scripts/release.sh` bumps the version, runs analyze, the tests and the build,
commits, pushes, checks the APK's versionName, and publishes a GitHub release
in Obtainium's shape: the tag is the bare version, with one arm64 APK. CI
(`.github/workflows/build.yml`) is manual-only.

## Original idea

a manga app that loads, japanese anime, has OCR to read the kanji from the bubble. allows you to learn from the book with flash cards and games once the text and words are extracted.

the use can place bubbles on top or next to the translation to slowly translate the book themselves
