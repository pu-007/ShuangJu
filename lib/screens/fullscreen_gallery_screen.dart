import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
// Added imports (ensure they are present)
import 'package:provider/provider.dart';
import 'package:shuang_ju/models/tv_show.dart';
import 'package:shuang_ju/providers/tv_show_notifier.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p; // For basename

class FullscreenGalleryScreen extends StatefulWidget {
  final List<File> imageFiles;
  final int initialIndex;
  // final Map<String, String> inlineLines; // Remove inlineLines map
  final TvShow tvShow; // Add TvShow object

  const FullscreenGalleryScreen({
    super.key,
    required this.imageFiles,
    required this.initialIndex,
    // required this.inlineLines, // Remove inlineLines requirement
    required this.tvShow, // Make tvShow required
  });

  @override
  State<FullscreenGalleryScreen> createState() =>
      _FullscreenGalleryScreenState();
}

class _FullscreenGalleryScreenState extends State<FullscreenGalleryScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- Improved Export Functionality ---
  Future<void> _exportImage(BuildContext context, File imageFile) async {
    final scaffoldMessenger = ScaffoldMessenger.of(
      context,
    ); // Capture messenger
    PermissionStatus status;

    // 1. Request Permission
    if (Platform.isAndroid) {
      // Request storage permission for Android.
      // Note: This might have limitations on Android 11+ due to Scoped Storage.
      // Saving to app's external dir is generally allowed.
      status = await Permission.storage.request();
    } else if (Platform.isIOS) {
      // Request photos permission for iOS (add description in Info.plist)
      // Saving to app's Documents directory doesn't require special permission.
      // We'll save to Documents directory on iOS.
      status =
          PermissionStatus.granted; // Assume granted for Documents dir access
      // If saving to Photos is desired later, use:
      // status = await Permission.photosAddOnly.request();
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('导出功能暂不支持此平台')),
      );
      return;
    }

    // 2. Check Permission and Get Directory
    if (status.isGranted) {
      try {
        Directory? targetDir;
        String targetDirDescription = ""; // Initialize with a default value

        if (Platform.isAndroid) {
          // Use the Pictures/ShuangJu directory for Android
          targetDir = Directory('/storage/emulated/0/Pictures/ShuangJu');
          targetDirDescription = "图片/ShuangJu 目录";

          // Create the directory if it doesn't exist
          if (!await targetDir.exists()) {
            await targetDir.create(recursive: true);
          }
        } else if (Platform.isIOS) {
          // Use getApplicationDocumentsDirectory for iOS app's private storage.
          targetDir = await getApplicationDocumentsDirectory();
          targetDirDescription = "应用的文档目录";
        }

        if (targetDir == null) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('无法获取目标存储目录')),
          );
          return;
        }

        final String originalFileName = p.basename(imageFile.path);
        final String destinationPath = p.join(targetDir.path, originalFileName);

        // 3. Copy File
        // Check if file already exists (optional, overwriting here)
        if (await File(destinationPath).exists()) {
          print("Overwriting existing file: $destinationPath");
        }
        await imageFile.copy(destinationPath);

        // 4. Show Success Message
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('图片已导出到 $targetDirDescription: ${targetDir.path}'),
            duration: const Duration(seconds: 5), // Show longer
          ),
        );
        print("Image exported to: $destinationPath");
      } catch (e) {
        print("Error exporting image: $e");
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('导出图片失败: $e')));
      }
    } else {
      // Handle Permission Denied
      String message = '需要存储权限才能导出图片。';
      SnackBarAction? action;
      if (status.isPermanentlyDenied) {
        message += '请在应用设置中授予权限。';
        action = SnackBarAction(
          label: '设置',
          onPressed: openAppSettings, // Open app settings
        );
      }
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(message), action: action),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access the latest TvShow state using Consumer or Provider.of if needed for reactivity,
    // but for initial build and passing to dialog, widget.tvShow is fine.
    // Let's refine this when adding the edit dialog.
    final currentImageFile = widget.imageFiles[_currentIndex];
    final currentImageName = p.basename(currentImageFile.path);
    // Access inline lines from the TvShow object passed in constructor initially
    // We will use Consumer later for the displayed text itself.
    // final currentInlineText = widget.tvShow.inline_lines[currentImageName]; // Keep this logic for passing to dialog initially

    return Scaffold(
      backgroundColor: Colors.black, // Dark background for gallery
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.7), // Use withOpacity
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.imageFiles.length}'),
        actions: [
          // Edit Button
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '编辑台词',
            onPressed: () {
              // Get the current text at the moment the button is pressed
              final currentShow =
                  Provider.of<TvShowNotifier>(
                    context,
                    listen: false,
                  ).findTvShowByName(widget.tvShow.name) ??
                  widget.tvShow;
              final currentText =
                  currentShow.inline_lines[currentImageName] ?? '';
              _showEditLineDialog(
                context,
                currentImageFile,
                currentImageName,
                currentText,
              );
            },
          ),
          // Download Button
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: '导出图片',
            onPressed: () {
              _exportImage(context, currentImageFile);
            },
          ),
        ],
      ),
      body: Stack(
        // Use Stack to overlay text
        children: [
          PhotoViewGallery.builder(
            itemCount: widget.imageFiles.length,
            pageController: _pageController,
            builder: (context, index) {
              final imageFile = widget.imageFiles[index];
              return PhotoViewGalleryPageOptions(
                imageProvider: FileImage(imageFile),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained * 0.8,
                maxScale: PhotoViewComputedScale.covered * 2.0,
                heroAttributes: PhotoViewHeroAttributes(
                  tag: imageFile.path,
                ), // Optional Hero animation
              );
            },
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            loadingBuilder:
                (context, event) => Center(
                  // Removed const
                  child: SizedBox(
                    // Removed const
                    width: 20.0,
                    height: 20.0,
                    child: CircularProgressIndicator(
                      value:
                          event == null || event.expectedTotalBytes == null
                              ? null
                              : event.cumulativeBytesLoaded /
                                  event.expectedTotalBytes!,
                    ),
                  ),
                ),
          ),
          // Inline Text Overlay (if exists) - Positioned at the bottom
          // Use Consumer to react to changes in TvShowNotifier for the text
          Consumer<TvShowNotifier>(
            builder: (context, notifier, child) {
              // Find the latest show data using the current image name
              final latestShow =
                  notifier.findTvShowByName(widget.tvShow.name) ??
                  widget.tvShow;
              final latestInlineText =
                  latestShow.inline_lines[currentImageName];

              if (latestInlineText == null || latestInlineText.isEmpty) {
                return const SizedBox.shrink(); // Return empty if no text
              }

              // Build the text overlay using the latest data
              return Positioned(
                bottom: 20, // Adjust position as needed
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: 0.7,
                    ), // Use withOpacity
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    latestInlineText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16, // Slightly larger font size
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Edit Dialog ---
  Future<void> _showEditLineDialog(
    BuildContext context,
    File imageFile,
    String imageName,
    String currentText,
  ) async {
    final TextEditingController textController = TextEditingController(
      text: currentText,
    );
    // No need to get notifier here, get it inside onPressed

    return showDialog<void>(
      context: context,
      barrierDismissible: true, // Allow dismissing by tapping outside
      builder: (BuildContext dialogContext) {
        // Use the dialog's context to get the notifier
        final notifier = Provider.of<TvShowNotifier>(
          dialogContext,
          listen: false,
        );
        return AlertDialog(
          title: const Text('编辑图片台词'),
          content: SingleChildScrollView(
            // In case text is long
            child: TextField(
              controller: textController,
              autofocus: true,
              maxLines: null, // Allow multiple lines
              decoration: const InputDecoration(
                hintText: '输入台词...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text('保存'),
              onPressed: () async {
                final newText = textController.text.trim();
                // Find the *latest* show state before updating
                // Use widget.tvShow.name as the key
                final currentShow = notifier.findTvShowByName(
                  widget.tvShow.name,
                );

                if (currentShow != null) {
                  // Create a mutable copy of the inline_lines map
                  final updatedInlineLines = Map<String, String>.from(
                    currentShow.inline_lines,
                  );

                  // Update or remove the entry based on imageName
                  if (newText.isEmpty) {
                    updatedInlineLines.remove(
                      imageName,
                    ); // Remove if text is empty
                    print('已删除图片台词: $imageName');
                  } else {
                    updatedInlineLines[imageName] = newText; // Add/Update entry
                    print('已更新图片台词: $imageName -> $newText');
                  }

                  // Create a copy of the show with the updated map
                  final updatedShow = currentShow.copyWith(
                    inline_lines: updatedInlineLines,
                  );
try {
  // 使用更新后的参数确保立即保存到JSON文件
  print("保存图片台词修改: $imageName -> ${newText.isEmpty ? '删除' : newText}");
  await notifier.updateTvShow(updatedShow, forceJsonSave: true);
  
  // 显示成功消息
  if (mounted) {
    ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(newText.isEmpty ? '台词已删除' : '台词已保存'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                      Navigator.of(dialogContext).pop(); // Close the dialog on success
                    }
                  } catch (e) {
                    print("Error saving inline line: $e");
                    // Check mount status before showing snackbar
                    if (mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        // Use dialogContext
                        SnackBar(content: Text('保存失败: $e')),
                      );
                    }
                  }
                } else {
                  print(
                    "Error: Could not find TvShow '${widget.tvShow.name}' to update inline line.",
                  );
                  // Check mount status before showing snackbar
                  if (mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      // Use dialogContext
                      const SnackBar(content: Text('无法找到电视剧以保存更改')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}
