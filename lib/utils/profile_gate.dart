import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../screens/complete_profile_screen.dart';

/// Returns true if profile is complete (or was just completed).
/// Returns false if user cancelled — caller should abort.
Future<bool> checkProfileComplete(BuildContext context) async {
  try {
    final profile = await ApiService.getMyProfile();
    if (profile['is_profile_complete'] == true) return true;

    if (!context.mounted) return false;
    final didComplete = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CompleteProfileScreen()),
    );
    return didComplete == true;
  } catch (_) {
    return true; // On error, let them proceed — backend will catch issues
  }
}
