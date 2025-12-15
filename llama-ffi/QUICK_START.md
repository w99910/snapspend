# Quick Start Guide

Get started with llama-ffi in 5 minutes!

## Prerequisites

Build llama.cpp as a shared library:

```bash
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
mkdir build && cd build
cmake .. -DBUILD_SHARED_LIBS=ON
cmake --build .
```

This creates:
- Linux: `libllama.so`
- macOS: `libllama.dylib`
- Windows: `llama.dll`

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  llama_ffi:
    path: ./llama-ffi  # Adjust path as needed
  ffi: ^2.1.3
```

Then:

```bash
dart pub get
```

## Basic Usage

### 1. Import the package

```dart
import 'package:llama_ffi/llama_ffi.dart';
import 'package:ffi/ffi.dart';
import 'dart:ffi';
```

### 2. Initialize

```dart
// Auto-detect library location
final llama = LlamaFFI();

// OR specify path explicitly
final llama = LlamaFFI(libraryPath: '/path/to/libllama.so');

final bindings = llama.bindings;
```

### 3. Use the API

```dart
// Initialize backend
bindings.llama_backend_init();

// Load model
final modelParams = bindings.llama_model_default_params();
final model = bindings.llama_model_load_from_file(
  'model.gguf'.toNativeUtf8().cast(),
  modelParams,
);

// Create context
final ctxParams = bindings.llama_context_default_params();
ctxParams.n_ctx = 512;
final ctx = bindings.llama_new_context_with_model(model, ctxParams);

// Tokenize
final vocab = bindings.llama_model_get_vocab(model);
final tokens = calloc<llama_token>(128);
final nTokens = bindings.llama_tokenize(
  vocab,
  'Hello!'.toNativeUtf8().cast(),
  6,
  tokens,
  128,
  true,
  true,
);

// ... use tokens ...

// Cleanup
calloc.free(tokens);
bindings.llama_free(ctx);
bindings.llama_model_free(model);
bindings.llama_backend_free();
```

## Run the Example

```bash
cd llama-ffi
dart run example/simple_generation.dart /path/to/model.gguf
```

## Common Operations

### Load a Model
```dart
final model = bindings.llama_model_load_from_file(
  path.toNativeUtf8().cast(),
  bindings.llama_model_default_params(),
);
```

### Create Context
```dart
final ctx = bindings.llama_new_context_with_model(
  model,
  bindings.llama_context_default_params(),
);
```

### Tokenize Text
```dart
final vocab = bindings.llama_model_get_vocab(model);
final tokens = calloc<llama_token>(maxTokens);
final n = bindings.llama_tokenize(
  vocab, text.cast(), textLen, tokens, maxTokens, true, true
);
```

### Detokenize
```dart
final buffer = calloc<Char>(64);
final len = bindings.llama_token_to_piece(
  vocab, token, buffer, 64, 0, false
);
final text = buffer.cast<Utf8>().toDartString(length: len);
calloc.free(buffer);
```

### Process Batch
```dart
final batch = bindings.llama_batch_init(nTokens, 0, 1);
// Manually populate batch.token, batch.pos, etc.
bindings.llama_decode(ctx, batch);
bindings.llama_batch_free(batch);
```

### Get Logits
```dart
final logits = bindings.llama_get_logits_ith(ctx, idx);
// logits is Pointer<Float> with n_vocab elements
```

## Memory Management

Always free allocated resources:

```dart
// FFI allocations
final ptr = calloc<Type>();
// ... use ptr ...
calloc.free(ptr);

// llama.cpp resources
bindings.llama_free(ctx);
bindings.llama_model_free(model);
bindings.llama_batch_free(batch);
bindings.llama_backend_free();  // Call at program end
```

## Error Handling

```dart
final model = bindings.llama_model_load_from_file(path.cast(), params);
if (model == nullptr) {
  throw Exception('Failed to load model');
}

final result = bindings.llama_decode(ctx, batch);
if (result != 0) {
  throw Exception('Decode failed: $result');
}
```

## Tips

1. **Always check return values** - Most functions return `nullptr` or negative values on error
2. **Free resources** - Use `calloc.free()` for FFI and `llama_*_free()` for llama.cpp
3. **Use try-finally** - Ensure cleanup even on errors
4. **Check buffer sizes** - Tokenization may fail if buffer is too small
5. **Refer to llama.cpp docs** - The bindings follow the C API closely

## Next Steps

- Read [README.md](README.md) for detailed documentation
- Check [API_REFERENCE.md](API_REFERENCE.md) for function reference
- Browse [example/](example/) for complete examples
- Visit [llama.cpp docs](https://github.com/ggerganov/llama.cpp) for API details

## Troubleshooting

### Library not found
```dart
// Specify explicit path
final llama = LlamaFFI(libraryPath: '/full/path/to/libllama.so');
```

### Model loading fails
- Check file path is correct
- Verify model format is GGUF
- Ensure sufficient memory

### Tokenization fails
- Check buffer size (increase if returns negative)
- Verify text encoding (should be UTF-8)

## Resources

- [llama.cpp GitHub](https://github.com/ggerganov/llama.cpp)
- [Dart FFI Documentation](https://dart.dev/guides/libraries/c-interop)
- [Package Documentation](README.md)






