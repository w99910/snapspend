import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'scan_receipts_page.dart';

class GalleryAccessPage extends StatefulWidget {
  const GalleryAccessPage({super.key});

  @override
  State<GalleryAccessPage> createState() => _GalleryAccessPageState();
}

class _GalleryAccessPageState extends State<GalleryAccessPage> {
  bool _isCheckingPermission = false;

  Future<void> _requestGalleryAccess() async {
    setState(() {
      _isCheckingPermission = true;
    });

    try {
      // Request storage/photos permission
      PermissionStatus status;

      // For Android 13+ (API 33+), use photos permission
      // For older versions, use storage permission
      if (await Permission.photos.isRestricted ||
          await Permission.photos.isPermanentlyDenied) {
        status = await Permission.storage.request();
      } else {
        status = await Permission.photos.request();
      }

      if (status.isGranted) {
        // Permission granted, navigate to scan receipts page
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const ScanReceiptsPage()),
          );
        }
      } else if (status.isDenied) {
        // Permission denied
        if (mounted) {
          _showPermissionDeniedDialog();
        }
      } else if (status.isPermanentlyDenied) {
        // Permission permanently denied, open app settings
        if (mounted) {
          _showOpenSettingsDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingPermission = false;
        });
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Gallery access is needed to scan receipt photos automatically. '
          'Please grant permission to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _requestGalleryAccess();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Gallery access permission was permanently denied. '
          'Please enable it in app settings to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text('Failed to request permission:\n$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _skipForNow() {
    // Navigate to scan receipts page without permission
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const ScanReceiptsPage()),
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
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Gallery icon
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
                      child: const Icon(
                        Icons.folder_open,
                        size: 60,
                        color: Color(0xFF4A90E2),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Title
                    const Text(
                      'Gallery Access',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Description
                    Text(
                      'Allow access to your gallery to scan receipt photos automatically',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.7),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Buttons
              Column(
                children: [
                  // Grant Access button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isCheckingPermission
                          ? null
                          : _requestGalleryAccess,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: const Color(0xFF2A4A6F),
                      ),
                      child: _isCheckingPermission
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
                          : const Text(
                              'Grant Access',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Skip button
                  TextButton(
                    onPressed: _isCheckingPermission ? null : _skipForNow,
                    child: Text(
                      'Skip for now',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
