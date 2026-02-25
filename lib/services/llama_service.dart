import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:ffi/ffi.dart';
import '../internal/llama_ffi.dart';

/// Service class for handling Llama model operations
/// Manages model downloading, loading, and text generation
class LlamaService {
  // Singleton: keep one model worker per app.
  static final LlamaService _instance = LlamaService._internal();
  factory LlamaService() => _instance;
  LlamaService._internal();

  // Model configuration
  // Using Qwen2.5-0.5B-Instruct: Pure instruct model (no reasoning overhead)
  static const String modelUrl =
      'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const String modelFileName = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';

  String _modelPath = '';
  bool _isModelReady = false;

  // Long-lived background worker that owns llama.cpp + loaded model.
  Isolate? _worker;
  SendPort? _workerSendPort;
  ReceivePort? _workerReceivePort;
  StreamSubscription<dynamic>? _workerSub;
  Completer<void>? _workerReadyCompleter;

  int _nextRequestId = 1;
  final Map<
    int,
    ({
      Completer<String> completer,
      Function(String)? onTextUpdate,
      Function(String) onStatusUpdate,
    })
  >
  _pending = {};

  String? _workerModelPath;
  int? _workerContextSize;
  int? _workerBatchSize;
  int? _workerThreads;

  /// Check if model is ready to use
  bool get isModelReady => _isModelReady;

  /// Get the model file path
  String get modelPath => _modelPath;

  /// Get the path where the model should be stored
  Future<String> getModelPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return path.join(directory.path, modelFileName);
  }

  /// Check if model file exists
  Future<bool> checkModelExists() async {
    _modelPath = await getModelPath();
    final file = File(_modelPath);
    final exists = await file.exists();
    _isModelReady = exists;
    return exists;
  }

  /// Download the model from Hugging Face
  /// Returns progress updates through the callback
  Future<void> downloadModel({
    required Function(double progress, String message) onProgress,
  }) async {
    try {
      _modelPath = await getModelPath();
      print('=== MODEL DOWNLOAD START ===');
      print('Model path: $_modelPath');
      print('===========================');

      final file = File(_modelPath);

      // Check if model already exists
      if (await file.exists()) {
        onProgress(1.0, 'Model already available!');
        _isModelReady = true;
        return;
      }

      // Start download
      onProgress(0.0, 'Downloading model from Hugging Face...');

      final request = http.Request('GET', Uri.parse(modelUrl));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('Failed to download: ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      var downloadedBytes = 0;

      final sink = file.openWrite();
      await for (var chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        if (totalBytes > 0) {
          final progress = downloadedBytes / totalBytes;
          final message =
              'Downloading: ${(downloadedBytes / 1024 / 1024).toStringAsFixed(1)}MB / ${(totalBytes / 1024 / 1024).toStringAsFixed(1)}MB';
          onProgress(progress, message);
        }
      }

      await sink.close();
      onProgress(1.0, 'Model downloaded successfully!');
      _isModelReady = true;
    } catch (e) {
      _isModelReady = false;
      rethrow;
    }
  }

  /// Load the appropriate Llama library for the current platform
  ffi.DynamicLibrary _loadLlamaLibrary() {
    if (Platform.isAndroid) {
      return ffi.DynamicLibrary.open('libllama.so');
    } else if (Platform.isLinux) {
      return ffi.DynamicLibrary.open('libllama.so');
    } else if (Platform.isMacOS) {
      return ffi.DynamicLibrary.open('libllama.dylib');
    } else if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('llama.dll');
    } else {
      throw UnsupportedError('Platform not supported');
    }
  }

  /// Generate text using the loaded model
  /// Returns generated text with progress updates through callbacks
  Future<String> generateText({
    required String prompt,
    required Function(String status) onStatusUpdate,
    Function(String generatedText)? onTextUpdate,
    int maxTokens = 128,
    int contextSize = 2048,
    int batchSize = 512,
    int threads = 4,
    bool streamOutput = true, // Enable streaming by default
    bool runInBackground = true, // Run inference in isolate to avoid UI jank
  }) async {
    if (!_isModelReady || _modelPath.isEmpty) {
      throw Exception('Model is not ready. Please download it first.');
    }

    if (!runInBackground) {
      // Debug-only: runs on current isolate (will block UI) and reloads the model each call.
      return _generateTextInternal(
        prompt: prompt,
        onStatusUpdate: onStatusUpdate,
        onTextUpdate: onTextUpdate,
        maxTokens: maxTokens,
        contextSize: contextSize,
        batchSize: batchSize,
        threads: threads,
        streamOutput: streamOutput,
      );
    }

    await _ensureWorkerReady(
      modelPath: _modelPath,
      contextSize: contextSize,
      batchSize: batchSize,
      threads: threads,
    );

    final requestId = _nextRequestId++;
    final completer = Completer<String>();
    _pending[requestId] = (
      completer: completer,
      onTextUpdate: onTextUpdate,
      onStatusUpdate: onStatusUpdate,
    );

    _workerSendPort!.send({
      'type': 'generate',
      'requestId': requestId,
      'prompt': prompt,
      'maxTokens': maxTokens,
      'contextSize': contextSize,
      'batchSize': batchSize,
      'threads': threads,
      'streamOutput': streamOutput,
    });

    return completer.future;
  }

  Future<void> _ensureWorkerReady({
    required String modelPath,
    required int contextSize,
    required int batchSize,
    required int threads,
  }) async {
    // Reuse existing worker if config matches.
    if (_workerSendPort != null &&
        _workerModelPath == modelPath &&
        _workerContextSize == contextSize &&
        _workerBatchSize == batchSize &&
        _workerThreads == threads) {
      return;
    }

    // Restart if config changed.
    await disposeWorker();

    _workerReadyCompleter = Completer<void>();
    _workerReceivePort = ReceivePort();
    _workerSub = _workerReceivePort!.listen(_handleWorkerMessage);

    _worker = await Isolate.spawn(_llamaModelWorkerEntry, {
      'sendPort': _workerReceivePort!.sendPort,
      'modelPath': modelPath,
      'contextSize': contextSize,
      'batchSize': batchSize,
      'threads': threads,
    }, errorsAreFatal: true);

    await _workerReadyCompleter!.future;
    _workerModelPath = modelPath;
    _workerContextSize = contextSize;
    _workerBatchSize = batchSize;
    _workerThreads = threads;
  }

  void _handleWorkerMessage(dynamic msg) {
    if (msg is! Map) return;
    final type = msg['type'];

    if (type == 'sendPort') {
      final sp = msg['sendPort'];
      if (sp is SendPort) _workerSendPort = sp;
      return;
    }

    if (type == 'ready') {
      _workerReadyCompleter?.complete();
      return;
    }

    final requestId = msg['requestId'];
    if (requestId is! int) return;
    final pending = _pending[requestId];
    if (pending == null) return;

    if (type == 'status') {
      final value = msg['value'];
      if (value is String) pending.onStatusUpdate(value);
      return;
    }

    if (type == 'text') {
      final value = msg['value'];
      if (value is String && pending.onTextUpdate != null) {
        pending.onTextUpdate!(value);
      }
      return;
    }

    if (type == 'done') {
      final value = msg['value'];
      _pending.remove(requestId);
      if (!pending.completer.isCompleted) {
        pending.completer.complete(value is String ? value : '');
      }
      return;
    }

    if (type == 'error') {
      final value = msg['value'];
      final stack = msg['stack'];
      _pending.remove(requestId);
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(
          Exception(value is String ? value : 'Unknown worker error'),
          stack is String ? StackTrace.fromString(stack) : null,
        );
      }
      return;
    }
  }

  /// Optional: dispose the long-lived model worker.
  /// If you don't call this, the OS will reclaim memory when the app exits.
  Future<void> disposeWorker() async {
    for (final entry in _pending.entries) {
      if (!entry.value.completer.isCompleted) {
        entry.value.completer.completeError(
          Exception('Model worker was disposed'),
        );
      }
    }
    _pending.clear();

    try {
      _workerSendPort?.send({'type': 'dispose'});
    } catch (_) {}

    await _workerSub?.cancel();
    _workerSub = null;
    _workerReceivePort?.close();
    _workerReceivePort = null;

    _worker?.kill(priority: Isolate.immediate);
    _worker = null;
    _workerSendPort = null;
    _workerReadyCompleter = null;

    _workerModelPath = null;
    _workerContextSize = null;
    _workerBatchSize = null;
    _workerThreads = null;
  }

  Future<String> _generateTextInternal({
    required String prompt,
    required Function(String status) onStatusUpdate,
    Function(String generatedText)? onTextUpdate,
    int maxTokens = 128,
    int contextSize = 2048,
    int batchSize = 512,
    int threads = 4,
    bool streamOutput = true,
  }) async {
    onStatusUpdate('Initializing llama.cpp...');

    // Load the library
    final dylib = _loadLlamaLibrary();
    final bindings = LlamaBindings(dylib);

    onStatusUpdate('Initializing backend...');
    bindings.llama_backend_init();

    onStatusUpdate('Loading model...');

    // Verify model file
    final modelFile = File(_modelPath);
    print('=== MODEL LOADING DEBUG ===');
    print('Model path: $_modelPath');
    print('File exists: ${await modelFile.exists()}');
    if (await modelFile.exists()) {
      final fileSize = await modelFile.length();
      print('File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // Check GGUF magic bytes
      final bytes = await modelFile.openRead(0, 4).first;
      final magic = String.fromCharCodes(bytes);
      print(
        'File magic: ${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')} ($magic)',
      );
      print('Expected GGUF: 47 47 55 46 (GGUF)');
    }
    print('========================');

    // Load model with parameters
    final modelParams = bindings.llama_model_default_params();
    modelParams.n_gpu_layers = 0; // CPU-only

    final pathPtr = _modelPath.toNativeUtf8();
    final model = bindings.llama_model_load_from_file(
      pathPtr.cast(),
      modelParams,
    );
    calloc.free(pathPtr);

    if (model == ffi.nullptr) {
      throw Exception(
        'Failed to load model from $_modelPath - check console for llama.cpp errors',
      );
    }

    onStatusUpdate('Model loaded! Creating context...');

    // Create context
    final ctxParams = bindings.llama_context_default_params();
    ctxParams.n_ctx = contextSize;
    ctxParams.n_batch = batchSize;
    ctxParams.n_threads = threads;

    final ctx = bindings.llama_new_context_with_model(model, ctxParams);
    if (ctx == ffi.nullptr) {
      bindings.llama_model_free(model);
      throw Exception('Failed to create context');
    }

    onStatusUpdate('Tokenizing prompt...');

    // Get vocabulary
    final vocab = bindings.llama_model_get_vocab(model);

    // Format prompt for Qwen2.5 instruct model (ChatML format)
    // Use a specific system prompt for receipt extraction
    final formattedPrompt =
        '<|im_start|>system\n'
        'You extract receipt/payment information.\n'
        'Return ONLY one valid JSON object (no code fences, no extra text).\n'
        'Schema (keys must be exactly these, in English):\n'
        '{"sender":"N/A","recipient":"N/A","amount":0.0,"time":"N/A"}\n'
        'Rules:\n'
        '- sender/recipient/time are strings\n'
        '- amount is a number (no quotes)\n'
        '- If unknown: use "N/A" and amount 0.0\n'
        '<|im_end|>\n'
        '<|im_start|>user\n$prompt<|im_end|>\n'
        '<|im_start|>assistant\n';
    // final formattedPrompt = prompt;

    print('formattedPrompt: $formattedPrompt');
    // Tokenize prompt
    // Keep this aligned with context size to avoid failures on long OCR prompts.
    final maxPromptTokens = contextSize;
    final tokens = calloc<llama_token>(maxPromptTokens);

    final promptUtf8 = formattedPrompt.toNativeUtf8();
    final nTokens = bindings.llama_tokenize(
      vocab,
      promptUtf8.cast(),
      utf8.encode(formattedPrompt).length,
      tokens,
      maxPromptTokens,
      true, // add_special
      true, // parse_special (required for <|im_start|> / <|im_end|>)
    );

    calloc.free(promptUtf8);

    if (nTokens < 0) {
      _cleanup(bindings, ctx, model, tokens);
      throw Exception('Failed to tokenize (buffer too small)');
    }

    onStatusUpdate('Generating response... ($nTokens tokens in prompt)');

    // Process prompt using batch
    final batch = bindings.llama_batch_get_one(tokens, nTokens);

    // Decode the prompt
    final decodeResult = bindings.llama_decode(ctx, batch);
    if (decodeResult != 0) {
      _cleanup(bindings, ctx, model, tokens);
      throw Exception('Failed to decode batch: $decodeResult');
    }

    // Create sampler with default parameters (matches llama-cli behavior)
    final samplerParams = bindings.llama_sampler_chain_default_params();
    samplerParams.no_perf = false; // Enable performance tracking

    final sampler = bindings.llama_sampler_chain_init(samplerParams);

    // Build a sane default sampler chain (similar to llama-cli):
    // top-k -> top-p -> temp -> dist
    // This avoids "drifting" generations and helps EOS / <|im_end|> appear naturally.
    bindings.llama_sampler_chain_add(
      sampler,
      bindings.llama_sampler_init_top_k(40),
    );
    bindings.llama_sampler_chain_add(
      sampler,
      bindings.llama_sampler_init_top_p(0.95, 1),
    );
    bindings.llama_sampler_chain_add(
      sampler,
      bindings.llama_sampler_init_temp(0.2),
    );
    bindings.llama_sampler_chain_add(
      sampler,
      bindings.llama_sampler_init_dist(0), // seed = 0
    );

    // Generate tokens - collect bytes as we go and stop on EOS / <|im_end|>
    final generatedTokens = <int>[];
    int consecutiveErrors = 0;
    const maxConsecutiveErrors = 5;

    // We stop when we see these ASCII byte sequences in the output.
    // Qwen2.5 uses ChatML <|im_end|> as the message terminator.
    final stopSequences = <List<int>>[
      utf8.encode('<|im_end|>'),
      utf8.encode('</s>'),
    ];

    bool endsWithStopSequence(List<int> bytes) {
      for (final seq in stopSequences) {
        if (bytes.length < seq.length) continue;
        bool matches = true;
        for (int i = 0; i < seq.length; i++) {
          if (bytes[bytes.length - seq.length + i] != seq[i]) {
            matches = false;
            break;
          }
        }
        if (matches) return true;
      }
      return false;
    }

    // Collect raw bytes for robust UTF-8 decoding (tokens can split multi-byte chars).
    final outBytes = <int>[];
    final pieceBuffer = calloc<ffi.Char>(256);
    final tokenPtr = calloc<llama_token>(1);

    for (int i = 0; i < maxTokens; i++) {
      // Sample next token
      final newToken = bindings.llama_sampler_sample(sampler, ctx, -1);

      // Check for EOS
      if (newToken == bindings.llama_token_eos(vocab)) {
        print('EOS token reached at position $i');
        break;
      }

      generatedTokens.add(newToken);

      // Update status periodically if streaming
      if (streamOutput && i % 10 == 0) {
        onStatusUpdate('Generating... (${i + 1} tokens)');
      }

      // Convert token -> bytes and optionally stream partial output
      final pieceLen = bindings.llama_token_to_piece(
        vocab,
        newToken,
        pieceBuffer,
        256,
        0,
        true, // special: render special tokens (so we can stop on <|im_end|>)
      );

      if (pieceLen > 0) {
        for (int j = 0; j < pieceLen; j++) {
          // ffi.Char is signed on some platforms; normalize to 0..255
          outBytes.add(pieceBuffer[j] & 0xFF);
        }

        // Stop early when we see <|im_end|> (prevents runaway generations)
        if (endsWithStopSequence(outBytes)) {
          break;
        }

        if (streamOutput && onTextUpdate != null && i % 4 == 0) {
          // Decode leniently for UI updates; final decode happens below.
          onTextUpdate(utf8.decode(outBytes, allowMalformed: true));
        }
      }

      // Prepare next batch with just the new token
      tokenPtr[0] = newToken;
      final nextBatch = bindings.llama_batch_get_one(tokenPtr, 1);

      // Decode next token
      final result = bindings.llama_decode(ctx, nextBatch);
      if (result != 0) {
        consecutiveErrors++;
        if (consecutiveErrors >= maxConsecutiveErrors) {
          print('Too many consecutive decode errors, stopping generation');
          break;
        }
      } else {
        consecutiveErrors = 0;
      }
    }

    print('Generated ${generatedTokens.length} tokens');

    // Convert all bytes to text at once to avoid UTF-8 encoding issues
    String generatedText = '';
    try {
      generatedText = utf8.decode(outBytes, allowMalformed: true);

      print('Decoded text length: ${generatedText.length}');
    } catch (e) {
      print('Error converting tokens to text: $e');
    }

    // Strip trailing chat terminators if present
    generatedText = generatedText.replaceAll('<|im_end|>', '').trim();

    // Free native buffers used during generation
    calloc.free(pieceBuffer);
    calloc.free(tokenPtr);

    // Cleanup
    bindings.llama_sampler_free(sampler);
    _cleanup(bindings, ctx, model, tokens);

    // Final update with complete text if not streaming
    if (!streamOutput && onTextUpdate != null) {
      onTextUpdate(generatedText);
    }
    onStatusUpdate('Generation complete!');
    return generatedText;
  }

  /// Clean up resources
  void _cleanup(
    LlamaBindings bindings,
    ffi.Pointer<llama_context> ctx,
    ffi.Pointer<llama_model> model,
    ffi.Pointer<llama_token> tokens,
  ) {
    calloc.free(tokens);
    bindings.llama_free(ctx);
    bindings.llama_model_free(model);
    bindings.llama_backend_free();
  }
}

// --------------------------
// Long-lived model worker isolate (top-level)
// --------------------------
void _llamaModelWorkerEntry(Map<String, dynamic> args) {
  _llamaModelWorkerEntryAsync(args);
}

Future<void> _llamaModelWorkerEntryAsync(Map<String, dynamic> args) async {
  final SendPort mainSendPort = args['sendPort'] as SendPort;
  final String modelPath = args['modelPath'] as String;
  final int contextSize = args['contextSize'] as int;
  final int batchSize = args['batchSize'] as int;
  final int threads = args['threads'] as int;

  final ReceivePort receivePort = ReceivePort();
  mainSendPort.send({'type': 'sendPort', 'sendPort': receivePort.sendPort});

  ffi.Pointer<llama_model> model = ffi.nullptr;
  ffi.Pointer<llama_vocab> vocab = ffi.nullptr;
  ffi.Pointer<llama_context> ctx = ffi.nullptr;
  late final LlamaBindings bindings;
  bool initialized = false;

  void sendStatus(int requestId, String s) =>
      mainSendPort.send({'type': 'status', 'requestId': requestId, 'value': s});
  void sendText(int requestId, String s) =>
      mainSendPort.send({'type': 'text', 'requestId': requestId, 'value': s});
  void sendDone(int requestId, String s) =>
      mainSendPort.send({'type': 'done', 'requestId': requestId, 'value': s});
  void sendError(int requestId, Object e, StackTrace st) => mainSendPort.send({
    'type': 'error',
    'requestId': requestId,
    'value': e.toString(),
    'stack': st.toString(),
  });

  Future<void> cleanupAll() async {
    try {
      if (!initialized) return;
      if (ctx != ffi.nullptr) {
        bindings.llama_free(ctx);
        ctx = ffi.nullptr;
      }
      if (model != ffi.nullptr) {
        bindings.llama_model_free(model);
        model = ffi.nullptr;
      }
      bindings.llama_backend_free();
    } catch (_) {}
  }

  try {
    // Load dynamic library
    final ffi.DynamicLibrary dylib;
    if (Platform.isAndroid) {
      dylib = ffi.DynamicLibrary.open('libllama.so');
    } else if (Platform.isLinux) {
      dylib = ffi.DynamicLibrary.open('libllama.so');
    } else if (Platform.isMacOS) {
      dylib = ffi.DynamicLibrary.open('libllama.dylib');
    } else if (Platform.isWindows) {
      dylib = ffi.DynamicLibrary.open('llama.dll');
    } else {
      throw UnsupportedError('Platform not supported');
    }

    bindings = LlamaBindings(dylib);
    initialized = true;
    bindings.llama_backend_init();

    final modelParams = bindings.llama_model_default_params();
    modelParams.n_gpu_layers = 0;

    final pathPtr = modelPath.toNativeUtf8();
    model = bindings.llama_model_load_from_file(pathPtr.cast(), modelParams);
    calloc.free(pathPtr);

    if (model == ffi.nullptr) {
      throw Exception('Failed to load model from $modelPath');
    }

    vocab = bindings.llama_model_get_vocab(model);

    // Initial context (will be recreated per request)
    final ctxParams = bindings.llama_context_default_params();
    ctxParams.n_ctx = contextSize;
    ctxParams.n_batch = batchSize;
    ctxParams.n_threads = threads;
    ctx = bindings.llama_new_context_with_model(model, ctxParams);
    if (ctx == ffi.nullptr) {
      throw Exception('Failed to create context');
    }

    mainSendPort.send({'type': 'ready'});
  } catch (e, st) {
    await cleanupAll();
    sendError(-1, e, st);
    return;
  }

  await for (final dynamic msg in receivePort) {
    if (msg is! Map) continue;
    final type = msg['type'];

    if (type == 'dispose') {
      await cleanupAll();
      receivePort.close();
      break;
    }

    if (type != 'generate') continue;

    final int requestId = msg['requestId'] as int;
    final String prompt = msg['prompt'] as String;
    final int maxTokens = msg['maxTokens'] as int;
    final int reqContextSize = msg['contextSize'] as int;
    final int reqBatchSize = msg['batchSize'] as int;
    final int reqThreads = msg['threads'] as int;
    final bool streamOutput = msg['streamOutput'] as bool;

    try {
      sendStatus(requestId, 'Preparing context...');

      // Recreate ctx each request (no KV-cache clear exposed in current bindings).
      if (ctx != ffi.nullptr) {
        bindings.llama_free(ctx);
        ctx = ffi.nullptr;
      }
      final ctxParams = bindings.llama_context_default_params();
      ctxParams.n_ctx = reqContextSize;
      ctxParams.n_batch = reqBatchSize;
      ctxParams.n_threads = reqThreads;
      ctx = bindings.llama_new_context_with_model(model, ctxParams);
      if (ctx == ffi.nullptr) {
        throw Exception('Failed to create context');
      }

      sendStatus(requestId, 'Tokenizing prompt...');

      final formattedPrompt =
          '<|im_start|>system\n'
          'You extract receipt/payment information.\n'
          'Return ONLY one valid JSON object (no code fences, no extra text).\n'
          'Schema (keys must be exactly these, in English):\n'
          '{"sender":"N/A","recipient":"N/A","amount":0.0,"time":"N/A"}\n'
          'Rules:\n'
          '- sender/recipient/time are strings\n'
          '- amount is a number (no quotes)\n'
          '- If unknown: use "N/A" and amount 0.0\n'
          '<|im_end|>\n'
          '<|im_start|>user\n$prompt<|im_end|>\n'
          '<|im_start|>assistant\n';

      final maxPromptTokens = reqContextSize;
      final tokens = calloc<llama_token>(maxPromptTokens);

      final promptUtf8 = formattedPrompt.toNativeUtf8();
      final nTokens = bindings.llama_tokenize(
        vocab,
        promptUtf8.cast(),
        utf8.encode(formattedPrompt).length,
        tokens,
        maxPromptTokens,
        true,
        true,
      );
      calloc.free(promptUtf8);

      if (nTokens < 0) {
        calloc.free(tokens);
        throw Exception('Failed to tokenize (buffer too small)');
      }

      sendStatus(
        requestId,
        'Generating response... ($nTokens tokens in prompt)',
      );

      final batch = bindings.llama_batch_get_one(tokens, nTokens);
      final decodeResult = bindings.llama_decode(ctx, batch);
      if (decodeResult != 0) {
        calloc.free(tokens);
        throw Exception('Failed to decode batch: $decodeResult');
      }

      final samplerParams = bindings.llama_sampler_chain_default_params();
      samplerParams.no_perf = false;
      final sampler = bindings.llama_sampler_chain_init(samplerParams);
      bindings.llama_sampler_chain_add(
        sampler,
        bindings.llama_sampler_init_top_k(40),
      );
      bindings.llama_sampler_chain_add(
        sampler,
        bindings.llama_sampler_init_top_p(0.95, 1),
      );
      bindings.llama_sampler_chain_add(
        sampler,
        bindings.llama_sampler_init_temp(0.2),
      );
      bindings.llama_sampler_chain_add(
        sampler,
        bindings.llama_sampler_init_dist(0),
      );

      final stopSequences = <List<int>>[
        utf8.encode('<|im_end|>'),
        utf8.encode('</s>'),
      ];
      bool endsWithStopSequence(List<int> bytes) {
        for (final seq in stopSequences) {
          if (bytes.length < seq.length) continue;
          bool matches = true;
          for (int i = 0; i < seq.length; i++) {
            if (bytes[bytes.length - seq.length + i] != seq[i]) {
              matches = false;
              break;
            }
          }
          if (matches) return true;
        }
        return false;
      }

      final outBytes = <int>[];
      final pieceBuffer = calloc<ffi.Char>(256);
      final tokenPtr = calloc<llama_token>(1);

      int consecutiveErrors = 0;
      const maxConsecutiveErrors = 5;

      for (int i = 0; i < maxTokens; i++) {
        final newToken = bindings.llama_sampler_sample(sampler, ctx, -1);

        if (newToken == bindings.llama_token_eos(vocab)) {
          break;
        }

        if (streamOutput && i % 10 == 0) {
          sendStatus(requestId, 'Generating... (${i + 1} tokens)');
        }

        final pieceLen = bindings.llama_token_to_piece(
          vocab,
          newToken,
          pieceBuffer,
          256,
          0,
          true,
        );

        if (pieceLen > 0) {
          for (int j = 0; j < pieceLen; j++) {
            outBytes.add(pieceBuffer[j] & 0xFF);
          }

          if (endsWithStopSequence(outBytes)) {
            break;
          }

          if (streamOutput && i % 4 == 0) {
            sendText(requestId, utf8.decode(outBytes, allowMalformed: true));
          }
        }

        tokenPtr[0] = newToken;
        final nextBatch = bindings.llama_batch_get_one(tokenPtr, 1);
        final result = bindings.llama_decode(ctx, nextBatch);
        if (result != 0) {
          consecutiveErrors++;
          if (consecutiveErrors >= maxConsecutiveErrors) {
            break;
          }
        } else {
          consecutiveErrors = 0;
        }
      }

      var generatedText = utf8.decode(outBytes, allowMalformed: true);
      generatedText = generatedText.replaceAll('<|im_end|>', '').trim();

      calloc.free(pieceBuffer);
      calloc.free(tokenPtr);
      bindings.llama_sampler_free(sampler);
      calloc.free(tokens);

      sendStatus(requestId, 'Generation complete!');
      // Keep behavior consistent with non-worker path: callers that rely on
      // onTextUpdate should still get the final output when streamOutput=false.
      if (!streamOutput) {
        sendText(requestId, generatedText);
      }
      sendDone(requestId, generatedText);
    } catch (e, st) {
      sendError(requestId, e, st);
    }
  }
}

/// Helper extension to convert Dart List to native llama_token array
extension ListTokenExtension on List<int> {
  ffi.Pointer<llama_token> toNativeToken() {
    final ptr = calloc<llama_token>(length);
    for (int i = 0; i < length; i++) {
      ptr[i] = this[i];
    }
    return ptr;
  }
}
