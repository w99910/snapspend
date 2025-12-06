# Llama FFI

Dart FFI bindings for [llama.cpp](https://github.com/ggerganov/llama.cpp), enabling you to run large language models locally in your Dart applications.

## Features

- Complete Dart FFI bindings for llama.cpp
- Support for all major llama.cpp APIs:
  - Model loading and management
  - Context creation and configuration
  - Token generation and decoding
  - Embedding generation
  - And much more!
- Cross-platform support (Linux, macOS, Windows)
- Auto-generated bindings using `ffigen`

## Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  llama_ffi:
    path: ./llama-ffi  # Adjust path as needed
```

## Prerequisites

Before using this library, you need to build llama.cpp as a shared library:

### Linux

```bash
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
mkdir build && cd build
cmake .. -DBUILD_SHARED_LIBS=ON
cmake --build .
# This will create libllama.so
```

### macOS

```bash
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
mkdir build && cd build
cmake .. -DBUILD_SHARED_LIBS=ON
cmake --build .
# This will create libllama.dylib
```

### Windows

```powershell
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
mkdir build
cd build
cmake .. -DBUILD_SHARED_LIBS=ON
cmake --build . --config Release
# This will create llama.dll
```

## Usage

### Basic Example

```dart
import 'package:llama_ffi/llama_ffi.dart';
import 'dart:ffi';

void main() {
  // Initialize the library
  final llama = LlamaFFI(libraryPath: '/path/to/libllama.so');
  
  // Access the bindings
  final bindings = llama.bindings;
  
  // Initialize backend
  bindings.llama_backend_init();
  
  // Load a model
  final modelPath = '/path/to/model.gguf'.toNativeUtf8();
  final params = bindings.llama_model_default_params();
  final model = bindings.llama_model_load_from_file(
    modelPath.cast(),
    params,
  );
  
  if (model == nullptr) {
    print('Failed to load model');
    return;
  }
  
  print('Model loaded successfully!');
  
  // Create context
  final ctxParams = bindings.llama_context_default_params();
  final ctx = bindings.llama_new_context_with_model(model, ctxParams);
  
  // ... use the model ...
  
  // Cleanup
  bindings.llama_free(ctx);
  bindings.llama_model_free(model);
  bindings.llama_backend_free();
}
```

### Auto-detecting Library Path

The library can automatically search for the llama.cpp shared library in common locations:

```dart
void main() {
  try {
    // Auto-detect library location
    final llama = LlamaFFI();
    print('Library loaded successfully!');
  } catch (e) {
    print('Could not find library: $e');
    print('Please specify the path explicitly.');
  }
}
```

## Regenerating Bindings

If you update the llama.cpp headers, you can regenerate the bindings:

```bash
cd llama-ffi
dart run ffigen --config ffigen.yaml
```

The bindings configuration is in `ffigen.yaml`.

## API Documentation

The bindings closely follow the llama.cpp C API. For detailed documentation on the available functions, refer to:

- [llama.cpp documentation](https://github.com/ggerganov/llama.cpp)
- The header files in `include/`:
  - `llama.h` - Main llama.cpp API
  - `ggml.h` - GGML tensor library API
  - `gguf.h` - GGUF file format API

## Example: Text Generation

```dart
import 'package:llama_ffi/llama_ffi.dart';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

void generateText(String modelPath, String prompt) {
  final llama = LlamaFFI();
  final bindings = llama.bindings;
  
  // Initialize
  bindings.llama_backend_init();
  
  // Load model
  final modelParams = bindings.llama_model_default_params();
  final model = bindings.llama_model_load_from_file(
    modelPath.toNativeUtf8().cast(),
    modelParams,
  );
  
  // Create context
  final ctxParams = bindings.llama_context_default_params();
  final ctx = bindings.llama_new_context_with_model(model, ctxParams);
  
  // Tokenize prompt
  final promptUtf8 = prompt.toNativeUtf8();
  final maxTokens = 512;
  final tokens = calloc<llama_token>(maxTokens);
  
  final nTokens = bindings.llama_tokenize(
    model,
    promptUtf8.cast(),
    prompt.length,
    tokens,
    maxTokens,
    true, // add_special
    true, // parse_special
  );
  
  // Generate tokens...
  // (Implementation details depend on your use case)
  
  // Cleanup
  calloc.free(tokens);
  calloc.free(promptUtf8);
  bindings.llama_free(ctx);
  bindings.llama_model_free(model);
  bindings.llama_backend_free();
}
```

## Platform Support

| Platform | Status | Library Extension |
|----------|--------|-------------------|
| Linux    | ✅ Supported | `.so` |
| macOS    | ✅ Supported | `.dylib` |
| Windows  | ✅ Supported | `.dll` |
| iOS      | ⚠️ Experimental | Framework |
| Android  | ⚠️ Experimental | `.so` |

## Contributing

Contributions are welcome! When updating bindings:

1. Update the header files in `include/`
2. Regenerate bindings with `dart run ffigen --config ffigen.yaml`
3. Test the changes
4. Submit a pull request

## License

This package is licensed under the MIT License. The llama.cpp library has its own license - please refer to the [llama.cpp repository](https://github.com/ggerganov/llama.cpp) for details.

## Acknowledgments

- [llama.cpp](https://github.com/ggerganov/llama.cpp) - The amazing C/C++ library this package wraps
- [ffigen](https://pub.dev/packages/ffigen) - Dart FFI bindings generator
