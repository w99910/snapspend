import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:ffi/ffi.dart';
import '../internal/llama_ffi.dart';

/// Service class for handling Llama model operations
/// Manages model downloading, loading, and text generation
class LlamaService {
  // Model configuration
  static const String modelUrl =
      'https://huggingface.co/unsloth/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_0.gguf';
  static const String modelFileName = 'Qwen3-0.6B-Q4_0.gguf';

  String _modelPath = '';
  bool _isModelReady = false;

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
    int contextSize = 512,
    int batchSize = 512,
    int threads = 4,
    bool streamOutput = true, // Enable streaming by default
  }) async {
    if (!_isModelReady || _modelPath.isEmpty) {
      throw Exception('Model is not ready. Please download it first.');
    }

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

    // Format prompt for Qwen3 chat (ChatML format)
    // Use a more specific system prompt for receipt extraction
    final formattedPrompt =
        '<|im_start|>system\nYou are a JSON generator. You MUST return valid JSON objects only. Never return numbered lists, explanations, or text. Only output pure JSON.<|im_end|>\n'
        '<|im_start|>user\n$prompt<|im_end|>\n'
        '<|im_start|>assistant\n';

    // Tokenize prompt
    final maxPromptTokens = 512;
    final tokens = calloc<llama_token>(maxPromptTokens);

    final promptUtf8 = formattedPrompt.toNativeUtf8();
    final nTokens = bindings.llama_tokenize(
      vocab,
      promptUtf8.cast(),
      formattedPrompt.length,
      tokens,
      maxPromptTokens,
      true, // add_special
      true, // parse_special
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

    // Create sampler for generation
    final sampler = bindings.llama_sampler_init_greedy();

    // Generate tokens - collect all tokens first, then decode at the end
    final generatedTokens = <int>[];
    int consecutiveErrors = 0;
    const maxConsecutiveErrors = 5;

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

      // Prepare next batch with just the new token
      final nextBatch = bindings.llama_batch_get_one(
        [newToken].toNativeToken(),
        1,
      );

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

    // Convert all tokens to text at once to avoid UTF-8 encoding issues
    String generatedText = '';
    try {
      // Build text from all tokens with proper UTF-8 handling
      final byteBuffer = <int>[];

      for (final token in generatedTokens) {
        final pieceBuffer = calloc<ffi.Char>(64);
        final pieceLen = bindings.llama_token_to_piece(
          vocab,
          token,
          pieceBuffer,
          64,
          0,
          false,
        );

        if (pieceLen > 0) {
          // Collect raw bytes
          for (int i = 0; i < pieceLen; i++) {
            byteBuffer.add(pieceBuffer[i]);
          }
        }

        calloc.free(pieceBuffer);
      }

      // Convert collected bytes to UTF-8 string with error handling
      try {
        generatedText = utf8.decode(byteBuffer, allowMalformed: true);
      } catch (e) {
        print('UTF-8 decode error: $e');
        // Fallback: decode with lenient mode
        generatedText = String.fromCharCodes(byteBuffer, 0, byteBuffer.length);
      }

      print('Decoded text length: ${generatedText.length}');
    } catch (e) {
      print('Error converting tokens to text: $e');
    }

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
