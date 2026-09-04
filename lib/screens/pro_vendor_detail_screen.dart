import '../models/service_pricing.dart';
import '../utils/breakpoints.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../theme.dart';
import '../utils/image_decode.dart';
import '../utils/profile_gate.dart';
import '../widgets/pro_vendor_card.dart';
import '../widgets/review_list_widget.dart';
import 'service_detail_screen.dart';

/// A Pro Vendor's public profile.
///
/// Reached from the curated home rows, from a banner pointed at a pro, and
/// from the pro row at the bottom of a service page. When it is opened from a
/// service page, [bookServiceId] is set and the bottom bar books *that*
/// service with this pro instead of sending the customer off to browse.
class ProVendorDetailScreen extends StatefulWidget {
  final int vendorId;

  /// What the card already knew, so the page has something to draw while the
  /// full profile loads.
  final Map<String, dynamic>? preview;

  final int? bookServiceId;
  final String? bookServiceName;

  const ProVendorDetailScreen({
    super.key,
    required this.vendorId,
    this.preview,
    this.bookServiceId,
    this.bookServiceName,
  });

  @override
  State<ProVendorDetailScreen> createState() => _ProVendorDetailScreenState();
}

class _ProVendorDetailScreenState extends State<ProVendorDetailScreen> {
  final _cart = CartService();

  Map<String, dynamic>? _vendor;
  Map<String, dynamic>? _reviewData;
  bool _isLoading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _vendor = widget.preview;
    _load();
  }

  Future<void> _load() async {
    final vendor = await ApiService.getProVendorDetail(widget.vendorId);
    if (!mounted) return;

    if (vendor == null) {
      // The admin can un-list a pro at any time; a stale card must not leave
      // the customer staring at a blank page.
      setState(() {
        _isLoading = false;
        _notFound = _vendor == null;
      });
      return;
    }

    setState(() {
      _vendor = vendor;
      _isLoading = false;
    });

    final reviews = await ApiService.getVendorReviews(widget.vendorId);
    if (mounted) setState(() => _reviewData = reviews);
  }

  /// Remembers the pro so the booking created from the cart carries the
  /// request through to the admin.
  Future<void> _bookWithThisPro() async {
    final vendor = _vendor;
    if (vendor == null) return;
    if (!await checkProfileComplete(context)) return;
    if (!mounted) return;

    _cart.setPreferredVendor(
      widget.vendorId,
      vendor['name'] ?? '',
      categoryIds:
          (vendor['category_ids'] as List<dynamic>?)?.cast<int>() ?? const [],
    );

    // Opened from a service page — hand control straight back so the customer
    // carries on where they were.
    if (widget.bookServiceId != null) {
      Navigator.of(context).pop(true);
      return;
    }

    await _openVendorCategory(vendor);
  }

  /// Sends the customer to a service this pro covers, so "book with them"
  /// ends on a service page with the pro already selected in its
  /// "Book with a Pro" row.
  ///
  /// The list comes from the API's `bookable_services`, never from walking the
  /// pro's categories here: a vendor may handle only part of a category, and
  /// only the server knows which part.
  Future<void> _openVendorCategory(Map<String, dynamic> vendor) async {
    final raw = vendor['bookable_services'] as List<dynamic>?;
    if (raw == null) {
      // Only the preview from the card has loaded so far.
      _showSnack('Just a moment...');
      return;
    }

    final services = raw.map((s) => Map<String, dynamic>.from(s)).toList();
    if (services.isEmpty) {
      _showSnack('This pro has no services listed yet.');
      return;
    }
    if (services.length == 1) {
      _openService(services.first);
      return;
    }
    _showServiceSheet(vendor, services);
  }

  void _openService(Map<String, dynamic> service) {
    final subcategoryName = service['subcategory_name'];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServiceDetailScreen(
          pricing: ServicePricing.fromJson(
            service,
            double.tryParse('${service['price']}') ?? 0,
          ),
          serviceId: service['id'],
          name: service['name'],
          description: service['description'] ?? '',
          price: double.tryParse('${service['price']}') ?? 0,
          durationMinutes: service['duration_minutes'],
          imageUrl: service['image'],
          categoryId: service['category'],
          subcategoryId: service['subcategory'],
          categoryName: subcategoryName == null
              ? '${service['category_name']}'
              : '${service['category_name']} - $subcategoryName',
        ),
      ),
    );
  }

  void _showServiceSheet(
    Map<String, dynamic> vendor,
    List<Map<String, dynamic>> services,
  ) {
    final firstName = ((vendor['name'] as String?) ?? '').split(' ').first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'What do you need $firstName for?',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 22),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: services.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final service = services[index];
                    final subcategoryName = service['subcategory_name'];
                    final price =
                        double.tryParse(
                          '${service['price']}',
                        )?.toStringAsFixed(0) ??
                        '${service['price']}';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${service['name']}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        subcategoryName == null
                            ? '${service['category_name']}'
                            : '${service['category_name']} \u00b7 $subcategoryName',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                        ),
                      ),
                      trailing: Text(
                        '\u20b9$price',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _openService(service);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_notFound) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pro Vendor')),
        body: DesktopCentered(
          child: const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'This pro vendor is no longer available.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textGrey),
              ),
            ),
          ),
        ),
      );
    }

    final vendor = _vendor;
    if (vendor == null) {
      return const Scaffold(
        body: DesktopCentered(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      body: DesktopCentered(
        child: CustomScrollView(
          slivers: [
            _buildHeader(vendor),
            SliverToBoxAdapter(child: _buildBody(vendor)),
          ],
        ),
      ),
      bottomNavigationBar: DesktopCentered(
        fillHeight: false,
        child: _buildBookBar(vendor),
      ),
    );
  }

  // ---------- Header ----------

  static const double _bannerHeight = 190;
  static const double _avatarSize = 88;
  static const double _avatarRing = 4;
  static const double _avatarBox = _avatarSize + _avatarRing * 2;

  /// Banner, the strip of page colour under it, and the avatar straddling the
  /// seam between them.
  ///
  /// The avatar has to live in *this* Stack rather than being nudged up out of
  /// the body below: the first sliver of a CustomScrollView paints last, so an
  /// avatar pushed up from the body is drawn underneath this app bar and its
  /// top half disappears behind the banner.
  Widget _buildHeader(Map<String, dynamic> vendor) {
    final banner = vendor['banner'] as String?;
    final name = (vendor['name'] as String?) ?? '';

    return SliverAppBar(
      expandedHeight: _bannerHeight + _avatarBox / 2,
      pinned: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.none,
        background: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _bannerHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (banner != null && banner.isNotEmpty)
                        Image.network(
                          banner,
                          fit: BoxFit.cover,
                          cacheWidth: decodeWidthFor(
                            context,
                            MediaQuery.sizeOf(context).width,
                          ),
                          errorBuilder: (_, __, ___) => _gradientBackdrop(),
                        )
                      else
                        _gradientBackdrop(),

                      // Keeps the back arrow readable over any uploaded image.
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black38, Colors.transparent],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Expanded(child: ColoredBox(color: AppColors.background)),
              ],
            ),

            Positioned(
              left: 20,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(_avatarRing),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: ProVendorAvatar(
                  photoUrl: vendor['photo'] as String?,
                  name: name,
                  size: _avatarSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientBackdrop() => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, AppColors.primaryDark],
      ),
    ),
  );

  // ---------- Body ----------

  Widget _buildBody(Map<String, dynamic> vendor) {
    final name = (vendor['name'] as String?) ?? '';
    final title = (vendor['pro_title'] as String?) ?? '';
    final tagline = (vendor['pro_tagline'] as String?) ?? '';
    final bio = (vendor['pro_bio'] as String?) ?? '';
    final categories = (vendor['categories'] as List<dynamic>?) ?? [];
    final serviceArea = (vendor['service_area'] as String?) ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const ProBadge(fontSize: 11),
            ],
          ),

          if (title.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],

          if (tagline.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              tagline,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textGrey,
                height: 1.4,
              ),
            ),
          ],

          if (serviceArea.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 15,
                  color: AppColors.textGrey,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    serviceArea,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          _buildStats(vendor),

          if (categories.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Works on',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories
                  .map<Widget>(
                    (c) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$c',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],

          if (bio.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'About',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              bio,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: AppColors.textGrey,
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Ratings & Reviews',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),
          _buildReviews(),
        ],
      ),
    );
  }

  Widget _buildStats(Map<String, dynamic> vendor) {
    final rating = ((vendor['average_rating'] as num?) ?? 0).toDouble();
    final reviews = (vendor['total_reviews'] as int?) ?? 0;
    final years = (vendor['experience_years'] as int?) ?? 0;
    final jobs = (vendor['completed_jobs'] as int?) ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _statCell(
            reviews > 0 ? rating.toStringAsFixed(1) : '--',
            reviews > 0
                ? '$reviews review${reviews == 1 ? '' : 's'}'
                : 'No reviews',
          ),
          _divider(),
          _statCell('$years', 'Yr${years == 1 ? '' : 's'} experience'),
          _divider(),
          _statCell('$jobs', 'Jobs done'),
        ],
      ),
    );
  }

  Widget _statCell(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
        ),
      ],
    ),
  );

  Widget _divider() =>
      Container(width: 1, height: 32, color: Colors.grey.shade200);

  Widget _buildReviews() {
    if (_isLoading && _reviewData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = _reviewData;
    final total = (data?['total_reviews'] as int?) ?? 0;

    if (data == null || total == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No reviews yet for this pro.',
            style: TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
        ),
      );
    }

    return ReviewListWidget(
      averageRating: ((data['average_rating'] as num?) ?? 0).toDouble(),
      totalReviews: total,
      ratingBreakdown: data['rating_breakdown'] as Map<String, dynamic>?,
      reviews: (data['reviews'] as List<dynamic>?) ?? [],
    );
  }

  // ---------- Book bar ----------

  Widget _buildBookBar(Map<String, dynamic> vendor) {
    final firstName = ((vendor['name'] as String?) ?? '').split(' ').first;
    final label = widget.bookServiceName != null
        ? 'Book ${widget.bookServiceName} with $firstName'
        : 'Book a service with $firstName';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _bookWithThisPro,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
