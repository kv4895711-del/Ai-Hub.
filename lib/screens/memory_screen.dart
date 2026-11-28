import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/memory_item.dart';
import '../providers/chat_provider.dart';
import '../services/memory_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/glass_card.dart';

/// Memory screen: saved notes dekho, search karo, add / edit / delete karo,
/// aur memory ON / OFF karo. Sab kuch sirf is phone mein save hota hai.
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  MemoryService get _memory => context.read<ChatProvider>().memory;

  // ---------- Actions ----------

  Future<String?> _askText({required String title, String initial = ''}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: MemoryService.maxTextLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'For example: I like short answers in Hinglish',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final memory = _memory;
    final text = await _askText(title: 'Add a note');
    if (text == null || !mounted) return;
    final item = await memory.add(text);
    if (!mounted) return;
    AppUtils.showSnack(
      context,
      item == null ? 'Nothing to save' : 'Saved to memory',
    );
  }

  Future<void> _edit(MemoryItem item) async {
    final memory = _memory;
    final text = await _askText(title: 'Edit note', initial: item.text);
    if (text == null || !mounted) return;
    await memory.edit(item.id, text);
  }

  Future<void> _delete(MemoryItem item) async {
    final memory = _memory;
    await memory.remove(item.id);
    if (!mounted) return;
    AppUtils.showSnack(context, 'Note deleted');
  }

  Future<void> _clearAll() async {
    final memory = _memory;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all memory?'),
        content: const Text(
          'All saved notes will be removed from this phone. '
          'Your chats are not touched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await memory.clearAll();
    if (!mounted) return;
    AppUtils.showSnack(context, 'Memory cleared');
  }

  String _date(DateTime d) => DateFormat('d MMM y').format(d);

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final memory = context.read<ChatProvider>().memory;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add note'),
      ),
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(isDark),
              Expanded(
                child: ListenableBuilder(
                  listenable: memory,
                  builder: (context, _) => _buildBody(isDark, memory),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: GlassCard(
              radius: 22,
              padding: EdgeInsets.zero,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Memory',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(isDark),
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark, MemoryService memory) {
    final secondary = AppTheme.textSecondary(isDark);
    final shown = memory.search(_query);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
      children: [
        GlassCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SwitchListTile(
            title: const Text('Use memory in chats'),
            subtitle: const Text(
              'Saved notes are added to every chat, so replies know you better',
            ),
            value: memory.enabled,
            onChanged: (v) => memory.setEnabled(v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Text(
            'Tip: write "yaad rakho: ..." in a chat to save a note. '
            'Anything inside <private>...</private> is never saved.',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: secondary),
          ),
        ),
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: 'Search notes',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Text(
            '${memory.count} of ${MemoryService.maxItems} notes',
            style: TextStyle(fontSize: 12.5, color: secondary),
          ),
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Text(
                _query.isEmpty
                    ? 'No notes yet.'
                    : 'No notes match your search.',
                style: TextStyle(color: secondary),
              ),
            ),
          ),
        ...shown.map((m) => _buildItem(isDark, m)),
        if (memory.count > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: TextButton.icon(
                onPressed: _clearAll,
                icon: const Icon(Icons.delete_sweep_rounded),
                label: const Text('Delete all memory'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildItem(bool isDark, MemoryItem item) {
    final secondary = AppTheme.textSecondary(isDark);
    final from = item.source == 'chat' ? 'from chat' : 'added by you';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        radius: 18,
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 10),
        onTap: () => _edit(item),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.text,
                    style: const TextStyle(fontSize: 15, height: 1.35),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_date(item.updatedAt)} · $from',
                    style: TextStyle(fontSize: 12, color: secondary),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: secondary,
              ),
              onPressed: () => _delete(item),
            ),
          ],
        ),
      ),
    );
  }
}
