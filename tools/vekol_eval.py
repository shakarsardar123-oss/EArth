#!/usr/bin/env python3
"""Measure the real quality of a speech-to-text CSV (columns: id, reference, prediction).

Exact string equality is too strict: a comma, a space inside a compound word or a
different form of the same letter makes a correct sentence "wrong". This script
reports the numbers that matter:

  * exact            - identical text
  * format-only      - identical after the same spelling, no punctuation, no spaces
  * WER              - word error rate (after normalising)
  * CER              - character error rate (spaces ignored, so "بەسەر" == "بە سەر")
  * buckets          - how many sentences are nearly right or badly wrong
  * top confusions   - the word pairs the model mixes up most often

Usage:  python tools/vekol_eval.py kurfem_inspection/sample100/vekol_baseline_100.csv
"""
import csv
import difflib
import re
import sys
import unicodedata
from collections import Counter

PUNCT = re.compile(r"[.,!?:;\"'()\[\]{}«»،؛؟…\-–—_*/\\]")
DIGIT_MAP = str.maketrans("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹", "01234567890123456789")
LETTERS = {
    "\u06BE": "\u0647", "\u06C1": "\u0647",   # heh variants
    "\u064A": "\u06CC", "\u0649": "\u06CC",   # yeh -> Kurdish yeh
    "\u0643": "\u06A9",                       # kaf -> Kurdish kaf
    "\u0640": "", "\u200c": "", "\u200d": "", # tatweel, zero-width
}
DIACRITICS = re.compile("[\u064B-\u065F\u0670]")


def norm(text: str) -> str:
    t = unicodedata.normalize("NFC", text or "").translate(DIGIT_MAP)
    t = "".join(LETTERS.get(c, c) for c in t)
    t = DIACRITICS.sub("", t)
    t = PUNCT.sub(" ", t.lower())
    return " ".join(t.split())


def lev(a, b) -> int:
    """Levenshtein distance between two sequences."""
    if not a:
        return len(b)
    if not b:
        return len(a)
    prev = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        cur = [i]
        for j, y in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x != y)))
        prev = cur
    return prev[-1]


def main(path: str) -> None:
    with open(path, encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    if not rows:
        print("no rows")
        return

    exact = fmt_only = 0
    w_err = w_tot = c_err = c_tot = 0
    buckets = Counter()
    worst = []
    confusions = Counter()

    for r in rows:
        ref_raw, hyp_raw = r["reference"] or "", r["prediction"] or ""
        ref, hyp = norm(ref_raw), norm(hyp_raw)
        rw, hw = ref.split(), hyp.split()
        rc, hc = ref.replace(" ", ""), hyp.replace(" ", "")

        if " ".join(ref_raw.split()) == " ".join(hyp_raw.split()):
            exact += 1
        if rc == hc:
            fmt_only += 1

        we, ce = lev(rw, hw), lev(rc, hc)
        w_err += we
        w_tot += len(rw)
        c_err += ce
        c_tot += len(rc)

        cer = ce / max(1, len(rc))
        if rc == hc:
            buckets["identical after normalising"] += 1
        elif cer <= 0.10:
            buckets["nearly right (CER <= 10%)"] += 1
        elif cer <= 0.25:
            buckets["several mistakes (CER 10-25%)"] += 1
        else:
            buckets["badly wrong (CER > 25%)"] += 1
        worst.append((cer, r.get("id", "?"), ref, hyp))

        sm = difflib.SequenceMatcher(None, rw, hw, autojunk=False)
        for op, i1, i2, j1, j2 in sm.get_opcodes():
            if op == "replace" and (i2 - i1) == (j2 - j1) == 1:
                confusions[(rw[i1], hw[j1])] += 1

    n = len(rows)
    print(f"sentences                : {n}")
    print(f"exact (raw text)         : {exact}")
    print(f"identical after spelling : {fmt_only}   (punctuation, spaces and letter forms ignored)")
    print(f"WER                      : {100.0 * w_err / max(1, w_tot):.1f}%")
    print(f"CER (spaces ignored)     : {100.0 * c_err / max(1, c_tot):.1f}%")
    print()
    for k, v in sorted(buckets.items(), key=lambda kv: -kv[1]):
        print(f"  {v:3d}  {k}")
    print("\nword pairs mixed up most often (reference -> heard):")
    for (a, b), c in confusions.most_common(15):
        if c > 1:
            print(f"  {c:2d}x  {a}  ->  {b}")
    print("\n8 worst sentences:")
    for cer, i, ref, hyp in sorted(worst, reverse=True)[:8]:
        print(f"  #{i}  CER {100 * cer:.0f}%\n     ref: {ref}\n     got: {hyp}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "vekol_baseline_100.csv")
