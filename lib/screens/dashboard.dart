import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/theme_notifier.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/check_connection.dart';
import '../widgets/upload/UploadPopup.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardState();
}

class _DashboardState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late SharedPreferences prefs;
  List<dynamic> images = [];
  bool loadedImage = false;
  bool isLoading = true;
  late AnimationController _controller;
  final _searchController = TextEditingController();
  List<dynamic> filteredImages = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    initPrefs();
    Future.delayed(const Duration(milliseconds: 1500), () {
      initImages();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void initImages() async {
    var temp = prefs.getStringList("images") ?? [];
    images = [];

    for (String imageString in temp) {
      try {
        // Try to parse as JSON first
        var decodedImage = jsonDecode(imageString);
        // Add timestamp if it doesn't exist (for sorting)
        if (decodedImage['timestamp'] == null) {
          decodedImage['timestamp'] = DateTime.now().millisecondsSinceEpoch;
        }
        images.add(decodedImage);
      } catch (e) {
        // Skip malformed JSON entries and clean them up
        print('Error decoding image data: $e');
        print('Malformed data: $imageString');

        // Try to extract data from malformed string if it follows a pattern
        try {
          if (imageString.contains('link:') && imageString.contains('title:')) {
            // Parse malformed data that looks like: {link: url, title: name, ...}
            final linkMatch = RegExp(r'link:\s*([^,}]+)').firstMatch(imageString);
            final titleMatch = RegExp(r'title:\s*([^,}]+)').firstMatch(imageString);
            final viewMatch = RegExp(r'view:\s*([^,}]+)').firstMatch(imageString);
            final sizeMatch = RegExp(r'size:\s*([^,}]+)').firstMatch(imageString);

            if (linkMatch != null && titleMatch != null) {
              final recoveredImage = {
                'link': linkMatch.group(1)?.trim() ?? '',
                'title': titleMatch.group(1)?.trim() ?? '',
                'view': viewMatch?.group(1)?.trim() ?? '',
                'size': sizeMatch?.group(1)?.trim() ?? '0 KB',
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              };
              images.add(recoveredImage);
            }
          }
        } catch (parseError) {
          print('Could not recover malformed data: $parseError');
        }
      }
    }

    // Sort images by timestamp (oldest first)
    images.sort((a, b) {
      final aTime = a['timestamp'] ?? 0;
      final bTime = b['timestamp'] ?? 0;
      return aTime.compareTo(bTime);
    });

    filteredImages = List.from(images);

    // Clean up SharedPreferences by saving only valid data
    List<String> validEncodedImages = images.map((image) => jsonEncode(image)).toList();
    await prefs.setStringList("images", validEncodedImages);

    setState(() {
      loadedImage = true;
      isLoading = false;
    });
    _controller.forward();
  }

  void refreshImages() {
    setState(() {
      isLoading = true;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      initImages();
    });
  }

  void filterImages(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredImages = List.from(images);
      } else {
        filteredImages = images.where((image) {
          final title = image['title'].toString().toLowerCase();
          final type = title.split('.').last.toLowerCase();
          final searchLower = query.toLowerCase();
          return title.contains(searchLower) || type.contains(searchLower);
        }).toList();
      }
    });
  }

  void initPrefs() async {
    prefs = await SharedPreferences.getInstance();
  }

  void selectImage(String title, String link, String view) {
    showDialog(
      context: context,
      builder: (context) => UploadPopup(
        imageUrl: link,
        imageName: title,
        viewUrl: view,
      ),
    );
  }

  void deleteImage(String title) async {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final isDarkMode = themeNotifier.themeMode == ThemeMode.dark ||
        (themeNotifier.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1A2B3D) : Colors.white,
        title: Text(
          'Delete Confirmation',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        content: Text(
          'Are you sure you want to delete "$title"?',
          style: TextStyle(color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDarkMode ? Colors.blue.shade300 : const Color(0xFF0D1F2D)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      setState(() {
        images.removeWhere((image) => image['title'] == title);
        filteredImages = List.from(images);
      });

      List<String> encodedImages = images.map((image) => jsonEncode(image)).toList();
      await prefs.setStringList("images", encodedImages);
    }
  }

  String _greeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formatFileSize(String size) {
    try {
      final sizeNum = double.parse(size.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (sizeNum < 1024) return '${sizeNum.toStringAsFixed(1)} KB';
      if (sizeNum < 1024 * 1024) return '${(sizeNum / 1024).toStringAsFixed(1)} MB';
      return '${(sizeNum / (1024 * 1024)).toStringAsFixed(1)} GB';
    } catch (e) {
      return size;
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? color.withOpacity(0.2) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(isDarkMode ? 0.4 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isDarkMode ? color.withOpacity(0.9) : color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: isDarkMode ? color : color.withOpacity(0.9),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    return Hero(
      tag: 'searchBar',
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A2B3D) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: filterImages,
            style: TextStyle(
              color: isDarkMode ? Colors.white : const Color(0xFF0D1F2D),
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: 'Search by name or file type...',
              hintStyle: TextStyle(
                color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                fontSize: 16,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF0D1F2D),
                size: 24,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF0D1F2D),
                    ),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        filterImages('');
                      });
                    },
                  )
                : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              fillColor: isDarkMode ? const Color(0xFF1A2B3D) : const Color(0xFFFAFAFA),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCards(bool isDarkMode) {
    if (isLoading) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Images',
            images.length.toString(),
            Icons.image_rounded,
            isDarkMode ? Colors.green.shade300 : const Color(0xFF4CAF50),
            isDarkMode,
          ).animate()
            .fadeIn(duration: const Duration(milliseconds: 600))
            .slideX(begin: -0.2, end: 0),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Total Size',
            _formatFileSize(images.fold<double>(
              0,
              (sum, image) => sum + double.parse(
                image['size'].replaceAll(RegExp(r'[^0-9.]'), ''),
              ),
            ).toString()),
            Icons.storage_rounded,
            isDarkMode ? Colors.blue.shade300 : const Color(0xFF2196F3),
            isDarkMode,
          ).animate()
            .fadeIn(duration: const Duration(milliseconds: 600))
            .slideX(begin: 0.2, end: 0),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0D1A26) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF666666),
                    ),
                  ).animate()
                    .fadeIn(duration: const Duration(milliseconds: 500))
                    .slideX(begin: -0.2, end: 0),
                  const SizedBox(height: 4),
                  Text(
                    'My Gallery',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : const Color(0xFF0D1F2D),
                    ),
                  ).animate()
                    .fadeIn(duration: const Duration(milliseconds: 500))
                    .slideX(begin: -0.2, end: 0),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.blue.withOpacity(0.2) : const Color(0xFF2196F3).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode ? Colors.black.withOpacity(0.2) : const Color(0xFF0D1F2D).withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: GestureDetector(
                      onTap: refreshImages,
                      child: Icon(
                        Icons.refresh_rounded,
                        color: isDarkMode ? Colors.blue.shade300 : const Color(0xFF2196F3),
                        size: 24,
                      ),
                    ),
                  ).animate()
                    .scale(duration: const Duration(milliseconds: 500))
                    .fadeIn(),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.teal.withOpacity(0.2) : const Color(0xFFDFF2B8),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode ? Colors.black.withOpacity(0.2) : const Color(0xFF0D1F2D).withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: isDarkMode ? Colors.teal.shade200 : const Color(0xFF0D1F2D),
                      size: 24,
                    ),
                  ).animate()
                    .scale(duration: const Duration(milliseconds: 500))
                    .fadeIn(),
                ],
              ),
            ],
          ),
          if (!isLoading) ...[
            const SizedBox(height: 20),
            _buildStatCards(isDarkMode),
            const SizedBox(height: 16),
            _buildSearchBar(isDarkMode).animate()
              .fadeIn(duration: const Duration(milliseconds: 500))
              .slideY(begin: -0.2, end: 0),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDarkMode = themeNotifier.themeMode == ThemeMode.dark ||
        (themeNotifier.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return ConnectivityWidget(
      child: Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF0D1A26) : const Color(0xFFFCF9F5),
        bottomNavigationBar: const BottomNavBar(selectedIndex: 1,),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDarkMode),
              Expanded(
                child: Stack(
                  children: [
                    if (isLoading)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(
                              './assets/lottie/upload.json',
                              width: 200,
                              fit: BoxFit.fill,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading your gallery...',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDarkMode ? Colors.white70 : const Color(0xFF0D1F2D),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (filteredImages.isEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(
                              './assets/lottie/search.json',
                              width: 250,
                              fit: BoxFit.fill,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No images uploaded yet'
                                  : 'No images found for "${_searchController.text}"',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : const Color(0xFF0D1F2D),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_searchController.text.isNotEmpty) ...[
                              const SizedBox(height: 7),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    filterImages('');
                                  });
                                },
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Clear search'),
                                style: TextButton.styleFrom(
                                  foregroundColor: isDarkMode ? Colors.blue.shade300 : const Color(0xFF2196F3),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    else
                      AnimationLimiter(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredImages.length,
                          itemBuilder: (context, index) {
                            final image = filteredImages[index];
                            return AnimationConfiguration.staggeredList(
                              position: index,
                              duration: const Duration(milliseconds: 500),
                              child: SlideAnimation(
                                verticalOffset: 50.0,
                                child: FadeInAnimation(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildStorageCard(
                                      title: image['title'],
                                      size: image['size'],
                                      view: image['view'],
                                      link: image['link'],
                                      isDarkMode: isDarkMode,
                                    ),
                                  ),
                                ),
                              ),
                            );
                            },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorageCard({
    required String title,
    required String size,
    required String view,
    required String link,
    required bool isDarkMode,
  }) {
    final fileType = title.split('.').last.toUpperCase();
    final formattedSize = _formatFileSize(size);
    final uploadDate = DateTime.now().subtract(const Duration(days: 1));
    final formattedDate = DateFormat('MMM d, yyyy').format(uploadDate);

    return GestureDetector(
      onTap: () => selectImage(title, link, view),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDarkMode ? const Color(0xFF1A2B3D) : Colors.white,
          border: Border.all(color: isDarkMode ? Colors.grey.withOpacity(0.2) : const Color(0xFFEEEEEE)),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey.withOpacity(0.1) : const Color(0xFF0D1F2D).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          fileType[0],
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : const Color(0xFF0D1F2D),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDarkMode ? Colors.teal.withOpacity(0.3) : const Color(0xFFF2D1A9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  fileType,
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.teal.shade200 : const Color(0xFF0D1F2D),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () => deleteImage(title),
                                splashRadius: 20,
                                tooltip: 'Delete image',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : const Color(0xFF0D1F2D),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.folder_outlined,
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formattedSize,
                                style: TextStyle(
                                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.calendar_today_outlined,
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDarkMode
                          ? [Colors.teal.shade300, Colors.blue.shade300]
                          : [const Color(0xFFF2D1A9), const Color(0xFFDFF2B8)],
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
