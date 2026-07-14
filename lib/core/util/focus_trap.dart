/// P1 task 7 — focus-trap helper for modal dialogs and bottom sheets.
///
/// Screen-reader users expect Tab/Shift-Tab navigation to stay inside a
/// modal while it's open (so focus doesn't silently escape to the dimmed
/// background). Flutter doesn't ship a built-in focus trap; this helper
/// wraps a child in a [FocusScope] with an [onKeyEvent] that intercepts
/// Tab key events at the boundary and wraps focus back to the first or
/// last focusable child.
///
/// Usage: wrap the modal's body in [FocusTrap] inside `showDialog` /
/// `showModalBottomSheet`. The focus trap activates only when the parent
/// [FocusScope] has primary focus, so it doesn't interfere with the rest
/// of the app.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A focus-trap wrapper for modals. Uses [FocusScope] + [onKeyEvent] to
/// keep Tab/Shift-Tab navigation confined to the modal's content.
class FocusTrap extends StatelessWidget {
  final Widget child;

  const FocusTrap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: _FocusTrapBody(child: child),
    );
  }
}

class _FocusTrapBody extends StatefulWidget {
  final Widget child;
  const _FocusTrapBody({required this.child});

  @override
  State<_FocusTrapBody> createState() => _FocusTrapBodyState();
}

class _FocusTrapBodyState extends State<_FocusTrapBody> {
  final FocusNode _node = FocusNode();

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }

  /// Intercept Tab/Shift-Tab at the boundary and wrap to the first/last
  /// focusable descendant.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isTab = event.logicalKey == LogicalKeyboardKey.tab;
    if (!isTab) return KeyEventResult.ignored;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    // Find all focusable descendants of this node.
    final scopeNode = FocusScope.of(context);
    final focusables = <FocusNode>[];
    void collect(FocusNode n) {
      if (n.canRequestFocus && n != _node) focusables.add(n);
      for (final c in n.children) {
        collect(c);
      }
    }

    collect(scopeNode);
    if (focusables.isEmpty) return KeyEventResult.ignored;

    // Walk the descendant tree in declaration order (Flutter's
    // children list is already in DOM/reading order for our modals).
    final first = focusables.first;
    final last = focusables.last;
    final current = scopeNode.focusedChild;

    if (shift) {
      // Shift+Tab on the first → wrap to the last.
      if (current == first || current == null) {
        last.requestFocus();
        return KeyEventResult.handled;
      }
    } else {
      // Tab on the last → wrap to the first.
      if (current == last) {
        first.requestFocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }
}
