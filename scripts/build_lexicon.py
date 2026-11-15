#!/usr/bin/env python3
"""Optional expansion from MIT-licensed McBopomofo sources, during build only."""
from pathlib import Path
from urllib.request import Request, urlopen
from collections import defaultdict
import sys
import math

ROOT=Path(__file__).resolve().parents[1]
TARGET=ROOT/"Keyboard/Resources/lexicon.tsv"
BASE="https://raw.githubusercontent.com/openvanilla/McBopomofo/master/Source/Data/"
PHONETIC=set("ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙㄧㄨㄩㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦ˙ˊˇˋ")
def fetch(name):
    req=Request(BASE+name,headers={"User-Agent":"NineGridZhuyin/1.0"})
    return urlopen(req,timeout=50).read().decode("utf-8-sig")
def valid(s):
    return bool(s) and all(c in PHONETIC for c in s)
def main():
    records={}
    for line in TARGET.read_text(encoding="utf-8").splitlines():
        parts=line.split("\t")
        if len(parts)>=3 and not parts[0].startswith("#"):
            records[(parts[0],parts[1])]=int(parts[2])
    counts = {}
    for line in fetch("phrase.occ").splitlines():
        parts = line.split()
        if len(parts) >= 2 and not parts[0].startswith("#"):
            try:
                counts[parts[0]] = max(0, int(parts[1]))
            except ValueError:
                continue
    def frequency(word, fallback):
        if word not in counts:
            return fallback
        return min(1650, int(50 + 190 * math.log10(counts[word] + 1) + 80 * (len(word) - 1)))
    base=fetch("BPMFBase.txt")
    ranks=defaultdict(int)
    for line in base.splitlines():
        parts=line.split()
        if len(parts)<2: continue
        word,reading=parts[0],parts[1]
        if not valid(reading) or not word: continue
        score=frequency(word, max(1,700-ranks[reading]*8))
        ranks[reading]+=1
        records[(word,reading)]=max(score,records.get((word,reading),0))
    phrases=fetch("BPMFMappings.txt")
    for line in phrases.splitlines():
        parts=line.split()
        if len(parts)<3 or parts[0].startswith("#"): continue
        word=parts[0]
        if word.startswith(("%","_")): continue
        reading=parts[1:]
        if len(reading)!=len(word) or not all(valid(p) for p in reading): continue
        key=(word," ".join(reading))
        records[key]=max(frequency(word, 100),records.get(key,0))
    # Retain single-character coverage and the most frequent phrases within the
    # keyboard extension's memory budget. The seed remains in the output.
    seed_keys = set()
    for line in TARGET.read_text(encoding="utf-8").splitlines():
        parts = line.split("\t")
        if len(parts) >= 2 and not parts[0].startswith("#"):
            seed_keys.add((parts[0], parts[1]))
    frequent_phrases = sorted(
        ((key, score) for key, score in records.items() if len(key[0]) > 1),
        key=lambda item: (-item[1], item[0]),
    )[:50000]
    keep = seed_keys | {key for key in records if len(key[0]) == 1} | {key for key, _ in frequent_phrases}
    records = {key: score for key, score in records.items() if key in keep}
    rows=sorted(((word,reading,rank) for (word,reading),rank in records.items()),key=lambda x:(x[1],-x[2],x[0]))
    output="# MIT-licensed McBopomofo data plus local seed; see THIRD_PARTY_NOTICES.md\n"
    output+="\n".join(f"{word}\t{reading}\t{rank}" for word,reading,rank in rows)+"\n"
    TARGET.write_text(output,encoding="utf-8")
    print(f"Offline dictionary contains {len(rows):,} entries")
if __name__=="__main__":
    try: main()
    except Exception as exc:
        print(f"Dictionary expansion failed; keeping bundled seed: {exc}",file=sys.stderr)
        sys.exit(1)

