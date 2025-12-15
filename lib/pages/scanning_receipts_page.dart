import 'dart:developer';

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:photo_manager/photo_manager.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import '../services/ocr_service.dart';
import '../services/database_service.dart';
import '../models/receipt.dart';
import 'expenses_summary_page.dart';

class ScanningReceiptsPage extends StatefulWidget {
  const ScanningReceiptsPage({super.key});

  @override
  State<ScanningReceiptsPage> createState() => _ScanningReceiptsPageState();
}

class _ScanningReceiptsPageState extends State<ScanningReceiptsPage>
    with SingleTickerProviderStateMixin {
  int _currentScanning = 0;
  int _totalReceipts = 0;
  final List<ScannedReceipt> _scannedReceipts = [];
  bool _isComplete = false;
  String _statusMessage = 'Preparing to scan...';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final OcrService _ocrService = OcrService();
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();

    // Setup pulse animation for scanning icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start scanning
    _startScanning();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<List<File>> _getReceiptImages() async {
    try {
      // Request permission - try multiple approaches
      print('🔐 Requesting photo access permission...');

      // First try: Request permission extend (for Android 13+)
      PermissionState ps = await PhotoManager.requestPermissionExtend();
      print('📋 Permission state: ${ps.toString()}');
      print('   isAuth: ${ps.isAuth}');
      print('   hasAccess: ${ps.hasAccess}');

      // If not authorized, try requesting again with limited access
      if (!ps.isAuth && !ps.hasAccess) {
        print(
          '⚠️ Permission not granted, trying requestPermissionExtend again...',
        );
        ps = await PhotoManager.requestPermissionExtend(
          requestOption: const PermissionRequestOption(
            androidPermission: AndroidPermission(
              type: RequestType.image,
              mediaLocation: false,
            ),
          ),
        );
        print('📋 Second attempt result: ${ps.toString()}');
      }

      // Check if we have at least some access
      if (!ps.isAuth && !ps.hasAccess) {
        print('❌ Permission denied - no access to photos');
        print('💡 Please go to Settings → Apps → SnapSpend → Permissions');
        print('💡 Enable "Photos and videos" or "Files and media"');
        return [];
      }

      if (ps.isAuth) {
        print('✅ Full permission granted, fetching albums...');
      } else if (ps.hasAccess) {
        print('✅ Limited access granted, fetching available albums...');
      }

      // Get all albums
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );

      print('📱 Found ${albums.length} total albums');

      // Print all albums for debugging
      for (var i = 0; i < albums.length; i++) {
        final count = await albums[i].assetCountAsync;
        print('  Album $i: "${albums[i].name}" - $count images');
      }

      List<File> receiptFiles = [];

      // Strategy 1: Try Camera/DCIM folders first (most common location)
      print('\n🔍 Strategy 1: Checking Camera/DCIM folders...');
      for (final album in albums) {
        final albumName = album.name.toLowerCase();
        if (albumName.contains('camera') ||
            albumName.contains('dcim') ||
            albumName == 'camera roll') {
          print('✓ Checking: "${album.name}"');
          final count = await album.assetCountAsync;
          print('  Contains $count images');

          if (count > 0) {
            final List<AssetEntity> assets = await album.getAssetListRange(
              start: 0,
              end: 4, // Limit to 4 receipts
            );
            print('  Retrieved ${assets.length} assets');

            for (final asset in assets) {
              final file = await asset.file;
              if (file != null) {
                print('  ✓ Adding: ${file.path}');
                receiptFiles.add(file);
              }
            }

            if (receiptFiles.isNotEmpty) {
              print('✅ Found ${receiptFiles.length} images in ${album.name}');
              return receiptFiles;
            }
          }
        }
      }

      // Strategy 2: Look for Receipts subfolder (if user organized them)
      print('\n🔍 Strategy 2: Looking for Receipts folder...');
      for (final album in albums) {
        final albumName = album.name.toLowerCase();

        if (albumName.contains('receipts') || albumName.contains('receipt')) {
          print('✓ Found Receipts album: "${album.name}"');
          final count = await album.assetCountAsync;
          print('  Contains $count images');

          if (count > 0) {
            final List<AssetEntity> assets = await album.getAssetListRange(
              start: 0,
              end: 4, // Limit to 4 receipts
            );
            print('  Retrieved ${assets.length} assets');

            for (final asset in assets) {
              final file = await asset.file;
              if (file != null) {
                print('  ✓ Adding: ${file.path}');
                receiptFiles.add(file);
              }
            }

            if (receiptFiles.isNotEmpty) {
              print('✅ Found ${receiptFiles.length} images in Receipts folder');
              return receiptFiles;
            }
          }
        }
      }

      // Strategy 3: Use "Recent" or first album with images
      print('\n🔍 Strategy 3: Using Recent or first available album...');
      if (albums.isNotEmpty) {
        // First try to find "Recent" album
        for (final album in albums) {
          final albumName = album.name.toLowerCase();
          if (albumName.contains('recent') || albumName.contains('all')) {
            final count = await album.assetCountAsync;
            if (count > 0) {
              print('✓ Using: "${album.name}" with $count images');
              final List<AssetEntity> assets = await album.getAssetListRange(
                start: 0,
                end: 4, // Limit to 4 receipts
              );

              for (final asset in assets) {
                final file = await asset.file;
                if (file != null) {
                  receiptFiles.add(file);
                }
              }

              if (receiptFiles.isNotEmpty) {
                print('✅ Found ${receiptFiles.length} images');
                return receiptFiles;
              }
            }
          }
        }

        // If no Recent album, use first album with images
        for (final album in albums) {
          final count = await album.assetCountAsync;
          if (count > 0) {
            print('✓ Using: "${album.name}" with $count images');
            final List<AssetEntity> assets = await album.getAssetListRange(
              start: 0,
              end: 4, // Limit to 4 receipts
            );

            for (final asset in assets) {
              final file = await asset.file;
              if (file != null) {
                receiptFiles.add(file);
              }
            }

            if (receiptFiles.isNotEmpty) {
              print('✅ Found ${receiptFiles.length} images');
              return receiptFiles;
            }
          }
        }
      }

      print('❌ No images found in any album');
      return receiptFiles;
    } catch (e) {
      print('❌ Error getting receipt images: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  Future<void> _startScanning() async {
    // Wait a bit before starting
    await Future.delayed(const Duration(milliseconds: 500));

    // Clear/truncate database before scanning
    setState(() {
      _statusMessage = 'Clearing previous data...';
    });

    try {
      final deletedCount = await _databaseService.deleteAllReceipts();
      print('✓ Deleted $deletedCount receipts from database');
    } catch (e) {
      print('⚠️ Error clearing database: $e');
    }

    // Check if Qwen3 model is available
    setState(() {
      _statusMessage = 'Checking AI model...';
    });

    final modelExists = await _ocrService.llamaService.checkModelExists();

    if (!modelExists) {
      if (!mounted) return;

      // Show dialog to download model
      final shouldDownload = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E3A5F),
          title: const Text(
            'AI Model Required',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'The Qwen3 AI model is needed to extract receipt data. '
            'Would you like to download it now? (~400MB)',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
              ),
              child: const Text('Download'),
            ),
          ],
        ),
      );

      if (shouldDownload != true) {
        if (mounted) {
          _navigateToMainApp();
        }
        return;
      }

      // Download the model
      if (mounted) {
        setState(() {
          _statusMessage = 'Downloading AI model...';
        });
      }

      try {
        await _ocrService.llamaService.downloadModel(
          onProgress: (progress, message) {
            if (mounted) {
              setState(() {
                _statusMessage = message;
              });
            }
          },
        );

        if (mounted) {
          setState(() {
            _statusMessage = 'Model downloaded! Starting scan...';
          });
        }
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('Error downloading model: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to download model: $e'),
              backgroundColor: Colors.red,
            ),
          );
          _navigateToMainApp();
        }
        return;
      }
    }

    // Get receipt images from gallery
    final receiptFiles = await _getReceiptImages();

    if (receiptFiles.isEmpty) {
      if (mounted) {
        setState(() {
          _statusMessage = 'No images found in gallery';
          _isComplete = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No images found. Please take some photos with your camera first, then try again.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        await Future.delayed(const Duration(seconds: 3));
        _navigateToMainApp();
      }
      return;
    }

    setState(() {
      _totalReceipts = receiptFiles.length;
      _statusMessage = 'Processing with AI-powered OCR';
    });

    // Scan each receipt
    for (int i = 0; i < receiptFiles.length; i++) {
      if (!mounted) return;

      final file = receiptFiles[i];
      final filename = path.basename(file.path);

      setState(() {
        _currentScanning = i + 1;
        _statusMessage = 'Scanning $filename...';
      });

      try {
        // Perform OCR on the receipt
        print('Scanning receipt $filename...');
        final text = await _ocrService.scanReceipt(file.path);

        if (!mounted) return;

        // Update status to show we're using AI
        setState(() {
          _statusMessage = 'Extracting data with Qwen3 AI...';
        });

        // Extract structured data using Llama/Qwen3
        Map<String, dynamic> extractedData;
        // try {
        extractedData = await _ocrService.extractReceiptDataWithLlama(
          receiptText: text,
          onStatusUpdate: (status) {
            print('Llama status: $status');
            if (mounted) {
              setState(() {
                _statusMessage = status;
              });
            }
          },
          onTextUpdate: (generatedText) {
            print('Llama generating: $generatedText');
          },
        );
        print('✓ Extracted data: $extractedData');
        // } catch (llamaError) {
        //   print(
        //     '⚠️ Llama extraction failed, falling back to enhanced parsing: $llamaError',
        //   );
        //   // Fallback to enhanced Thai receipt parsing if Llama fails
        //   extractedData = _ocrService.extractFromThaiReceipt(text);

        //   // If enhanced parsing also fails, use basic parser
        //   if (extractedData['amount'] == 0.0 &&
        //       extractedData['sender'] == 'N/A') {
        //     print('⚠️ Enhanced parsing failed, using basic parser');
        //     final parsedData = _ocrService.parseReceiptText(text);
        //     extractedData = {
        //       'sender': parsedData['merchant'] ?? 'N/A',
        //       'recipient': parsedData['recipient'] ?? 'N/A',
        //       'amount': parsedData['total'] ?? 0.0,
        //       'time': parsedData['date'] ?? 'N/A',
        //     };
        //   }
        // }

        if (!mounted) return;

        final scannedReceipt = ScannedReceipt(
          filename: filename,
          amount: extractedData['amount'] as double,
          rawText: text,
          sender: extractedData['sender'] as String,
          recipient: extractedData['recipient'] as String,
          time: extractedData['time'] as String,
        );

        setState(() {
          _scannedReceipts.add(scannedReceipt);
          _statusMessage = 'Processing with AI-powered OCR';
        });

        // Save to database
        try {
          final receipt = Receipt(
            imagePath: file.path,
            imageTaken: DateTime.now(),
            amount: extractedData['amount'] as double,
            recipient: extractedData['recipient'] as String,
            merchantName: extractedData['sender'] as String,
            category: null,
            rawOcrText: text,
            rawJsonData: json.encode(extractedData),
          );

          await _databaseService.insertReceipt(receipt);
          print('✓ Saved to database');
        } catch (dbError) {
          print('⚠️ Failed to save to database: $dbError');
        }

        print('✓ Scanned $filename:');
        print('  Sender: ${extractedData['sender']}');
        print('  Recipient: ${extractedData['recipient']}');
        print(
          '  Amount: \$${(extractedData['amount'] as double).toStringAsFixed(2)}',
        );
        print('  Time: ${extractedData['time']}');
      } catch (e) {
        print('Error scanning $filename: $e');
        // Still add it but with 0 amount to show it was attempted
        if (mounted) {
          setState(() {
            _scannedReceipts.add(
              ScannedReceipt(
                filename: filename,
                amount: 0.0,
                rawText: 'Error: $e',
                sender: 'Error',
                recipient: 'N/A',
                time: 'N/A',
              ),
            );
          });
        }
      }

      // Small pause to show the checkmark animation
      await Future.delayed(const Duration(milliseconds: 300));
    }

    inspect(_scannedReceipts);

    // All done
    if (mounted) {
      setState(() {
        _isComplete = true;
        _statusMessage = 'Scanning complete!';
      });

      // Wait a bit before navigating
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        _navigateToMainApp();
      }
    }
  }

  void _navigateToMainApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const ExpensesSummaryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalReceipts > 0
        ? _currentScanning / _totalReceipts
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1A2F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Scanning icon with pulse animation
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF4A90E2),
                      width: 3,
                    ),
                    color: const Color(0xFF1E3A5F),
                  ),
                  child: const Icon(
                    Icons.image_outlined,
                    size: 50,
                    color: Color(0xFF4A90E2),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Title
              const Text(
                'Scanning Receipts',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Progress counter
              Text(
                '$_currentScanning / $_totalReceipts',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 8,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFF1E3A5F),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF4A90E2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Scanned receipts list
              Expanded(
                child: _totalReceipts == 0
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              color: Color(0xFF4A90E2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Accessing gallery...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _scannedReceipts.isEmpty
                    ? Center(
                        child: Text(
                          'Preparing to scan...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _scannedReceipts.length,
                        itemBuilder: (context, index) {
                          return _ReceiptListItem(
                            receipt: _scannedReceipts[index],
                            index: index,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptListItem extends StatefulWidget {
  final ScannedReceipt receipt;
  final int index;

  const _ReceiptListItem({required this.receipt, required this.index});

  @override
  State<_ReceiptListItem> createState() => _ReceiptListItemState();
}

class _ReceiptListItemState extends State<_ReceiptListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F).withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A4A6F), width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkmark icon with animation
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 300),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4A90E2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),

              // Receipt details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recipient
                    if (widget.receipt.recipient != 'N/A') ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 14,
                            color: Color(0xFF4A90E2),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.receipt.recipient,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Time
                    if (widget.receipt.time != 'N/A') ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: Color(0xFF6B9BD1),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.receipt.time,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Filename (smaller, less prominent)
                    Text(
                      widget.receipt.filename,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Amount
              Text(
                '${widget.receipt.amount.toStringAsFixed(2)} THB',
                style: const TextStyle(
                  color: Color(0xFF4A90E2),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScannedReceipt {
  final String filename;
  final double amount;
  final String rawText;
  final String sender;
  final String recipient;
  final String time;

  ScannedReceipt({
    required this.filename,
    required this.amount,
    this.rawText = '',
    this.sender = 'N/A',
    this.recipient = 'N/A',
    this.time = 'N/A',
  });
}
