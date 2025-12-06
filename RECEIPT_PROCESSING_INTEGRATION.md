# Receipt Processing Integration with Qwen 3 and SQLite

## Overview
This document describes the complete integration of OCR → Qwen 3 AI processing → SQLite database storage for receipt scanning in SnapSpend.

## Architecture

### Flow
1. **OCR Scanning**: Receipt image is processed with Tesseract OCR
2. **AI Processing**: OCR text is sent to Qwen 3 (via llama.cpp) for structured data extraction
3. **JSON Parsing**: AI response is parsed to extract structured receipt data
4. **Database Storage**: Receipt data is saved to on-device SQLite database

## Components Created

### 1. Receipt Model (`lib/models/receipt.dart`)
Defines the receipt data structure with the following fields:
- `id`: Auto-incrementing primary key (nullable for new receipts)
- `imagePath`: Path to the receipt image file
- `imageTaken`: DateTime when the receipt was scanned
- `amount`: Total amount on the receipt
- `recipient`: Person or company name (nullable)
- `merchantName`: Store or business name (nullable)
- `category`: Category like Food, Shopping, Gas, etc. (nullable)
- `rawOcrText`: Original OCR text (nullable)
- `rawJsonData`: AI response JSON (nullable)

**Key Methods:**
- `toMap()`: Converts receipt to database map
- `fromMap()`: Creates receipt from database query result
- `copyWith()`: Creates a copy with updated fields

### 2. Database Service (`lib/services/database_service.dart`)
Singleton service managing SQLite operations using `sqflite` package.

**Key Features:**
- Automatic database initialization on first use
- CRUD operations for receipts
- Advanced queries:
  - `getAllReceipts()`: Get all receipts ordered by date
  - `getReceiptById()`: Get specific receipt
  - `getReceiptsByDateRange()`: Filter by date range
  - `getTotalAmount()`: Calculate total spending
  - `searchReceipts()`: Search by merchant or recipient

**Database Schema:**
```sql
CREATE TABLE receipts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  image_path TEXT NOT NULL,
  image_taken TEXT NOT NULL,
  amount REAL NOT NULL,
  recipient TEXT,
  merchant_name TEXT,
  category TEXT,
  raw_ocr_text TEXT,
  raw_json_data TEXT
)
```

### 3. Enhanced Receipt Scanner (`lib/pages/receipt_scanner_page.dart`)
Updated with complete AI + Database integration.

**New Features:**
- Integration with `LlamaService` for AI processing
- Integration with `DatabaseService` for storage
- Smart prompt engineering for Qwen 3
- Robust JSON parsing with fallback to basic OCR
- Visual feedback showing database save status
- Navigation to receipts list page

**Processing Pipeline:**
```
1. OCR Scanning → Extract raw text
2. Model Check → Ensure Qwen 3 is available
3. AI Processing → Send prompt to Qwen 3
   Prompt includes:
   - OCR text
   - Required JSON structure
   - Field extraction instructions
4. JSON Parsing → Extract structured data
   - Handles various response formats
   - Removes markdown code blocks
   - Falls back to basic OCR on parse errors
5. Database Storage → Save receipt
6. UI Update → Show success with receipt ID
```

**AI Prompt Format:**
The system uses a carefully crafted prompt that instructs Qwen 3 to:
- Extract merchant name, amount, date, recipient, category, and items
- Return ONLY valid JSON (no extra text)
- Use null for missing fields
- Infer category from merchant/items
- Format date as YYYY-MM-DD
- Format amount as decimal number

### 4. Receipts List Page (`lib/pages/receipts_list_page.dart`)
New page for viewing all saved receipts.

**Features:**
- Summary card showing total spending and receipt count
- Scrollable list of all receipts with thumbnails
- Tap to view detailed receipt information
- Delete receipts with confirmation dialog
- Refresh button to reload data
- Empty state when no receipts exist
- Category badges
- Formatted dates and amounts
- Image preview in detail modal

**UI Components:**
- Gradient summary card at top
- Receipt cards with:
  - Thumbnail image
  - Merchant name
  - Date/time stamp
  - Category badge
  - Amount (highlighted in green)
  - Recipient (if available)
  - Delete button
- Detail modal showing:
  - Full image
  - All metadata
  - Raw OCR text

## Navigation Updates

Added navigation links across the app:

1. **Receipt Scanner Page**
   - AppBar action button → View All Receipts

2. **Llama Demo Page**
   - AppBar action button → Scan Receipt
   - AppBar action button → View All Receipts

## Dependencies Added

```yaml
dependencies:
  sqflite: ^2.3.0    # SQLite database
  intl: ^0.19.0      # Date formatting
```

## Usage Example

### Scanning a Receipt
```dart
// 1. User selects/captures image
final image = await ImagePicker().pickImage(source: ImageSource.camera);

// 2. OCR processing
final ocrText = await OcrService().scanReceipt(image.path);

// 3. AI processing
final aiResponse = await LlamaService().generateText(
  prompt: buildExtractionPrompt(ocrText),
  maxTokens: 256,
);

// 4. Parse JSON
final extractedData = parseAiResponse(aiResponse);

// 5. Save to database
final receipt = Receipt(
  imagePath: image.path,
  imageTaken: DateTime.now(),
  amount: extractedData['amount'],
  recipient: extractedData['recipient'],
  merchantName: extractedData['merchant'],
  category: extractedData['category'],
  rawOcrText: ocrText,
  rawJsonData: jsonEncode(extractedData),
);

final id = await DatabaseService().insertReceipt(receipt);
```

### Querying Receipts
```dart
// Get all receipts
final receipts = await DatabaseService().getAllReceipts();

// Get total spending
final total = await DatabaseService().getTotalAmount();

// Search receipts
final results = await DatabaseService().searchReceipts('Walmart');

// Get by date range
final monthReceipts = await DatabaseService().getReceiptsByDateRange(
  DateTime(2024, 1, 1),
  DateTime(2024, 1, 31),
);
```

## Error Handling

The system includes multiple layers of error handling:

1. **OCR Failures**: Shows error message, doesn't proceed to AI
2. **Model Not Found**: Checks if Qwen 3 model exists before processing
3. **AI Processing Errors**: Shows error in status message
4. **JSON Parse Errors**: Falls back to basic OCR parsing
5. **Database Errors**: Shows error snackbar

## Testing Checklist

- [x] OCR extracts text from receipt images
- [x] Qwen 3 model loads successfully
- [x] AI generates valid JSON responses
- [x] JSON parser handles various formats
- [x] Receipts save to SQLite database
- [x] Receipts list displays saved receipts
- [x] Detail view shows complete receipt info
- [x] Delete functionality works
- [x] Navigation between pages works
- [ ] Test with various receipt formats (physical receipts)
- [ ] Test error scenarios (bad images, no model, etc.)
- [ ] Performance test with many receipts

## Future Enhancements

### Potential Improvements
1. **Batch Processing**: Scan multiple receipts at once
2. **Export**: CSV/PDF export of receipts
3. **Analytics**: Spending trends, category breakdowns, charts
4. **Search Filters**: Filter by category, date range, amount
5. **Edit Receipts**: Allow manual corrections
6. **Backup/Sync**: Cloud backup or export
7. **Receipt Templates**: Learn from user corrections
8. **Image Optimization**: Compress stored images
9. **OCR Improvements**: Better preprocessing for difficult receipts
10. **AI Fine-tuning**: Fine-tune Qwen 3 on receipt-specific data

### Performance Optimizations
- Implement pagination for large receipt lists
- Add image caching
- Lazy load receipt thumbnails
- Index database columns for faster queries
- Implement search debouncing

## Technical Notes

### Database Location
- Android: `/data/data/com.example.snapspend/databases/receipts.db`
- iOS: `Library/Application Support/receipts.db`
- Can be inspected using `adb` or device file browser

### Model Requirements
- Qwen 3 model must be downloaded first (handled in download_model_page.dart)
- Model size: ~600MB
- Requires sufficient device storage
- CPU-only inference (no GPU acceleration yet)

### JSON Format Expected from Qwen 3
```json
{
  "merchant": "Store Name",
  "amount": 123.45,
  "date": "2024-12-06",
  "recipient": "Person Name or null",
  "category": "Food",
  "items": [
    {"name": "Item 1", "price": 10.00},
    {"name": "Item 2", "price": 20.00}
  ]
}
```

## Troubleshooting

### Common Issues

**Issue**: "Qwen 3 model not found"
- **Solution**: Navigate to Download Model page and download the model first

**Issue**: AI returns invalid JSON
- **Solution**: System automatically falls back to basic OCR parsing

**Issue**: OCR text is inaccurate
- **Solution**: Ensure good lighting, clear image, minimal blur

**Issue**: Database errors
- **Solution**: Check device storage space, restart app

**Issue**: Receipts not appearing in list
- **Solution**: Pull to refresh or restart app

## Files Modified

- `pubspec.yaml`: Added sqflite and intl dependencies
- `lib/pages/receipt_scanner_page.dart`: Complete AI + DB integration
- `lib/pages/llama_demo_page.dart`: Added navigation actions

## Files Created

- `lib/models/receipt.dart`: Receipt data model
- `lib/services/database_service.dart`: SQLite database service
- `lib/pages/receipts_list_page.dart`: Receipts viewing page
- `RECEIPT_PROCESSING_INTEGRATION.md`: This documentation

## Summary

The integration is now complete! Every receipt scanned goes through:
1. ✅ OCR with Tesseract
2. ✅ AI processing with Qwen 3 via llama.cpp
3. ✅ JSON data extraction
4. ✅ SQLite database storage

Users can now:
- Scan receipts with camera or gallery
- View automatically extracted data (merchant, amount, date, recipient, category)
- Browse all saved receipts in a dedicated list page
- View detailed information about each receipt
- Delete unwanted receipts
- Track total spending

The system is robust with fallback mechanisms and comprehensive error handling.
