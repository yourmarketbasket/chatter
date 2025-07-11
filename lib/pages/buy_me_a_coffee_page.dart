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
  final String legacyNetworkInfo = 'For use with wallets that only support legacy BTC addresses (starting with "1", "3", "bc1p" and "bc1q").';


  Widget _buildAddressSection(BuildContext context, String title, String address, String networkInfo, String heroTag) {
    // Use explicit colors for better contrast control on the dark background
    const Color titleColor = Colors.white;
    const Color addressColor = Color(0xFFE0E0E0); // Light grey for address
    const Color networkInfoColor = Color(0xFFBDBDBD); // Medium grey for network info
    const Color buttonTextColor = Color(0xFF121212); // Dark text for light button
    const Color buttonBackgroundColor = Colors.tealAccent;
    final Color snackBarBackgroundColor = Colors.grey[850]!; // Darker grey for snackbar

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 20, // Slightly larger title
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2), // Slightly darker background for address block
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[700]!, width: 0.5),
          ),
          child: SelectableText(
            address,
            style: GoogleFonts.robotoMono(
              fontSize: 16, // Slightly larger address text
              color: addressColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          networkInfo,
          style: GoogleFonts.roboto(
            fontSize: 14, // Slightly larger network info
            color: networkInfoColor,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: Icon(FeatherIcons.copy, size: 20, color: buttonTextColor),
          label: Text(
            'Copy Address',
            style: GoogleFonts.roboto(
                color: buttonTextColor,
                fontWeight: FontWeight.bold, // Bolder button text
                fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonBackgroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), // More padding
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25), // More rounded corners for "elegant" feel
            ),
            elevation: 2, // Subtle shadow
          ),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: address));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$title copied to clipboard!', style: GoogleFonts.roboto(color: Colors.white)),
                backgroundColor: snackBarBackgroundColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Explicit colors for main page elements
    const Color pageBackgroundColor = Color(0xFF121212);
    const Color appBarBackgroundColor = Color(0xFF1E1E1E); // Slightly different dark for app bar
    const Color appBarTitleColor = Colors.white;
    const Color introTextColor = Color(0xFFE0E0E0); // Light grey for intro text
    const Color thankYouTextColor = Colors.white;
    final Color dividerColor = Colors.grey[800]!;

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Buy Me a Coffee',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: appBarTitleColor,
          ),
        ),
        backgroundColor: appBarBackgroundColor,
        elevation: 1, // Add a slight elevation to appbar
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Your support helps keep this app running and ad-free. If you find it useful, please consider sending a tip!',
              style: GoogleFonts.roboto(
                fontSize: 17, // Slightly larger intro text
                color: introTextColor,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 35),
            _buildAddressSection(
              context,
              'BTC (SegWit/Bech32)',
              btcSegwitAddress,
              segwitNetworkInfo,
              'segwit-copy-button',
            ),
            const SizedBox(height: 35),
            Divider(color: dividerColor, thickness: 0.5),
            const SizedBox(height: 35),
            _buildAddressSection(
              context,
              'BTC (Legacy)',
              btcLegacyAddress,
              legacyNetworkInfo,
              'legacy-copy-button',
            ),
            const SizedBox(height: 45),
            Center(
              child: Column(
                children: [
                  Icon(FeatherIcons.gift, color: Colors.tealAccent, size: 32), // Changed icon
                  const SizedBox(height: 12),
                  Text(
                    'Thank you for your generosity!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 19, // Slightly larger thank you
                      fontWeight: FontWeight.w500,
                      color: thankYouTextColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }
}
