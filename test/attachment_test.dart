import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:chatter/pages/new-posts-page.dart' show Attachment;

void main() {
  group('Attachment toJson', () {
    test('should return correct map when all fields are populated', () {
      // Arrange
      final file = File('dummy.txt');
      final attachment = Attachment(
        file: file,
        type: 'image',
        filename: 'dummy.txt',
        url: 'http://example.com/dummy.txt',
        size: 12345,
      );

      // Act
      final json = attachment.toJson();

      // Assert
      expect(json, {
        'filename': 'dummy.txt',
        'type': 'image',
        'url': 'http://example.com/dummy.txt',
        'size': 12345,
      });
    });

    test('should return correct map when optional fields (url, size) are null', () {
      // Arrange
      final file = File('another_dummy.png');
      final attachment = Attachment(
        file: file,
        type: 'image',
        filename: 'another_dummy.png',
        url: null,
        size: null,
      );

      // Act
      final json = attachment.toJson();

      // Assert
      expect(json, {
        'filename': 'another_dummy.png',
        'type': 'image',
        'url': null,
        'size': null,
      });
    });

    test('should return correct map when type is different and url/size are null', () {
      // Arrange
      final file = File('test_audio.mp3');
      final attachment = Attachment(
        file: file,
        type: 'audio',
        filename: 'test_audio.mp3',
        // url and size default to null if not provided
      );

      // Act
      final json = attachment.toJson();

      // Assert
      expect(json, {
        'filename': 'test_audio.mp3',
        'type': 'audio',
        'url': null,
        'size': null,
      });
    });
  });
}
