import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Which basemap this app draws, decided by the admin in Settings -> Maps.
///
/// The backend answers with a finished tile URL and the attribution that goes
/// with it, rather than with the name of a provider, so switching between the
/// free map and Google Maps is one string changing here — no new build of the
/// app, no key compiled into the APK, nothing to release.
///
/// That is also why this uses raster tiles through `flutter_map` on the Google
/// setting rather than the native Google map widget: `google_maps_flutter`
/// reads its key from AndroidManifest.xml at build time, so a key pasted into
/// the dashboard could never reach it without shipping a new build. Google's
/// Map Tiles API serves the same Google cartography as {z}/{x}/{y} tiles that
/// any slippy-map renderer can draw.
///
/// Values are cached on the device and read back before the first frame, the
/// way [BrandingService] does it, so the picker opens on the right map instead
/// of drawing one and swapping it a moment later.
class MapConfigService {
  // Version suffix: bumping it retires whatever a device already cached, so a
  // basemap that had to be dropped cannot outlive the update on old installs.
  static const _tileUrlKey = 'map_tile_url_v2';
  static const _subdomainsKey = 'map_subdomains_v2';
  static const _attributionKey = 'map_attribution_v2';
  static const _maxZoomKey = 'map_max_zoom_v2';
  static const _retinaKey = 'map_retina_tiles_v2';
  static const _providerKey = 'map_provider_v2';

  /// What ships in the app, and what it falls back to when the backend cannot
  /// be reached on a cold install. Keyless, so it always works.
  ///
  /// Esri's World Street Map, matching `MapSettings.FREE_*` on the backend.
  /// It replaced CARTO, which now stamps "API KEY REQUIRED" across every
  /// keyless tile while still answering 200 — nothing in the code notices,
  /// the map simply looks broken. Note the {z}/{y}/{x} order: Esri puts row
  /// before column, the opposite of the usual slippy-map convention.
  static const _defaultTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map'
      '/MapServer/tile/{z}/{y}/{x}';
  static const _defaultSubdomains = '';
  static const _defaultAttribution =
      'Esri, HERE, Garmin, OpenStreetMap contributors';
  static const _defaultMaxZoom = 19.0;

  static String _tileUrl = _defaultTileUrl;
  static String _subdomains = _defaultSubdomains;
  static String _attribution = _defaultAttribution;
  static double _maxZoom = _defaultMaxZoom;
  static bool _retinaTiles = true;
  static String _provider = 'FREE';

  /// Bumped whenever the map changes, so a picker already on screen can redraw
  /// instead of waiting to be reopened.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static String get tileUrl => _tileUrl;

  /// Subdomains for the `{s}` placeholder, split the way flutter_map wants
  /// them. Empty when the URL has no `{s}` in it, as Google's does not.
  static List<String> get subdomains => _subdomains.isEmpty
      ? const <String>[]
      : _subdomains.split('').toList(growable: false);

  /// Required by the tile licence on both providers, and it has to stay
  /// visible on the map.
  static String get attribution => _attribution;

  static double get maxZoom => _maxZoom;

  /// Whether the renderer should draw one zoom level out at double size on a
  /// high-density screen. Google's Map Tiles session already asks for 2x
  /// tiles, so doing it again there would halve the detail.
  static bool get retinaTiles => _retinaTiles;

  static bool get isGoogle => _provider == 'GOOGLE';

  /// Reads the cached values. Call once before runApp.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _tileUrl = prefs.getString(_tileUrlKey) ?? _defaultTileUrl;
      _subdomains = prefs.getString(_subdomainsKey) ?? _defaultSubdomains;
      _attribution = prefs.getString(_attributionKey) ?? _defaultAttribution;
      _maxZoom = prefs.getDouble(_maxZoomKey) ?? _defaultMaxZoom;
      _retinaTiles = prefs.getBool(_retinaKey) ?? true;
      _provider = prefs.getString(_providerKey) ?? 'FREE';
    } catch (_) {
      // Storage unavailable: the compiled-in free map is a fine answer.
    }
  }

  /// Pulls the current setting and caches it. Safe to fire and forget —
  /// nothing here should block or break app start-up.
  ///
  /// Worth refreshing on more than just launch: on the Google setting the tile
  /// URL carries a session token that Google expires after about two weeks,
  /// and the backend mints a new one whenever it is asked.
  static Future<void> refresh() async {
    try {
      final response = await http
          .get(Uri.parse('$kApiBaseUrl/maps/config/'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tileUrl = data['tile_url'] as String?;
      if (tileUrl == null || tileUrl.isEmpty) return;

      final changed = tileUrl != _tileUrl;

      _tileUrl = tileUrl;
      _subdomains = (data['subdomains'] as String?) ?? '';
      _attribution = (data['attribution'] as String?) ?? _defaultAttribution;
      _maxZoom = (data['max_zoom'] as num?)?.toDouble() ?? _defaultMaxZoom;
      _retinaTiles = (data['retina_tiles'] as bool?) ?? true;
      _provider = (data['provider'] as String?) ?? 'FREE';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tileUrlKey, _tileUrl);
      await prefs.setString(_subdomainsKey, _subdomains);
      await prefs.setString(_attributionKey, _attribution);
      await prefs.setDouble(_maxZoomKey, _maxZoom);
      await prefs.setBool(_retinaKey, _retinaTiles);
      await prefs.setString(_providerKey, _provider);

      if (changed) revision.value++;
    } catch (_) {
      // Offline or backend down — the cached map carries on working.
    }
  }
}
