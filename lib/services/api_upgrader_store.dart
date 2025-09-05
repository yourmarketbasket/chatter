import 'package:get/get.dart';
import 'package:upgrader/upgrader.dart';
import 'package:chatter/controllers/data-controller.dart';

class ApiUpgraderStore extends UpgraderStore {
  final DataController _dataController = Get.find<DataController>();

  ApiUpgraderStore() {
    // The initialize method is called by the Upgrader package.
  }

  @override
  Future<void> initialize() async {
    // This is where we will override the default behavior.
    // We will call our own API to check for updates.
    print('[ApiUpgraderStore] Initializing custom upgrader store.');
    await super.initialize(); // It's good practice to call the parent's initialize.

    final updateData = await _dataController.getLatestAppUpdate();

    if (updateData != null) {
      final version = updateData['version'] as String?;
      final notes = updateData['notes'] as String?;
      final url = updateData['url'] as String?;
      // The backend will need to specify if an update is critical.
      // For now, let's assume a field 'isCritical' or similar.
      // The `upgrader` package uses `minAppVersion` for this. If the new version
      // is greater than the minAppVersion from the store, it's a critical update.
      // We can simulate this by setting a minAppVersion if our API says so.
      final minAppVersion = updateData['minAppVersion'] as String?;

      if (version != null && url != null) {
        print('[ApiUpgraderStore] Found update: $version, URL: $url');
        // Save the fetched update data into the store for Upgrader to use.
        savePendingUpdate(version, notes, url, minAppVersion);
      } else {
        print('[ApiUpgraderStore] No update found or data is incomplete.');
      }
    } else {
      print('[ApiUpgraderStore] Failed to fetch update data from API.');
    }
  }
}
