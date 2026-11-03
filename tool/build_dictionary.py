#!/usr/bin/env python3
"""Builds assets/dict/jmdict.db, the offline dictionary, from open data.

Run:  python3 tool/build_dictionary.py

Lookups used to go to jisho.org one request at a time. Tapping a word in a
bubble checks every prefix from that character plus its deinflected forms
— tens of exact-match questions per tap — which a local index answers in
well under a millisecond, offline, and without leaning on an unofficial
API. jisho.org serves this same data (JMdict), so nothing is lost but its
WaniKani tags.

Sources, both redistributable, credited in the README and Settings:

  jmdict-simplified (JMdict, EDRDG)  CC BY-SA 4.0  the dictionary
  open-anki-jlpt-decks               MIT           JLPT levels N5-N1

Schema, built for one question — "which entries is this exact text?":

  form(text, entry, rank)   every kanji and kana spelling → entry id
  entry(id, data)           the entry as compact JSON, decoded in the app
  pos(code, text)           part-of-speech codes → their English names
  meta(key, value)          versions and counts, shown in Settings

Downloads are cached in tool/.cache/ (gitignored); delete it to refresh.
"""

import csv
import io
import json
import os
import sqlite3
import sys
import urllib.request
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CACHE = os.path.join(HERE, ".cache")
OUT_DIR = os.path.join(ROOT, "assets", "dict")
OUT = os.path.join(OUT_DIR, "jmdict.db")
VERSION_FILE = os.path.join(OUT_DIR, "version.txt")

JMDICT_RELEASE = ("https://api.github.com/repos/scriptin/"
                  "jmdict-simplified/releases/latest")
VOCAB_URL = ("https://raw.githubusercontent.com/jamsinclair/"
             "open-anki-jlpt-decks/main/src/n{level}.csv")


def log(msg):
    print(msg, flush=True)


def fetch(url, name):
    """Downloads to the cache, or returns what is already there."""
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        log(f"  downloading {name}")
        req = urllib.request.Request(url, headers={"User-Agent": "manabee-build"})
        with urllib.request.urlopen(req, timeout=600) as r, open(path, "wb") as f:
            f.write(r.read())
    with open(path, "rb") as f:
        return f.read()


def load_jmdict():
    """The full English JMdict. Found on the release by substring: the
    filenames carry a build timestamp, so an exact name rots within days."""
    meta = json.loads(fetch(JMDICT_RELEASE, "jmdict.release.json"))
    for asset in meta["assets"]:
        n = asset["name"]
        if n.startswith("jmdict-eng-") and "common" not in n and n.endswith(".zip"):
            blob = fetch(asset["browser_download_url"], "jmdict-eng.zip")
            with zipfile.ZipFile(io.BytesIO(blob)) as z:
                return json.loads(z.read(z.namelist()[0])), meta["tag_name"]
    raise SystemExit("no jmdict-eng asset on the latest release")


def load_jlpt():
    """(expression, reading) → easiest level, as 'N5'..'N1'. The lists are a
    community reconstruction — the JLPT has published none since 2010."""
    levels = {}
    for level in (1, 2, 3, 4, 5):  # harder first, so easier levels win
        data = fetch(VOCAB_URL.format(level=level), f"vocab-n{level}.csv").decode()
        for r in csv.DictReader(io.StringIO(data)):
            reading = r["reading"].strip()
            for expr in r["expression"].replace("；", ";").split(";"):
                expr = expr.replace("～", "").replace("〜", "").replace("~", "").strip()
                if expr:
                    levels[(expr, reading)] = f"N{level}"
                    levels.setdefault((expr, ""), f"N{level}")
    return levels


def main():
    log("loading sources")
    jm, tag = load_jmdict()
    jlpt = load_jlpt()
    log(f"  jmdict {tag}: {len(jm['words'])} entries")

    os.makedirs(OUT_DIR, exist_ok=True)
    tmp = OUT + ".tmp"
    if os.path.exists(tmp):
        os.remove(tmp)
    db = sqlite3.connect(tmp)
    db.executescript("""
        CREATE TABLE entry (id INTEGER PRIMARY KEY, data TEXT NOT NULL);
        -- WITHOUT ROWID: the table *is* its index on text, rather than a
        -- table plus a copy of it as an index — about half the size.
        CREATE TABLE form (text TEXT NOT NULL, entry INTEGER NOT NULL,
                           rank INTEGER NOT NULL,
                           PRIMARY KEY (text, entry)) WITHOUT ROWID;
        CREATE TABLE pos (code TEXT PRIMARY KEY, text TEXT NOT NULL);
        CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
    """)

    # Spoken frequency (tool/count_frequency.dart): counts of words as
    # written — by spelling when it has kanji or katakana, by kana when
    # written in hiragana (which homophone it was is decided below).
    # Optional: without it, entries rank as before.
    by_spelling = {}
    by_kana = {}
    freq_path = os.path.join(HERE, "data", "spoken_frequency.tsv")
    if os.path.exists(freq_path):
        with open(freq_path) as f:
            for line in f:
                if line.startswith("#") or not line.strip():
                    continue
                word, reading, count = line.rstrip("\n").split("\t")
                # A lone kana is a particle (ordered on its own) or a
                # fragment of a word the segmenter split: no evidence.
                if word == reading and len(word) == 1:
                    continue
                bucket = by_kana if word == reading else by_spelling
                bucket[word] = bucket.get(word, 0) + int(count)
        log(f"  spoken frequency: {len(by_spelling) + len(by_kana)} words")
    kana_owners = {}
    owners_path = os.path.join(HERE, "data", "kana_owners.tsv")
    if os.path.exists(owners_path):
        with open(owners_path) as f:
            for line in f:
                if line.startswith("#") or not line.strip():
                    continue
                kana_form, spelling = line.rstrip("\n").split("\t")
                kana_owners[kana_form] = spelling

    # Each count goes to one entry. A spelling to the likeliest entry
    # written that way — common first, then the easier JLPT level (人 is
    # ひと before the suffix じん). A kana form to the word named in
    # kana_owners.tsv, else the likeliest entry usually written in kana.
    best_for_spelling = {}
    best_for_kana = {}
    spoken = {}
    if by_spelling or by_kana:
        for w in jm["words"]:
            kanji = [k["text"] for k in w["kanji"]]
            kana = [k["text"] for k in w["kana"]]
            common = any(k.get("common") for k in w["kanji"] + w["kana"])
            uk = not kanji or any("uk" in s.get("misc", []) for s in w["sense"])
            levels = [jlpt.get((e, r)) for e in kanji + kana for r in kana]
            levels.append(jlpt.get(((kanji or kana)[0], "")))
            easiest = max((int(l[1]) for l in levels if l), default=0)
            # A suffix, prefix or counter (人 as じん, "-person") loses a tie
            # to the word itself (人, ひと).
            first_pos = w["sense"][0]["partOfSpeech"] if w["sense"] else []
            affix = any(p in ("suf", "pref", "ctr") for p in first_pos)
            prio = (0 if common else 1, 1 if affix else 0, -easiest)
            for k in dict.fromkeys(kanji + kana):
                if k in by_spelling and (k not in best_for_spelling
                                         or prio < best_for_spelling[k][0]):
                    best_for_spelling[k] = (prio, w["id"])
            for r in kana:
                if r not in by_kana:
                    continue
                named = kana_owners.get(r)
                if named is not None:
                    kprio = (0 if named in kanji else 1,) + prio
                else:
                    kprio = (0 if uk else 1,) + prio
                if r not in best_for_kana or kprio < best_for_kana[r][0]:
                    best_for_kana[r] = (kprio, w["id"])
        totals = {}
        for k, (_, eid) in best_for_spelling.items():
            totals[eid] = totals.get(eid, 0) + by_spelling[k]
        for r, (_, eid) in best_for_kana.items():
            totals[eid] = totals.get(eid, 0) + by_kana[r]
        for i, eid in enumerate(sorted(totals, key=lambda e: -totals[e])):
            spoken[eid] = i + 1
    with_freq = 0

    used_pos = set()
    entries = forms = with_level = 0
    for w in jm["words"]:
            kanji = [k["text"] for k in w["kanji"]]
            kana = [k["text"] for k in w["kana"]]
            common = any(k.get("common") for k in w["kanji"] + w["kana"])
            uk = not kanji or any("uk" in s.get("misc", []) for s in w["sense"])
            levels = [jlpt.get((e, r)) for e in kanji + kana for r in kana]
            # N5 the easiest, so the likeliest of several readings.
            easiest = max((int(l[1]) for l in levels if l), default=0)
            keys = [(k, r) for k in kanji for r in kana]
            keys += [(r, r) for r in kana]
            for key in keys:
                # A kana count: the word usually written in kana first.
                kana_key = key[0] == key[1]
                prio = (0 if (uk or not kana_key) else 1,
                        0 if common else 1, -easiest)
                if key in spoken and (key not in owner or prio < owner[key][0]):
                    owner[key] = (prio, w["id"])

    for w in jm["words"]:
        kanji = [k["text"] for k in w["kanji"]]
        kana = [k["text"] for k in w["kana"]]
        common = any(k.get("common") for k in w["kanji"] + w["kana"])

        senses = []
        for s in w["sense"]:
            glosses = [g["text"] for g in s["gloss"] if g.get("lang", "eng") == "eng"]
            if not glosses:
                continue
            used_pos.update(s["partOfSpeech"])
            senses.append({"g": glosses, "p": s["partOfSpeech"]})
        if not senses:
            continue

        # Spelling and reading together, any form; spelling alone only for
        # the entry's main form — 荒ぶ lists 遊ぶ as a rare spelling, and
        # matching on that alone made it N5.
        level = None
        for e in kanji + kana:
            for r in kana:
                level = level or jlpt.get((e, r))
        main = kanji[0] if kanji else kana[0]
        level = level or jlpt.get((main, ""))
        with_level += level is not None

        data = {"k": kanji, "r": kana, "s": senses}
        if common:
            data["c"] = 1
        # "Usually written in kana" (JMdict's uk) on any sense: ここ, ある,
        # いっぱい ("lots", though 一杯 "one cup" isn't). Shown in kana when
        # met in kana, not as 此処 / 有る / 一杯.
        if any("uk" in s.get("misc", []) for s in w["sense"]):
            data["u"] = 1
        if level:
            data["j"] = level
        # Its spoken rank, 1 the most said.
        if w["id"] in spoken:
            data["f"] = spoken[w["id"]]
            with_freq += 1
        eid = int(w["id"])
        db.execute("INSERT INTO entry VALUES (?, ?)",
                   (eid, json.dumps(data, ensure_ascii=False, separators=(",", ":"))))
        entries += 1

        # Rank: by how often it's said, when that's known — what a reader
        # most likely meant when one spelling has several entries — and
        # after those, common words, then JLPT words, then the rest.
        if "f" in data:
            rank = data["f"]
        else:
            rank = 1_000_000 + (0 if common else 200_000) + (0 if level else 100_000)
        # A kana spelling of a word normally written in kanji ranks behind
        # words actually written that way: は is the particle before it is
        # 羽 (a feather, read は), に before 荷. Words usually written in
        # kana (ここ, ある) keep their place.
        kanji_word = bool(kanji) and "u" not in data
        # Particles go first for their own kana: a small, closed set that
        # JMdict doesn't always flag common (で, の), and the reader colours
        # them by what comes back first.
        particle = any("prt" in sn["p"] for sn in senses[:1])
        for f in dict.fromkeys(kanji + kana):
            form_rank = rank
            # Softly: a very common verb met in kana (かえる → 帰る) still
            # beats a rare word that's usually written that way (蛙).
            if kanji_word and f in kana:
                form_rank = rank * 4
            if particle and f in kana:
                form_rank = -1
            db.execute("INSERT OR IGNORE INTO form VALUES (?, ?, ?)",
                       (f, eid, form_rank))
            forms += 1

    tags = jm.get("tags", {})
    for code in sorted(used_pos):
        db.execute("INSERT INTO pos VALUES (?, ?)", (code, tags.get(code, code)))

    # The app re-copies the database when this changes, so the spoken
    # frequency it was built with is part of it.
    version = f"{tag}-spoken{len(spoken)}b" if spoken else f"{tag}"
    for k, v in {
        "jmdict": tag,
        "entries": str(entries),
        "forms": str(forms),
        "with_jlpt": str(with_level),
        "with_spoken_frequency": str(with_freq),
        "version": version,
    }.items():
        db.execute("INSERT INTO meta VALUES (?, ?)", (k, v))
    db.commit()
    db.execute("VACUUM")
    db.close()
    os.replace(tmp, OUT)
    with open(VERSION_FILE, "w") as f:
        f.write(version + "\n")

    size = os.path.getsize(OUT) / 1e6
    log(f"wrote {OUT}: {entries} entries, {forms} forms, "
        f"{with_level} with a JLPT level, {size:.1f} MB")


if __name__ == "__main__":
    sys.exit(main())
