// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:async';
// Keep for PlayerState enum if needed, or remove if controls are moved
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/play_source_notifier.dart';
import '../providers/tv_show_notifier.dart';
import '../services/audio_service.dart'; // Import AudioService
import 'gallery_screen.dart';
import 'tv_show_detail_screen.dart'; // 导入详情页
import '../models/tv_show.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Local state for UI elements only
  bool _isExpanded = false;
  final TextEditingController _thoughtController = TextEditingController();
  Timer? _updateTimer;
  Duration _updateInterval = const Duration(hours: 1); // Default interval
  static const String _updateIntervalKey = 'home_update_interval_seconds';
  static const String _lastRefreshTimestampKey = 'home_last_refresh_timestamp_ms'; // Key for last refresh time
  static const String _lastSelectedShowNameKey = 'home_last_selected_show_name'; // Key for last show name
  // late AudioPlayer _audioPlayer; // Removed local audio player
  // Listener specifically for checking if initial load is done
  VoidCallback? _initialLoadListener;
  // Listener for settings changes
  VoidCallback? _settingsChangeListener;
  bool _wasLoading = true; // Track previous loading state for listener
  String? _loadedShowNameFromPrefs; // Temporarily store loaded show name

  // Audio Player State is now managed by AudioService

  @override
  void initState() {
    super.initState();
    print("[HomeScreen initState] Initializing...");
    // _audioPlayer = AudioPlayer(); // Removed initialization
    WidgetsBinding.instance.addObserver(this); // Register lifecycle observer

    // --- Setup Listener for Initial Load Completion ---
    // We listen specifically for the loading state to change to false
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final notifier = Provider.of<TvShowNotifier>(context, listen: false);
        _wasLoading = notifier.isLoading; // Initialize previous loading state
        // Only add listener if currently loading, otherwise try selecting immediately
        if (_wasLoading) {
          _initialLoadListener = _handleNotifierChangeForInitialLoad;
          notifier.addListener(_initialLoadListener!);
          print(
            "[HomeScreen initState] Notifier is loading. Added initial load listener.",
          );
        } else {
          print(
            "[HomeScreen initState] Notifier already loaded. Trying initial selection.",
          );
          // If already loaded, try restoring the saved show immediately
          _tryRestoreOrSelectInitialShow();
        }
      }
    });

    // --- Listener for Settings Changes ---
    // Listen to the ValueNotifier in TvShowNotifier
    _settingsChangeListener = () {
      print("[HomeScreen] Settings change detected via notifier. Reloading interval.");
      // Use addPostFrameCallback to avoid calling setState during build/layout phase if listener fires during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted) {
            _loadIntervalAndStartTimer(forceRestartTimer: true); // Force restart on settings change
         }
      });
    };
    Provider.of<TvShowNotifier>(context, listen: false)
        .settingsChangeNotifier
        .addListener(_settingsChangeListener!);


    // Load interval, check for missed updates, and start timer immediately
    _loadIntervalAndStartTimer(isInitialSetup: true); // Indicate initial setup

    // Audio player listeners are now handled within AudioService
  }

  // Listener specifically for initial load completion
  void _handleNotifierChangeForInitialLoad() {
    if (!mounted) return;
    final notifier = Provider.of<TvShowNotifier>(context, listen: false);
    print(
      "[HomeScreen _handleNotifierChangeForInitialLoad] Notifier changed state. isLoading: ${notifier.isLoading}, wasLoading: $_wasLoading",
    );

    // Check specifically if loading just finished
    if (_wasLoading && !notifier.isLoading) {
      print(
        "[HomeScreen _handleNotifierChangeForInitialLoad] Loading finished.",
      );
      // Loading finished, now try restoring or selecting the initial show
      _tryRestoreOrSelectInitialShow();

      // Remove the listener after it served its purpose
      if (_initialLoadListener != null) {
        notifier.removeListener(_initialLoadListener!);
        _initialLoadListener = null;
        print(
          "[HomeScreen _handleNotifierChangeForInitialLoad] Listener removed.",
        );
      }
    }
    // Update wasLoading for the next change detection (though listener should be removed)
    _wasLoading = notifier.isLoading;
  }

  @override
  void dispose() {
    print("[HomeScreen dispose] Disposing HomeScreen state...");
    WidgetsBinding.instance.removeObserver(this);
    // Remove the listener using the stored callback if it's still attached
    if (_initialLoadListener != null) {
      try {
        Provider.of<TvShowNotifier>(
          context,
          listen: false,
        ).removeListener(_initialLoadListener!);
        print(
          "[HomeScreen dispose] Removed initial load listener during dispose.",
        );
      } catch (e) {
        print("[HomeScreen dispose] Error removing initial load listener: $e");
      }
    }
    // Remove settings change listener
    if (_settingsChangeListener != null) {
      try {
        // Check if TvShowNotifier is still available before removing listener
        // This can prevent errors if the notifier itself is disposed before this widget
        if (context.mounted) { // Check context validity
           final notifier = Provider.of<TvShowNotifier>(context, listen: false);
           notifier.settingsChangeNotifier.removeListener(_settingsChangeListener!);
           print("[HomeScreen dispose] Removed settings change listener.");
        } else {
           print("[HomeScreen dispose] Context not mounted, cannot remove settings listener.");
        }
      } catch (e) {
        // Catch potential errors if Provider.of fails during dispose
        print("[HomeScreen dispose] Error removing settings change listener: $e");
      }
    }
    _updateTimer?.cancel();
    // Audio player subscriptions and disposal are handled by AudioService
    // _audioPlayer.stop(); // No longer needed
    // _audioPlayer.dispose(); // No longer needed
    _thoughtController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      print(
        "[HomeScreen] App resumed. Reloading interval and potentially restarting timer.",
      );
      _loadIntervalAndStartTimer(); // Reload interval and restart timer if needed
      setState(() {}); // Trigger rebuild to update time display
    } else if (state == AppLifecycleState.paused) {
      print("[HomeScreen] App paused. Stopping timer.");
      _updateTimer?.cancel();
    }
  }

  // Helper to attempt restoring the last show or selecting a new initial one
  // This is typically called once after the notifier finishes loading its data.
  Future<void> _tryRestoreOrSelectInitialShow() async {
    if (!mounted) return;
    final notifier = Provider.of<TvShowNotifier>(context, listen: false);

    // Ensure notifier is loaded and has shows before proceeding
    if (notifier.isLoading || notifier.tvShows.isEmpty) {
      print("[HomeScreen _tryRestoreOrSelectInitialShow] Not ready (Loading: ${notifier.isLoading}, HasShows: ${notifier.tvShows.isNotEmpty}). Aborting.");
      return;
    }

    // Only proceed if an initial show hasn't been selected/restored yet
    if (notifier.initialHomeScreenShowSelected) {
       print("[HomeScreen _tryRestoreOrSelectInitialShow] Initial show already selected/restored. Aborting.");
       return;
    }

    // Use the temporarily stored show name loaded during initState's _loadIntervalAndStartTimer
    String? savedShowName = _loadedShowNameFromPrefs;
    print("[HomeScreen _tryRestoreOrSelectInitialShow] Using loaded saved show name: $savedShowName");


    bool showRestored = false;
    if (savedShowName != null) {
      // Try setting the show by name
      notifier.setCurrentHomeScreenShowByName(savedShowName);
      // Check if the notifier actually set the show (it might fail if the show was deleted)
      if (notifier.currentHomeScreenShow?.name == savedShowName) {
         print("[HomeScreen _tryRestoreOrSelectInitialShow] Successfully restored show: $savedShowName");
         showRestored = true;
         // Save the restored show name again (in case quote changed during restore)
         await _saveLastSelectedShowName(savedShowName);
      } else {
         print("[HomeScreen _tryRestoreOrSelectInitialShow] Failed to restore show '$savedShowName' (might be deleted).");
         // Clear the invalid saved name
         await _saveLastSelectedShowName(null);
      }
    }

    // If no show was restored (no saved name, or restore failed), select a random one
    if (!showRestored) {
      print("[HomeScreen _tryRestoreOrSelectInitialShow] No show restored. Selecting random initial show.");
      // Use addPostFrameCallback because this might be called during build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted) {
            // Perform the initial random selection sequence
            _performRefreshSequence(isInitialSelection: true);
         }
      });
    }
     // Clear the temporary variable after use
    _loadedShowNameFromPrefs = null;
  }

  // Loads interval, checks for missed updates, and starts/restarts the timer.
  // Central function to load settings, check for missed updates, potentially restore show, and manage the timer.
  Future<void> _loadIntervalAndStartTimer({bool isInitialSetup = false, bool forceRestartTimer = false}) async {
      if (!mounted) return;
      print("[HomeScreen _loadIntervalAndStartTimer] Start. Initial: $isInitialSetup, ForceRestart: $forceRestartTimer");

      Duration loadedInterval = _updateInterval;
      int? lastRefreshTimestampMillis;
      String? savedShowName; // Only load during initial setup
      SharedPreferences? prefs;

      try {
          prefs = await SharedPreferences.getInstance();
          final savedSeconds = prefs.getInt(_updateIntervalKey) ?? 3600;
          loadedInterval = Duration(seconds: savedSeconds < 10 ? 10 : savedSeconds);
          lastRefreshTimestampMillis = prefs.getInt(_lastRefreshTimestampKey);
          // Load saved show name only during initial setup
          if (isInitialSetup) {
             savedShowName = prefs.getString(_lastSelectedShowNameKey);
             _loadedShowNameFromPrefs = savedShowName; // Store temporarily for initial load listener
             print("[HomeScreen _loadIntervalAndStartTimer] Loaded initial savedShowName: $savedShowName");
          }
          print("[HomeScreen _loadIntervalAndStartTimer] Loaded Interval: $loadedInterval, Last Refresh: ${lastRefreshTimestampMillis != null ? DateTime.fromMillisecondsSinceEpoch(lastRefreshTimestampMillis) : 'Never'}");
      } catch (e) {
          print("[HomeScreen _loadIntervalAndStartTimer] Error loading SharedPreferences: $e");
          loadedInterval = _updateInterval; // Use current state if loading fails
      }

      if (!mounted) return;

      bool intervalChanged = loadedInterval != _updateInterval;
      if (intervalChanged || forceRestartTimer) { // Also update state if forcing restart (ensures _updateInterval is current)
          print("[HomeScreen _loadIntervalAndStartTimer] Interval changed or forced. New: $loadedInterval. Updating state.");
          // Update state safely after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted) {
                setState(() {
                   _updateInterval = loadedInterval;
                });
             }
          });
      }

      // --- Refresh Check ---
      bool refreshNeeded = false;
      if (lastRefreshTimestampMillis != null && loadedInterval > Duration.zero) {
          final now = DateTime.now();
          final lastRefreshTime = DateTime.fromMillisecondsSinceEpoch(lastRefreshTimestampMillis);
          final elapsed = now.difference(lastRefreshTime);
          if (elapsed >= loadedInterval) {
              print("[HomeScreen _loadIntervalAndStartTimer] Refresh needed. Elapsed: $elapsed >= Interval: $loadedInterval");
              refreshNeeded = true;
          } else {
              print("[HomeScreen _loadIntervalAndStartTimer] No refresh needed. Elapsed: $elapsed < Interval: $loadedInterval");
          }
      } else if (lastRefreshTimestampMillis == null && isInitialSetup) {
          // First run ever, needs an initial selection/refresh
          print("[HomeScreen _loadIntervalAndStartTimer] First run, refresh needed.");
          refreshNeeded = true;
      }

      // --- Perform Actions ---
      // Crucially, perform refresh check *before* deciding whether to restore saved show on initial setup
      if (refreshNeeded) {
          print("[HomeScreen _loadIntervalAndStartTimer] Performing refresh sequence synchronously due to need.");
          // Call directly and await, ensuring refresh happens before timer logic proceeds.
          // Pass isInitialSelection only if it's the very first run.
          await _performRefreshSequence(prefsInstance: prefs, isInitialSelection: isInitialSetup && lastRefreshTimestampMillis == null);
      } else if (isInitialSetup) {
          // No refresh needed, but it's initial setup. Try restoring the show loaded earlier.
          // This logic is now primarily handled by _tryRestoreOrSelectInitialShow triggered by the load listener.
          // We ensure _tryRestoreOrSelectInitialShow uses the _loadedShowNameFromPrefs loaded here.
          print("[HomeScreen _loadIntervalAndStartTimer] Initial setup, no refresh needed. Restore/Select handled by listener.");
          // If the notifier was *already* loaded before initState ran, the listener won't fire.
          // Trigger the check manually in that case.
          final notifier = Provider.of<TvShowNotifier>(context, listen: false);
          if (!notifier.isLoading && !notifier.initialHomeScreenShowSelected) {
             print("[HomeScreen _loadIntervalAndStartTimer] Notifier already loaded, manually triggering restore/select check.");
             WidgetsBinding.instance.addPostFrameCallback((_) {
                 _tryRestoreOrSelectInitialShow();
             });
          }
      }


      // --- Timer Management ---
      // Restart if forced, interval changed, initial setup, or timer inactive
      bool needsTimerRestart = forceRestartTimer || isInitialSetup || intervalChanged || _updateTimer == null || !_updateTimer!.isActive;
      if (needsTimerRestart) {
          print("[HomeScreen _loadIntervalAndStartTimer] Needs timer restart (Forced: $forceRestartTimer, Initial: $isInitialSetup, IntervalChanged: $intervalChanged, Timer Active: ${_updateTimer?.isActive}). Starting timer.");
          _startUpdateTimer(loadedInterval); // Pass the correct interval
      } else {
          print("[HomeScreen _loadIntervalAndStartTimer] Timer active and conditions met. Not restarting.");
      }
  }

  void _startUpdateTimer(Duration interval) { // Accept interval as parameter
    _updateTimer?.cancel(); // Cancel previous timer before starting new one
    // Use the passed interval parameter
    if (interval > Duration.zero) {
      print(
        "[HomeScreen] Starting/Restarting update timer with interval: $interval",
      );
      _updateTimer = Timer.periodic(interval, (timer) { // Use passed interval
        print("[HomeScreen] Timer fired! Selecting new random show.");
        if (mounted) {
          // Trigger refresh logic and save timestamp
          _performRefreshSequence(); // Timer just triggers the sequence
        } else {
          timer.cancel();
          print("[HomeScreen] Timer cancelled because widget is disposed.");
        }
      });
    } else {
      print(
        "[HomeScreen] Update interval ($interval) is zero or negative. Timer not started.",
      );
    }
  }

  // Saves the current timestamp as the last refresh time.
  Future<void> _saveLastRefreshTimestamp([SharedPreferences? prefsInstance]) async {
    try {
      final prefs = prefsInstance ?? await SharedPreferences.getInstance();
      final nowMillis = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_lastRefreshTimestampKey, nowMillis);
      print("[HomeScreen] Last refresh timestamp saved: ${DateTime.fromMillisecondsSinceEpoch(nowMillis)}");
    } catch (e) {
      print("[HomeScreen] Error saving last refresh timestamp: $e");
    }
  }

  // Saves the name of the currently displayed show.
  Future<void> _saveLastSelectedShowName(String? showName, [SharedPreferences? prefsInstance]) async {
    // Don't save null if we intend to clear it
    // if (showName == null) return;
    try {
      final prefs = prefsInstance ?? await SharedPreferences.getInstance();
      if (showName != null) {
         await prefs.setString(_lastSelectedShowNameKey, showName);
         print("[HomeScreen] Saved last selected show name: $showName");
      } else {
         // Explicitly remove the key if showName is null
         await prefs.remove(_lastSelectedShowNameKey);
         print("[HomeScreen] Cleared last selected show name.");
      }
    } catch (e) {
      print("[HomeScreen] Error saving/clearing last selected show name: $e");
    }
  }


  // Performs the complete refresh sequence: select new show, save timestamp, save show name.
  Future<void> _performRefreshSequence({SharedPreferences? prefsInstance, bool isInitialSelection = false}) async {
    if (!mounted) return;
    print("[HomeScreen _performRefreshSequence] Start. InitialSelection: $isInitialSelection");
    final notifier = Provider.of<TvShowNotifier>(context, listen: false);

    // Ensure shows are loaded before selecting
    if (notifier.tvShows.isEmpty) {
       print("[HomeScreen _performRefreshSequence] No shows loaded. Cannot perform refresh.");
       return;
    }

    // Select a new random show
    notifier.selectRandomHomeScreenShow();

    // Get the newly selected show name (might be null if list is empty, though checked above)
    final newShowName = notifier.currentHomeScreenShow?.name;

    // Stop audio using the service
    final audioService = Provider.of<AudioService>(context, listen: false);
    await audioService.stop(); // Stop playback via service

    // UI state updates will happen automatically via Consumer/Selector listening to AudioService


    // Save timestamp and show name
    // Use a single prefs instance if provided
    final prefs = prefsInstance ?? await SharedPreferences.getInstance();
    await _saveLastRefreshTimestamp(prefs);
    await _saveLastSelectedShowName(newShowName, prefs);

    print("[HomeScreen _performRefreshSequence] Finished. New show: $newShowName");
  }


  // Manual Refresh Function - Triggers refresh, saves timestamp, and restarts timer interval.
  Future<void> _manualRefreshShow() async {
    print("[HomeScreen] Manual refresh triggered.");
    await _performRefreshSequence(); // Perform the full refresh sequence
    _startUpdateTimer(_updateInterval); // Restart with the current state interval
  }

  @override
  Widget build(BuildContext context) {
    // Use Selector to rebuild only when currentHomeScreenShow changes
    return Selector<TvShowNotifier, TvShow?>(
      selector: (_, notifier) => notifier.currentHomeScreenShow,
      shouldRebuild: (previous, next) => previous?.name != next?.name,
      builder: (context, currentShow, _) {
        print(
          "[HomeScreen build] Building UI. Current show from Selector: ${currentShow?.name}",
        );

        // Get potentially updated quote (listen: false as Selector handles rebuild)
        final currentQuote =
            Provider.of<TvShowNotifier>(
              context,
              listen: false,
            ).currentHomeScreenQuote;
        // Get loading/error state (listen: false)
        final isLoading =
            Provider.of<TvShowNotifier>(context, listen: false).isLoading;
        final error = Provider.of<TvShowNotifier>(context, listen: false).error;
        final hasShows =
            Provider.of<TvShowNotifier>(
              context,
              listen: false,
            ).tvShows.isNotEmpty;
        final initialSelected =
            Provider.of<TvShowNotifier>(
              context,
              listen: false,
            ).initialHomeScreenShowSelected;

        // --- Refined Loading/Error/No Data Handling ---
        Widget bodyContent;
        if (currentShow == null) {
          // If no show is selected yet, check notifier status
          if (isLoading && !initialSelected) {
            // Show loading only during initial load phase
            print("[HomeScreen build] State: Initial Loading");
            bodyContent = const Center(child: CircularProgressIndicator());
          } else if (error != null) {
            print("[HomeScreen build] State: Error Loading");
            bodyContent = Center(child: Text("加载主页数据出错: $error"));
          } else if (!hasShows && !isLoading) {
            // Not loading, no error, but tvShows list is empty
            print(
              "[HomeScreen build] State: No Show Data Available (Empty List)",
            );
            bodyContent = const Center(child: Text("没有可显示的电视剧数据"));
          } else {
            // Not loading, no error, has shows, but currentShow is null.
            // This means initial selection is pending. Show loading.
            print("[HomeScreen build] State: Waiting for initial selection");
            bodyContent = const Center(child: CircularProgressIndicator());
          }
        } else {
          // --- Main UI (Show is available) ---
          print(
            "[HomeScreen build] State: Displaying Show - ${currentShow.name}",
          );
          final theme = Theme.of(context);
          final dateFormat = DateFormat('yyyy / MM / dd');
          final timeFormat = DateFormat('HH:mm:ss');

          bodyContent = Stack(
            fit: StackFit.expand,
            children: [
              // 1. Background Image
              Image.file(
                File(currentShow.coverImagePath),
                key: ValueKey(
                  currentShow.name,
                ), // Key to force rebuild on change
                fit: BoxFit.cover,
                errorBuilder:
                    (context, error, stackTrace) => Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: Icon(Icons.error_outline, color: Colors.white54),
                      ),
                    ),
              ),
              // Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.black.withValues(alpha: 0.2),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
              // 2. Main Content
              Positioned(
                bottom: 80,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateFormat.format(DateTime.now()),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    StreamBuilder(
                      stream: Stream.periodic(const Duration(seconds: 1)),
                      builder: (context, snapshot) {
                        if (!mounted) return const SizedBox.shrink();
                        return Text(
                          timeFormat.format(DateTime.now()),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white70,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 15),
                    if (currentQuote != null)
                      Text(
                        '"$currentQuote"',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "— 《${currentShow.name}》",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 3. Top Buttons
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shuffle, color: Colors.white),
                      tooltip: '切换背景',
                      onPressed: _manualRefreshShow,
                    ),
                    IconButton(
                      icon: Icon(
                        _isExpanded ? Icons.keyboard_arrow_up : Icons.menu,
                        color: Colors.white,
                      ),
                      tooltip: '展开菜单',
                      onPressed:
                          () => setState(() => _isExpanded = !_isExpanded),
                    ),
                  ],
                ),
              ),
              // 4. Expansion Panel Menu
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                top:
                    _isExpanded
                        ? MediaQuery.of(context).padding.top + 60
                        : -(MediaQuery.of(context).size.height),
                left: 10,
                right: 10,
                child: Material(
                  elevation: 4.0,
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: theme.canvasColor.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    // Pass the currentShow from selector to the menu builder
                    child: _buildExpansionMenuItems(currentShow),
                  ),
                ),
              ),
            ],
          );
        }

        // Return Scaffold wrapping the bodyContent
        return Scaffold(body: bodyContent);
      },
    );
  }

  // Menu items builder now accepts the current show as a parameter
  Widget _buildExpansionMenuItems(TvShow currentShow) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 新增 - 跳转到详情页
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('详情页'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TvShowDetailScreen(tvShow: currentShow),
                ),
              );
              // 关闭折叠菜单
              setState(() => _isExpanded = false);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('相册'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GalleryScreen(tvShow: currentShow),
                ),
              );
              // 关闭折叠菜单
              setState(() => _isExpanded = false);
            },
          ),
          ListTile(
            leading: const Icon(Icons.music_note_outlined),
            title: const Text('音乐'),
            onTap: () async {
              // Use AudioService to play the theme song
              final audioService = Provider.of<AudioService>(context, listen: false);
              await audioService.playThemeSong(currentShow);

              // Show snackbar (optional)
              if (mounted) {
                 if (audioService.currentShow?.name == currentShow.name && audioService.isPlaying) {
                    ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text('正在播放 ${currentShow.name} 主题曲')),
                    );
                 } else if (audioService.isStopped && audioService.currentShow == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('播放主题曲失败，请检查文件是否存在')),
                    );
                 }
                 // Close the expansion panel
                 setState(() => _isExpanded = false);
              }
            },
          ),
          ListTile(
            // Play Sources Button
            leading: const Icon(Icons.play_circle_outline),
            title: const Text('播放'),
            onTap: () {
              _showPlaySourcesDialog(context, currentShow); // Use passed show
              // 关闭折叠菜单
              setState(() => _isExpanded = false);
            },
          ),
          const Divider(),
          // --- Music Controls (using Consumer for AudioService) ---
          // Always build the controls container, visibility handled inside _buildMusicControls
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 4.0,
            ),
            child: _buildMusicControls(currentShow), // Pass currentShow
          ),
          // --- Progress (Consumer for live updates) ---
          Consumer<TvShowNotifier>(
            builder: (context, notifier, child) {
              // Find the latest show data using the passed currentShow's name
              final latestShow =
                  notifier.findTvShowByName(currentShow.name) ?? currentShow;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Text(
                      '观看记录 (${latestShow.progress.current} / ${latestShow.progress.total})',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: LinearProgressIndicator(
                      value: latestShow.progress.percentage,
                      backgroundColor: Colors.grey[300],
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        tooltip: '减少进度',
                        onPressed:
                            (latestShow.progress.current <= 0)
                                ? null
                                : () {
                                  notifier.updateProgress(
                                    latestShow,
                                    latestShow.progress.current - 1,
                                    latestShow.progress.total,
                                  );
                                },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          '${latestShow.progress.current} / ${latestShow.progress.total}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: '增加进度',
                        onPressed:
                            (latestShow.progress.current >=
                                    latestShow.progress.total)
                                ? null
                                : () {
                                  notifier.updateProgress(
                                    latestShow,
                                    latestShow.progress.current + 1,
                                    latestShow.progress.total,
                                  );
                                },
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const Divider(),
          // --- Thoughts (Consumer for live updates) ---
          Consumer<TvShowNotifier>(
            builder: (context, notifier, child) {
              final latestShow =
                  notifier.findTvShowByName(currentShow.name) ?? currentShow;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Text('我的想法 (${latestShow.thoughts.length})'),
                  ),
                  if (latestShow.thoughts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('暂无想法', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        latestShow.thoughts.join(' / '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              );
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.add_comment_outlined),
            label: const Text('添加/查看想法'),
            onPressed:
                () => _showThoughtsDialog(
                  context,
                  currentShow,
                ), // Use passed show
          ),
        ],
      ),
    );
  }

  // --- Helper method to show play sources ---
  void _showPlaySourcesDialog(BuildContext context, TvShow show) {
    Provider.of<PlaySourceNotifier>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
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
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!notifier.isLoading) {
                  notifier.loadPlaySources();
                }
              });
              content = const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              );
            } else {
              final sources = notifier.sources;
              content = Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sources.length,
                  separatorBuilder:
                      (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final source = sources[index];
                    return ListTile(
                      title: Text(source.name),
                      onTap: () async {
                        Navigator.pop(ctx);
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
                            ScaffoldMessenger.of(ctx).showSnackBar( // Use ctx
                              SnackBar(content: Text('无法打开链接: $urlString')),
                            );
                          }
                        } else {
                          print(
                            "Could not generate valid URL for ${source.name}",
                          );
                        if (!ctx.mounted) return; // Use ctx from builder
                        ScaffoldMessenger.of(ctx).showSnackBar( // Use ctx
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
            final double maxHeight = MediaQuery.of(ctx).size.height * 0.6;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '选择播放源: ${show.name}',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const Divider(height: 20),
                    content,
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Helper method to show thoughts dialog ---
  // --- Helper method to show thoughts dialog with Edit/Delete ---
  void _showThoughtsDialog(BuildContext context, TvShow show) {
    _thoughtController.clear();
    int? editingIndex; // Track which thought is being edited

    // Use StatefulBuilder to manage the editing state within the dialog
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder( // Use StatefulBuilder for local state management
          builder: (context, setDialogState) {
            // Consumer is still needed to get updated show data from the provider
            return Consumer<TvShowNotifier>(
              builder: (context, notifier, child) {
                final currentShow = notifier.findTvShowByName(show.name) ?? show;
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
                                      // Edit Button
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20),
                                        tooltip: '编辑想法',
                                        onPressed: () {
                                          setDialogState(() { // Update dialog state
                                            editingIndex = index;
                                            _thoughtController.text = thoughts[index];
                                          });
                                        },
                                      ),
                                      // Delete Button
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                        tooltip: '删除想法',
                                        onPressed: () => _confirmDeleteThought(ctx, notifier, currentShow, index), // Pass ctx
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
                            labelText: editingIndex == null ? '添加新想法...' : '编辑想法...',
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
                    // Show "Cancel Edit" button only when editing
                    if (editingIndex != null)
                      TextButton(
                        onPressed: () {
                          setDialogState(() { // Update dialog state
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
                              // --- Edit existing thought ---
                              await notifier.editThought(currentShow, editingIndex!, thoughtText);
                              setDialogState(() { // Update dialog state after successful edit
                                editingIndex = null;
                                _thoughtController.clear();
                              });
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('想法已更新')));

                            } else {
                              // --- Add new thought ---
                              await notifier.addThought(currentShow, thoughtText);
                              _thoughtController.clear(); // Clear after adding
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('想法已添加')));
                            }
                          } catch (e) {
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('操作失败: $e')));
                          }
                        }
                      },
                      // Change button text based on editing state
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

  // --- Helper method to confirm thought deletion ---
  void _confirmDeleteThought(BuildContext dialogContext, TvShowNotifier notifier, TvShow show, int index) {
     showDialog(
        context: dialogContext, // Use the dialog's context
        builder: (BuildContext confirmCtx) { // Use a different context name
           return AlertDialog(
              title: const Text('确认删除'),
              content: Text('确定要删除这条想法吗？\n"${show.thoughts[index]}"'),
              actions: [
                 TextButton(
                    onPressed: () => Navigator.pop(confirmCtx), // Dismiss confirmation dialog
                    child: const Text('取消'),
                 ),
                 TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () async {
                       Navigator.pop(confirmCtx); // Dismiss confirmation dialog FIRST
                       try {
                          await notifier.removeThought(show, index);
                          if (!dialogContext.mounted) return; // Check original dialog context
                          ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('想法已删除')));
                          // No need to manually pop the main dialog here, Consumer will rebuild it
                       } catch (e) {
                          if (!dialogContext.mounted) return; // Check original dialog context
                          ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('删除失败: $e')));
                       }
                    },
                    child: const Text('删除'),
                 ),
              ],
           );
        },
     );
  }

  // --- Widget for Music Controls (Uses AudioService) ---
  // Accepts the show displayed in the menu to check relevance
  Widget _buildMusicControls(TvShow menuShow) {
    return Consumer<AudioService>(
      builder: (context, audioService, child) {
        final duration = audioService.duration;
        final position = audioService.position;
        final isPlaying = audioService.isPlaying;
        final currentAudioShow = audioService.currentShow; // Show whose audio is playing

        // Controls are relevant if audio is loaded for *any* show
        final bool showControls = duration > Duration.zero && currentAudioShow != null;
        // Check if the audio playing belongs to the show currently displayed in the *menu*
        final bool controlsAreForThisMenuShow = currentAudioShow?.name == menuShow.name;

        // Only show controls if audio is loaded AND it's for the show in this menu item
        if (!showControls || !controlsAreForThisMenuShow) {
          return const SizedBox.shrink(); // Hide if not relevant
        }

        // --- Build Controls UI ---
        final maxSeconds = duration.inSeconds.toDouble();
        final currentSeconds = position.inSeconds.toDouble().clamp(
              0.0,
              maxSeconds > 0 ? maxSeconds : 0.0,
            );

        return Column(
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
                  iconSize: 36.0,
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () async {
                    if (isPlaying) {
                      await audioService.pause();
                    } else {
                      await audioService.resume();
                    }
                  },
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined),
                  iconSize: 36.0,
                  color: Theme.of(context).colorScheme.secondary,
                  onPressed: () async {
                    await audioService.stop();
                    // UI update will happen via Consumer listening to service state
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
                    await audioService.seek(seekPosition);
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
        );
      },
    );
  }

  // Helper to format duration (e.g., 01:30)
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
