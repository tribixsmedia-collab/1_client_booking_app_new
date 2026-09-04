import '../utils/breakpoints.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme.dart';
import '../utils/tender_format.dart';
import 'create_tender_screen.dart';
import 'tender_detail_screen.dart';

/// "My Tenders" — every project the customer has posted for vendors to bid on.
///
/// Split into Active and Closed rather than one long list: a tender the
/// customer still has to act on (publish a draft, compare bids, pay a
/// milestone) should never be buried under finished ones.
class MyTendersScreen extends StatefulWidget {
  const MyTendersScreen({super.key});

  @override
  State<MyTendersScreen> createState() => _MyTendersScreenState();
}

class _MyTendersScreenState extends State<MyTendersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _tenders = [];
  bool _isLoading = true;
  String? _errorMessage;

  static const _closedStatuses = ['COMPLETED', 'CANCELLED'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final tenders = await ApiService.getMyTenders();
      if (!mounted) return;
      setState(() {
        _tenders = tenders;
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

  List<dynamic> get _active =>
      _tenders.where((t) => !_closedStatuses.contains(t['status'])).toList();

  List<dynamic> get _closed =>
      _tenders.where((t) => _closedStatuses.contains(t['status'])).toList();

  Future<void> _openCreate() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CreateTenderScreen()));
    if (created == true) _load();
  }

  Future<void> _openDetail(int tenderId) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TenderDetailScreen(tenderId: tenderId)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Tenders'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textGrey,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: [
            Tab(text: 'Active (${_active.length})'),
            Tab(text: 'Closed (${_closed.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Post a tender'),
      ),
      body: DesktopCentered(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _stateMessage(
                icon: Icons.cloud_off_outlined,
                title: "Couldn't load your tenders",
                message: _errorMessage!,
                action: ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _list(
                    _active,
                    Icons.post_add_rounded,
                    'No tenders yet',
                    'Post what you want built, set your budget, and let '
                        'vendors send you their quotes.',
                  ),
                  _list(
                    _closed,
                    Icons.inventory_2_outlined,
                    'Nothing closed yet',
                    'Completed and cancelled tenders land here.',
                  ),
                ],
              ),
      ),
    );
  }

  Widget _list(
    List<dynamic> tenders,
    IconData icon,
    String title,
    String message,
  ) {
    if (tenders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.18),
            _stateMessage(icon: icon, title: title, message: message),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: tenders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _TenderCard(
          tender: tenders[index],
          onTap: () => _openDetail(tenders[index]['id']),
        ),
      ),
    );
  }

  Widget _stateMessage({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: AppColors.textGrey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.textGrey),
            ),
            if (action != null) ...[const SizedBox(height: 20), action],
          ],
        ),
      ),
    );
  }
}

class _TenderCard extends StatelessWidget {
  final Map<String, dynamic> tender;
  final VoidCallback onTap;

  _TenderCard({required dynamic tender, required this.onTap})
    : tender = Map<String, dynamic>.from(tender);

  @override
  Widget build(BuildContext context) {
    final bidCount = tender['bid_count'] ?? 0;
    final status = tender['status'] as String?;
    final deadlineHint = status == 'OPEN'
        ? tenderDeadlineHint(tender['bid_deadline'])
        : null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${tender['title'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TenderStatusPill(status: status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${tender['code'] ?? ''} · ${tender['category_name'] ?? ''}',
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _fact(
                    Icons.account_balance_wallet_outlined,
                    'Your budget',
                    tenderMoney(tender['expected_budget']),
                  ),
                  // Once awarded the agreed price matters more than the count
                  // of quotes that got there.
                  if (tender['final_amount'] != null)
                    _fact(
                      Icons.handshake_outlined,
                      'Agreed',
                      tenderMoney(tender['final_amount']),
                    )
                  else
                    _fact(
                      Icons.gavel_rounded,
                      'Bids',
                      bidCount == 0 ? 'None yet' : '$bidCount received',
                    ),
                ],
              ),
              if (tender['awarded_vendor_name'] != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 15,
                      color: AppColors.textGrey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${tender['awarded_vendor_name']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              // A choice made but not paid for outranks everything else here:
              // the vendor is held, and nothing happens until the fee lands.
              if (status == 'PENDING_CONFIRMATION') ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_clock_rounded,
                        size: 16,
                        color: Colors.amber.shade800,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your vendor is held — pay the confirmation fee to '
                          'lock them in',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // A tender with quotes waiting is the one thing on this screen
              // worth calling out.
              if (status == 'OPEN' && bidCount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.compare_arrows_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bidCount == 1
                              ? '1 bid waiting — compare and choose'
                              : '$bidCount bids waiting — compare and choose',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (deadlineHint != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.textGrey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      deadlineHint,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _fact(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.textGrey),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
