import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/theme_notifier.dart';

class TestimonialScreen extends StatefulWidget {
  const TestimonialScreen({Key? key}) : super(key: key);

  @override
  State<TestimonialScreen> createState() => _TestimonialScreenState();
}

class _TestimonialScreenState extends State<TestimonialScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _quoteController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _logoController = TextEditingController();

  int _rating = 5;
  String _selectedColor = 'blue';
  bool _isSubmitting = false;

  final Map<String, Color> _palette = {
    'blue': Colors.blueAccent,
    'red': Colors.redAccent,
    'green': Colors.green,
    'yellow': Colors.amber,
    'purple': Colors.purpleAccent,
    'pink': Colors.pinkAccent,
    'indigo': Colors.indigo,
    'teal': Colors.teal,
  };

  @override
  void dispose() {
    _quoteController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _locationController.dispose();
    _companyController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      // Call APIService.saveTestimonial
      final resp = await APIService.saveTestimonial(
        logo: _logoController.text.trim(),
        logoColor: 'text-$_selectedColor-600',
        rating: _rating.toString(),
        quote: _quoteController.text.trim(),
        name: _nameController.text.trim(),
        location: _locationController.text.trim(),
        company: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
      );

      if (resp['success'] == true) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Thank you!'),
            content: const Text('Your testimonial has been submitted. We appreciate your feedback.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
            ],
          ),
        );

        _formKey.currentState!.reset();
        _quoteController.clear();
        _nameController.clear();
        _usernameController.clear();
        _locationController.clear();
        _companyController.clear();
        _logoController.clear();
        setState(() {
          _rating = 5;
          _selectedColor = 'blue';
        });
      } else {
        final msg = resp['message'] ?? 'Failed to submit testimonial';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit testimonial: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildStar(int index) {
    final filled = index <= _rating;
    return GestureDetector(
      onTap: () => setState(() => _rating = index),
      child: Icon(
        Icons.star_rounded,
        size: 36,
        color: filled ? Colors.amber : Colors.grey.shade400,
      ),
    );
  }

  Widget _buildColorTile(String key) {
    final color = _palette[key]!;
    final selected = key == _selectedColor;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: Colors.black, width: 2) : null,
          boxShadow: selected
              ? [BoxShadow(color: Color.fromRGBO(color.red, color.green, color.blue, 0.4), blurRadius: 12, offset: const Offset(0, 6))]
              : [BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.06), blurRadius: 6, offset: const Offset(0, 4))],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = themeNotifier.themeMode == ThemeMode.dark ||
        (themeNotifier.themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Testimonial'),
        backgroundColor: isDark ? const Color(0xFF0D1A26) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0D1F2D),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero header
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? LinearGradient(colors: [const Color(0xFF071526), const Color(0xFF102433)])
                      : LinearGradient(colors: [Colors.blue.shade50, Colors.purple.shade50]),
                  borderRadius: BorderRadius.circular(16),
                  color: isDark ? const Color(0xFF071526) : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your Voice Matters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Share a short story about your experience. It helps us grow.', style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) => _buildStar(i + 1)).animate(interval: 40.ms).fadeIn(),
                    ),
                    const SizedBox(height: 8),
                    Center(child: Text(_rating == 5 ? 'Outstanding' : _rating >= 4 ? 'Great' : _rating >= 3 ? 'Good' : _rating >= 2 ? 'Okay' : 'Needs improvement', style: TextStyle(color: isDark ? Colors.white70 : null))),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Quote
                    TextFormField(
                      controller: _quoteController,
                      maxLength: 150,
                      minLines: 4,
                      maxLines: 6,
                      decoration: InputDecoration(
                        labelText: 'Share your story',
                        hintText: 'Tell us about your experience... (max 150 chars)',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0D1A26) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Feedback is required' : null,
                    ),

                    const SizedBox(height: 12),

                    // Grid fields
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width > 600 ? (MediaQuery.of(context).size.width - 64) / 2 : double.infinity,
                          child: TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(labelText: 'Your Name', filled: true, fillColor: isDark ? const Color(0xFF0D1A26) : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                          ),
                        ),

                        SizedBox(
                          width: MediaQuery.of(context).size.width > 600 ? (MediaQuery.of(context).size.width - 64) / 2 : double.infinity,
                          child: TextFormField(
                            controller: _locationController,
                            decoration: InputDecoration(labelText: 'Location', filled: true, fillColor: isDark ? const Color(0xFF0D1A26) : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Location is required' : null,
                          ),
                        ),

                        SizedBox(
                          width: MediaQuery.of(context).size.width > 600 ? (MediaQuery.of(context).size.width - 64) / 2 : double.infinity,
                          child: TextFormField(
                            controller: _companyController,
                            decoration: InputDecoration(labelText: 'Company (optional)', filled: true, fillColor: isDark ? const Color(0xFF0D1A26) : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Logo and color
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _logoController,
                            decoration: InputDecoration(labelText: 'Company Logo Name (optional)', filled: true, fillColor: isDark ? const Color(0xFF0D1A26) : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 220,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Logo Color', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _palette.keys.map((k) => _buildColorTile(k)).toList(),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Preview
                    Text('Preview', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0B1620) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black.withOpacity(0.6) : Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: isDark ? _palette[_selectedColor]!.darken(0.05) : _palette[_selectedColor]!.withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  (_logoController.text.isEmpty ? (_companyController.text.isEmpty ? (_nameController.text.isNotEmpty ? _nameController.text[0] : 'A') : _companyController.text[0]) : _logoController.text[0]).toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_nameController.text.isEmpty ? 'Anonymous' : _nameController.text, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text(_companyController.text.isEmpty ? (_usernameController.text.isEmpty ? '' : '@' + _usernameController.text) : _companyController.text, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              Row(
                                children: List.generate(5, (i) => Icon(Icons.star, size: 16, color: i < _rating ? Colors.amber : Colors.grey.shade300)),
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _quoteController.text.isEmpty ? 'Your testimonial preview will show here.' : _quoteController.text,
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade800),
                          ),
                          const SizedBox(height: 8),
                          Text(_locationController.text.isEmpty ? '' : _locationController.text, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: isDark ? cs.primary : null,
                        foregroundColor: isDark ? cs.onPrimary : null,
                      ),
                      child: _isSubmitting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Share My Experience'),
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
}

// Add color extension used for subtle color adjustments in dark mode
extension ColorExtension on Color {
  Color darken([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  Color lighten([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }
}
