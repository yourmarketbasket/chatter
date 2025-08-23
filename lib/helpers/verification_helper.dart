import 'package:flutter/material.dart';

Color getVerificationBadgeColor(String entityType, String level) {
  switch (entityType) {
    case 'individual':
      switch (level) {
        case 'basic':
          return Colors.green;
        case 'intermediate':
          return Colors.yellow;
        case 'premium':
          return Colors.red;
        default:
          return Colors.grey;
      }
    case 'organization':
      switch (level) {
        case 'basic':
          return Colors.blue;
        case 'intermediate':
          return Colors.purple;
        case 'premium':
          return Colors.orange;
        default:
          return Colors.grey;
      }
    case 'government':
      switch (level) {
        case 'basic':
          return Colors.white;
        case 'intermediate':
          return Colors.black;
        case 'premium':
          return const Color(0xFF6D4C41); // Brown
        default:
          return Colors.grey;
      }
    default:
      return Colors.grey;
  }
}
