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
    return getColorFromHex("#94A3B8"); // Light Slate Blue
  }

  switch (entityType) {
    case 'individual':
      switch (level) {
        case 'basic':
          return getColorFromHex("#E8D5A1"); // Pale Gold
        case 'intermediate':
          return getColorFromHex("#D4A017"); // Classic Gold
        case 'premium':
          return getColorFromHex("#475569"); // Deep Slate Blue
        default:
          return getColorFromHex("#94A3B8");
      }
    case 'organization':
      switch (level) {
        case 'basic':
          return getColorFromHex("#2D3B45"); // Dark Greyish Blue
        case 'intermediate':
          return getColorFromHex("#B8975B"); // Burnished Gold
        case 'premium':
          return getColorFromHex("#334155"); // Charcoal Slate
        default:
          return getColorFromHex("#94A3B8");
      }
    case 'government':
      switch (level) {
        case 'basic':
          return getColorFromHex("#E2E8F0"); // Soft Greyish White
        case 'intermediate':
          return getColorFromHex("#6B7280"); // Cool Grey
        case 'premium':
          return getColorFromHex("#1F2937"); // Deep Charcoal
        default:
          return getColorFromHex("#94A3B8");
      }
    default:
      return getColorFromHex("#94A3B8");
  }
}
