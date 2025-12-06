/// FFI bindings for llama.cpp
///
/// This library provides Dart bindings for the llama.cpp library,
/// allowing you to use large language models in Dart applications.
library;

import 'dart:ffi' as ffi;
import 'dart:io';

// Export the generated bindings
export 'src/llama_bindings_generated.dart';

import 'src/llama_bindings_generated.dart';

/// Helper class to load and initialize the llama.cpp library
class LlamaFFI {
  late final LlamaBindings _bindings;
  late final ffi.DynamicLibrary _dylib;

  /// Get the bindings instance
  LlamaBindings get bindings => _bindings;

  /// Get the dynamic library instance
  ffi.DynamicLibrary get dylib => _dylib;

  /// Initialize the llama.cpp library
  ///
  /// [libraryPath] - Optional path to the llama.cpp shared library.
  /// If not provided, it will attempt to find the library in common locations.
  LlamaFFI({String? libraryPath}) {
    if (libraryPath != null) {
      _dylib = ffi.DynamicLibrary.open(libraryPath);
    } else {
      _dylib = _loadLibrary();
    }
    _bindings = LlamaBindings(_dylib);
  }

  /// Load the llama.cpp library from common locations
  ffi.DynamicLibrary _loadLibrary() {
    // Try to load the library from common locations
    if (Platform.isLinux) {
      // Try common Linux locations
      final possiblePaths = [
        'libllama.so',
        '/usr/lib/libllama.so',
        '/usr/local/lib/libllama.so',
        './libllama.so',
      ];

      for (final libPath in possiblePaths) {
        try {
          return ffi.DynamicLibrary.open(libPath);
        } catch (_) {
          continue;
        }
      }
    } else if (Platform.isMacOS) {
      // Try common macOS locations
      final possiblePaths = [
        'libllama.dylib',
        '/usr/local/lib/libllama.dylib',
        './libllama.dylib',
      ];

      for (final libPath in possiblePaths) {
        try {
          return ffi.DynamicLibrary.open(libPath);
        } catch (_) {
          continue;
        }
      }
    } else if (Platform.isWindows) {
      // Try common Windows locations
      final possiblePaths = [
        'llama.dll',
        'libllama.dll',
        r'C:\Program Files\llama\llama.dll',
        r'.\llama.dll',
      ];

      for (final libPath in possiblePaths) {
        try {
          return ffi.DynamicLibrary.open(libPath);
        } catch (_) {
          continue;
        }
      }
    }

    throw UnsupportedError(
      'Could not find llama.cpp library. '
      'Please provide the library path explicitly.',
    );
  }
}
