import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spring_button/spring_button.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../widgets/upload/UploadPopup.dart';
import '../services/theme_notifier.dart';

// Simple data classes
class GroupChatArgs {
  final String username;
  final String uid;
  final String groupId;
  final String groupName;
  final String? groupCode;

  GroupChatArgs({
    required this.username,
    required this.uid,
    required this.groupId,
    required this.groupName,
    this.groupCode,
  });
}

class ChatMessage {
  final String id;
  final String username;
  final String? imageUrl;
  final String? downloadUrl;
  final String? viewUrl;
  final DateTime timestamp;
  final String title;
  final String? size;
  final bool isMyMessage;

  ChatMessage({
    required this.id,
    required this.username,
    this.imageUrl,
    this.downloadUrl,
    this.viewUrl,
    required this.timestamp,
    required this.title,
    this.size,
    required this.isMyMessage,
  });
}

class GroupChatScreen extends StatefulWidget {
  static const String routeName = '/group-chat';
  final GroupChatArgs args;

  const GroupChatScreen({Key? key, required this.args}) : super(key: key);

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> with TickerProviderStateMixin {
   List<ChatMessage> messages = [];
  bool loading = false;
  bool _loadingGroupData = true;
  Map<String, dynamic>? _groupDetails;
  List<dynamic>? _groupMembers;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  late AnimationController _fabAnimationController;
  Timer? _refreshTimer;
  bool _showScrollToBottom = false;
  String? _lastFetchedMessageId;

  File? _pendingImage;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
      _setupScrollListener();
      _startPeriodicRefresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _fabAnimationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      if (mounted && !loading) await _checkForNewMessages();
    });
  }

  Future<void> _checkForNewMessages() async {
    try {
      final result = await APIService.getGroupDetails(groupId: widget.args.groupId, code: widget.args.groupCode ?? '', uid: widget.args.uid);
      if (result['success'] == true && mounted) {
        final List<dynamic> messagesData = result['messages'] ?? [];
        if (messagesData.isNotEmpty) {
          final String latestMessageId = messagesData.first['id']?.toString() ?? '';
          if (_lastFetchedMessageId != latestMessageId) {
            setState(() {
              messages = messagesData.map((m) => _mapToMessage(m)).toList();
              _lastFetchedMessageId = messages.isNotEmpty ? messages.first.id : null;
              _groupDetails = result['group'];
              _groupMembers = result['members'];
            });

            if (_scrollController.hasClients && _scrollController.position.pixels == 0) {
              _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _initializeChat() async {
    if (loading) return;
    setState(() => loading = true);
    await _fetchGroupDetails();
    if (mounted) setState(() => loading = false);
  }

  Future<void> _fetchGroupDetails() async {
    setState(() => _loadingGroupData = true);
    try {
      final details = await APIService.getGroupDetails(groupId: widget.args.groupId, code: widget.args.groupCode ?? '', uid: widget.args.uid);
      if (details['success'] == true && mounted) {
        final List<dynamic> messagesData = details['messages'] ?? [];
        setState(() {
          _groupDetails = details['group'];
          _groupMembers = details['members'];
          messages = messagesData.map((m) => _mapToMessage(m)).toList();
          if (messages.isNotEmpty) _lastFetchedMessageId = messages.first.id;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) _scrollController.jumpTo(0);
        });
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(details['message'] ?? 'Failed to load group')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load group')));
    }
    if (mounted) setState(() => _loadingGroupData = false);
  }

  ChatMessage _mapToMessage(dynamic msg) {
    return ChatMessage(
      id: msg['id']?.toString() ?? '',
      username: msg['username']?.toString() ?? 'Unknown',
      imageUrl: msg['imageUrl']?.toString(),
      downloadUrl: msg['downloadUrl']?.toString(),
      viewUrl: msg['viewUrl']?.toString(),
      timestamp: DateTime.tryParse(msg['timestamp']?.toString() ?? '') ?? DateTime.now(),
      title: msg['title']?.toString() ?? '',
      size: msg['size']?.toString(),
      isMyMessage: msg['uid']?.toString() == widget.args.uid.toString(),
    );
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > 500) {
        if (!_showScrollToBottom) {
          setState(() => _showScrollToBottom = true);
          _fabAnimationController.forward();
        }
      } else if (_showScrollToBottom) {
        setState(() => _showScrollToBottom = false);
        _fabAnimationController.reverse();
      }
    });
  }

  Future<void> _showImageSourceActionSheet() async {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: SafeArea(
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildSourceTile(icon: Icons.photo_library_outlined, label: 'Gallery', onTap: () => _pickImage(ImageSource.gallery)),
            _buildSourceTile(icon: Icons.camera_alt_outlined, label: 'Camera', onTap: () => _pickImage(ImageSource.camera)),
          ]),
        ),
      ),
    );
  }

  Widget _buildSourceTile({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
            child: Center(child: Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary)),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    HapticFeedback.mediumImpact();
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? picked = await picker.pickImage(source: source, imageQuality: 80);
      if (picked == null) return;
      setState(() {
        _pendingImage = File(picked.path);
      });
      // small delay for UX before showing preview
      await Future.delayed(const Duration(milliseconds: 120));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick image')));
    }
  }

  Future<void> _refreshMessages() async {
    if (loading) return;
    HapticFeedback.mediumImpact();
    await _fetchGroupDetails();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Messages refreshed')));
  }

  void _scrollToBottom() {
    HapticFeedback.selectionClick();
    if (_scrollController.hasClients) _scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    if (messageDate == today) return 'Today';
    if (messageDate == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (now.difference(messageDate).inDays < 7) return DateFormat('EEEE').format(date);
    return DateFormat('MMM d, y').format(date);
  }

  String _formatTime(DateTime date) => DateFormat('HH:mm').format(date);

  Color _getUserColor(String username, bool isDark) {
    final colors = [
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFFE91E63),
      const Color(0xFF00BCD4),
    ];
    return colors[username.hashCode.abs() % colors.length];
  }

  void _showGroupInfo() {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final isDarkMode = themeNotifier.themeMode == ThemeMode.dark || (themeNotifier.themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _GroupInfoBottomSheet(
        groupDetails: _groupDetails,
        groupMembers: _groupMembers,
        totalMessages: messages.length,
        isDarkMode: isDarkMode,
        onShare: () async {
          if (widget.args.groupCode != null) await Share.share('Join my PicDB group with code: ${widget.args.groupCode}');
        },
      ),
    );
  }

  void _showImageFullScreen(ChatMessage message) {
    Navigator.of(context).push(PageRouteBuilder(pageBuilder: (context, a1, a2) => FadeTransition(opacity: a1, child: _FullScreenImageViewer(imageUrl: message.imageUrl!, username: message.username, title: message.title, timestamp: _formatTime(message.timestamp), heroTag: 'image_${message.id}'))));
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDarkMode = themeNotifier.themeMode == ThemeMode.dark || (themeNotifier.themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
    final primaryBlue = isDarkMode ? const Color(0xFFCCE6FF) : const Color(0xFF0D1F2D);
    final accentBlue = isDarkMode ? const Color(0xFF4FC3F7) : const Color(0xFF2196F3);
    final scaffoldBg = isDarkMode ? const Color(0xFF081018) : const Color(0xFFFCF9F5);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: scaffoldBg,
      appBar: PreferredSize(preferredSize: const Size.fromHeight(96), child: _buildAppBar(primaryBlue, isDarkMode)),
      body: Column(children: [
        if (_loadingGroupData) _buildLoadingHeader(accentBlue, primaryBlue, isDarkMode),
        Expanded(child: _buildMessagesList(isDarkMode, primaryBlue, accentBlue)),
        if (_showScrollToBottom) _buildScrollToBottomButton(primaryBlue),
        _buildMessageInput(accentBlue, isDarkMode),
      ]),
    );
  }

  PreferredSizeWidget _buildAppBar(Color primaryBlue, bool isDarkMode) {
     final cover = _groupDetails?['coverImage'];
    return PreferredSize(
      preferredSize: const Size.fromHeight(96),
      child: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF071017) : Colors.white,
            image: cover != null ? DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover, opacity: 0.18) : null,
            gradient: cover == null
                ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [isDarkMode ? const Color(0xFF071017) : Colors.white, isDarkMode ? const Color(0xFF071017) : const Color(0xFFF8FBFF)])
                : null,
          ),
          child: Container(
            decoration: BoxDecoration(color: cover != null ? Color.fromRGBO(0,0,0,0.14) : Colors.transparent, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14))),
          ),
        ),
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: SafeArea(
          child: Row(children: [
            // styled back button
          Padding(
            padding: const EdgeInsets.only(right: 10, left: 12),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDarkMode ? Color.fromRGBO(76,175,80,0.18) : const Color.fromRGBO(76,175,80,0.10),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode ? Color.fromRGBO(0,0,0,0.04) : const Color.fromRGBO(13,31,45,0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_rounded, color: isDarkMode ? Colors.green.shade300 : const Color(0xFF4CAF50), size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            // title & meta
            Expanded(
              child: InkWell(
                onTap: _showGroupInfo,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(_groupDetails?['name'] ?? widget.args.groupName, style: TextStyle(color: primaryBlue, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('${_groupMembers?.length ?? 0} members', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(width: 8),
                  ])
                ]),
              ),
            ),

            // actions group styled like dashboard
            Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.blue.withOpacity(0.18) : const Color(0xFF2196F3).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode ? Color.fromRGBO(0,0,0,0.2) : const Color.fromRGBO(13,31,45,0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: GestureDetector(
                  onTap: _refreshMessages,
                  child: Icon(Icons.refresh_rounded, color: isDarkMode ? Colors.blue.shade300 : const Color(0xFF2196F3), size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.green.withOpacity(0.18) : const Color(0xFF2196F3).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: GestureDetector(
                  onTap: _showGroupInfo,
                  child: Icon(Icons.info_outline_rounded, color: isDarkMode ? Colors.green.shade300 : const Color(0xFF4CAF50), size: 22),
                ),
              ),
              const SizedBox(width: 8),
            ])
          ]),
        ),
      ),
    );
  }

  Widget _buildLoadingHeader(Color accentBlue, Color primaryBlue, bool isDarkMode) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF0D1A26) : Colors.white, boxShadow: [BoxShadow(color: Color.fromRGBO(0,0,0,0.03), blurRadius: 8, offset: const Offset(0, 2))]), child: Row(children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: accentBlue)), const SizedBox(width: 12), Text('Loading conversation...', style: TextStyle(color: primaryBlue, fontSize: 14, fontWeight: FontWeight.w500))]));
  }

  Widget _buildMessagesList(bool isDarkMode, Color primaryBlue, Color accentBlue) {
    if (_loadingGroupData) return _buildShimmerList(isDarkMode);
    if (messages.isEmpty) return _buildEmptyState(accentBlue, isDarkMode);

    return AnimationLimiter(
      child: ListView.builder(
        reverse: true,
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: messages.length + (loading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == messages.length && loading) return _buildLoadingIndicator();
          final messageIndex = messages.length - 1 - index;
          final message = messages[messageIndex];
          final bool isFirstOfDay = messageIndex == messages.length - 1 || !_isSameDay(message.timestamp, messages[messageIndex + 1].timestamp);
          return AnimationConfiguration.staggeredList(position: index, duration: const Duration(milliseconds: 350), child: SlideAnimation(verticalOffset: 20, child: FadeInAnimation(child: Column(children: [if (isFirstOfDay) _buildDateDivider(message.timestamp), _buildMessageBubble(message, isDarkMode, primaryBlue, accentBlue)]))));
        },
      ),
    );
  }

  Widget _buildShimmerList(bool isDarkMode) {
    final base = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlight = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;
    return ListView.builder(reverse: true, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), itemCount: 5, itemBuilder: (context, index) { final isLeft = index % 2 == 0; return Padding(padding: EdgeInsets.only(left: isLeft ? 0 : 60, right: isLeft ? 60 : 0, bottom: 16), child: Column(crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end, children: [if (isLeft) Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(width: 120, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)))), const SizedBox(height: 4), Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(width: MediaQuery.of(context).size.width * 0.6, height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)))), const SizedBox(height: 4), Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(width: 80, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))))])); });
  }

  Widget _buildEmptyState(Color accentBlue, bool isDarkMode) {
     final textColor = isDarkMode ? Colors.white70 : const Color(0xFF0D1F2D);
     final subtitleColor = isDarkMode ? Colors.white54 : Colors.grey.shade600;
    // compute RGB components from accent color value to avoid deprecated channel getters
    final int r = (accentBlue.value >> 16) & 0xFF;
    final int g = (accentBlue.value >> 8) & 0xFF;
    final int b = accentBlue.value & 0xFF;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Color.fromRGBO(r, g, b, 0.08), borderRadius: BorderRadius.circular(40)),
            child: Icon(Icons.image_outlined, size: 44, color: accentBlue),
          ),
          const SizedBox(height: 18),
          Text('No messages yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 8),
          Text('Share a photo or say hi to start the conversation', style: TextStyle(color: subtitleColor)),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)), const SizedBox(width: 12), Text('Loading more messages...', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))]));
  }

  Widget _buildDateDivider(DateTime date) {
    return Container(margin: const EdgeInsets.symmetric(vertical: 18), child: Row(children: [Expanded(child: Divider(color: Colors.grey.withAlpha((0.3*255).round()), thickness: 1)), Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withAlpha((0.2*255).round()))), child: Text(_formatDate(date), style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w500))), Expanded(child: Divider(color: Colors.grey.withAlpha((0.3*255).round()), thickness: 1))]));
  }

  Widget _buildMessageBubble(ChatMessage message, bool isDarkMode, Color primaryBlue, Color accentBlue) {
    return Padding(
      padding: EdgeInsets.only(left: message.isMyMessage ? 56 : 0, right: message.isMyMessage ? 0 : 56, bottom: 8),
      child: Column(
        crossAxisAlignment: message.isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!message.isMyMessage) _buildUsernameLabel(message, isDarkMode),
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            decoration: BoxDecoration(
              color: message.isMyMessage ? accentBlue : (isDarkMode ? const Color(0xFF0D1A26) : Colors.white),
              borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(message.isMyMessage ? 16 : 10), bottomRight: Radius.circular(message.isMyMessage ? 10 : 16)),
              boxShadow: [BoxShadow(color: Color.fromRGBO(0,0,0,0.03), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: message.imageUrl != null ? _buildImageMessage(message, isDarkMode) : _buildTextMessage(message, isDarkMode),
          ),
          _buildMessageFooter(message, isDarkMode)
        ],
      ),
    );
  }

  Widget _buildUsernameLabel(ChatMessage message, bool isDarkMode) {
    final color = _getUserColor(message.username, isDarkMode);
    return Padding(padding: const EdgeInsets.only(left: 12, bottom: 6), child: Row(children: [Container(width: 24, height: 24, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(message.username.isNotEmpty ? message.username[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)))), const SizedBox(width: 8), Text(message.username, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600))]));
  }

  Widget _buildTextMessage(ChatMessage message, bool isDarkMode) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: Text(message.title, style: TextStyle(color: message.isMyMessage ? Colors.white : (isDarkMode ? Colors.white70 : const Color(0xFF0D1F2D)), fontSize: 15, height: 1.4)));
  }

  Widget _buildImageMessage(ChatMessage message, bool isDarkMode) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         ClipRRect(
           borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
           child: GestureDetector(
             onTap: () => _showImageFullScreen(message),
             child: Hero(
               tag: 'image_${message.id}',
               child: Container(
                 width: double.infinity,
                 height: 200,
                 color: Colors.grey.shade100,
                 child: Image.network(
                   message.imageUrl!,
                   fit: BoxFit.cover,
                   loadingBuilder: (c, child, progress) {
                     if (progress == null) return child;
                     return Center(
                       child: CircularProgressIndicator(
                         value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null,
                       ),
                     );
                   },
                   errorBuilder: (c, e, s) => Container(
                     color: Colors.grey.shade100,
                     child: const Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Icon(Icons.broken_image_rounded, color: Colors.grey, size: 48),
                         SizedBox(height: 8),
                         Text('Failed to load image', style: TextStyle(color: Colors.grey)),
                       ],
                     ),
                   ),
                 ),
               ),
             ),
           ),
         ),
         Container(
           padding: const EdgeInsets.all(12),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
              Text(
                message.title.isNotEmpty ? message.title : 'Photo',
                style: TextStyle(
                  color: message.isMyMessage ? Colors.white : (isDarkMode ? Colors.white70 : const Color(0xFF0D1F2D)),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
               if (message.size?.isNotEmpty == true) ...[
                 const SizedBox(height: 6),
                Text(
                  _formatFileSize(message.size!),
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : Color.fromRGBO(13,31,45,0.7),
                    fontSize: 12,
                  ),
                ),
               ],
             ],
           ),
         ),
       ],
     );
   }

  Widget _buildMessageFooter(ChatMessage message, bool isDarkMode) {
    return Padding(padding: EdgeInsets.only(top: 6, left: message.isMyMessage ? 0 : 12, right: message.isMyMessage ? 12 : 0), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(_formatTime(message.timestamp), style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w400)), if (message.isMyMessage) ...[const SizedBox(width: 6), const Icon(Icons.check_rounded, size: 14, color: Color(0xFF4CAF50))]]));
  }

  Widget _buildMessageInput(Color accentBlue, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF071017) : Colors.white,
        boxShadow: [BoxShadow(color: Color.fromRGBO(0,0,0,0.03), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Camera + Gallery quick actions
            _buildCameraGalleryGroup(accentBlue, isDarkMode),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tap Camera or Gallery to share a photo',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : const Color(0xFF0D1F2D),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraGalleryGroup(Color accentBlue, bool isDarkMode) {
    final bg = isDarkMode ? Colors.grey.shade900 : Colors.white;
    return Row(
      children: [
        SpringButton(
          SpringButtonType.OnlyScale,
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Color.fromRGBO(0,0,0,0.04), blurRadius: 6, offset: const Offset(0,2))]),
            child: IconButton(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: Icon(Icons.camera_alt_rounded, color: accentBlue, size: 26),
              tooltip: 'Camera',
            ),
          ),
          onTap: () => _pickImage(ImageSource.camera),
          scaleCoefficient: 0.96,
        ),
        const SizedBox(width: 10),
        SpringButton(
          SpringButtonType.OnlyScale,
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Color.fromRGBO(0,0,0,0.04), blurRadius: 6, offset: const Offset(0,2))]),
            child: IconButton(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: Icon(Icons.photo_library_rounded, color: accentBlue, size: 26),
              tooltip: 'Gallery',
            ),
          ),
          onTap: () => _pickImage(ImageSource.gallery),
          scaleCoefficient: 0.96,
        ),
      ],
    );
  }

  Widget _buildScrollToBottomButton(Color primaryBlue) {
    return ScaleTransition(
      scale: _fabAnimationController,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton.small(
          backgroundColor: primaryBlue,
          elevation: 4,
          onPressed: _scrollToBottom,
          child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatFileSize(String size) {
    try {
      final s = size.trim();
      final regex = RegExp(r'([0-9,.]+)\s*([KMGT]?B)?', caseSensitive: false);
      final m = regex.firstMatch(s);
      if (m != null) {
        final numStr = m.group(1)!.replaceAll(',', '');
        final unit = (m.group(2) ?? '').toUpperCase();
        double bytes = double.parse(numStr);
        if (unit == 'KB') bytes = bytes * 1024;
        else if (unit == 'MB') bytes = bytes * 1024 * 1024;
        else if (unit == 'GB') bytes = bytes * 1024 * 1024 * 1024;
        else if (unit == 'TB') bytes = bytes * 1024 * 1024 * 1024 * 1024;
        // if unit is empty we assume the number is bytes
        if (bytes < 1024) return '${bytes.toStringAsFixed(bytes < 10 ? 1 : 0)} B';
        final kb = bytes / 1024;
        if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
        final mb = kb / 1024;
        if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
        final gb = mb / 1024;
        return '${gb.toStringAsFixed(1)} GB';
      }
    } catch (_) {}
    return size;
  }
}

class _GroupInfoBottomSheet extends StatelessWidget {
  final Map<String, dynamic>? groupDetails;
  final List<dynamic>? groupMembers;
  final int totalMessages;
  final VoidCallback onShare;
  final bool isDarkMode;

  const _GroupInfoBottomSheet({Key? key, required this.groupDetails, required this.groupMembers, required this.totalMessages, required this.onShare, required this.isDarkMode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
     final cover = groupDetails?['coverImage'];
     final background = isDarkMode ? const Color(0xFF081018) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0D1F2D);
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.grey.shade600;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header / cover
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                image: cover != null ? DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover) : null,
                // Use blue -> green themed gradient when there's no cover (dashboard style)
                gradient: cover == null
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDarkMode
                            ? [const Color(0xFF072435), const Color(0xFF083A2E)]
                            : [const Color(0xFFEAF6FF), const Color(0xFFF0FFF4)],
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  // overlay + title placed at bottom-left (painted first so it's behind)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      // Keep a subtle overlay on top of the cover; for gradient case keep a slight tint to make text pop
                      color: cover != null ? Color.fromRGBO(0,0,0,0.35) : (isDarkMode ? Color.fromRGBO(0,0,0,0.12) : Color.fromRGBO(255,255,255,0.04)),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(groupDetails?['name'] ?? 'Group Chat', style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFF4CAF50), borderRadius: BorderRadius.circular(4))), const SizedBox(width: 8), Text('${groupMembers?.length ?? 0} members', style: TextStyle(color: subtitleColor, fontSize: 14, fontWeight: FontWeight.w500))]),
                      ],
                    ),
                  ),

                  // top-left close/back button styled like dashboard (on top for proper hit-testing)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDarkMode ? Color.fromRGBO(76,175,80,0.18) : const Color.fromRGBO(76,175,80,0.10),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: isDarkMode ? Color.fromRGBO(0,0,0,0.04) : const Color.fromRGBO(13,31,45,0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(Icons.arrow_back_ios_rounded, color: isDarkMode ? Colors.green.shade300 : const Color(0xFF4CAF50), size: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Group code + actions (copy, share)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Color.fromRGBO(0,0,0,0.03), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    // code display
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Group Code', style: TextStyle(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(
                            (groupDetails?['code'] ?? groupDetails?['groupCode'] ?? '------').toString().toUpperCase(),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 2),
                          ),
                        ],
                      ),
                    ),

                    // copy button
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () async {
                            final code = (groupDetails?['code'] ?? groupDetails?['groupCode'] ?? '').toString();
                            if (code.isNotEmpty) {
                              await Clipboard.setData(ClipboardData(text: code.toUpperCase()));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group code copied')));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No group code available')));
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Color.fromRGBO(33,150,243,0.12) : const Color.fromRGBO(33,150,243,0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.copy_rounded, size: 18, color: isDarkMode ? Colors.blue.shade300 : const Color(0xFF2196F3)),
                          ),
                        ),
                      ),
                    ),

                    // share button
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () async {
                            final code = (groupDetails?['code'] ?? groupDetails?['groupCode'] ?? '').toString();
                            if (code.isNotEmpty) {
                              await Share.share('Join my PicDB group with code: ${code.toUpperCase()}');
                            } else {
                              // fallback to provided onShare callback
                              try {
                                onShare();
                              } catch (_) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No group code to share')));
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Color.fromRGBO(76,175,80,0.12) : const Color.fromRGBO(76,175,80,0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.share_rounded, size: 18, color: isDarkMode ? Colors.green.shade300 : const Color(0xFF4CAF50)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Members header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
                  Text('${groupMembers?.length ?? 0}', style: TextStyle(color: subtitleColor, fontSize: 14)),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Members list
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: (groupMembers != null && groupMembers!.isNotEmpty)
                    ? ListView.separated(
                        itemCount: groupMembers!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final member = groupMembers![index];
                          final username = (member['username'] ?? member['name'] ?? 'Unknown').toString();
                          final subtitle = (member['subtitle'] ?? member['bio'] ?? member['handle'] ?? '').toString();
                          final isOwner = member['role'] == 'owner' || member['isOwner'] == true || index == 0;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDarkMode ? Color.fromRGBO(76,175,80,0.06) : Color.fromRGBO(33,150,243,0.06)),
                              boxShadow: [BoxShadow(color: Color.fromRGBO(0,0,0,0.02), blurRadius: 6, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(color: _staticMemberColor(username), borderRadius: BorderRadius.circular(22)),
                                      child: Center(child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
                                    ),
                                    if (member['isOnline'] == true)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFF4CAF50), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white, width: 2))),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: Text(username, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor))),
                                          if (isOwner)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: isDarkMode ? Colors.green.shade800 : const Color.fromRGBO(76,175,80,0.12), borderRadius: BorderRadius.circular(12)),
                                              child: Text('owner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white70 : const Color(0xFF4CAF50))),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(fontSize: 12, color: subtitleColor)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Center(child: Text('No members to display', style: TextStyle(color: subtitleColor))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _staticMemberColor(String username) {
    final colors = [const Color(0xFF2196F3), const Color(0xFF4CAF50), const Color(0xFFFF9800), const Color(0xFF9C27B0)];
    return colors[username.hashCode.abs() % colors.length];
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String username;
  final String timestamp;
  final String? heroTag;
  final String title;

  const _FullScreenImageViewer({Key? key, required this.imageUrl, required this.username, required this.title, required this.timestamp, this.heroTag}) : super(key: key);

  // String _getFileName() {
  //   try {
  //     return imageUrl.split('/').last;
  //   } catch (_) {
  //     return 'Image';
  //   }
  // }

  void _showMoreOptions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF081018) : Colors.white;
    final handleColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final iconColor = isDark ? Colors.white70 : Colors.black54;
    final textStyle = TextStyle(color: isDark ? Colors.white : Colors.black87);

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: handleColor, borderRadius: BorderRadius.circular(2)),
            ),
                  ListTile(
                    leading: Icon(Icons.info_outline, color: iconColor),
                    title: Text('Image Info', style: textStyle),
                    onTap: () {
                      Navigator.pop(context);
                      _showImageInfo(context);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
            ),
        ),
    );
  }
  void _showImageInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => UploadPopup(imageUrl: imageUrl, imageName: title, viewUrl: imageUrl.replaceAll('/v/', '/d/')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withAlpha(200),
        elevation: 0,
        // Show the file name in the app bar
        title: Text(title, style: const TextStyle(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () => _showMoreOptions(context)),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_rounded, color: Colors.white, size: 48),
                SizedBox(height: 16),
                Text('Failed to load image', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

