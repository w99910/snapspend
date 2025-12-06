# Llama FFI Setup Summary

This document summarizes what was created for the llama-ffi package.

## Generated Files

### Core Bindings
- **`lib/src/llama_bindings_generated.dart`** (20,729 lines)
  - Auto-generated FFI bindings from llama.cpp C headers
  - Contains `LlamaBindings` class with all C function bindings
  - Includes structs, enums, typedefs, and function pointers

### Library Files
- **`lib/llama_ffi.dart`**
  - Main library file
  - Exports the generated bindings
  - Provides `LlamaFFI` helper class for easy library loading
  - Auto-detects library location or accepts custom paths

### Configuration
- **`ffigen.yaml`**
  - Configuration for the ffigen tool
  - Specifies which headers to process
  - Includes preamble with ignore rules
  - Silences enum warnings

### Documentation
- **`README.md`**
  - Comprehensive usage guide
  - Installation instructions for llama.cpp
  - Platform support matrix
  - Basic and advanced examples

- **`API_REFERENCE.md`**
  - Quick reference for common functions
  - Organized by category (model, context, tokenization, etc.)
  - Includes code examples for each operation
  - Type definitions reference

- **`SETUP_SUMMARY.md`** (this file)
  - Summary of the package structure
  - What was generated and why

### Examples
- **`bin/llama_ffi.dart`**
  - Simple command-line example
  - Shows basic library loading
  - Error handling demonstration

- **`example/simple_generation.dart`**
  - Complete model loading example
  - Demonstrates tokenization
  - Shows model information inspection
  - Proper cleanup patterns

### Tests
- **`test/llama_ffi_test.dart`**
  - Basic tests to verify exports
  - Constructor validation tests

### Other Files
- **`.gitignore`**
  - Standard Dart package ignores
  - IDE and OS-specific files

## Header Files Included

The following llama.cpp headers are included in `include/`:

### Core Headers
- `llama.h` - Main llama.cpp API (1,433 lines)
- `llama-cpp.h` - C++ utilities (31 lines)

### GGML Headers
- `ggml.h` - Core GGML tensor library (2,699 lines)
- `ggml-alloc.h` - Memory allocation (77 lines)
- `ggml-backend.h` - Backend abstraction (373 lines)
- `ggml-cpu.h` - CPU backend (146 lines)
- `ggml-opt.h` - Optimization algorithms (257 lines)

### Backend-Specific Headers
- `ggml-cuda.h` - CUDA support (48 lines)
- `ggml-metal.h` - Metal (macOS) support (62 lines)
- `ggml-sycl.h` - SYCL support (50 lines)
- `ggml-vulkan.h` - Vulkan support (30 lines)
- `ggml-webgpu.h` - WebGPU support (20 lines)
- `ggml-cann.h` - CANN support (124 lines)
- `ggml-blas.h` - BLAS support (26 lines)
- `ggml-cpp.h` - C++ utilities (40 lines)
- `ggml-rpc.h` - RPC support (31 lines)

### File Format
- `gguf.h` - GGUF file format (203 lines)

### Multi-Threading
- `mtmd.h` - Multi-threaded matrix operations (308 lines)
- `mtmd-helper.h` - Helper functions (97 lines)

## API Coverage

The generated bindings include:

### Functions
- **Model Management**: Loading, freeing, metadata access
- **Context Management**: Creation, configuration, cleanup
- **Tokenization**: Text ↔ token conversion
- **Inference**: Encoding, decoding, batch processing
- **Embeddings**: Vector generation
- **Sampling**: Various sampling strategies
- **State Management**: Save/load model state
- **Performance**: Timing and profiling
- **GGML Operations**: Tensor creation and manipulation
- **GGUF Support**: File format reading/writing

### Enums
- 32 enums covering:
  - Model types and parameters
  - Tensor types and operations
  - Backend types
  - Pooling and attention types
  - Vocabulary types
  - And more...

### Structs
- Forward declarations for opaque types (context, model, etc.)
- Complete definitions for:
  - `llama_batch` - Batch processing
  - Model parameters
  - Context parameters
  - Token data structures
  - And more...

## Usage Pattern

```dart
import 'package:llama_ffi/llama_ffi.dart';

// 1. Initialize
final llama = LlamaFFI();  // or with custom path
final bindings = llama.bindings;

// 2. Use the bindings
bindings.llama_backend_init();
final model = bindings.llama_model_load_from_file(...);
// ... use model ...
bindings.llama_model_free(model);
bindings.llama_backend_free();
```

## Dependencies

### Runtime Dependencies
- `ffi: ^2.1.3` - Dart FFI package
- `path: ^1.9.0` - Path utilities

### Development Dependencies
- `ffigen: ^20.1.1` - FFI binding generator
- `lints: ^6.0.0` - Dart linter
- `test: ^1.25.6` - Testing framework

## Regenerating Bindings

To regenerate the bindings after updating headers:

```bash
cd llama-ffi
dart run ffigen --config ffigen.yaml
```

This will:
1. Parse all specified header files
2. Generate Dart equivalents for structs, enums, and functions
3. Output to `lib/src/llama_bindings_generated.dart`

## Platform Compatibility

The bindings are platform-agnostic. You need to provide the llama.cpp shared library for your platform:

- **Linux**: `libllama.so`
- **macOS**: `libllama.dylib`
- **Windows**: `llama.dll`

The `LlamaFFI` class will auto-detect the library in common locations, or you can specify the path explicitly.

## Testing

Run tests with:

```bash
dart test
```

Note: Most functionality tests require the actual llama.cpp library to be available.

## Analysis

Check code quality with:

```bash
dart analyze
```

Current status: ✅ No issues found!

## Next Steps

To use this package:

1. Build llama.cpp as a shared library (see README.md)
2. Place the library where it can be found, or note its path
3. Use the examples as a starting point
4. Refer to API_REFERENCE.md for available functions
5. Check the llama.cpp documentation for detailed API behavior

## Notes

- Some warnings during binding generation are expected (forward declarations, private structs)
- The bindings closely follow the C API - refer to llama.cpp docs for detailed usage
- Memory management is manual - use `calloc`/`free` appropriately
- Always check return values for errors


