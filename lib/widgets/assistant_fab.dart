import 'package:flutter/material.dart';
import '../screens/assistant_screen.dart';
import '../theme.dart';
import '../utils/breakpoints.dart';
import '../utils/profile_gate.dart';

/// The floating way in to the assistant, on every tab of the shell.
///
/// It lives here rather than only inside Help & Support because that is three
/// taps deep — profile, Help & Support, then the card — and nobody goes
/// looking in a support inbox for a quick answer. A bubble in the corner is
/// where people have learnt to expect one, and most of what the assistant is
/// good at ("where is my booking", "how much is this") is asked while
/// browsing, not while raising a ticket.
///
/// Extended on a monitor, where there is room for words and a bare icon in a
/// corner reads as ambiguous. Circular on a phone, where the bottom tabs are
/// already using the width.
///
/// The sign-in gate is the same one booking and reviewing use. On the web
/// nobody is signed in when the home page loads, and the assistant answers
/// from the customer's own rows, so there is nothing it could say to a guest.
class AssistantFab extends StatelessWidget {
  const AssistantFab({super.key});

  Future<void> _open(BuildContext context) async {
    if (!await requireSignIn(context)) return;
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AssistantScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktopLayout(context)) {
      return FloatingActionButton.extended(
        onPressed: () => _open(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Ask the assistant'),
      );
    }

    return FloatingActionButton(
      onPressed: () => _open(context),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      tooltip: 'Ask the assistant',
      child: const Icon(Icons.chat_bubble_outline),
    );
  }
}
