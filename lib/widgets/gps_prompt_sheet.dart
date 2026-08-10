import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class GpsPromptSheet extends StatelessWidget {
  const GpsPromptSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GpsPromptSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Looks like your GPS is turned off',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Allow us to get your exact location for smooth booking experience',
            style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Geolocator.openLocationSettings();
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.location_on, color: Colors.white),
              label: const Text(
                'Turn on your GPS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE94E4E),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Center(
          //   child: TextButton(
          //     onPressed: () => Navigator.of(context).pop(),
          //     child: const Text(
          //       'Not now',
          //       style: TextStyle(color: Colors.grey),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}
