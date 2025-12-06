# Llama FFI Setup Guide

This Flutter app demonstrates using llama.cpp via FFI bindings on Android emulator.

## Prerequisites

- Flutter SDK
- Android Studio with x86_64 emulator configured
- The llama.cpp native libraries already placed in `android/app/src/main/jniLibs/x86_64/`

## Project Structure

```
lib/
  ├── main.dart                    # Main app with model download and inference
  └── internal/
      └── llama_ffi.dart          # FFI bindings generated from llama.cpp

android/app/src/main/jniLibs/x86_64/
  ├── libggml-base.so
  ├── libggml-cpu.so
  ├── libggml.so
  ├── libllama.so
  └── libmtmd.so
```

## Features

The app includes:

1. **Model Download**: Downloads TinyLlama-1.1B-Chat-v1.0 (Q4_K_M quantized, ~669MB) from Hugging Face
2. **Model Loading**: Loads the GGUF model using llama.cpp FFI bindings
3. **Text Generation**: Generates responses using greedy sampling
4. **Real-time UI**: Shows download progress and generation status

## Running the App

### 1. Start the Android Emulator

Make sure you're using an x86_64 emulator (not ARM). You can check with:

```bash
flutter devices
```

### 2. Run the App

```bash
flutter run
```

### 3. Using the App

1. **Download Model**: Tap the "Download Model" button on first launch
   - The app will download the TinyLlama model (~669MB)
   - Progress is shown with a progress bar
   - The model is cached in app documents directory

2. **Generate Text**: Once the model is downloaded:
   - Enter a prompt in the text field (default: "Hello, how are you?")
   - Tap "Generate" to run inference
   - Watch as the response is generated token by token
   - Generation uses greedy sampling (deterministic output)

## Model Information

- **Model**: TinyLlama-1.1B-Chat-v1.0
- **Quantization**: Q4_K_M (4-bit quantization)
- **Size**: ~669MB
- **Source**: https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF
- **Format**: GGUF (unified format for GGML models)

## Configuration

You can modify the generation parameters in `main.dart`:

```dart
// Context settings
ctxParams.n_ctx = 512;        // Context window size
ctxParams.n_batch = 512;      // Batch size
ctxParams.n_threads = 4;      // Number of CPU threads

// Generation settings
final maxGenTokens = 128;     // Max tokens to generate
```

## Chat Template

The app uses TinyLlama's chat template format:

```
<|system|>
You are a helpful assistant.</s>
<|user|>
{prompt}</s>
<|assistant|>
```

## Troubleshooting

### Library Not Found Error

If you get an error about `libllama.so` not being found:
- Verify libraries are in `android/app/src/main/jniLibs/x86_64/`
- Make sure you're using an x86_64 emulator
- Clean and rebuild: `flutter clean && flutter run`

### Download Fails

If model download fails:
- Check internet connection
- Check available storage space (need ~700MB free)
- Try downloading manually and placing in app documents directory

### Out of Memory

If you get OOM errors:
- Reduce `n_ctx` in context params (e.g., to 256)
- Reduce `maxGenTokens` (e.g., to 64)
- Close other apps to free memory

### Slow Generation

Generation speed depends on:
- Emulator performance (native > emulated)
- Number of threads (`n_threads`)
- Quantization level (Q4_K_M is a good balance)

## Changing Models

To use a different model:

1. Update the model URL in `main.dart`:
```dart
static const String modelUrl = 'https://huggingface.co/.../your-model.gguf';
static const String modelFileName = 'your-model.gguf';
```

2. Update the chat template if needed (different models use different formats)

### Recommended Small Models for Testing

- **TinyLlama 1.1B**: Current default, fast and lightweight
- **Phi-2 2.7B**: Higher quality, needs more memory
- **Qwen 0.5B**: Even smaller, very fast

## Performance Tips

1. **Use Q4_K_M quantization**: Good balance of size and quality
2. **Increase threads**: Set `n_threads` to match CPU cores
3. **Reduce context**: Lower `n_ctx` if you don't need long context
4. **Use greedy sampling**: Faster than other sampling methods
5. **Profile device**: Test on real device for better performance

## Next Steps

- Implement streaming generation for better UX
- Add different sampling methods (temperature, top-k, top-p)
- Support multiple chat turns with context management
- Add model selection UI
- Implement quantization on-device
- Add performance metrics (tokens/second)

## References

- [llama.cpp](https://github.com/ggml-org/llama.cpp)
- [TinyLlama](https://github.com/jzhang38/TinyLlama)
- [GGUF Format](https://github.com/ggml-org/ggml/blob/master/docs/gguf.md)
