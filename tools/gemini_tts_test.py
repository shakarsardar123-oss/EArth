#!/usr/bin/env python3
"""Does Gemini's text-to-speech speak Sorani Kurdish well, and which voice is closest
to a calm "Jarvis"-like assistant?  No installs needed (standard library only).

    export GEMINI_API_KEY="your key"        # the same key the app uses
    python tools/gemini_tts_test.py
    python tools/gemini_tts_test.py "your own Kurdish sentence"

Makes ~6 requests. WAV files go to ~/storage/downloads/gemini_tts_test/ .
"""
import base64, json, os, re, sys, urllib.error, urllib.request, wave

MODEL = "gemini-3.1-flash-tts-preview"
OUT = os.path.expanduser("~/storage/downloads/gemini_tts_test")
TEXT = "سڵاو، من تێکسۆم. چۆنیت ئەمڕۆ؟ دەتوانم یارمەتیت بدەم لە هەموو شتێکدا."
STYLE = "Say this in a calm, composed, confident and refined tone, like a very capable AI assistant:\n\n"
# (voice, use style prompt)
TESTS = [("Charon", False), ("Charon", True), ("Orus", False), ("Iapetus", False),
         ("Schedar", False), ("Alnilam", False)]


def synth(key, text, voice):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={key}"
    body = {"contents": [{"parts": [{"text": text}]}],
            "generationConfig": {"responseModalities": ["AUDIO"],
                                 "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": voice}}}}}
    req = urllib.request.Request(url, json.dumps(body).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=90) as r:
        d = json.load(r)
    part = d["candidates"][0]["content"]["parts"][0]["inlineData"]
    rate = 24000
    m = re.search(r"rate=(\d+)", part.get("mimeType", ""))
    if m: rate = int(m.group(1))
    return base64.b64decode(part["data"]), rate


def main():
    key = os.environ.get("GEMINI_API_KEY") or input("Gemini API key: ").strip()
    text = " ".join(sys.argv[1:]) or TEXT
    os.makedirs(OUT, exist_ok=True)
    print("text:", text)
    for voice, styled in TESTS:
        name = f"{voice}{'_styled' if styled else ''}"
        try:
            pcm, rate = synth(key, (STYLE + text) if styled else text, voice)
        except urllib.error.HTTPError as e:
            print(f"{name:16s} HTTP {e.code}: {e.read().decode('utf-8', 'ignore')[:300]}")
            continue
        except Exception as e:
            print(f"{name:16s} failed: {type(e).__name__}: {e}")
            continue
        path = f"{OUT}/{name}.wav"
        with wave.open(path, "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate); w.writeframes(pcm)
        print(f"{name:16s} ok  {len(pcm) / 2 / rate:.1f}s  {rate} Hz  -> {path}")
    print("\nOpen the files with the Files app and listen. Does it pronounce Sorani correctly?")


if __name__ == "__main__":
    main()
