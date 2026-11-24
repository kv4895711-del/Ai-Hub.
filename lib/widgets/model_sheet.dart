import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/ai_model.dart';
import '../providers/models_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

/// Bottom sheet jisme saare AI models dikhte hain.
/// Use: ModelSheet.show(context);
class ModelSheet extends StatefulWidget {
  const ModelSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => const ModelSheet(),
    );
  }

  @override
  State<ModelSheet> createState() => _ModelSheetState();
}

class _ModelSheetState extends State<ModelSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  bool _visionOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ModelsProvider>().loadIfNeeded();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pick(AiModel m) {
    final haptics = context.read<SettingsProvider>().haptics;
    AppUtils.selectionHaptic(haptics);
    context.read<ModelsProvider>().select(m.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mp = context.watch<ModelsProvider>();
    final accent = Theme.of(context).colorScheme.primary;
    final textPrimary = AppTheme.textPrimary(isDark);
    final textSecondary = AppTheme.textSecondary(isDark);

    final List<AiModel> results =
        mp.search(_query, visionOnly: _visionOnly).toList();

    final List<AiModel> autoModels = results.where((m) => m.isAuto).toList();
    final Map<String, List<AiModel>> groups = {};
    for (final m in results) {
      if (m.isAuto) continue;
      final key = m.provider.toString();
      groups.putIfAbsent(key, () => <AiModel>[]).add(m);
    }
    final providerNames = groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final List<Widget> items = [];

    for (final m in autoModels) {
      items.add(_modelTile(m, mp, accent, textPrimary, textSecondary, isDark));
    }

    for (final name in providerNames) {
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
        child: Text(
          name.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: textSecondary,
          ),
        ),
      ));
      for (final m in groups[name]!) {
        items.add(
            _modelTile(m, mp, accent, textPrimary, textSecondary, isDark));
      }
    }

    Widget? stateWidget;
    if (mp.isLoading && mp.models.isEmpty) {
      stateWidget = const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (mp.models.isEmpty) {
      final err = mp.error;
      stateWidget = Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: textSecondary),
            const SizedBox(height: 12),
            Text(
              err == null
                  ? 'Abhi koi model nahi mila.'
                  : 'Models load nahi hue.\n${err.toString()}',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => mp.load(force: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Dobara try karo'),
            ),
          ],
        ),
      );
    } else if (results.isEmpty) {
      stateWidget = Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Is search se kuch nahi mila.',
            style: TextStyle(color: textSecondary),
          ),
        ),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.baseBackground(isDark).withOpacity(0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppTheme.glassBorder(isDark)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: textSecondary.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Model chuno',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    if (mp.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      IconButton(
                        tooltip: 'Refresh',
                        icon: Icon(Icons.refresh_rounded, color: textPrimary),
                        onPressed: () => mp.load(force: true),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _controller,
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Model ya provider search karo',
                    hintStyle: TextStyle(color: textSecondary),
                    prefixIcon: Icon(Icons.search_rounded, color: textSecondary),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.close_rounded,
                                color: textSecondary),
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
                      borderSide: BorderSide(color: AppTheme.glassBorder(isDark)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppTheme.glassBorder(isDark)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: accent),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    FilterChip(
                      selected: _visionOnly,
                      label: const Text('Sirf vision (image) models'),
                      avatar: Icon(Icons.visibility_rounded,
                          size: 16, color: _visionOnly ? accent : textSecondary),
                      onSelected: (v) => setState(() => _visionOnly = v),
                    ),
                    const Spacer(),
                    Text(
                      '${mp.modelCount} models',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppTheme.glassBorder(isDark)),
              Expanded(
                child: stateWidget != null
                    ? ListView(
                        controller: scrollController,
                        children: [stateWidget],
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.only(bottom: 24),
                        children: items,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _modelTile(
    AiModel m,
    ModelsProvider mp,
    Color accent,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final selected = mp.selectedId == m.id;

    String ctx = m.contextLabel.toString();
    if (ctx == 'null') ctx = '';

    final List<Widget> badges = [];
    if (m.supportsVision) {
      badges.add(_badge(Icons.visibility_rounded, 'Vision', accent));
    } else if (m.visionGuessed) {
      badges.add(_badge(Icons.visibility_outlined, 'Vision?', textSecondary));
    }
    if (m.supportsTools) {
      badges.add(_badge(Icons.build_rounded, 'Tools', textSecondary));
    }
    if (ctx.isNotEmpty) {
      badges.add(_badge(Icons.data_array_rounded, ctx, textSecondary));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? accent.withOpacity(0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _pick(m),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    m.isAuto
                        ? Icons.auto_awesome_rounded
                        : Icons.memory_rounded,
                    size: 20,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.isAuto ? 'Auto (best available)' : m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: textPrimary,
                        ),
                      ),
                      if (badges.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(spacing: 8, runSpacing: 2, children: badges),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: accent, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}
