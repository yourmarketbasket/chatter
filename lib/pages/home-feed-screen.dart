import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/new-posts-page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumb;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class Attachment {
  final File file;
  final String type;
  String? url; // URL after uploading to Cloudinary

  Attachment({required this.file, required this.type, this.url});
}

class ChatterPost {
  final String username;
  final String content;
  final DateTime timestamp;
  int likes;
  int reposts;
  int views;
  final List<Attachment> attachments;
  final String avatarInitial;
  final List<ChatterPost> replies;

  ChatterPost({
    required this.username,
    required this.content,
    required this.timestamp,
    this.likes = 0,
    this.reposts = 0,
    this.views = 0,
    this.attachments = const [],
    required this.avatarInitial,
    this.replies = const [],
  });
}

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({Key? key}) : super(key: key);

  @override
  _HomeFeedScreenState createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  DataController dataController = Get.put(DataController());
  final List<ChatterPost> _posts = [
    ChatterPost(
      username: "MtaaniGuru",
      content: "Sasa! Who's vibin' in Nairobi tonight? 😎 #PoaVibes",
      timestamp: DateTime.now().subtract(Duration(minutes: 5)),
      likes: 42,
      reposts: 10,
      views: Random().nextInt(1000) + 100,
      avatarInitial: "M",
      attachments: [
        Attachment(
          file: File(''), // Placeholder for demo post
          type: "image",
          url: "https://images.unsplash.com/photo-1518791841217-8f162f1e1131",
        ),
      ],
      replies: [
        ChatterPost(
          username: "NiajeBro",
          content: "Poa msee! Hitting Westie clubs tonight! 🎉",
          timestamp: DateTime.now().subtract(Duration(minutes: 2)),
          likes: 5,
          reposts: 1,
          views: 50,
          avatarInitial: "N",
        ),
      ],
    ),
  ];

  void _navigateToPostScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewPostScreen()),
    );
    if (result != null && result is Map<String, dynamic>) {
      _addPost(result['content'], result['attachments']);
    }
  }

  Future<void> _addPost(String content, List<Attachment> attachments) async {
    // Upload files to Cloudinary
    List<Attachment> uploadedAttachments = [];
    if (attachments.isNotEmpty) {
      List<File> files = attachments.map((a) => a.file).toList();
      List<Map<String, dynamic>> uploadResults = await dataController.uploadFilesToCloudinary(files);
      
      for (int i = 0; i < attachments.length; i++) {
        var result = uploadResults[i];
        print(result);
        if (result['success'] == true) {
          uploadedAttachments.add(Attachment(
            file: attachments[i].file,
            type: attachments[i].type,
            url: result['url'] as String,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to upload ${attachments[i].file.path.split('/').last}: ${result['message']}',
                style: GoogleFonts.roboto(color: Colors.white),
              ),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    }

    // Early exit if no content and no successfully uploaded attachments
    if (content.trim().isEmpty && uploadedAttachments.isEmpty) {
      return;
    }

    // Prepare data for the backend
    Map<String, dynamic> postData = {
      'content': content.trim(),
      'attachment_urls': uploadedAttachments
          .where((att) => att.url != null)
          .map((att) => att.url!)
          .toList(),
    };

    // Call the backend to create the post
    final result = await dataController.createPost(postData);

    if (result['success'] == true) {
      setState(() {
        _posts.insert(
          0,
          ChatterPost(
            username: "YourName", // Assuming "YourName" is a placeholder for the actual user
            content: content.trim(),
            timestamp: DateTime.now(),
            attachments: uploadedAttachments, // Use the full Attachment objects for the UI
            avatarInitial: "Y", // Placeholder for avatar
            views: Random().nextInt(100) + 10, // Placeholder for views
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Poa! Your chatter is live!',
            style: GoogleFonts.roboto(color: Colors.white),
          ),
          backgroundColor: Colors.teal[700],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to create post on server: ${result['message'] ?? 'Unknown error'}',
            style: GoogleFonts.roboto(color: Colors.white),
          ),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  void _showRepliesDialog(ChatterPost post) {
    final replyController = TextEditingController();
    final List<Attachment> replyAttachments = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Color(0xFF000000),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.tealAccent, width: 2),
              ),
              contentPadding: EdgeInsets.all(16),
              title: Text(
                'Replies',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[800]!),
                          ),
                        ),
                        child: _buildPostContent(post, isReply: false),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: post.replies.length,
                        separatorBuilder: (context, index) => Divider(
                          color: Colors.grey[800],
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.only(left: 16),
                            child: _buildPostContent(post.replies[index], isReply: true),
                          );
                        },
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: replyController,
                        maxLength: 280,
                        maxLines: 3,
                        style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "Post your reply...",
                          hintStyle: GoogleFonts.roboto(color: Colors.grey[500]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.tealAccent),
                          ),
                          filled: true,
                          fillColor: Color(0xFF252525),
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(FeatherIcons.image, color: Colors.tealAccent),
                            onPressed: () async {
                              final picker = ImagePicker();
                              final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                              if (image != null) {
                                final file = File(image.path);
                                final sizeInMB = file.lengthSync() / (1024 * 1024);
                                if (sizeInMB <= 10) {
                                  setDialogState(() {
                                    replyAttachments.add(
                                      Attachment(
                                        file: file,
                                        type: "image",
                                      ),
                                    );
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'File must be under 10MB!',
                                        style: GoogleFonts.roboto(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.red[700],
                                    ),
                                  );
                                }
                              }
                            },
                            tooltip: 'Upload Image',
                          ),
                          IconButton(
                            icon: Icon(FeatherIcons.fileText, color: Colors.tealAccent),
                            onPressed: () async {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['pdf'],
                                allowMultiple: false,
                              );
                              if (result != null && result.files.single.path != null) {
                                final file = File(result.files.single.path!);
                                final sizeInMB = file.lengthSync() / (1024 * 1024);
                                if (sizeInMB <= 10) {
                                  setDialogState(() {
                                    replyAttachments.add(
                                      Attachment(
                                        file: file,
                                        type: "pdf",
                                      ),
                                    );
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'File must be under 10MB!',
                                        style: GoogleFonts.roboto(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.red[700],
                                    ),
                                  );
                                }
                              }
                            },
                            tooltip: 'Upload Document',
                          ),
                          IconButton(
                            icon: Icon(FeatherIcons.music, color: Colors.tealAccent),
                            onPressed: () async {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.audio,
                                allowMultiple: false,
                              );
                              if (result != null && result.files.single.path != null) {
                                final file = File(result.files.single.path!);
                                final sizeInMB = file.lengthSync() / (1024 * 1024);
                                if (sizeInMB <= 10) {
                                  setDialogState(() {
                                    replyAttachments.add(
                                      Attachment(
                                        file: file,
                                        type: "audio",
                                      ),
                                    );
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'File must be under 10MB!',
                                        style: GoogleFonts.roboto(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.red[700],
                                    ),
                                  );
                                }
                              }
                            },
                            tooltip: 'Upload Audio',
                          ),
                          IconButton(
                            icon: Icon(FeatherIcons.video, color: Colors.tealAccent),
                            onPressed: () async {
                              final picker = ImagePicker();
                              final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
                              if (video != null) {
                                final file = File(video.path);
                                final sizeInMB = file.lengthSync() / (1024 * 1024);
                                if (sizeInMB <= 10) {
                                  setDialogState(() {
                                    replyAttachments.add(
                                      Attachment(
                                        file: file,
                                        type: "video",
                                      ),
                                    );
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'File must be under 10MB!',
                                        style: GoogleFonts.roboto(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.red[700],
                                    ),
                                  );
                                }
                              }
                            },
                            tooltip: 'Upload Video',
                          ),
                        ],
                      ),
                      if (replyAttachments.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: replyAttachments.map((attachment) {
                            return Chip(
                              label: Text(
                                attachment.file.path.split('/').last,
                                style: GoogleFonts.roboto(color: Colors.white, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                              backgroundColor: Colors.grey[800],
                              deleteIcon: Icon(FeatherIcons.x, size: 16, color: Colors.white),
                              onDeleted: () {
                                setDialogState(() {
                                  replyAttachments.remove(attachment);
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.roboto(color: Colors.grey[400]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (replyController.text.trim().isEmpty && replyAttachments.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please enter some text or add attachments!',
                            style: GoogleFonts.roboto(color: Colors.white),
                          ),
                          backgroundColor: Colors.red[700],
                        ),
                      );
                      return;
                    }

                    // Upload reply attachments to Cloudinary
                    List<Attachment> uploadedReplyAttachments = [];
                    if (replyAttachments.isNotEmpty) {
                      List<File> files = replyAttachments.map((a) => a.file).toList();
                      List<Map<String, dynamic>> uploadResults = await dataController.uploadFilesToCloudinary(files);
                      
                      for (int i = 0; i < replyAttachments.length; i++) {
                        var result = uploadResults[i];
                        if (result['success'] == true) {
                          uploadedReplyAttachments.add(Attachment(
                            file: replyAttachments[i].file,
                            type: replyAttachments[i].type,
                            url: result['url'] as String,
                          ));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to upload ${replyAttachments[i].file.path.split('/').last}: ${result['message']}',
                                style: GoogleFonts.roboto(color: Colors.white),
                              ),
                              backgroundColor: Colors.red[700],
                            ),
                          );
                        }
                      }
                    }

                    if (replyController.text.trim().isEmpty && uploadedReplyAttachments.isEmpty) {
                      return; // No content and no successful uploads
                    }

                    setState(() {
                      post.replies.add(
                        ChatterPost(
                          username: "YourName",
                          content: replyController.text.trim(),
                          timestamp: DateTime.now(),
                          attachments: uploadedReplyAttachments,
                          avatarInitial: "Y",
                          views: Random().nextInt(100) + 10,
                        ),
                      );
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Poa! Reply posted!',
                          style: GoogleFonts.roboto(color: Colors.white),
                        ),
                        backgroundColor: Colors.teal[700],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Reply',
                    style: GoogleFonts.roboto(color: Colors.black, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPostContent(ChatterPost post, {required bool isReply}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: isReply ? 16 : 20,
              backgroundColor: Colors.tealAccent.withOpacity(0.2),
              child: Text(
                post.avatarInitial,
                style: GoogleFonts.poppins(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: isReply ? 14 : 16,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '@${post.username}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: isReply ? 14 : 16,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        DateFormat('h:mm a · MMM d').format(post.timestamp),
                        style: GoogleFonts.roboto(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    post.content,
                    style: GoogleFonts.roboto(
                      fontSize: isReply ? 13 : 14,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  if (post.attachments.isNotEmpty) ...[
                    SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: post.attachments.length > 1 ? 2 : 1,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: post.attachments.length,
                      itemBuilder: (context, idx) {
                        final attachment = post.attachments[idx];
                        final displayUrl = attachment.url ?? attachment.file.path;
                        return GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Opening ${attachment.type}: ${displayUrl.split('/').last}',
                                  style: GoogleFonts.roboto(color: Colors.white),
                                ),
                                backgroundColor: Colors.teal[700],
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: attachment.type == "image"
                                ? attachment.url != null
                                    ? Image.network(
                                        attachment.url!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: Colors.grey[900],
                                          child: Icon(
                                            FeatherIcons.image,
                                            color: Colors.grey[500],
                                            size: 40,
                                          ),
                                        ),
                                      )
                                    : Image.file(
                                        attachment.file,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: Colors.grey[900],
                                          child: Icon(
                                            FeatherIcons.image,
                                            color: Colors.grey[500],
                                            size: 40,
                                          ),
                                        ),
                                      )
                                : attachment.type == "pdf"
                                    ? PdfViewer.uri(
                                        Uri.parse(displayUrl),
                                        params: PdfViewerParams(
                                          maxScale: 1.0,
                                        ),
                                      )
                                    : Container(
                                        color: Colors.grey[900],
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              attachment.type == "audio" ? FeatherIcons.music : FeatherIcons.video,
                                              color: Colors.tealAccent,
                                              size: 40,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              displayUrl.split('/').last,
                                              style: GoogleFonts.roboto(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                          ),
                        );
                      },
                    ),
                  ],
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              FeatherIcons.heart,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                post.likes++;
                              });
                            },
                          ),
                          Text(
                            '${post.likes}',
                            style: GoogleFonts.roboto(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              FeatherIcons.messageCircle,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () {
                              _showRepliesDialog(post);
                            },
                          ),
                          Text(
                            '${post.replies.length}',
                            style: GoogleFonts.roboto(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              FeatherIcons.repeat,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                post.reposts++;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Poa! Reposted!',
                                    style: GoogleFonts.roboto(color: Colors.white),
                                  ),
                                  backgroundColor: Colors.teal[700],
                                ),
                              );
                            },
                          ),
                          Text(
                            '${post.reposts}',
                            style: GoogleFonts.roboto(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              FeatherIcons.eye,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () {},
                          ),
                          Text(
                            '${post.views}',
                            style: GoogleFonts.roboto(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF000000),
      appBar: AppBar(
        title: Text(
          'Chatter',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 24,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF000000),
        elevation: 0,
      ),
      body: ListView.separated(
        itemCount: _posts.length,
        separatorBuilder: (context, index) => Divider(
          color: Colors.grey[850],
          height: 1,
        ),
        itemBuilder: (context, index) {
          final post = _posts[index];
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: ModalRoute.of(context)!.animation!,
              curve: Curves.easeInOut,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: _buildPostContent(post, isReply: false),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color(0xFF000000),
        selectedItemColor: Colors.tealAccent,
        unselectedItemColor: Colors.grey[500],
        selectedLabelStyle: GoogleFonts.roboto(fontWeight: FontWeight.w500),
        unselectedLabelStyle: GoogleFonts.roboto(),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(FeatherIcons.home, size: 24),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(FeatherIcons.search, size: 24),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(FeatherIcons.user, size: 24),
            label: 'Profile',
          ),
        ],
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Search screen coming soon!',
                  style: GoogleFonts.roboto(color: Colors.white),
                ),
                backgroundColor: Colors.teal[700],
              ),
            );
          } else if (index == 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Profile screen coming soon!',
                  style: GoogleFonts.roboto(color: Colors.white),
                ),
                backgroundColor: Colors.teal[700],
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToPostScreen,
        backgroundColor: Colors.tealAccent,
        elevation: 2,
        child: Icon(FeatherIcons.plus, color: Colors.black),
      ),
    );
  }
}