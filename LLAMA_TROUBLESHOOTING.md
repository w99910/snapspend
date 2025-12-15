# Llama Model Output Issues - Troubleshooting Guide

## Common Issue: Repetitive Nonsense Output

### Problem Description

The Qwen3 model sometimes generates repetitive nonsense instead of valid JSON:

```
✓ Extracted data: {
  sender: N/A, 
  recipient: N/A, 
  amount: 0.0, 
  time: N/A, 
  raw_response: "4. 4. 4. 4. 4. 4. 4. 4. 4. ...",
  error: Failed to extract structured data
}
```

Or repeating Thai text:
```
raw_response: "ค่าธรรมเนียม] ณ 25 ต.ค. 68 19:45 น. ณ 18 ต.ค. 68 19:45 น. ณ 18 ต.ค. 68 19:45 น..."
```

### Root Causes

1. **Greedy Sampling**: Using deterministic greedy sampling can lead to repetitive loops
2. **Long Input Context**: Too much OCR text overwhelms the small model
3. **Unclear Prompt**: Model doesn't understand the task clearly
4. **No Stopping Criteria**: Model continues generating even after task is complete
5. **Model Size**: 0.6B parameter model is small and can hallucinate

## Solutions Implemented

### 1. Repetition Detection

Added automatic detection of repetitive output:

```dart
bool _isRepetitiveOutput(String text) {
  // Check for consecutive identical words/tokens
  // Example: "4. 4. 4. 4." → detected
  
  // Check for repeating patterns
  // Example: "ณ 18 ต.ค. 68 19:45 น. ณ 18 ต.ค. 68 19:45 น." → detected
  
  return maxRepeat > 5 || hasRepeatingPattern;
}
```

**What it does:**
- Counts consecutive identical words (> 5 = repetitive)
- Detects repeating patterns using regex
- Throws exception if repetition detected
- Falls back to basic regex parsing

### 2. Improved Prompt

**Before:**
```
Extract the following information from this receipt text and return ONLY a valid JSON object with these exact fields:
- sender: The merchant/store name
- recipient: The customer name (if mentioned, otherwise "N/A")
...
```

**After:**
```
Extract receipt information and return JSON only.

Receipt:
{truncated_text}

Return this format:
{"sender":"store name","recipient":"N/A","amount":0.0,"time":"date"}

Rules: sender=store, recipient=customer or N/A, amount=total number, time=date. JSON only:
```

**Improvements:**
- Shorter, clearer prompt
- Explicit format example
- Concise rules
- Ends with "JSON only:" to guide model output

### 3. Input Truncation

Long OCR text is now truncated to prevent overwhelming the model:

```dart
final truncatedText = receiptText.length > 500 
    ? receiptText.substring(0, 500) + '...'
    : receiptText;
```

**Why:**
- Small models (0.6B) have limited capacity
- First 500 chars usually contain key info
- Reduces context confusion
- Faster generation

### 4. Reduced Token Limits

**Old settings:**
```dart
maxTokens: 256
contextSize: 1024
batchSize: 512
```

**New settings:**
```dart
maxTokens: 100      // Stop sooner
contextSize: 768    // Smaller context
batchSize: 256      // Smaller batch
```

**Benefits:**
- Less time for model to go off-track
- Faster generation
- Lower memory usage
- Forces concise output

### 5. Better JSON Extraction

Enhanced JSON parsing with multiple strategies:

```dart
Map<String, dynamic>? _extractJsonFromResponse(String response) {
  // Strategy 1: Find JSON objects with key fields
  // Strategy 2: Look for JSON-like structures in lines
  // Strategy 3: Validate that JSON has expected fields
}
```

**Improvements:**
- Checks for "sender", "amount", "time" in JSON
- Tries multiple parsing approaches
- Validates structure before accepting
- Handles malformed JSON gracefully

### 6. Graceful Fallback

When Llama fails, automatically falls back to regex-based parsing:

```dart
try {
  extractedData = await ocrService.extractReceiptDataWithLlama(...);
} catch (llamaError) {
  print('⚠️ Llama extraction failed, falling back to basic parsing');
  final parsedData = ocrService.parseReceiptText(text);
  extractedData = {
    'sender': parsedData['merchant'] ?? 'N/A',
    'recipient': 'N/A',
    'amount': parsedData['total'] ?? 0.0,
    'time': parsedData['date'] ?? 'N/A',
  };
}
```

**Benefits:**
- User never sees failure
- Basic extraction still works
- Receipts still get saved
- App remains functional

## Testing the Fixes

### Manual Testing

1. **Scan a receipt** with mixed language text (English + Thai)
2. **Check console output** for:
   ```
   ✓ Extracted data: {sender: Store Name, ...}
   ```
   OR
   ```
   ⚠️ Detected repetitive output, discarding
   ⚠️ Llama extraction failed, falling back to basic parsing
   ```

3. **Verify fallback works** - receipt should still be saved even if Llama fails

### Expected Behavior

**Success case:**
```
Scanning receipt IMG_1234.jpg...
Status: Extracting data with Qwen3 AI...
Llama response: {"sender":"Starbucks","recipient":"N/A","amount":12.5,"time":"2024-12-06"}
✓ Extracted data: {sender: Starbucks, recipient: N/A, amount: 12.5, time: 2024-12-06}
✓ Saved to database
```

**Failure case with fallback:**
```
Scanning receipt IMG_1234.jpg...
Status: Extracting data with Qwen3 AI...
Llama response: 4. 4. 4. 4. 4. 4. 4. 4. ...
⚠️ Detected 15 consecutive repetitions
⚠️ Llama extraction failed, falling back to basic parsing: Failed to extract structured data from model output
✓ Using fallback parser
✓ Extracted data: {sender: Starbucks, recipient: N/A, amount: 12.5, time: 2024-12-06}
✓ Saved to database
```

## Advanced Solutions (If Issues Persist)

### Option 1: Use Temperature Sampling

Instead of greedy sampling, use temperature-based sampling:

**Pros:**
- More diverse output
- Less repetitive
- Better for creative tasks

**Cons:**
- Requires changes to llama_service.dart
- May produce less consistent output
- Slightly slower

**Implementation:**
Would require adding `llama_sampler_init_dist()` with temperature parameter in the FFI bindings.

### Option 2: Use a Larger Model

Switch from Qwen3-0.6B to a larger model:

**Options:**
- **Qwen3-1.5B**: More capable, ~1GB
- **Phi-2 (2.7B)**: Better reasoning, ~1.6GB
- **TinyLlama-1.1B**: Balanced option, ~669MB

**Trade-offs:**
- Better output quality
- Slower generation
- More memory usage
- Larger download

**How to change:**
Update `lib/services/llama_service.dart`:
```dart
static const String modelUrl = 'https://huggingface.co/...';
static const String modelFileName = 'larger-model.gguf';
```

### Option 3: Fine-tune the Model

Train a custom model specifically for receipt extraction:

**Pros:**
- Optimal performance for receipts
- No repetition issues
- Faster generation

**Cons:**
- Requires ML expertise
- Time-consuming
- Needs training data

### Option 4: Use Cloud API

Use a cloud-based LLM API instead of on-device:

**Options:**
- OpenAI GPT-4
- Anthropic Claude
- Google PaLM

**Pros:**
- Much better quality
- No repetition issues
- Always up-to-date

**Cons:**
- Requires internet
- Costs money per request
- Privacy concerns

## Configuration Tuning

### If Model is Too Slow

Reduce quality for speed:
```dart
maxTokens: 50        // Even shorter
contextSize: 512     // Smaller context
threads: 8           // More threads (if CPU supports)
```

### If Output Quality is Poor

Increase quality parameters:
```dart
maxTokens: 150       // More generation space
contextSize: 1024    // Full context
// And increase input truncation:
truncatedText = receiptText.length > 800 ? ...
```

### If Memory Issues

Reduce memory usage:
```dart
contextSize: 512     // Half the context
batchSize: 128       // Smaller batches
```

## Monitoring and Debugging

### Console Logs to Watch

**Good output:**
```
✓ Extracted data: {sender: ..., amount: ...}
✓ Saved to database
```

**Warning signs:**
```
⚠️ Detected 10 consecutive repetitions
⚠️ Detected repeating pattern
⚠️ Llama extraction failed, falling back
```

**Critical errors:**
```
❌ Failed to load model
❌ Out of memory
❌ Model file corrupt
```

### Performance Metrics

Track these in production:
- **Success rate**: % of receipts successfully extracted
- **Fallback rate**: % using regex fallback
- **Average time**: Time per receipt
- **Error types**: Which errors are most common

## FAQ

### Q: Why does it work sometimes and fail other times?

**A:** Small models are inconsistent. The same receipt can produce different results based on:
- Random variations in token selection
- Model internal state
- Context length
- Input text variations

### Q: Can I use multiple models?

**A:** Yes! You could:
1. Try Qwen3 first
2. If it fails, try TinyLlama
3. If both fail, use regex fallback

### Q: Should I use on-device or cloud API?

**A:** Depends on your needs:

| Factor | On-Device | Cloud API |
|--------|-----------|-----------|
| Privacy | ✅ Best | ❌ Data sent to server |
| Cost | ✅ Free | ❌ Pay per request |
| Speed | ⚠️ Medium | ✅ Fast |
| Quality | ⚠️ Variable | ✅ Excellent |
| Offline | ✅ Works | ❌ Needs internet |

For a receipt app, **on-device is recommended** for privacy.

### Q: How can I improve accuracy?

1. **Better OCR**: Improve image preprocessing
2. **Truncate wisely**: Keep merchant name and total
3. **Post-processing**: Validate extracted data
4. **User feedback**: Let users correct mistakes
5. **Retry logic**: Try extraction multiple times

## Best Practices

1. **Always have fallback** - Never rely 100% on AI
2. **Validate output** - Check for reasonable values
3. **Log everything** - Debug issues in production
4. **Monitor performance** - Track success rates
5. **Update prompts** - Iterate based on real data
6. **Test extensively** - Try various receipt types
7. **Handle errors gracefully** - Never crash the app

## References

- [llama.cpp Sampling](https://github.com/ggml-org/llama.cpp/blob/master/common/sampling.h)
- [GGUF Models](https://huggingface.co/models?library=gguf)
- [Qwen3 Documentation](https://github.com/QwenLM/Qwen)
- [Receipt OCR Best Practices](https://www.microsoft.com/en-us/research/project/receipt-ocr/)




