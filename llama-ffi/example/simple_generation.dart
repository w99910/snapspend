/// Example: Basic llama.cpp model loading and inspection
///
/// This example demonstrates how to:
/// 1. Load a model
/// 2. Inspect model properties
/// 3. Create a context
/// 4. Perform basic tokenization
library;

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:llama_ffi/llama_ffi.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart simple_generation.dart <model_path>');
    print('Example: dart simple_generation.dart model.gguf');
    return;
  }

  final modelPath = args[0];

  print('=== Llama.cpp FFI Example ===\n');
  print('Initializing llama.cpp...');
  
  final llama = LlamaFFI();
  final bindings = llama.bindings;

  try {
    // Initialize backend
    bindings.llama_backend_init();
    print('✓ Backend initialized\n');

    // Load model
    print('Loading model from: $modelPath');
    final modelParams = bindings.llama_model_default_params();
    final model = bindings.llama_model_load_from_file(
      modelPath.toNativeUtf8().cast(),
      modelParams,
    );

    if (model == nullptr) {
      throw Exception('Failed to load model');
    }
    print('✓ Model loaded successfully\n');

    // Get model vocabulary
    final vocab = bindings.llama_model_get_vocab(model);
    print('Model Information:');
    print('  Vocabulary size: ${bindings.llama_n_vocab(vocab)}');
    print('  Training context: ${bindings.llama_n_ctx_train(model)}');
    print('  Embedding dimension: ${bindings.llama_n_embd(model)}');
    print('  Number of layers: ${bindings.llama_n_layer(model)}');
    
    // Get model metadata
    final metaCount = bindings.llama_model_meta_count(model);
    print('  Metadata entries: $metaCount\n');

    // Create context
    print('Creating context...');
    final ctxParams = bindings.llama_context_default_params();
    ctxParams.n_ctx = 512; // Context size
    ctxParams.n_batch = 512; // Batch size
    ctxParams.n_threads = 4; // Number of threads
    
    final ctx = bindings.llama_new_context_with_model(model, ctxParams);
    if (ctx == nullptr) {
      bindings.llama_model_free(model);
      throw Exception('Failed to create context');
    }
    print('✓ Context created');
    print('  Context size: ${bindings.llama_n_ctx(ctx)}');
    print('  Batch size: ${bindings.llama_n_batch(ctx)}\n');

    // Example tokenization
    final testPrompt = 'Hello, world!';
    print('Tokenizing test prompt: "$testPrompt"');
    
    final maxTokens = 128;
    final tokens = calloc<llama_token>(maxTokens);
    
    final nTokens = bindings.llama_tokenize(
      vocab,
      testPrompt.toNativeUtf8().cast(),
      testPrompt.length,
      tokens,
      maxTokens,
      true, // add_special (BOS)
      true, // parse_special
    );

    if (nTokens < 0) {
      throw Exception('Failed to tokenize (buffer too small)');
    }
    
    print('✓ Tokenized into $nTokens tokens:');
    for (int i = 0; i < nTokens; i++) {
      final token = tokens[i];
      // Get token piece (text representation)
      final pieceBuffer = calloc<Char>(64);
      final pieceLen = bindings.llama_token_to_piece(
        vocab,
        token,
        pieceBuffer,
        64,
        0,
        false,
      );
      
      if (pieceLen > 0) {
        final piece = pieceBuffer.cast<Utf8>().toDartString(length: pieceLen);
        print('  Token[$i]: $token -> "$piece"');
      } else {
        print('  Token[$i]: $token');
      }
      calloc.free(pieceBuffer);
    }

    // Get special tokens
    print('\nSpecial tokens:');
    final bos = bindings.llama_token_bos(vocab);
    final eos = bindings.llama_token_eos(vocab);
    final eot = bindings.llama_token_eot(vocab);
    final nl = bindings.llama_token_nl(vocab);
    
    print('  BOS (Beginning of sequence): $bos');
    print('  EOS (End of sequence): $eos');
    print('  EOT (End of turn): $eot');
    print('  NL (Newline): $nl');

    // Cleanup
    calloc.free(tokens);
    bindings.llama_free(ctx);
    bindings.llama_model_free(model);
    bindings.llama_backend_free();

    print('\n✓ Cleanup complete');
    print('\n=== Example completed successfully ===');
    
  } catch (e, stackTrace) {
    print('\nError: $e');
    print('Stack trace: $stackTrace');
    
    // Backend cleanup
    try {
      bindings.llama_backend_free();
    } catch (_) {
      // Ignore cleanup errors
    }
    exit(1);
  }
}
