import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class AmenityRepository {
  final SupabaseClient _client = SupabaseClientManager.instance;

  /// Get all amenities for a community
  /// Supports search and pagination
  Future<List<Amenity>> getAmenities(
    String communityId, {
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    var query =
        _client.from('amenities').select().eq('community_id', communityId);

    // Add search filter if provided (search by name)
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('name', '%$searchQuery%');
    }

    // Build the final query with ordering and pagination
    var finalQuery = query.order('name');

    if (limit != null && offset != null) {
      finalQuery = finalQuery.limit(limit).range(offset, offset + limit - 1);
    } else if (limit != null) {
      finalQuery = finalQuery.limit(limit);
    }

    final response = await finalQuery;

    return (response as List).map((item) => Amenity.fromJson(item)).toList();
  }

  /// Get total count of amenities for pagination
  Future<int> getAmenitiesCount(
    String communityId, {
    String? searchQuery,
  }) async {
    var query =
        _client.from('amenities').select('id').eq('community_id', communityId);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('name', '%$searchQuery%');
    }

    final response = await query;
    return (response as List).length;
  }

  /// Get single amenity
  Future<Amenity?> getAmenity(String id) async {
    final response =
        await _client.from('amenities').select().eq('id', id).maybeSingle();

    if (response == null) return null;
    return Amenity.fromJson(response);
  }

  /// Create amenity (staff only)
  Future<String> createAmenity({
    required String communityId,
    required String name,
    Map<String, dynamic>? rules,
  }) async {
    final response = await _client
        .from('amenities')
        .insert({
          'community_id': communityId,
          'name': name,
          'rules': rules ?? {},
        })
        .select()
        .single();

    return response['id'] as String;
  }

  /// Update amenity rules (staff only)
  Future<void> updateAmenity(String id, Map<String, dynamic> updates) async {
    await _client.from('amenities').update(updates).eq('id', id);
  }

  /// Get bookings for an amenity
  /// Supports search and pagination
  Future<List<AmenityBooking>> getBookings({
    required String amenityId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    var query =
        _client.from('amenity_bookings').select().eq('amenity_id', amenityId);

    // Filter by date range if provided
    // Note: For tstzrange filtering, you'd use overlaps with range

    // Add search filter if provided (search by status)
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('status', '%$searchQuery%');
    }

    // Build the final query with ordering and pagination
    var finalQuery = query.order('created_at', ascending: false);

    if (limit != null && offset != null) {
      finalQuery = finalQuery.limit(limit).range(offset, offset + limit - 1);
    } else if (limit != null) {
      finalQuery = finalQuery.limit(limit);
    }

    final response = await finalQuery;

    return (response as List)
        .map((item) => AmenityBooking.fromJson(item))
        .toList();
  }

  /// Get total count of bookings for pagination
  Future<int> getBookingsCount({
    required String amenityId,
    String? searchQuery,
  }) async {
    var query = _client
        .from('amenity_bookings')
        .select('id')
        .eq('amenity_id', amenityId);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('status', '%$searchQuery%');
    }

    final response = await query;
    return (response as List).length;
  }

  /// Get user's bookings
  Future<List<AmenityBooking>> getUserBookings(String communityId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('amenity_bookings')
        .select()
        .eq('community_id', communityId)
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => AmenityBooking.fromJson(item))
        .toList();
  }

  /// Book amenity via Edge Function (handles validation)
  /// Set [noVerify] to true to skip pool access and household checks.
  Future<String> bookAmenity({
    required String amenityId,
    required String targetDate,
    required String unitId,
    bool noVerify = false,
  }) async {
    final response = await _client.functions.invoke(
      'book_amenity',
      body: {
        'amenity_id': amenityId,
        'target_date': targetDate,
        'unit_id': unitId,
        if (noVerify) 'no_verify': true,
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'Booking failed');
    }

    return data['booking_id'] as String;
  }

  /// Approve booking (staff only) - sets status to confirmed
  Future<void> approveBooking(String bookingId) async {
    await _client.from('amenity_bookings').update({
      'status': 'confirmed',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', bookingId);
  }

  /// Cancel booking
  Future<void> cancelBooking(String bookingId) async {
    await _client.from('amenity_bookings').update({
      'status': 'cancelled',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', bookingId);
  }

  /// Get all bookings for a community (staff only)
  Future<List<AmenityBooking>> getAllBookings(String communityId) async {
    final response = await _client
        .from('amenity_bookings')
        .select()
        .eq('community_id', communityId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => AmenityBooking.fromJson(item))
        .toList();
  }

  /// Delete amenity (staff only)
  Future<void> deleteAmenity(String id) async {
    await _client.from('amenities').delete().eq('id', id);
  }
}
