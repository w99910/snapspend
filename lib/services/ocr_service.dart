import 'dart:io';
import 'dart:convert';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'llama_service.dart';

class OcrService {
  final LlamaService _llamaService = LlamaService();

  /// Get access to the Llama service for model management
  LlamaService get llamaService => _llamaService;

  /// Preprocesses an image for better OCR results
  /// - Converts to grayscale
  /// - Ensures DPI is at least 300
  /// - Applies contrast enhancement
  /// - Applies sharpening
  Future<String> preprocessImage(String imagePath) async {
    try {
      // Read the image
      final imageFile = File(imagePath);
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      print('Original image size: ${image.width}x${image.height}');

      // Convert to grayscale
      final grayscale = img.grayscale(image);
      print('Converted to grayscale');

      // Ensure minimum DPI of 300
      // Calculate scaling factor if needed
      const minDpi = 300;
      const targetWidth = 2480; // ~8.27 inches at 300 DPI (A4 width)

      img.Image processed = grayscale;
      if (grayscale.width < targetWidth) {
        final scaleFactor = targetWidth / grayscale.width;
        final newWidth = (grayscale.width * scaleFactor).round();
        final newHeight = (grayscale.height * scaleFactor).round();

        processed = img.copyResize(
          grayscale,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.cubic,
        );
        print('Resized to ${processed.width}x${processed.height} for 300+ DPI');
      }

      // Increase contrast for better text recognition
      // processed = img.contrast(processed, contrast: 120);
      // print('Applied contrast enhancement');

      // Apply sharpening
      // processed = img.convolution(
      //   processed,
      //   filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
      // );
      // print('Applied sharpening');

      // Optional: Apply adaptive thresholding for better text/background separation
      // processed = _adaptiveThreshold(processed);
      // print('Applied adaptive thresholding');

      // Save the processed image
      final tempDir = await getTemporaryDirectory();
      final processedPath = path.join(
        tempDir.path,
        'processed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final processedFile = File(processedPath);
      await processedFile.writeAsBytes(img.encodeJpg(processed, quality: 95));

      print('Preprocessed image saved to: $processedPath');
      return processedPath;
    } catch (e) {
      print('Error preprocessing image: $e');
      rethrow;
    }
  }

  /// Apply adaptive thresholding for better text recognition
  img.Image _adaptiveThreshold(img.Image image) {
    final threshold = img.Image(width: image.width, height: image.height);

    const blockSize = 15;
    const c = 10;

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final gray = pixel.r.toInt();

        // Calculate local mean
        var sum = 0;
        var count = 0;

        for (var dy = -blockSize ~/ 2; dy <= blockSize ~/ 2; dy++) {
          for (var dx = -blockSize ~/ 2; dx <= blockSize ~/ 2; dx++) {
            final nx = x + dx;
            final ny = y + dy;

            if (nx >= 0 && nx < image.width && ny >= 0 && ny < image.height) {
              final neighborPixel = image.getPixel(nx, ny);
              sum += neighborPixel.r.toInt();
              count++;
            }
          }
        }

        final mean = sum ~/ count;
        final localThreshold = mean - c;

        // Apply threshold
        final newValue = gray > localThreshold ? 255 : 0;
        threshold.setPixel(x, y, img.ColorRgb8(newValue, newValue, newValue));
      }
    }

    return threshold;
  }

  /// Scans a receipt image with Tesseract OCR
  /// Returns the extracted text
  Future<String> scanReceipt(String imagePath) async {
    try {
      print('Starting OCR scan for: $imagePath');

      // Preprocess the image for better OCR results
      print('Preprocessing image...');
      final processedPath = await preprocessImage(imagePath);

      // Perform OCR on the preprocessed image
      print('Running Tesseract OCR...');
      final text = await FlutterTesseractOcr.extractText(
        processedPath,
        language: 'eng+tha',
        args: {
          "psm": "6", // Assume a single uniform block of text
          "osm": "1",
          "preserve_interword_spaces": "1",
        },
      );

      print('OCR completed. Extracted text length: ${text.length}');

      // Clean up the preprocessed temporary file
      try {
        await File(processedPath).delete();
        print('Cleaned up temporary preprocessed file');
      } catch (e) {
        print('Warning: Could not delete temporary file: $e');
      }

      return text;
    } catch (e) {
      print('Error scanning receipt: $e');
      rethrow;
    }
  }

  /// Extract structured data from receipt text
  /// Returns a map with receipt information
  Map<String, dynamic> parseReceiptText(String text) {
    final lines = text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final result = <String, dynamic>{
      'rawText': text,
      'merchant': '',
      'date': '',
      'total': 0.0,
      'items': <Map<String, dynamic>>[],
    };

    // Try to find merchant name (usually first few lines)
    if (lines.isNotEmpty) {
      result['merchant'] = lines[0].trim();
    }

    // Pattern for prices: $XX.XX or XX.XX
    final pricePattern = RegExp(r'\$?\s*(\d+\.\d{2})');

    // Pattern for dates
    final datePattern = RegExp(
      r'(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})|(\d{4}[-/]\d{1,2}[-/]\d{1,2})',
    );

    double? maxPrice;

    for (final line in lines) {
      // Look for date
      final dateMatch = datePattern.firstMatch(line);
      if (dateMatch != null && result['date'].isEmpty) {
        result['date'] = dateMatch.group(0) ?? '';
      }

      // Look for prices
      final priceMatches = pricePattern.allMatches(line);
      for (final match in priceMatches) {
        final priceStr = match.group(1);
        if (priceStr != null) {
          final price = double.tryParse(priceStr);
          if (price != null) {
            // Track the highest price as potential total
            if (maxPrice == null || price > maxPrice) {
              maxPrice = price;
            }

            // Try to extract item name (text before the price)
            final itemName = line.substring(0, match.start).trim();
            if (itemName.isNotEmpty) {
              result['items'].add({'name': itemName, 'price': price});
            }
          }
        }
      }

      // Look for total amount (keywords: total, amount, balance)
      if (line.toLowerCase().contains('total') ||
          line.toLowerCase().contains('amount') ||
          line.toLowerCase().contains('balance')) {
        final priceMatch = pricePattern.firstMatch(line);
        if (priceMatch != null) {
          final totalStr = priceMatch.group(1);
          if (totalStr != null) {
            result['total'] = double.tryParse(totalStr) ?? 0.0;
          }
        }
      }
    }

    // If no explicit total found, use the highest price
    if (result['total'] == 0.0 && maxPrice != null) {
      result['total'] = maxPrice;
    }

    return result;
  }

  /// Extract structured receipt data using regex-based pattern matching
  /// Returns a JSON object with sender, recipient, amount, and time
  /// This is faster and more reliable than LLM-based extraction
  Future<Map<String, dynamic>> extractReceiptDataWithLlama({
    required String receiptText,
    Function(String)? onStatusUpdate,
    Function(String)? onTextUpdate,
  }) async {
    try {
      // Update status
      if (onStatusUpdate != null) {
        onStatusUpdate('Extracting receipt data...');
      }

      // Use regex-based extraction directly (much faster than LLM)
      print('📋 Using regex-based extraction for receipt data');
      final result = extractFromThaiReceipt(receiptText);

      // Validate we got some data
      if (result['amount'] == 0.0 &&
          result['sender'] == 'N/A' &&
          result['time'] == 'N/A') {
        throw Exception('Failed to extract any valid data from receipt');
      }

      if (onStatusUpdate != null) {
        onStatusUpdate('Extraction complete!');
      }

      return result;
    } catch (e) {
      print('Error in extractReceiptDataWithLlama: $e');
      rethrow;
    }
  }

  /// Extract JSON object from LLM response text
  Map<String, dynamic>? _extractJsonFromResponse(String response) {
    // Clean response - remove any markdown code blocks
    String cleaned = response.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    }
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    print(
      '🔍 Attempting to parse: ${cleaned.substring(0, cleaned.length > 200 ? 200 : cleaned.length)}...',
    );

    // Try to find JSON object in the response - handle nested braces and Thai text
    // Use a more flexible pattern that handles Unicode (Thai characters)
    final jsonPattern = RegExp(
      r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}',
      multiLine: true,
    );
    final matches = jsonPattern.allMatches(cleaned);

    // First try: look for complete JSON objects
    for (final match in matches) {
      try {
        final jsonStr = match.group(0);
        if (jsonStr != null && jsonStr.length > 10) {
          // Basic sanity check - should have key fields
          if (jsonStr.contains('sender') ||
              jsonStr.contains('amount') ||
              jsonStr.contains('time')) {
            print(
              '✓ Found potential JSON: ${jsonStr.substring(0, jsonStr.length > 100 ? 100 : jsonStr.length)}...',
            );
            final parsed = json.decode(jsonStr);
            if (parsed is Map<String, dynamic>) {
              final validated = _validateAndNormalizeReceiptData(parsed);
              if (validated != null) {
                return validated;
              }
              // If validation failed, continue to next match
              print('⚠️ Validation failed, trying next match...');
            }
          }
        }
      } catch (e) {
        print('⚠️ JSON parse failed for match: $e');
        // Continue to next match
        continue;
      }
    }

    // Second try: look for JSON-like structure even if malformed
    final lines = cleaned.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('{') && trimmed.contains('}')) {
        try {
          final parsed = json.decode(trimmed);
          if (parsed is Map<String, dynamic>) {
            print('✓ Parsed JSON from line');
            final validated = _validateAndNormalizeReceiptData(parsed);
            if (validated != null) {
              return validated;
            }
          }
        } catch (e) {
          continue;
        }
      }
    }

    // Third try: try to extract JSON from the entire response
    try {
      final parsed = json.decode(cleaned);
      if (parsed is Map<String, dynamic>) {
        print('✓ Parsed JSON from entire response');
        final validated = _validateAndNormalizeReceiptData(parsed);
        if (validated != null) {
          return validated;
        }
      }
    } catch (e) {
      // Not valid JSON
      print('⚠️ Full response not valid JSON');
    }

    // Fourth try: If model outputs numbered list, try to parse it
    print('🔧 Attempting to parse numbered list format...');
    final extractedData = _parseNumberedListFormat(cleaned);
    if (extractedData != null) {
      print('✓ Successfully parsed from numbered list');
      return extractedData;
    }

    print('❌ All JSON extraction attempts failed');
    return null;
  }

  /// Parse numbered list format that the model sometimes outputs
  /// Example: "1. sender: GrabPay\n2. recipient: N/A\n3. amount: 62.00\n4. time: ..."
  Map<String, dynamic>? _parseNumberedListFormat(String text) {
    try {
      final result = <String, dynamic>{
        'sender': 'N/A',
        'recipient': 'N/A',
        'amount': 0.0,
        'time': 'N/A',
      };

      // Patterns to extract field values from numbered lists
      final senderPattern = RegExp(
        r'(?:sender|merchant)[:\s]+["' +
            r"']?" +
            r'([^"' +
            r"'" +
            r'\n]+?)["' +
            r"']?" +
            r'(?:\n|$)',
        caseSensitive: false,
      );
      final recipientPattern = RegExp(
        r'recipient[:\s]+["' +
            r"']?" +
            r'([^"' +
            r"'" +
            r'\n]+?)["' +
            r"']?" +
            r'(?:\n|$)',
        caseSensitive: false,
      );
      final amountPattern = RegExp(
        r'amount(?:_in_currency)?[:\s]+["' +
            r"']?" +
            r'(\d+\.?\d*)["' +
            r"']?" +
            r'(?:\n|$)',
        caseSensitive: false,
      );
      final timePattern = RegExp(
        r'(?:time|date_time)[:\s]+["' +
            r"']?" +
            r'([^"' +
            r"'" +
            r'\n]+?)["' +
            r"']?" +
            r'(?:\n|$)',
        caseSensitive: false,
      );

      bool foundAny = false;

      // Extract sender
      final senderMatch = senderPattern.firstMatch(text);
      if (senderMatch != null) {
        result['sender'] = senderMatch.group(1)?.trim() ?? 'N/A';
        foundAny = true;
      }

      // Extract recipient
      final recipientMatch = recipientPattern.firstMatch(text);
      if (recipientMatch != null) {
        result['recipient'] = recipientMatch.group(1)?.trim() ?? 'N/A';
        foundAny = true;
      }

      // Extract amount
      final amountMatch = amountPattern.firstMatch(text);
      if (amountMatch != null) {
        final amountStr = amountMatch.group(1);
        if (amountStr != null) {
          result['amount'] = double.tryParse(amountStr) ?? 0.0;
          foundAny = true;
        }
      }

      // Extract time
      final timeMatch = timePattern.firstMatch(text);
      if (timeMatch != null) {
        result['time'] = timeMatch.group(1)?.trim() ?? 'N/A';
        foundAny = true;
      }

      // Only return if we found at least some data
      return foundAny ? _validateAndNormalizeReceiptData(result) : null;
    } catch (e) {
      print('⚠️ Error parsing numbered list: $e');
      return null;
    }
  }

  /// Validate and normalize the receipt data structure
  /// Rejects template/placeholder responses
  Map<String, dynamic>? _validateAndNormalizeReceiptData(
    Map<String, dynamic> data,
  ) {
    final sender = data['sender']?.toString() ?? 'N/A';
    final recipient = data['recipient']?.toString() ?? 'N/A';
    final time = data['time']?.toString() ?? 'N/A';

    // Check for placeholder/template text that the model shouldn't return
    final placeholders = [
      'merchant_name_here',
      'customer_or_NA',
      'date_time_here',
      'actual_name',
      'actual_company',
      'actual_number',
      'actual_date',
    ];

    for (final placeholder in placeholders) {
      if (sender.toLowerCase().contains(placeholder.toLowerCase()) ||
          recipient.toLowerCase().contains(placeholder.toLowerCase()) ||
          time.toLowerCase().contains(placeholder.toLowerCase())) {
        print('⚠️ Rejected response with placeholder text: $placeholder');
        return null; // Reject this response
      }
    }

    // Validate that we have at least some real data
    final amount = _parseAmount(data['amount']);
    if (amount == 0.0 && sender == 'N/A' && time == 'N/A') {
      print('⚠️ Rejected response with no valid data');
      return null;
    }

    // Ensure all required fields exist
    final normalized = <String, dynamic>{
      'sender': sender,
      'recipient': recipient,
      'amount': amount,
      'time': time,
    };

    print('✓ Extracted data: $normalized');
    return normalized;
  }

  /// Parse amount field to double
  double _parseAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is num) return amount.toDouble();
    if (amount is String) {
      // Remove currency symbols, commas, and Thai text like "บาท"
      final cleaned = amount
          .replaceAll(
            RegExp(r'[^\d.]'),
            '',
          ) // Remove non-numeric except decimal
          .replaceAll('บาท', '') // Remove Thai "baht"
          .replaceAll(' ', '')
          .trim();
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  /// Enhanced extraction for Thai receipts (fallback when AI fails)
  /// Extracts data directly from OCR text using pattern matching
  /// For Thai receipts: sender = person (น.ส./นาย), recipient = company (บจก.)
  Map<String, dynamic> extractFromThaiReceipt(String text) {
    final result = <String, dynamic>{
      'sender': 'N/A',
      'recipient': 'N/A',
      'amount': 0.0,
      'time': 'N/A',
    };

    try {
      // Use parseReceiptText to extract amount reliably
      final parsedData = parseReceiptText(text);
      if (parsedData['total'] != null && parsedData['total'] > 0) {
        result['amount'] = parsedData['total'] as double;
        print('✓ Found amount from parseReceiptText: ${result['amount']}');
      } else {
        // Fallback: Try Thai-specific patterns
        final amountPatterns = [
          RegExp(
            r'จ[ำํ]านวน\s*:?\s*(\d+(?:[,\.]\d+)*)\s*บาท',
          ), // "จำนวน: 1277.00 บาท"
          RegExp(
            r'(\d+(?:[,\.]\d+)*)\s*บาท',
          ), // "1277.00 บาท" - any number before "บาท"
        ];

        for (final pattern in amountPatterns) {
          final match = pattern.firstMatch(text);
          if (match != null && match.groupCount >= 1) {
            final amountStr = match.group(1);
            if (amountStr != null && amountStr.isNotEmpty) {
              // Remove commas and parse
              final cleanAmount = amountStr.replaceAll(',', '');
              final amount = double.tryParse(cleanAmount);
              if (amount != null && amount > 0) {
                result['amount'] = amount;
                print('✓ Found amount from Thai pattern: $amount');
                break;
              }
            }
          }
        }
      }

      // Extract sender - person making payment (น.ส./นาย/นาง)
      final senderPatterns = [
        RegExp(r'(น\.ส\.\s*[ก-๙]+(?:\s+[ก-๙]+)?)'), // น.ส. วริษฐา ม
        RegExp(r'(นาย\s*[ก-๙]+(?:\s+[ก-๙]+)?)'), // นาย name
        RegExp(r'(นาง\s*[ก-๙]+(?:\s+[ก-๙]+)?)'), // นาง name
        RegExp(
          r'GrabPay\s*Wallet',
          caseSensitive: false,
        ), // Fallback for English
      ];

      for (final pattern in senderPatterns) {
        final match = pattern.firstMatch(text);
        if (match != null && match.groupCount >= 1) {
          final group1 = match.group(1);
          final group0 = match.group(0);
          if (group1 != null && group1.isNotEmpty) {
            result['sender'] = group1.trim();
            break;
          } else if (group0 != null && group0.isNotEmpty) {
            result['sender'] = group0.trim();
            break;
          }
        }
      }

      // Extract recipient - company receiving payment (บจก./บริษัท)
      final recipientPatterns = [
        RegExp(r'(บจก\.\s*[ก-๙\s\(\)]+)'), // บจก. ช็อปปี้เพย์ (ประเทศไทย)
        RegExp(r'(บริษัท\s*[ก-๙\s\(\)]+)'), // บริษัท name
        RegExp(r'(ธ\.กสิกรไทย)'), // Bank name
        RegExp(r'(ธนาคาร[ก-๙\s]+)'), // ธนาคาร name
      ];

      for (final pattern in recipientPatterns) {
        final match = pattern.firstMatch(text);
        if (match != null && match.groupCount >= 1) {
          final group1 = match.group(1);
          final group0 = match.group(0);
          final extracted = group1 ?? group0;
          if (extracted != null && extracted.isNotEmpty) {
            result['recipient'] = extracted.trim().replaceAll(
              RegExp(r'\s+'),
              ' ',
            );
            break;
          }
        }
      }

      // Extract time - Thai date format like "10 ต.ค. 68 09:01น."
      final timePatterns = [
        RegExp(
          r'(\d{1,2}\s*ต\.?[ก-๙]+\.?\s*\d{2,4}\s*\d{1,2}:\d{2}น?\.)',
        ), // 10 ต.ค. 68 09:01น.
        RegExp(
          r'(\d{1,2}\s*[ก-๙]+\s*\d{2,4}\s*\d{1,2}:\d{2}\s*น\.)',
        ), // Thai format
        RegExp(r'(\d{1,2}/\d{1,2}/\d{2,4}\s*\d{1,2}:\d{2})'), // Date/time
        RegExp(r'(\d{4}-\d{2}-\d{2}\s*\d{2}:\d{2})'), // ISO format
      ];

      for (final pattern in timePatterns) {
        final match = pattern.firstMatch(text);
        if (match != null && match.groupCount >= 1) {
          final timeStr = match.group(1);
          if (timeStr != null && timeStr.isNotEmpty) {
            result['time'] = timeStr.trim();
            break;
          }
        }
      }

      print('✓ Enhanced extraction result: $result');
    } catch (e, stackTrace) {
      print('⚠️ Error in enhanced extraction: $e');
      print('Stack trace: $stackTrace');
    }

    return result;
  }
}
