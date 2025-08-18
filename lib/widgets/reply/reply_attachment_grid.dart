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

    final List<Map<String, dynamic>> allAttachmentsForMediaView;
    final dynamic rawPostAttachments = postOrReplyData['attachments'];
    if (rawPostAttachments is List) {
      allAttachmentsForMediaView = rawPostAttachments.whereType<Map<String, dynamic>>().toList();
    } else {
      allAttachmentsForMediaView = attachmentsArg;
    }

    if (attachmentsArg.length == 1) {
      final attachment = attachmentsArg[0];
      double aspectRatioToUse = 4 / 3;

      return AspectRatio(
        aspectRatio: aspectRatioToUse,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: ReplyAttachmentDisplayWidget(
              attachmentMap: attachment,
              currentIndex: 0,
              allAttachmentsInThisPost: allAttachmentsForMediaView,
              postOrReplyData: postOrReplyData,
              borderRadius: BorderRadius.zero),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: _buildGridContent(context, allAttachmentsForMediaView),
      ),
    );
  }

  Widget _buildGridContent(BuildContext context, List<Map<String, dynamic>> allAttachmentsForMediaView) {
    const double itemSpacing = 4.0;
    if (attachmentsArg.length == 2) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
              child: ReplyAttachmentDisplayWidget(
                  attachmentMap: attachmentsArg[0],
                  currentIndex: 0,
                  allAttachmentsInThisPost: allAttachmentsForMediaView,
                  postOrReplyData: postOrReplyData,
                  borderRadius: BorderRadius.zero)),
          const SizedBox(width: itemSpacing),
          Expanded(
              child: ReplyAttachmentDisplayWidget(
                  attachmentMap: attachmentsArg[1],
                  currentIndex: 1,
                  allAttachmentsInThisPost: allAttachmentsForMediaView,
                  postOrReplyData: postOrReplyData,
                  borderRadius: BorderRadius.zero)),
        ],
      );
    } else if (attachmentsArg.length == 3) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
              flex: 2,
              child: ReplyAttachmentDisplayWidget(
                  attachmentMap: attachmentsArg[0],
                  currentIndex: 0,
                  allAttachmentsInThisPost: allAttachmentsForMediaView,
                  postOrReplyData: postOrReplyData,
                  borderRadius: BorderRadius.zero)),
          const SizedBox(width: itemSpacing),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                    child: ReplyAttachmentDisplayWidget(
                        attachmentMap: attachmentsArg[1],
                        currentIndex: 1,
                        allAttachmentsInThisPost: allAttachmentsForMediaView,
                        postOrReplyData: postOrReplyData,
                        borderRadius: BorderRadius.zero)),
                const SizedBox(height: itemSpacing),
                Expanded(
                    child: ReplyAttachmentDisplayWidget(
                        attachmentMap: attachmentsArg[2],
                        currentIndex: 2,
                        allAttachmentsInThisPost: allAttachmentsForMediaView,
                        postOrReplyData: postOrReplyData,
                        borderRadius: BorderRadius.zero)),
              ],
            ),
          ),
        ],
      );
    } else if (attachmentsArg.length == 4) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: itemSpacing,
            mainAxisSpacing: itemSpacing,
            childAspectRatio: 1.0),
        itemCount: 4,
        itemBuilder: (context, index) => ReplyAttachmentDisplayWidget(
            attachmentMap: attachmentsArg[index],
            currentIndex: index,
            allAttachmentsInThisPost: allAttachmentsForMediaView,
            postOrReplyData: postOrReplyData,
            borderRadius: BorderRadius.zero),
      );
    } else { // 5 or more attachments
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(
                    child: ReplyAttachmentDisplayWidget(
                        attachmentMap: attachmentsArg[0],
                        currentIndex: 0,
                        allAttachmentsInThisPost: allAttachmentsForMediaView,
                        postOrReplyData: postOrReplyData,
                        borderRadius: BorderRadius.zero)),
                const SizedBox(height: itemSpacing),
                Expanded(
                    child: ReplyAttachmentDisplayWidget(
                        attachmentMap: attachmentsArg[1],
                        currentIndex: 1,
                        allAttachmentsInThisPost: allAttachmentsForMediaView,
                        postOrReplyData: postOrReplyData,
                        borderRadius: BorderRadius.zero)),
              ],
            )
          ),
          const SizedBox(width: itemSpacing),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(
                    child: ReplyAttachmentDisplayWidget(
                        attachmentMap: attachmentsArg[2],
                        currentIndex: 2,
                        allAttachmentsInThisPost: allAttachmentsForMediaView,
                        postOrReplyData: postOrReplyData,
                        borderRadius: BorderRadius.zero)),
                const SizedBox(height: itemSpacing),
                Expanded(
                    child: ReplyAttachmentDisplayWidget(
                        attachmentMap: attachmentsArg[3],
                        currentIndex: 3,
                        allAttachmentsInThisPost: allAttachmentsForMediaView,
                        postOrReplyData: postOrReplyData,
                        borderRadius: BorderRadius.zero)),
                const SizedBox(height: itemSpacing),
                Expanded(
                    child: ReplyAttachmentDisplayWidget(
                        attachmentMap: attachmentsArg[4],
                        currentIndex: 4,
                        allAttachmentsInThisPost: allAttachmentsForMediaView,
                        postOrReplyData: postOrReplyData,
                        borderRadius: BorderRadius.zero)),
              ],
            )
          ),
        ],
      );
    }
  }
}
