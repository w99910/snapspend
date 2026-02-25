import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'scanning_receipts_page.dart';

class ScanReceiptsPage extends StatefulWidget {
  final AssetPathEntity? selectedAlbum;
  final String? selectedAlbumName;

  const ScanReceiptsPage({
    super.key,
    this.selectedAlbum,
    this.selectedAlbumName,
  });

  @override
  State<ScanReceiptsPage> createState() => _ScanReceiptsPageState();
}

class _ScanReceiptsPageState extends State<ScanReceiptsPage> {
  void _getStarted() {
    // Navigate to automatic scanning page
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ScanningReceiptsPage(
          selectedAlbum: widget.selectedAlbum,
          selectedAlbumName: widget.selectedAlbumName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final albumLabel = (widget.selectedAlbumName?.trim().isNotEmpty ?? false)
        ? widget.selectedAlbumName!.trim()
        : null;

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
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A4A6F),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // Current page (active) - last one
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 24,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A90E2),
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
                    // Scan icon with dashed border
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
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Inner dashed border effect using CustomPaint would be ideal
                          // For simplicity, using icons
                          Icon(
                            Icons.crop_free,
                            size: 70,
                            color: const Color(0xFF4A90E2).withOpacity(0.3),
                          ),
                          const Icon(
                            Icons.document_scanner_outlined,
                            size: 50,
                            color: Color(0xFF4A90E2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Title
                    const Text(
                      'Scan Receipts',
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
                      albumLabel == null
                          ? "We'll scan up to 10 recent photos from your camera/DCIM or Recents"
                          : "We'll scan up to 10 recent photos from \"$albumLabel\"",
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

              // Get Started button
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _getStarted,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
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
