import 'package:flutter/material.dart';
import '../screens/location_picker_screen.dart';
import '../services/api_service.dart';

/// Opens the map picker and saves whatever the customer confirms onto their
/// profile. Returns the new address text, or null if they backed out or the
/// save failed. Shared by the home hero and the profile page so both stay in
/// step on how a location change is persisted.
Future<String?> pickAndSaveLocation(BuildContext context) async {
  final picked = await Navigator.of(context).push<PickedLocation>(
    MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
  );
  if (picked == null || !context.mounted) return null;

  try {
    final profile = await ApiService.getMyProfile();
    await ApiService.updateMyProfile(
      firstName: profile['first_name'] ?? '',
      lastName: profile['last_name'] ?? '',
      phoneNumber: profile['phone_number'] ?? '',
      address: picked.addressText,
      email: profile['email'] ?? '',
      state: profile['state'] ?? '',
      district: profile['district'] ?? '',
      pincode: profile['pincode'] ?? '',
      latitude: picked.latitude,
      longitude: picked.longitude,
    );
    return picked.addressText;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save location: $e')));
    }
    return null;
  }
}
