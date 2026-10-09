#!/usr/bin/env python3
"""Builds assets/kanji/combos.json for Kanji Chain, the slingshot game.

Run:  python3 tool/build_kanji_combos.py

Every kanji that KanjiVG splits into exactly two named parts becomes a
combination: 明 = 日 + 月, 休 = 亻 + 木, and — because results are parts
too — chains: 林 = 木 + 木, then 森 = 木 + 林. Meanings, readings and the
school grade come from KANJIDIC, which is what orders the game from easy
to hard.

Sources, both redistributable, credited in Settings and the README:

  KanjiVG (Ulrich Apel)       CC BY-SA 3.0  how each kanji is built
  KANJIDIC2 (EDRDG) via
  jmdict-simplified           CC BY-SA 4.0  meanings, readings, grade

Only jouyou kanji (grades 1-8) are kept: the ones worth making.
"""

import gzip
import io
import json
import os
import sys
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CACHE = os.path.join(HERE, ".cache")
OUT = os.path.join(ROOT, "assets", "kanji", "combos.json")

KANJIVG_RELEASE = "https://api.github.com/repos/KanjiVG/kanjivg/releases/latest"
JMDICT_RELEASE = ("https://api.github.com/repos/scriptin/"
                  "jmdict-simplified/releases/latest")
KVG = "{http://kanjivg.tagaini.net}"


def log(msg):
    print(msg, flush=True)


def fetch(url, name):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        log(f"  downloading {name}")
        req = urllib.request.Request(url, headers={"User-Agent": "manabee-build"})
        with urllib.request.urlopen(req, timeout=600) as r, open(path, "wb") as f:
            f.write(r.read())
    with open(path, "rb") as f:
        return f.read()


def asset(release_url, cache_name, pick):
    meta = json.loads(fetch(release_url, cache_name + ".release.json"))
    for a in meta["assets"]:
        if pick(a["name"]):
            return fetch(a["browser_download_url"], cache_name), meta["tag_name"]
    raise SystemExit(f"no matching asset on {release_url}")


def load_kanjidic():
    blob, tag = asset(JMDICT_RELEASE, "kanjidic2-en.zip",
                      lambda n: n.startswith("kanjidic2-en-") and n.endswith(".zip"))
    with zipfile.ZipFile(io.BytesIO(blob)) as z:
        data = json.loads(z.read(z.namelist()[0]))
    out = {}
    for c in data["characters"]:
        grades = c["misc"].get("grade")
        if not grades:
            continue
        on, kun, meanings = [], [], []
        for g in (c.get("readingMeaning") or {}).get("groups", []):
            for r in g.get("readings", []):
                if r["type"] == "ja_on":
                    on.append(r["value"])
                elif r["type"] == "ja_kun":
                    kun.append(r["value"])
            meanings += [m["value"] for m in g.get("meanings", []) if m.get("lang", "en") == "en"]
        out[c["literal"]] = {
            "g": grades,
            "m": meanings[:3],
            "on": on[:2],
            "kun": kun[:2],
            "f": c["misc"].get("frequency"),
        }
    return out, tag


def load_kanjivg():
    blob, tag = asset(KANJIVG_RELEASE, "kanjivg.xml.gz", lambda n: n.endswith(".xml.gz"))
    root = ET.fromstring(gzip.decompress(blob))
    parts = {}
    for k in root.iter("kanji"):
        top = next(iter(k), None)  # the <g> for the kanji itself
        if top is None:
            continue
        literal = top.get(KVG + "element")
        kids = [g for g in top if g.tag == "g"]
        if not literal or len(kids) != 2:
            continue
        a, b = kids
        ea, eb = a.get(KVG + "element"), b.get(KVG + "element")
        if not ea or not eb:
            continue
        parts[literal] = {
            "a": ea,
            "b": eb,
            # The standalone kanji a radical form stands for: 亻 is 人.
            "ao": a.get(KVG + "original"),
            "bo": b.get(KVG + "original"),
            "p": a.get(KVG + "position") or "",
        }
    return parts, tag


def main():
    log("loading sources")
    dic, dic_tag = load_kanjidic()
    vg, vg_tag = load_kanjivg()
    log(f"  kanjidic {dic_tag}: {len(dic)} graded kanji; kanjivg {vg_tag}: "
        f"{len(vg)} two-part kanji")

    combos = []
    for k, p in vg.items():
        info = dic.get(k)
        # Grades 1-6 are taught in school, 8 is the rest of the jouyou set;
        # 9-10 are name-only kanji, not worth building.
        if not info or info["g"] > 8 or p["a"] == k or p["b"] == k:
            continue
        # A part has to be something a phone can draw: one character, not
        # a KanjiVG code name (CDP-8BC4), and not from CJK Extension B or
        # beyond, which ordinary Japanese fonts don't cover.
        if any(len(x) != 1 or ord(x) >= 0x20000 for x in (p["a"], p["b"])):
            continue
        combos.append({
            "k": k, "a": p["a"], "b": p["b"],
            **({"ao": p["ao"]} if p["ao"] else {}),
            **({"bo": p["bo"]} if p["bo"] else {}),
            "p": p["p"],
            "g": info["g"],
            "m": info["m"],
            "on": info["on"],
            "kun": info["kun"],
        })
    combos.sort(key=lambda c: (c["g"], c["k"]))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump({"kanjivg": vg_tag, "kanjidic": dic_tag, "combos": combos},
                  f, ensure_ascii=False, separators=(",", ":"))
    by_grade = {}
    for c in combos:
        by_grade[c["g"]] = by_grade.get(c["g"], 0) + 1
    chains = sum(1 for c in combos if c["a"] in {x["k"] for x in combos}
                 or c["b"] in {x["k"] for x in combos})
    log(f"wrote {OUT}: {len(combos)} combinations by grade {dict(sorted(by_grade.items()))}, "
        f"{chains} chain onto another, {os.path.getsize(OUT) // 1024} KB")


if __name__ == "__main__":
    sys.exit(main())
