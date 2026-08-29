import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api_service.dart';
import '../screens/complete_profile_screen.dart';
import '../screens/phone_entry_screen.dart';

/// The gate in front of every action that needs an account — booking a
/// service, adding to the cart, leaving a review.
///
/// Returns true if the caller may go ahead, false if the customer backed out,
/// in which case the caller aborts. That contract is what makes guest
/// browsing possible: on the web nobody is signed in when the home page
/// loads, so this is where the phone number and OTP are collected, and then
/// the missing profile details. On Android the customer already signed in at
/// launch and only the profile half runs.
Future<bool> checkProfileComplete(BuildContext context) async {
  if (!await requireSignIn(context)) return false;

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

/// The sign-in half of the gate on its own, with no profile-completion step.
///
/// For actions that need an account but not a filled-in profile — opening the
/// notification list, saving a location. Anyone already signed in passes
/// straight through, and off the web it never does anything at all, so the
/// installed apps behave exactly as they did before guest browsing existed.
Future<bool> requireSignIn(BuildContext context) async {
  if (!kGuestBrowsing || await ApiService.isLoggedIn()) return true;
  if (!context.mounted) return false;
  final signedIn = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const PhoneEntryScreen(asGate: true)),
  );
  return signedIn == true;
}
