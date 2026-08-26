import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../theme.dart';
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
import 'pro_vendor_detail_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

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
    _loadProfileName();
    _loadHeaderBanners();
    _loadPromoCards();
    _loadReferralInfo();
    _loadPersonalizedRows();
    _loadSpotlights();
    _loadHomeSections();
    _loadProVendorSections();
    _loadCurations();
    _cart.addListener(_onCartChanged);
    _captureAndSaveLocation();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
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
    final info = await ApiService.getReferralInfo();
    if (mounted) setState(() => _referralInfo = info);
  }

  Future<void> _loadPersonalizedRows() async {
    final recent = await ApiService.getRecentlyViewed();
    final again = await ApiService.getBookAgain();
    if (mounted) {
      setState(() {
        _recentlyViewed = recent;
        _bookAgain = again;
      });
    }
  }

  /// Opens the map picker and saves whatever the customer confirms back
  /// onto their profile, so the hero header stays in sync.
  Future<void> _changeLocation() async {
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
    _loadReferralInfo();
    _loadPersonalizedRows();
    _loadSpotlights();
    _loadHomeSections();
    _loadProVendorSections();
    _loadCurations();
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
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  ),
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
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
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
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _buildHero(context),
              const SizedBox(height: 24),

              // --- Categories ---
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
                        child: Center(child: Text('Error: ${snapshot.error}')),
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
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
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

              // These go edge-to-edge — NO horizontal padding wrapper
              SpotlightSection(spotlights: _spotlights, onTap: _onBannerTap),

              PersonalizedRow(
                title: 'Book again',
                subtitle: 'Services you have booked before',
                services: _bookAgain,
                showTimesBooked: true,
              ),

              PersonalizedRow(
                title: 'Recently viewed',
                services: _recentlyViewed,
              ),

              HomeSectionsWidget(
                sections: _homeSections,
                promoCards: _promoCards,
                onPromoTap: _onBannerTap,
              ),

              ProVendorSectionsWidget(sections: _proVendorSections),

              CurationSectionWidget(sections: _curations),

              // --- Refer & earn, closing out the page ---
              if (_referralInfo != null) ...[
                const SizedBox(height: 8),
                ReferBanner(info: _referralInfo!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
