#!/usr/bin/env python3
"""Step 1 of building assets/sentences/: choose candidate sentences.

Downloads Tatoeba's exports (https://tatoeba.org, CC BY 2.0 FR) and keeps
Japanese sentences that

- were added by a user who declares Japanese as their native language
  (skill level 5) — Tatoeba's older imported sentences have known errors,
  and shadowing a wrong sentence drills the mistake;
- have an English translation;
- are short enough to shadow in one breath.

Writes build/sentences/candidates.tsv (id, Japanese, English, author).
Step 2, tool/grade_sentences.dart, grades each by the JLPT level of its
words with the app's own segmenter and dictionary and writes the asset:

    python3 tool/build_sentences.py
    flutter test tool/grade_sentences.dart
"""
import csv
import os
import sys
import tarfile
import urllib.request
import bz2

BASE = "https://downloads.tatoeba.org/exports/"
FILES = {
    "jpn_sentences_detailed.tsv": "per_language/jpn/jpn_sentences_detailed.tsv.bz2",
    "jpn-eng_links.tsv": "per_language/jpn/jpn-eng_links.tsv.bz2",
    "eng_sentences.tsv": "per_language/eng/eng_sentences.tsv.bz2",
}
CACHE = os.path.join("build", "tatoeba")
OUT = os.path.join("build", "sentences", "candidates.tsv")
MAX_CHARS = 25


def log(*a):
    print(*a, file=sys.stderr)


def fetch(name, path):
    dest = os.path.join(CACHE, name)
    if os.path.exists(dest):
        return dest
    log(f"  downloading {path}")
    with urllib.request.urlopen(BASE + path) as r:
        data = bz2.decompress(r.read())
    with open(dest, "wb") as f:
        f.write(data)
    return dest


def main():
    os.makedirs(CACHE, exist_ok=True)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    paths = {name: fetch(name, path) for name, path in FILES.items()}

    langs = os.path.join(CACHE, "user_languages.csv")
    if not os.path.exists(langs):
        log("  downloading user_languages")
        tar = os.path.join(CACHE, "user_languages.tar.bz2")
        urllib.request.urlretrieve(BASE + "user_languages.tar.bz2", tar)
        with tarfile.open(tar) as t:
            t.extractall(CACHE, filter="data")
    natives = set()
    with open(langs, newline="") as f:
        for row in csv.reader(f, delimiter="\t"):
            if len(row) > 2 and row[0] == "jpn" and row[1] == "5":
                natives.add(row[2])

    first_english = {}
    with open(paths["jpn-eng_links.tsv"]) as f:
        for line in f:
            jp, en = line.rstrip("\n").split("\t")
            first_english.setdefault(jp, en)

    candidates = []
    with open(paths["jpn_sentences_detailed.tsv"]) as f:
        for line in f:
            sid, _, text, user, *_ = line.rstrip("\n").split("\t")
            if user in natives and sid in first_english and len(text) <= MAX_CHARS:
                candidates.append((sid, text, user))

    wanted = {first_english[sid] for sid, _, _ in candidates}
    english = {}
    with open(paths["eng_sentences.tsv"]) as f:
        for line in f:
            eid, _, text = line.rstrip("\n").split("\t", 2)
            if eid in wanted:
                english[eid] = text

    kept = 0
    with open(OUT, "w") as out:
        for sid, text, user in candidates:
            en = english.get(first_english[sid])
            if not en:
                continue
            out.write(f"{sid}\t{text}\t{en}\t{user}\n")
            kept += 1
    log(f"  {kept} candidates from {len(natives)} native speakers -> {OUT}")


if __name__ == "__main__":
    main()
