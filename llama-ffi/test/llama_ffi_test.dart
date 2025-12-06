import 'package:llama_ffi/llama_ffi.dart';
import 'package:test/test.dart';

void main() {
  group('LlamaFFI', () {
    test('should export LlamaBindings class', () {
      // The LlamaBindings class should be available
      expect(LlamaBindings, isNotNull);
    });

    test('should export LlamaFFI helper class', () {
      // The LlamaFFI helper class should be available
      expect(LlamaFFI, isNotNull);
    });

    // Note: Actual functionality tests require the llama.cpp shared library
    // to be available. These tests just verify the bindings are properly exported.
    
    test('LlamaFFI constructor should accept optional library path', () {
      // This will fail if the library is not found, which is expected in CI
      expect(
        () => LlamaFFI(libraryPath: '/nonexistent/path/libllama.so'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
