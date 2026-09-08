import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import '../services/map_config_service.dart';
import '../utils/geocoding.dart';
import '../utils/plus_code.dart';

/// Result returned when the customer confirms a location.
class PickedLocation {
  final double latitude;
  final double longitude;
  final String addressText;

  PickedLocation({
    required this.latitude,
    required this.longitude,
    required this.addressText,
  });

  /// The Plus Code for the confirmed point.
  ///
  /// Derived rather than carried: it is arithmetic on the latitude and
  /// longitude right beside it, so a stored copy could only ever drift out of
  /// step with them. The backend takes the same view and computes it on the
  /// way out instead of keeping a column for it.
  String get plusCode => plusCodeFor(latitude, longitude);
}

/// Map screen where the customer fine-tunes their exact location.
/// Flow: opens centered on GPS -> customer can drag the MAP underneath a
/// FIXED center pin (common map-picker UX, e.g. Uber/Swiggy) -> confirms.
///
/// A Plus Code sits under the address field and follows the pin. It is there
/// because a large share of the addresses this app collects have no street
/// name worth writing down, and "37MC+37, Chennai" is something a customer can
/// read out over a phone and a vendor can paste into any maps app. The field
/// above it also accepts one, for the customer who was given a code and has
/// nothing else to search for.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final _addressController = TextEditingController();
  final _plusCodeController = TextEditingController();

  LatLng _center = const LatLng(
    13.0827,
    80.2707,
  ); // fallback: Chennai, until GPS loads
  bool _isLoadingGps = true;
  bool _isLoadingAddress = false;
  bool _isLookingUpCode = false;
  String? _errorMessage;

  /// The town under the pin, kept so the code can be written the short way.
  /// Empty until a geocoder names one, which is why the full code is what
  /// gets shown in the meantime.
  String _locality = '';

  /// The code for wherever the pin is now. Recomputed on the phone as the map
  /// moves -- no network, so it keeps up with a drag.
  String get _plusCode => plusCodeFor(_center.latitude, _center.longitude);

  String get _plusCodeDisplay =>
      displayPlusCode(_plusCode, locality: _locality);

  @override
  void initState() {
    super.initState();
    // Ask what to draw every time the screen opens rather than only at
    // launch: the admin may have switched provider since, and on the Google
    // setting the tile URL carries a session token Google expires after about
    // two weeks, which a long-installed app would otherwise draw blank with.
    MapConfigService.revision.addListener(_onMapConfigChanged);
    MapConfigService.refresh();
    _goToCurrentLocation();
  }

  void _onMapConfigChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _goToCurrentLocation() async {
    setState(() {
      _isLoadingGps = true;
      _errorMessage = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Please enable location services (GPS) and try again.');
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception(
            'Location permission is required to pick your address.',
          );
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission permanently denied. Enable it in phone Settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final newCenter = LatLng(position.latitude, position.longitude);
      setState(() => _center = newCenter);
      _mapController.move(newCenter, 17);
      await _reverseGeocode(newCenter);
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  /// Converts lat/long -> a readable address, through whichever geocoder the
  /// admin picked in the dashboard. This is a courtesy auto-fill -- the
  /// customer can always edit the text field manually if it's not accurate
  /// enough (e.g. doesn't know the flat/floor number).
  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isLoadingAddress = true);
    try {
      final place = await describePoint(point.latitude, point.longitude);
      if (place.address != null) {
        _addressController.text = place.address!;
      }
      // The town is what turns the full code into the short one people
      // actually say. Until it arrives the full code is shown, which is
      // longer but resolves anywhere.
      if (mounted) setState(() => _locality = place.locality);
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      // setState so the Plus Code under the pin keeps up with the drag. It is
      // pure arithmetic, so this costs nothing per frame.
      setState(() => _center = camera.center);
    }
  }

  /// Moves the map to a Plus Code the customer typed or pasted.
  Future<void> _goToPlusCode() async {
    final typed = _plusCodeController.text.trim();
    if (typed.isEmpty) return;

    setState(() {
      _isLookingUpCode = true;
      _errorMessage = null;
    });

    // The map's current centre is the reference for a short code with no town
    // written after it -- "37MC+37" alone means the nearest of its repeats.
    final result = await lookupPlusCode(
      typed,
      referenceLatitude: _center.latitude,
      referenceLongitude: _center.longitude,
    );
    if (!mounted) return;

    setState(() => _isLookingUpCode = false);

    if (!result.isFound) {
      setState(() => _errorMessage = result.error);
      return;
    }

    final found = LatLng(result.latitude!, result.longitude!);
    setState(() {
      _center = found;
      _locality = result.locality;
    });
    _mapController.move(found, 18);

    if (result.address != null && result.address!.isNotEmpty) {
      _addressController.text = result.address!;
    } else {
      // Nobody could name the place, which is the ordinary case for the codes
      // worth typing in. Fill in the address separately.
      await _reverseGeocode(found);
    }
  }

  Future<void> _copyPlusCode() async {
    await Clipboard.setData(ClipboardData(text: _plusCodeDisplay));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $_plusCodeDisplay')),
    );
  }

  Future<void> _sharePlusCode() async {
    // The full code goes out, never the short one: a short code read in
    // another town points somewhere else entirely.
    await SharePlus.instance.share(
      ShareParams(
        text: _locality.isEmpty
            ? 'My location: $_plusCode'
            : 'My location: $_plusCode ($_plusCodeDisplay)',
      ),
    );
  }

  void _confirm() {
    if (_addressController.text.trim().isEmpty) {
      setState(
        () => _errorMessage =
            'Please add a short address description (flat/floor/landmark).',
      );
      return;
    }
    Navigator.of(context).pop(
      PickedLocation(
        latitude: _center.latitude,
        longitude: _center.longitude,
        addressText: _addressController.text.trim(),
      ),
    );
  }

  @override
  void dispose() {
    MapConfigService.revision.removeListener(_onMapConfigChanged);
    _addressController.dispose();
    _plusCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Your Location')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 17,
                    onPositionChanged: _onMapMoved,
                    onMapEvent: (event) {
                      if (event is MapEventMoveEnd) {
                        _reverseGeocode(_center);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      // Whichever basemap the admin picked in the dashboard.
                      // On the Google setting the URL already carries the Map
                      // Tiles session token and key.
                      urlTemplate: MapConfigService.tileUrl,
                      subdomains: MapConfigService.subdomains,
                      maxNativeZoom: MapConfigService.maxZoom.round(),
                      userAgentPackageName: 'com.homeservice.customer_app',
                      // Providers that serve no @2x tiles need flutter_map to
                      // simulate: on a high-density screen it draws one zoom
                      // level out at double size, which keeps roads and labels
                      // the right physical size instead of hairline-thin.
                      // Google's session already asks for 2x tiles, so there
                      // it says not to.
                      retinaMode: MapConfigService.retinaTiles &&
                          RetinaMode.isHighDensity(context),
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(MapConfigService.attribution),
                      ],
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 36),
                  child: Icon(Icons.location_pin, size: 48, color: Colors.red),
                ),
                if (_isLoadingGps)
                  Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    mini: true,
                    onPressed: _isLoadingGps ? null : _goToCurrentLocation,
                    child: const Icon(Icons.my_location),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(8),
                    child: TextField(
                      controller: _plusCodeController,
                      textInputAction: TextInputAction.search,
                      textCapitalization: TextCapitalization.characters,
                      onSubmitted: (_) => _goToPlusCode(),
                      decoration: InputDecoration(
                        hintText: 'Plus Code, e.g. 37MC+37, Chennai',
                        prefixIcon: const Icon(Icons.pin_drop_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        isDense: true,
                        suffixIcon: _isLookingUpCode
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.search),
                                tooltip: 'Go to this Plus Code',
                                onPressed: _goToPlusCode,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Address (flat/floor/landmark)',
                    border: const OutlineInputBorder(),
                    suffixIcon: _isLoadingAddress
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                _PlusCodeBar(
                  display: _plusCodeDisplay,
                  onCopy: _copyPlusCode,
                  onShare: _sharePlusCode,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Confirm This Location'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Plus Code for the pin, with the two things anyone ever wants to do
/// with one.
///
/// Shown as a row rather than another text field because it is not something
/// the customer edits here -- it follows the pin. Copy and share both send the
/// code out; the sharing one deliberately sends the full version, since a
/// short code read in a different town points somewhere else.
class _PlusCodeBar extends StatelessWidget {
  final String display;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const _PlusCodeBar({
    required this.display,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (display.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4, right: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.pin_drop_outlined,
              size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plus Code',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  display,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    // A code is read character by character, and 0/O and 1/I
                    // are the two mistakes that put a vendor in the wrong
                    // street. The alphabet excludes them, but a monospace face
                    // still makes it easier to read aloud and to check.
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 20),
            tooltip: 'Copy Plus Code',
            onPressed: onCopy,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            tooltip: 'Share Plus Code',
            onPressed: onShare,
          ),
        ],
      ),
    );
  }
}
