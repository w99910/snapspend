# Llama/Qwen3 Receipt Data Extraction

## Overview

The SnapSpend app now uses the **Qwen3-0.6B** AI model via llama.cpp to extract structured data from receipt text. This provides more accurate extraction of sender, recipient, amount, and time information compared to traditional regex-based parsing.

## Features

### Extracted Fields

The system extracts the following information in JSON format:

- **sender**: The merchant/store name
- **recipient**: The customer name (or "N/A" if not found)
- **amount**: The total transaction amount (as a number)
- **time**: The date and/or time of the transaction

### Workflow

1. **OCR Scanning**: Tesseract OCR extracts raw text from the receipt image
2. **AI Extraction**: Qwen3 model processes the text to extract structured data
3. **Validation**: Data is validated and normalized to ensure consistency
4. **Fallback**: If AI extraction fails, falls back to regex-based parsing

## Architecture

### Components

```
lib/services/
├── ocr_service.dart          # Main OCR + AI extraction service
├── llama_service.dart        # Llama.cpp FFI bindings & model management
```

### New Methods

#### OcrService.extractReceiptDataWithLlama()

```dart
Future<Map<String, dynamic>> extractReceiptDataWithLlama({
  required String receiptText,
  Function(String)? onStatusUpdate,
  Function(String)? onTextUpdate,
}) async
```

**Parameters:**
- `receiptText`: The raw OCR text from the receipt
- `onStatusUpdate`: Optional callback for status updates (e.g., "Loading model...", "Generating...")
- `onTextUpdate`: Optional callback for real-time text generation updates

**Returns:**
```json
{
  "sender": "Starbucks Coffee",
  "recipient": "N/A",
  "amount": 12.50,
  "time": "2024-12-06 14:30"
}
```

**Error Handling:**
- Throws exception if model is not downloaded
- Returns structured error data if extraction fails
- Validates and normalizes all fields

### Model Management

The Qwen3 model is automatically managed by the `LlamaService`:

- **Model**: Qwen3-0.6B-Q4_0.gguf (~400MB)
- **Source**: Hugging Face (unsloth/Qwen3-0.6B-GGUF)
- **Format**: GGUF (llama.cpp compatible)
- **Quantization**: Q4_0 (4-bit for smaller size)

#### Accessing LlamaService

```dart
final ocrService = OcrService();
final llamaService = ocrService.llamaService;

// Check if model exists
final exists = await llamaService.checkModelExists();

// Download model
await llamaService.downloadModel(
  onProgress: (progress, message) {
    print('$message (${(progress * 100).toInt()}%)');
  },
);
```

## Usage Examples

### Basic Usage

```dart
final ocrService = OcrService();

// 1. Scan receipt with OCR
final receiptText = await ocrService.scanReceipt('/path/to/receipt.jpg');

// 2. Extract structured data with AI
final receiptData = await ocrService.extractReceiptDataWithLlama(
  receiptText: receiptText,
  onStatusUpdate: (status) => print('Status: $status'),
  onTextUpdate: (text) => print('Generated: $text'),
);

// 3. Use extracted data
print('Merchant: ${receiptData['sender']}');
print('Amount: \$${receiptData['amount']}');
print('Date: ${receiptData['time']}');
```

### With Progress Tracking

```dart
final ocrService = OcrService();

// Check and download model if needed
if (!await ocrService.llamaService.checkModelExists()) {
  print('Downloading Qwen3 model...');
  await ocrService.llamaService.downloadModel(
    onProgress: (progress, message) {
      print('$message (${(progress * 100).toInt()}%)');
    },
  );
}

// Process receipt
final receiptText = await ocrService.scanReceipt(imagePath);

final receiptData = await ocrService.extractReceiptDataWithLlama(
  receiptText: receiptText,
  onStatusUpdate: (status) {
    // Update UI with status
    setState(() {
      statusMessage = status;
    });
  },
  onTextUpdate: (text) {
    // Show real-time generation (optional)
    print('AI generating: $text');
  },
);
```

### Integrated Scanning (Current Implementation)

The `ScanningReceiptsPage` automatically:

1. Checks if the Qwen3 model is downloaded
2. Prompts user to download if missing
3. Scans each receipt with OCR
4. Extracts structured data with AI
5. Falls back to basic parsing if AI fails
6. Displays all extracted information in the UI

See `lib/pages/scanning_receipts_page.dart` for full implementation.

## AI Prompt Design

The extraction uses a carefully designed prompt to ensure JSON output:

```
Extract the following information from this receipt text and return ONLY a valid JSON object with these exact fields:
- sender: The merchant/store name
- recipient: The customer name (if mentioned, otherwise "N/A")
- amount: The total amount as a number (extract just the numeric value)
- time: The date and/or time of the transaction (in any format found)

Receipt text:
{OCR_TEXT}

Return only the JSON object, no other text or explanation.
```

## Performance

### Model Specifications

- **Size**: ~400MB (Q4_0 quantization)
- **Speed**: ~5-10 tokens/second on typical mobile devices
- **Context**: 1024 tokens (sufficient for most receipts)
- **Max Generation**: 256 tokens (enough for structured data)

### Optimization Tips

1. **Use Q4_0 quantization** for smaller size (current default)
2. **Adjust thread count** based on device CPU cores
3. **Reduce context size** if receipts are short
4. **Cache model** in app documents directory (already implemented)

## Error Handling

### Model Not Found

```dart
try {
  final data = await ocrService.extractReceiptDataWithLlama(
    receiptText: text,
  );
} catch (e) {
  if (e.toString().contains('model not found')) {
    // Prompt user to download model
    await ocrService.llamaService.downloadModel(/*...*/);
  }
}
```

### Extraction Failure

The method includes automatic fallback to regex-based parsing:

```dart
try {
  extractedData = await ocrService.extractReceiptDataWithLlama(/*...*/);
} catch (llamaError) {
  // Falls back to basic parsing
  final parsedData = ocrService.parseReceiptText(text);
  extractedData = {
    'sender': parsedData['merchant'] ?? 'N/A',
    'recipient': 'N/A',
    'amount': parsedData['total'] ?? 0.0,
    'time': parsedData['date'] ?? 'N/A',
  };
}
```

### Malformed JSON

The extraction includes robust JSON parsing:

1. Attempts to parse entire response as JSON
2. Uses regex to find JSON object in response
3. Validates and normalizes all fields
4. Returns error structure if all parsing fails

## Configuration

### Model Parameters (LlamaService)

```dart
final response = await llamaService.generateText(
  prompt: prompt,
  maxTokens: 256,        // Max tokens to generate
  contextSize: 1024,     // Context window size
  batchSize: 512,        // Batch size for processing
  threads: 4,            // CPU threads
  onStatusUpdate: (status) => print(status),
  onTextUpdate: (text) => print(text),
);
```

### Changing Models

To use a different model, update `LlamaService`:

```dart
// In lib/services/llama_service.dart
static const String modelUrl = 'https://huggingface.co/...';
static const String modelFileName = 'your-model.gguf';
```

**Recommended models:**
- **Qwen3-0.6B** (current): Fast, lightweight, good for extraction
- **Phi-2 2.7B**: Higher quality, needs more memory
- **TinyLlama 1.1B**: Balanced option

## Testing

### Manual Testing

```bash
# Run the app
flutter run

# The scanning page will:
# 1. Check for model
# 2. Prompt to download if needed
# 3. Process receipts with AI
# 4. Display extracted data
```

### Debug Output

The implementation includes extensive logging:

```
Scanning receipt IMG_1234.jpg...
Status: Initializing llama.cpp...
Status: Loading model...
Status: Tokenizing prompt...
Status: Generating response... (45 tokens in prompt)
Status: Generating... (15 tokens)
Llama response: {"sender": "Starbucks", "recipient": "N/A", "amount": 12.50, "time": "2024-12-06"}
✓ Extracted data: {sender: Starbucks, recipient: N/A, amount: 12.5, time: 2024-12-06}
✓ Scanned IMG_1234.jpg:
  Sender: Starbucks
  Recipient: N/A
  Amount: $12.50
  Time: 2024-12-06
```

## UI Integration

The receipt list item now displays:

- **Merchant name** (sender) with store icon
- **Transaction time** with clock icon
- **Amount** (prominently displayed)
- **Filename** (small, for reference)

All information is extracted by the AI and displayed automatically.

## Future Enhancements

Possible improvements:

1. **Multi-language support**: Add support for non-English receipts
2. **Item extraction**: Extract individual line items, not just totals
3. **Category classification**: Auto-categorize expenses (food, transport, etc.)
4. **Tax extraction**: Separate tax from total amount
5. **Confidence scores**: Return confidence for each extracted field
6. **Streaming UI**: Show token generation in real-time
7. **Model selection**: Let users choose between speed/quality

## Troubleshooting

### Model Download Fails

- Check internet connection
- Ensure sufficient storage (~500MB free)
- Check Hugging Face URL is accessible

### Slow Generation

- Reduce `contextSize` to 512
- Reduce `maxTokens` to 128
- Increase `threads` to match CPU cores
- Test on real device (faster than emulator)

### Incorrect Extraction

- Check OCR quality (preprocessing may help)
- Try different prompt wording
- Fallback to regex parsing is automatic
- Consider using larger model (Phi-2)

### Out of Memory

- Use smaller quantization (Q4_0 is already small)
- Reduce context size
- Close other apps
- Increase Android app memory limit

## References

- [llama.cpp](https://github.com/ggml-org/llama.cpp)
- [Qwen3 Model](https://huggingface.co/Qwen/Qwen3-0.6B)
- [GGUF Format](https://github.com/ggml-org/ggml/blob/master/docs/gguf.md)
- [Flutter FFI](https://dart.dev/guides/libraries/c-interop)








