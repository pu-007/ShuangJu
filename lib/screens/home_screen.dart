import 'dart:io'; // Import dart:io for File class
import 'dart:math'; // For random selection
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher
import '../providers/play_source_notifier.dart'; // Import PlaySourceNotifier
import '../providers/tv_show_notifier.dart';
// Import PlaySource model
import '../models/tv_show.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TvShow? _currentShow;
  String? _currentQuote;
  bool _isExpanded = false; // State for the expansion panel

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure Provider is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectRandomShowAndQuote();
    });
  }

  void _selectRandomShowAndQuote() {
    final notifier = Provider.of<TvShowNotifier>(context, listen: false);
    if (notifier.tvShows.isNotEmpty) {
      final random = Random();
      final randomIndex = random.nextInt(notifier.tvShows.length);
      final selectedShow = notifier.tvShows[randomIndex];

      String? selectedQuote;
      if (selectedShow.lines.isNotEmpty) {
        final quoteIndex = random.nextInt(selectedShow.lines.length);
        selectedQuote = selectedShow.lines[quoteIndex];
      }

      print("[HomeScreen] Selecting random show. Notifier has ${notifier.tvShows.length} shows."); // Added Log
      setState(() {
        _currentShow = selectedShow;
        _currentQuote = selectedQuote;
         print("[HomeScreen] Selected show: ${selectedShow.name}, Quote: $selectedQuote"); // Added Log
      });
    } else {
       print("[HomeScreen] Cannot select random show. Notifier has ${notifier.tvShows.length} shows."); // Added Log
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch for changes in the notifier (e.g., after loading)
    // Using Consumer or Selector might be more efficient later
    final notifier = Provider.of<TvShowNotifier>(context);

    // Handle loading and error states
    if (notifier.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (notifier.error != null) {
      return Center(child: Text("加载主页数据出错: ${notifier.error}"));
    }
    if (_currentShow == null && notifier.tvShows.isNotEmpty) {
      // If shows loaded but _currentShow is still null, try selecting again
      // This can happen if initState runs before provider is fully ready initially
       WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted) { // Check if widget is still in the tree
            _selectRandomShowAndQuote();
         }
       });
       return const Center(child: CircularProgressIndicator()); // Show loading briefly
    }
     if (_currentShow == null && notifier.tvShows.isEmpty) {
       return const Center(child: Text("没有可显示的电视剧数据"));
     }


    // --- Main UI ---
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy / MM / dd'); // Customize date format
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      // Using a Stack to layer background, content, and menu
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Image (Cover of the current show)
          if (_currentShow != null)
            Image.file(
              // Assuming DataService provides the correct path including writable dir prefix
              // We need to get the actual file path from DataService or TvShow model
              // For now, using the path stored in the model (needs verification)
              File(_currentShow!.coverImagePath),
              fit: BoxFit.cover,
              // Add error builder for image loading issues
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[800],
                child: const Center(child: Icon(Icons.error_outline, color: Colors.white54)),
              ),
            ),
          // Add a semi-transparent overlay for better text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.6), Colors.black.withOpacity(0.2)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),

          // 2. Main Content (Date, Quote) - Positioned at the bottom
          Positioned(
            bottom: 80, // Adjust position to leave space for potential bottom controls/nav
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateFormat.format(DateTime.now()),
                  style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                 Text(
                  timeFormat.format(DateTime.now()),
                  style: theme.textTheme.titleLarge?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 15),
                if (_currentQuote != null)
                  Text(
                    '"$_currentQuote"',
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontStyle: FontStyle.italic),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (_currentShow != null)
                  Text(
                    "— 《${_currentShow!.name}》",
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    textAlign: TextAlign.right,
                  ),
              ],
            ),
          ),

          // 3. Top Action Buttons / Foldable Menu Trigger
          Positioned(
            top: MediaQuery.of(context).padding.top + 10, // Respect status bar
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 // Button to trigger random show change
                 IconButton(
                   icon: const Icon(Icons.shuffle, color: Colors.white),
                   tooltip: '切换背景',
                   onPressed: _selectRandomShowAndQuote,
                 ),
                 // Button to toggle the expansion panel
                 IconButton(
                   icon: Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.menu, color: Colors.white),
                   tooltip: '展开菜单',
                   onPressed: () {
                     setState(() {
                       _isExpanded = !_isExpanded;
                     });
                   },
                 ),
              ],
            ),
          ),

          // 4. Expansion Panel Menu (Animated Positioned)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: _isExpanded ? MediaQuery.of(context).padding.top + 60 : -(MediaQuery.of(context).size.height), // Animate off-screen
            left: 10,
            right: 10,
            child: Material( // Use Material for elevation and background
              elevation: 4.0,
              borderRadius: BorderRadius.circular(8.0),
              child: Container(
                 padding: const EdgeInsets.all(10.0),
                 decoration: BoxDecoration(
                    color: theme.canvasColor.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(8.0),
                 ),
                 child: _buildExpansionMenuItems(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpansionMenuItems() {
    if (_currentShow == null) return const SizedBox.shrink();

    // TODO: Implement actual functionality for buttons
    return SingleChildScrollView( // Allow scrolling if content overflows
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch, // Make buttons wider
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('相册'),
            onTap: () { /* TODO: Navigate to Album/Gallery */ print('相册 tapped'); },
          ),
          ListTile(
            leading: const Icon(Icons.music_note_outlined),
            title: const Text('音乐'),
            onTap: () { /* TODO: Play Music */ print('音乐 tapped'); },
          ),
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: const Text('播放'),
            onTap: () => _showPlaySourcesDialog(context, _currentShow!), // Call dialog function
          ),
          const Divider(),
          // --- Progress ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('观看记录 (${_currentShow!.progress.current} / ${_currentShow!.progress.total})'),
          ),
          // TODO: Add progress editing UI (Slider, TextField?)
          LinearProgressIndicator(
             value: _currentShow!.progress.percentage,
             backgroundColor: Colors.grey[300],
             minHeight: 6, // Make it slightly thicker
          ),
          // Add +/- buttons for progress
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: '减少进度',
                onPressed: (_currentShow!.progress.current <= 0) ? null : () { // Disable if already 0
                   final current = _currentShow!.progress.current - 1;
                   Provider.of<TvShowNotifier>(context, listen: false).updateProgress(
                      _currentShow!,
                      current,
                      _currentShow!.progress.total,
                   );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                // Allow tapping text to manually input progress? (More complex)
                child: Text(
                  '${_currentShow!.progress.current} / ${_currentShow!.progress.total}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: '增加进度',
                 onPressed: (_currentShow!.progress.current >= _currentShow!.progress.total) ? null : () { // Disable if already max
                   final current = _currentShow!.progress.current + 1;
                   Provider.of<TvShowNotifier>(context, listen: false).updateProgress(
                      _currentShow!,
                      current,
                      _currentShow!.progress.total,
                   );
                 },
              ),
            ],
          ),
          // const SizedBox(height: 10), // Removed extra space before divider
          const Divider(), // Add divider before thoughts
          // --- Thoughts ---
           Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('我的想法 (${_currentShow!.thoughts.length})'),
          ),
          // TODO: Display thoughts list and add button
          if (_currentShow!.thoughts.isEmpty)
             const Padding(
               padding: EdgeInsets.symmetric(horizontal: 16.0),
               child: Text('暂无想法', style: TextStyle(color: Colors.grey)),
             )
          else
             // Limited display here, full view maybe elsewhere
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16.0),
               child: Text(_currentShow!.thoughts.join('\n'), maxLines: 2, overflow: TextOverflow.ellipsis),
             ),
          TextButton.icon(
             icon: const Icon(Icons.add_comment_outlined),
             label: const Text('添加/查看想法'),
             onPressed: () { /* TODO: Show thoughts dialog/screen */ print('想法 tapped'); },
          ),
        ],
      ),
    );
  }

  // --- Helper method to show play sources ---
  void _showPlaySourcesDialog(BuildContext context, TvShow show) {
    final playSourceNotifier = Provider.of<PlaySourceNotifier>(context, listen: false);
    final sources = playSourceNotifier.sources;

    if (sources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可用的播放源')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      // Make it scrollable if many sources
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        // Calculate max height for the sheet
        final double maxHeight = MediaQuery.of(ctx).size.height * 0.6; // 60% of screen height

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
                 Flexible( // Make the ListView flexible within Column
                   child: ListView.separated(
                     shrinkWrap: true, // Important for Column/BottomSheet
                     itemCount: sources.length,
                     separatorBuilder: (context, index) => const Divider(height: 1),
                     itemBuilder: (context, index) {
                       final source = sources[index];
                       return ListTile(
                         title: Text(source.name),
                         // Optional: Add subtitle with URL template?
                         // subtitle: Text(source.urlTemplate, style: TextStyle(color: Colors.grey, fontSize: 12)),
                         onTap: () async {
                           final urlString = source.getUrlForTvShow(
                             tvShowName: show.name,
                             tmdbId: show.tmdb_id,
                             mediaType: show.media_type,
                           );
                           if (urlString.isNotEmpty) {
                             final url = Uri.parse(urlString);
                             if (await canLaunchUrl(url)) {
                               await launchUrl(url, mode: LaunchMode.externalApplication);
                               // ignore: use_build_context_synchronously
                               Navigator.pop(ctx); // Close bottom sheet on success
                             } else {
                               print("Could not launch $url");
                               // ignore: use_build_context_synchronously
                               ScaffoldMessenger.of(ctx).showSnackBar(
                                 SnackBar(content: Text('无法打开链接: $urlString')),
                               );
                             }
                           } else {
                              print("Could not generate valid URL for ${source.name}");
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                 SnackBar(content: Text('无法为 ${source.name} 生成有效链接')),
                               );
                           }
                         },
                       );
                     },
                   ),
                 ),
               ],
             ),
           ),
        );
      },
    );
  }
}