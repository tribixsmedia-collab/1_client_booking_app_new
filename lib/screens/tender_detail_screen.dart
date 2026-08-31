import '../utils/breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../theme.dart';
import '../utils/tender_format.dart';
import 'tender_bids_screen.dart';

/// One tender, from draft through to the review — whatever stage it is at,
/// the action the customer can take next sits at the top of the screen.
class TenderDetailScreen extends StatefulWidget {
  final int tenderId;

  const TenderDetailScreen({super.key, required this.tenderId});

  @override
  State<TenderDetailScreen> createState() => _TenderDetailScreenState();
}

class _TenderDetailScreenState extends State<TenderDetailScreen> {
  Map<String, dynamic>? _tender;
  bool _isLoading = true;
  bool _isBusy = false;
  String? _errorMessage;

  /// Whether anything changed, so the list behind can refresh on the way out.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final tender = await ApiService.getTenderDetail(widget.tenderId);
      if (!mounted) return;
      setState(() {
        _tender = tender;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _isBusy = true);
    try {
      await action();
      _changed = true;
      if (!mounted) return;
      _snack(success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------- actions
  Future<void> _publish() => _run(
    () => ApiService.publishTender(widget.tenderId),
    'Sent for review. We will publish it to vendors shortly.',
  );

  Future<void> _cancel() async {
    final reason = await _askForText(
      title: 'Cancel this tender?',
      message: 'Any vendor who has bid will be told it is closed.',
      hint: 'Reason (optional)',
      confirmLabel: 'Cancel tender',
      isDestructive: true,
    );
    if (reason == null) return;
    await _run(
      () => ApiService.cancelTender(widget.tenderId, reason: reason),
      'Tender cancelled.',
    );
  }

  Future<void> _openBids() async {
    final awarded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TenderBidsScreen(
          tenderId: widget.tenderId,
          expectedBudget: _tender?['expected_budget'],
        ),
      ),
    );
    if (awarded == true) {
      _changed = true;
      _load();
    }
  }

  Future<void> _payMilestone(Map<String, dynamic> milestone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as paid?'),
        content: Text(
          'This records that you have settled '
          '${tenderMoney(milestone['amount'])} for '
          '"${milestone['title']}". It does not move any money — pay your '
          'vendor directly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark paid'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run(
      () => ApiService.payTenderMilestone(milestone['id']),
      'Payment recorded.',
    );
  }

  Future<void> _leaveReview() async {
    var rating = 5;
    final comment = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('How did it go?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setDialogState(() => rating = i),
                      icon: Icon(
                        i <= rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: Colors.amber.shade600,
                        size: 32,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: comment,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Anything you want to add (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (submitted != true) {
      comment.dispose();
      return;
    }
    final text = comment.text.trim();
    comment.dispose();

    await _run(
      () => ApiService.submitTenderReview(
        tenderId: widget.tenderId,
        rating: rating,
        comment: text,
      ),
      'Thanks for the review.',
    );
  }

  Future<String?> _askForText({
    required String title,
    required String message,
    required String hint,
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: const TextStyle(fontSize: 13.5)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(hintText: hint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep it'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: isDestructive
                ? ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _call(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _snack('Could not open the dialler.');
    }
  }

  // --------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_tender?['code']?.toString() ?? 'Tender'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
        ),
        body: DesktopCentered(
          maxWidth: kDesktopFormWidth,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _errorState()
              : RefreshIndicator(onRefresh: _load, child: _content()),
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppColors.textGrey,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textGrey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final tender = _tender!;
    final status = tender['status'] as String?;
    final style = tenderStatusStyle(status);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ---------------------------------------------------- status banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: style.color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(style.icon, color: style.color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    style.label,
                    style: TextStyle(
                      color: style.color,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              if (style.hint.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  style.hint,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
              ],
              if (status == 'REJECTED' &&
                  '${tender['rejection_reason'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${tender['rejection_reason']}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        _primaryAction(status),

        // ------------------------------------------------------- the brief
        _card(
          title: 'The project',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${tender['title'] ?? ''}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              _row('Type', '${tender['project_type_display'] ?? ''}'),
              _row(
                'Category',
                [
                  tender['category_name'],
                  tender['subcategory_name'],
                ].where((v) => v != null).join(' → '),
              ),
              if (tender['area_sqft'] != null)
                _row('Area', '${tender['area_sqft']} sq ft'),
              _row('Your budget', tenderMoney(tender['expected_budget'])),
              if (tender['preferred_start_date'] != null)
                _row(
                  'Preferred start',
                  tenderDate(tender['preferred_start_date']),
                ),
              if (tender['duration_days'] != null)
                _row('Expected duration', '${tender['duration_days']} days'),
              if (tender['bid_deadline'] != null)
                _row('Bidding closes', tenderDate(tender['bid_deadline'])),
              const SizedBox(height: 12),
              const Text(
                'Description',
                style: TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
              const SizedBox(height: 4),
              Text(
                '${tender['description'] ?? ''}',
                style: const TextStyle(fontSize: 13.5),
              ),
              if ('${tender['requirements'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Requirements',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tender['requirements']}',
                  style: const TextStyle(fontSize: 13.5),
                ),
              ],
            ],
          ),
        ),

        _buildAttachments(tender),
        _buildAwarded(tender),
        _buildMilestones(tender),
        _buildProgress(tender),
        _buildReview(tender),
      ],
    );
  }

  /// The one thing worth doing next, given where the tender has got to.
  Widget _primaryAction(String? status) {
    final tender = _tender!;
    final bidCount = tender['bid_count'] ?? 0;

    final buttons = <Widget>[];

    if (status == 'DRAFT' || status == 'REJECTED') {
      buttons.add(
        _bigButton(
          icon: Icons.campaign_rounded,
          label: status == 'REJECTED' ? 'Publish again' : 'Publish tender',
          onPressed: _publish,
        ),
      );
    }

    if (status == 'OPEN') {
      buttons.add(
        _bigButton(
          icon: Icons.compare_arrows_rounded,
          label: bidCount == 0
              ? 'No bids yet — check back soon'
              : 'Compare $bidCount bid${bidCount == 1 ? '' : 's'}',
          onPressed: bidCount == 0 ? null : _openBids,
        ),
      );
    }

    if (status == 'COMPLETED' && tender['review'] == null) {
      buttons.add(
        _bigButton(
          icon: Icons.star_rounded,
          label: 'Rate your vendor',
          onPressed: _leaveReview,
        ),
      );
    }

    final canCancel =
        status != null &&
        !['COMPLETED', 'CANCELLED', 'IN_PROGRESS'].contains(status);
    if (canCancel) {
      buttons.add(
        TextButton.icon(
          onPressed: _isBusy ? null : _cancel,
          icon: const Icon(Icons.close_rounded, size: 18),
          label: const Text('Cancel this tender'),
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(children: buttons),
    );
  }

  Widget _bigButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isBusy ? null : onPressed,
        icon: _isBusy
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        label: Text(label),
      ),
    );
  }

  Widget _buildAttachments(Map<String, dynamic> tender) {
    final attachments = (tender['attachments'] as List?) ?? const [];
    if (attachments.isEmpty) return const SizedBox.shrink();

    return _card(
      title: 'Drawings & photos',
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: attachments.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final attachment = attachments[index];
            final isImage = attachment['is_image'] == true;
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isImage
                  ? Image.network(
                      '${attachment['file']}',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fileTile(attachment),
                    )
                  : _fileTile(attachment),
            );
          },
        ),
      ),
    );
  }

  Widget _fileTile(dynamic attachment) {
    return Container(
      width: 96,
      height: 96,
      color: AppColors.background,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.insert_drive_file_outlined,
            color: AppColors.textGrey,
          ),
          const SizedBox(height: 6),
          Text(
            '${attachment['filename'] ?? 'File'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildAwarded(Map<String, dynamic> tender) {
    final bid = tender['awarded_bid'];
    if (bid == null) return const SizedBox.shrink();

    final phone = '${bid['vendor_phone'] ?? ''}';

    return _card(
      title: 'Your vendor',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage: bid['vendor_photo'] != null
                    ? NetworkImage('${bid['vendor_photo']}')
                    : null,
                child: bid['vendor_photo'] == null
                    ? const Icon(Icons.person, color: AppColors.primary)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${bid['vendor_name'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '★ ${bid['vendor_rating'] ?? 0} · '
                      '${bid['vendor_experience_years'] ?? 0} yrs experience',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              if (phone.isNotEmpty)
                IconButton(
                  onPressed: () => _call(phone),
                  icon: const Icon(Icons.phone_rounded),
                  color: AppColors.primary,
                  tooltip: 'Call',
                ),
            ],
          ),
          const SizedBox(height: 14),
          _row('Agreed price', tenderMoney(bid['amount'])),
          if (bid['timeline_days'] != null)
            _row('Timeline', '${bid['timeline_days']} days'),
          _row('Payment', _paymentLabel(tender['payment_status'])),
          if ('${bid['work_plan'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Work plan',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
            const SizedBox(height: 4),
            Text('${bid['work_plan']}', style: const TextStyle(fontSize: 13.5)),
          ],
        ],
      ),
    );
  }

  String _paymentLabel(dynamic status) {
    switch (status) {
      case 'PAID':
        return 'Fully paid';
      case 'PARTIAL':
        return 'Partly paid';
      default:
        return 'Nothing paid yet';
    }
  }

  Widget _buildMilestones(Map<String, dynamic> tender) {
    final milestones = (tender['milestones'] as List?) ?? const [];
    if (milestones.isEmpty) return const SizedBox.shrink();

    return _card(
      title: 'Payment plan',
      child: Column(
        children: [
          for (final milestone in milestones)
            _MilestoneRow(
              milestone: Map<String, dynamic>.from(milestone),
              onPay: _isBusy
                  ? null
                  : () => _payMilestone(Map<String, dynamic>.from(milestone)),
            ),
        ],
      ),
    );
  }

  Widget _buildProgress(Map<String, dynamic> tender) {
    final updates = (tender['progress_updates'] as List?) ?? const [];
    if (updates.isEmpty) return const SizedBox.shrink();

    return _card(
      title: 'Progress',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final update in updates) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${update['vendor_name'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                if (update['percent_complete'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${update['percent_complete']}%',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              tenderDateTime(update['created_at']),
              style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
            ),
            const SizedBox(height: 6),
            Text(
              '${update['message'] ?? ''}',
              style: const TextStyle(fontSize: 13.5),
            ),
            if ((update['photos'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: (update['photos'] as List).length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      '${update['photos'][index]['image']}',
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 76,
                        height: 76,
                        color: AppColors.background,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const Divider(height: 26),
          ],
        ],
      ),
    );
  }

  Widget _buildReview(Map<String, dynamic> tender) {
    final review = tender['review'];
    if (review == null) return const SizedBox.shrink();

    return _card(
      title: 'Your review',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= (review['rating'] ?? 0)
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 20,
                  color: Colors.amber.shade600,
                ),
            ],
          ),
          if ('${review['comment'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${review['comment']}',
              style: const TextStyle(fontSize: 13.5),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------- widgets
  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  final Map<String, dynamic> milestone;
  final VoidCallback? onPay;

  const _MilestoneRow({required this.milestone, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final status = '${milestone['status']}';
    final isPaid = status == 'PAID';
    final isReached = status == 'REACHED';

    final color = isPaid
        ? Colors.green.shade700
        : isReached
        ? Colors.orange.shade700
        : AppColors.textGrey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPaid
                ? Icons.check_circle_rounded
                : isReached
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${milestone['title'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  isPaid
                      ? 'Paid'
                      : isReached
                      ? 'Vendor marked this done'
                      : 'Not started',
                  style: TextStyle(fontSize: 11.5, color: color),
                ),
                // Only a stage the vendor has actually claimed done can be
                // settled — that ordering is enforced on the server too.
                if (isReached && onPay != null)
                  TextButton(
                    onPressed: onPay,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Mark as paid'),
                  ),
              ],
            ),
          ),
          Text(
            tenderMoney(milestone['amount']),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
