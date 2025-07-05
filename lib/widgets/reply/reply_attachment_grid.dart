import 'package:chatter/widgets/reply/reply_attachment_widget.dart';
import 'package:flutter/material.dart';

class ReplyAttachmentGrid extends StatelessWidget {
  final List<Map<String, dynamic>> attachmentsArg;
  final Map<String, dynamic> postOrReplyData;
  // These parameters were in the original _buildReplyAttachmentGrid signature but seemed specific to MediaViewPage navigation context
  // If they are needed for other purposes by ReplyAttachmentDisplayWidget or its children, they should be passed down.
  // For now, assuming postOrReplyData contains enough context for ReplyAttachmentDisplayWidget.
  // final String userName;
  // final String? userAvatar;
  // final DateTime timestamp;
  // final int viewsCount;
  // final int likesCount;
  // final int repostsCount;
  // final String messageContent;

  const ReplyAttachmentGrid({
    Key? key,
    required this.attachmentsArg,
    required this.postOrReplyData,
    // required this.userName,
    // this.userAvatar,
    // required this.timestamp,
    // required this.viewsCount,
    // required this.likesCount,
    // required this.repostsCount,
    // required this.messageContent,
  }) : super(key: key);

  double? _parseAspectRatio(dynamic aspectRatio) {
    if (aspectRatio == null) return null;
    try {
      if (aspectRatio is double) {
        return (aspectRatio > 0) ? aspectRatio : 1.0;
      }
      if (aspectRatio is String) {
        if (aspectRatio.contains(':')) {
          final parts = aspectRatio.split(':');
          if (parts.length == 2) {
            final width = double.tryParse(parts[0].trim());
            final height = double.tryParse(parts[1].trim());
            if (width != null && height != null && width > 0 && height > 0) {
              return width / height;
            }
          }
        } else {
          final value = double.tryParse(aspectRatio);
          if (value != null && value > 0) {
            return value;
          }
        }
      }
    } catch (e) {
      print('Error parsing aspect ratio: $e');
    }
    return 1.0; // Default aspect ratio if parsing fails or type is unknown
  }

  @override
  Widget build(BuildContext context) {
    const double itemSpacing = 4.0;
    if (attachmentsArg.isEmpty) return const SizedBox.shrink();

    // This list is used by MediaViewPage. ReplyAttachmentDisplayWidget constructs it.
    final List<Map<String, dynamic>> allAttachmentsForMediaView;
    final dynamic rawPostAttachments = postOrReplyData['attachments'];
    if (rawPostAttachments is List) {
      allAttachmentsForMediaView = rawPostAttachments.whereType<Map<String, dynamic>>().toList();
    } else {
      allAttachmentsForMediaView = []; // Should ideally be attachmentsArg itself if no other source
      // If attachmentsArg is the definitive list for this grid, use it directly for MediaViewPage
      // For now, sticking to original logic of trying to get from postOrReplyData['attachments']
    }


    Widget gridContent;

    if (attachmentsArg.length == 1) {
      final attachment = attachmentsArg[0];
      double aspectRatioToUse = _parseAspectRatio(attachment['aspectRatio']) ??
          (attachment['type'] == 'video' ? 16 / 9 : 1.0);
      if (aspectRatioToUse <= 0) {
        aspectRatioToUse = (attachment['type'] == 'video' ? 16 / 9 : 1.0);
      }

      gridContent = AspectRatio(
        aspectRatio: aspectRatioToUse,
        child: ReplyAttachmentDisplayWidget(
            attachmentMap: attachment,
            currentIndex: 0,
            allAttachmentsInThisPost: allAttachmentsForMediaView.isNotEmpty ? allAttachmentsForMediaView : attachmentsArg,
            postOrReplyData: postOrReplyData,
            borderRadius: BorderRadius.circular(12.0)),
      );
    } else if (attachmentsArg.length == 2) {
      gridContent = AspectRatio(
        // Defaulting to a common aspect ratio for 2 items, e.g., 2 * (4/3) or ensure items fill
        // The original code didn't specify a fixed aspect ratio for the container of 2 items,
        // it relied on Expanded within a Row.
        // Let's make it flexible by not wrapping in AspectRatio or using a common one like 2:1 or 8:3.
        // For now, we mimic the structure that would be responsive.
        // aspectRatio: 2 * (4 / 3), // This might be too restrictive
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
                child: ReplyAttachmentDisplayWidget(
                    attachmentMap: attachmentsArg[0],
                    currentIndex: 0,
                    allAttachmentsInThisPost: allAttachmentsForMediaView.isNotEmpty ? allAttachmentsForMediaView : attachmentsArg,
                    postOrReplyData: postOrReplyData,
                    borderRadius: BorderRadius.zero)),
            const SizedBox(width: itemSpacing),
            Expanded(
                child: ReplyAttachmentDisplayWidget(
                    attachmentMap: attachmentsArg[1],
                    currentIndex: 1,
                    allAttachmentsInThisPost: allAttachmentsForMediaView.isNotEmpty ? allAttachmentsForMediaView : attachmentsArg,
                    postOrReplyData: postOrReplyData,
                    borderRadius: BorderRadius.zero)),
          ],
        ),
      );
    } else if (attachmentsArg.length == 3) {
      gridContent = LayoutBuilder(builder: (context, constraints) {
        double width = constraints.maxWidth;
        double leftItemWidth = (width - itemSpacing) * (2 / 3);
        double rightColumnWidth = (width - itemSpacing) * (1 / 3);

        // Determine height based on content. If there's a video, it might prefer 16:9.
        // Otherwise, a common photo aspect ratio like 4:3 or 3:4.
        // This was complex in original, let's try to simplify or make it adaptive.
        // A common approach is to set a fixed aspect ratio for the whole 3-item container
        // or calculate height based on the primary item.
        // For now, using a common image aspect ratio for height calculation.
        double totalHeight = leftItemWidth * (3/4); // Assuming first item dictates height with a 4:3 aspect ratio
         if (attachmentsArg.any((att) => (_parseAspectRatio(att['aspectRatio']) ?? 1.0) < 1)) {
          // If any item is portrait, the container might need to be taller.
          // This part of the logic was: totalHeight = width * (4 / 3); which seems too tall.
          // Let's make the totalHeight responsive to the left item's aspect ratio
            final firstItemAR = _parseAspectRatio(attachmentsArg[0]['aspectRatio']) ?? (4/3);
            totalHeight = leftItemWidth / firstItemAR;
        }


        return SizedBox(
          height: totalHeight, // Calculated height
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                  width: leftItemWidth,
                  child: ReplyAttachmentDisplayWidget(
                      attachmentMap: attachmentsArg[0],
                      currentIndex: 0,
                      allAttachmentsInThisPost: allAttachmentsForMediaView.isNotEmpty ? allAttachmentsForMediaView : attachmentsArg,
                      postOrReplyData: postOrReplyData,
                      borderRadius: BorderRadius.zero)),
              const SizedBox(width: itemSpacing),
              SizedBox(
                width: rightColumnWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                        child: ReplyAttachmentDisplayWidget(
                            attachmentMap: attachmentsArg[1],
                            currentIndex: 1,
                            allAttachmentsInThisPost: allAttachmentsForMediaView.isNotEmpty ? allAttachmentsForMediaView : attachmentsArg,
                            postOrReplyData: postOrReplyData,
                            borderRadius: BorderRadius.zero)),
                    const SizedBox(height: itemSpacing),
                    Expanded(
                        child: ReplyAttachmentDisplayWidget(
                            attachmentMap: attachmentsArg[2],
                            currentIndex: 2,
                            allAttachmentsInThisPost: allAttachmentsForMediaView.isNotEmpty ? allAttachmentsForMediaView : attachmentsArg,
                            postOrReplyData: postOrReplyData,
                            borderRadius: BorderRadius.zero)),
                  ],
                ),
              ),
            ],
          ),
        );
      });
    } else if (attachmentsArg.length == 4) {
      gridContent = AspectRatio(
        aspectRatio: 1.0, // 2x2 grid is typically square overall
        child: GridView.builder(
          shrinkWrap: true, // Important for embedding in other layouts
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: itemSpacing,
              mainAxisSpacing: itemSpacing,
              childAspectRatio: 1.0), // Square items
          itemCount: 4,
          itemBuilder: (context, index) => ReplyAttachmentDisplayWidget(
              attachmentMap: attachmentsArg[index],
              currentIndex: index,
              allAttachmentsInThisPost: allAttachmentsForMediaView.isNotEmpty ? allAttachmentsForMediaView : attachmentsArg,
              postOrReplyData: postOrReplyData,
              borderRadius: BorderRadius.zero),
        ),
      );
    } else if (attachmentsArg.length == 5) {
      // This layout was specific. Replicating the height calculation logic.
      gridContent = LayoutBuilder(builder: (context, constraints) {
        double containerWidth = constraints.maxWidth;
        // Height of items in the first row (2 items)
        double h1 = (containerWidth - itemSpacing) / 2; // Assuming square items, so width = height
        // Height of items in the second row (3 items)
        double h2 = (containerWidth - 2 * itemSpacing) / 3; // Assuming square items

        // If items are not square, this calculation needs to consider their aspect ratios.
        // The original code implies square items by this division for height.
        // Let's assume a default aspect ratio of 1.0 for calculation if not specified.
        // For simplicity, we'll stick to the original assumption that h1 and h2 are item heights.

        double totalHeight = h1 + itemSpacing + h2;
        return SizedBox(
          height: totalHeight,
          child: Column(
            children: [
              SizedBox( // First row with 2 items
                  height: h1,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                            child: ReplyAttachmentDisplayWidget(
                                attachmentMap: attachmentsArg[0],
                                currentIndex: 0,
                                allAttachmentsInThisPost: allAttachmentsForMediaView.isNotEmpty ? allAttachmentsForMediaView : attachmentsArg,
                                postOrReplyData: postOrReplyData,
                                borderRadius: BorderRadius.zero)),
                        const SizedBox(width: itemSpacing),
                        Expanded(
                            child: ReplyAttachmentDisplayWidget(
                                attachmentMap: attachmentsArg[1],
                                currentIndex: 1,
                                allAttachmentsInThisPost: allAttachmentsForMediaView.isNotEmpty ? allAttachmentsForMediaView : attachmentsArg,
                                postOrReplyData: postOrReplyData,
                                borderRadius: BorderRadius.zero)),
                      ])),
              const SizedBox(height: itemSpacing),
              SizedBox( // Second row with 3 items
                  height: h2,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                            child: ReplyAttachmentDisplayWidget(
                                attachmentMap: attachmentsArg[2],
                                currentIndex: 2,
                                allAttachmentsInThisPost: allAttachmentsForMediaView.isNotEmpty ? allAttachmentsForMediaView : attachmentsArg,
                                postOrReplyData: postOrReplyData,
                                borderRadius: BorderRadius.zero)),
                        const SizedBox(width: itemSpacing),
                        Expanded(
                            child: ReplyAttachmentDisplayWidget(
                                attachmentMap: attachmentsArg[3],
                                currentIndex: 3,
                                allAttachmentsInThisPost: allAttachmentsForMediaView.isNotEmpty ? allAttachmentsForMediaView : attachmentsArg,
                                postOrReplyData: postOrReplyData,
                                borderRadius: BorderRadius.zero)),
                        const SizedBox(width: itemSpacing),
                        Expanded(
                            child: ReplyAttachmentDisplayWidget(
                                attachmentMap: attachmentsArg[4],
                                currentIndex: 4,
                                allAttachmentsInThisPost: allAttachmentsForMediaView.isNotEmpty ? allAttachmentsForMediaView : attachmentsArg,
                                postOrReplyData: postOrReplyData,
                                borderRadius: BorderRadius.zero)),
                      ])),
            ],
          ),
        );
      });
    } else { // 6 or more attachments
      const int crossAxisCount = 3;
      const double childAspectRatio = 1.0; // Square items in the grid

      // Using LayoutBuilder to get available width for precise item sizing
      gridContent = LayoutBuilder(builder: (context, constraints) {
        // Calculate item width based on available width, crossAxisCount, and spacing
        double itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * itemSpacing) / crossAxisCount;
        // Calculate item height based on itemWidth and childAspectRatio
        double itemHeight = itemWidth / childAspectRatio;
        // Calculate number of rows
        int numRows = (attachmentsArg.length / crossAxisCount).ceil();
        // Calculate total height required for the GridView
        double totalHeight = numRows * itemHeight + (numRows - 1) * itemSpacing;

        return SizedBox(
          height: totalHeight, // Set the calculated height for the GridView container
          child: GridView.builder(
            shrinkWrap: true, // Essential for embedding in a scrollable view or column
            physics: const NeverScrollableScrollPhysics(), // Disable GridView's own scrolling
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: itemSpacing,
                mainAxisSpacing: itemSpacing,
                childAspectRatio: childAspectRatio),
            itemCount: attachmentsArg.length,
            itemBuilder: (context, index) => ReplyAttachmentDisplayWidget(
                attachmentMap: attachmentsArg[index],
                currentIndex: index,
                allAttachmentsInThisPost: allAttachmentsForMediaView.isNotEmpty ? allAttachmentsForMediaView : attachmentsArg,
                postOrReplyData: postOrReplyData,
                borderRadius: BorderRadius.zero),
          ),
        );
      });
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12.0), // Overall rounding for the grid container
      child: gridContent,
    );
  }
}
