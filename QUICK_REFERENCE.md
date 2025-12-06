# Quick Reference Guide

## 🚀 Quick Start

```bash
# 1. Start x86_64 emulator
emulator -avd <your_avd_name>

# 2. Run the app
flutter run

# 3. In the app:
#    - Tap "Download Model" (first time only)
#    - Enter prompt
#    - Tap "Generate"
```

## 📁 Project Structure

```
lib/
  ├── main.dart                    # Main app (downloads + runs model)
  └── internal/
      └── llama_ffi.dart          # FFI bindings (20K+ lines)

android/app/src/main/jniLibs/x86_64/
  ├── libllama.so                 # Main library (29MB)
  ├── libggml*.so                 # Supporting libraries (11MB)
  └── libmtmd.so                  # Multi-threading (4.7MB)
```

## 🔧 Common Commands

```bash
# Get dependencies
flutter pub get

# Clean build
flutter clean
flutter pub get

# Build APK
flutter build apk --debug

# Run on emulator
flutter run

# Check devices
flutter devices

# View logs
flutter logs

# Hot reload
r

# Hot restart
R
```

## 🔍 Debugging

```bash
# Analyze code
flutter analyze

# Run with verbose logging
flutter run -v

# Check for issues
flutter doctor
```

## ⚙️ Configuration

### Edit these in `lib/main.dart`:

```dart
// Model URL (line ~29)
static const String modelUrl = 'https://huggingface.co/...';

// Context size (line ~220)
ctxParams.n_ctx = 512;

// Number of threads (line ~222)
ctxParams.n_threads = 4;

// Max tokens to generate (line ~237)
final maxGenTokens = 128;
```

## 🎯 Key Functions

```dart
_downloadModel()      // Downloads model from HuggingFace
_loadLlamaLibrary()   // Loads native libraries
_generateText()       // Main inference function
```

## 📊 App Flow

```
Launch App
    ↓
Download Model (669MB) ← First time only
    ↓
Enter Prompt
    ↓
Tap Generate
    ↓
Load Native Library
    ↓
Initialize Backend
    ↓
Load Model File
    ↓
Create Context
    ↓
Tokenize Prompt
    ↓
Process Batch
    ↓
Generate Tokens (one by one)
    ↓
Display Results
    ↓
Cleanup Memory
```

## 🐛 Common Issues

| Issue | Solution |
|-------|----------|
| Library not found | Use x86_64 emulator |
| Download fails | Check internet connection |
| Out of memory | Reduce n_ctx to 256 |
| Slow generation | Reduce maxGenTokens |
| Build fails | Run `flutter clean` |

## 📱 Testing Checklist

- [ ] Emulator is x86_64 (not ARM)
- [ ] Internet connection available
- [ ] 1GB+ free space
- [ ] App installs successfully
- [ ] Model downloads completely
- [ ] Generate button works
- [ ] Text appears token by token
- [ ] No crashes during generation

## 💡 Tips

1. **First generation is slow** - Model needs to load into memory
2. **Subsequent generations faster** - Model stays in memory
3. **Restart app** - If memory issues occur
4. **Use real device** - Much faster than emulator
5. **Check file sizes** - All .so files should be present

## 🎨 UI Elements

```
┌─────────────────────────────────┐
│  Llama FFI Demo           ⚙️    │
├─────────────────────────────────┤
│                                 │
│  Status                        │
│  ┌──────────────────────────┐  │
│  │ Ready to download model  │  │
│  └──────────────────────────┘  │
│                                 │
│  [Download Model]              │
│                                 │
│  Prompt                        │
│  ┌──────────────────────────┐  │
│  │ Hello, how are you?      │  │
│  └──────────────────────────┘  │
│                                 │
│  [🪄 Generate]                 │
│                                 │
│  Generated Response            │
│  ┌──────────────────────────┐  │
│  │ Hi! I'm doing great...   │  │
│  └──────────────────────────┘  │
│                                 │
└─────────────────────────────────┘
```

## 🔐 Permissions Required

- **INTERNET**: Download model from HuggingFace
- **WRITE_EXTERNAL_STORAGE**: Save model file
- **READ_EXTERNAL_STORAGE**: Load model file

## 📈 Performance Metrics

| Device Type | Load Time | Generation Speed |
|-------------|-----------|------------------|
| x86_64 Emulator | 5-15s | 1-3 tokens/s |
| Real Device | 2-5s | 3-10 tokens/s |

## 🎓 Learning Resources

- [llama.cpp](https://github.com/ggml-org/llama.cpp) - Native library
- [TinyLlama](https://github.com/jzhang38/TinyLlama) - Model info
- [GGUF Format](https://github.com/ggml-org/ggml/blob/master/docs/gguf.md) - Model format
- [Dart FFI](https://dart.dev/guides/libraries/c-interop) - FFI guide

## 🔄 Workflow for Updates

```bash
# 1. Make changes to lib/main.dart
# 2. Hot reload
r

# If hot reload doesn't work:
R  # Hot restart

# If that doesn't work:
flutter run  # Full restart
```

## 📞 Getting Help

1. Check `IMPLEMENTATION_SUMMARY.md` for details
2. Check `LLAMA_FFI_SETUP.md` for troubleshooting
3. Run `flutter doctor` for environment issues
4. Check `flutter logs` for runtime errors

## ✅ Success Indicators

✓ App launches without errors
✓ Download progress shows correctly
✓ Model loads within 15 seconds
✓ Generation produces text
✓ UI updates in real-time
✓ No memory leaks
✓ Clean shutdown

## 🎉 You're Ready!

Run this to get started:
```bash
./run_emulator.sh
```
