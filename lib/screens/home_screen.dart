import 'dart:io'; // Import dart:io for File class
import 'dart:math'; // For random selection
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:provider/provider.dart';
import '../providers/tv_show_notifier.dart';
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
            onTap: () { /* TODO: Show Play Sources */ print('播放 tapped'); },
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
          ),
          const SizedBox(height: 10),
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
}