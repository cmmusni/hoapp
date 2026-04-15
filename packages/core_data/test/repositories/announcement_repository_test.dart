import 'package:flutter_test/flutter_test.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_data/core_data.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('AnnouncementRepository', () {
    test('Announcement model can be created with required fields', () {
      final announcement = createMockAnnouncement(
        title: 'Test Announcement',
        pinned: true,
      );

      expect(announcement.title, equals('Test Announcement'));
      expect(announcement.pinned, isTrue);
      expect(announcement.communityId, isNotEmpty);
      expect(announcement.body, isNotEmpty);
    });

    test('Announcement.fromJson parses valid JSON correctly', () {
      final now = DateTime.now();
      final json = {
        'id': '1',
        'community_id': 'community-1',
        'title': 'Test',
        'body': 'Body text',
        'pinned': false,
        'publish_at': now.toIso8601String(),
        'created_by': 'user-1',
        'created_at': now.toIso8601String(),
        'is_archived': false,
      };

      final announcement = Announcement.fromJson(json);

      expect(announcement.id, equals('1'));
      expect(announcement.communityId, equals('community-1'));
      expect(announcement.title, equals('Test'));
      expect(announcement.body, equals('Body text'));
      expect(announcement.pinned, isFalse);
      expect(announcement.isArchived, isFalse);
    });

    test('Announcement.toJson produces valid JSON', () {
      final announcement = createMockAnnouncement();
      final json = announcement.toJson();

      expect(json['id'], isNotNull);
      expect(json['community_id'], isNotNull);
      expect(json['title'], isNotNull);
      expect(json['body'], isNotNull);
      expect(json.containsKey('pinned'), isTrue);
    });

    test('Announcement with pinned=true serializes correctly', () {
      final announcement = createMockAnnouncement(pinned: true);
      final json = announcement.toJson();

      expect(json['pinned'], isTrue);
    });

    test('Announcement isArchived defaults to false', () {
      final announcement = createMockAnnouncement();
      expect(announcement.isArchived, isFalse);
    });
  });
}
