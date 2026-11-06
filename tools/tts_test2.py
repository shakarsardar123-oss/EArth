"""Termux test: old voice settings vs new ones (same chunking/pauses/post-process
as the app). Usage:  python tools/tts_test2.py [model.onnx]
Writes WAV files to ~/storage/downloads/tts_test2 and prints speed numbers."""
import json, math, os, re, sys, time, unicodedata, wave
import numpy as np
import onnxruntime as ort

MODEL = sys.argv[1] if len(sys.argv) > 1 else "assets/vekol/model.onnx"
CONFIG = MODEL + ".json"
OUT = os.path.expanduser("~/storage/downloads/tts_test2")
SR = 22050
os.makedirs(OUT, exist_ok=True)

cfg = json.load(open(CONFIG, encoding="utf-8"))
PH = {k: v[0] for k, v in cfg["phoneme_id_map"].items() if v}
sess = ort.InferenceSession(MODEL, providers=["CPUExecutionProvider"])

NORM = {'ك':'ک','ھ':'ه','ہ':'ه','ۀ':'ە','ة':'ە','ى':'ی','ﻯ':'ی','ﺉ':'ئ','ٸ':'ئ',
        'ؤ':'و','أ':'ا','إ':'ا','آ':'ا','ٱ':'ا','ڭ':'گ','\u200c':'','\u200d':'','ـ':'',
        '“':'"','”':'"','’':"'",'‘':"'",'—':'-','–':'-','…':'.'}
ONES = ['سفر','یەک','دوو','سێ','چوار','پێنج','شەش','حەوت','هەشت','نۆ']
TEENS = ['دە','یازدە','دوازدە','سیازدە','چواردە','پازدە','شازدە','حەڤدە','هەژدە','نۆزدە']
TENS = ['','','بیست','سی','چل','پەنجا','شەست','حەفتا','هەشتا','نەوەد']

def num(n):
    if n < 10: return ONES[n]
    if n < 20: return TEENS[n-10]
    if n < 100: return TENS[n//10] + ('' if n%10==0 else ' و ' + ONES[n%10])
    if n < 1000:
        w = 'سەد' if n//100==1 else ONES[n//100]+' سەد'
        return w + ('' if n%100==0 else ' و ' + num(n%100))
    if n < 1000000:
        w = 'هەزار' if n//1000==1 else num(n//1000)+' هەزار'
        return w + ('' if n%1000==0 else ' و ' + num(n%1000))
    return str(n)

def normalize(t):
    out = []
    for ch in t:
        o = ord(ch)
        if 0x660 <= o <= 0x669: out.append(chr(48 + o - 0x660)); continue
        if 0x6F0 <= o <= 0x6F9: out.append(chr(48 + o - 0x6F0)); continue
        out.append(NORM.get(ch, ch))
    return ''.join(out)

def numbers(t): return re.sub(r'\d+', lambda m: num(int(m.group())), t)

MAXC, FIRSTMIN = 70, 20
GAP_IN, GAP_END = 0.05, 0.16

def prepare_chunks(text):
    cleaned = numbers(normalize(text))
    sentences = [s.strip() for s in re.split(r'(?<=[.!?؟…])\s+|\n+', cleaned) if s.strip()]
    out = []
    for s in sentences:
        ending = '؟' if s.endswith(('؟','?')) else ('!' if s.endswith('!') else '.')
        body = re.sub(r'[.!?؟]+$', '', s)
        clauses = []
        for c in re.split(r'[،؛,;:]+', body):
            c = re.sub(r'[؟،؛]', ' ', c)
            c = re.sub(r'[^\u0600-\u06FF\u0750-\u077F\s]', ' ', c)
            c = re.sub(r'\s+', ' ', c).strip()
            if c: clauses.append(c)
        if not clauses: continue
        pieces, buf = [], ''
        start = len(out) == 0
        for c in clauses:
            if buf and len(buf) + 1 + len(c) <= MAXC:
                buf += ' ' + c
            else:
                if buf: pieces.append(buf); buf = ''
                if len(c) <= MAXC: buf = c
                else:
                    line = ''
                    for w in c.split(' '):
                        if line and len(line) + 1 + len(w) > MAXC: pieces.append(line); line = w
                        else: line = w if not line else line + ' ' + w
                    buf = line
            if start and not pieces and len(buf) >= FIRSTMIN:
                pieces.append(buf); buf = ''
        if buf: pieces.append(buf)
        for i, p in enumerate(pieces):
            last = i == len(pieces) - 1
            out.append((p + ending if last else p, GAP_END if last else GAP_IN))
    return out

def to_ids(text):
    t = unicodedata.normalize('NFD', normalize(text))
    ids = [PH.get('^', 1), PH.get('_', 0)]
    for ch in t:
        if ch in PH: ids += [PH[ch], PH.get('_', 0)]
    ids.append(PH.get('$', 2))
    return ids

def infer(ids, ns, ls, nw):
    out = sess.run(None, {
        'input': np.array([ids], dtype=np.int64),
        'input_lengths': np.array([len(ids)], dtype=np.int64),
        'scales': np.array([ns, ls, nw], dtype=np.float32),
        'sid': np.array([0], dtype=np.int64)})[0]
    return out.reshape(-1).astype(np.float64)

def post(w):
    if w.size == 0: return w
    peak = np.abs(w).max()
    if peak < 1e-4: return w[:0]
    idx = np.where(np.abs(w) >= peak * 0.02)[0]
    s = max(0, idx[0] - int(SR * 0.012)); e = min(len(w) - 1, idx[-1] + int(SR * 0.030))
    w = w[s:e+1]
    a = math.exp(-2 * math.pi * 6500 / SR)
    y = np.empty_like(w); prev = 0.0
    for i, x in enumerate(w):
        prev = (1 - a) * x + a * prev; y[i] = prev
    y *= min(0.92 / max(np.abs(y).max(), 1e-9), 4.0)
    f = min(int(SR * 0.006), len(y) // 2)
    if f: y[:f] *= np.linspace(0, 1, f); y[-f:] *= np.linspace(1, 0, f)
    return y

def save(path, w):
    pcm = (np.clip(w, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(SR); f.writeframes(pcm.tobytes())

def render_new(text, ns, ls, nw):
    chunks = prepare_chunks(text); wav = []; first = None; t0 = time.time()
    for i, (c, gap) in enumerate(chunks):
        ids = to_ids(c)
        if len(ids) <= 4: continue
        part = post(infer(ids, ns, ls, nw))
        if first is None: first = time.time() - t0
        wav.append(part)
        if i < len(chunks) - 1: wav.append(np.zeros(int(SR * gap)))
    return np.concatenate(wav), first, time.time() - t0

TEXTS = [
 "سڵاو، من تێکسۆم. چۆنیت ئەمڕۆ؟ دەتوانم یارمەتیت بدەم لە هەموو شتێکدا.",
 "هەواڵەکانی ئەمڕۆ دەڵێن کە نرخی دۆلار لە بازاڕەکاندا کەمێک دابەزیوە، بەڵام کاریگەرییەکی ئەوتۆی نییە.",
]
# name: (noise_scale, length_scale, noise_w)
VARIANTS = {
 "OLD_app":        (0.667, 1.00, 0.80),
 "N1_new_default": (0.55,  0.85, 0.60),
 "N2_steadier":    (0.45,  0.85, 0.50),
 "N3_model_noisew":(0.55,  0.85, 0.35),
 "N4_faster":      (0.55,  0.78, 0.60),
 "N5_more_lively": (0.667, 0.85, 0.80),
}
for ti, text in enumerate(TEXTS, 1):
    print(f"\n=== text {ti}")
    for name, (ns, ls, nw) in VARIANTS.items():
        w, first, total = render_new(text, ns, ls, nw)
        save(f"{OUT}/t{ti}_{name}.wav", w)
        print(f"{name:16s} audio {len(w)/SR:4.1f}s | first chunk ready {first:4.2f}s | all synth {total:4.2f}s")
print("\nWAV files:", OUT)
