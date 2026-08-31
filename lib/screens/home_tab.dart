import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../theme.dart';
import '../widgets/tender_promo_card.dart';
import '../widgets/header_carousel.dart';
import '../widgets/spotlight_section.dart';
import '../widgets/category_grid.dart';
import 'service_list_screen.dart';
import 'cart_screen.dart';
import '../widgets/home_sections_widget.dart';
import '../widgets/curation_section_widget.dart';
import 'search_screen.dart';
import '../utils/profile_gate.dart';
import '../utils/location_update.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/gps_prompt_sheet.dart';
import '../widgets/notification_bell.dart';
import '../widgets/refer_banner.dart';
import '../widgets/personalized_row.dart';
import '../widgets/pro_vendor_sections_widget.dart';
import '../utils/breakpoints.dart';
import '../widgets/web_footer.dart';
import '../services/branding_service.dart';
import '../widgets/app_logo.dart';
import 'pro_vendor_detail_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, this.onOpenBookings});

  /// Bookings is a sibling tab rather than a route, so the footer asks the
  /// navigation shell to switch to it.
  final VoidCallback? onOpenBookings;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<List<dynamic>> _categoriesFuture;
  List<dynamic> _allCategories = [];

  List<dynamic> _spotlights = [];
  List<dynamic> _homeSections = [];
  List<dynamic> _curations = [];
  List<dynamic> _headerBanners = [];
  List<dynamic> _promoCards = [];
  List<dynamic> _proVendorSections = [];
  Map<String, dynamic>? _referralInfo;
  List<dynamic> _recentlyViewed = [];
  List<dynamic> _bookAgain = [];
  String? _customerFirstName;
  String? _customerAddress;
  final _cart = CartService();

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _loadCategories();
    _categoriesFuture.catchError((Object _) => <dynamic>[]).ignore();
    _loadHeaderBanners();
    _loadPromoCards();
    _loadSpotlights();
    _loadHomeSections();
    _loadProVendorSections();
    _loadCurations();
    _loadSignedInExtras();
    _cart.addListener(_onCartChanged);
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  /// The parts of this page that belong to a specific customer: their name and
  /// saved address, their referral code, and the rows built from their own
  /// history.
  ///
  /// A guest has none of those and the endpoints behind them are all
  /// customer-only, so asking would just be four 401s. Everything they feed
  /// already renders as nothing when it is empty — the greeting falls back to
  /// "Welcome", and [PersonalizedRow] draws no heading for an empty list — so
  /// skipping them leaves a clean catalogue rather than a broken page.
  Future<void> _loadSignedInExtras() async {
    if (!await ApiService.isLoggedIn()) return;
    _loadProfileName();
    _loadReferralInfo();
    _loadPersonalizedRows();
    _captureAndSaveLocation();
  }

  Future<void> _loadCurations() async {
    try {
      final data = await ApiService.getCurations();
      if (mounted) setState(() => _curations = data);
    } catch (_) {}
  }

  Future<void> _loadHomeSections() async {
    try {
      final data = await ApiService.getHomeSections();
      if (mounted) setState(() => _homeSections = data);
    } catch (_) {}
  }

  Future<void> _loadProVendorSections() async {
    try {
      final data = await ApiService.getProVendorSections();
      if (mounted) setState(() => _proVendorSections = data);
    } catch (_) {}
  }

  Future<List<dynamic>> _loadCategories() async {
    final categories = await ApiService.getServiceCategories();
    setState(() {
      _allCategories = categories;
    });
    return categories;
  }

  Future<void> _loadProfileName() async {
    try {
      final profile = await ApiService.getMyProfile();
      if (mounted) {
        setState(() {
          _customerFirstName = profile['first_name'];
          _customerAddress = profile['address'];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadHeaderBanners() async {
    try {
      final data = await ApiService.getHeaderBanners();
      if (mounted) setState(() => _headerBanners = data);
    } catch (_) {}
  }

  Future<void> _loadPromoCards() async {
    try {
      final data = await ApiService.getPromoCards();
      if (mounted) setState(() => _promoCards = data);
    } catch (_) {}
  }

  Future<void> _loadReferralInfo() async {
    try {
      final info = await ApiService.getReferralInfo();
      if (mounted) setState(() => _referralInfo = info);
    } catch (_) {}
  }

  Future<void> _loadPersonalizedRows() async {
    try {
      final recent = await ApiService.getRecentlyViewed();
      final again = await ApiService.getBookAgain();
      if (mounted) {
        setState(() {
          _recentlyViewed = recent;
          _bookAgain = again;
        });
      }
    } catch (_) {}
  }

  /// Opens the map picker and saves whatever the customer confirms back
  /// onto their profile, so the hero header stays in sync.
  Future<void> _changeLocation() async {
    if (!await requireSignIn(context)) return;
    if (!mounted) return;
    final newAddress = await pickAndSaveLocation(context);
    if (newAddress != null && mounted) {
      setState(() => _customerAddress = newAddress);
    }
  }

  Future<void> _captureAndSaveLocation() async {
    try {
      // Check if GPS is on
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) await GpsPromptSheet.show(context);
        // Check again after user comes back
        if (!await Geolocator.isLocationServiceEnabled()) return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Always update — fetch profile and save latest coordinates
      final profile = await ApiService.getMyProfile();
      await ApiService.updateMyProfile(
        firstName: profile['first_name'] ?? '',
        lastName: profile['last_name'] ?? '',
        phoneNumber: profile['phone_number'] ?? '',
        address: profile['address'] ?? '',
        email: profile['email'] ?? '',
        state: profile['state'] ?? '',
        district: profile['district'] ?? '',
        pincode: profile['pincode'] ?? '',
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      // Non-critical — silently fail
    }
  }

  Future<void> _loadSpotlights() async {
    try {
      final data = await ApiService.getSpotlights();
      if (mounted) setState(() => _spotlights = data);
    } catch (_) {}
  }

  Future<void> _refresh() async {
    setState(() {
      _categoriesFuture = _loadCategories();
    });
    _loadHeaderBanners();
    _loadPromoCards();
    _loadSpotlights();
    _loadHomeSections();
    _loadProVendorSections();
    _loadCurations();
    _loadSignedInExtras();
  }

  Future<void> _onCategoryTap(Map<String, dynamic> cat) async {
    if (!await checkProfileComplete(context)) return;

    if (!mounted) return;

    final subcategories = (cat['subcategories'] as List<dynamic>?) ?? [];
    final directServices = (cat['services'] as List<dynamic>?) ?? [];

    if (subcategories.isEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ServiceListScreen(
            categoryId: cat['id'],
            title: cat['name'],
            services: directServices,
          ),
        ),
      );
    } else {
      _showSubcategorySheet(cat, subcategories);
    }
  }

  /// Shared by the hero carousel and the spotlight cards — both carry
  /// `category` / `subcategory` ids pointing at where the tap should land.
  Future<void> _onBannerTap(Map<String, dynamic> banner) async {
    // A pro vendor target wins over the category one — that is the promise
    // the dashboard makes on the banner forms.
    final proVendorId = banner['pro_vendor'];
    if (proVendorId != null) {
      if (!await checkProfileComplete(context)) return;
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProVendorDetailScreen(vendorId: proVendorId as int),
        ),
      );
      return;
    }

    final categoryId = banner['category'];
    final subcategoryId = banner['subcategory'];
    if (categoryId == null) return;

    if (!await checkProfileComplete(context)) return;

    if (!mounted) return;

    final cat = _allCategories.firstWhere(
      (c) => c['id'] == categoryId,
      orElse: () => null,
    );
    if (cat == null) return;

    if (subcategoryId != null) {
      final subcategories = (cat['subcategories'] as List<dynamic>?) ?? [];
      final sub = subcategories.firstWhere(
        (s) => s['id'] == subcategoryId,
        orElse: () => null,
      );
      if (sub != null) {
        final subServices = (sub['services'] as List<dynamic>?) ?? [];
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ServiceListScreen(
              categoryId: categoryId,
              subcategoryId: subcategoryId,
              title: '${cat['name']} - ${sub['name']}',
              services: subServices,
            ),
          ),
        );
        return;
      }
    }

    _onCategoryTap(Map<String, dynamic>.from(cat));
  }

  void _showAllServices() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'All Services',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 24),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: _allCategories.length,
                  itemBuilder: (context, index) {
                    final cat = _allCategories[index];
                    final subcategories =
                        (cat['subcategories'] as List<dynamic>?) ?? [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category title
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 12),
                          child: Text(
                            cat['name'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // Subcategories as icon grid, or single category tap
                        if (subcategories.isEmpty)
                          // No subcategories — show as single tappable item
                          GestureDetector(
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _onCategoryTap(Map<String, dynamic>.from(cat));
                            },
                            child: Container(
                              width: 90,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                children: [
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child:
                                          cat['icon'] != null &&
                                              (cat['icon'] as String).isNotEmpty
                                          ? Image.network(
                                              cat['icon'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                    Icons.build,
                                                    color: AppColors.primary,
                                                  ),
                                            )
                                          : const Icon(
                                              Icons.build,
                                              color: AppColors.primary,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    cat['name'],
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          // Subcategories grid
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: subcategories.map((sub) {
                              return GestureDetector(
                                onTap: () {
                                  Navigator.of(sheetContext).pop();
                                  final subServices =
                                      (sub['services'] as List<dynamic>?) ?? [];
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ServiceListScreen(
                                        categoryId: cat['id'],
                                        subcategoryId: sub['id'],
                                        title:
                                            '${cat['name']} - ${sub['name']}',
                                        services: subServices,
                                      ),
                                    ),
                                  );
                                },
                                child: SizedBox(
                                  width: 90,
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 70,
                                        height: 70,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          child:
                                              sub['icon'] != null &&
                                                  (sub['icon'] as String)
                                                      .isNotEmpty
                                              ? Image.network(
                                                  sub['icon'],
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(
                                                        Icons.build,
                                                        color:
                                                            AppColors.primary,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.build,
                                                  color: AppColors.primary,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        sub['name'],
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                        // Divider between categories
                        if (index < _allCategories.length - 1)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Divider(),
                          ),
                      ],
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

  void _showSubcategorySheet(
    Map<String, dynamic> cat,
    List<dynamic> subcategories,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        cat['name'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 24),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 20,
                    children: subcategories.map((sub) {
                      return SubcategoryItem(
                        name: sub['name'],
                        iconUrl: sub['icon'],
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          final subServices =
                              (sub['services'] as List<dynamic>?) ?? [];
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ServiceListScreen(
                                categoryId: cat['id'],
                                subcategoryId: sub['id'],
                                title: '${cat['name']} - ${sub['name']}',
                                services: subServices,
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  /// Coloured hero at the top of the home screen: greeting + saved address,
  /// the search entry point, and the admin-managed promo carousel.
  // ----------------------------------------------------------- desktop hero
  /// Two columns: what you can book on the left, the running promotions as a
  /// mosaic on the right. Only used above [kDesktopBreakpoint] — the phone
  /// keeps [_buildHero].
  Widget _buildDesktopHero(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kDesktopContentWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _desktopHeroLeft(context)),
                const SizedBox(width: 48),
                Expanded(flex: 6, child: _desktopHeroMosaic(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopHeroLeft(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BrandingBuilder(
          builder: (context) => Text(
            BrandingService.tagline?.isNotEmpty == true
                ? BrandingService.tagline!
                : 'Services at your doorstep',
            style: const TextStyle(
              fontSize: 36,
              height: 1.22,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ),
        const SizedBox(height: 26),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'What do you need done?',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const Spacer(),
                  if (_allCategories.length > 6)
                    TextButton(
                      onPressed: _showAllServices,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'See all',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (_allCategories.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 14,
                    // A fixed row height rather than an aspect ratio: the tile
                    // is a 70px icon plus up to two lines of label whatever
                    // the window is doing, so a ratio either leaves dead space
                    // at 1440px or clips the label at the 900px breakpoint.
                    mainAxisExtent: 118,
                  ),
                  itemCount: _allCategories.length < 6
                      ? _allCategories.length
                      : 6,
                  itemBuilder: (context, index) {
                    final cat = _allCategories[index];
                    return CategoryCard(
                      name: cat['name'],
                      iconUrl: cat['icon'],
                      onTap: () =>
                          _onCategoryTap(Map<String, dynamic>.from(cat)),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _desktopHeroMosaic(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _desktopHeroBanners(context),
        const SizedBox(height: 16),
        // Sits under the carousel rather than across the full page: it is a
        // side entrance to a different flow, not a headline.
        const TenderPromoCard(padding: EdgeInsets.zero),
      ],
    );
  }

  Widget _desktopHeroBanners(BuildContext context) {
    final withImages = _headerBanners
        .whereType<Map>()
        .where((b) => (b['image'] as String?)?.isNotEmpty == true)
        .toList();

    // Three promotions or fewer is not a mosaic - fall back to the same
    // carousel the phone uses rather than leaving holes in the grid.
    if (withImages.length < 4) {
      return HeaderCarousel(banners: _headerBanners, onTap: _onBannerTap);
    }

    Widget tile(Map banner, double height) {
      return GestureDetector(
        onTap: () => _onBannerTap(Map<String, dynamic>.from(banner)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Image.network(
              banner['image'] as String,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: AppColors.background),
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              tile(withImages[0], 178),
              const SizedBox(height: 14),
              tile(withImages[1], 236),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: [
              tile(withImages[2], 236),
              const SizedBox(height: 14),
              tile(withImages[3], 178),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        0,
        MediaQuery.of(context).padding.top + 14,
        0,
        _headerBanners.isEmpty ? 22 : 18,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Greeting + location + actions ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _changeLocation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _customerFirstName != null &&
                                  _customerFirstName!.isNotEmpty
                              ? 'Hi, $_customerFirstName 👋'
                              : 'Welcome 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _customerAddress != null &&
                                        _customerAddress!.isNotEmpty
                                    ? _customerAddress!
                                    : 'Set your location',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 18,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                NotificationBell(
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  iconColor: Colors.white,
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const CartScreen())),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        child: const Icon(
                          Icons.shopping_cart_outlined,
                          color: Colors.white,
                        ),
                      ),
                      if (_cart.totalItems > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              '${_cart.totalItems}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- Search ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: AppColors.textGrey),
                    SizedBox(width: 12),
                    Text(
                      'Search for a service (e.g. Plumbing)',
                      style: TextStyle(color: AppColors.textGrey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- Admin-managed promo carousel ---
          if (_headerBanners.isNotEmpty) ...[
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: HeaderCarousel(
                banners: _headerBanners,
                onTap: _onBannerTap,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopLayout(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: EdgeInsets.only(bottom: desktop ? 0 : 24),
            children: [
              desktop ? _buildDesktopHero(context) : _buildHero(context),
              SizedBox(height: desktop ? 8 : 24),

              if (!desktop) ...[
                const TenderPromoCard(),
                const SizedBox(height: 24),
              ],

              // --- Categories ---
              // On desktop these already sit inside the hero card, so the
              // standalone section would just repeat them.
              if (!desktop) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'All Services',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FutureBuilder<List<dynamic>>(
                    future: _categoriesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Center(
                            child: Text('Error: ${snapshot.error}'),
                          ),
                        );
                      }
                      if (_allCategories.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(
                            child: Text('No matching services found.'),
                          ),
                        );
                      }
                      // Phones keep the four columns they always had. Only a
                      // window wider than a phone gets more of them, so the
                      // tiles stay tile-sized instead of stretching to a
                      // quarter of a 1920px monitor each.
                      final gridWidth = MediaQuery.sizeOf(context).width;
                      final columns = gridWidth < 600
                          ? 4
                          : (gridWidth / 130).floor().clamp(4, 12);
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.60,
                        ),
                        itemCount: _allCategories.length <= 7
                            ? _allCategories.length
                            : 8,
                        itemBuilder: (context, index) {
                          if (_allCategories.length > 7 && index == 7) {
                            return MoreCard(
                              remainingCount: _allCategories.length - 7,
                              onTap: _showAllServices,
                            );
                          }
                          final cat = _allCategories[index];
                          return CategoryCard(
                            name: cat['name'],
                            // price: cat['base_price'],
                            iconUrl: cat['icon'],
                            onTap: () =>
                                _onCategoryTap(Map<String, dynamic>.from(cat)),
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),
              ],

              // Edge-to-edge on a phone; centred in the content column on a
              // monitor so the rows stay under their own headings.
              DesktopCentered(
                child: SpotlightSection(
                  spotlights: _spotlights,
                  onTap: _onBannerTap,
                ),
              ),

              DesktopCentered(
                child: PersonalizedRow(
                  title: 'Book again',
                  subtitle: 'Services you have booked before',
                  services: _bookAgain,
                  showTimesBooked: true,
                ),
              ),

              DesktopCentered(
                child: PersonalizedRow(
                  title: 'Recently viewed',
                  services: _recentlyViewed,
                ),
              ),

              DesktopCentered(
                child: HomeSectionsWidget(
                  sections: _homeSections,
                  promoCards: _promoCards,
                  onPromoTap: _onBannerTap,
                ),
              ),

              DesktopCentered(
                child: ProVendorSectionsWidget(sections: _proVendorSections),
              ),

              DesktopCentered(
                child: CurationSectionWidget(sections: _curations),
              ),

              // --- Refer & earn, closing out the page ---
              if (_referralInfo != null) ...[
                const SizedBox(height: 8),
                DesktopCentered(child: ReferBanner(info: _referralInfo!)),
              ],

              if (desktop) ...[
                const SizedBox(height: 48),
                WebFooter(onOpenBookings: widget.onOpenBookings ?? () {}),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
