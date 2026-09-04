import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// The gate in front of adding a service to the cart: does anybody actually
/// do this work in the state the customer lives in?
///
/// Sits behind [checkProfileComplete], which is what puts a state on the
/// account in the first place — a guest has none, and this must never be the
/// thing that stops them.
///
/// Returns true when the booking may go on. It says true whenever we cannot
/// answer: no state on the profile, or the server did not come back. Not
/// knowing where somebody is is not a reason to refuse them a booking.
Future<bool> checkServiceZone(
  BuildContext context, {
  required int serviceId,
  required String serviceName,
}) async {
  final area = await ApiService.getMyArea();
  if (area == null) return true;

  final zone = await ApiService.getServiceAvailability(
    serviceId: serviceId,
    state: area['state'],
    district: area['district'],
  );
  if (zone == null || zone['available'] != false) return true;

  if (!context.mounted) return false;
  await showZoneBlockedDialog(
    context,
    zone: zone,
    serviceName: serviceName,
  );
  return false;
}

/// What a customer sees when they try to book a service nobody covers where
/// they live. Shared so every "Add" in the app says the same thing.
Future<void> showZoneBlockedDialog(
  BuildContext context, {
  required Map<String, dynamic> zone,
  required String serviceName,
}) {
  final stateName = zoneStateName(zone);
  final elsewhere =
      (zone['vendors_elsewhere'] as List<dynamic>?)?.length ?? 0;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.location_off_outlined, color: Color(0xFFE65100)),
          SizedBox(width: 8),
          Expanded(child: Text('No vendor in your zone')),
        ],
      ),
      content: Text(
        elsewhere == 0
            ? 'We have no vendor for "$serviceName" in $stateName yet. '
                  'Please try another service, or check back soon.'
            : 'We have no vendor for "$serviceName" in $stateName yet.\n\n'
                  '$elsewhere vendor${elsewhere == 1 ? '' : 's'} elsewhere '
                  'do this work. Open the service to see them, with the state '
                  'and district each one is in.',
        style: const TextStyle(fontSize: 14, height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Where the customer is, as the server spells it — "Ernakulam, Kerala", or
/// just the state when we were never told the district. Falls back to
/// something that still reads as a sentence when it sent nothing.
String zoneStateName(Map<String, dynamic>? zone) {
  final state = (zone?['state'] as String?) ?? '';
  if (state.isEmpty) return 'your area';

  final district = (zone?['district'] as String?) ?? '';
  return district.isEmpty ? state : '$district, $state';
}
