import '../utils/breakpoints.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/payment_service.dart';
import '../theme.dart';
import '../utils/tender_format.dart';

/// "Compare Bids" — every quote side by side, so the choice is price against
/// rating, experience and timeline rather than price alone.
class TenderBidsScreen extends StatefulWidget {
  final int tenderId;
  final dynamic expectedBudget;

  /// What the platform charges to confirm a choice, as a percentage of the
  /// bid. Shown before they pick, so the fee is never a surprise afterwards.
  final dynamic confirmationFeePercent;

  const TenderBidsScreen({
    super.key,
    required this.tenderId,
    this.expectedBudget,
    this.confirmationFeePercent,
  });

  @override
  State<TenderBidsScreen> createState() => _TenderBidsScreenState();
}

class _TenderBidsScreenState extends State<TenderBidsScreen> {
  List<dynamic> _bids = [];
  bool _isLoading = true;
  bool _isAwarding = false;
  String? _errorMessage;
  String _sort = 'amount';
  final _payer = PaymentService();

  static const _sorts = {
    'amount': 'Lowest price',
    'rating': 'Best rated',
    'timeline': 'Fastest',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _payer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final bids = await ApiService.getTenderBids(widget.tenderId, sort: _sort);
      if (!mounted) return;
      setState(() {
        _bids = bids;
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

  /// The fee this bid would cost to confirm, worked out from the rate the
  /// server sent. Only ever a preview — the amount actually charged is the
  /// one the server puts on the fee when the bid is chosen.
  double? _feeOn(dynamic amount) {
    final percent = double.tryParse('${widget.confirmationFeePercent ?? ''}');
    final value = double.tryParse('${amount ?? ''}');
    if (percent == null || value == null || percent <= 0) return null;
    return value * percent / 100;
  }

  Future<void> _accept(Map<String, dynamic> bid) async {
    final fee = _feeOn(bid['amount']);
    final percent = widget.confirmationFeePercent;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Choose ${bid['vendor_name']}?'),
        content: Text(
          fee == null
              ? 'They will take on this project for '
                    '${tenderMoney(bid['amount'])}.\n\n'
                    'Every other bid is turned down at the same time, and this '
                    'cannot be undone.'
              : 'They will take on this project for '
                    '${tenderMoney(bid['amount'])}.\n\n'
                    'To confirm them you pay a ${_percentLabel(percent)}% '
                    'confirmation fee of ${tenderMoneyExact(fee)} to Make My '
                    'House. Your choice is held until that is paid — nothing is '
                    'awarded and no other bid is turned down before then.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(fee == null ? 'Confirm' : 'Choose & pay'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isAwarding = true);
    Map<String, dynamic> result;
    try {
      result = await ApiService.acceptTenderBid(bid['id']);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAwarding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return;
    }

    if (!mounted) return;

    // No fee to pay: the server has awarded it already, exactly as before.
    if (result['fee'] == null) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${bid['vendor_name']} has the job.')),
      );
      return;
    }

    final outcome = await _payer.payTenderConfirmationFee(
      tenderId: widget.tenderId,
      description: 'Confirming ${bid['vendor_name']}',
    );
    if (!mounted) return;
    setState(() => _isAwarding = false);

    if (outcome.isSuccess) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${bid['vendor_name']} has the job.')),
      );
      return;
    }

    // The choice is held either way, so send them back to the tender where
    // the Pay button is waiting rather than leaving them on a list whose
    // buttons no longer do anything.
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome.needsConfirmation
              ? outcome.message
              : '${outcome.message} ${bid['vendor_name']} is still held for '
                    'you — pay the confirmation fee to lock them in.',
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  /// 10, not 10.00 — the trailing zeros read like precision that isn't there.
  String _percentLabel(dynamic percent) {
    final value = double.tryParse('${percent ?? ''}');
    if (value == null) return '$percent';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Compare bids')),
      body: DesktopCentered(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
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
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : _bids.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.gavel_rounded,
                        size: 52,
                        color: AppColors.textGrey,
                      ),
                      SizedBox(height: 14),
                      Text(
                        'No bids yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Vendors are still looking at your tender. '
                        'We will notify you the moment one quotes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  _buildSummary(),
                  _buildSortBar(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                        itemCount: _bids.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _BidCard(
                          bid: Map<String, dynamic>.from(_bids[index]),
                          isCheapest: _sort == 'amount' && index == 0,
                          isBusy: _isAwarding,
                          onAccept: () =>
                              _accept(Map<String, dynamic>.from(_bids[index])),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// The spread of what has come in, against what the customer budgeted.
  Widget _buildSummary() {
    final amounts =
        _bids
            .map((b) => double.tryParse('${b['amount']}'))
            .whereType<double>()
            .toList()
          ..sort();
    if (amounts.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _stat('Your budget', tenderMoney(widget.expectedBudget)),
          _divider(),
          _stat('Lowest bid', tenderMoney(amounts.first)),
          _divider(),
          _stat('Highest', tenderMoney(amounts.last)),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    ),
  );

  Widget _divider() =>
      Container(width: 1, height: 30, color: AppColors.background);

  Widget _buildSortBar() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final entry in _sorts.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: _sort == entry.key,
                onSelected: (_) {
                  if (_sort == entry.key) return;
                  setState(() => _sort = entry.key);
                  _load();
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _sort == entry.key
                      ? AppColors.primary
                      : AppColors.textGrey,
                ),
                backgroundColor: Colors.white,
                side: BorderSide.none,
              ),
            ),
        ],
      ),
    );
  }
}

class _BidCard extends StatelessWidget {
  final Map<String, dynamic> bid;
  final bool isCheapest;
  final bool isBusy;
  final VoidCallback onAccept;

  const _BidCard({
    required this.bid,
    required this.isCheapest,
    required this.isBusy,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final difference =
        double.tryParse('${bid['difference_from_expected']}') ?? 0;
    final overBudget = difference > 0;
    final milestones = (bid['milestones'] as List?) ?? const [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCheapest
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCheapest) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Lowest bid',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ------------------------------------------------ vendor + price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${bid['vendor_name'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        if (bid['vendor_is_pro'] == true) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if ('${bid['vendor_title'] ?? ''}'.isNotEmpty)
                      Text(
                        '${bid['vendor_title']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    tenderMoney(bid['amount']),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    difference == 0
                        ? 'On budget'
                        : '${overBudget ? '+' : '−'}'
                              '${tenderMoney(difference.abs())}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: overBudget
                          ? Colors.red.shade600
                          : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),
          // -------------------------------------------------- what they bring
          Row(
            children: [
              _chip(
                Icons.star_rounded,
                '${bid['vendor_rating'] ?? 0}',
                '${bid['vendor_review_count'] ?? 0} reviews',
              ),
              _chip(
                Icons.workspace_premium_outlined,
                '${bid['vendor_experience_years'] ?? 0} yrs',
                'experience',
              ),
              _chip(
                Icons.schedule_rounded,
                bid['timeline_days'] == null
                    ? '—'
                    : '${bid['timeline_days']} d',
                'timeline',
              ),
            ],
          ),

          if ('${bid['work_plan'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              '${bid['work_plan']}',
              style: const TextStyle(fontSize: 13, color: AppColors.textDark),
            ),
          ],

          if (milestones.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Payment plan',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
            const SizedBox(height: 6),
            for (final milestone in milestones)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${milestone['title']}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    Text(
                      tenderMoney(milestone['amount']),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],

          if ('${bid['notes'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${bid['notes']}',
              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isBusy ? null : onAccept,
              child: const Text('Choose this vendor'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 17, color: AppColors.textGrey),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}
