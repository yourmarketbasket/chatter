import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CustomCacheManager {
  static const key = 'thumbnailCache'; // Unique key for this cache

  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 15), // How long to keep items in cache before revalidating
      maxNrOfCacheObjects: 500, // Maximum number of objects in cache
      // You might also consider fileService: HttpFileService() if not default
    ),
  );
}
