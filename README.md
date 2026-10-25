# manabee 🐝

Read Japanese manga, OCR the speech bubbles, write your own translation on the
page, and turn the words into flash cards and games. Android, Flutter, personal
sideload. Design: `DESIGN.md` and `ui-design/`.

applicationId: **`com.manabee.manabee`** (org + name default — a regenerated
`android/` folder gets it right on its own).

## Features

**Library**
- Import a manga from page images or `.cbz` / `.zip` archives, with a cover and title
- **Photograph a book** page by page with the in-app camera (it stays open: shoot, turn the page, shoot; retake the last one) — good for children's picture books — or pick **photos you already took, put in the order they were taken** (EXIF capture time, then the camera's file-name timestamp, then the file date). Photos are turned upright and scaled to 2400 px on the long side as they're imported
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
- **Tap a word to look it up**: the bubble's text is tappable character by character; a tap finds the longest dictionary word starting there (as is, or with conjugation and a trailing particle undone) and highlights it. Long-press one character and tap another to look up any span by hand, or **drag the highlight** sideways to take in more characters or fewer (grab its end to move the end, its start to move the start). When a span only makes a word with one character read the way OCR commonly confuses it (ば/ぱ, つ/っ, ロ/口…), it's looked up as that word — 「いっばい」 is read as 「いっぱい」 — with **Fix text** to correct the bubble; the diary check suggests the same fix. The **last word of a sentence** is looked up verbs (then adjectives) first, since that's where Japanese puts them: 「いえにかえるよ」 gives 帰る before 蛙 ("frog"). Nothing is hidden, only reordered. The bubble's text shows its **words spaced apart** and its **particles in purple** (が, は, を, に…), so a sentence's structure is visible before you tap anything; a particle right after a word is read as a particle (人**が**いっぱい, not 害), and the copula です stays whole. No up-front word splitting, which fails on hiragana-only text
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
- **JLPT packs**: the same new-book tile offers N5 to N1, each made into a commonplace book from the offline dictionary's level tags (about 900 N5 words, 800 N4, 2,400 N3, 1,800 N2, 2,800 N1 — community lists; the JLPT itself publishes none). Common words come first; **Focus next 20** works through a pack in order. Importing a level again only adds what's missing, so progress is kept

**Study** — flash cards at the top, then three sections: **Writing** (Diary, Quiz, Match, Kanji Chain), **Listening** (Listen, Listening Quiz, Listening Match), **Speaking** (Shadowing)
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
- **Verb maps**: every form of a verb as a map — the form in focus in the middle, the forms built from it in a ring, each line a rule (る → ない, く → いて). Plain (casual) forms, polite (ます) forms in mint, and the spoken contractions manga is full of in violet: 食べてる, 食べちゃう/読んじゃう, 食べとく, 食べなきゃ/食べなくちゃ, 食べん, 食べちゃだめ, 見れる. Tap a form to hear it; tap a step of the route to go back. Handles godan, ichidan, する (and 勉強 → 勉強する), 来る (来ない read こない), and the exceptions (行って, ある → ない, いらっしゃいます, くれ). Open one from **Study → Verb maps** (your verbs, or any), from any verb's dictionary entry, or from a verb in a bubble: tapping 食べちゃった opens the map on it with the route 食べる → 食べて → 食べてしまう → 食べちゃう → 食べちゃった laid out. Every form on every map can also be tapped in a bubble — checked in the tests across all ~285 N5/N4 verbs. **Add** on any form saves it as its own card (食べちゃった, "食べる (to eat) · te-form → completely → casual → past: ended up doing") in the **Verb forms** book, so it studies like any word
- **Particles**: 17 rules — を for the thing acted on, に for where something goes or is, で for where an action happens… — practised as gaps (それ＿食べる, そこ＿行く, 七時＿起きる) built from your own verbs, the verb deciding the particle by its kind (JMdict's transitive/intransitive, motion, existence), plus hand-written gaps for what no verb decides (私＿本, 犬＿好き). A wrong answer explains the rule; は and も, fine in almost any gap, are never offered as wrong
- **Joining words**: 13 joiners (から, ので, けど, のに, 前に, まで, ながら, て, てから, ても, たら, たり, ば), each attached to its own verb form: pick 読んでも for "読む + even if" over the same joiner on the wrong form (読むても) or a different joiner (読むのに). Feedback shows the form it hangs on, with a link to that node on the verb map. Real Japanese is never offered as a mistake (読んだから is fine)
- Both drills are scheduled per rule, not per question — due rules first, then new ones — and list every rule with its progress under **Rules**
- **Diary**: dated entries written in Japanese. **Check** (offline) shows the entry split into words with particles in purple and marks what the dictionary doesn't know (usually a typo — runs of one-kana "words" count too), doubled particles (がが), and polite and plain style mixed in one entry. Tap any word to look it up and save it to the **Diary words** commonplace book. It catches mistakes, not unnatural phrasing — there's no good offline Japanese grammar checker
- The **Listening** section (Listen, Listening Quiz, Listening Match) always works on your **focus words** when you have some, whichever deck is picked at the top of Study; with no focus set it follows the deck
- **Listening Quiz**: hear the word, pick its meaning; the Japanese is shown only once you've answered
- **Listening Match**: the Japanese tiles are speakers — tap to hear, pair with the meaning
- **Shadowing**: hear the phone's voice say the word (only the word — bubble sentences come from OCR and aren't checked, so they're not drilled) — record yourself, then play **You** and **Native** side by side as often as you like and grade yourself Again / Hard / Good / Easy. No fake pronunciation score: you judge, as in shadowing practice generally. Speaking has its own spaced-repetition schedule per word, separate from flash cards (saying and recognising are different skills); recordings stay on the phone
- **Sentence shadowing**: the same loop with whole sentences written by native speakers, from [Tatoeba](https://tatoeba.org) (CC BY 2.0 FR; each shown with its number and author). Choose **Focus words** — each focus word in up to three sentences, easiest first, the word lit — or a level, **N5 / N4 / N3**, shortest first. Only sentences by users who declare Japanese as their native language, and only those whose every word is on a JLPT list at that level or below (katakana loanwords and names aside), graded by the app's own segmenter and dictionary at build time (`tool/build_sentences.py`, then `flutter test tool/grade_sentences.dart`). Its own schedule and daily new-sentence limit
- **Kanji Chain**: a slingshot game. Pull back and fire a kanji part into the part it combines with — 日 into 月 makes 明, with its meaning and readings. What you build stays on the board, so it chains: 木 + 木 → 林, then 木 + 林 → 森, scoring more. Three hearts; every loaded part can combine with something on the board; it starts with grade 1–2 kanji and widens as you score. 1,619 combinations from KanjiVG + KANJIDIC (`tool/build_kanji_combos.py`)
- **Focus**: study a few words at a time instead of a deck that only grows — tick words (filtered by book) or tap **Next 20** for the next 20 not-yet-learned, then the 20 after. The focus set is a deck of its own, first among the chips; words left out keep their progress

**Other**
- Japanese text-to-speech using the phone's own voice, adjustable speed
- **Listen mode**: the deck as an audio playlist — each word in Japanese, a pause to recall it (adjustable "think time"), the meaning in English, a soft chime, next. Built on the learning research: **retrieval** (a pause to recall before the answer; meaning-first for the harder recall), **weakest first** (forgotten and still-learning words, then new, then reviews, learned last — or shuffled, or as saved), **graduated-interval repeats** (Pimsleur: new and weak words come back 2 items later, then 6 after that), **adaptive pause** (more think time for new words, less for learned ones), **interleaving** (shuffled, and reshuffled each loop), and **context** (the manga sentence a word came from, after it). Options in a sheet (⚙): think time, playlist order, chime before/after, Japanese or meaning first, say meaning, Japanese twice, loop, repeats, adaptive pause, sentence. Practice only; it doesn't move the flash-card schedule
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
  instead of failing silently. Kanji Chain's parts come from
  [KanjiVG](https://kanjivg.tagaini.net) (© Ulrich Apel, CC BY-SA 3.0), with
  meanings and readings from KANJIDIC (EDRDG, CC BY-SA 4.0). The Listen chime is `assets/sounds/tone.wav`,
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
