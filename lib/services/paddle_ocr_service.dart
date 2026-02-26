import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class PaddleOcrResult {
  final String text;
  final double score;

  PaddleOcrResult({required this.text, required this.score});
}

class PaddleOcrService {
  static const _channel = MethodChannel('com.example.snapspend/native_info');
  static const _ocrChannel = MethodChannel('com.example.snapspend/paddle_ocr');

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  String? _nativeLibDir;
  String? _dataDir;

  // Persistent process for batch mode (Android only)
  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  final _lineBuffer = <String>[];
  Completer<List<PaddleOcrResult>>? _pendingResult;

  static const _modelAssets = {
    'det': 'assets/models/th_PP-OCRv5_mobile_det.nb',
    'cls': 'assets/models/PP-LCNet_x0_25_textline_ori.nb',
    'rec': 'assets/models/th_PP-OCRv5_mobile_rec.nb',
    'config': 'assets/models/config.txt',
    'label': 'assets/labels/th_ppocr_keys.txt',
  };

  Future<Map<String, String>> _extractAssets() async {
    final appDir = await getApplicationDocumentsDirectory();
    _dataDir = path.join(appDir.path, 'ppocr');
    final modelDir = Directory(_dataDir!);
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    final paths = <String, String>{};
    for (final entry in _modelAssets.entries) {
      final filename = path.basename(entry.value);
      final destFile = File(path.join(_dataDir!, filename));

      if (!await destFile.exists()) {
        print('PaddleOCR: extracting ${entry.value}');
        final data = await rootBundle.load(entry.value);
        await destFile.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }
      paths[entry.key] = destFile.path;
    }
    return paths;
  }

  /// Start the persistent OCR process. Models are loaded once
  /// and stay in memory until [release] is called.
  Future<void> init() async {
    if (_isInitialized) return;

    if (Platform.isIOS) {
      await _initIOS();
    } else {
      await _initAndroid();
    }
  }

  Future<void> _initIOS() async {
    print('PaddleOCR: initializing on iOS via MethodChannel...');

    await _ocrChannel.invokeMethod('init', {
      'detModel': _modelAssets['det']!,
      'recModel': _modelAssets['rec']!,
      'clsModel': _modelAssets['cls']!,
      'configPath': _modelAssets['config']!,
      'labelPath': _modelAssets['label']!,
    });

    _isInitialized = true;
    print('PaddleOCR: iOS pipeline ready');
  }

  Future<void> _initAndroid() async {
    _nativeLibDir = await _channel.invokeMethod<String>('getNativeLibDir');
    print('PaddleOCR: nativeLibDir = $_nativeLibDir');

    await _extractAssets();

    final binaryPath = path.join(_nativeLibDir!, 'libppocr.so');
    final detModel = path.join(_dataDir!, 'th_PP-OCRv5_mobile_det.nb');
    final recModel = path.join(_dataDir!, 'th_PP-OCRv5_mobile_rec.nb');
    final clsModel = path.join(_dataDir!, 'PP-LCNet_x0_25_textline_ori.nb');
    final labelFile = path.join(_dataDir!, 'th_ppocr_keys.txt');
    final configFile = path.join(_dataDir!, 'config.txt');
    final outputImg = path.join(_dataDir!, 'ocr_result.jpg');

    print('PaddleOCR: starting persistent process...');
    _process = await Process.start(
      binaryPath,
      [detModel, recModel, clsModel, '-', outputImg, labelFile, configFile],
      environment: {'LD_LIBRARY_PATH': _nativeLibDir!},
    );

    _stderrSub = _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => print('PaddleOCR stderr: $line'));

    // Wait for __READY__ signal (models loaded)
    final readyCompleter = Completer<void>();
    _stdoutSub = _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (!readyCompleter.isCompleted && line.trim() == '__READY__') {
            readyCompleter.complete();
            return;
          }
          _handleLine(line);
        });

    await readyCompleter.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('PaddleOCR init timed out'),
    );

    _isInitialized = true;
    print('PaddleOCR: models loaded, ready for batch processing');
  }

  void _handleLine(String line) {
    if (line.startsWith('__BEGIN__')) {
      _lineBuffer.clear();
      return;
    }
    if (line.trim() == '__END__') {
      final results = _parseLines(_lineBuffer);
      _lineBuffer.clear();
      _pendingResult?.complete(results);
      _pendingResult = null;
      return;
    }
    _lineBuffer.add(line);
  }

  List<PaddleOcrResult> _parseLines(List<String> lines) {
    final results = <PaddleOcrResult>[];
    for (final line in lines) {
      final parts = line.split('\t');
      if (parts.length >= 3) {
        final text = parts[1];
        final score = double.tryParse(parts[2]) ?? 0.0;
        results.add(PaddleOcrResult(text: text, score: score));
      }
    }
    return results;
  }

  /// Run OCR on a single image. The process stays alive between calls.
  Future<List<PaddleOcrResult>> runOCR(String imagePath) async {
    if (!_isInitialized) await init();

    if (Platform.isIOS) {
      return _runOCRIOS(imagePath);
    } else {
      return _runOCRAndroid(imagePath);
    }
  }

  Future<List<PaddleOcrResult>> _runOCRIOS(String imagePath) async {
    print('PaddleOCR: processing $imagePath (iOS)');

    final List<dynamic> rawResults = await _ocrChannel.invokeMethod('runOCR', {
      'imagePath': imagePath,
    });

    final results = <PaddleOcrResult>[];
    for (final item in rawResults) {
      final map = Map<String, dynamic>.from(item as Map);
      results.add(
        PaddleOcrResult(
          text: map['text'] as String? ?? '',
          score: (map['score'] as num?)?.toDouble() ?? 0.0,
        ),
      );
    }

    print('PaddleOCR: got ${results.length} lines from $imagePath');
    return results;
  }

  Future<List<PaddleOcrResult>> _runOCRAndroid(String imagePath) async {
    if (_pendingResult != null) {
      throw StateError('Another OCR call is already in progress');
    }

    _pendingResult = Completer<List<PaddleOcrResult>>();
    _process!.stdin.writeln(imagePath);
    await _process!.stdin.flush();

    print('PaddleOCR: processing $imagePath');

    final results = await _pendingResult!.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        _pendingResult = null;
        throw TimeoutException('OCR timed out for $imagePath');
      },
    );

    print('PaddleOCR: got ${results.length} lines from $imagePath');
    return results;
  }

  /// Convenience: run OCR and return concatenated text.
  Future<String> runOCRToText(String imagePath) async {
    final results = await runOCR(imagePath);
    return results.map((r) => r.text).join('\n');
  }

  /// Release the persistent process. Call when batch processing is done.
  Future<void> release() async {
    if (Platform.isIOS) {
      await _releaseIOS();
    } else {
      await _releaseAndroid();
    }
  }

  Future<void> _releaseIOS() async {
    if (_isInitialized) {
      try {
        await _ocrChannel.invokeMethod('release');
      } catch (_) {}
    }
    _isInitialized = false;
    print('PaddleOCR: released (iOS)');
  }

  Future<void> _releaseAndroid() async {
    if (_process != null) {
      try {
        _process!.stdin.writeln('__EXIT__');
        await _process!.stdin.flush();
        await _process!.stdin.close();
      } catch (_) {}
      _process!.kill();
      _process = null;
    }
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
    _pendingResult = null;
    _lineBuffer.clear();
    _isInitialized = false;
    print('PaddleOCR: released');
  }
}
