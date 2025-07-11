import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BuyMeACoffeePage extends StatelessWidget {
  const BuyMeACoffeePage({super.key});

  final String btcAddress = 'bc1qe79qj786sek33ujy2hz8edpd3mahnupllhwz6z';
  final String networkInfo =
      'Binance supports deposits from all BTC addresses (starting with "1", "3", "bc1p" and "bc1q")';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Me a Coffee'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'If you\'d like to support the development of this app, you can send some Bitcoin to the address below.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            const Text(
              'BTC Address:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(
              btcAddress,
              style: const TextStyle(fontSize: 16, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copy Address'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: btcAddress));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('BTC Address copied to clipboard!')),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Network Information:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              networkInfo,
              style: const TextStyle(fontSize: 16),
            ),
            const Spacer(),
            const Center(
              child: Text(
                'Thank you for your support! ❤️',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
