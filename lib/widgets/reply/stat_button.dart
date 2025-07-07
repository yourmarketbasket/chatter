import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onPressed;

  const StatButton({
    Key? key,
    required this.icon,
    required this.text,
    required this.color,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min, // Allow row to shrink to content
        children: [
          Icon(icon, size: 16, color: color), // Reduced icon size
          if (text.isNotEmpty) ...[
            const SizedBox(width: 3), // Slightly reduced spacing
            Text(
              text,
              style: GoogleFonts.roboto(
                color: Colors.white70,
                fontSize: 11, // Slightly reduced font size for text next to icon
              ),
            ),
          ],
          const SizedBox(width: 4), // Reduced spacing at the end of the button
        ],
      ),
    );
  }
}
