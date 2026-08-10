import 'dart:convert';
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
    await logout();
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
}
