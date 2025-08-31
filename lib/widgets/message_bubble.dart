import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/widgets/link_preview_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:linkify/linkify.dart' as linkify_helper;
import 'package:url_launcher/url_launcher.dart';
import 'package:chatter/widgets/reply_attachment_preview.dart';

class MessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final Map<String, dynamic>? prevMessage;
  final DataController dataController;
  final Function(Map<String, dynamic>) showMessageOptions;
  final Function(Map<String, dynamic>, int) openMediaView;
  final Widget Function(Map<String, dynamic>) buildAttachment;
  final String Function(Map<String, dynamic>) getReplyPreviewText;
  final Widget Function(Map<String, dynamic>, bool) buildReactions;

  const MessageBubble({
    Key? key,
    required this.message,
    this.prevMessage,
    required this.dataController,
    required this.showMessageOptions,
    required this.openMediaView,
    required this.buildAttachment,
    required this.getReplyPreviewText,
    required this.buildReactions,
  }) : super(key: key);

  @override
  _MessageBubbleState createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final Set<String> _successfulPreviewUrls = {};

  String _getAggregateStatus(Map<String, dynamic> message) {
    if (message['status'] == 'sending') return 'sending';
    if (message['status_for_failed_only'] == 'failed') return 'failed';
    final receipts = (message['readReceipts'] as List?)?.cast<Map<String, dynamic>>();
    if (receipts == null || receipts.isEmpty) return 'sent';
    if (receipts.every((r) => r['status'] == 'read')) return 'read';
    if (receipts.any((r) => r['status'] == 'delivered' || r['status'] == 'read')) return 'delivered';
    return 'sent';
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'sending': return Icons.access_time;
      case 'sent': return Icons.check;
      case 'delivered': return Icons.done_all;
      case 'read': return Icons.done_all;
      case 'failed': return Icons.error_outline;
      default: return Icons.access_time;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'read': return Colors.tealAccent;
      case 'failed': return Colors.red;
      default: return Colors.grey[400]!;
    }
  }

  Future<void> _onOpenLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Consider showing a Snackbar or some other feedback
    }
  }

  List<TextSpan> _buildTextSpans(String text, bool isYou) {
    final spans = <TextSpan>[];
    final elements = linkify_helper.linkify(text, options: const linkify_helper.LinkifyOptions(humanize: false));

    // Check if the text contains only a single URL
    final isOnlyUrl = elements.length == 1 && elements.first is linkify_helper.LinkableElement;

    for (final e in elements) {
      if (e is linkify_helper.LinkableElement) {
        // If text contains only a URL, skip adding it to spans
        if (isOnlyUrl) {
          continue;
        }
        // If a preview exists for this URL, render the text plainly
        if (_successfulPreviewUrls.contains(e.url)) {
          spans.add(TextSpan(text: e.text));
        } else {
          // Otherwise, render it as a clickable link
          spans.add(
            TextSpan(
              text: e.text,
              style: const TextStyle(color: Colors.tealAccent, decoration: TextDecoration.underline),
              recognizer: TapGestureRecognizer()..onTap = () => _onOpenLink(e.url),
            ),
          );
        }
      } else {
        spans.add(TextSpan(text: e.text));
      }
    }
    return spans;
}

  @override
  Widget build(BuildContext context) {
    final senderId = widget.message['senderId'] is Map ? widget.message['senderId']['_id'] : widget.message['senderId'];
    final isYou = senderId == widget.dataController.user.value['user']['_id'];
    final prevSenderId = widget.prevMessage != null ? (widget.prevMessage!['senderId'] is Map ? widget.prevMessage!['senderId']['_id'] : widget.prevMessage!['senderId']) : null;
    final isSameSenderAsPrevious = prevSenderId != null && prevSenderId == senderId;
    final bottomMargin = isSameSenderAsPrevious ? 2.0 : 8.0;
    final hasAttachment = widget.message['files'] != null && (widget.message['files'] as List).isNotEmpty;
    final content = widget.message['content'] as String? ?? '';

    final sender = widget.dataController.allUsers.firstWhere(
      (u) => u['_id'] == senderId,
      orElse: () {
        final participant = (widget.dataController.currentChat.value['participants'] as List).firstWhere(
          (p) => (p is Map ? p['_id'] : p) == senderId,
          orElse: () => <String, dynamic>{},
        );
        return (participant is Map && participant['name'] != null)
            ? Map<String, dynamic>.from(participant)
            : {'_id': senderId, 'name': 'Unknown User'};
      },
    );
    final senderName = isYou ? 'You' : sender['name'];

    final List<linkify_helper.LinkifyElement> elements = linkify_helper.linkify(content, options: const linkify_helper.LinkifyOptions(humanize: false));
    final Set<String> urls = elements.whereType<linkify_helper.LinkableElement>().map((e) => e.url).toSet();

    final bool isOnlyLinkWithPreview = elements.length == 1 &&
        elements.first is linkify_helper.LinkableElement &&
        _successfulPreviewUrls.contains((elements.first as linkify_helper.LinkableElement).url);

    final messageBubbleContent = Column(
      crossAxisAlignment: isYou ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (widget.dataController.currentChat.value['type'] == 'group' && !isYou)
          Padding(
            padding: const EdgeInsets.only(bottom: 2.0),
            child: Text(senderName, style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        if (widget.message['deletedForEveryone'] ?? false)
          Text('Message deleted', style: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.italic))
        else ...[
          if (widget.message['replyTo'] != null)
            Obx(() {
              final originalMessage = widget.dataController.currentConversationMessages.firstWhere(
                (m) => m['_id'] == widget.message['replyTo'],
                orElse: () => {'_id': '', 'senderId': {'_id': '', 'name': 'Unknown User'}, 'content': 'Original message not found.', 'files': [], 'type': 'text'},
              );
              if (originalMessage['_id'].isEmpty) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.all(8.0),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.grey[900]?.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border(left: BorderSide(color: isYou ? Colors.teal : Colors.grey, width: 2)),
                ),
                child: Column(
                  crossAxisAlignment:  CrossAxisAlignment.start,
                  children: [
                    Text(
                      originalMessage['senderId']['_id'] == widget.dataController.user.value['user']['_id']
                          ? 'You'
                          : widget.dataController.allUsers.firstWhere((u) => u['_id'] == originalMessage['senderId']['_id'], orElse: () => {'name': 'Unknown User'})['name'],
                      style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    if (originalMessage['files'] != null && (originalMessage['files'] as List).isNotEmpty)
                      Row(
                        children: [
                          ReplyAttachmentPreview(attachment: originalMessage['files'][0]),
                          const SizedBox(width: 8),
                          Expanded(child: Text(widget.getReplyPreviewText(originalMessage['files'][0]), style: TextStyle(color: Colors.grey[300]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      )
                    else
                      Text(originalMessage['content'] ?? '', style: TextStyle(color: Colors.grey[300]), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              );
            }),
          if (hasAttachment) ...[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: widget.buildAttachment(widget.message),
            ),
            if (content.isNotEmpty) const SizedBox(height: 8),
          ],
          // important
          ...urls.map((url) => LinkPreviewWidget(
                url: url,
                onPreviewSuccess: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_successfulPreviewUrls.contains(url)) {
                      setState(() {
                        _successfulPreviewUrls.add(url);
                      });
                    }
                  });
                },
              )),
          if (content.isNotEmpty && !isOnlyLinkWithPreview)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 8, right:8),
              child: RichText(
                textAlign: isYou ? TextAlign.right : TextAlign.left,
                text: TextSpan(
                  style: TextStyle(color: isYou ? Colors.white : Colors.grey[200], fontSize: 12),
                  children: _buildTextSpans(content, isYou),
                ),
              ),
            ),
        ],
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left:10.0, right: 10.0, bottom:5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.message['edited'] ?? false)
                Text('(edited) ', style: TextStyle(color: Colors.grey[400], fontSize: 10, fontStyle: FontStyle.italic)),
              Text(
                DateFormat('h:mm a').format(DateTime.parse(widget.message['createdAt']).toLocal()),
                style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 9, fontStyle: FontStyle.italic),
              ),
              if (isYou) ...[
                const SizedBox(width: 4),
                Icon(_getStatusIcon(_getAggregateStatus(widget.message)), size: 12, color: _getStatusColor(_getAggregateStatus(widget.message))),
              ],
            ],
          ),
        ),
      ],
    );

    return GestureDetector(
      onLongPress: () {
        if (!(widget.message['deletedForEveryone'] ?? false)) widget.showMessageOptions(widget.message);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: EdgeInsets.only(bottom: bottomMargin),
            padding: isOnlyLinkWithPreview
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 1.0, vertical: 1.0),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.55,
              minWidth: MediaQuery.of(context).size.width * 0.10,
            ),
            decoration: BoxDecoration(
              color: isYou ? Colors.transparent.withOpacity(0.2) : Colors.transparent,
              border: Border.all(color: isYou ? Colors.teal.withOpacity(0.6) : const Color.fromARGB(167, 143, 141, 141), width: 1.0),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20.0),
                topRight: const Radius.circular(20.0),
                bottomLeft: Radius.circular(isYou ? 20.0 : 0.0),
                bottomRight: Radius.circular(isYou ? 0.0 : 20.0),
              ),
            ),
            child: messageBubbleContent,
          ),
          widget.buildReactions(widget.message, isYou),
        ],
      ),
    );
  }
}