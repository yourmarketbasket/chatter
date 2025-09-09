import 'package:get/get.dart';
import 'package:upgrader/upgrader.dart';
import 'package:chatter/services/api_upgrader_store.dart';

class UpdateController extends GetxController {
  final upgrader = Upgrader(
    storeController: UpgraderStoreController(
      onAndroid: () => ApiUpgraderStore(),
      oniOS: () => ApiUpgraderStore(),
    ),
    debugLogging: true, // For debugging purposes
  );

  var isUpdateAvailable = false.obs;
  var hasBeenDismissed = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkForUpdates();
  }

  Future<void> checkForUpdates() async {
    await upgrader.initialize();
    if (upgrader.isUpdateAvailable()) {
      isUpdateAvailable.value = true;
    }
  }

  void dismissUpdateCard() {
    hasBeenDismissed.value = true;
  }
}
