import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class VisibleMediaItem {
  final String mediaId;
  final String mediaType; // 'video' or 'audio'
  double visibleFraction;
  final Function playCallback;
  final Function pauseCallback;
  final BuildContext context; // To get RenderBox for position

  VisibleMediaItem({
    required this.mediaId,
    required this.mediaType,
    required this.visibleFraction,
    required this.playCallback,
    required this.pauseCallback,
    required this.context,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisibleMediaItem &&
          runtimeType == other.runtimeType &&
          mediaId == other.mediaId;

  @override
  int get hashCode => mediaId.hashCode;
}

class MediaVisibilityService extends GetxService {
  final RxList<VisibleMediaItem> _visibleItems = <VisibleMediaItem>[].obs;
  Rxn<String> currentlyPlayingByVisibility = Rxn<String>();

  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 500); // Adjust as needed

  // Thresholds
  static const double _minVisibilityToPlay = 0.6; // Must be at least 60% visible to start
  static const double _visibilityThresholdSwitch = 0.1; // New item must be 10% more visible to switch

  void itemVisibilityChanged({
    required String mediaId,
    required String mediaType,
    required double visibleFraction,
    required Function playCallback,
    required Function pauseCallback,
    required BuildContext context,
  }) {
    _visibleItems.removeWhere((item) => item.mediaId == mediaId);
    if (visibleFraction > 0) {
      _visibleItems.add(VisibleMediaItem(
        mediaId: mediaId,
        mediaType: mediaType,
        visibleFraction: visibleFraction,
        playCallback: playCallback,
        pauseCallback: pauseCallback,
        context: context,
      ));
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, _processVisibleItems);
  }

  void _processVisibleItems() {
    if (_visibleItems.isEmpty) {
      if (currentlyPlayingByVisibility.value != null) {
        // This case should ideally be handled by the item itself calling pause when it becomes not visible.
        // However, as a fallback, if no items are visible, ensure nothing is marked as playing due to visibility.
        // This doesn't directly pause, assumes the item's own visibility handler does that.
        currentlyPlayingByVisibility.value = null;
      }
      return;
    }

    // Sort by visibility (descending), then by screen position (topmost first)
    _visibleItems.sort((a, b) {
      final visibilityDiff = b.visibleFraction.compareTo(a.visibleFraction);
      if (visibilityDiff != 0) {
        return visibilityDiff;
      }
      // Tie-breaking: Use vertical position on screen
      try {
        final RenderBox? boxA = a.context.findRenderObject() as RenderBox?;
        final RenderBox? boxB = b.context.findRenderObject() as RenderBox?;
        if (boxA != null && boxB != null) {
          final positionA = boxA.localToGlobal(Offset.zero).dy;
          final positionB = boxB.localToGlobal(Offset.zero).dy;
          return positionA.compareTo(positionB);
        }
      } catch (e) {
        // In case context is no longer valid / findRenderObject fails
        print("Error comparing item positions: $e");
      }
      return 0; // Default if positions can't be determined
    });

    VisibleMediaItem? mostVisibleItem = _visibleItems.firstWhereOrNull((item) => item.visibleFraction >= _minVisibilityToPlay);

    if (mostVisibleItem == null) {
      // No item meets the minimum visibility to play.
      // If something was playing due to visibility, pause it.
      if (currentlyPlayingByVisibility.value != null) {
        final previouslyPlayingItem = _visibleItems.firstWhereOrNull((item) => item.mediaId == currentlyPlayingByVisibility.value);
        previouslyPlayingItem?.pauseCallback();
        currentlyPlayingByVisibility.value = null;
        print("[MediaVisibilityService] No item sufficiently visible. Paused ${previouslyPlayingItem?.mediaId}.");
      }
      return;
    }

    // Check if we should switch player
    if (currentlyPlayingByVisibility.value == null) {
      // Nothing is playing due to visibility, so play the most visible (if it meets threshold)
      mostVisibleItem.playCallback();
      currentlyPlayingByVisibility.value = mostVisibleItem.mediaId;
      print("[MediaVisibilityService] Playing most visible: ${mostVisibleItem.mediaId}");
    } else if (currentlyPlayingByVisibility.value != mostVisibleItem.mediaId) {
      // Something else is playing due to visibility. Should we switch?
      VisibleMediaItem? currentPlayingVisibleItem = _visibleItems.firstWhereOrNull(
          (item) => item.mediaId == currentlyPlayingByVisibility.value);

      if (currentPlayingVisibleItem == null) {
        // The item that was playing is no longer visible (or doesn't meet threshold), switch to new most visible
        mostVisibleItem.playCallback();
        currentlyPlayingByVisibility.value = mostVisibleItem.mediaId;
        print("[MediaVisibilityService] Previously playing item gone. Playing new most visible: ${mostVisibleItem.mediaId}");
      } else if (mostVisibleItem.visibleFraction > currentPlayingVisibleItem.visibleFraction + _visibilityThresholdSwitch) {
        // New item is significantly more visible, switch
        currentPlayingVisibleItem.pauseCallback();
        print("[MediaVisibilityService] Pausing ${currentPlayingVisibleItem.mediaId} due to switch.");
        mostVisibleItem.playCallback();
        currentlyPlayingByVisibility.value = mostVisibleItem.mediaId;
        print("[MediaVisibilityService] Playing new most visible (switched): ${mostVisibleItem.mediaId}");
      } else {
        // Not significantly more visible, keep current playing (stickiness)
        print("[MediaVisibilityService] Most visible is ${mostVisibleItem.mediaId}, but not switching from ${currentlyPlayingByVisibility.value} due to threshold.");
      }
    } else {
      // The most visible item is already the one playing due to visibility. Do nothing.
      print("[MediaVisibilityService] Most visible item ${mostVisibleItem.mediaId} is already playing by visibility.");
    }
  }

  void unregisterItem(String mediaId) {
    _visibleItems.removeWhere((item) => item.mediaId == mediaId);
     if (currentlyPlayingByVisibility.value == mediaId) {
        currentlyPlayingByVisibility.value = null;
        // No need to call pause here, the item's dispose should handle it.
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, _processVisibleItems); // Re-process if an item is removed
  }

  void playItem(String mediaId) {
    final itemToPlay = _visibleItems.firstWhereOrNull((item) => item.mediaId == mediaId);
    if (itemToPlay != null) {
      print("[MediaVisibilityService] External request to play item: $mediaId. Current playingByVisibility: ${currentlyPlayingByVisibility.value}");
      if (currentlyPlayingByVisibility.value != null && currentlyPlayingByVisibility.value != mediaId) {
        final currentlyPlayingItem = _visibleItems.firstWhereOrNull((item) => item.mediaId == currentlyPlayingByVisibility.value);
        currentlyPlayingItem?.pauseCallback();
        print("[MediaVisibilityService] Paused ${currentlyPlayingByVisibility.value} due to external play request for $mediaId.");
      }
      itemToPlay.playCallback();
      currentlyPlayingByVisibility.value = itemToPlay.mediaId; // Set this as the one playing due to (now direct) visibility logic
    } else {
      print("[MediaVisibilityService] External request to play item: $mediaId, but item not found or not visible.");
      // Optionally, if not visible, one could decide to not play or log.
      // For a queue, we assume it should play if the previous finished, even if briefly not "most visible".
      // However, the item still needs to be in _visibleItems (i.e. somewhat visible) for its playCallback to be valid.
      // This might need refinement if a queued video is completely off-screen when its turn comes.
    }
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    super.onClose();
  }
}
