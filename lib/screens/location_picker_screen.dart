import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/geocoding.dart';

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
}

/// Basemap tiles, and the one thing to change if the map ever needs to look
/// different again.
///
/// Esri's World Street Map, rather than the plain OpenStreetMap raster this
/// used to draw: same roads, but a softer palette and far less label clutter,
/// which is the whole reason the old map read as dated.
///
/// Two things make it a drop-in here. It needs no API key, so there is no
/// billing account to keep alive, and it answers with
/// `Access-Control-Allow-Origin: *`, so the identical URL works in the web
/// build instead of failing CORS. Note the {z}/{y}/{x} order -- Esri puts row
/// before column, the opposite of the usual slippy-map convention.
///
/// If tile usage ever outgrows a public endpoint, MapTiler and Stadia both
/// serve raster URLs of the same shape once `?key=...` is appended, so
/// switching is a change to this string and the attribution below.
const _tileUrlTemplate =
    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

// 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map'
// '/MapServer/tile/{z}/{y}/{x}';

/// Required by the tile licence, and it has to stay visible on the map.
const _tileAttribution = '© OpenStreetMap contributors © CARTO';
// 'Esri, HERE, Garmin, OpenStreetMap contributors';

/// Map screen where the customer fine-tunes their exact location.
/// Flow: opens centered on GPS -> customer can drag the MAP underneath a
/// FIXED center pin (common map-picker UX, e.g. Uber/Swiggy) -> confirms.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final _addressController = TextEditingController();

  LatLng _center = const LatLng(
    13.0827,
    80.2707,
  ); // fallback: Chennai, until GPS loads
  bool _isLoadingGps = true;
  bool _isLoadingAddress = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _goToCurrentLocation();
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

  /// Converts lat/long -> a readable address using OpenStreetMap's free
  /// Nominatim service. This is a courtesy auto-fill -- the customer can
  /// always edit the text field manually if it's not accurate enough
  /// (e.g. doesn't know the flat/floor number).
  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isLoadingAddress = true);
    try {
      final address = await reverseGeocode(point.latitude, point.longitude);
      if (address != null) {
        _addressController.text = address;
      }
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      _center = camera.center;
    }
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
    _addressController.dispose();
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
                      urlTemplate: _tileUrlTemplate,
                      userAgentPackageName: 'com.homeservice.customer_app',
                      // Esri serves no @2x tiles, so ask flutter_map to
                      // simulate: on a high-density screen it draws one zoom
                      // level out at double size, which keeps roads and labels
                      // the right physical size instead of hairline-thin.
                      retinaMode: RetinaMode.isHighDensity(context),
                    ),
                    const RichAttributionWidget(
                      attributions: [TextSourceAttribution(_tileAttribution)],
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
