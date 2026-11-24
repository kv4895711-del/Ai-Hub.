import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import '../models/chat.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

/// Side menu: chat list, search, new chat, rename, delete, pin,
/// aur "Clear all chats".
/// Use: Scaffold(drawer: const ChatDrawer(), ...)
class ChatDrawer extends StatefulWidget {
  const ChatDrawer({super.key});

  @override
  State<ChatDrawer> createState() => _ChatDrawerState();
}

class _ChatDrawerState extends State<ChatDrawer> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---------- helpers ----------

  DateTime _asDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  String _bucket(Chat chat) {
    if (chat.pinned) return 'Pinned';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = _asDate(chat.updatedAt);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Aaj';
    if (diff == 1) return 'Kal';
    if (diff <= 7) return 'Pichhle 7 din';
    return 'Purani chats';
  }

  bool get _haptics => context.read<SettingsProvider>().haptics;

  // ---------- actions ----------

  void _newChat() {
    AppUtils.mediumHaptic(_haptics);
    context.read<ChatProvider>().newChat();
    Navigator.of(context).pop();
  }

  void _open(Chat chat) {
    AppUtils.selectionHaptic(_haptics);
    context.read<ChatProvider>().selectChat(chat.id);
    Navigator.of(context).pop();
  }

  void _togglePin(Chat chat) {
    AppUtils.lightHaptic(_haptics);
    context.read<ChatProvider>().setPinned(chat.id, !chat.pinned);
  }

  Future<void> _rename(Chat chat) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: chat.title),
    );
    if (!mounted) return;
    if (result == null || result.isEmpty || result == chat.title) return;
    context.read<ChatProvider>().renameChat(chat.id, result);
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
  }) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _delete(Chat chat) async {
    final ok = await _confirm(
      title: 'Chat delete karein?',
      body: '"${chat.title}" hamesha ke liye delete ho jayegi.',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    AppUtils.mediumHaptic(_haptics);
    context.read<ChatProvider>().deleteChat(chat.id);
  }

  Future<void> _deleteAll() async {
    final ok = await _confirm(
      title: 'Saari chats delete karein?',
      body: 'Saari chats aur unke messages hamesha ke liye delete ho jayenge. '
          'Ye wapas nahi aa sakta.',
      action: 'Sab delete karo',
    );
    if (!ok || !mounted) return;
    AppUtils.mediumHaptic(_haptics);
    context.read<ChatProvider>().deleteAllChats();
    AppUtils.showSnack(context, 'Saari chats delete ho gayi');
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cp = context.watch<ChatProvider>();
    final accent = Theme.of(context).colorScheme.primary;
    final textPrimary = AppTheme.textPrimary(isDark);
    final textSecondary = AppTheme.textSecondary(isDark);
    final border = AppTheme.glassBorder(isDark);

    final q = _query.trim().toLowerCase();
    final List<Chat> chats = cp.chats
        .where((c) => q.isEmpty || c.title.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return _asDate(b.updatedAt).compareTo(_asDate(a.updatedAt));
      });

    // Headers + chats ko ek flat list mein daalo.
    final List<Object> rows = [];
    String? lastBucket;
    for (final c in chats) {
      final b = _bucket(c);
      if (b != lastBucket) {
        rows.add(b);
        lastBucket = b;
      }
      rows.add(c);
    }

    return Drawer(
      backgroundColor: AppTheme.baseBackground(isDark).withOpacity(0.97),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // New chat button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _newChat,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nayi chat'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _controller,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Chats search karo',
                  hintStyle: TextStyle(color: textSecondary),
                  prefixIcon: Icon(Icons.search_rounded, color: textSecondary),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close_rounded, color: textSecondary),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: AppTheme.glassFill(isDark),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: accent),
                  ),
                ),
              ),
            ),

            Divider(height: 1, color: border),

            // Chat list
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          q.isEmpty
                              ? 'Abhi koi chat nahi hai.\nUpar "Nayi chat" dabao.'
                              : 'Is search se kuch nahi mila.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textSecondary),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final row = rows[i];
                        if (row is String) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                            child: Text(
                              row.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: textSecondary,
                              ),
                            ),
                          );
                        }
                        final chat = row as Chat;
                        return _chatTile(
                          chat,
                          chat.id == cp.currentChatId,
                          accent,
                          textPrimary,
                          textSecondary,
                        );
                      },
                    ),
            ),

            Divider(height: 1, color: border),

            // Clear all
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: cp.chats.isEmpty ? null : _deleteAll,
                  icon: const Icon(Icons.delete_sweep_rounded),
                  label: const Text('Saari chats delete karo'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatTile(
    Chat chat,
    bool selected,
    Color accent,
    Color textPrimary,
    Color textSecondary,
  ) {
    final title = chat.title.trim().isEmpty ? 'Nayi chat' : chat.title;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected ? accent.withOpacity(0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _open(chat),
          onLongPress: () => _togglePin(chat),
          child: Padding(
            padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
            child: Row(
              children: [
                Icon(
                  chat.pinned
                      ? Icons.push_pin_rounded
                      : Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: selected || chat.pinned ? accent : textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      size: 20, color: textSecondary),
                  tooltip: 'Options',
                  onSelected: (v) {
                    if (v == 'pin') {
                      _togglePin(chat);
                    } else if (v == 'rename') {
                      _rename(chat);
                    } else if (v == 'delete') {
                      _delete(chat);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
                      value: 'pin',
                      child: Row(
                        children: [
                          Icon(
                            chat.pinned
                                ? Icons.push_pin_outlined
                                : Icons.push_pin_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(chat.pinned ? 'Unpin karo' : 'Pin karo'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 20),
                          SizedBox(width: 12),
                          Text('Naam badlo'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 20, color: Colors.redAccent),
                          SizedBox(width: 12),
                          Text('Delete',
                              style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rename dialog: apna controller khud sambhalta hai (crash se bachne ke liye).
class _RenameDialog extends StatefulWidget {
  final String initial;
  const _RenameDialog({required this.initial});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
    _c.selection =
        TextSelection(baseOffset: 0, extentOffset: widget.initial.length);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(_c.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chat ka naam badlo'),
      content: TextField(
        controller: _c,
        autofocus: true,
        maxLength: 80,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: const InputDecoration(hintText: 'Naya naam'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
