import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../platform/vlog.dart';

/// sherpa-onnx 离线流式识别（zipformer 中英双语 int8 模型，构建时打进 APK）。
class SherpaStt {
  SherpaStt._(this._recognizer);

  final sherpa.OnlineRecognizer _recognizer;
  sherpa.OnlineStream? _stream;
  String _committed = '';
  int _fedSamples = 0;
  String _lastLogged = '';

  static const _files = [
    'encoder-epoch-99-avg-1.int8.onnx',
    'decoder-epoch-99-avg-1.int8.onnx',
    'joiner-epoch-99-avg-1.int8.onnx',
    'tokens.txt',
  ];

  /// 首次调用会把模型从 assets 拷到应用目录（native 侧需要真实文件路径）。
  static Future<SherpaStt> create() async {
    final dir = await getApplicationDocumentsDirectory();
    VLog.say('model dir: ${dir.path}');
    for (final f in _files) {
      final out = File(p.join(dir.path, f));
      if (!out.existsSync()) {
        final data = await rootBundle.load('assets/models/$f');
        await out.writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      }
      VLog.say('model $f = ${out.lengthSync()} bytes');
    }
    final config = sherpa.OnlineRecognizerConfig(
      model: sherpa.OnlineModelConfig(
        transducer: sherpa.OnlineTransducerModelConfig(
          encoder: p.join(dir.path, _files[0]),
          decoder: p.join(dir.path, _files[1]),
          joiner: p.join(dir.path, _files[2]),
        ),
        tokens: p.join(dir.path, _files[3]),
        numThreads: 2,
      ),
    );
    final rec = sherpa.OnlineRecognizer(config);
    VLog.say('recognizer ready');
    return SherpaStt._(rec);
  }

  void newStream() {
    _committed = '';
    _lastLogged = '';
    _stream = _recognizer.createStream();
  }

  /// 喂入 16kHz 单声道 PCM16 字节流。
  void feed(Uint8List pcm) {
    final st = _stream;
    if (st == null) return;
    final n = pcm.lengthInBytes ~/ 2;
    if (n == 0) return;
    final bytes = Uint8List.sublistView(pcm);
    final data = ByteData.view(bytes.buffer, bytes.offsetInBytes, n * 2);
    final f32 = Float32List(n);
    for (var i = 0; i < n; i++) {
      f32[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    _fedSamples += n;
    if (_fedSamples ~/ 16000 != (_fedSamples - n) ~/ 16000) {
      VLog.say('fed ${(_fedSamples / 16000).toStringAsFixed(1)}s');
    }
    st.acceptWaveform(samples: f32, sampleRate: 16000);
  }

  /// 解码并返回当前已识别文本（含端点分段）。
  String decode() {
    final st = _stream;
    if (st == null) return _committed;
    while (_recognizer.isReady(st)) {
      _recognizer.decode(st);
    }
    var text = _recognizer.getResult(st).text;
    if (text.isNotEmpty && text != _lastLogged) {
      _lastLogged = text;
      VLog.say('asr: $text');
    }
    if (_recognizer.isEndpoint(st)) {
      _committed += text;
      VLog.say('endpoint, committed="$_committed"');
      text = '';
      _recognizer.reset(st);
    }
    return _committed + text;
  }

  void dispose() {
    try {
      _stream?.free();
    } catch (_) {}
    try {
      _recognizer.free();
    } catch (_) {}
  }
}
