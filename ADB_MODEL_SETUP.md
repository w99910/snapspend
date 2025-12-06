# Using Pre-downloaded Model via ADB

Since you already have the Qwen3-0.6B model downloaded, you can avoid re-downloading it by using adb to place it where the app can find it.

## Quick Setup

### 1. Verify Model Location on Device

```bash
adb shell ls -lh /data/local/tmp/Qwen3-0.6B-Q4_K_M.gguf
```

Expected output:
```
-rw-rw-rw- 1 shell shell 400M Dec  6 15:30 /data/local/tmp/Qwen3-0.6B-Q4_K_M.gguf
```

### 2. If Model Needs to be Pushed

If the model isn't there yet, push it from your local machine:

```bash
# If you have the model locally
adb push /path/to/Qwen3-0.6B-Q4_K_M.gguf /data/local/tmp/

# Example:
adb push ~/Downloads/Qwen3-0.6B-Q4_K_M.gguf /data/local/tmp/
```

### 3. Verify Permissions (Important!)

Make the file readable by all apps:

```bash
adb shell chmod 666 /data/local/tmp/Qwen3-0.6B-Q4_K_M.gguf
```

### 4. Run the App

```bash
flutter run
```

## What Happens in the App

When you tap "Download Model", the app will:

1. ✅ **Check app directory** - See if model already copied
2. ✅ **Check /data/local/tmp** - Look for your pre-downloaded model
3. ✅ **Copy to app directory** - If found, copy it (much faster than download!)
4. ⬇️ **Download** - Only if not found locally

## Expected Behavior

### Success Case (Model Found)
```
Status Updates:
"Checking for model..."
  ↓
"Checking /data/local/tmp for existing model..."
  ↓
"Found model in /data/local/tmp, copying to app directory..."
  ↓
"Copying model (400.0 MB)..."
  ↓
"Model copied successfully! (400.0 MB)"
```

This should take only **5-10 seconds** instead of downloading ~400MB!

### Fallback Case (Model Not Found)
```
Status Updates:
"Checking for model..."
  ↓
"Checking /data/local/tmp for existing model..."
  ↓
"Downloading model from Hugging Face..."
  ↓
"Downloading: 50.0MB / 400.0MB"
  ↓
"Model downloaded successfully!"
```

## Troubleshooting

### "Could not copy from /data/local/tmp"

**Cause**: Permission denied or file not readable

**Fix**:
```bash
# Make file readable
adb shell chmod 666 /data/local/tmp/Qwen3-0.6B-Q4_K_M.gguf

# Or push again with correct permissions
adb push Qwen3-0.6B-Q4_K_M.gguf /data/local/tmp/
adb shell chmod 666 /data/local/tmp/Qwen3-0.6B-Q4_K_M.gguf
```

### "File not found"

**Verify path**:
```bash
adb shell ls /data/local/tmp/ | grep Qwen
```

**Check filename matches exactly**:
```bash
# App expects this exact name:
Qwen3-0.6B-Q4_K_M.gguf
```

### Model Copies But App Still Downloads

**Possible issues**:
1. Model file corrupt during copy
2. Insufficient storage space

**Verify copy succeeded**:
```bash
# Check app's documents directory (requires rooted device or emulator)
adb shell run-as com.example.snapspend ls -lh files/
```

## Alternative: Direct Copy to App Directory

If you have root access or using an emulator:

```bash
# Find the app's data directory
APP_DIR="/data/data/com.example.snapspend/app_flutter"

# Create directory if needed
adb shell "run-as com.example.snapspend mkdir -p files"

# Copy directly
adb push Qwen3-0.6B-Q4_K_M.gguf /data/local/tmp/
adb shell "run-as com.example.snapspend cp /data/local/tmp/Qwen3-0.6B-Q4_K_M.gguf files/"
```

Then the app will find it immediately without any copying!

## Model Information

**Current Model**: Qwen3-0.6B-Q4_K_M
- **Size**: ~400MB (smaller than TinyLlama!)
- **Quantization**: Q4_K_M (4-bit)
- **Source**: https://huggingface.co/unsloth/Qwen3-0.6B-GGUF
- **Chat Format**: ChatML style (handled automatically)

## Qwen3 vs TinyLlama

| Feature | Qwen3-0.6B | TinyLlama-1.1B |
|---------|------------|----------------|
| Size | 400MB | 669MB |
| Parameters | 0.6B | 1.1B |
| Speed | Faster | Slower |
| Quality | Good | Better |
| Best For | Quick tests | Better responses |

## Chat Template

The app now uses Qwen3's ChatML format:

```
<|im_start|>system
You are a helpful assistant.<|im_end|>
<|im_start|>user
Hello, how are you?<|im_end|>
<|im_start|>assistant
[Model generates response here]
```

This is handled automatically in the code!

## Performance Expectations

With Qwen3-0.6B on x86_64 emulator:
- **Model Load**: 3-8 seconds (smaller than TinyLlama!)
- **Generation**: 2-5 tokens/second
- **Memory Usage**: ~600MB RAM

## Complete Workflow

```bash
# 1. Ensure model is in /data/local/tmp
adb push Qwen3-0.6B-Q4_K_M.gguf /data/local/tmp/
adb shell chmod 666 /data/local/tmp/Qwen3-0.6B-Q4_K_M.gguf

# 2. Run the app
flutter run

# 3. In the app:
#    - Tap "Download Model" (will copy instead!)
#    - Wait 5-10 seconds for copy
#    - Enter prompt
#    - Tap "Generate"
#    - Watch response appear!
```

## Benefits of This Approach

✅ **No re-download** - Saves time and bandwidth
✅ **Faster setup** - Copy is much faster than download
✅ **Works offline** - No internet needed after model is placed
✅ **Easy to swap models** - Just push different GGUF files
✅ **Automatic fallback** - Downloads if file not found

## Testing Different Models

Want to try other models? Just push them to `/data/local/tmp/`:

```bash
# Small and fast
adb push phi-2-Q4_K_M.gguf /data/local/tmp/Qwen3-0.6B-Q4_K_M.gguf

# Update modelUrl in main.dart to match, or rename the file
```

Remember to update the `modelFileName` constant in `main.dart` if using a different file!

## Success! ✅

If you see "Model copied successfully!", you're all set! The model is now in the app's private directory and ready to use for generation.
