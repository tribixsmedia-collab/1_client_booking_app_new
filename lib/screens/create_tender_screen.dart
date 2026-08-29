import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../theme.dart';
import '../utils/tender_format.dart';

/// Post a tender: what you want built, what you expect to pay, where it is,
/// and the drawings a vendor needs to quote against.
///
/// Saving creates a DRAFT and uploads the attachments, then the customer
/// chooses whether to publish. Splitting it that way means a failed upload
/// never costs them the whole form.
class CreateTenderScreen extends StatefulWidget {
  const CreateTenderScreen({super.key});

  @override
  State<CreateTenderScreen> createState() => _CreateTenderScreenState();
}

class _CreateTenderScreenState extends State<CreateTenderScreen> {
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _description = TextEditingController();
  final _requirements = TextEditingController();
  final _area = TextEditingController();
  final _budget = TextEditingController();
  final _duration = TextEditingController();
  final _addressText = TextEditingController();
  final _state = TextEditingController();
  final _district = TextEditingController();
  final _pincode = TextEditingController();
  final _phone = TextEditingController();

  String _projectType = 'HOUSE';
  int? _categoryId;
  int? _subcategoryId;
  DateTime? _startDate;
  DateTime? _bidDeadline;

  List<dynamic> _categories = [];
  final List<File> _attachments = [];

  bool _loadingCategories = true;
  bool _isSaving = false;
  String? _loadError;

  static const _projectTypes = {
    'HOUSE': 'Independent House',
    'APARTMENT': 'Apartment / Flat',
    'VILLA': 'Villa',
    'COMMERCIAL': 'Commercial Space',
    'RENOVATION': 'Renovation / Remodel',
    'INTERIOR': 'Interior Work',
    'OTHER': 'Other',
  };

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _prefillFromProfile();
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _description,
      _requirements,
      _area,
      _budget,
      _duration,
      _addressText,
      _state,
      _district,
      _pincode,
      _phone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ApiService.getServiceCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _loadingCategories = false;
      });
    }
  }

  /// The site is usually the customer's own address, so start from their
  /// profile rather than making them retype it. Best-effort: a failure here
  /// just means an empty form, not a broken screen.
  Future<void> _prefillFromProfile() async {
    try {
      final profile = await ApiService.getMyProfile();
      if (!mounted) return;
      setState(() {
        if (_addressText.text.isEmpty) {
          _addressText.text = '${profile['address'] ?? ''}';
        }
        if (_state.text.isEmpty) _state.text = '${profile['state'] ?? ''}';
        if (_district.text.isEmpty) {
          _district.text = '${profile['district'] ?? ''}';
        }
        if (_pincode.text.isEmpty) {
          _pincode.text = '${profile['pincode'] ?? ''}';
        }
        if (_phone.text.isEmpty) {
          _phone.text = '${profile['phone_number'] ?? ''}';
        }
      });
    } catch (_) {}
  }

  List<dynamic> get _subcategories {
    if (_categoryId == null) return const [];
    final category = _categories.firstWhere(
      (c) => c['id'] == _categoryId,
      orElse: () => null,
    );
    if (category == null) return const [];
    return (category['subcategories'] as List?) ?? const [];
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final now = DateTime.now();
    final first = firstDate ?? DateTime(now.year, now.month, now.day);
    final last = lastDate ?? now.add(const Duration(days: 365 * 3));

    // The two dates constrain each other, so the window can be narrow or —
    // if the customer already picked an early start date — empty. Opening a
    // picker with first after last throws, so say why instead.
    if (last.isBefore(first)) {
      _snack(
        'Bidding has to close before work starts, and your start date is '
        'already here. Change the start date first.',
      );
      return;
    }

    // initialDate outside [first, last] also throws.
    var initial = current ?? now.add(const Duration(days: 7));
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _addAttachment() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isEmpty) return;
    setState(() {
      _attachments.addAll(picked.map((x) => File(x.path)));
    });
  }

  String _iso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _save({required bool publish}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      _snack('Choose what kind of work this is.');
      return;
    }

    // The server refuses this pair too. Catching it here means the customer
    // is told which two dates clash, next to the fields, instead of getting a
    // bare rejection back after everything else has already been filled in.
    if (_startDate != null &&
        _bidDeadline != null &&
        _bidDeadline!.isAfter(_startDate!)) {
      _snack(
        'Bidding closes ${tenderDate(_bidDeadline!.toIso8601String())} but '
        'work is meant to start ${tenderDate(_startDate!.toIso8601String())}. '
        'Move the bid deadline earlier, or the start date later.',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final tender = await ApiService.createTender(
        title: _title.text.trim(),
        projectType: _projectType,
        categoryId: _categoryId!,
        subcategoryId: _subcategoryId,
        description: _description.text.trim(),
        requirements: _requirements.text.trim(),
        areaSqft: int.tryParse(_area.text.trim()),
        expectedBudget: _budget.text.trim(),
        preferredStartDate: _startDate == null ? null : _iso(_startDate!),
        durationDays: int.tryParse(_duration.text.trim()),
        bidDeadline: _bidDeadline == null ? null : _iso(_bidDeadline!),
        addressText: _addressText.text.trim(),
        addressState: _state.text.trim(),
        addressDistrict: _district.text.trim(),
        addressPincode: _pincode.text.trim(),
        contactPhone: _phone.text.trim(),
      );

      final tenderId = tender['id'] as int;

      // Uploaded one at a time so a single bad file does not lose the rest.
      final failed = <String>[];
      for (final file in _attachments) {
        try {
          await ApiService.uploadTenderAttachment(
            tenderId: tenderId,
            file: file,
          );
        } catch (_) {
          failed.add(file.path.split(Platform.pathSeparator).last);
        }
      }

      if (publish) await ApiService.publishTender(tenderId);

      if (!mounted) return;
      Navigator.of(context).pop(true);

      final message = publish
          ? 'Tender sent for review. We will publish it to vendors shortly.'
          : 'Draft saved. Publish it when you are ready.';
      _snack(
        failed.isEmpty
            ? message
            : '$message ${failed.length} file(s) could not be uploaded.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      // A previous message still on screen would otherwise queue behind this
      // one, and the customer would read the stale one first.
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          // These say what to change, so give the longer ones time to be read.
          duration: Duration(
            milliseconds: message.length > 80 ? 6000 : 4000,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Post a tender')),
      bottomNavigationBar: _buildActions(),
      body: _loadingCategories
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
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
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _loadingCategories = true;
                          _loadError = null;
                        });
                        _loadCategories();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _section('What do you need built?'),
                  _field(
                    controller: _title,
                    label: 'Title',
                    hint: 'e.g. 3BHK ground-floor construction',
                    validator: _required,
                  ),
                  _dropdown<String>(
                    label: 'Project type',
                    value: _projectType,
                    items: _projectTypes.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _projectType = v!),
                  ),
                  _dropdown<int>(
                    label: 'Type of work',
                    value: _categoryId,
                    hint: 'Choose a category',
                    items: _categories
                        .map(
                          (c) => DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text('${c['name']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _categoryId = v;
                      // The old pick belongs to a different category now.
                      _subcategoryId = null;
                    }),
                  ),
                  if (_subcategories.isNotEmpty)
                    _dropdown<int>(
                      label: 'Speciality (optional)',
                      value: _subcategoryId,
                      hint: 'Any vendor in this category',
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Any vendor in this category'),
                        ),
                        ..._subcategories.map(
                          (s) => DropdownMenuItem<int>(
                            value: s['id'] as int,
                            child: Text('${s['name']}'),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _subcategoryId = v),
                    ),
                  _field(
                    controller: _description,
                    label: 'Description',
                    hint: 'What the project involves',
                    maxLines: 4,
                    validator: _required,
                  ),
                  _field(
                    controller: _requirements,
                    label: 'Requirements (optional)',
                    hint: 'Materials, finishes, anything specific',
                    maxLines: 3,
                  ),
                  _field(
                    controller: _area,
                    label: 'Built-up area in sq ft (optional)',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),

                  const SizedBox(height: 20),
                  _section('Your budget'),
                  _hint(
                    'Vendors quote against this figure, so a realistic number '
                    'gets you more useful bids.',
                  ),
                  _field(
                    controller: _budget,
                    label: 'Expected budget',
                    hint: 'e.g. 1500000',
                    prefixText: '₹ ',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final value = int.tryParse((v ?? '').trim());
                      if (value == null || value <= 0) {
                        return 'Enter the budget you expect to spend.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),
                  _section('Timeline'),
                  _dateTile(
                    label: 'Preferred start date',
                    value: _startDate,
                    // Work cannot start before bidding has closed.
                    onTap: () => _pickDate(
                      current: _startDate,
                      firstDate: _bidDeadline,
                      onPicked: (d) => setState(() => _startDate = d),
                    ),
                    onClear: () => setState(() => _startDate = null),
                  ),
                  _field(
                    controller: _duration,
                    label: 'How long should it take? (days, optional)',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  _dateTile(
                    label: 'Last day for bids',
                    value: _bidDeadline,
                    // Bidding has to be over by the time work starts.
                    onTap: () => _pickDate(
                      current: _bidDeadline,
                      lastDate: _startDate,
                      onPicked: (d) => setState(() => _bidDeadline = d),
                    ),
                    onClear: () => setState(() => _bidDeadline = null),
                  ),
                  _hint(
                    _startDate == null
                        ? 'Leave the bid deadline empty to keep it open.'
                        : 'Bidding has to close on or before your start date '
                              '(${tenderDate(_startDate!.toIso8601String())}). '
                              'Leave it empty to keep it open.',
                  ),

                  const SizedBox(height: 20),
                  _section('Where is the site?'),
                  _field(
                    controller: _addressText,
                    label: 'Address',
                    maxLines: 2,
                    validator: _required,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          controller: _district,
                          label: 'District',
                          validator: _required,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(controller: _state, label: 'State'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          controller: _pincode,
                          label: 'Pincode',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          controller: _phone,
                          label: 'Contact number',
                          keyboardType: TextInputType.phone,
                          validator: _required,
                        ),
                      ),
                    ],
                  ),
                  _hint(
                    'Your number is only shared with the vendor you finally '
                    'choose.',
                  ),

                  const SizedBox(height: 20),
                  _section('Drawings & photos'),
                  _hint(
                    'Plans or site photos help vendors quote accurately.',
                  ),
                  _buildAttachments(),
                ],
              ),
            ),
    );
  }

  Widget _buildAttachments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_attachments.isNotEmpty)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _attachments.length; i++)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _attachments[i],
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => setState(() => _attachments.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isSaving ? null : _addAttachment,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Add photos'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    if (_loadingCategories || _loadError != null) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => _save(publish: false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save draft'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isSaving ? null : () => _save(publish: true),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Publish tender'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- widgets
  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'This is required.' : null;

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ),
    ),
  );

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? prefixText,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: prefixText,
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value == null ? 'Not set' : tenderDate(value.toIso8601String()),
                  style: TextStyle(
                    color: value == null
                        ? AppColors.textGrey
                        : AppColors.textDark,
                  ),
                ),
              ),
              if (value != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.textGrey,
                  ),
                )
              else
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 17,
                  color: AppColors.textGrey,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
