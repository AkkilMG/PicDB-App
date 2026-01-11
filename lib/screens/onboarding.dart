import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/theme_notifier.dart';
import '../widgets/onboarding_content.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool termsAccepted = false;
  bool privacyAccepted = false;
  late SharedPreferences prefs;

  // Username input handling
  final TextEditingController _usernameController = TextEditingController();
  bool _isUsernameValid = false;
  bool _isSubmitting = false;
  String? _usernameError;
  bool _hasUsername = false;

  final List<Map<String, String>> onboardingData = [
    {
      'title': 'Welcome to PicDB',
      'description': 'Your secure and efficient image management solution',
      'animation': 'assets/lottie/onboarding_welcome.json',
    },
    {
      'title': 'Easy Image Upload',
      'description': 'Upload and manage your images with just a few taps',
      'animation': 'assets/lottie/upload.json',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  void _initPrefs() async {
    prefs = await SharedPreferences.getInstance();

    // If onboarding already completed, skip directly to upload
    final bool onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    final bool acceptedPref = prefs.getBool('accepted') ?? false;

    if (onboardingCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/upload');
      });
      return;
    }

    // If policies were already accepted previously, mark onboarding completed and go to upload
    if (acceptedPref) {
      await prefs.setBool('onboarding_completed', true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/upload');
      });
      return;
    }

    // Check if username and uid already exist in SharedPreferences
    final String? username = prefs.getString('username');
    final String? uid = prefs.getString('uid');

    setState(() {
      _hasUsername = username != null && uid != null;
      if (_hasUsername) {
        _usernameController.text = username!;
      }
    });
  }

  Future<void> _launchURL(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
  }

  void _handleContinue() async {
    // Dismiss keyboard first
    FocusScope.of(context).unfocus();

    // If we're on the last page (policy page)
    if (_currentPage == onboardingData.length + 1) {
      if (termsAccepted && privacyAccepted) {
        await prefs.setBool("accepted", true);
        // mark onboarding completed when policies accepted
        await prefs.setBool('onboarding_completed', true);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/upload');
        }
      }
    }
    // If we're on the username page
    else if (_currentPage == onboardingData.length) {
      if (_hasUsername) {
        // Username already exists, proceed to policy page
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn,
        );
      } else {
        // Username doesn't exist yet, validate and submit
        if (_isUsernameValid) {
          final success = await _submitUsername();
          if (success) {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeIn,
            );
          }
        } else {
          // Validate the current input to show errors if needed
          setState(() {
            _validateUsername(_usernameController.text);
          });
        }
      }
    }
    // Otherwise, we're on a regular onboarding page
    else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
  }

  void _validateUsername(String value) {
    if (value.isEmpty) {
      _isUsernameValid = false;
      _usernameError = 'Username cannot be empty';
    } else if (value.length < 3) {
      _isUsernameValid = false;
      _usernameError = 'Username must be at least 3 characters';
    } else if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      _isUsernameValid = false;
      _usernameError = 'Only letters, numbers, and underscores allowed';
    } else {
      _isUsernameValid = true;
      _usernameError = null;
    }
  }

  Future<bool> _submitUsername() async {
    if (!_isUsernameValid) return false;

    setState(() {
      _isSubmitting = true;
    });

    final username = _usernameController.text.trim();
    final result = await APIService.setUsernameAPI(username);

    setState(() {
      _isSubmitting = false;
    });

    if (result['success'] == true && result['id'] != null) {
      // Store username and uid in SharedPreferences
      await prefs.setString('username', username);
      await prefs.setString('uid', result['id']);
      return true;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to set username'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return false;
  }

  Widget _buildUsernameInputPage() {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDarkMode = themeNotifier.themeMode == ThemeMode.dark ||
        (themeNotifier.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
      ),
    );

    final focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: isDarkMode ? const Color(0xFF4A90E2) : const Color(0xFF0D1F2D),
        width: 2,
      ),
    );

    final errorInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: Colors.red,
        width: 1.5,
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - 200, // Allow scrolling but ensure content fills screen
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Your Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Lottie.asset(
                  "assets/lottie/onboarding_found.json",
                  height: 180,  // Reduced height further to avoid overflow
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Choose a username to identify yourself:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _usernameController,
                enabled: !_hasUsername,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  labelText: 'Username',
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  hintText: 'Enter your desired username',
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                  errorText: _usernameError,
                  filled: true,
                  fillColor: isDarkMode ? const Color(0xFF1A2B3D) : Colors.white,
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: focusedInputBorder,
                  errorBorder: errorInputBorder,
                  focusedErrorBorder: errorInputBorder,
                  disabledBorder: inputBorder,
                ),
                onChanged: (value) {
                  setState(() {
                    _validateUsername(value);
                  });
                },
              ),
              const SizedBox(height: 30),
              if (_isSubmitting)
                const Center(child: CircularProgressIndicator())
              else
                Center(
                  child: ElevatedButton(
                    onPressed: (_hasUsername || _isUsernameValid) ? _handleContinue : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 15),
                      backgroundColor: isDarkMode ? const Color(0xFF4A90E2) : const Color(0xFF0D1F2D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Continue', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPolicyPage() {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDarkMode = themeNotifier.themeMode == ThemeMode.dark ||
        (themeNotifier.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Our Policies',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildPolicyItem(
              context: context,
              isDarkMode: isDarkMode,
              title: 'Terms of Service',
              value: termsAccepted,
              onChanged: (val) => setState(() => termsAccepted = val!),
              onTap: () => _launchURL('https://picdb.arkynox.com/policy/mobile/terms-of-service'),
            ),
            const SizedBox(height: 15),
            _buildPolicyItem(
              context: context,
              isDarkMode: isDarkMode,
              title: 'Privacy Policy',
              value: privacyAccepted,
              onChanged: (val) => setState(() => privacyAccepted = val!),
              onTap: () => _launchURL('https://picdb.arkynox.com/policy/mobile/privacy-policy'),
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: termsAccepted && privacyAccepted ? _handleContinue : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 15),
                  backgroundColor: isDarkMode ? const Color(0xFF4A90E2) : const Color(0xFF0D1F2D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Accept and Continue',
                    style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyItem({
    required BuildContext context,
    required bool isDarkMode,
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A2B3D) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF4A90E2),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Text.rich(
                TextSpan(
                  text: 'I agree to the ',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                  children: [
                    TextSpan(
                      text: title,
                      style: TextStyle(
                        color: isDarkMode ? const Color(0xFF4A90E2) : const Color(0xFF0D1F2D),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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

    final totalPages = onboardingData.length + 2; // Regular pages + username + policy

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0D1A26) : const Color(0xFFFCF9F5),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: totalPages,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, index) {
                  if (index < onboardingData.length) {
                    return OnboardingContent(
                      title: onboardingData[index]['title']!,
                      description: onboardingData[index]['description']!,
                      animation: onboardingData[index]['animation']!,
                    );
                  } else if (index == onboardingData.length) {
                    return _buildUsernameInputPage();
                  } else {
                    return _buildPolicyPage();
                  }
                },
              ),
            ),
            _buildBottomControls(isDarkMode, totalPages),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(bool isDarkMode, int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // "Skip" button - show on onboarding and username pages
          if (_currentPage <= onboardingData.length)
            TextButton(
              onPressed: () {
                _pageController.animateToPage(
                  totalPages - 1, // Skip to the last page (policy page)
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.ease,
                );
              },
              child: Text(
                'Skip',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            )
          else
            const SizedBox(width: 60), // Placeholder for alignment

          // Page indicator dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              totalPages,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? (isDarkMode ? const Color(0xFF4A90E2) : const Color(0xFF0D1F2D))
                      : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // "Continue" or "Next" button
          if (_currentPage < onboardingData.length)
            ElevatedButton(
              onPressed: _handleContinue,
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(15),
                backgroundColor: isDarkMode ? const Color(0xFF4A90E2) : const Color(0xFF0D1F2D),
              ),
              child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
            )
          else
            const SizedBox(width: 60), // Placeholder for alignment
        ],
      ),
    );
  }
}
