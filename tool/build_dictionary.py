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

    used_pos = set()
    entries = forms = with_level = 0
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
        eid = int(w["id"])
        db.execute("INSERT INTO entry VALUES (?, ?)",
                   (eid, json.dumps(data, ensure_ascii=False, separators=(",", ":"))))
        entries += 1

        # Rank: common words first, then JLPT words, then the rest — what
        # a reader most likely meant when one spelling has several entries.
        rank = (0 if common else 2) + (0 if level else 1)
        for f in dict.fromkeys(kanji + kana):
            db.execute("INSERT OR IGNORE INTO form VALUES (?, ?, ?)", (f, eid, rank))
            forms += 1

    tags = jm.get("tags", {})
    for code in sorted(used_pos):
        db.execute("INSERT INTO pos VALUES (?, ?)", (code, tags.get(code, code)))

    version = f"{tag}"
    for k, v in {
        "jmdict": tag,
        "entries": str(entries),
        "forms": str(forms),
        "with_jlpt": str(with_level),
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
