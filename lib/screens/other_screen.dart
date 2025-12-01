import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:picdb/widgets/bottom_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../services/theme_notifier.dart';
import 'package:picdb/screens/testimonial_screen.dart';

class OtherScreen extends StatefulWidget {
  const OtherScreen({super.key});

  @override
  State<OtherScreen> createState() => _OtherScreenState();
}

class _OtherScreenState extends State<OtherScreen> {
  String _userName = 'User'; // Placeholder

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _loadUserName() async {
    // Placeholder for loading user name
    // In a real app, you would fetch this from your auth service or user profile storage.
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('username') ?? 'Arkynox'; // Example name
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDarkMode = themeNotifier.themeMode == ThemeMode.dark ||
        (themeNotifier.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: isDarkMode ? const Color(0xFF0D1A26) : const Color(0xFFFCF9F5),
      bottomNavigationBar: const BottomNavBar(selectedIndex: 3),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDarkMode),
            Expanded(
              child: _buildSettingsList(isDarkMode, themeNotifier),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A2B3D) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.05),
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
                    'Signed in as'.toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF666666),
                      letterSpacing: 0.5,
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.2, end: 0),
                  const SizedBox(height: 4),
                  Text(
                    _userName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : const Color(0xFF0D1F2D),
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.2, end: 0),
                ],
              ),
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
                  Icons.settings_outlined,
                  color: isDarkMode ? Colors.teal.shade200 : const Color(0xFF0D1F2D),
                  size: 24,
                ),
              ).animate().scale(duration: 500.ms).fadeIn(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList(bool isDarkMode, ThemeNotifier themeNotifier) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Appearance', isDarkMode),
        _buildCard(
          isDarkMode: isDarkMode,
          child: Column(
            children: [
              _buildThemeOption(
                title: 'System Default',
                value: ThemeMode.system,
                isDarkMode: isDarkMode,
                themeNotifier: themeNotifier,
              ),
              _buildThemeOption(
                title: 'Light',
                value: ThemeMode.light,
                isDarkMode: isDarkMode,
                themeNotifier: themeNotifier,
              ),
              _buildThemeOption(
                title: 'Dark',
                value: ThemeMode.dark,
                isLast: true,
                isDarkMode: isDarkMode,
                themeNotifier: themeNotifier,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Support', isDarkMode),
        _buildCard(
          isDarkMode: isDarkMode,
          child: Column(
            children: [
              _buildListTile(
                icon: Icons.support_agent_outlined,
                iconColor: const Color(0xFF2196F3),
                title: 'Contact Support',
                onTap: () => _launchUrl('https://desk.arkynox.com/'),
                isDarkMode: isDarkMode,
              ),
              Divider(height: 1, indent: 16, endIndent: 16, color: isDarkMode ? Colors.grey.shade800 : const Color(0xFFEEEEEE)),
              _buildListTile(
                icon: Icons.reviews_outlined,
                iconColor: const Color(0xFF8E24AA),
                title: 'Share Testimonial',
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const TestimonialScreen()));
                },
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Legal', isDarkMode),
        _buildCard(
          isDarkMode: isDarkMode,
          child: Column(
            children: [
              _buildListTile(
                icon: Icons.privacy_tip_outlined,
                iconColor: const Color(0xFF4CAF50),
                title: 'Privacy Policy',
                onTap: () => _launchUrl('https://picdb.arkynox.com/policy/mobile/privacy'),
                isDarkMode: isDarkMode,
              ),
              Divider(height: 1, indent: 16, endIndent: 16, color: isDarkMode ? Colors.grey.shade800 : const Color(0xFFEEEEEE)),
              _buildListTile(
                icon: Icons.gavel_outlined,
                iconColor: const Color(0xFFF44336),
                title: 'Terms of Service',
                onTap: () => _launchUrl('https://picdb.arkynox.com/policy/mobile/terms-of-service'),
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ),
      ].animate(interval: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child, required bool isDarkMode}) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A2B3D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildThemeOption({
    required String title,
    required ThemeMode value,
    bool isLast = false,
    required bool isDarkMode,
    required ThemeNotifier themeNotifier,
  }) {
    return RadioListTile<ThemeMode>(
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: isDarkMode ? Colors.white : Colors.black)),
      value: value,
      groupValue: themeNotifier.themeMode,
      onChanged: (newValue) {
        if (newValue != null) {
          themeNotifier.toggleTheme(newValue);
        }
      },
      activeColor: const Color(0xFF2196F3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: isLast ? null : Border(bottom: BorderSide(color: isDarkMode ? Colors.grey.shade800 : const Color(0xFFEEEEEE))),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: isDarkMode ? Colors.white : Colors.black)),
      trailing: Icon(Icons.chevron_right_rounded, color: isDarkMode ? Colors.grey.shade600 : Colors.grey),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
