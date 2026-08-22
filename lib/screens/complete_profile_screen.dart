import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../theme.dart';

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

  @override
  void initState() {
    super.initState();
    _loadExisting();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

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
      body: Form(
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
            _optionalField(
              'Email',
              _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _requiredField('Address', _addressController, maxLines: 2),
            const SizedBox(height: 12),
            _requiredField('State', _stateController),
            const SizedBox(height: 12),
            _requiredField('District', _districtController),
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
