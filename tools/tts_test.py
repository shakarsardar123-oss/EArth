#!/usr/bin/env python3
"""Hear (and measure) the app's Kurdish voice WITHOUT building the app.

It repeats exactly what VekolTtsBridge.kt does (text clean-up, numbers, chunks,
letter ids, the same ONNX model) and writes several .wav files that differ in
one setting each, so you can listen and pick the smoothest.

Setup in Termux (once):
    pkg install tur-repo -y
    pkg install python-numpy python-onnxruntime -y

Run from the project folder:
    python tools/tts_test.py
    python tools/tts_test.py "text to say"      # your own sentence

Files are written to ~/storage/downloads/tts_test/ : open them with the Files app.
"""
import json, os, re, sys, unicodedata, wave
import numpy as np
import onnxruntime as ort

MODEL = "android/app/src/main/assets/vekol/model.onnx"
CONFIG = "android/app/src/main/assets/vekol/model.onnx.json"
OUT = os.path.expanduser("~/storage/downloads/tts_test")
SR = 22050
MAX_CHUNK = 70
GAP = 0.13

TEXTS = [
    "سڵاو، من تێکسۆم. چۆنیت ئەمڕۆ؟ دەتوانم یارمەتیت بدەم لە هەموو شتێکدا.",
    "هەواڵەکانی ئەمڕۆ دەڵێن کە نرخی دۆلار لە بازاڕەکاندا کەمێک دابەزیوە، بەڵام کاریگەرییەکی ئەوتۆی نییە.",
]

# ---------- same text preparation as VekolTtsBridge.kt ----------
REPL = {'ك': 'ک', 'ھ': 'ه', 'ہ': 'ه', 'ۀ': 'ە', 'ة': 'ە', 'ى': 'ی', 'ﻯ': 'ی', 'ﺉ': 'ئ',
        'ٸ': 'ئ', 'ؤ': 'و', 'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', 'ڭ': 'گ',
        '\u200c': '', '\u200d': '', 'ـ': '', '“': '"', '”': '"', '’': "'", '‘': "'",
        '—': '-', '–': '-', '…': '.'}
DIG = str.maketrans("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹", "01234567890123456789")
ONES = ["سفر", "یەک", "دوو", "سێ", "چوار", "پێنج", "شەش", "حەوت", "هەشت", "نۆ"]
TEEN = ["دە", "یازدە", "دوازدە", "سیازدە", "چواردە", "پازدە", "شازدە", "حەڤدە", "هەژدە", "نۆزدە"]
TENS = ["", "", "بیست", "سی", "چل", "پەنجا", "شەست", "حەفتا", "هەشتا", "نەوەد"]


def normalize(t):
    return "".join(REPL.get(c, c) for c in t).translate(DIG)


def num_kurdish(n):
    if n < 10: return ONES[n]
    if n < 20: return TEEN[n - 10]
    if n < 100:
        t, o = divmod(n, 10)
        return TENS[t] if o == 0 else TENS[t] + " و " + ONES[o]
    if n < 1000:
        h, r = divmod(n, 100)
        w = "سەد" if h == 1 else ONES[h] + " سەد"
        return w if r == 0 else w + " و " + num_kurdish(r)
    if n < 1000000:
        th, r = divmod(n, 1000)
        w = "هەزار" if th == 1 else num_kurdish(th) + " هەزار"
        return w if r == 0 else w + " و " + num_kurdish(r)
    return str(n)


def replace_numbers(t):
    return re.sub(r"[0-9]+", lambda m: num_kurdish(int(m.group())) if int(m.group()) < 1000000 else m.group(), t)


def split_chunks(text, max_chunk=MAX_CHUNK):
    out = []
    sentences = [s.strip() for s in re.split(r"(?<=[.!?؟])\s+|\n+", text) if s.strip()]
    for s in sentences:
        last = s[-1]
        ending = ('؟' if last == '?' else last) if last in "!؟?" else '.'
        pieces = []
        if len(s) <= max_chunk:
            pieces.append(s)
        else:
            buf = ""
            for part in re.split(r"(?<=[،؛,;:])\s+", s):
                if len(part) > max_chunk + 20:
                    sub, cur = [], ""
                    for w in part.split(" "):
                        if cur and len(cur) + len(w) + 1 > max_chunk:
                            sub.append(cur); cur = w
                        else:
                            cur = w if not cur else cur + " " + w
                    if cur: sub.append(cur)
                else:
                    sub = [part]
                for piece in sub:
                    if buf and len(buf) + len(piece) + 1 > max_chunk:
                        pieces.append(buf); buf = piece
                    else:
                        buf = piece if not buf else buf + " " + piece
            if buf.strip(): pieces.append(buf)
        for i, p in enumerate(pieces):
            clean = p.strip().rstrip(".!?؟،؛,;:").strip()
            if clean:
                out.append(clean + (ending if i == len(pieces) - 1 else "."))
    return out


class Voice:
    def __init__(self):
        cfg = json.load(open(CONFIG, encoding="utf-8"))
        self.cfg = cfg
        self.map = {k: v[0] for k, v in cfg["phoneme_id_map"].items() if v}
        self.sess = ort.InferenceSession(MODEL, providers=["CPUExecutionProvider"])
        self.names = [i.name for i in self.sess.get_inputs()]
        print("model inputs:", self.names)
        print("config inference block:", cfg.get("inference"), "| speakers:", cfg.get("num_speakers"),
              "| sample_rate:", cfg.get("audio", {}).get("sample_rate"))

    def ids(self, text):
        n = unicodedata.normalize("NFD", normalize(text))
        pad, bos, eos = self.map.get("_", 0), self.map.get("^", 1), self.map.get("$", 2)
        ids = [bos, pad]
        for ch in n:
            if ch in self.map:
                ids += [self.map[ch], pad]
        ids.append(eos)
        return ids

    def synth(self, text, noise=0.667, length=1.0, noise_w=0.8, sid=0):
        ids = self.ids(text)
        if len(ids) <= 4: return np.zeros(0, np.float32)
        feeds = {"input": np.array([ids], np.int64),
                 "input_lengths": np.array([len(ids)], np.int64),
                 "scales": np.array([noise, length, noise_w], np.float32)}
        if "sid" in self.names: feeds["sid"] = np.array([sid], np.int64)
        return np.asarray(self.sess.run(None, feeds)[0]).reshape(-1).astype(np.float32)

    def say(self, text, chunked=True, **kw):
        pieces = split_chunks(replace_numbers(normalize(text.strip()))) if chunked else [text]
        parts = []
        for i, p in enumerate(pieces):
            a = self.synth(p, **kw)
            fade = min(int(SR * 0.006), len(a) // 2)
            if fade:
                a = a.copy(); a[:fade] *= np.linspace(0, 1, fade); a[-fade:] *= np.linspace(1, 0, fade)
            parts.append(a)
            if i < len(pieces) - 1: parts.append(np.zeros(int(SR * GAP), np.float32))
        return np.concatenate(parts) if parts else np.zeros(0, np.float32)


def lowpass(a, hz):
    spec = np.fft.rfft(a); f = np.fft.rfftfreq(len(a), 1 / SR)
    spec *= np.clip((hz + 1000 - f) / 1000, 0, 1)
    return np.fft.irfft(spec, len(a)).astype(np.float32)


def norm_peak(a, db=-3.0):
    p = np.abs(a).max() + 1e-9
    return a * (10 ** (db / 20) / p)


def metrics(a):
    """F0 (cepstrum), HNR (periodicity at that pitch) and where the energy sits, in the loud frames."""
    N, H = int(0.06 * SR), int(0.02 * SR)
    rms = np.array([np.sqrt((a[i:i + N] ** 2).mean()) for i in range(0, len(a) - N, H)])
    if len(rms) == 0 or rms.max() < 1e-4: return "silent"
    f0s, hnrs, low, high = [], [], 0.0, 0.0
    for k, i in enumerate(range(0, len(a) - N, H)):
        if rms[k] < 0.4 * rms.max(): continue
        fr = a[i:i + N]
        sp = np.abs(np.fft.rfft(fr * np.hanning(N), 8 * N)); fq = np.fft.rfftfreq(8 * N, 1 / SR)
        c = np.fft.irfft(np.log(sp + 1e-12)); q = np.arange(len(c)) / SR
        m = (q > 1 / 500) & (q < 1 / 60)
        f0 = 1 / q[m][int(np.argmax(c[m]))]
        lag = int(round(SR / f0)); s0 = fr - fr.mean()
        r = (s0[:-lag] * s0[lag:]).sum() / np.sqrt((s0[:-lag] ** 2).sum() * (s0[lag:] ** 2).sum() + 1e-12)
        f0s.append(f0); hnrs.append(10 * np.log10(max(min(r, .999), 1e-3) / (1 - min(r, .999))))
        p = sp ** 2; low += p[fq < 300].sum() / p.sum(); high += p[fq > 4000].sum() / p.sum()
    if not f0s: return "no loud frames"
    n = len(f0s)
    return (f"F0 {np.median(f0s):4.0f} Hz | HNR {np.median(hnrs):4.1f} dB | "
            f"energy <300Hz {100 * low / n:2.0f}% >4kHz {100 * high / n:2.0f}% | {len(a) / SR:.1f}s")


def save(path, a):
    pcm = (np.clip(a, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())


def main():
    os.makedirs(OUT, exist_ok=True)
    texts = [" ".join(sys.argv[1:])] if len(sys.argv) > 1 else TEXTS
    v = Voice()
    inf = v.cfg.get("inference", {}) or {}
    dn, dl, dw = inf.get("noise_scale", .667), inf.get("length_scale", 1.0), inf.get("noise_w", .35)
    print(f"hop_length={v.cfg.get('hop_length')} phoneme_type={v.cfg.get('phoneme_type')} speakers={v.cfg.get('speaker_id_map')}")
    variants = [
        ("A_kotlin_now", dict(noise=0.667, length=1.0, noise_w=0.8)),
        ("B_model_defaults", dict(noise=dn, length=dl, noise_w=dw)),
        ("C_noise0.30", dict(noise=0.30, length=dl, noise_w=dw)),
        ("D_noise0.00_no_sampling", dict(noise=0.0, length=dl, noise_w=dw)),
        ("E_speaker1_defaults", dict(noise=dn, length=dl, noise_w=dw, sid=1)),
        ("F_speaker1_noise0.00", dict(noise=0.0, length=dl, noise_w=dw, sid=1)),
        ("G_defaults_one_piece", dict(noise=dn, length=dl, noise_w=dw, chunked=False)),
    ]
    for ti, text in enumerate(texts, 1):
        print(f"\n=== text {ti}: {text}")
        for name, kw in variants:
            a = v.say(text, **dict(kw))
            path = f"{OUT}/t{ti}_{name}.wav"; save(path, a)
            print(f"{name:26s} {metrics(a)}")
    print("\nWAV files:", OUT)


if __name__ == "__main__":
    main()
