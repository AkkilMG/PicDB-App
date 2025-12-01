// lib/screens/group_list_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart' hide GroupItem;
import '../widgets/group-room/dialogs.dart';
import '../widgets/bottom_nav.dart';
import '../models/group_item.dart';
import 'group_chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../services/theme_notifier.dart';
import 'package:flutter/services.dart';

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> with TickerProviderStateMixin {
  // Will be loaded from SharedPreferences
  String uid = '';
  String username = '';
  bool loading = true;
  List<GroupItem> groups = [];
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  // Persistent controller for the inline username prompt
  final TextEditingController _usernameController = TextEditingController();
  // Focus node so we can explicitly request keyboard focus when prompt appears
  final FocusNode _usernameFocusNode = FocusNode();
  List<GroupItem> _filteredGroups = [];
  late AnimationController _refreshIconController;
  bool _isRefreshing = false;
  late SharedPreferences _prefs;
  // show inline username prompt when uid is missing (non-modal so bottom nav remains usable)
  bool _requireUsername = false;
  bool _isSubmittingUsername = false;

  // Only allow search and manual refresh when we have both uid and username
  bool get _canUseSearchAndRefresh => uid.isNotEmpty && username.isNotEmpty;

  // Keep the form key stable to prevent focus loss while typing
  final GlobalKey<FormState> _usernameFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _refreshIconController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _loadUserData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _usernameController.dispose();
    _usernameFocusNode.dispose();
    _refreshIconController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    _prefs = await SharedPreferences.getInstance();
    final storedUid = _prefs.getString('uid') ?? '';
    final storedName = _prefs.getString('username') ?? '';
    setState(() {
      uid = storedUid;
      username = storedName;
      // keep the prompt controller in sync with stored name
      _usernameController.text = storedName;
      // if no uid, show inline prompt (non-modal) so bottom nav remains usable
      _requireUsername = storedUid.isEmpty;
      // if we don't have both uid and username, ensure search isn't active
      if (!(storedUid.isNotEmpty && storedName.isNotEmpty)) {
        _isSearchActive = false;
      }
      loading = false; // allow UI to render prompt
    });

    // If the prompt should be shown, request focus so the keyboard opens
    if (_requireUsername && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).requestFocus(_usernameFocusNode);
      });
    }

    if (!_requireUsername) {
      // only load groups when we have a uid
      await _loadGroups();
    }
  }

  // Inline (non-modal) username prompt widget so bottom navigation remains usable.
  Widget _buildUsernamePrompt(ColorScheme cs, bool isDarkMode) {
    // Moved formKey to a state field to avoid rebuild focus issues
    // final formKey = GlobalKey<FormState>();
    final allowed = RegExp(r"^[A-Za-z0-9 _.'-]+");
    final trimmed = _usernameController.text.trim();
    final isValid = trimmed.length >= 3 && allowed.hasMatch(trimmed);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Card(
        elevation: isDarkMode ? 1 : 3,
        color: isDarkMode ? const Color(0xFF1A2B3D) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.primary.withOpacity(0.18)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _usernameFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set your user name',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Choose a name for group rooms.',
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey.shade400 : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameController,
                  focusNode: _usernameFocusNode,
                  autofocus: true,
                  // Ensure taps inside the field don't bubble to any global unfocus handlers
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  maxLength: 30,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z0-9 _.'-]")),
                    LengthLimitingTextInputFormatter(30),
                  ],
                  decoration: InputDecoration(
                    labelText: 'User name',
                    hintText: 'e.g. JaneDoe',
                    helperText: 'Letters, numbers',
                    counterText: '',
                    prefixIcon: const Icon(Icons.person_outline, color: Colors.blue),
                    filled: true,
                    fillColor: isDarkMode
                        ? Colors.blue.shade900.withOpacity(0.2)
                        : Colors.blue.shade50,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade600,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.error),
                    ),
                    suffixIcon: _usernameController.text.isNotEmpty
                        ? IconButton(
                      tooltip: 'Clear',
                      icon: Icon(Icons.clear_rounded, color: cs.onSurfaceVariant),
                      onPressed: () {
                        setState(() => _usernameController.clear());
                      },
                    )
                        : null,
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Name required';
                    if (t.length < 3) return 'Min 3 characters';
                    if (!allowed.hasMatch(t)) return 'Invalid characters';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) async {
                    if (isValid && !_isSubmittingUsername) {
                      FocusScope.of(context).unfocus();
                      await _handleSaveUsername(trimmed);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.icon(
                      onPressed: (!isValid || _isSubmittingUsername)
                          ? null
                          : () async {
                              if (_usernameFormKey.currentState?.validate() != true) return;
                              FocusScope.of(context).unfocus();
                              await _handleSaveUsername(_usernameController.text.trim());
                            },
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                          if (states.contains(MaterialState.disabled)) {
                            return isDarkMode ? Colors.blue.withOpacity(0.2) : const Color(0xFF2196F3).withOpacity(0.1); // disabled bg
                          }
                          return isDarkMode ? Colors.blue.withOpacity(0.2) : const Color(0xFF2195F1).withOpacity(0.1);
                        }),
                        foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                          if (states.contains(MaterialState.disabled)) {
                            return Colors.blue; // force white even when disabled
                          }
                          return Colors.blue; // normal state
                        }),
                        padding: MaterialStateProperty.all(
                          const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: (isDarkMode ? Colors.blue.shade300 : const Color(0xFF2196F3)).withOpacity(0.2),
                            ),
                          ),
                        ),
                      ),
                      icon: _isSubmittingUsername
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue,
                        ),
                      )
                          : Icon(Icons.check, color: Colors.blue[700]),
                      label: const Text('Save'),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

  }

  Future<void> _handleSaveUsername(String name) async {
    setState(() => _isSubmittingUsername = true);
    try {
      final res = await APIService.setUsernameAPI(name);
      if (res['success'] == true && res['id'] != null) {
        final id = res['id'].toString();
        await _prefs.setString('username', name);
        await _prefs.setString('uid', id);
        setState(() {
          uid = id;
          username = name;
          _requireUsername = false;
        });
        await _loadGroups();
        _showSuccessSnack('Welcome, $name');
      } else {
        _showErrorSnack(res['message'] ?? res['error'] ?? 'Failed to create user');
      }
    } catch (e) {
      _showErrorSnack('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmittingUsername = false);
    }
  }

  Future<void> _loadGroups() async {
    if (_isRefreshing) return;

    setState(() {
      loading = true;
      _isRefreshing = true;
    });

    _refreshIconController.repeat();

    try {
      final res = await APIService.getUserGroups(uid);
      final list = (res['groups'] ?? res['data'] ?? []) as List;
      groups = list.map((j) => GroupItem.fromJson(j as Map<String, dynamic>)).toList();
      _filterGroups();
    } catch (e) {
      _showSnack('Failed to load groups: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          _isRefreshing = false;
        });
        _refreshIconController.reset();
      }
    }
  }

  void _filterGroups() {
    if (_searchController.text.isEmpty) {
      _filteredGroups = List.from(groups);
    } else {
      _filteredGroups = groups
          .where((group) => group.name.toLowerCase().contains(_searchController.text.toLowerCase()))
          .toList();
    }
    setState(() {});
  }

  void _goToChat(GroupItem g) {
    Navigator.pushNamed(
      context,
      GroupChatScreen.routeName,
      arguments: GroupChatArgs(
        username: username,
        uid: uid,
        groupId: g.id,
        groupName: g.name,
        groupCode: g.code,
      ),
    ).then((_) => _loadGroups()); // Reload groups when returning from chat
  }

  Future<void> _createGroup() async {
    final r = await showCreateGroupDialog(context);
    if (r == null) return;

    setState(() => loading = true);

    try {
      final res = await APIService.createGroup(
        username: username,
        uid: uid,
        password: r.password,
        groupName: r.name,
      );

      if (res['success'] == true) {
        final id = res['groupId'].toString();
        final code = (res['groupCode'] ?? '').toString();
        await _loadGroups();
        if (!mounted) return;
        _goToChat(GroupItem(id: id, name: r.name?.isNotEmpty == true ? r.name! : 'New group', code: code));
        _showSuccessSnack('Group created successfully!');
      } else {
        _showErrorSnack(res['error'] ?? 'Failed to create group');
      }
    } catch (e) {
      _showErrorSnack('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _joinGroup() async {
    final r = await showJoinGroupDialog(context);
    if (r == null) return;

    setState(() => loading = true);

    try {
      final res = await APIService.joinGroup(
        code: r.code,
        uid: uid,
        password: r.password,
        username: username,
      );

      if (res['success'] == true) {
        final id = res['groupId'].toString();
        await _loadGroups();
        if (!mounted) return;
        _goToChat(GroupItem(id: id, name: '[New Group Room]', code: r.code));
        _showSuccessSnack('Joined group successfully!');
      } else {
        _showErrorSnack(res['error'] ?? 'Failed to join group');
      }
    } catch (e) {
      _showErrorSnack('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSuccessSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDarkMode = themeNotifier.themeMode == ThemeMode.dark ||
        (themeNotifier.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      // Keep bottom navigation fixed; handle keyboard insets within body
      resizeToAvoidBottomInset: false,
      backgroundColor: isDarkMode ? const Color(0xFF0D1A26) : const Color(0xFFFCF9F5),
      bottomNavigationBar: const BottomNavBar(selectedIndex: 2),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(cs, isDarkMode),
            const SizedBox(height: 8),
            // If a username is required, show the inline prompt (non-modal). User can still use bottom nav.
            if (_requireUsername) ...[
              // Manually lift the prompt above the keyboard without moving the bottom nav
              AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: _buildUsernamePrompt(cs, isDarkMode),
              ),
              // Expanded(
              //   child: SingleChildScrollView(
              //     padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
              //     child: Center(
              //       child: Text(
              //         'Set your user name to access groups',
              //         style: TextStyle(color: isDarkMode ? Colors.white70 : cs.onSurfaceVariant),
              //       ),
              //     ),
              //   ),
              // ),
            ] else ...[
              Expanded(
                child: loading
                    ? Center(
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
                              'Loading your groups...',
                              style: TextStyle(color: isDarkMode ? Colors.white70 : cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : groups.isEmpty
                        ? _buildEmptyState(cs, isDarkMode)
                        : RefreshIndicator(
                            onRefresh: _loadGroups,
                            child: _filteredGroups.isEmpty ? _buildNoSearchResults(cs, isDarkMode) : _buildGroupList(cs, isDarkMode),
                          ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, bool isDarkMode) {
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
                    username.isNotEmpty ? 'Welcome, $username' : 'Welcome',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF666666),
                    ),
                  ).animate().fadeIn(duration: const Duration(milliseconds: 500)).slideX(begin: -0.2, end: 0),
                  const SizedBox(height: 4),
                  Text(
                    'Group Room',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : const Color(0xFF0D1F2D),
                    ),
                  ).animate().fadeIn(duration: const Duration(milliseconds: 500)).slideX(begin: -0.2, end: 0),
                ],
              ),
              // only show search + refresh when both uid and username are available
              (_canUseSearchAndRefresh)
                  ? Row(
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
                            onTap: () {
                              setState(() {
                                _isSearchActive = !_isSearchActive;
                                if (!_isSearchActive) {
                                  _searchController.clear();
                                  _filterGroups();
                                }
                              });
                            },
                            child: Icon(
                              _isSearchActive ? Icons.close : Icons.search_rounded,
                              color: isDarkMode ? Colors.blue.shade300 : const Color(0xFF2196F3),
                              size: 24,
                            ),
                          ),
                        ).animate().scale(duration: const Duration(milliseconds: 500)).fadeIn(),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isRefreshing
                                ? (isDarkMode ? Colors.blue.withOpacity(0.2) : const Color(0xFF2196F3).withOpacity(0.1))
                                : (isDarkMode ? Colors.teal.withOpacity(0.2) : const Color(0xFFDFF2B8)),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: isDarkMode ? Colors.black.withOpacity(0.2) : const Color(0xFF0D1F2D).withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: AnimatedBuilder(
                            animation: _refreshIconController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _refreshIconController.value * 6.3,
                                child: GestureDetector(
                                  onTap: _loadGroups,
                                  child: Icon(
                                    _isRefreshing ? Icons.sync : Icons.refresh_rounded,
                                    color: _isRefreshing
                                        ? (isDarkMode ? Colors.blue.shade300 : const Color(0xFF2196F3))
                                        : (isDarkMode ? Colors.teal.shade200 : const Color(0xFF0D1F2D)),
                                    size: 24,
                                  ),
                                ),
                              );
                            },
                          ),
                        ).animate().scale(duration: const Duration(milliseconds: 500)).fadeIn(),
                      ],
                    )
                  : const SizedBox.shrink(),
             ],
          ),
          if (!loading) ...[
            const SizedBox(height: 20),
            // hide stat cards (Total Groups / Create/Join) when user must set display name / uid
            if (!_isSearchActive && !_requireUsername) _buildStatCards(cs, isDarkMode),
            if (_isSearchActive) ...[
              const SizedBox(height: 16),
              _buildSearchBar(cs, isDarkMode).animate().fadeIn(duration: const Duration(milliseconds: 500)).slideY(begin: -0.2, end: 0),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStatCards(ColorScheme cs, bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Groups',
            groups.length.toString(),
            Icons.group_rounded,
            isDarkMode ? Colors.green.shade300 : const Color(0xFF4CAF50),
            isDarkMode,
          ).animate().fadeIn(duration: const Duration(milliseconds: 600)).slideX(begin: -0.2, end: 0),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildDateCard(isDarkMode).animate().fadeIn(duration: const Duration(milliseconds: 600)).slideX(begin: -0.2, end: 0),
        ),
      ],
    );
  }

  Widget _buildDateCard(bool isDarkMode) {
    // If user hasn't provided a display name/uid yet, hide the create/join actionable buttons
    if (_requireUsername) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // subtle placeholders so layout remains intact but actions are hidden
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.lock, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text('Sign in', style: TextStyle(color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade700, fontSize: 12)),
            ],
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.lock, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text('Sign in', style: TextStyle(color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade700, fontSize: 12)),
            ],
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          onPressed: _createGroup,
          icon: Icons.add_circle_outline,
          label: 'Create',
          color: isDarkMode ? Colors.green.shade300 : const Color(0xFF4CAF50),
          isDarkMode: isDarkMode,
        ),
        _buildActionButton(
          onPressed: _joinGroup,
          icon: Icons.group_add_outlined,
          label: 'Join',
          color: isDarkMode ? Colors.blue.shade300 : const Color(0xFF2196F3),
          isDarkMode: isDarkMode,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(isDarkMode ? 0.2 : 0.1),
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
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required bool isDarkMode,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(isDarkMode ? 0.2 : 0.1),
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(isDarkMode ? 0.4 : 0.2)),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: color, size: 30),
            tooltip: label,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(ColorScheme cs, bool isDarkMode) {
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
            onChanged: (_) => _filterGroups(),
            autofocus: true,
            style: TextStyle(
              color: isDarkMode ? Colors.white : const Color(0xFF0D1F2D),
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: 'Search groups...',
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
                          _filterGroups();
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

  Widget _buildEmptyState(ColorScheme cs, bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: (isDarkMode ? Colors.blue.shade900 : cs.primaryContainer).withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Lottie.asset(
                  './assets/lottie/search.json',
                  width: 120,
                  height: 120,
                ),
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text(
              'No Groups Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : cs.primary,
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.5, end: 0),
            const SizedBox(height: 8),
            Text(
              'Create a new group or join an existing one to start sharing photos with your friends',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey.shade400 : cs.onSurfaceVariant,
              ),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 20),
            // Hide direct create/join actions when user hasn't set a display name/uid
            if (!_requireUsername)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _createGroup,
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                    label: const Text('Create Group'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? Colors.green.shade700 : const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: (isDarkMode ? Colors.green.shade600 : const Color(0xFF4CAF50)).withOpacity(0.2)),
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.5, end: 0),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _joinGroup,
                    icon: Icon(Icons.group_add_outlined, color: isDarkMode ? Colors.blue.shade300 : const Color(0xFF2196F3)),
                    label: Text('Join Group', style: TextStyle(color: isDarkMode ? Colors.blue.shade300 : const Color(0xFF2196F3))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      foregroundColor: isDarkMode ? Colors.blue.shade300 : const Color(0xFF2196F3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: (isDarkMode ? Colors.blue.shade300 : const Color(0xFF2196F3)).withOpacity(0.2)),
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.5, end: 0),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Set your user name to create or join groups', style: TextStyle(color: isDarkMode ? Colors.grey.shade400 : cs.onSurfaceVariant)),
              ),
           ],
         ),
       ),
     );
   }

  Widget _buildNoSearchResults(ColorScheme cs, bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 80,
              color: isDarkMode ? Colors.grey.shade700 : cs.surfaceContainerHighest,
            ),
            const SizedBox(height: 16),
            Text(
              'No matching groups',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white70 : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDarkMode ? Colors.grey.shade500 : cs.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();
                _filterGroups();
              },
              child: const Text('Clear search'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupList(ColorScheme cs, bool isDarkMode) {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: _filteredGroups.length,
        itemBuilder: (context, i) {
          final g = _filteredGroups[i];
          return AnimationConfiguration.staggeredList(
            position: i,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              horizontalOffset: 50.0,
              child: FadeInAnimation(
                child: _buildGroupItem(g, cs, isDarkMode),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupItem(GroupItem g, ColorScheme cs, bool isDarkMode) {
    final randomSeed = g.name.isNotEmpty ? g.name.codeUnitAt(0) % 360 : 0;
    final randomColor = HSLColor.fromAHSL(
      1.0,
      randomSeed.toDouble(),
      isDarkMode ? 0.7 : 0.6,
      isDarkMode ? 0.5 : 0.8,
    ).toColor();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: isDarkMode ? 1 : 2,
        shadowColor: isDarkMode ? Colors.black.withOpacity(0.4) : Colors.black12,
        color: isDarkMode ? const Color(0xFF1A2B3D) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isDarkMode ? BorderSide(color: Colors.grey.withOpacity(0.2)) : BorderSide.none,
        ),
        child: InkWell(
          onTap: () => _goToChat(g),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: randomColor.withOpacity(isDarkMode ? 0.3 : 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: randomColor.withOpacity(isDarkMode ? 0.7 : 0.6), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          g.name.isNotEmpty ? g.name[0].toUpperCase() : 'G',
                          style: TextStyle(
                            color: isDarkMode ? randomColor.lighten(0.2) : randomColor.darken(),
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                        ),
                      ),
                    ),
                    if (g.unread > 0)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.blue.shade400 : cs.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isDarkMode ? Colors.blue.shade400 : cs.primary).withOpacity(0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: isDarkMode ? const Color(0xFF1A2B3D) : cs.surface, width: 2),
                        ),
                        child: Text(
                          g.unread > 99 ? '99+' : '${g.unread}',
                          style: TextStyle(
                            color: cs.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.name,
                        style: TextStyle(
                          fontWeight: g.unread > 0 ? FontWeight.bold : FontWeight.w500,
                          fontSize: 16,
                          color: g.unread > 0 ? (isDarkMode ? Colors.white : cs.onSurface) : (isDarkMode ? Colors.white.withOpacity(0.9) : cs.onSurface.withOpacity(0.9)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.photo,
                            size: 14,
                            color: isDarkMode ? Colors.grey.shade500 : cs.onSurfaceVariant.withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              g.lastMessage ?? 'Share your first photo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: g.unread > 0
                                    ? (isDarkMode ? Colors.white.withOpacity(0.9) : cs.onSurface.withOpacity(0.9))
                                    : (isDarkMode ? Colors.grey.shade500 : cs.onSurfaceVariant.withOpacity(0.8)),
                                fontSize: 13,
                                fontWeight: g.unread > 0 ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDarkMode ? Colors.grey.shade600 : cs.onSurfaceVariant.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
