import '../utils/breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../theme.dart';

/// Refer & Earn. Every string here comes from the dashboard
/// (Refer & Earn -> Programme Settings), with the reward amounts already
/// substituted in by the backend.
class ReferEarnScreen extends StatefulWidget {
  /// Passed in when the caller already loaded it, so the screen opens
  /// without a spinner.
  final Map<String, dynamic>? info;

  const ReferEarnScreen({super.key, this.info});

  @override
  State<ReferEarnScreen> createState() => _ReferEarnScreenState();
}

class _ReferEarnScreenState extends State<ReferEarnScreen> {
  Map<String, dynamic>? _info;
  List<dynamic> _referrals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _info = widget.info;
    _isLoading = _info == null;
    _load();
  }

  Future<void> _load() async {
    final info = await ApiService.getReferralInfo();
    final referrals = await ApiService.getMyReferrals();
    if (!mounted) return;
    setState(() {
      if (info != null) _info = info;
      _referrals = referrals;
      _isLoading = false;
    });
  }

  String get _code => (_info?['code'] as String?) ?? '';
  String get _shareMessage => (_info?['share_message'] as String?) ?? '';

  Future<void> _shareOnWhatsApp() async {
    final uri = Uri.parse(
      'whatsapp://send?text=${Uri.encodeComponent(_shareMessage)}',
    );
    // Throws rather than returning false when WhatsApp is missing, so fall
    // back to the system share sheet instead of leaving the tap dead.
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) return;
    } catch (_) {}
    await _shareViaOther();
  }

  Future<void> _shareViaOther() async {
    // The system share sheet, so any messaging app the customer has works.
    await SharePlus.instance.share(ShareParams(text: _shareMessage));
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$label copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Refer & Earn')),
      body: DesktopCentered(
        maxWidth: kDesktopFormWidth,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _info == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Referrals are not available right now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: EdgeInsets.zero,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _buildHero(),
                    const SizedBox(height: 20),
                    _buildCodeCard(),
                    const SizedBox(height: 20),
                    _buildHowItWorks(),
                    if ((_info!['terms'] as String?)?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 20),
                      _buildTerms(),
                    ],
                    const SizedBox(height: 20),
                    _buildEarnings(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  // ---------- Hero: headline, description, share buttons ----------

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.10),
            AppColors.primary.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _info!['screen_title'] ?? '',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _info!['screen_description'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textGrey,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Text('🎁', style: TextStyle(fontSize: 52)),
            ],
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Refer via',
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShareButton(
                icon: Icons.chat,
                color: const Color(0xFF25D366),
                label: 'WhatsApp',
                onTap: _shareOnWhatsApp,
              ),
              _ShareButton(
                icon: Icons.ios_share,
                color: AppColors.primary,
                label: 'More',
                onTap: _shareViaOther,
              ),
              _ShareButton(
                icon: Icons.link,
                color: const Color(0xFF2563EB),
                label: 'Copy',
                onTap: () => _copy(_shareMessage, 'Invite message'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- The code itself ----------

  Widget _buildCodeCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your referral code',
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _code,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.5,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _copy(_code, 'Code'),
              icon: const Icon(Icons.copy, size: 17),
              label: const Text('Copy'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- How it works ----------

  Widget _buildHowItWorks() {
    final steps = (_info!['steps'] as List<dynamic>?) ?? [];
    if (steps.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How it works?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < steps.length; i++)
              _StepRow(
                number: i + 1,
                text: '${steps[i]}',
                isLast: i == steps.length - 1,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerms() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Terms and conditions',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            _info!['terms'] ?? '',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textGrey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Earnings so far ----------

  Widget _buildEarnings() {
    final invited = _info!['total_invited'] ?? 0;
    final earnedCount = _info!['total_earned_count'] ?? 0;
    final earnedAmount = _info!['total_earned_amount'] ?? '0';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            invited == 0
                ? 'You are yet to refer anyone'
                : 'You have earned ₹$earnedAmount',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            invited == 0
                ? 'Start referring to get rewarded'
                : '$invited friend${invited == 1 ? '' : 's'} invited · '
                      '$earnedCount reward${earnedCount == 1 ? '' : 's'} earned',
            style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),

          if (_referrals.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final referral in _referrals)
              _ReferralRow(referral: Map<String, dynamic>.from(referral)),
          ],
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ShareButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white,
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textDark),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int number;
  final String text;
  final bool isLast;

  const _StepRow({
    required this.number,
    required this.text,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 1.5, color: Colors.white)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18, top: 4),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14.5,
                  color: AppColors.textDark,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralRow extends StatelessWidget {
  final Map<String, dynamic> referral;

  const _ReferralRow({required this.referral});

  @override
  Widget build(BuildContext context) {
    final status = referral['status'] as String? ?? 'PENDING';
    final isPending = status == 'PENDING';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: const Icon(Icons.person, size: 17, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              referral['friend_name'] ?? 'A friend',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isPending
                  ? Colors.grey.shade100
                  : Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isPending
                  ? 'Yet to book'
                  : '₹${referral['reward_amount'] ?? 0} earned',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isPending ? AppColors.textGrey : Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
