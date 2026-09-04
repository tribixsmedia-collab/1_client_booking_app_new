import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../config.dart';
import '../main.dart';
import '../screens/phone_entry_screen.dart';
// import '../screens/notification_service.dart';
import 'notification_service.dart';
import 'push_service.dart';

class ApiService {
  static const _tokenKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  // ---------- Token storage ----------

  static Future<void> _saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, access);
    await prefs.setString(_refreshKey, refresh);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> logout() async {
    await PushService.unregisterToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshKey);
    NotificationService.instance.reset();
    _cachedArea = null;
  }

  /// Where the signed-in customer is, held for the session.
  ///
  /// Every service page asks whether it can be booked there, and somebody
  /// does not move house while browsing. Cleared on logout and whenever the
  /// profile is saved. Keys: `state` and `district`.
  static Map<String, String>? _cachedArea;

  /// The customer's own state and district, or null when nobody is signed in,
  /// the profile carries no state yet, or the profile could not be read.
  ///
  /// Null is not "no vendors" — it is "we do not know where they are", and
  /// the zone check lets an unknown place through rather than blocking a
  /// booking over it. The district may be empty even when the state is not,
  /// in which case the question is asked of the state alone.
  static Future<Map<String, String>?> getMyArea() async {
    if (_cachedArea != null) return _cachedArea;
    if (!await isLoggedIn()) return null;

    try {
      final profile = await getMyProfile();
      final state = (profile['state'] as String?)?.trim() ?? '';
      if (state.isEmpty) return null;
      return _cachedArea = {
        'state': state,
        'district': (profile['district'] as String?)?.trim() ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null;
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Authenticated GET that retries once with a fresh token on a 401,
  /// following the same refresh pattern the write calls use.
  static Future<http.Response> _authorizedGet(String url) async {
    var res = await http.get(Uri.parse(url), headers: await _authHeaders());
    if (res.statusCode == 401 && await _tryRefreshToken()) {
      res = await http.get(Uri.parse(url), headers: await _authHeaders());
    }
    return res;
  }

  static Future<bool> _tryRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(_refreshKey);
    if (refreshToken == null) return false;

    try {
      final res = await http.post(
        Uri.parse('$kApiBaseUrl/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await prefs.setString(_tokenKey, data['access']);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> tryRefreshToken() => _tryRefreshToken();

  static Future<void> _forceLogout() async {
    final hadSession = await getAccessToken() != null;
    await logout();

    // A guest browsing the web app has no session to expire, so a 401 here
    // just means "not signed in" — throwing up the login screen mid-browse
    // would be wrong. They get asked at the point of booking instead.
    if (kGuestBrowsing && !hadSession) return;

    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      Navigator.of(ctx).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PhoneEntryScreen()),
        (route) => false,
      );
    }
  }

  // ---------- Auth (Phone + OTP) ----------

  static Future<void> sendOtp(String phoneNumber) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/auth/send-otp/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone_number': phoneNumber}),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractFirstError(jsonDecode(res.body)));
    }
  }

  static Future<bool> verifyOtp({
    required String phoneNumber,
    required String code,
    String firstName = '',
    String lastName = '',
    String address = '',
    String referralCode = '',
  }) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/auth/verify-otp/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone_number': phoneNumber,
        'code': code,
        'first_name': firstName,
        'last_name': lastName,
        'address': address,
        'referral_code': referralCode,
      }),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      await _saveTokens(data['access'], data['refresh']);
      PushService.registerToken();
      return data['is_new_user'] == true;
    } else {
      throw Exception(_extractFirstError(jsonDecode(res.body)));
    }
  }

  static String _extractFirstError(dynamic body) {
    if (body is Map) {
      final firstKey = body.keys.first;
      final firstVal = body[firstKey];
      if (firstVal is List && firstVal.isNotEmpty) return '${firstVal.first}';
      return '$firstVal';
    }
    if (body is List && body.isNotEmpty) return '${body.first}';
    return 'Something went wrong. Please try again.';
  }

  // ---------- Service Categories ----------

  static Future<List<dynamic>> getServiceCategories() async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/services/categories/'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Could not load services. Please check your connection.');
  }

  // ---------- Bookings ----------

  static Future<Map<String, dynamic>> createBooking({
    required int categoryId,
    int? subcategoryId,
    required String preferredDate,
    required String preferredTime,
    required String notes,
    String? addressText,
    String? addressState,
    String? addressDistrict,
    String? addressPincode,
    String? customerPhone,
    double? locationLat,
    double? locationLng,
    List<Map<String, dynamic>>? servicesJson,
    int? formSubmissionId,
    double discountAmount = 0,
    String couponCode = '',
    int? preferredVendorId,
  }) async {
    var headers = await _authHeaders();
    var res = await http.post(
      Uri.parse('$kApiBaseUrl/bookings/'),
      headers: headers,
      body: jsonEncode({
        'category': categoryId,
        'preferred_date': preferredDate,
        'preferred_time': preferredTime,
        'notes': notes,
        if (subcategoryId != null) 'subcategory': subcategoryId,
        if (addressText != null) 'address_text': addressText,
        if (addressState != null) 'address_state': addressState,
        if (addressDistrict != null) 'address_district': addressDistrict,
        if (addressPincode != null) 'address_pincode': addressPincode,
        if (customerPhone != null) 'customer_phone': customerPhone,
        if (locationLat != null) 'location_lat': locationLat.toStringAsFixed(6),
        if (locationLng != null) 'location_lng': locationLng.toStringAsFixed(6),
        if (servicesJson != null) 'services_json': servicesJson,
        if (formSubmissionId != null) 'form_submission': formSubmissionId,
        if (servicesJson != null) 'services_json': servicesJson,
        if (formSubmissionId != null) 'form_submission': formSubmissionId,
        'discount_amount': discountAmount.toStringAsFixed(2),
        'coupon_code': couponCode,
        if (preferredVendorId != null) 'preferred_vendor': preferredVendorId,
      }),
    );
    if (res.statusCode == 401) {
      if (await _tryRefreshToken()) {
        headers = await _authHeaders();
        res = await http.post(
          Uri.parse('$kApiBaseUrl/bookings/'),
          headers: headers,
          body: jsonEncode({
            'category': categoryId,
            'preferred_date': preferredDate,
            'preferred_time': preferredTime,
            'notes': notes,
            if (subcategoryId != null) 'subcategory': subcategoryId,
            if (addressText != null) 'address_text': addressText,
            if (locationLat != null)
              'location_lat': locationLat.toStringAsFixed(6),
            if (locationLng != null)
              'location_lng': locationLng.toStringAsFixed(6),
            if (servicesJson != null) 'services_json': servicesJson,
            if (formSubmissionId != null) 'form_submission': formSubmissionId,
            'discount_amount': discountAmount.toStringAsFixed(2),
            'coupon_code': couponCode,
            if (preferredVendorId != null)
              'preferred_vendor': preferredVendorId,
          }),
        );
      } else {
        await _forceLogout();
        throw Exception('Session expired. Please log in again.');
      }
    }
    if (res.statusCode == 201) return jsonDecode(res.body);
    throw Exception(_extractFirstError(jsonDecode(res.body)));
  }

  static Future<List<dynamic>> getMyBookings() async {
    var headers = await _authHeaders();
    var res = await http.get(
      Uri.parse('$kApiBaseUrl/bookings/my/'),
      headers: headers,
    );
    if (res.statusCode == 401) {
      if (await _tryRefreshToken()) {
        headers = await _authHeaders();
        res = await http.get(
          Uri.parse('$kApiBaseUrl/bookings/my/'),
          headers: headers,
        );
      } else {
        await _forceLogout();
        throw Exception('Session expired. Please log in again.');
      }
    }
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Could not load your bookings.');
  }

  static Future<void> cancelBooking(int bookingId) async {
    var headers = await _authHeaders();
    var res = await http.post(
      Uri.parse('$kApiBaseUrl/bookings/$bookingId/cancel/'),
      headers: headers,
    );
    if (res.statusCode == 401) {
      if (await _tryRefreshToken()) {
        headers = await _authHeaders();
        res = await http.post(
          Uri.parse('$kApiBaseUrl/bookings/$bookingId/cancel/'),
          headers: headers,
        );
      } else {
        await _forceLogout();
        throw Exception('Session expired. Please log in again.');
      }
    }
    if (res.statusCode != 200) {
      throw Exception(_extractFirstError(jsonDecode(res.body)));
    }
  }

  // ---------- Profile ----------

  static Future<Map<String, dynamic>> getMyProfile() async {
    var headers = await _authHeaders();
    var res = await http.get(
      Uri.parse('$kApiBaseUrl/customers/me/'),
      headers: headers,
    );
    if (res.statusCode == 401) {
      if (await _tryRefreshToken()) {
        headers = await _authHeaders();
        res = await http.get(
          Uri.parse('$kApiBaseUrl/customers/me/'),
          headers: headers,
        );
      } else {
        await _forceLogout();
        throw Exception('Session expired. Please log in again.');
      }
    }
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Could not load your profile.');
  }

  static Future<void> updateMyProfile({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String address,
    required String email,
    required String state,
    required String district,
    required String pincode,
    double? latitude,
    double? longitude,
  }) async {
    var headers = await _authHeaders();
    var res = await http.patch(
      Uri.parse('$kApiBaseUrl/customers/me/'),
      headers: headers,
      body: jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'address': address,
        'email': email,
        'state': state,
        'district': district,
        'pincode': pincode,
        if (latitude != null) 'latitude': latitude.toStringAsFixed(6),
        if (longitude != null) 'longitude': longitude.toStringAsFixed(6),
      }),
    );
    if (res.statusCode == 401) {
      if (await _tryRefreshToken()) {
        headers = await _authHeaders();
        res = await http.patch(
          Uri.parse('$kApiBaseUrl/customers/me/'),
          headers: headers,
          body: jsonEncode({
            'first_name': firstName,
            'last_name': lastName,
            'phone_number': phoneNumber,
            'address': address,
            'email': email,
            'state': state,
            'district': district,
            'pincode': pincode,
            if (latitude != null) 'latitude': latitude.toStringAsFixed(6),
            if (longitude != null) 'longitude': longitude.toStringAsFixed(6),
          }),
        );
      } else {
        await _forceLogout();
        throw Exception('Session expired. Please log in again.');
      }
    }
    if (res.statusCode != 200) {
      throw Exception(_extractFirstError(jsonDecode(res.body)));
    }
    // They may have just moved somewhere else; the zone check must not go on
    // answering for where they used to be.
    _cachedArea = state.trim().isEmpty
        ? null
        : {'state': state.trim(), 'district': district.trim()};
  }
  // ---------- Email verification (OTP to the address on the profile) ----------
  //
  // The address is never written by the profile form. It reaches the account
  // through verifyEmailOtp alone, which is what makes the badge mean anything.

  /// Emails a 6-digit code to [email]. Throws with the server's wording on a
  /// cooldown, an address another account already proved, or a failed send.
  static Future<void> sendEmailOtp(String email) async {
    final res = await _withAuth(
      (headers) => http.post(
        Uri.parse('$kApiBaseUrl/auth/email/send-otp/'),
        headers: headers,
        body: jsonEncode({'email': email}),
      ),
    );
    if (res.statusCode != 200) {
      throw Exception(
        _errorFrom(res, 'Could not send the code. Please try again.'),
      );
    }
  }

  /// Confirms the code. On success the address is saved on the account and
  /// marked verified, so the profile save that follows just agrees with it.
  static Future<void> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    final res = await _withAuth(
      (headers) => http.post(
        Uri.parse('$kApiBaseUrl/auth/email/verify-otp/'),
        headers: headers,
        body: jsonEncode({'email': email, 'code': code}),
      ),
    );
    if (res.statusCode != 200) {
      throw Exception(_errorFrom(res, 'Could not verify that code.'));
    }
  }

  // ---------- Header Carousel ----------

  static Future<List<dynamic>> getHeaderBanners() async {
    final res = await http.get(
      Uri.parse('$kApiBaseUrl/promotions/header-banners/'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return []; // non-critical, return empty on failure
  }

  // ---------- Personalised rows ----------

  /// Services this customer opened before, newest first.
  static Future<List<dynamic>> getRecentlyViewed() async {
    try {
      final res = await _authorizedGet(
        '$kApiBaseUrl/customers/recently-viewed/',
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return [];
  }

  /// Services this customer has booked before, most-booked first.
  static Future<List<dynamic>> getBookAgain() async {
    try {
      final res = await _authorizedGet('$kApiBaseUrl/customers/book-again/');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return [];
  }

  /// Remembers that the customer opened a service. Fire-and-forget — a failed
  /// call must never get in the way of viewing the service itself.
  static Future<void> recordServiceView(int serviceId) async {
    try {
      var headers = await _authHeaders();
      final url = Uri.parse('$kApiBaseUrl/customers/recently-viewed/');
      final body = jsonEncode({'service_id': serviceId});
      var res = await http.post(url, headers: headers, body: body);
      if (res.statusCode == 401 && await _tryRefreshToken()) {
        headers = await _authHeaders();
        await http.post(url, headers: headers, body: body);
      }
    } catch (_) {}
  }

  // ---------- Refer & Earn ----------

  /// The customer's referral code plus all the admin-managed copy and their
  /// earnings so far. Returns null when the call fails or the programme is
  /// switched off, so callers can simply hide the banner.
  static Future<Map<String, dynamic>?> getReferralInfo() async {
    try {
      final res = await _authorizedGet('$kApiBaseUrl/referrals/me/');
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['is_active'] == true ? data : null;
    } catch (_) {
      return null;
    }
  }

  static Future<List<dynamic>> getMyReferrals() async {
    try {
      final res = await _authorizedGet('$kApiBaseUrl/referrals/my-referrals/');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return [];
  }

  // ---------- Promo Cards ----------

  static Future<List<dynamic>> getPromoCards() async {
    final res = await http.get(
      Uri.parse('$kApiBaseUrl/promotions/promo-cards/'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return []; // non-critical, return empty on failure
  }

  // ---------- Spotlights ----------

  static Future<List<dynamic>> getSpotlights() async {
    final res = await http.get(
      Uri.parse('$kApiBaseUrl/promotions/spotlights/'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return []; // non-critical, return empty on failure
  }

  // ---------- Home Sections ----------

  static Future<List<dynamic>> getHomeSections() async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/home/sections/'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }
  // ---------- Pro Vendors ----------

  /// Admin-flagged vendors put on show in the app.
  ///
  /// Pass [serviceId] to narrow the list to pros who cover that service's
  /// category — what the row at the bottom of a service page asks for.
  static Future<List<dynamic>> getProVendors({
    int? serviceId,
    int? categoryId,
    String? state,
    String? district,
  }) async {
    final query = <String, String>{
      if (serviceId != null) 'service': '$serviceId',
      if (categoryId != null) 'category': '$categoryId',
      if (state != null && state.isNotEmpty) 'state': state,
      if (district != null && district.isNotEmpty) 'district': district,
    };
    final uri = Uri.parse(
      '$kApiBaseUrl/vendors/pro/',
    ).replace(queryParameters: query.isEmpty ? null : query);

    try {
      final res = await http.get(uri);
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return [];
  }

  /// Every state with the districts under it, for the pickers on the profile
  /// form. Fetched once when that screen opens — around 20KB.
  ///
  /// A state whose list comes back empty is one the server holds no districts
  /// for, and the form lets that district be typed instead of picked. An
  /// empty result overall means the call failed, which the form treats the
  /// same way: nobody should be locked out of their own profile because a
  /// lookup did not load.
  static Future<Map<String, List<String>>> getRegions() async {
    try {
      final res = await http.get(Uri.parse('$kApiBaseUrl/vendors/regions/'));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return {
          for (final entry in (body['states'] as List<dynamic>))
            entry['name'] as String:
                List<String>.from(entry['districts'] as List<dynamic>),
        };
      }
    } catch (_) {}
    return {};
  }

  /// Whether this service can actually be had in [state] (narrowed by
  /// [district] when we know it), and who is around if not.
  ///
  /// Returns null when the call fails: not being able to reach the server is
  /// no reason to tell a customer their zone is uncovered, so the caller
  /// treats null as "carry on".
  ///
  /// Keys: `available`, `state`, `district`, `state_known`, `vendor_count`
  /// and `vendors_elsewhere` — vendor cards from elsewhere, each carrying the
  /// state and district it shows.
  static Future<Map<String, dynamic>?> getServiceAvailability({
    required int serviceId,
    String? state,
    String? district,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl/vendors/availability/').replace(
      queryParameters: {
        'service': '$serviceId',
        if (state != null && state.isNotEmpty) 'state': state,
        if (district != null && district.isNotEmpty) 'district': district,
      },
    );

    try {
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  /// Full profile for one pro vendor, or null when they are no longer listed.
  static Future<Map<String, dynamic>?> getProVendorDetail(int vendorId) async {
    try {
      final res = await http.get(
        Uri.parse('$kApiBaseUrl/vendors/pro/$vendorId/'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  static Future<List<dynamic>> getProVendorSections() async {
    try {
      final res = await http.get(
        Uri.parse('$kApiBaseUrl/home/pro-vendor-sections/'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> getProVendorSectionFull(
    int sectionId,
  ) async {
    final res = await http.get(
      Uri.parse('$kApiBaseUrl/home/pro-vendor-sections/$sectionId/full/'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return {'items': []};
  }

  // ---------- Curations ----------

  static Future<List<dynamic>> getCurations() async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/curations/sections/'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }
  // ---------- Service Forms ----------

  static Future<List<dynamic>> getFormByService({
    int? serviceId,
    int? subcategoryId,
    int? categoryId,
  }) async {
    String query = '';
    if (serviceId != null)
      query = 'service_id=$serviceId';
    else if (subcategoryId != null)
      query = 'subcategory_id=$subcategoryId';
    else if (categoryId != null)
      query = 'category_id=$categoryId';

    final res = await http.get(
      Uri.parse('$kApiBaseUrl/forms/by-service/?$query'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<int> submitForm({
    required int formId,
    required List<Map<String, dynamic>> responses,
  }) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/forms/submit/'),
      headers: headers,
      body: jsonEncode({'form': formId, 'responses': responses}),
    );
    if (res.statusCode == 201) {
      final data = jsonDecode(res.body);
      return data['id'];
    }
    throw Exception(_extractFirstError(jsonDecode(res.body)));
  }
  // ---------- Reviews ----------

  static Future<void> submitReview({
    required int bookingId,
    required int rating,
    required String comment,
  }) async {
    var headers = await _authHeaders();
    var res = await http.post(
      Uri.parse('$kApiBaseUrl/reviews/create/'),
      headers: headers,
      body: jsonEncode({
        'booking': bookingId,
        'rating': rating,
        'comment': comment,
      }),
    );
    if (res.statusCode == 401) {
      if (await _tryRefreshToken()) {
        headers = await _authHeaders();
        res = await http.post(
          Uri.parse('$kApiBaseUrl/reviews/create/'),
          headers: headers,
          body: jsonEncode({
            'booking': bookingId,
            'rating': rating,
            'comment': comment,
          }),
        );
      } else {
        await _forceLogout();
        throw Exception('Session expired. Please log in again.');
      }
    }
    if (res.statusCode != 201) {
      throw Exception(_extractFirstError(jsonDecode(res.body)));
    }
  }

  static Future<Map<String, dynamic>> getBookingReview(int bookingId) async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$kApiBaseUrl/reviews/booking/$bookingId/'),
      headers: headers,
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return {'reviewed': false};
  }

  static Future<Map<String, dynamic>> getVendorReviews(int vendorId) async {
    final res = await http.get(
      Uri.parse('$kApiBaseUrl/reviews/vendor/$vendorId/'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return {'average_rating': 0, 'total_reviews': 0, 'reviews': []};
  }

  static Future<Map<String, dynamic>> getIndividualServiceReviews(
    int serviceId,
  ) async {
    final res = await http.get(
      Uri.parse('$kApiBaseUrl/reviews/individual-service/$serviceId/'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return {'average_rating': 0, 'total_reviews': 0, 'reviews': []};
  }

  static Future<Map<String, dynamic>> getServiceReviews(int categoryId) async {
    final res = await http.get(
      Uri.parse('$kApiBaseUrl/reviews/service/$categoryId/'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return {'average_rating': 0, 'total_reviews': 0, 'reviews': []};
  }
  // ---------- Discounts ----------

  static Future<Map<String, dynamic>> getApplicableDiscount({
    required List<Map<String, dynamic>> items,
  }) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/discounts/applicable/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'items': items}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return {'discount': null, 'discount_amount': '0'};
  }

  static Future<Map<String, dynamic>> validateCoupon({
    required String code,
    required double cartTotal,
  }) async {
    var headers = await _authHeaders();
    var res = await http.post(
      Uri.parse('$kApiBaseUrl/discounts/coupon/'),
      headers: headers,
      body: jsonEncode({'code': code, 'cart_total': cartTotal}),
    );
    if (res.statusCode == 401) {
      if (await _tryRefreshToken()) {
        headers = await _authHeaders();
        res = await http.post(
          Uri.parse('$kApiBaseUrl/discounts/coupon/'),
          headers: headers,
          body: jsonEncode({'code': code, 'cart_total': cartTotal}),
        );
      } else {
        await _forceLogout();
        throw Exception('Session expired. Please log in again.');
      }
    }
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(_extractFirstError(jsonDecode(res.body)));
  }

  static Future<Map<String, dynamic>> getHomeSectionFull(int sectionId) async {
    final res = await http.get(
      Uri.parse('$kApiBaseUrl/home/sections/$sectionId/full/'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return {'items': []};
  }
  // ---------- Support ----------

  static Future<List<dynamic>> getMyTickets() async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$kApiBaseUrl/support/my/'),
      headers: headers,
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<int> createTicket({
    required String subject,
    required String category,
    required String message,
    int? bookingId,
  }) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/support/create/'),
      headers: headers,
      body: jsonEncode({
        'subject': subject,
        'category': category,
        'message': message,
        if (bookingId != null) 'booking': bookingId,
      }),
    );
    if (res.statusCode == 201) {
      return jsonDecode(res.body)['id'];
    }
    throw Exception('Failed to create ticket');
  }

  static Future<Map<String, dynamic>> getTicketDetail(int ticketId) async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$kApiBaseUrl/support/$ticketId/'),
      headers: headers,
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load ticket');
  }

  static Future<void> addTicketMessage({
    required int ticketId,
    required String message,
  }) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/support/$ticketId/message/'),
      headers: headers,
      body: jsonEncode({'message': message}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to send message');
    }
  }

  // ---------- Payments (Razorpay) ----------

  /// Opens a Razorpay order for a booking and returns what Checkout needs:
  /// `order_id`, `amount` (paise), `key_id`, `currency`.
  ///
  /// The amount is decided by the server from the booking -- deliberately not
  /// a parameter here, so the app has no way to influence what is charged.
  static Future<Map<String, dynamic>> createPaymentOrder(int bookingId) async {
    var headers = await _authHeaders();
    final url = Uri.parse('$kApiBaseUrl/payments/order/');
    final body = jsonEncode({'booking_id': bookingId});

    var res = await http.post(url, headers: headers, body: body);
    if (res.statusCode == 401 && await _tryRefreshToken()) {
      headers = await _authHeaders();
      res = await http.post(url, headers: headers, body: body);
    }
    if (res.statusCode == 201) return jsonDecode(res.body);
    throw Exception(_extractFirstError(jsonDecode(res.body)));
  }

  /// Hands Checkout's three return values to the server, which verifies the
  /// signature and confirms with Razorpay before marking the booking paid.
  static Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    var headers = await _authHeaders();
    final url = Uri.parse('$kApiBaseUrl/payments/verify/');
    final body = jsonEncode({
      'razorpay_order_id': orderId,
      'razorpay_payment_id': paymentId,
      'razorpay_signature': signature,
    });

    var res = await http.post(url, headers: headers, body: body);
    if (res.statusCode == 401 && await _tryRefreshToken()) {
      headers = await _authHeaders();
      res = await http.post(url, headers: headers, body: body);
    }
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(_extractFirstError(jsonDecode(res.body)));
  }

  /// The server's own view of what has been paid on a booking.
  ///
  /// This is the reconciliation path: if verifying fails because the network
  /// dropped, Razorpay's webhook still reaches the server, so asking here a
  /// moment later gives the true answer without charging anyone twice.
  static Future<Map<String, dynamic>> getBookingPaymentStatus(
    int bookingId,
  ) async {
    final res = await _authorizedGet(
      '$kApiBaseUrl/payments/booking/$bookingId/',
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Could not check the payment status.');
  }

  static Future<List<dynamic>> getMyPayments() async {
    final res = await _authorizedGet('$kApiBaseUrl/payments/my/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Could not load your payments.');
  }

  // ---------- Tenders (post a requirement, vendors bid on it) ----------
  //
  // The flow: create a DRAFT, attach drawings, publish for admin review, then
  // compare the bids that come in and award one.

  /// Runs [send], and if the token has expired, refreshes it and retries once.
  static Future<http.Response> _withAuth(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    var res = await send(await _authHeaders());
    if (res.statusCode == 401) {
      if (await _tryRefreshToken()) {
        res = await send(await _authHeaders());
      } else {
        await _forceLogout();
        throw Exception('Session expired. Please log in again.');
      }
    }
    return res;
  }

  /// Reads the server's error message, falling back to something readable
  /// when the body is HTML from a crash or a proxy rather than JSON.
  static String _errorFrom(http.Response res, String fallback) {
    try {
      return _extractFirstError(jsonDecode(res.body));
    } catch (_) {
      return fallback;
    }
  }

  /// Creates the tender as a DRAFT. Nothing is visible to vendors until it is
  /// published and an admin approves it.
  static Future<Map<String, dynamic>> createTender({
    required String title,
    required String projectType,
    required int categoryId,
    int? subcategoryId,
    required String description,
    String requirements = '',
    int? areaSqft,
    required String expectedBudget,
    String? preferredStartDate,
    int? durationDays,
    String? bidDeadline,
    String addressText = '',
    String addressState = '',
    String addressDistrict = '',
    String addressPincode = '',
    String contactPhone = '',
    double? latitude,
    double? longitude,
  }) async {
    final body = jsonEncode({
      'title': title,
      'project_type': projectType,
      'category': categoryId,
      if (subcategoryId != null) 'subcategory': subcategoryId,
      'description': description,
      'requirements': requirements,
      if (areaSqft != null) 'area_sqft': areaSqft,
      'expected_budget': expectedBudget,
      if (preferredStartDate != null)
        'preferred_start_date': preferredStartDate,
      if (durationDays != null) 'duration_days': durationDays,
      if (bidDeadline != null) 'bid_deadline': bidDeadline,
      'address_text': addressText,
      'address_state': addressState,
      'address_district': addressDistrict,
      'address_pincode': addressPincode,
      'contact_phone': contactPhone,
      if (latitude != null) 'location_lat': latitude.toStringAsFixed(6),
      if (longitude != null) 'location_lng': longitude.toStringAsFixed(6),
    });

    final res = await _withAuth(
      (headers) => http.post(
        Uri.parse('$kApiBaseUrl/tenders/'),
        headers: headers,
        body: body,
      ),
    );
    if (res.statusCode == 201) return jsonDecode(res.body);
    throw Exception(_errorFrom(res, 'Could not post your tender.'));
  }

  static Future<List<dynamic>> getMyTenders({String? status}) async {
    final query = status == null || status.isEmpty ? '' : '?status=$status';
    final res = await _withAuth(
      (headers) => http.get(
        Uri.parse('$kApiBaseUrl/tenders/my/$query'),
        headers: headers,
      ),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Could not load your tenders.');
  }

  static Future<Map<String, dynamic>> getTenderDetail(int tenderId) async {
    final res = await _withAuth(
      (headers) => http.get(
        Uri.parse('$kApiBaseUrl/tenders/$tenderId/'),
        headers: headers,
      ),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Could not load this tender.');
  }

  /// Edits a tender. Only allowed while it is a draft or has been sent back.
  static Future<Map<String, dynamic>> updateTender(
    int tenderId,
    Map<String, dynamic> fields,
  ) async {
    final body = jsonEncode(fields);
    final res = await _withAuth(
      (headers) => http.patch(
        Uri.parse('$kApiBaseUrl/tenders/$tenderId/'),
        headers: headers,
        body: body,
      ),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(_errorFrom(res, 'Could not save your changes.'));
  }

  static Future<void> deleteTender(int tenderId) async {
    final res = await _withAuth(
      (headers) => http.delete(
        Uri.parse('$kApiBaseUrl/tenders/$tenderId/'),
        headers: headers,
      ),
    );
    if (res.statusCode != 204) {
      throw Exception(_errorFrom(res, 'Could not delete this tender.'));
    }
  }

  /// Sends the tender for admin review. It reaches vendors once approved.
  static Future<void> publishTender(int tenderId) async {
    final res = await _withAuth(
      (headers) => http.post(
        Uri.parse('$kApiBaseUrl/tenders/$tenderId/publish/'),
        headers: headers,
      ),
    );
    if (res.statusCode != 200) {
      throw Exception(_errorFrom(res, 'Could not publish this tender.'));
    }
  }

  static Future<void> cancelTender(int tenderId, {String reason = ''}) async {
    final body = jsonEncode({'reason': reason});
    final res = await _withAuth(
      (headers) => http.post(
        Uri.parse('$kApiBaseUrl/tenders/$tenderId/cancel/'),
        headers: headers,
        body: body,
      ),
    );
    if (res.statusCode != 200) {
      throw Exception(_errorFrom(res, 'Could not cancel this tender.'));
    }
  }

  /// Attaches a drawing or site photo. Multipart, so it does not go through
  /// [_withAuth] — the body would have to be rebuilt on the retry anyway.
  static Future<Map<String, dynamic>> uploadTenderAttachment({
    required int tenderId,
    required File file,
    String caption = '',
  }) async {
    final uri = Uri.parse('$kApiBaseUrl/tenders/$tenderId/attachments/');

    Future<http.Response> send() async {
      final token = await getAccessToken();
      final request = http.MultipartRequest('POST', uri);
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (caption.isNotEmpty) request.fields['caption'] = caption;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      return http.Response.fromStream(await request.send());
    }

    var res = await send();
    if (res.statusCode == 401) {
      if (await _tryRefreshToken()) {
        res = await send();
      } else {
        await _forceLogout();
        throw Exception('Session expired. Please log in again.');
      }
    }
    if (res.statusCode == 201) return jsonDecode(res.body);
    throw Exception(_errorFrom(res, 'Could not upload that file.'));
  }

  static Future<void> deleteTenderAttachment(int attachmentId) async {
    final res = await _withAuth(
      (headers) => http.delete(
        Uri.parse('$kApiBaseUrl/tenders/attachments/$attachmentId/'),
        headers: headers,
      ),
    );
    if (res.statusCode != 204) {
      throw Exception(_errorFrom(res, 'Could not remove that attachment.'));
    }
  }

  /// The quotes to compare. [sort] is 'amount', 'timeline' or 'rating'.
  static Future<List<dynamic>> getTenderBids(
    int tenderId, {
    String sort = 'amount',
  }) async {
    final res = await _withAuth(
      (headers) => http.get(
        Uri.parse('$kApiBaseUrl/tenders/$tenderId/bids/?sort=$sort'),
        headers: headers,
      ),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Could not load the bids.');
  }

  /// Chooses this bid. The choice is *held*, not awarded: the response comes
  /// back with a `fee` the customer has to pay to confirm it, and only then
  /// is the vendor told and every other bid turned down.
  ///
  /// `fee` is null when the platform is not charging one, in which case the
  /// tender is awarded on the spot.
  static Future<Map<String, dynamic>> acceptTenderBid(int bidId) async {
    final res = await _withAuth(
      (headers) => http.post(
        Uri.parse('$kApiBaseUrl/tenders/bids/$bidId/accept/'),
        headers: headers,
      ),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(_errorFrom(res, 'Could not accept this bid.'));
  }

  /// Opens a Razorpay order for the confirmation fee owed on this tender.
  ///
  /// The amount comes back from the server, which worked it out from the bid
  /// and the rate the admin set — the app never composes a fee of its own.
  static Future<Map<String, dynamic>> createTenderConfirmationOrder(
    int tenderId,
  ) async {
    final res = await _withAuth(
      (headers) => http.post(
        Uri.parse('$kApiBaseUrl/tenders/$tenderId/confirmation/'),
        headers: headers,
      ),
    );
    if (res.statusCode == 201) return jsonDecode(res.body);
    throw Exception(_errorFrom(res, 'Could not start the payment.'));
  }

  /// Hands Checkout's three return values to the server, which verifies the
  /// signature and confirms with Razorpay before awarding the tender.
  static Future<Map<String, dynamic>> verifyTenderConfirmationPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final body = jsonEncode({
      'razorpay_order_id': orderId,
      'razorpay_payment_id': paymentId,
      'razorpay_signature': signature,
    });
    final res = await _withAuth(
      (headers) => http.post(
        Uri.parse('$kApiBaseUrl/tenders/confirmation/verify/'),
        headers: headers,
        body: body,
      ),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(_errorFrom(res, 'Payment could not be verified.'));
  }

  /// The server's own view of the confirmation fee on this tender.
  ///
  /// The reconciliation path, exactly as for bookings: if verifying fails
  /// because the network dropped, Razorpay's webhook still reaches the
  /// server, so asking here a moment later gives the true answer without
  /// anyone paying twice.
  static Future<Map<String, dynamic>> getTenderConfirmationStatus(
    int tenderId,
  ) async {
    final res = await _authorizedGet(
      '$kApiBaseUrl/tenders/$tenderId/confirmation/',
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Could not check the payment status.');
  }

  /// Gives up a held choice without paying. The bid goes back in the pile and
  /// the tender is open for bidding again.
  static Future<void> releaseTenderSelection(int tenderId) async {
    final res = await _withAuth(
      (headers) => http.delete(
        Uri.parse('$kApiBaseUrl/tenders/$tenderId/confirmation/'),
        headers: headers,
      ),
    );
    if (res.statusCode != 200) {
      throw Exception(_errorFrom(res, 'Could not release your choice.'));
    }
  }

  /// Records a milestone as settled. No money moves here — the payment
  /// happens between the customer and the vendor directly.
  static Future<Map<String, dynamic>> payTenderMilestone(
    int milestoneId,
  ) async {
    final res = await _withAuth(
      (headers) => http.post(
        Uri.parse('$kApiBaseUrl/tenders/milestones/$milestoneId/pay/'),
        headers: headers,
      ),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(_errorFrom(res, 'Could not record that payment.'));
  }

  static Future<void> submitTenderReview({
    required int tenderId,
    required int rating,
    String comment = '',
  }) async {
    final body = jsonEncode({'rating': rating, 'comment': comment});
    final res = await _withAuth(
      (headers) => http.post(
        Uri.parse('$kApiBaseUrl/tenders/$tenderId/review/'),
        headers: headers,
        body: body,
      ),
    );
    if (res.statusCode != 201) {
      throw Exception(_errorFrom(res, 'Could not submit your review.'));
    }
  }
}
