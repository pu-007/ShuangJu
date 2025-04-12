import 'dart:async'; // Import async for StreamSubscription (might be removable later)
import 'package:flutter/material.dart';
import 'dart:io'; // Import dart:io for File class
import 'package:audioplayers/audioplayers.dart'; // Needed for PlayerState enum

// import 'package:audioplayers/audioplayers.dart'; // No longer needed here
import 'package:provider/provider.dart'; // Import Provider
import 'package:shuang_ju/models/tv_show.dart';
import 'package:shuang_ju/providers/play_source_notifier.dart'; // Import PlaySourceNotifier
import 'package:shuang_ju/providers/tv_show_notifier.dart'; // Import TvShowNotifier
import 'package:shuang_ju/services/audio_service.dart'; // Import AudioService
import 'package:path/path.dart' as p; // Import path package
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher
import 'fullscreen_gallery_screen.dart'; // Import the new screen
import 'edit_tv_show_screen.dart'; // 导入编辑电视剧屏幕

class TvShowDetailScreen extends StatefulWidget {
  final TvShow tvShow;

  const TvShowDetailScreen({super.key, required this.tvShow});

  @override
  State<TvShowDetailScreen> createState() => _TvShowDetailScreenState();
}

class _TvShowDetailScreenState extends State<TvShowDetailScreen> {
  // late AudioPlayer _audioPlayer; // Removed local audio player
  final TextEditingController _thoughtController = TextEditingController();
  List<File> _albumImages = [];
  bool _isLoadingAlbum = true; // Loading state for album
  String? _currentlyLoadingAlbumForShow; // Track which show's album is loading

  // Keys and Controller for scrolling
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _albumSectionKey = GlobalKey();
  final GlobalKey _linesSectionKey = GlobalKey();

  // Audio Player State is now managed by AudioService

  @override
  void initState() {
    super.initState();
    // _audioPlayer = AudioPlayer(); // Removed initialization
    // Don't load album images here initially, wait for the Selector to provide the show

    // Audio player listeners are now handled within AudioService
  }

  @override
  void dispose() {
    // Audio player subscriptions and disposal are handled by AudioService
    // _audioPlayer.stop(); // No longer needed
    // _audioPlayer.dispose(); // No longer needed
    _thoughtController.dispose();
    _scrollController.dispose(); // Dispose scroll controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get the initial name once
    final showName = widget.tvShow.name;
    // 侧边导航按钮的状态
    bool isNavExpanded = false;

    return Scaffold(
      appBar: AppBar(
        title: Text(showName), // Use initial name for title
        actions: [
          // 添加编辑按钮
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '编辑电视剧',
            onPressed: () {
              // 获取当前显示的电视剧
              final tvShowNotifier = Provider.of<TvShowNotifier>(
                context,
                listen: false,
              );
              final currentShow = tvShowNotifier.findTvShowByName(showName);
              if (currentShow != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => EditTvShowScreen(
                          tvShow: currentShow,
                          isEditing: true,
                        ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('无法编辑：找不到电视剧信息')));
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController, // Assign the scroll controller
            padding: const EdgeInsets.all(16.0), // Add padding
            // Use Selector to listen only to changes for *this specific show*
            child: Selector<TvShowNotifier, TvShow?>(
              selector: (_, notifier) => notifier.findTvShowByName(showName),
              // Rebuild only if the found show instance changes (or goes from null to non-null etc.)
              shouldRebuild: (previous, next) => previous != next,
              builder: (context, currentShowFromSelector, _) {
                // If the show was somehow deleted while viewing, handle it
                if (currentShowFromSelector == null) {
                  // Maybe pop the screen or show an error message
                  // For now, just show a placeholder
                  // Consider popping back automatically:
                  // WidgetsBinding.instance.addPostFrameCallback((_) {
                  //   if (Navigator.canPop(context)) {
                  //     Navigator.pop(context);
                  //   }
                  // });
                  return const Center(child: Text('电视剧信息丢失或已更改名称'));
                }

                // Use the show provided by the Selector
                final displayShow = currentShowFromSelector;

                // --- Trigger Album Load Logic ---
                // Check if we need to load the album for *this specific show*.
                // We trigger loading if we haven't started loading for this show yet.
                if (_currentlyLoadingAlbumForShow != displayShow.name) {
                  // Use addPostFrameCallback to schedule the load after the build.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    // Double-check mounted status before async operations and setState.
                    if (mounted) {
                      // Set loading state *before* starting the async operation.
                      // This ensures the UI shows loading immediately and prevents
                      // potential race conditions if the builder runs again quickly.
                      setState(() {
                        _isLoadingAlbum = true;
                        _currentlyLoadingAlbumForShow = displayShow.name;
                        _albumImages = []; // Clear any previous album images
                      });
                      // Now, call the actual loading function.
                      _loadAlbumImages(displayShow);
                    }
                  });
                  // While loading is scheduled, ensure the UI shows loading state immediately
                  // if _isLoadingAlbum wasn't already true. This handles the very first build.
                  if (!_isLoadingAlbum) {
                    // This setState is safe here because it's guarded by the outer if,
                    // ensuring it only runs once per show transition.
                    // We set it directly (not in postFrameCallback) for immediate UI feedback.
                    _isLoadingAlbum = true;
                    _albumImages =
                        []; // Clear images for immediate feedback too
                  }
                }
                // --- End Trigger Album Load Logic ---

                // Now build the Column using displayShow
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pass displayShow to helper methods
                    _buildBasicInfoSection(context, displayShow),
                    const SizedBox(height: 24),
                    _buildAlbumSection(
                      context,
                      displayShow,
                      key: _albumSectionKey,
                    ),
                    const SizedBox(height: 24),
                    _buildLinesSection(
                      context,
                      displayShow,
                      key: _linesSectionKey,
                    ),
                  ],
                );
              },
            ),
          ),

          // 侧边折叠导航按钮
          StatefulBuilder(
            builder: (context, setState) {
              return Positioned(
                right: 0,
                top: MediaQuery.of(context).size.height * 0.4,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isNavExpanded ? 140 : 40,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.8),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: const Offset(-2, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 展开/折叠按钮
                      IconButton(
                        icon: Icon(
                          isNavExpanded
                              ? Icons.keyboard_arrow_right
                              : Icons.keyboard_arrow_left,
                          color: Colors.white,
                        ),
                        onPressed:
                            () =>
                                setState(() => isNavExpanded = !isNavExpanded),
                        tooltip: isNavExpanded ? '收起导航' : '展开导航',
                      ),

                      // 导航按钮组
                      if (isNavExpanded) ...[
                        _buildNavButton(
                          icon: Icons.arrow_upward,
                          label: '回到顶部',
                          onPressed: () {
                            _scrollController.animateTo(
                              0,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                            );
                          },
                        ),
                        _buildNavButton(
                          icon: Icons.photo_library_outlined,
                          label: '相册',
                          onPressed: () {
                            final targetContext =
                                _albumSectionKey.currentContext;
                            if (targetContext != null) {
                              Scrollable.ensureVisible(
                                targetContext,
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                        ),
                        _buildNavButton(
                          icon: Icons.format_quote_outlined,
                          label: '台词',
                          onPressed: () {
                            final targetContext =
                                _linesSectionKey.currentContext;
                            if (targetContext != null) {
                              Scrollable.ensureVisible(
                                targetContext,
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 构建导航按钮
  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build Basic Info Section
  // Modify to accept TvShow parameter instead of using widget.tvShow
  Widget _buildBasicInfoSection(BuildContext context, TvShow displayShow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover Image
        Center(
          // Center the image
          child: ClipRRect(
            // Add rounded corners
            borderRadius: BorderRadius.circular(8.0),
            child: Image.file(
              File(
                displayShow.coverImagePath, // Use displayShow
              ), // Use Image.file for local files
              height: 300, // Increased height for detail view
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) => Container(
                    height: 300, // Match height
                    color: Colors.grey[300],
                    child: Center(
                      // Center the icon within the container
                      child: Icon(
                        Icons.broken_image,
                        size: 100, // Keep icon size reasonable
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
            ),
          ),
        ),
        const SizedBox(height: 16), // Add space after image
        Text(
          displayShow.name, // Use displayShow
          style: Theme.of(
            context,
          ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        ), // Show name
        if (displayShow.alias != null && displayShow.alias!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10), // Add spacing
            child: Text(
              displayShow.alias!, // Use displayShow alias
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          displayShow.overview, // Use displayShow
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey[800]),
        ),
        const SizedBox(height: 16),
        // Action Buttons Row (Theme Song, Play, Thoughts)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Use displayShow for actions
            ElevatedButton.icon(
              // Theme Song Button
              onPressed: () async {
                // Use AudioService to play the theme song
                final audioService = Provider.of<AudioService>(context, listen: false);
                await audioService.playThemeSong(displayShow);

                // Show snackbar (optional, AudioService could handle this too)
                if (mounted) {
                   // Check if the audio service actually started playing this show's song
                   if (audioService.currentShow?.name == displayShow.name && audioService.isPlaying) {
                      ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('正在播放 ${displayShow.name} 主题曲')),
                      );
                   } else if (audioService.playerState == PlayerState.stopped && audioService.currentShow == null) {
                      // Handle cases where playThemeSong might have failed internally
                      // (e.g., file not found, which AudioService now handles)
                      // You might want AudioService to expose an error state or return a boolean
                      ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('播放主题曲失败，请检查文件是否存在')),
                      );
                   }
                }
              },
              icon: const Icon(Icons.music_note),
              label: const Text('主题曲'),
            ),
            ElevatedButton.icon(
              // Play Sources Button
              onPressed: () {
                _showPlaySourcesDialog(
                  context,
                  displayShow, // Use displayShow
                ); // Show play sources
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('播放'),
            ),
            ElevatedButton.icon(
              // Thoughts Button
              onPressed: () {
                _showThoughtsDialog(
                  context,
                  displayShow, // Use displayShow
                ); // Show thoughts dialog
              },
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('想法'),
            ),
          ],
        ),
        const SizedBox(height: 10), // Space before music controls
        // --- Music Player Controls ---
        // --- Music Player Controls (using Consumer for AudioService) ---
        // Always build the controls container, but content visibility depends on AudioService state
        _buildMusicControls(),
        const SizedBox(height: 16), // Space before progress indicator
        // --- Progress Indicator & Controls (Now directly uses displayShow) ---
        Column(
          // Use a Column to group the two Rows
          children: [
            Row(
              // Row for label and indicator
              children: [
                Text(
                  '观看进度:', // Label
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value:
                        displayShow
                            .progress
                            .percentage, // Directly use displayShow
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
            Row(
              // Row for +/- buttons and text display
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: '减少进度',
                  // Disable if current is 0 or less
                  onPressed:
                      (displayShow.progress.current <= 0)
                          ? null
                          : () {
                            // Get notifier using Provider.of
                            final notifier = Provider.of<TvShowNotifier>(
                              context,
                              listen: false,
                            );
                            final current = displayShow.progress.current - 1;
                            notifier.updateProgress(
                              displayShow, // Pass the current instance from Selector
                              current,
                              displayShow.progress.total,
                            );
                          },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '${displayShow.progress.current} / ${displayShow.progress.total}', // Directly use displayShow
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: '增加进度',
                  // Disable if current is total or more
                  onPressed:
                      (displayShow.progress.current >=
                              displayShow.progress.total)
                          ? null
                          : () {
                            // Get notifier using Provider.of
                            final notifier = Provider.of<TvShowNotifier>(
                              context,
                              listen: false,
                            );
                            final current = displayShow.progress.current + 1;
                            notifier.updateProgress(
                              displayShow, // Pass the current instance from Selector
                              current,
                              displayShow.progress.total,
                            );
                          },
                ),
              ],
            ),
            const SizedBox(height: 16), // Add space before jump buttons
            // --- Jump Buttons ---
            _buildJumpButtons(
              context,
            ), // Jump buttons don't depend on the show data directly
          ],
        ),
      ],
    );
  }

  // --- Method to load album images ---
  // Modify to accept TvShow parameter
  Future<void> _loadAlbumImages(TvShow displayShow) async {
    // Log added at the very beginning of the function
    print(
      "DEBUG: [Load Func] Entered for ${displayShow.name}. Checking mounted status...",
    );
    if (!mounted) {
      // Log added if mounted is false at the start of the function
      print(
        "DEBUG: [Load Func] Widget is NOT mounted for ${displayShow.name}. Aborting.",
      );
      return;
    }
    print(
      "DEBUG: [Load Func] Widget is mounted for ${displayShow.name}. Proceeding with load.",
    );

    // Removed the concurrent loading check here as it was causing premature exit.
    // The check in the Selector builder should handle preventing duplicate loads.

    setState(() {
      _isLoadingAlbum = true;
      _currentlyLoadingAlbumForShow =
          displayShow.name; // Mark this show as loading
      _albumImages =
          []; // Clear previous images when starting load for a new show
    });
    // Log added *immediately* after setState
    print(
      "DEBUG: [Load Func] setState completed for ${displayShow.name}. Now checking directory path...",
    );

    if (displayShow.directoryPath == null) {
      // Use displayShow
      print(
        "DEBUG: Attempting to load album for ${displayShow.name}, but directoryPath is null.",
      ); // Added log
      if (mounted) {
        setState(() {
          _isLoadingAlbum = false;
          _currentlyLoadingAlbumForShow = null; // Reset loading tracker
        });
      }
      print(
        "Error: Directory path is null for ${displayShow.name}",
      ); // Use displayShow
      return; // No path, nothing to load
    }
    print(
      "DEBUG: Loading album images from directory: ${displayShow.directoryPath}",
    ); // Added log

    final directory = Directory(displayShow.directoryPath!); // Use displayShow
    final directoryExists = await directory.exists(); // Added check
    print("DEBUG: Directory exists: $directoryExists"); // Added log
    if (!directoryExists) {
      if (mounted) {
        setState(() {
          _isLoadingAlbum = false;
          _currentlyLoadingAlbumForShow = null; // Reset loading tracker
        });
      }
      print("Error: Directory not found: ${directory.path}");
      return; // Directory doesn't exist
    }

    List<File> imageFiles = [];
    try {
      await for (final entity in directory.list()) {
        if (entity is File) {
          print("DEBUG: Checking file: ${entity.path}"); // Added log
          final filename = p.basename(entity.path); // Get filename
          final extension = p.extension(filename).toLowerCase();
          // Check if it's an image file and not cover/themesong
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
            // Ensure correct themesong filename check
            imageFiles.add(entity);
            
            // 打印图片文件名和对应的台词（用于调试）
            final inlineText = displayShow.inline_lines[filename];
            print("DEBUG: 图片文件 $filename ${inlineText != null ? '有台词: $inlineText' : '无台词'}");
          }
        }
      }
      // Sort images if needed (e.g., by name or date modified)
      imageFiles.sort(
        (a, b) => a.path.compareTo(b.path),
      ); // Simple sort by path

      if (mounted) {
        setState(() {
          _albumImages = imageFiles;
          _isLoadingAlbum = false;
          // DO NOT reset _currentlyLoadingAlbumForShow here on success,
          // as it causes an infinite reload loop. It should remain set
          // to the currently loaded show's name.
        });
      }
      print(
        "DEBUG: Successfully loaded ${_albumImages.length} album images for ${displayShow.name}: ${_albumImages.map((f) => f.path).toList()}", // Added log with paths
      );
    } catch (e) {
      print(
        "Error loading album images for ${displayShow.name}: $e",
      ); // Use displayShow
      if (mounted) {
        setState(() {
          _isLoadingAlbum = false;
          _currentlyLoadingAlbumForShow =
              null; // Reset loading tracker on error
        });
        // Optionally show an error message to the user
      }
    }
  }

  // Build Album Section
  // Update method signature to accept Key and TvShow
  Widget _buildAlbumSection(
    BuildContext context,
    TvShow displayShow, {
    Key? key,
  }) {
    return Column(
      key: key, // Assign the key to the Column
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('剧照相册', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12), // Increased spacing
        _isLoadingAlbum // Use the state variable directly
            ? const Center(child: CircularProgressIndicator())
            : _albumImages.isEmpty
            ? const Center(child: Text('没有找到剧照'))
            : GridView.builder(
              shrinkWrap: true, // Important inside SingleChildScrollView
              physics:
                  const NeverScrollableScrollPhysics(), // Disable GridView's own scrolling
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Adjust number of columns
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                childAspectRatio: 0.75, // Adjust aspect ratio (width / height)
              ),
              itemCount: _albumImages.length,
              itemBuilder: (context, index) {
                final imageFile = _albumImages[index];
                final imageName = p.basename(imageFile.path);
                
                // 使用Consumer来实时获取最新的inline_lines数据
                return Consumer<TvShowNotifier>(
                  builder: (context, notifier, child) {
                    // 获取最新的电视剧数据
                    final latestShow = notifier.findTvShowByName(displayShow.name) ?? displayShow;
                    // 获取最新的台词数据
                    final inlineText = latestShow.inline_lines[imageName];
                    
                    return InkWell(
                      // Wrap Card with InkWell for tap detection
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => FullscreenGalleryScreen(
                                  imageFiles: _albumImages,
                                  initialIndex: index,
                                  // 传递最新的电视剧对象
                                  tvShow: latestShow,
                                ),
                          ),
                        );
                      },
                      child: Card(
                    // Wrap image in a card for better visual separation
                    clipBehavior: Clip.antiAlias,
                    elevation: 2.0,
                    child: Stack(
                      // Use Stack to overlay text
                      fit: StackFit.expand, // Make stack fill the card
                      children: [
                        // Image
                        Hero(
                          // Add Hero animation
                          tag: imageFile.path, // Use unique tag (file path)
                          child: Image.file(
                            imageFile,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.broken_image),
                                ),
                          ),
                        ),
                        // Inline Text Overlay (if exists)
                        if (inlineText != null && inlineText.isNotEmpty)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                                horizontal: 6.0,
                              ),
                              color: Colors.black.withValues(
                                alpha: 0.6,
                              ), // Use withOpacity
                              child: Text(
                                inlineText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2, // Limit lines
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
      ],
    );
  }

  // Build Lines Section
  // Update method signature to accept Key and TvShow
  Widget _buildLinesSection(
    BuildContext context,
    TvShow displayShow, {
    Key? key,
  }) {
    return Column(
      key: key, // Assign the key to the Column
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('经典台词', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        // Iterate over lines list from displayShow
        if (displayShow.lines.isEmpty) // Use displayShow
          const Text('暂无台词')
        else
          // 使用Consumer获取最新的电视剧数据
          Consumer<TvShowNotifier>(
            builder: (context, notifier, child) {
              // 获取最新的电视剧数据
              final latestShow = notifier.findTvShowByName(displayShow.name) ?? displayShow;
              
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: latestShow.lines.length,
                itemBuilder: (context, index) {
                  final line = latestShow.lines[index];
                  return InkWell(
                    onTap: () {
                      // 点击时显示全文对话框
                      _showLineDetailDialog(context, latestShow, index);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.7),
                            Theme.of(
                              context,
                            ).colorScheme.secondary.withValues(alpha: 0.5),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 半透明背景
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            // 台词内容
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Center(
                                child: Text(
                                  line,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black38,
                                        blurRadius: 2,
                                        offset: Offset(1, 1),
                                      ),
                                    ],
                                  ),
                                  maxLines: 4, // 限制显示行数
                                  overflow: TextOverflow.ellipsis, // 超出部分显示省略号
                                ),
                              ),
                            ),
                            // 引号装饰
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Icon(
                                Icons.format_quote,
                                color: Colors.white.withValues(alpha: 0.3),
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  // --- Helper method to show play sources ---
  void _showPlaySourcesDialog(BuildContext context, TvShow show) {
    // No change needed here, already accepts TvShow
    Provider.of<PlaySourceNotifier>(context, listen: false);
    // Use showModalBottomSheet's builder to handle loading state directly
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        // Use Consumer inside the builder to react to notifier changes
        return Consumer<PlaySourceNotifier>(
          builder: (context, notifier, child) {
            Widget content;
            if (notifier.isLoading) {
              content = const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (notifier.error != null) {
              content = Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('加载播放源失败: ${notifier.error}'),
                ),
              );
            } else if (notifier.sources.isEmpty) {
              // Trigger load if empty and not loading/error
              // Use addPostFrameCallback to avoid calling setState during build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!notifier.isLoading) {
                  // Check again to avoid race condition
                  notifier.loadPlaySources();
                }
              });
              // Show loading initially, will rebuild when state changes
              content = const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              );
            } else {
              // --- Build the list if sources are available ---
              final sources = notifier.sources;
              content = Flexible(
                // Make the ListView scrollable within the Column
                child: ListView.separated(
                  shrinkWrap: true, // Important within Flexible/Column
                  itemCount: sources.length,
                  separatorBuilder:
                      (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final source = sources[index];
                    return ListTile(
                      title: Text(source.name),
                      onTap: () async {
                        Navigator.pop(ctx); // Close bottom sheet first
                        final urlString = source.getUrlForTvShow(
                          tvShowName: show.name,
                          tmdbId: show.tmdb_id,
                          mediaType: show.media_type,
                        );
                        if (urlString.isNotEmpty) {
                          final url = Uri.parse(urlString);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            print("Could not launch $url");
                            if (!ctx.mounted) return; // Use ctx from builder
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              // Use ctx
                              SnackBar(content: Text('无法打开链接: $urlString')),
                            );
                          }
                        } else {
                          print(
                            "Could not generate valid URL for ${source.name}",
                          );
                          if (!ctx.mounted) return; // Use ctx from builder
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            // Use ctx
                            SnackBar(
                              content: Text('无法为 ${source.name} 生成有效链接'),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              );
            }

            // --- Common structure for the bottom sheet ---
            final double maxHeight = MediaQuery.of(ctx).size.height * 0.6;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Take only needed height
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '选择播放源: ${show.name}',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const Divider(height: 20),
                    content, // Display the content (loading/error/list)
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Helper method to show thoughts dialog with Edit/Delete ---
  void _showThoughtsDialog(BuildContext context, TvShow show) {
    _thoughtController.clear();
    int? editingIndex; // 跟踪正在编辑的想法索引

    // 使用StatefulBuilder管理对话框内的编辑状态
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // 仍然需要Consumer来从provider获取更新的电视剧数据
            return Consumer<TvShowNotifier>(
              builder: (context, notifier, child) {
                final currentShow =
                    notifier.findTvShowByName(show.name) ?? show;
                final thoughts = currentShow.thoughts;

                return AlertDialog(
                  title: Text('${currentShow.name} - 想法'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (thoughts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Text('还没有想法，快添加一个吧！'),
                          )
                        else
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: thoughts.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  title: Text(thoughts[index]),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 编辑按钮
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 20,
                                        ),
                                        tooltip: '编辑想法',
                                        onPressed: () {
                                          setDialogState(() {
                                            editingIndex = index;
                                            _thoughtController.text =
                                                thoughts[index];
                                          });
                                        },
                                      ),
                                      // 删除按钮
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                          color: Colors.redAccent,
                                        ),
                                        tooltip: '删除想法',
                                        onPressed:
                                            () => _confirmDeleteThought(
                                              ctx,
                                              notifier,
                                              currentShow,
                                              index,
                                            ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        const Divider(),
                        TextField(
                          controller: _thoughtController,
                          decoration: InputDecoration(
                            labelText:
                                editingIndex == null ? '添加新想法...' : '编辑想法...',
                            border: const OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('关闭'),
                    ),
                    // 仅在编辑时显示"取消编辑"按钮
                    if (editingIndex != null)
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            editingIndex = null;
                            _thoughtController.clear();
                          });
                        },
                        child: const Text('取消编辑'),
                      ),
                    ElevatedButton(
                      onPressed: () async {
                        final thoughtText = _thoughtController.text.trim();
                        if (thoughtText.isNotEmpty) {
                          try {
                            if (editingIndex != null) {
                              // 编辑现有想法
                              await notifier.editThought(
                                currentShow,
                                editingIndex!,
                                thoughtText,
                              );
                              setDialogState(() {
                                editingIndex = null;
                                _thoughtController.clear();
                              });
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('想法已更新')),
                              );
                            } else {
                              // 添加新想法
                              await notifier.addThought(
                                currentShow,
                                thoughtText,
                              );
                              _thoughtController.clear();
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('想法已添加')),
                              );
                            }
                          } catch (e) {
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(
                              ctx,
                            ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
                          }
                        }
                      },
                      // 根据编辑状态更改按钮文本
                      child: Text(editingIndex == null ? '添加' : '保存编辑'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // --- 确认删除想法的辅助方法 ---
  void _confirmDeleteThought(
    BuildContext dialogContext,
    TvShowNotifier notifier,
    TvShow show,
    int index,
  ) {
    showDialog(
      context: dialogContext,
      builder: (BuildContext confirmCtx) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除这条想法吗？\n"${show.thoughts[index]}"'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(confirmCtx),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(confirmCtx); // 先关闭确认对话框
                try {
                  await notifier.removeThought(show, index);
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(const SnackBar(content: Text('想法已删除')));
                } catch (e) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
                }
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  // --- Widget for Music Controls ---
  // --- Widget for Music Controls (Uses AudioService) ---
  Widget _buildMusicControls() {
    // Use Consumer to listen to AudioService changes
    return Consumer<AudioService>(
      builder: (context, audioService, child) {
        // Get state from the service
        final duration = audioService.duration;
        final position = audioService.position;
        final isPlaying = audioService.isPlaying;
        final currentAudioShow = audioService.currentShow; // Show whose audio is playing

        // Determine if controls should be visible (audio loaded for *any* show)
        final bool showControls = duration > Duration.zero && currentAudioShow != null;

        // Get the currently *displayed* show from the outer Selector/widget
        // We need this to know if the controls belong to *this* screen's show
        final displayedShowName = widget.tvShow.name; // Or get from Selector if needed
        final bool controlsAreForThisShow = currentAudioShow?.name == displayedShowName;


        // Only show controls if audio is loaded AND it's for the show currently displayed on this detail screen
        if (!showControls || !controlsAreForThisShow) {
          return const SizedBox.shrink(); // Hide controls if not relevant
        }

        // --- Build Controls UI ---
        final maxSeconds = duration.inSeconds.toDouble();
        final currentSeconds = position.inSeconds.toDouble().clamp(
              0.0,
              maxSeconds > 0 ? maxSeconds : 0.0,
            );

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                    ),
                    iconSize: 48.0,
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: () async {
                      if (isPlaying) {
                        await audioService.pause();
                      } else {
                        await audioService.resume();
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.stop_circle_outlined),
                    iconSize: 48.0,
                    color: Theme.of(context).colorScheme.secondary,
                    onPressed: () async {
                      await audioService.stop();
                    },
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  inactiveTrackColor: Colors.grey[400],
                  thumbColor: Theme.of(context).colorScheme.primary,
                ),
                child: Slider(
                  min: 0,
                  max: maxSeconds > 0 ? maxSeconds : 1.0,
                  value: currentSeconds,
                  onChanged: (value) async {
                    if (maxSeconds > 0) {
                      final seekPosition = Duration(seconds: value.toInt());
                      // Update UI immediately via service state change
                      // setState(() => _position = position); // No longer needed
                      await audioService.seek(seekPosition);
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(Duration(seconds: currentSeconds.toInt())),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      _formatDuration(duration),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper to format duration (can be kept here or moved to a utils file)
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  // --- Helper method to build Jump Buttons ---
  Widget _buildJumpButtons(BuildContext context) {
    // No change needed, doesn't depend on TvShow data
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('跳转到相册'),
          onPressed: () {
            final targetContext = _albumSectionKey.currentContext;
            if (targetContext != null) {
              Scrollable.ensureVisible(
                targetContext,
                duration: const Duration(
                  milliseconds: 500,
                ), // Animation duration
                curve: Curves.easeInOut, // Animation curve
              );
            }
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.format_quote_outlined),
          label: const Text('跳转到台词'),
          onPressed: () {
            final targetContext = _linesSectionKey.currentContext;
            if (targetContext != null) {
              Scrollable.ensureVisible(
                targetContext,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            }
          },
        ),
      ],
    );
  }
  // 显示台词详情对话框
  void _showLineDetailDialog(BuildContext context, TvShow show, int index) {
    final TextEditingController lineController = TextEditingController();
    lineController.text = show.lines[index];

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('台词详情'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 显示完整台词
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    show.lines[index],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 编辑台词的文本框
                TextField(
                  controller: lineController,
                  decoration: const InputDecoration(
                    labelText: '编辑台词',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                ),
              ],
            ),
          ),
          actions: [
            // 取消按钮
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            // 删除按钮
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => _confirmDeleteLine(ctx, show, index),
              child: const Text('删除'),
            ),
            // 保存按钮
            ElevatedButton(
              onPressed: () {
                final newText = lineController.text.trim();
                if (newText.isNotEmpty) {
                  _updateLine(ctx, show, index, newText);
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  // 确认删除台词
  void _confirmDeleteLine(BuildContext dialogContext, TvShow show, int index) {
    showDialog(
      context: dialogContext,
      builder: (BuildContext confirmCtx) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除这条台词吗？\n"${show.lines[index]}"'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(confirmCtx),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(confirmCtx); // 先关闭确认对话框
                Navigator.pop(dialogContext); // 再关闭详情对话框
                
                try {
                  // 获取TvShowNotifier
                  final notifier = Provider.of<TvShowNotifier>(context, listen: false);
                  // 创建新的台词列表（删除指定索引的台词）
                  final List<String> updatedLines = List.from(show.lines);
                  updatedLines.removeAt(index);
                  
                  // 更新电视剧数据
                  await notifier.updateLines(show, updatedLines);
                  
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('台词已删除')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败: $e')),
                  );
                }
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  // 更新台词
  void _updateLine(BuildContext dialogContext, TvShow show, int index, String newText) async {
    Navigator.pop(dialogContext); // 关闭对话框
    
    try {
      // 获取TvShowNotifier
      final notifier = Provider.of<TvShowNotifier>(context, listen: false);
      // 创建新的台词列表（更新指定索引的台词）
      final List<String> updatedLines = List.from(show.lines);
      updatedLines[index] = newText;
      
      // 更新电视剧数据
      await notifier.updateLines(show, updatedLines);
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('台词已更新')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失败: $e')),
      );
    }
  }
} // End of _TvShowDetailScreenState class
