import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/pro_vendor_card.dart';
import 'pro_vendor_detail_screen.dart';

/// Every pro in one curated section — the "See all" behind a home row.
class ProVendorSeeAllScreen extends StatefulWidget {
  final int sectionId;
  final String title;
  final String subtitle;

  const ProVendorSeeAllScreen({
    super.key,
    required this.sectionId,
    required this.title,
    required this.subtitle,
  });

  @override
  State<ProVendorSeeAllScreen> createState() => _ProVendorSeeAllScreenState();
}

class _ProVendorSeeAllScreenState extends State<ProVendorSeeAllScreen> {
  List<dynamic> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getProVendorSectionFull(widget.sectionId);
      if (mounted) {
        setState(() {
          _items = (data['items'] as List<dynamic>?) ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openVendor(Map<String, dynamic> vendor) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProVendorDetailScreen(
          vendorId: vendor['id'] as int,
          preview: vendor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            if (widget.subtitle.isNotEmpty)
              Text(
                widget.subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(
              child: Text(
                'No pro vendors here right now.',
                style: TextStyle(color: AppColors.textGrey),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final vendor = Map<String, dynamic>.from(_items[index]);
                return ProVendorListTile(
                  vendor: vendor,
                  onTap: () => _openVendor(vendor),
                );
              },
            ),
    );
  }
}
