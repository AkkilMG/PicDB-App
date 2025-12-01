import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/theme_notifier.dart';

class UploadPopup extends StatefulWidget {
  final String imageUrl;
  final String imageName;
  final String viewUrl;

  const UploadPopup({
    Key? key,
    required this.imageUrl,
    required this.imageName,
    required this.viewUrl,
  }) : super(key: key);

  @override
  _UploadPopupState createState() => _UploadPopupState();
}

class _UploadPopupState extends State<UploadPopup> {
  // By default, show the download content
  bool _showDownloadContent = true;
  final GlobalKey _downloadKey = GlobalKey();
  final GlobalKey _viewKey = GlobalKey();
  bool _showcaseStarted = false;
  final GlobalKey<ShowCaseWidgetState> _popupShowCaseKey = GlobalKey<ShowCaseWidgetState>();
  SharedPreferences? _prefs;
  bool _shouldStartPopupTutorial = false;

  // Build custom tooltip with Skip button
  Widget _buildPopupShowcaseContent({required String title, required String description}) {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final isDarkMode = themeNotifier.themeMode == ThemeMode.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1C2A3A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.25) : Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
          const SizedBox(height: 6),
          Text(description, style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _skipPopupTutorial,
              child: const Text('Skip tutorial'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _skipPopupTutorial() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setBool('upload_pop_tutorial', true);
    _popupShowCaseKey.currentState?.dismiss();
    if (mounted) {
      setState(() {
        _shouldStartPopupTutorial = false;
        _showcaseStarted = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Removed startShowCase here because context is not under ShowCaseWidget yet.
    // Load shared preferences to decide whether to show popup tutorial
    SharedPreferences.getInstance().then((p) {
      _prefs = p;
      // p.setBool('upload_pop_tutorial', false);
      final seen = p.getBool('upload_pop_tutorial') ?? false;
      if (!seen && mounted) {
        setState(() {
          _shouldStartPopupTutorial = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDarkMode = themeNotifier.themeMode == ThemeMode.dark;

    final backgroundColor = isDarkMode ? Colors.grey[850] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final buttonPrimaryColor = isDarkMode ? Colors.blue[700] : Colors.blue;
    final buttonSecondaryColor =
        isDarkMode ? Colors.blue[900] : Colors.blue.shade200;
    final containerBorderColor =
        isDarkMode ? Colors.grey[700] : Colors.grey.shade400;
    final iconContainerColor =
        isDarkMode ? Colors.grey[700] : Colors.grey.shade300;
    final iconColor = isDarkMode ? Colors.white : Colors.black;
    final linkColor = isDarkMode ? Colors.lightBlueAccent : Colors.blue.shade800;

    return ShowCaseWidget(
      key: _popupShowCaseKey,
      onFinish: () async {
        // Mark popup tutorial as seen
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        await prefs.setBool('upload_pop_tutorial', true);
      },
      builder: (showcaseContext) {
        if (!_showcaseStarted && _shouldStartPopupTutorial) {
          _showcaseStarted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ShowCaseWidget.of(showcaseContext).startShowCase([
              _downloadKey,
              _viewKey,
            ]);
          });
        }
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: backgroundColor,
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title and Close Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title (Image Name and Type)
                    Row(
                      children: [
                        // Text(
                        //   widget.imageName.length > 13 ? '${widget.imageName.substring(0, 10)}...' : widget.imageName,
                        //   style: const TextStyle(
                        //     fontSize: 18,
                        //     fontWeight: FontWeight.bold,
                        //   ),
                        // ),
                        // const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade400,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "PNG",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 15),
                    // Close Button
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: Icon(Icons.close, color: textColor),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Text(
                  // "Name: ${widget.imageName}",
                  "Name: ${widget.imageName.length > 18 ? '${widget.imageName.substring(0, 20)}...' : widget.imageName}",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),

                const SizedBox(height: 10),

                // Buttons (Download and View)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Showcase.withWidget(
                        key: _downloadKey,
                        targetShapeBorder: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        container: _buildPopupShowcaseContent(
                          title: 'Download Image',
                          description: 'Get a direct link and QR to save the image to your device.',
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _showDownloadContent = true;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonPrimaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: const Text('Download'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Showcase.withWidget(
                        key: _viewKey,
                        targetShapeBorder: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        container: _buildPopupShowcaseContent(
                          title: 'Preview & View Link',
                          description: 'See a preview and get a sharable view link.',
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _showDownloadContent = false;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonSecondaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: const Text('View'),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Conditional Content (Download or View)
                _showDownloadContent
                    ? _buildDownloadContent(context,
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor ?? Colors.grey,
                        containerBorderColor: containerBorderColor ?? Colors.grey,
                        iconContainerColor: iconContainerColor ?? Colors.grey,
                        iconColor: iconColor,
                        linkColor: linkColor,
                        isDarkMode: isDarkMode)
                    : _buildViewContent(context,
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor ?? Colors.grey,
                        containerBorderColor: containerBorderColor ?? Colors.grey,
                        iconContainerColor: iconContainerColor ?? Colors.grey,
                        iconColor: iconColor,
                        linkColor: linkColor),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDownloadContent(
    BuildContext context, {
    required Color textColor,
    required Color secondaryTextColor,
    required Color containerBorderColor,
    required Color iconContainerColor,
    required Color iconColor,
    required Color linkColor,
    required bool isDarkMode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Image Download:",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "This provides you a link to download the image.",
          style: TextStyle(color: secondaryTextColor),
        ),
        const SizedBox(height: 16),
        Text("Download link", style: TextStyle(color: textColor)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: containerBorderColor),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.imageUrl,
                  style: TextStyle(color: linkColor),
                  overflow: TextOverflow.ellipsis, // Hide overflow with ellipsis
                  maxLines: 1, // Allow only one line
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.imageUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: iconContainerColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(Icons.copy, size: 20, color: iconColor),
                ),
              ),
              const SizedBox(width: 5),
              GestureDetector(
                onTap: () async {
                  if (!await launchUrl(Uri.parse(widget.imageUrl))) {
                    throw 'Could not launch ${widget.imageUrl}';
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: iconContainerColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(Icons.open_in_new, size: 20, color: iconColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: QrImageView(
            data: widget.imageUrl,
            version: QrVersions.auto,
            size: 200.0,
            backgroundColor: isDarkMode ? Colors.white : Colors.transparent,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            "Scan this code to download the image.",
            style: TextStyle(color: secondaryTextColor),
          ),
        ),
      ],
    );
  }

  Widget _buildViewContent(
    BuildContext context, {
    required Color textColor,
    required Color secondaryTextColor,
    required Color containerBorderColor,
    required Color iconContainerColor,
    required Color iconColor,
    required Color linkColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Image View:",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "This provides you a link to view the image.",
          style: TextStyle(color: secondaryTextColor),
        ),
        const SizedBox(height: 20),
        Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.6,
            height: MediaQuery.of(context).size.width * 0.6,
            child: Image.network(
              widget.viewUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Text(
                    "Image failed to load",
                    style: TextStyle(color: secondaryTextColor),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text("View link", style: TextStyle(color: textColor)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: containerBorderColor),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.viewUrl,
                  style: TextStyle(color: linkColor),
                  overflow: TextOverflow.ellipsis, // Hide the overflow
                  maxLines: 1, // Only allow one line
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.viewUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: iconContainerColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(Icons.copy, size: 20, color: iconColor),
                ),
              ),
              const SizedBox(width: 5),
              GestureDetector(
                onTap: () async {
                  if (!await launchUrl(Uri.parse(widget.viewUrl))) {
                    throw 'Could not launch ${widget.viewUrl}';
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: iconContainerColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(Icons.open_in_new, size: 20, color: iconColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
