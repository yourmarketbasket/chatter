import 'package:flutter/material.dart';

Color getColorFromHex(String hexColor) {
  hexColor = hexColor.toUpperCase().replaceAll("#", "");
  if (hexColor.length == 6) {
    hexColor = "FF" + hexColor;
  }
  return Color(int.parse(hexColor, radix: 16));
}

Color getVerificationBadgeColor(String? entityType, String? level) {
  if (entityType == null || entityType == 'N/A') {
    return getColorFromHex("#0000FF"); // Blue for Free/Unverified
  }

  switch (entityType) {
    case 'individual':
      switch (level) {
        case 'basic':
          return getColorFromHex("#008000"); // Green
        case 'intermediate':
          return getColorFromHex("#FFD700"); // Gold
        case 'premium':
          return getColorFromHex("#800080"); // Purple
        default:
          return getColorFromHex("#0000FF");
      }
    case 'organization':
      switch (level) {
        case 'basic':
          return getColorFromHex("#00008B"); // Dark Blue
        case 'intermediate':
          return getColorFromHex("#FFA500"); // Orange
        case 'premium':
          return getColorFromHex("#A52A2A"); // Brown
        default:
          return getColorFromHex("#0000FF");
      }
    case 'government':
      switch (level) {
        case 'basic':
          return getColorFromHex("#FFFFFF"); // White
        case 'intermediate':
          return getColorFromHex("#D3D3D3"); // Light Gray
        case 'premium':
          return getColorFromHex("#808080"); // Gray
        default:
          return getColorFromHex("#0000FF");
      }
    default:
      return getColorFromHex("#0000FF");
  }
}
