import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Formatting and status styling shared by every tender screen, so a status
/// pill looks the same on the list, the detail page and the bid comparison.

final _rupees = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// '1400000' -> '₹14,00,000'. Anything unparseable comes back as an em dash
/// rather than a crash — a missing figure is a normal state here.
String tenderMoney(dynamic amount) {
  final value = double.tryParse('${amount ?? ''}');
  if (value == null) return '—';
  return _rupees.format(value);
}

/// '2026-08-26' -> '26 Aug 2026'.
String tenderDate(dynamic raw) {
  final parsed = DateTime.tryParse('${raw ?? ''}'.trim());
  if (parsed == null) return '—';
  return DateFormat('d MMM yyyy').format(parsed);
}

/// '2026-08-26T10:30:00Z' -> '26 Aug, 10:30 AM'.
String tenderDateTime(dynamic raw) {
  final parsed = DateTime.tryParse('${raw ?? ''}'.trim());
  if (parsed == null) return '—';
  return DateFormat('d MMM, h:mm a').format(parsed.toLocal());
}

/// 'Closes in 3 days' / 'Closing today' / 'Closed', or null when the tender
/// has no deadline at all.
String? tenderDeadlineHint(dynamic rawDeadline) {
  final deadline = DateTime.tryParse('${rawDeadline ?? ''}'.trim());
  if (deadline == null) return null;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(deadline.year, deadline.month, deadline.day);
  final days = target.difference(today).inDays;

  if (days < 0) return 'Bidding closed';
  if (days == 0) return 'Closing today';
  if (days == 1) return 'Closes tomorrow';
  return 'Closes in $days days';
}

/// How one tender status is presented.
class TenderStatusStyle {
  final String label;
  final Color color;
  final IconData icon;

  /// What the customer should understand is happening, in one line.
  final String hint;

  const TenderStatusStyle(this.label, this.color, this.icon, this.hint);
}

TenderStatusStyle tenderStatusStyle(String? status) {
  switch (status) {
    case 'DRAFT':
      return TenderStatusStyle(
        'Draft',
        Colors.grey.shade600,
        Icons.edit_note_rounded,
        'Not sent yet. Add your drawings, then publish it.',
      );
    case 'PENDING_APPROVAL':
      return TenderStatusStyle(
        'Under review',
        Colors.orange.shade700,
        Icons.hourglass_top_rounded,
        'Our team is checking it. Vendors cannot see it yet.',
      );
    case 'REJECTED':
      return TenderStatusStyle(
        'Needs changes',
        Colors.red.shade600,
        Icons.error_outline_rounded,
        'Fix the point below and publish it again.',
      );
    case 'OPEN':
      return TenderStatusStyle(
        'Open for bids',
        Colors.blue.shade700,
        Icons.campaign_rounded,
        'Vendors can see this and are sending their quotes.',
      );
    case 'AWARDED':
      return TenderStatusStyle(
        'Awarded',
        Colors.indigo.shade600,
        Icons.handshake_rounded,
        'Deal confirmed. Your vendor will start shortly.',
      );
    case 'IN_PROGRESS':
      return TenderStatusStyle(
        'Work in progress',
        Colors.purple.shade600,
        Icons.construction_rounded,
        'Work is under way. Watch the updates below.',
      );
    case 'COMPLETED':
      return TenderStatusStyle(
        'Completed',
        Colors.green.shade700,
        Icons.check_circle_outline_rounded,
        'Finished. Tell us how it went.',
      );
    case 'CANCELLED':
      return TenderStatusStyle(
        'Cancelled',
        Colors.red.shade600,
        Icons.cancel_outlined,
        'This tender was closed.',
      );
    default:
      return TenderStatusStyle(
        status ?? 'Unknown',
        Colors.grey,
        Icons.help_outline_rounded,
        '',
      );
  }
}

/// The pill used on cards and headers.
class TenderStatusPill extends StatelessWidget {
  final String? status;
  final bool compact;

  const TenderStatusPill({super.key, required this.status, this.compact = true});

  @override
  Widget build(BuildContext context) {
    final style = tenderStatusStyle(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: compact ? 13 : 16, color: style.color),
          const SizedBox(width: 5),
          Text(
            style.label,
            style: TextStyle(
              color: style.color,
              fontSize: compact ? 11.5 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
