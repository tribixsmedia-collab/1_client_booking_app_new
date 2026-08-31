import '../utils/breakpoints.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../theme.dart';
import 'service_list_screen.dart';
import 'service_detail_screen.dart';
import 'service_form_screen.dart';
import '../utils/profile_gate.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _cart = CartService();
  List<dynamic> _allCategories = [];
  List<dynamic> _allServices = [];
  List<dynamic> _filteredCategories = [];
  List<dynamic> _filteredServices = [];
  List<dynamic> _allSubcategories = [];
  List<dynamic> _filteredSubcategories = [];
  bool _isLoading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
    _loadData();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _onServiceAddTap(Map<String, dynamic> svc) async {
    // Profile-completion gate
    if (!await checkProfileComplete(context)) return;

    final svcId = svc['id'] as int;
    final name = svc['name'] as String;
    final price = double.tryParse('${svc['price']}') ?? 0;
    final categoryId = svc['_category_id'] as int;
    final subcategoryId = svc['_subcategory_id'];
    final categoryName = svc['_category_name'] as String? ?? '';

    try {
      List<dynamic> forms = await ApiService.getFormByService(serviceId: svcId);
      if (forms.isEmpty && subcategoryId != null) {
        forms = await ApiService.getFormByService(subcategoryId: subcategoryId);
      }
      if (forms.isEmpty) {
        forms = await ApiService.getFormByService(categoryId: categoryId);
      }

      if (forms.isNotEmpty && mounted) {
        final result = await Navigator.of(context)
            .push<List<Map<String, dynamic>>>(
              MaterialPageRoute(
                builder: (_) => ServiceFormScreen(
                  form: Map<String, dynamic>.from(forms.first),
                  categoryName: categoryName,
                  returnDataOnly: true,
                ),
              ),
            );
        if (result == null) return;

        _cart.setCategoryInfo(
          categoryId: categoryId,
          subcategoryId: subcategoryId,
          categoryName: categoryName,
        );
        _cart.addItem(
          serviceId: svcId,
          name: name,
          price: price,
          formId: forms.first['id'],
          formData: result,
        );
        return;
      }
    } catch (_) {}

    _cart.setCategoryInfo(
      categoryId: categoryId,
      subcategoryId: subcategoryId,
      categoryName: categoryName,
    );
    _cart.addItem(serviceId: svcId, name: name, price: price);
  }

  Future<void> _loadData() async {
    try {
      final categories = await ApiService.getServiceCategories();
      final services = <dynamic>[];

      // Extract all services from categories and subcategories
      for (final cat in categories) {
        final directServices = (cat['services'] as List<dynamic>?) ?? [];
        for (final svc in directServices) {
          svc['_category_id'] = cat['id'];
          svc['_category_name'] = cat['name'];
          svc['_subcategory_id'] = null;
          services.add(svc);
        }

        final subcategories = (cat['subcategories'] as List<dynamic>?) ?? [];
        for (final sub in subcategories) {
          final subServices = (sub['services'] as List<dynamic>?) ?? [];
          for (final svc in subServices) {
            svc['_category_id'] = cat['id'];
            svc['_category_name'] = '${cat['name']} - ${sub['name']}';
            svc['_subcategory_id'] = sub['id'];
            services.add(svc);
          }
        }
      }

      final subcategories = <dynamic>[];
      for (final cat in categories) {
        final subs = (cat['subcategories'] as List<dynamic>?) ?? [];
        for (final sub in subs) {
          sub['_category_id'] = cat['id'];
          sub['_category_name'] = cat['name'];
          subcategories.add(sub);
        }
      }

      if (mounted) {
        setState(() {
          _allCategories = categories;
          _allSubcategories = subcategories;
          _allServices = services;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _query = query.toLowerCase().trim();

      if (_query.isEmpty) {
        _filteredCategories = [];
        _filteredSubcategories = [];
        _filteredServices = [];
        return;
      }

      _filteredCategories = _allCategories
          .where((c) => (c['name'] as String).toLowerCase().contains(_query))
          .toList();

      _filteredServices = _allServices
          .where(
            (s) =>
                (s['name'] as String).toLowerCase().contains(_query) ||
                ((s['description'] ?? '') as String).toLowerCase().contains(
                  _query,
                ),
          )
          .toList();
      _filteredSubcategories = _allSubcategories
          .where((s) => (s['name'] as String).toLowerCase().contains(_query))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search for services...',
            border: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
        ],
      ),
      body: DesktopCentered(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _query.isEmpty
            ? _buildRecentOrSuggestions()
            : _buildResults(),
      ),
    );
  }

  Widget _buildRecentOrSuggestions() {
    // Show popular categories as suggestions
    if (_allCategories.isEmpty) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Popular services',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allCategories.take(8).map((cat) {
            return ActionChip(
              label: Text(cat['name']),
              onPressed: () {
                _searchController.text = cat['name'];
                _onSearchChanged(cat['name']);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (_filteredCategories.isEmpty &&
        _filteredSubcategories.isEmpty &&
        _filteredServices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 64, color: AppColors.textGrey),
            const SizedBox(height: 12),
            Text(
              'No results for "$_query"',
              style: const TextStyle(color: AppColors.textGrey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Categories
        if (_filteredCategories.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Categories',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ..._filteredCategories.map((cat) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 2,
              ),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 44,
                  height: 44,
                  color: AppColors.primary.withValues(alpha: 0.08),
                  child:
                      cat['icon'] != null && (cat['icon'] as String).isNotEmpty
                      ? Image.network(
                          cat['icon'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.build, color: AppColors.primary),
                        )
                      : const Icon(Icons.build, color: AppColors.primary),
                ),
              ),
              title: Text(
                cat['name'],
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'From ₹${cat['base_price']}',
                style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.textGrey,
              ),
              onTap: () {
                final subcategories =
                    (cat['subcategories'] as List<dynamic>?) ?? [];
                final directServices =
                    (cat['services'] as List<dynamic>?) ?? [];

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
                  // Show first subcategory's services or all direct services
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ServiceListScreen(
                        categoryId: cat['id'],
                        title: cat['name'],
                        services: directServices,
                      ),
                    ),
                  );
                }
              },
            );
          }),
        ],

        // Services
        // Subcategories
        if (_filteredSubcategories.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Subcategories',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ..._filteredSubcategories.map((sub) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 2,
              ),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 44,
                  height: 44,
                  color: AppColors.primary.withValues(alpha: 0.08),
                  child:
                      sub['icon'] != null && (sub['icon'] as String).isNotEmpty
                      ? Image.network(
                          sub['icon'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.build, color: AppColors.primary),
                        )
                      : const Icon(Icons.build, color: AppColors.primary),
                ),
              ),
              title: Text(
                sub['name'],
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                sub['_category_name'] ?? '',
                style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.textGrey,
              ),
              onTap: () {
                final subServices = (sub['services'] as List<dynamic>?) ?? [];
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ServiceListScreen(
                      categoryId: sub['_category_id'],
                      subcategoryId: sub['id'],
                      title: '${sub['_category_name']} - ${sub['name']}',
                      services: subServices,
                    ),
                  ),
                );
              },
            );
          }),
        ],
        if (_filteredServices.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Services',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ..._filteredServices.map((svc) {
            final price = double.tryParse('${svc['price']}') ?? 0;
            final imageUrl = svc['image'] as String?;
            final qty = _cart.getQuantity(svc['id']);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ServiceDetailScreen(
                                serviceId: svc['id'],
                                name: svc['name'],
                                description: svc['description'] ?? '',
                                price: price,
                                durationMinutes: svc['duration_minutes'],
                                imageUrl: imageUrl,
                                categoryId: svc['_category_id'],
                                subcategoryId: svc['_subcategory_id'],
                                categoryName: svc['_category_name'] ?? '',
                              ),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              svc['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              svc['_category_name'] ?? '',
                              style: const TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Image + Add
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 70,
                            height: 60,
                            color: Colors.grey.shade100,
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.image,
                                      color: AppColors.textGrey,
                                    ),
                                  )
                                : const Icon(
                                    Icons.image,
                                    color: AppColors.textGrey,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        qty == 0
                            ? SizedBox(
                                width: 70,
                                height: 28,
                                child: OutlinedButton(
                                  onPressed: () => _onServiceAddTap(svc),
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    side: const BorderSide(
                                      color: AppColors.primary,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: const Text(
                                    'Add',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                width: 70,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _cart.removeItem(svc['id']),
                                      child: const Icon(
                                        Icons.remove,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                    Text(
                                      '$qty',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _onServiceAddTap(svc),
                                      child: const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
