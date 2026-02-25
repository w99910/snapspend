import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:photo_manager/photo_manager.dart';
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
      // Request Photos permission via photo_manager (supports iOS limited + Android 13+).
      final PermissionState ps = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.image,
            mediaLocation: false,
          ),
        ),
      );

      if (!mounted) return;

      if (ps.isAuth || ps.hasAccess) {
        // Permission granted (full or limited): let user pick an album to scan.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AlbumPickerPage()),
        );
        return;
      }

      // photo_manager doesn't expose "permanently denied" uniformly across
      // platforms; if we don't have access, guide the user to Settings.
      _showOpenSettingsDialog();
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

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Gallery access is required to scan receipt photos from an album. '
          'Please enable Photos access in Settings to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              PhotoManager.openSetting();
            },
            child: const Text('Open Settings'),
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

class AlbumPickerPage extends StatefulWidget {
  const AlbumPickerPage({super.key});

  @override
  State<AlbumPickerPage> createState() => _AlbumPickerPageState();
}

class _AlbumPickerPageState extends State<AlbumPickerPage> {
  late Future<List<AssetPathEntity>> _albumsFuture;

  @override
  void initState() {
    super.initState();
    _albumsFuture = _loadAlbums();
  }

  Future<List<AssetPathEntity>> _loadAlbums() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
    );

    // Put likely receipt albums first (if user creates one).
    albums.sort((a, b) {
      final an = a.name.toLowerCase();
      final bn = b.name.toLowerCase();
      int score(String n) {
        if (n.contains('snapspend')) return 0;
        if (n.contains('receipt')) return 1;
        if (n.contains('camera')) return 2;
        if (n.contains('dcim')) return 3;
        if (n.contains('recent') || n.contains('all')) return 4;
        return 10;
      }

      final s = score(an).compareTo(score(bn));
      if (s != 0) return s;
      return an.compareTo(bn);
    });

    return albums;
  }

  void _selectAlbum(AssetPathEntity album) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ScanReceiptsPage(
          selectedAlbum: album,
          selectedAlbumName: album.name,
        ),
      ),
    );
  }

  Future<void> _promptCreateAlbum() async {
    if (!(Platform.isIOS || Platform.isMacOS)) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E3A5F),
          title: const Text(
            'Create album',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Creating a new Photos album from within the app is only supported on iOS.\n\n'
            'On Android, please create an album/folder in your gallery app, then come back and select it here.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final controller = TextEditingController(text: 'SnapSpend Receipts');
    final name = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text(
          'Create album',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Album name',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF4A90E2)),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;

    try {
      final created = await PhotoManager.editor.darwin.createAlbum(trimmed);
      if (!mounted) return;

      if (created == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create album.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Refresh list and immediately use it.
      setState(() {
        _albumsFuture = _loadAlbums();
      });

      _selectAlbum(created);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create album: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A2F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1A2F),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Choose an album'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<AssetPathEntity>>(
          future: _albumsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load albums:\n${snapshot.error}',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final albums = snapshot.data ?? const <AssetPathEntity>[];
            if (albums.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No albums found.\n\nTip: Create a Photos album (e.g. "SnapSpend Receipts") and add receipt images to it.',
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A4A6F)),
                  ),
                  child: const Text(
                    'Tip: Create an album like "SnapSpend Receipts" and save your receipt photos there. SnapSpend will only scan images inside the album you pick.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ),
                const SizedBox(height: 12),
                ...albums.map((album) {
                  return FutureBuilder<int>(
                    future: album.assetCountAsync,
                    builder: (context, countSnap) {
                      final count = countSnap.data;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F).withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2A4A6F)),
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.photo_album_outlined,
                            color: Color(0xFF4A90E2),
                          ),
                          title: Text(
                            album.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            count == null ? 'Loading…' : '$count photos',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.white54,
                          ),
                          onTap: () => _selectAlbum(album),
                        ),
                      );
                    },
                  );
                }),
                const SizedBox(height: 4),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A4A6F)),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.add_circle_outline,
                      color: Color(0xFF4A90E2),
                    ),
                    title: const Text(
                      'Create a new album…',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      (Platform.isIOS || Platform.isMacOS)
                          ? 'Create an album in Photos and scan only it'
                          : 'Android: create it in your gallery app',
                      style: TextStyle(color: Colors.white.withOpacity(0.65)),
                    ),
                    onTap: _promptCreateAlbum,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
