import '../utils/breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/email_otp_sheet.dart';

class CompleteProfileScreen extends StatefulWidget {
  /// The same form doubles as "Edit profile" from the profile page — only the
  /// wording changes, since the fields and the save call are identical.
  final bool isEditing;

  const CompleteProfileScreen({super.key, this.isEditing = false});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isGettingLocation = false;
  String? _errorMessage;
  String? _locationStatus;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _stateController = TextEditingController();
  final _districtController = TextEditingController();
  final _pincodeController = TextEditingController();
  String _currentPhone = '';
  double? _latitude;
  double? _longitude;
  bool _isSendingEmailOtp = false;

  /// The address the account currently holds, lower-cased, and whether it was
  /// proved by OTP. Everything the email row shows is decided by comparing
  /// the text in the field against these two: the badge, the button, and
  /// whether saving is allowed at all.
  String _savedEmail = '';
  bool _emailVerified = false;

  /// State -> its districts, for the two pickers. Empty until the lookup
  /// lands, and empty for good if it never does — in which case both fields
  /// fall back to plain text, because a lookup that failed to load must not
  /// be the reason somebody cannot save their own address.
  Map<String, List<String>> _regions = {};

  // RawAutocomplete drives the field through a controller and focus node we
  // own, so the value the profile loads into it survives — its own internal
  // controller would be seeded once and then drift.
  final _stateFocus = FocusNode();
  final _districtFocus = FocusNode();

  String get _typedEmail => _emailController.text.trim().toLowerCase();

  /// True when what is typed is exactly the address already proved. Editing a
  /// single character makes this false again, which is the point -- a
  /// verified badge must never outlive the address it was earned by.
  bool get _isTypedEmailVerified =>
      _emailVerified && _typedEmail.isNotEmpty && _typedEmail == _savedEmail;

  @override
  void initState() {
    super.initState();
    _loadRegions();
    _loadExisting();
  }

  Future<void> _loadRegions() async {
    final regions = await ApiService.getRegions();
    if (mounted) setState(() => _regions = regions);
  }

  /// The districts offered for whatever state is in the field right now.
  /// Empty means "let them type it": either no state chosen yet, or a state
  /// we hold no districts for.
  List<String> get _districtOptions {
    final state = _stateController.text.trim();
    if (state.isEmpty) return const [];
    for (final entry in _regions.entries) {
      if (entry.key.toLowerCase() == state.toLowerCase()) return entry.value;
    }
    return const [];
  }

  Future<void> _loadExisting() async {
    try {
      final p = await ApiService.getMyProfile();
      _firstNameController.text = p['first_name'] ?? '';
      _lastNameController.text = p['last_name'] ?? '';
      _emailController.text = p['email'] ?? '';
      _addressController.text = p['address'] ?? '';
      _stateController.text = p['state'] ?? '';
      _districtController.text = p['district'] ?? '';
      _pincodeController.text = p['pincode'] ?? '';
      _currentPhone = p['phone_number'] ?? '';
      _savedEmail = (p['email'] ?? '').toString().trim().toLowerCase();
      _emailVerified = p['email_verified'] == true;

      final lat = p['latitude'];
      final lng = p['longitude'];
      if (lat != null) _latitude = double.tryParse('$lat');
      if (lng != null) _longitude = double.tryParse('$lng');

      if (mounted) setState(() {});

      // Auto-capture GPS if not already set
      if (_latitude == null || _longitude == null) {
        _captureLocation();
      } else {
        setState(() => _locationStatus = 'Location saved ✓');
      }
    } catch (_) {}
  }

  Future<void> _captureLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationStatus = 'Getting your location...';
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(
          () =>
              _locationStatus = 'GPS is off. Please enable location services.',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(
            () => _locationStatus = 'Location permission denied. Tap to retry.',
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(
          () => _locationStatus =
              'Location permission permanently denied. Enable in Settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationStatus = 'Location captured ✓';
      });
    } catch (e) {
      setState(() => _locationStatus = 'Could not get location. Tap to retry.');
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  /// Emails a code to whatever is in the field, then asks for it back.
  ///
  /// A confirmed code writes the address onto the account server-side, so
  /// `_savedEmail` is advanced to match: the save that follows is then
  /// agreeing with the server rather than trying to change anything.
  Future<void> _verifyEmail() async {
    final email = _typedEmail;
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Enter your email address first.');
      return;
    }
    if (!_looksLikeEmail(email)) {
      setState(() => _errorMessage = 'Enter a valid email address.');
      return;
    }

    setState(() {
      _isSendingEmailOtp = true;
      _errorMessage = null;
    });

    try {
      await ApiService.sendEmailOtp(email);
      if (!mounted) return;

      final verified = await showEmailOtpSheet(context, email);
      if (!mounted || !verified) return;

      setState(() {
        _savedEmail = email;
        _emailVerified = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email verified ✓')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isSendingEmailOtp = false);
    }
  }

  /// Deliberately loose. The address is about to be sent a code, and whether
  /// it can receive one is the only test that actually settles it -- this
  /// just catches the obvious typo before a wasted round trip.
  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // The backend refuses an unproved address anyway; catching it here means
    // the customer is told what to do about it instead of reading a 400.
    // An address that predates verification saves as it always did, so
    // nobody is trapped on this screen by an old, unconfirmed email.
    if (_typedEmail.isNotEmpty && _typedEmail != _savedEmail) {
      setState(
        () => _errorMessage = 'Please verify your email address before saving.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ApiService.updateMyProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _currentPhone,
        address: _addressController.text.trim(),
        email: _emailController.text.trim(),
        state: _stateController.text.trim(),
        district: _districtController.text.trim(),
        pincode: _pincodeController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    _stateFocus.dispose();
    _districtFocus.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Profile' : 'Complete Your Profile',
        ),
      ),
      body: DesktopCentered(
        maxWidth: kDesktopFormWidth,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.isEditing
                    ? 'Update your details below.'
                    : 'Please fill in your details before placing a booking.',
                style: const TextStyle(color: AppColors.textGrey),
              ),
              const SizedBox(height: 20),

              _requiredField('First Name', _firstNameController),
              const SizedBox(height: 12),
              _optionalField('Last Name', _lastNameController),
              const SizedBox(height: 12),
              _emailField(),
              const SizedBox(height: 12),
              _requiredField('Address', _addressController, maxLines: 2),
              const SizedBox(height: 12),
              _pickerField(
                label: 'State',
                controller: _stateController,
                focusNode: _stateFocus,
                options: _regions.keys.toList(),
                hint: 'Start typing your state',
                // Changing state invalidates whatever district was chosen
                // under the old one.
                onSelected: (_) => setState(_districtController.clear),
              ),
              const SizedBox(height: 12),
              _pickerField(
                label: 'District',
                controller: _districtController,
                focusNode: _districtFocus,
                options: _districtOptions,
                hint: _stateController.text.trim().isEmpty
                    ? 'Choose your state first'
                    : 'Start typing your district',
              ),
              const SizedBox(height: 12),
              _requiredField(
                'Pincode',
                _pincodeController,
                keyboardType: TextInputType.number,
              ),

              // Location status
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _latitude != null
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _latitude != null
                        ? Colors.green.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    if (_isGettingLocation)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        _latitude != null
                            ? Icons.location_on
                            : Icons.location_off,
                        size: 20,
                        color: _latitude != null ? Colors.green : Colors.orange,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _locationStatus ?? 'Detecting location...',
                        style: TextStyle(
                          fontSize: 13,
                          color: _latitude != null
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                    if (!_isGettingLocation && _latitude == null)
                      GestureDetector(
                        onTap: _captureLocation,
                        child: const Text(
                          'Retry',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
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
                        widget.isEditing ? 'Save Changes' : 'Save & Continue',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The email row: the field itself plus whichever of the three states it
  /// is in — verified, waiting to be verified, or empty.
  Widget _emailField() {
    final verified = _isTypedEmailVerified;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          // Rebuilds the row on every keystroke so the badge disappears the
          // moment the address stops being the one that was verified.
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Email',
            suffixIcon: verified
                ? const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.verified,
                      color: Colors.green,
                      size: 22,
                    ),
                  )
                : null,
          ),
          validator: (v) {
            final value = (v ?? '').trim();
            if (value.isEmpty) return null; // still optional
            return _looksLikeEmail(value.toLowerCase())
                ? null
                : 'Enter a valid email address';
          },
        ),
        const SizedBox(height: 6),
        if (verified)
          const _EmailStatus(
            icon: Icons.check_circle,
            color: Colors.green,
            message: 'Email verified',
          )
        else if (_typedEmail.isEmpty)
          const _EmailStatus(
            icon: Icons.info_outline,
            color: AppColors.textGrey,
            message: 'Optional. Add one to get booking updates by email.',
          )
        else
          Row(
            children: [
              const Expanded(
                child: _EmailStatus(
                  icon: Icons.gpp_maybe_outlined,
                  color: Colors.orange,
                  message: 'Not verified yet',
                ),
              ),
              TextButton.icon(
                onPressed: _isSendingEmailOtp ? null : _verifyEmail,
                icon: _isSendingEmailOtp
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined, size: 16),
                label: Text(_isSendingEmailOtp ? 'Sending...' : 'Verify'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _requiredField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: '$label *'),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? '$label is required' : null,
    );
  }

  /// A required field that suggests as you type and only accepts one of its
  /// own suggestions.
  ///
  /// This is what keeps state and district worth matching on: the whole
  /// "is there a vendor in your zone" question compares these two against
  /// what a vendor covers, and two people spelling one place differently
  /// would quietly answer it wrong.
  ///
  /// With no [options] it degrades to a plain text field. That happens when
  /// the lookup could not be fetched, or for a state we hold no districts
  /// for — and being unable to save an address because *our* list is short
  /// would be worse than an unrecognised spelling.
  Widget _pickerField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required List<String> options,
    String? hint,
    void Function(String)? onSelected,
  }) {
    if (options.isEmpty) {
      return TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: '$label *', hintText: hint),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? '$label is required' : null,
      );
    }

    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (value) {
        final typed = value.text.trim().toLowerCase();
        if (typed.isEmpty) return options;
        // Names starting with what was typed come first, then names merely
        // containing it, so "kann" offers Kannur before Bhadradri Kothagudem.
        final starts = options.where((o) => o.toLowerCase().startsWith(typed));
        final contains = options.where(
          (o) =>
              !o.toLowerCase().startsWith(typed) &&
              o.toLowerCase().contains(typed),
        );
        return [...starts, ...contains];
      },
      onSelected: (value) => onSelected?.call(value),
      fieldViewBuilder: (context, textController, node, onSubmitted) {
        return TextFormField(
          controller: textController,
          focusNode: node,
          decoration: InputDecoration(
            labelText: '$label *',
            hintText: hint,
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          validator: (v) {
            final typed = (v ?? '').trim();
            if (typed.isEmpty) return '$label is required';
            final match = options.any(
              (o) => o.toLowerCase() == typed.toLowerCase(),
            );
            return match ? null : 'Pick your $label from the list';
          },
        );
      },
      optionsViewBuilder: (context, onSelected, matches) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 400),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final option = matches.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(option),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _optionalField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _EmailStatus extends StatelessWidget {
  const _EmailStatus({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ),
      ],
    );
  }
}
