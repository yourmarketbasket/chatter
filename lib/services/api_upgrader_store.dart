import 'package:get/get.dart';
import 'package:upgrader/upgrader.dart';
import 'package:chatter/controllers/data-controller.dart';

class ApiUpgraderStore extends UpgraderStore {
  final DataController _dataController = Get.find<DataController>();

  ApiUpgraderStore();

  @override
  Future<UpgraderVersionInfo> getVersionInfo(String? countryCode, String? languageCode) async {
    print('[ApiUpgraderStore] Getting version info from custom API.');

    final updateData = await _dataController.getLatestAppUpdate();

    if (updateData != null) {
      final version = updateData['version'] as String?;
      final notes = updateData['notes'] as String?;
      final url = updateData['url'] as String?;
      final minAppVersion = updateData['minAppVersion'] as String?;

      if (version != null && url != null) {
        print('[ApiUpgraderStore] Found update: $version, URL: $url');
        return UpgraderVersionInfo(
          appStoreVersion: version,
          releaseNotes: notes,
          appStoreListingURL: url,
          minAppVersion: minAppVersion,
        );
      }
    }
    print('[ApiUpgraderStore] No update found or data was incomplete.');
    // Return empty info if no update is found.
    return UpgraderVersionInfo();
  }
}
