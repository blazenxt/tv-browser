import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Visual style constants shared by the TV UI.
class TvStyle {
  TvStyle._();

  static const Color background = Color(0xFF0E1116);
  static const Color surface = Color(0xFF1A212B);
  static const Color surfaceAlt = Color(0xFF232C38);
  static const Color accent = Color(0xFFFFD740);
  static const Color focusBorder = accent;
  static const double borderWidth = 3.0;
  static const double radius = 10.0;
}

/// A button designed for TV: clearly visible focus ring, activated with
/// DPAD select / enter, but also clickable with a mouse for emulator testing.
class TvButton extends StatefulWidget {
  const TvButton({
    super.key,
    required this.onPressed,
    this.icon,
    this.label,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
    this.expanded = false,
    this.padding,
    this.child,
    this.selected = false,
    this.onMenu, // long-press alternative: context menu key
  });

  final VoidCallback? onPressed;
  final IconData? icon;
  final String? label;
  final String? tooltip;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool expanded;
  final EdgeInsetsGeometry? padding;
  final Widget? child;
  final bool selected;

  /// Called when the MENU key is pressed while focused (bookmark delete, etc).
  final VoidCallback? onMenu;

  @override
  State<TvButton> createState() => _TvButtonState();
}

class _TvButtonState extends State<TvButton> {
  late final FocusNode _node = widget.focusNode ?? FocusNode();
  bool _focused = false;
  bool _hover = false;

  bool get _enabled => widget.onPressed != null;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA) {
      widget.onPressed?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.contextMenu && widget.onMenu != null) {
      widget.onMenu!.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final showRing = _enabled && (_focused || _hover);
    final bg = !_enabled
        ? TvStyle.surface.withOpacity(0.4)
        : widget.selected
            ? TvStyle.accent.withOpacity(0.18)
            : _focused
                ? TvStyle.surfaceAlt
                : TvStyle.surface;

    final content = widget.child ??
        Row(
          mainAxisSize:
              widget.expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                size: 22,
                color: _enabled
                    ? (widget.selected ? TvStyle.accent : Colors.white)
                    : Colors.white38,
              ),
            ],
            if (widget.icon != null && widget.label != null)
              const SizedBox(width: 8),
            if (widget.label != null)
              Flexible(
                child: Text(
                  widget.label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    color: _enabled
                        ? (widget.selected ? TvStyle.accent : Colors.white)
                        : Colors.white38,
                    fontWeight:
                        _focused ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
          ],
        );

    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      onFocusChange: (f) => setState(() => _focused = f),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: widget.padding ??
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(TvStyle.radius),
              border: Border.all(
                color: showRing ? TvStyle.focusBorder : Colors.transparent,
                width: TvStyle.borderWidth,
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Helper so the rest of the app can check for "activate" keys consistently.
bool isActivateKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.select ||
    key == LogicalKeyboardKey.enter ||
    key == LogicalKeyboardKey.numpadEnter ||
    key == LogicalKeyboardKey.gameButtonA;

bool isBackKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.goBack ||
    key == LogicalKeyboardKey.browserBack ||
    key == LogicalKeyboardKey.escape;

bool isMenuKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.contextMenu || key == LogicalKeyboardKey.f1;
