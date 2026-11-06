import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// One piece of text that is synthesized on its own.
/// [gapAfter] is the silence (seconds) to insert after it.
class TtsChunk {
  const TtsChunk(this.text, this.gapAfter);

  final String text;
  final double gapAfter;
}

class VekolTtsService {
  VekolTtsService._();

  static final VekolTtsService instance = VekolTtsService._();

  static const String _modelAsset = 'assets/vekol/model.onnx';

  // ---- voice tuning (change only here) -------------------------------------
  // noise_scale : lower = steadier, less trembling (too low = monotone)
  // length_scale: lower = faster speech (1.0 = model default, 0.85 = ~18% faster)
  // noise_w     : lower = more even rhythm, higher = more varied timing
  static const double _noiseScale = 0.55;
  static const double _lengthScale = 0.85;
  static const double _noiseW = 0.6;

  // ---- chunking / pauses ----------------------------------------------------
  static const int _sampleRate = 22050;
  static const int _firstChunkMin = 20; // first chunk is short -> fast start
  static const int _maxChunkLength = 70;
  static const double _gapInsideSentence = 0.05; // seconds
  static const double _gapAfterSentence = 0.16; // seconds
  static const double _lowpassHz = 6500;

  OrtSession? _session;
  Future<void>? _initFuture;

  Future<void> initialize() {
    if (_session != null) return Future<void>.value();
    return _initFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    try {
      final runtime = OnnxRuntime();
      _session = await runtime.createSessionFromAsset(_modelAsset);
    } catch (_) {
      _initFuture = null;
      rethrow;
    }

    // Warm-up: the very first inference is slow; do it now, not on the
    // user's first answer.
    try {
      await synthesizeIds(_textToIds('سڵاو.'));
    } catch (_) {}
  }

  Future<void> dispose() async {
    final session = _session;
    _session = null;
    _initFuture = null;

    if (session != null) {
      await session.close();
    }
  }

  static const Map<String, int> _phonemeIds = {
    '_': 0,
    '^': 1,
    r'$': 2,
    ' ': 3,
    '\n': 4,
    '!': 5,
    '"': 6,
    '-': 7,
    '.': 8,
    ':': 9,
    '،': 10,
    '؛': 11,
    '؟': 12,
    'ء': 13,
    'ا': 14,
    'ب': 15,
    'ت': 16,
    'ج': 17,
    'ح': 18,
    'خ': 19,
    'د': 20,
    'ر': 21,
    'ز': 22,
    'س': 23,
    'ش': 24,
    'ع': 25,
    'غ': 26,
    'ف': 27,
    'ق': 28,
    'ل': 29,
    'م': 30,
    'ن': 31,
    'ه': 32,
    'و': 33,
    'ي': 34,
    'ٔ': 35,
    'پ': 36,
    'چ': 37,
    'ڕ': 38,
    'ژ': 39,
    'ڤ': 40,
    'ک': 41,
    'گ': 42,
    'ڵ': 43,
    'ۆ': 44,
    'ی': 45,
    'ێ': 46,
    'ە': 47,
  };

  static const Map<String, String> _normalization = {
    'ك': 'ک',
    'ھ': 'ه',
    'ہ': 'ه',
    'ۀ': 'ە',
    'ة': 'ە',
    'ى': 'ی',
    'ﻯ': 'ی',
    'ﺉ': 'ئ',
    'ٸ': 'ئ',
    'ؤ': 'و',
    'أ': 'ا',
    'إ': 'ا',
    'آ': 'ا',
    'ٱ': 'ا',
    'ڭ': 'گ',
    '‌': '',
    '‍': '',
    'ـ': '',
    '“': '"',
    '”': '"',
    '’': "'",
    '‘': "'",
    '—': '-',
    '–': '-',
    '…': '.',
  };

  String _normalize(String text) {
    final buffer = StringBuffer();

    for (final rune in text.runes) {
      // Arabic-Indic and Persian digits -> ASCII digits.
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + (rune - 0x0660));
        continue;
      }
      if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(0x30 + (rune - 0x06F0));
        continue;
      }
      final char = String.fromCharCode(rune);
      buffer.write(_normalization[char] ?? char);
    }

    return buffer.toString();
  }

  static const List<String> _ones = [
    'سفر',
    'یەک',
    'دوو',
    'سێ',
    'چوار',
    'پێنج',
    'شەش',
    'حەوت',
    'هەشت',
    'نۆ',
  ];

  static const List<String> _teens = [
    'دە',
    'یازدە',
    'دوازدە',
    'سیازدە',
    'چواردە',
    'پازدە',
    'شازدە',
    'حەڤدە',
    'هەژدە',
    'نۆزدە',
  ];

  static const List<String> _tens = [
    '',
    '',
    'بیست',
    'سی',
    'چل',
    'پەنجا',
    'شەست',
    'حەفتا',
    'هەشتا',
    'نەوەد',
  ];

  String _numberToKurdish(int number) {
    if (number < 10) return _ones[number];
    if (number < 20) return _teens[number - 10];
    if (number < 100) {
      final tens = number ~/ 10;
      final ones = number % 10;
      return ones == 0
          ? _tens[tens]
          : '${_tens[tens]} و ${_ones[ones]}';
    }

    if (number < 1000) {
      final hundreds = number ~/ 100;
      final remainder = number % 100;
      final hundredWord = hundreds == 1
          ? 'سەد'
          : '${_ones[hundreds]} سەد';

      return remainder == 0
          ? hundredWord
          : '$hundredWord و ${_numberToKurdish(remainder)}';
    }

    if (number < 1000000) {
      final thousands = number ~/ 1000;
      final remainder = number % 1000;
      final thousandWord = thousands == 1
          ? 'هەزار'
          : '${_numberToKurdish(thousands)} هەزار';

      return remainder == 0
          ? thousandWord
          : '$thousandWord و ${_numberToKurdish(remainder)}';
    }

    return number.toString();
  }

  String _replaceNumbers(String text) {
    return text.replaceAllMapped(
      RegExp(r'\d+'),
      (match) {
        final value = int.tryParse(match.group(0)!);
        if (value == null) return match.group(0)!;
        return _numberToKurdish(value);
      },
    );
  }

  List<int> _textToIds(String text) {
    final normalized = _normalize(_replaceNumbers(text))
        .replaceAll('\u0626', '\u064A\u0654');
    final ids = <int>[1, 0];

    for (final rune in normalized.runes) {
      final char = String.fromCharCode(rune);
      final id = _phonemeIds[char];

      if (id != null) {
        ids
          ..add(id)
          ..add(0);
      } else {
        debugPrint(
          '[Vekol] dropped unsupported character '
          "'$char' U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')}",
        );
      }
    }

    ids.add(2);
    return ids;
  }

  // ---------------------------------------------------------------------------
  // Text -> chunks.
  //
  // Commas and other inner punctuation are NOT sent to the model: each one made
  // the model insert its own long pause. Instead the text is cut at those
  // places and the pause is a fixed, short silence we control.
  // ---------------------------------------------------------------------------
  List<TtsChunk> prepareChunks(String text) {
    final cleaned = _replaceNumbers(_normalize(text));

    final sentences = cleaned
        .split(RegExp(r'(?<=[.!?؟…])\s+|\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final out = <TtsChunk>[];

    for (final sentence in sentences) {
      var ending = '.';
      if (sentence.endsWith('؟') || sentence.endsWith('?')) {
        ending = '؟';
      } else if (sentence.endsWith('!')) {
        ending = '!';
      }

      final body = sentence.replaceAll(RegExp(r'[.!?؟]+$'), '');

      final clauses = body
          .split(RegExp(r'[،؛,;:]+'))
          .map(
            (c) => c
                .replaceAll(RegExp(r'[؟،؛]'), ' ')
                .replaceAll(
                  RegExp(r'[^\u0600-\u06FF\u0750-\u077F\s]'),
                  ' ',
                )
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim(),
          )
          .where((c) => c.isNotEmpty)
          .toList();

      if (clauses.isEmpty) continue;

      final pieces = <String>[];
      var buf = '';

      void flush() {
        if (buf.isNotEmpty) {
          pieces.add(buf);
          buf = '';
        }
      }

      final isUtteranceStart = out.isEmpty;

      for (final clause in clauses) {
        if (buf.isNotEmpty &&
            buf.length + 1 + clause.length <= _maxChunkLength) {
          buf = '$buf $clause';
        } else {
          flush();
          if (clause.length <= _maxChunkLength) {
            buf = clause;
          } else {
            final words = clause.split(' ');
            var line = '';
            for (final w in words) {
              if (line.isNotEmpty &&
                  line.length + 1 + w.length > _maxChunkLength) {
                pieces.add(line);
                line = w;
              } else {
                line = line.isEmpty ? w : '$line $w';
              }
            }
            buf = line;
          }
        }

        // The first chunk of the answer is flushed early so speech starts fast.
        if (isUtteranceStart && pieces.isEmpty && buf.length >= _firstChunkMin) {
          flush();
        }
      }
      flush();

      for (var i = 0; i < pieces.length; i++) {
        final last = i == pieces.length - 1;
        out.add(
          TtsChunk(
            last ? '${pieces[i]}$ending' : pieces[i],
            last ? _gapAfterSentence : _gapInsideSentence,
          ),
        );
      }
    }

    return out;
  }

  // ---------------------------------------------------------------------------
  // Synthesis
  // ---------------------------------------------------------------------------

  /// One chunk -> cleaned waveform (silence trimmed, hiss reduced, level fixed).
  Future<List<double>> synthesizeChunk(String text) async {
    final ids = _textToIds(text);
    if (ids.length <= 4) return <double>[];
    final raw = await synthesizeIds(ids);
    return _postProcess(raw);
  }

  /// Several chunks -> one waveform, joined with short controlled gaps.
  Future<List<double>> synthesizeUnit(List<TtsChunk> chunks) async {
    final waveform = <double>[];

    for (var i = 0; i < chunks.length; i++) {
      final part = await synthesizeChunk(chunks[i].text);
      if (part.isEmpty) continue;
      waveform.addAll(part);

      if (i < chunks.length - 1) {
        final gap = (_sampleRate * chunks[i].gapAfter).round();
        waveform.addAll(List<double>.filled(gap, 0.0));
      }
    }

    return _applyNoiseGate(waveform);
  }

  /// Suppress low-level model hiss while preserving speech and word endings.
  List<double> _applyNoiseGate(List<double> input) {
    const frameSize = 220; // 10 ms at 22050 Hz
    const padFrames = 4; // Preserve 40 ms around speech.
    const fadeSamples = 176; // Smooth gate transitions.
    const minimumThreshold = 0.00008;

    if (input.length < frameSize * 3) return input;

    final frameCount = input.length ~/ frameSize;
    final levels = List<double>.filled(frameCount, 0.0);

    for (var f = 0; f < frameCount; f++) {
      var sum = 0.0;
      final start = f * frameSize;
      for (var j = 0; j < frameSize; j++) {
        final sample = input[start + j];
        sum += sample * sample;
      }
      levels[f] = math.sqrt(sum / frameSize);
    }

    final sorted = List<double>.from(levels)..sort();
    final floor = sorted[((sorted.length - 1) * 0.20).floor()];
    final threshold = math.max(floor * 2.5, minimumThreshold);

    final active = List<bool>.filled(frameCount, false);
    for (var i = 0; i < frameCount; i++) {
      active[i] = levels[i] > threshold;
    }

    // Expand speech regions so quiet consonants and word endings survive.
    final expanded = List<bool>.filled(frameCount, false);
    for (var i = 0; i < frameCount; i++) {
      if (!active[i]) continue;
      final from = math.max(0, i - padFrames);
      final to = math.min(frameCount - 1, i + padFrames);
      for (var j = from; j <= to; j++) {
        expanded[j] = true;
      }
    }

    // Build a prefix sum for a smooth transition at gate boundaries.
    final prefix = List<double>.filled(input.length + 1, 0.0);
    for (var i = 0; i < input.length; i++) {
      final frame = i ~/ frameSize;
      final open = frame < frameCount && expanded[frame];
      prefix[i + 1] = prefix[i] + (open ? 1.0 : 0.0);
    }

    final output = List<double>.filled(input.length, 0.0);
    for (var i = 0; i < input.length; i++) {
      final left = math.max(0, i - fadeSamples);
      final right = math.min(input.length, i + fadeSamples + 1);
      final envelope = (prefix[right] - prefix[left]) / (right - left);
      output[i] = input[i] * envelope;
    }

    return output;
  }

  Future<List<double>> synthesizeText(String text) async {
    final trimmed = text.trim();

    if (trimmed.isEmpty) {
      throw ArgumentError('Vekol text cannot be empty.');
    }

    return synthesizeUnit(prepareChunks(trimmed));
  }

  List<double> _postProcess(List<double> raw) {
    if (raw.isEmpty) return raw;

    var peak = 0.0;
    for (final v in raw) {
      final a = v.abs();
      if (a > peak) peak = a;
    }
    if (peak < 1e-4) return <double>[];

    // Cut the silence the model adds at the start and end of every chunk.
    final threshold = peak * 0.02;
    var start = 0;
    while (start < raw.length && raw[start].abs() < threshold) {
      start++;
    }
    var end = raw.length - 1;
    while (end > start && raw[end].abs() < threshold) {
      end--;
    }
    start = math.max(0, start - (_sampleRate * 0.012).round());
    end = math.min(raw.length - 1, end + (_sampleRate * 0.030).round());

    final n = end - start + 1;
    if (n <= 0) return <double>[];

    // Gentle one-pole low-pass: removes high-frequency hiss.
    final a = math.exp(-2 * math.pi * _lowpassHz / _sampleRate);
    final out = List<double>.filled(n, 0.0);
    var y = 0.0;
    var peak2 = 0.0;
    for (var i = 0; i < n; i++) {
      y = (1 - a) * raw[start + i] + a * y;
      out[i] = y;
      final m = y.abs();
      if (m > peak2) peak2 = m;
    }

    // Same loudness for every chunk.
    final gain = peak2 > 0 ? math.min(0.92 / peak2, 1.5) : 1.0;
    final fade = math.min((_sampleRate * 0.006).round(), n ~/ 2);
    for (var i = 0; i < n; i++) {
      var v = out[i] * gain;
      if (i < fade) {
        v *= i / fade;
      } else if (i >= n - fade) {
        v *= (n - 1 - i) / fade;
      }
      out[i] = v;
    }

    return out;
  }

  Uint8List waveformToWav(List<double> waveform) {
    if (waveform.isEmpty) {
      throw ArgumentError('Vekol waveform cannot be empty.');
    }

    const channels = 1;
    const bitsPerSample = 16;
    const bytesPerSample = bitsPerSample ~/ 8;

    final dataSize = waveform.length * bytesPerSample;
    final fileSize = 44 + dataSize;
    final wav = ByteData(fileSize);

    wav.setUint32(0, 0x52494646, Endian.big); // RIFF
    wav.setUint32(4, fileSize - 8, Endian.little);
    wav.setUint32(8, 0x57415645, Endian.big); // WAVE

    wav.setUint32(12, 0x666d7420, Endian.big); // fmt
    wav.setUint32(16, 16, Endian.little);
    wav.setUint16(20, 1, Endian.little);
    wav.setUint16(22, channels, Endian.little);
    wav.setUint32(24, _sampleRate, Endian.little);
    wav.setUint32(28, _sampleRate * channels * bytesPerSample, Endian.little);
    wav.setUint16(32, channels * bytesPerSample, Endian.little);
    wav.setUint16(34, bitsPerSample, Endian.little);

    wav.setUint32(36, 0x64617461, Endian.big); // data
    wav.setUint32(40, dataSize, Endian.little);

    for (var i = 0; i < waveform.length; i++) {
      final sample = waveform[i].clamp(-1.0, 1.0);
      wav.setInt16(
        44 + i * bytesPerSample,
        (sample * 32767.0).round(),
        Endian.little,
      );
    }

    return wav.buffer.asUint8List();
  }

  Future<List<double>> synthesizeIds(List<int> ids) async {
    await initialize();

    final session = _session;
    if (session == null) {
      throw StateError('Vekol ONNX session is not initialized.');
    }

    final input = await OrtValue.fromList(
      Int64List.fromList(ids),
      [1, ids.length],
    );

    final inputLengths = await OrtValue.fromList(
      Int64List.fromList([ids.length]),
      [1],
    );

    final scales = await OrtValue.fromList(
      Float32List.fromList([_noiseScale, _lengthScale, _noiseW]),
      [3],
    );

    final speakerId = await OrtValue.fromList(
      Int64List.fromList([0]),
      [1],
    );

    Map<String, OrtValue>? outputs;

    try {
      outputs = await session.run({
        'input': input,
        'input_lengths': inputLengths,
        'scales': scales,
        'sid': speakerId,
      });

      final output = outputs['output'];

      if (output == null) {
        throw StateError(
          'Vekol ONNX model did not return an "output" tensor.',
        );
      }

      return (await output.asFlattenedList())
          .map((value) => (value as num).toDouble())
          .toList();
    } finally {
      await input.dispose();
      await inputLengths.dispose();
      await scales.dispose();
      await speakerId.dispose();

      final result = outputs;
      if (result != null) {
        for (final value in result.values) {
          await value.dispose();
        }
      }
    }
  }
}
