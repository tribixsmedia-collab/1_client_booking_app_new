import '../utils/breakpoints.dart';
import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/sign_in_prompt.dart';
import '../utils/location_update.dart';
import '../widgets/refer_banner.dart';
import 'phone_entry_screen.dart';
import 'complete_profile_screen.dart';
import 'notification_screen.dart';
import 'cart_screen.dart';
import 'my_tenders_screen.dart';
import 'support_screen.dart';

class ProfileTab extends StatefulWidget {
  /// Lets the profile page hand the customer over to the Bookings tab
  /// instead of stacking a second copy of it on the navigator.
  final VoidCallback? onOpenBookings;

  const ProfileTab({super.key, this.onOpenBookings});

  @override
  State<ProfileTab> createState() => ProfileTabState();
}

class ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _referralInfo;
  bool _isLoading = true;
  String? _errorMessage;

  /// Assumed true so the installed apps behave exactly as before; only guest
  /// browsing on the web can flip it.
  bool _signedIn = true;

  @override
  void initState() {
    super.initState();
    loadProfile();
    _loadReferralInfo();
  }

  Future<void> _loadReferralInfo() async {
    // Referral codes belong to an account; a guest has none.
    if (kGuestBrowsing && !await ApiService.isLoggedIn()) return;
    try {
      final info = await ApiService.getReferralInfo();
      if (mounted) setState(() => _referralInfo = info);
    } catch (_) {}
  }

  Future<void> loadProfile() async {
    final signedIn = !kGuestBrowsing || await ApiService.isLoggedIn();
    if (!mounted) return;
    if (!signedIn) {
      setState(() {
        _signedIn = false;
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _signedIn = true;
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final profile = await ApiService.getMyProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _fullName {
    final first = (_profile?['first_name'] as String?) ?? '';
    final last = (_profile?['last_name'] as String?) ?? '';
    final name = '$first $last'.trim();
    return name.isEmpty ? 'Customer' : name;
  }

  bool get _isProfileComplete => _profile?['is_profile_complete'] == true;

  Future<void> _openProfileForm({required bool isEditing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CompleteProfileScreen(isEditing: isEditing),
      ),
    );
    if (saved == true) loadProfile();
  }

  Future<void> _changeLocation() async {
    final newAddress = await pickAndSaveLocation(context);
    if (newAddress != null) loadProfile();
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 12),
            Text('Log Out'),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ApiService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PhoneEntryScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F3),
      body: DesktopCentered(
        maxWidth: kDesktopFormWidth,
        child: !_signedIn
            ? SignInPrompt(
                icon: Icons.person_outline_rounded,
                title: 'Your account',
                message:
                    'Sign in to manage your details, addresses and referrals.',
                onSignedIn: () {
                  loadProfile();
                  _loadReferralInfo();
                },
              )
            : _isLoading && _profile == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([loadProfile(), _loadReferralInfo()]);
                },
                child: ListView(
                  padding: EdgeInsets.zero,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 10),
                    _buildMenu(),

                    // --- Refer & earn, just above logout ---
                    if (_referralInfo != null) ...[
                      const SizedBox(height: 18),
                      ReferCard(info: _referralInfo!),
                      const SizedBox(height: 18),
                    ] else
                      const SizedBox(height: 10),

                    _buildLogout(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  // ---------- Header: status chip, name, phone, quick tiles ----------

  Widget _buildHeader(BuildContext context) {
    final phone = (_profile?['phone_number'] as String?) ?? '';

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 20,
        20,
        22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null) ...[
            _buildError(),
            const SizedBox(height: 16),
          ],

          if (!_isProfileComplete && _profile != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 17),
                      SizedBox(width: 7),
                      Text(
                        'Incomplete profile',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => _openProfileForm(isEditing: false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Complete',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          Text(
            _fullName,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              phone,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
          ],

          const SizedBox(height: 22),

          // Quick action tiles
          Row(
            children: [
              Expanded(
                child: _QuickTile(
                  icon: Icons.assignment_outlined,
                  label: 'My\nbookings',
                  onTap: () => widget.onOpenBookings?.call(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickTile(
                  icon: Icons.shopping_bag_outlined,
                  label: 'My\ncart',
                  onTap: () => _open(const CartScreen()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickTile(
                  icon: Icons.headset_mic_outlined,
                  label: 'Help &\nsupport',
                  onTap: () => _open(const SupportScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
          TextButton(onPressed: loadProfile, child: const Text('Retry')),
        ],
      ),
    );
  }

  // ---------- Menu rows ----------

  Widget _buildMenu() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          _MenuRow(
            icon: Icons.person_outline,
            label: 'Edit profile',
            onTap: () => _openProfileForm(isEditing: true),
          ),
          _MenuRow(
            icon: Icons.location_on_outlined,
            label: 'Manage address',
            onTap: _changeLocation,
          ),
          _MenuRow(
            icon: Icons.gavel_rounded,
            label: 'My tenders',
            onTap: () => _open(const MyTendersScreen()),
          ),
          _MenuRow(
            icon: Icons.notifications_none_rounded,
            label: 'Notifications',
            onTap: () => _open(const NotificationScreen()),
          ),
          _MenuRow(
            icon: Icons.headset_mic_outlined,
            label: 'Help & support',
            onTap: () => _open(const SupportScreen()),
          ),
        ],
      ),
    );
  }

  Widget _buildLogout() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: _MenuRow(
        icon: Icons.logout,
        label: 'Log out',
        color: Colors.red,
        showChevron: false,
        onTap: _confirmLogout,
      ),
    );
  }
}

/// One of the bordered shortcut squares under the customer's name.
class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 132,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26, color: AppColors.textDark),
            const Spacer(),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single row in the account list: icon, label, chevron.
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool showChevron;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.textDark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 23, color: tint),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: tint,
                ),
              ),
            ),
            if (showChevron)
              Icon(Icons.chevron_right, color: Colors.grey.shade500, size: 22),
          ],
        ),
      ),
    );
  }
}
