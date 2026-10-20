import '../utils/breakpoints.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'ticket_detail_screen.dart';

/// The in-app assistant.
///
/// Deliberately not a general chatbot screen. Three things shape it:
///
/// The assistant answers from the customer's own rows or from the team's own
/// answer book, and says so when it cannot. There is nothing to "regenerate"
/// and no reason to offer it, so the only actions are asking, tapping a
/// suggested question, and asking for a person.
///
/// Every answer may come with suggestions, which are real questions the
/// assistant knows how to answer. They matter most when it fails: a dead end
/// offers the nearest questions it does know, which is a second chance from
/// the customer rather than a shrug.
///
/// When the assistant is unsure it sets `can_escalate`, and the handover
/// button appears under that answer. Tapping it opens a real support ticket
/// carrying the whole transcript, so nobody has to retype their problem.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

/// One turn on screen. `pending` is the question that has been sent but not
/// answered yet, which is what the typing indicator hangs off.
class _Turn {
  _Turn({required this.text, required this.isBot, this.pending = false});

  final String text;
  final bool isBot;
  final bool pending;
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  /// Null while the session is still loading, so the screen can tell
  /// "loading" apart from "switched off".
  bool? _enabled;

  final List<_Turn> _turns = [];
  List<String> _suggestions = [];
  bool _canEscalate = false;
  bool _sending = false;
  String? _error;

  /// Set once this chat has been handed to support, which ends it: the
  /// transcript a person is about to read must not keep growing.
  int? _ticketId;

  @override
  void initState() {
    super.initState();
    _openSession();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openSession() async {
    try {
      final session = await ApiService.getAssistantSession();
      if (!mounted) return;

      if (session['enabled'] != true) {
        setState(() => _enabled = false);
        return;
      }

      final conversation =
          session['conversation'] as Map<String, dynamic>? ?? {};
      final stored = conversation['messages'] as List<dynamic>? ?? [];

      setState(() {
        _enabled = true;
        _turns
          ..clear()
          ..addAll(
            stored.map(
              (m) => _Turn(
                text: (m['text'] ?? '').toString(),
                isBot: m['is_bot'] == true,
              ),
            ),
          );

        // The greeting is not a stored message -- it is settings text an admin
        // owns -- so it stands in for one only while the chat is empty.
        if (_turns.isEmpty) {
          final greeting = (session['greeting'] ?? '').toString();
          if (greeting.isNotEmpty) {
            _turns.add(_Turn(text: greeting, isBot: true));
          }
        }

        _suggestions = (session['suggestions'] as List<dynamic>? ?? [])
            .map((s) => s.toString())
            .toList();
      });
      _scrollToEnd();
    } catch (_) {
      if (mounted) {
        setState(() {
          _enabled = true;
          _error = 'Could not reach the assistant. Pull down to try again.';
        });
      }
    }
  }

  Future<void> _ask(String question) async {
    final text = question.trim();
    if (text.isEmpty || _sending || _ticketId != null) return;

    _controller.clear();
    setState(() {
      _sending = true;
      _error = null;
      // The suggestions belonged to the previous answer; keeping them on
      // screen while a new question is in flight invites a second tap.
      _suggestions = [];
      _turns.add(_Turn(text: text, isBot: false));
      _turns.add(_Turn(text: '', isBot: true, pending: true));
    });
    _scrollToEnd();

    try {
      final reply = await ApiService.askAssistant(text);
      if (!mounted) return;

      final message = reply['message'] as Map<String, dynamic>? ?? {};
      setState(() {
        _turns.removeLast(); // the typing indicator
        _turns.add(
          _Turn(text: (message['text'] ?? '').toString(), isBot: true),
        );
        _suggestions = (reply['suggestions'] as List<dynamic>? ?? [])
            .map((s) => s.toString())
            .toList();
        _canEscalate = reply['can_escalate'] == true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _turns.removeLast();
        // The question stays on screen above this: it was asked, and showing
        // the failure under it is clearer than silently dropping both.
        _error = _message(e);
        // A limit or an outage is exactly when somebody needs a person.
        _canEscalate = true;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  Future<void> _handOver() async {
    setState(() => _sending = true);
    try {
      final result = await ApiService.escalateAssistantChat();
      if (!mounted) return;
      setState(() {
        _ticketId = result['ticket_id'] as int?;
        _canEscalate = false;
        _suggestions = [];
        _turns.add(
          _Turn(
            text: (result['message'] ?? 'Passed to our support team.')
                .toString(),
            isBot: true,
          ),
        );
      });
      _scrollToEnd();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// An exception's message without Dart's "Exception: " prefix.
  ///
  /// The strings these carry are the server's own wording, written for the
  /// customer, so they are shown as-is.
  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  void _scrollToEnd() {
    // After the frame, so the list has the new row's height.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant'),
        bottom: _enabled == true && _ticketId == null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(0),
                child: Container(height: 1, color: Colors.grey.shade200),
              )
            : null,
      ),
      body: DesktopCentered(
        maxWidth: kDesktopFormWidth,
        child: switch (_enabled) {
          null => const Center(child: CircularProgressIndicator()),
          false => _unavailable(),
          _ => _chat(),
        },
      ),
    );
  }

  /// Shown when an admin has switched the assistant off for this app.
  Widget _unavailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'The assistant is not available right now.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.support_agent),
              label: const Text('Go to Help & Support'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chat() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              for (final turn in _turns) _bubble(turn),
              if (_error != null) _errorNote(_error!),
              if (_suggestions.isNotEmpty) _suggestionChips(),
              if (_canEscalate && _ticketId == null) _handOverButton(),
              if (_ticketId != null) _ticketLink(),
            ],
          ),
        ),
        if (_ticketId == null) _composer(),
      ],
    );
  }

  Widget _bubble(_Turn turn) {
    final isBot = turn.isBot;
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isBot ? Colors.grey.shade200 : AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: turn.pending
            ? const _TypingDots()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Answers are written as several short lines, so the
                  // newlines in them are meant to survive.
                  Text(
                    turn.text,
                    style: TextStyle(
                      color: isBot ? Colors.black87 : Colors.white,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isBot ? 'Assistant' : 'You',
                    style: TextStyle(
                      color: isBot ? Colors.black45 : Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Questions the assistant knows how to answer, offered as chips.
  Widget _suggestionChips() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final suggestion in _suggestions)
            ActionChip(
              label: Text(suggestion, style: const TextStyle(fontSize: 12)),
              onPressed: _sending ? null : () => _ask(suggestion),
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
            ),
        ],
      ),
    );
  }

  Widget _handOverButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _sending ? null : _handOver,
          icon: const Icon(Icons.support_agent, size: 18),
          label: const Text('Talk to a person'),
        ),
      ),
    );
  }

  /// Shown once the chat has been handed over. The chat ends here, so this
  /// replaces the composer rather than sitting above it.
  Widget _ticketLink() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ticket #$_ticketId is with our support team.',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'They have the whole chat, so there is nothing to repeat. '
            'Replies arrive on the ticket.',
            style: TextStyle(color: AppColors.textGrey, fontSize: 12),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => TicketDetailScreen(ticketId: _ticketId!),
              ),
            ),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Open the ticket'),
          ),
        ],
      ),
    );
  }

  Widget _errorNote(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Text(
        message,
        style: TextStyle(color: Colors.red.shade900, fontSize: 13),
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_sending,
                textInputAction: TextInputAction.send,
                onSubmitted: _ask,
                decoration: InputDecoration(
                  hintText: 'Ask about a booking, a payment, a price...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () => _ask(_controller.text),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three dots, while an answer is on its way.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Opacity(
                  // Each dot a third of a cycle behind the one before it.
                  opacity: 0.3 +
                      0.7 *
                          ((_controller.value + i / 3) % 1 < 0.5
                              ? (_controller.value + i / 3) % 1 * 2
                              : 2 - ((_controller.value + i / 3) % 1) * 2),
                  child: const CircleAvatar(
                    radius: 3,
                    backgroundColor: Colors.black54,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
