import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';

class BuyMeACoffeePage extends StatelessWidget {
  const BuyMeACoffeePage({super.key});

  final String btcSegwitAddress = 'bc1qe79qj786sek33ujy2hz8edpd3mahnupllhwz6z';
  final String segwitNetworkInfo =
      'Supports deposits from all BTC addresses (Legacy, SegWit, Bech32, etc., starting with "1", "3", "bc1p" and "bc1q").';
  final String btcLegacyAddress = '1EXu3QeiySmF7HqT7363VvPJawh7oBU6yK';
  final String legacyNetworkInfo = 'For use with wallets that only support legacy BTC addresses (starting with "1").';


  Widget _buildAddressSection(BuildContext context, String title, String address, String networkInfo, String heroTag) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.textTheme.titleLarge?.color ?? Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        SelectableText(
          address,
          style: GoogleFonts.robotoMono( // Monospaced font for address
            fontSize: 15,
            color: theme.textTheme.bodyMedium?.color ?? Colors.grey[300],
            backgroundColor: Colors.black.withOpacity(0.1),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          networkInfo,
          style: GoogleFonts.roboto(
            fontSize: 13,
            color: theme.textTheme.bodySmall?.color ?? Colors.grey[400],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: Icon(FeatherIcons.copy, size: 18, color: Colors.black),
          label: Text(
            'Copy Address',
            style: GoogleFonts.roboto(color: Colors.black, fontWeight: FontWeight.w500),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.tealAccent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: address));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$title copied to clipboard!', style: GoogleFonts.roboto(color: Colors.white)),
                backgroundColor: Colors.grey[800],
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get the current theme

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Consistent background with app_drawer
      appBar: AppBar(
        title: Text(
          'Buy Me a Coffee',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white, // Explicitly white for AppBar title
          ),
        ),
        backgroundColor: Colors.teal[700], // Match drawer header
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Your support helps keep this app running and ad-free. If you find it useful, please consider sending a tip!',
              style: GoogleFonts.roboto(
                fontSize: 16,
                color: theme.textTheme.bodyLarge?.color ?? Colors.grey[200],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            _buildAddressSection(
              context,
              'BTC (SegWit/Bech32)',
              btcSegwitAddress,
              segwitNetworkInfo,
              'segwit-copy-button',
            ),
            const SizedBox(height: 30),
            Divider(color: Colors.grey[700]),
            const SizedBox(height: 30),
            _buildAddressSection(
              context,
              'BTC (Legacy)',
              btcLegacyAddress,
              legacyNetworkInfo,
              'legacy-copy-button',
            ),
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(FeatherIcons.heart, color: Colors.redAccent, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    'Thank you for your generosity!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: theme.textTheme.titleMedium?.color ?? Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
