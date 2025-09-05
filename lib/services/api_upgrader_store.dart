import 'package:get/get.dart';
import 'package:upgrader/upgrader.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:version/version.dart';

class ApiUpgraderStore extends UpgraderStore {
  final DataController _dataController = Get.find<DataController>();

  ApiUpgraderStore();

  @override
  Future<UpgraderVersionInfo> getVersionInfo({String? countryCode, String? languageCode}) async {
    print('[ApiUpgraderStore] Getting version info from custom API.');

    final updateData = await _dataController.getLatestAppUpdate();

    if (updateData != null) {
      final versionStr = updateData['version'] as String?;
      final notes = updateData['notes'] as String?;
      final url = updateData['url'] as String?;
      final minAppVersionStr = updateData['minAppVersion'] as String?;

      if (versionStr != null && url != null) {
        print('[ApiUpgraderStore] Found update: $versionStr, URL: $url');

        final appStoreVersion = Version.parse(versionStr);
        final minAppVersion = minAppVersionStr != null ? Version.parse(minAppVersionStr) : null;

        return UpgraderVersionInfo(
          appStoreVersion: appStoreVersion,
          releaseNotes: notes,
          appStoreListingURL: url,
          minAppVersion: minAppVersion,
        );
      }
    }
    print('[ApiUpgraderStore] No update found or data was incomplete.');
    return UpgraderVersionInfo();
  }
}
