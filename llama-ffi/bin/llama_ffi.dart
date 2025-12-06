import 'package:llama_ffi/llama_ffi.dart';

void main(List<String> arguments) {
  print('Llama FFI Example');
  print('=================\n');

  try {
    // Initialize the llama.cpp library
    // You can provide a custom path to the library:
    // final llama = LlamaFFI(libraryPath: '/path/to/libllama.so');
    
    // Or let it auto-detect (will throw if not found):
    final llama = LlamaFFI();

    print('✓ Successfully loaded llama.cpp library');
    print('  Bindings are available via llama.bindings\n');

    // Example: Get backend count
    try {
      final backendCount = llama.bindings.ggml_backend_reg_count();
      print('Available backends: $backendCount');
    } catch (e) {
      print('Note: Some functions may require the full llama.cpp library to be built');
    }

    print('\nYou can now use the bindings to:');
    print('  - Load models: llama.bindings.llama_model_load_from_file()');
    print('  - Create contexts: llama.bindings.llama_new_context_with_model()');
    print('  - Generate tokens: llama.bindings.llama_decode()');
    print('  - And much more!');
    
  } catch (e) {
    print('Error loading llama.cpp library:');
    print('  $e\n');
    print('To use this library, you need to:');
    print('  1. Build llama.cpp as a shared library');
    print('  2. Place it in a location where it can be found');
    print('  3. Or provide the path explicitly when initializing LlamaFFI\n');
    print('Example:');
    print('  final llama = LlamaFFI(libraryPath: "/path/to/libllama.so");');
  }
}
