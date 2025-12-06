import 'package:flutter/material.dart';
import '../services/llama_service.dart';
import 'gallery_access_page.dart';

class DownloadModelPage extends StatefulWidget {
  const DownloadModelPage({super.key});

  @override
  State<DownloadModelPage> createState() => _DownloadModelPageState();
}

class _DownloadModelPageState extends State<DownloadModelPage> {
  final LlamaService _llamaService = LlamaService();

  bool _isDownloading = false;
  bool _isModelReady = false;
  double _downloadProgress = 0.0;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _checkModelExists();
  }

  Future<void> _checkModelExists() async {
    final exists = await _llamaService.checkModelExists();
    if (mounted) {
      setState(() {
        _isModelReady = exists;
        if (exists) {
          _statusMessage = 'Model already downloaded!';
        }
      });
    }
  }

  Future<void> _downloadModel() async {
    if (_isModelReady) {
      // Navigate to next page (llama demo page for now)
      _navigateToNextPage();
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      await _llamaService.downloadModel(
        onProgress: (progress, message) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
              _statusMessage = message;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isModelReady = true;
        });

        // Auto-navigate after successful download
        await Future.delayed(const Duration(milliseconds: 500));
        _navigateToNextPage();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: $e';
          _isDownloading = false;
        });

        // Show error dialog
        _showErrorDialog(e.toString());
      }
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Failed'),
        content: Text('Failed to download model:\n$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadModel();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _navigateToNextPage() {
    // Navigate to the gallery access page
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const GalleryAccessPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A2F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            children: [
              // Page indicators
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Previous pages (completed)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A4A6F),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // Current page (active)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 24,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A90E2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // Future pages
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A4A6F),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A4A6F),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Download icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A90E2).withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: _isDownloading
                          ? Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(
                                value: _downloadProgress,
                                strokeWidth: 3,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF4A90E2),
                                ),
                              ),
                            )
                          : Icon(
                              _isModelReady
                                  ? Icons.check_circle
                                  : Icons.download,
                              size: 60,
                              color: const Color(0xFF4A90E2),
                            ),
                    ),
                    const SizedBox(height: 40),

                    // Title
                    Text(
                      _isModelReady ? 'Model Ready!' : 'Download AI Models',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Description
                    Text(
                      _isModelReady
                          ? 'AI model is ready for offline processing'
                          : 'We need to download the OCR models for offline processing',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.7),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // Status message
                    if (_statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    // Download progress
                    if (_isDownloading) ...[
                      const SizedBox(height: 20),
                      Text(
                        '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Download button
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isDownloading ? null : _downloadModel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: const Color(0xFF2A4A6F),
                    ),
                    child: _isDownloading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            _isModelReady ? 'Continue' : 'Download Models',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
