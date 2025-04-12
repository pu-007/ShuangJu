import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shuang_ju/models/tv_show.dart';
import 'package:shuang_ju/providers/tv_show_notifier.dart';
import 'package:shuang_ju/screens/fullscreen_gallery_screen.dart';

class GalleryScreen extends StatefulWidget {
  final TvShow tvShow;

  const GalleryScreen({super.key, required this.tvShow});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<File> _galleryImages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGalleryImages();
  }

  Future<void> _loadGalleryImages() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    if (widget.tvShow.directoryPath == null) {
      if (mounted) setState(() => _isLoading = false);
      print("Gallery Error: Directory path is null for ${widget.tvShow.name}");
      return;
    }

    final directory = Directory(widget.tvShow.directoryPath!);
    if (!await directory.exists()) {
      if (mounted) setState(() => _isLoading = false);
      print("Gallery Error: Directory not found: ${directory.path}");
      return;
    }

    List<File> imageFiles = [];
    try {
      await for (final entity in directory.list()) {
        if (entity is File) {
          final filename = p.basename(entity.path);
          final extension = p.extension(filename).toLowerCase();
          if ([
                '.jpg',
                '.jpeg',
                '.png',
                '.gif',
                '.bmp',
                '.webp',
              ].contains(extension) &&
              filename != 'cover.jpg' &&
              filename != 'themesong.mp3') {
            imageFiles.add(entity);
          }
        }
      }
      imageFiles.sort((a, b) => a.path.compareTo(b.path));

      if (mounted) {
        setState(() {
          _galleryImages = imageFiles;
          _isLoading = false;
        });
      }
      print(
        "Loaded ${_galleryImages.length} gallery images for ${widget.tvShow.name}",
      );
    } catch (e) {
      print("Error loading gallery images for ${widget.tvShow.name}: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.tvShow.name} - 相册')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _galleryImages.isEmpty
              ? const Center(child: Text('没有找到图片'))
              : GridView.builder(
                padding: const EdgeInsets.all(8.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // Adjust columns as needed
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                ),
                itemCount: _galleryImages.length,
                itemBuilder: (context, index) {
                  final imageFile = _galleryImages[index];
                  final imageName = p.basename(imageFile.path);
                  
                  // 使用Consumer获取最新的电视剧数据和台词
                  return Consumer<TvShowNotifier>(
                    builder: (context, notifier, child) {
                      // 获取最新的电视剧数据
                      final latestShow = notifier.findTvShowByName(widget.tvShow.name) ?? widget.tvShow;
                      // 获取最新的台词数据
                      final inlineText = latestShow.inline_lines[imageName];

                      return GestureDetector(
                        onTap: () {
                          print("Tapped image: $imageName");
                          // 导航到全屏图片查看器，并传递最新的电视剧数据
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullscreenGalleryScreen(
                                imageFiles: _galleryImages,
                                initialIndex: index,
                                tvShow: latestShow,
                              ),
                            ),
                          );
                        },
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          elevation: 1.0,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                imageFile,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) => const Center(
                                      child: Icon(Icons.broken_image),
                                    ),
                              ),
                              if (inlineText != null && inlineText.isNotEmpty)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2.0,
                                      horizontal: 4.0,
                                    ),
                                    color: Colors.black.withValues(alpha: 0.6),
                                    child: Text(
                                      inlineText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}
