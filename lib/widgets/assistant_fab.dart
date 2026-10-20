import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../screens/assistant_screen.dart';
import '../utils/breakpoints.dart';
import '../utils/profile_gate.dart';

/// The floating way in to the assistant, on every tab of the shell.
///
/// It lives here rather than only inside Help & Support because that is three
/// taps deep — profile, Help & Support, then the card — and nobody goes
/// looking in a support inbox for a quick answer. A mascot in the corner is
/// where people have learnt to expect one, and most of what the assistant is
/// good at ("where is my booking", "how much is this") is asked while
/// browsing, not while raising a ticket.
///
/// A robot rather than a labelled pill: it reads as "chat" to anyone who has
/// used the web, in any language, which matters on a site whose customers do
/// not all read English comfortably.
///
/// The sign-in gate is the same one booking and reviewing use. On the web
/// nobody is signed in when the home page loads, and the assistant answers
/// from the customer's own rows, so there is nothing it could say to a guest.
class AssistantFab extends StatefulWidget {
  const AssistantFab({super.key});

  @override
  State<AssistantFab> createState() => _AssistantFabState();
}

class _AssistantFabState extends State<AssistantFab>
    with SingleTickerProviderStateMixin {
  /// A slow bob, so the mascot reads as floating rather than stuck on.
  ///
  /// Four seconds and six pixels: enough to catch the eye once, slow enough
  /// not to nag at somebody trying to read the page behind it.
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (!await requireSignIn(context)) return;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AssistantScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = isDesktopLayout(context) ? 110.0 : 88.0;

    // The bob wraps the tap target rather than sitting inside it, so what you
    // see is what you can tap. The other way round, the mascot drifts up to
    // six pixels away from its own hit box -- the kind of near-miss nobody
    // can describe but everybody feels.
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -6 * Curves.easeInOut.transform(_bob.value)),
        child: child,
      ),
      child: Tooltip(
        message: 'Ask the assistant',
        child: GestureDetector(
          onTap: _open,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              fit: StackFit.expand,
              children: [_shadow(), _mascot()],
            ),
          ),
        ),
      ),
    );
  }

  /// A drop shadow that follows the robot's own outline rather than a disc
  /// behind it.
  ///
  /// The mascot is mostly white and so is the page, so without this it
  /// dissolves into the background -- and a circular shadow would show as a
  /// halo around a shape that is not a circle.
  Widget _shadow() {
    return Transform.translate(
      offset: const Offset(0, 5),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: _mascot(
          color: Colors.black.withValues(alpha: 0.3),
          blend: BlendMode.srcIn,
        ),
      ),
    );
  }

  /// The mascot, optionally flattened to a silhouette for the shadow pass.
  Widget _mascot({Color? color, BlendMode? blend}) {
    return Image.asset(
      'assets/assistant_bot.png',
      fit: BoxFit.contain,
      color: color,
      colorBlendMode: blend,
      // A missing asset must not take the whole shell down with it.
      errorBuilder: (context, error, stack) => const Center(
        child: CircleAvatar(child: Icon(Icons.chat_bubble_outline)),
      ),
    );
  }
}
