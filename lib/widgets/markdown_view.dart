import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../core/utils.dart';
import '../theme/app_theme.dart';

/// Shows an AI answer with formatting: headings, bold, lists, tables, quotes,
/// and code blocks with a Copy button. The text is selectable.
class MarkdownView extends StatelessWidget {
  const MarkdownView({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = AppTheme.textPrimary(isDark);
    final secondary = AppTheme.textSecondary(isDark);
    final accent = theme.colorScheme.primary;
    final border = AppTheme.glassBorder(isDark);

    TextStyle base(double size, {FontWeight? weight}) => TextStyle(
          color: primary,
          fontSize: size,
          height: 1.45,
          fontWeight: weight,
        );

    final sheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: base(15.5),
      h1: base(22, weight: FontWeight.w700),
      h2: base(19.5, weight: FontWeight.w700),
      h3: base(17.5, weight: FontWeight.w600),
      h4: base(16.5, weight: FontWeight.w600),
      h5: base(15.5, weight: FontWeight.w600),
      h6: base(15, weight: FontWeight.w600),
      strong: TextStyle(color: primary, fontWeight: FontWeight.w700),
      em: TextStyle(color: primary, fontStyle: FontStyle.italic),
      a: TextStyle(color: accent, decoration: TextDecoration.underline),
      listBullet: base(15.5),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13.5,
        color: primary,
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.07),
      ),
      blockquote: base(15, weight: FontWeight.w500).copyWith(color: secondary),
      blockquotePadding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      blockquoteDecoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: border, width: 1)),
      ),
      tableBorder: TableBorder.all(color: border, width: 1),
      tableHead: base(14.5, weight: FontWeight.w700),
      tableBody: base(14.5),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      blockSpacing: 10,
      listIndent: 22,
    );

    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      styleSheet: sheet,
      builders: {'pre': _CodeBlockBuilder()},
      onTapLink: (text, href, title) {
        // Opening links needs an extra package, so we copy the link instead.
        if (href != null && href.isNotEmpty) {
          AppUtils.copyText(context, href);
        }
      },
    );
  }
}

/// Draws a fenced code block as a dark box with the language name and a Copy button.
class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.textContent.replaceAll(RegExp(r'\n+$'), '');

    // The language comes from the first child, e.g. class="language-dart".
    var language = '';
    if (element.children != null && element.children!.isNotEmpty) {
      final first = element.children!.first;
      if (first is md.Element) {
        final cls = first.attributes['class'] ?? '';
        if (cls.startsWith('language-')) {
          language = cls.substring('language-'.length);
        }
      }
    }

    return _CodeBlock(code: code, language: language);
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code, required this.language});

  final String code;
  final String language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    const codeBackground = Color(0xFF12131C);
    const headerBackground = Color(0xFF1C1E2B);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: codeBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassBorder(isDark)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: headerBackground,
            padding: const EdgeInsets.fromLTRB(14, 2, 4, 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    language.isEmpty ? 'code' : language,
                    style: const TextStyle(
                      color: Color(0xFFA9ADC1),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => AppUtils.copyText(context, code),
                  icon: Icon(Icons.copy_rounded, size: 15, color: accent),
                  label: Text(
                    'Copy',
                    style: TextStyle(color: accent, fontSize: 12.5),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(14),
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13.5,
                height: 1.45,
                color: Color(0xFFE6E8F2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
