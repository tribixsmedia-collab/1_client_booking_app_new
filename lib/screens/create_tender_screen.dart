import '../utils/breakpoints.dart';
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
///
/// The same screen edits an existing tender. That matters most when an admin
/// has sent one back: the customer has to be able to act on the reason before
/// publishing again, and re-submitting an unchanged tender would just be
/// rejected a second time.
/// What a quote-only service hands the tender form to start it off.
class QuoteSeed {
  /// The service's own category and subcategory — the form's "type of work".
  final int categoryId;
  final int? subcategoryId;

  /// One of Tender.ProjectType. Empty leaves the form on its default.
  final String projectType;

  /// The service's name, used as the opening title.
  final String serviceName;

  const QuoteSeed({
    required this.categoryId,
    this.subcategoryId,
    this.projectType = '',
    this.serviceName = '',
  });
}


class CreateTenderScreen extends StatefulWidget {
  /// The tender being edited, as returned by the detail endpoint. Null when
  /// posting a new one. Only DRAFT and REJECTED tenders may be passed here —
  /// the server refuses to change any other status.
  final Map<String, dynamic>? tender;

  /// The quote-only service the customer came from, when they arrived by
  /// tapping "Request a quote" rather than posting a tender from scratch.
  ///
  /// It answers the first two questions the form asks — what kind of project
  /// this is, and what type of work — so the customer starts from the service
  /// they were already looking at instead of describing it again. Everything
  /// stays editable; this only decides what the form opens with.
  final QuoteSeed? seed;

  const CreateTenderScreen({super.key, this.tender, this.seed});

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

  bool get _isEditing => widget.tender != null;

  /// True when the admin sent this one back, which changes what the buttons
  /// should say — "publish again" rather than "publish".
  bool get _wasSentBack => widget.tender?['status'] == 'REJECTED';

  /// Attachments already on the server. Removing one deletes it immediately;
  /// the new files in [_attachments] are only uploaded on save.
  List<dynamic> _existingAttachments = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (_isEditing) {
      _prefillFromTender();
    } else {
      // The service the customer came from answers the first two questions;
      // their profile answers the address ones.
      _prefillFromService();
      _prefillFromProfile();
    }
  }

  /// Opens the form on the quote-only service the customer tapped, so they do
  /// not describe again what they were just looking at.
  ///
  /// Only what the service actually knows: the project type an admin set on
  /// it, its own category and subcategory as the type of work, and its name
  /// as a starting title. All of it stays editable.
  void _prefillFromService() {
    final seed = widget.seed;
    if (seed == null) return;

    _categoryId = seed.categoryId;
    _subcategoryId = seed.subcategoryId;
    // Only a value the dropdown actually offers, or it would have nothing to
    // show for it.
    if (_projectTypes.containsKey(seed.projectType)) {
      _projectType = seed.projectType;
    }
    if (seed.serviceName.isNotEmpty && _title.text.isEmpty) {
      _title.text = seed.serviceName;
    }
  }

  /// Lets go of a seeded category the list does not offer.
  ///
  /// The service's category could have been switched off since, and a
  /// dropdown holding a value that is not among its items throws rather than
  /// just looking wrong. Falling back to an empty picker is the safe end.
  void _dropSeededCategoryIfMissing() {
    if (_categoryId == null) return;

    final offered = _categories.any((c) => c['id'] == _categoryId);
    if (!offered) {
      _categoryId = null;
      _subcategoryId = null;
      return;
    }

    if (_subcategoryId != null &&
        !_subcategories.any((s) => s['id'] == _subcategoryId)) {
      _subcategoryId = null;
    }
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
        _dropSeededCategoryIfMissing();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _loadingCategories = false;
      });
    }
  }

  /// Fill the form from the tender being edited, so the customer changes the
  /// one thing the admin asked about rather than retyping the whole brief.
  void _prefillFromTender() {
    final tender = widget.tender!;

    _title.text = '${tender['title'] ?? ''}';
    _description.text = '${tender['description'] ?? ''}';
    _requirements.text = '${tender['requirements'] ?? ''}';
    _area.text = tender['area_sqft'] == null ? '' : '${tender['area_sqft']}';
    _budget.text = _wholeNumber(tender['expected_budget']);
    _duration.text = tender['duration_days'] == null
        ? ''
        : '${tender['duration_days']}';
    _addressText.text = '${tender['address_text'] ?? ''}';
    _state.text = '${tender['address_state'] ?? ''}';
    _district.text = '${tender['address_district'] ?? ''}';
    _pincode.text = '${tender['address_pincode'] ?? ''}';
    _phone.text = '${tender['contact_phone'] ?? ''}';

    _projectType = '${tender['project_type'] ?? 'HOUSE'}';
    _categoryId = tender['category'] as int?;
    _subcategoryId = tender['subcategory'] as int?;
    _startDate = DateTime.tryParse('${tender['preferred_start_date'] ?? ''}');
    _bidDeadline = DateTime.tryParse('${tender['bid_deadline'] ?? ''}');
    _existingAttachments = List<dynamic>.from(tender['attachments'] ?? const []);
  }

  /// '1500000.00' -> '1500000', so the field does not show trailing zeros the
  /// customer then has to delete.
  String _wholeNumber(dynamic value) {
    final parsed = double.tryParse('${value ?? ''}');
    return parsed == null ? '' : parsed.truncate().toString();
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
      final int tenderId;

      if (_isEditing) {
        tenderId = widget.tender!['id'] as int;
        // Nulls are sent deliberately: clearing a date or the area has to
        // reach the server, and a partial PATCH would silently keep the old
        // value instead.
        await ApiService.updateTender(tenderId, {
          'title': _title.text.trim(),
          'project_type': _projectType,
          'category': _categoryId,
          'subcategory': _subcategoryId,
          'description': _description.text.trim(),
          'requirements': _requirements.text.trim(),
          'area_sqft': int.tryParse(_area.text.trim()),
          'expected_budget': _budget.text.trim(),
          'preferred_start_date': _startDate == null ? null : _iso(_startDate!),
          'duration_days': int.tryParse(_duration.text.trim()),
          'bid_deadline': _bidDeadline == null ? null : _iso(_bidDeadline!),
          'address_text': _addressText.text.trim(),
          'address_state': _state.text.trim(),
          'address_district': _district.text.trim(),
          'address_pincode': _pincode.text.trim(),
          'contact_phone': _phone.text.trim(),
        });
      } else {
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
        tenderId = tender['id'] as int;
      }

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

      final String message;
      if (publish) {
        message = _wasSentBack
            ? 'Sent back for review. We will publish it to vendors shortly.'
            : 'Tender sent for review. We will publish it to vendors shortly.';
      } else {
        message = _isEditing
            ? 'Changes saved. Publish it when you are ready.'
            : 'Draft saved. Publish it when you are ready.';
      }
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
          duration: Duration(milliseconds: message.length > 80 ? 6000 : 4000),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit tender' : 'Post a tender'),
      ),
      bottomNavigationBar: DesktopCentered(
        fillHeight: false,
        maxWidth: kDesktopFormWidth,
        child: _buildActions(),
      ),
      body: DesktopCentered(
        maxWidth: kDesktopFormWidth,
        child: _loadingCategories
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
                    // The reason has to be visible while they fix it —
                    // it lives on the detail screen they just came from.
                    if (_wasSentBack) _buildSentBackNotice(),
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
      ),
    );
  }

  /// Why the admin sent it back, shown above the form so the customer can
  /// read it while making the change rather than remembering it.
  Widget _buildSentBackNotice() {
    final reason = '${widget.tender?['rejection_reason'] ?? ''}'.trim();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: Colors.orange.shade800,
              ),
              const SizedBox(width: 8),
              Text(
                'Our team asked for a change',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              reason,
              style: const TextStyle(fontSize: 13.5, color: AppColors.textDark),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Make the change, then send it back for review.',
            style: TextStyle(fontSize: 12.5, color: Colors.orange.shade900),
          ),
        ],
      ),
    );
  }

  /// Removes an attachment already on the server. Immediate, unlike the new
  /// files below it — there is nothing to undo it against once it is gone.
  Future<void> _removeExistingAttachment(dynamic attachment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this file?'),
        content: const Text('It will be deleted from your tender.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService.deleteTenderAttachment(attachment['id']);
      if (!mounted) return;
      setState(() => _existingAttachments.remove(attachment));
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget _buildAttachments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_existingAttachments.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final attachment in _existingAttachments)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: attachment['is_image'] == true
                          ? Image.network(
                              '${attachment['file']}',
                              width: 92,
                              height: 92,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _existingFileTile(attachment),
                            )
                          : _existingFileTile(attachment),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: _isSaving
                            ? null
                            : () => _removeExistingAttachment(attachment),
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
          const SizedBox(height: 10),
        ],
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
                child: Text(_isEditing ? 'Save only' : 'Save draft'),
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
                    : Text(
                        _wasSentBack
                            ? 'Save & send again'
                            : _isEditing
                            ? 'Save & publish'
                            : 'Publish tender',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Stand-in for an attachment that is not an image, or whose thumbnail
  /// could not be fetched.
  Widget _existingFileTile(dynamic attachment) => Container(
    width: 92,
    height: 92,
    color: AppColors.background,
    padding: const EdgeInsets.all(6),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.insert_drive_file_outlined, color: AppColors.textGrey),
        const SizedBox(height: 4),
        Text(
          '${attachment['filename'] ?? 'File'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9.5, color: AppColors.textGrey),
        ),
      ],
    ),
  );

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
                  value == null
                      ? 'Not set'
                      : tenderDate(value.toIso8601String()),
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
