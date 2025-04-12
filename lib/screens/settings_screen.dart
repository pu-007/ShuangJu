// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
// For PlayerState if needed, or remove if not used directly
import 'package:video_player/video_player.dart'; // For birthday video
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'package:provider/provider.dart';
import '../providers/tv_show_notifier.dart'; // Import TvShowNotifier
import '../services/audio_service.dart'; // Import AudioService
// Import TvShow model

// Import screens/dialogs for editing sources
import 'edit_sources_screen.dart'; // Import the screen
import 'permissions_info_screen.dart'; // Import the permissions info screen

// Helper to format Duration into a readable string (e.g., "1 小时 30 分钟")
String _formatDuration(Duration duration) {
  if (duration.inSeconds < 0) return "无效间隔"; // Handle negative duration
  if (duration.inSeconds < 60) {
    return '${duration.inSeconds} 秒';
  } else if (duration.inMinutes < 60) {
     final minutes = duration.inMinutes;
     final seconds = duration.inSeconds.remainder(60);
     return '$minutes 分钟${seconds > 0 ? ' $seconds 秒' : ''}';
  } else {
     final hours = duration.inHours;
     final minutes = duration.inMinutes.remainder(60);
     return '$hours 小时${minutes > 0 ? ' $minutes 分钟' : ''}';
  }
}


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _updateIntervalKey = 'home_update_interval_seconds';
  Duration _selectedInterval = const Duration(hours: 1); // Default to 1 hour

  @override
  void initState() {
    super.initState();
    _loadUpdateInterval(); // Load saved interval on init
  }

  // Load saved interval from SharedPreferences
  Future<void> _loadUpdateInterval() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSeconds = prefs.getInt(_updateIntervalKey) ?? 3600;
    if (mounted) { // Check if widget is still mounted
       setState(() {
         _selectedInterval = Duration(seconds: savedSeconds < 10 ? 10 : savedSeconds);
       });
    }
  }

  // Save selected interval to SharedPreferences
  Future<void> _saveUpdateInterval(Duration newInterval) async {
    final intervalToSave = newInterval.inSeconds < 10
        ? const Duration(seconds: 10)
        : newInterval;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_updateIntervalKey, intervalToSave.inSeconds);
     if (mounted) { // Check if widget is still mounted
        setState(() {
          _selectedInterval = intervalToSave;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('主页背景更新频率已保存为: ${_formatDuration(intervalToSave)}'),
            duration: const Duration(seconds: 2),
          ),
        );
        // Notify HomeScreen (indirectly via TvShowNotifier) that settings changed
        Provider.of<TvShowNotifier>(context, listen: false).notifySettingsChanged();
     }
  }

  // --- Method to show interval picker dialog ---
  Future<void> _showIntervalPicker(BuildContext context) async {
    final newInterval = await showDialog<Duration>(
      context: context,
      // Use the separate StatefulWidget for the dialog content
      builder: (context) => _IntervalPickerDialog(initialInterval: _selectedInterval),
    );

    // Check mounted again after await before saving
    if (newInterval != null && mounted) {
      await _saveUpdateInterval(newInterval);
    }
  }


  // Function to play the birthday video
  void _playBirthdayVideo(BuildContext context) async {
    final videoPlayerController = VideoPlayerController.asset('assets/birthday_mv.mp4');

    try {
      await videoPlayerController.initialize();
      await videoPlayerController.setLooping(true);
      await videoPlayerController.play();

      if (!mounted) return; // Check mounted before showing dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
              contentPadding: EdgeInsets.zero,
              content: AspectRatio(
                aspectRatio: videoPlayerController.value.aspectRatio,
                child: VideoPlayer(videoPlayerController),
              ),
              actions: [
                TextButton(
                  child: const Text('关闭'),
                  onPressed: () {
                    videoPlayerController.dispose();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
      ).then((_) => videoPlayerController.dispose()); // Ensure disposal if dismissed
    } catch (e) {
      print("Error playing birthday video: $e");
      // Ensure mounted check is directly before context use in catch block
      if (mounted) {
         if (!mounted) return; // Ensure mounted before using context
         final messenger = ScaffoldMessenger.of(context); // Capture messenger
         messenger.showSnackBar(SnackBar(content: Text('无法播放生日祝福视频: $e')));
      }
    }
  }

  // Function to navigate to edit sources screen
  void _navigateToEditSources(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditSourcesScreen()),
    ).then((_) {
       // Optional: Force reload sources after returning from edit screen
       // Provider.of<PlaySourceNotifier>(context, listen: false).reloadPlaySources();
       print("Returned from EditSourcesScreen");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('爽剧 - 设置')),
      body: Column( // Use Column to allow placing the player controls at the bottom
        children: [
          Expanded( // Make the ListView take available space
            child: ListView(
              children: <Widget>[
                // --- Existing Settings ---
                ListTile(
                  leading: const Icon(Icons.edit_location_alt_outlined),
                  title: const Text('编辑数据源'),
                  subtitle: const Text('管理跳转播放链接'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _navigateToEditSources(context),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('主页背景更新频率'),
                  subtitle: Text('当前: ${_formatDuration(_selectedInterval)}'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showIntervalPicker(context),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.cake_outlined),
                  title: const Text('播放生日祝福'),
                  subtitle: const Text('观看特别为你准备的视频'),
                  trailing: const Icon(Icons.play_arrow),
                  onTap: () => _playBirthdayVideo(context),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('权限说明'),
                  subtitle: const Text('了解应用所需权限及其用途'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PermissionsInfoScreen(),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('关于应用'),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'ShuangJu - 爽剧',
                      applicationVersion: 'v5.20.4', // Consider making this dynamic
                      applicationLegalese: '© 2025.5.24 为梁爽定制',
                    );
                  },
                ),
                const Divider(), // Add a divider before the player
              ],
            ),
          ),
          // --- Global Music Player Controls ---
          _buildGlobalMusicControls(), // Add the player widget here
        ],
      ),
    );
  }

  // --- Widget for Global Music Controls ---
  Widget _buildGlobalMusicControls() {
    return Consumer<AudioService>(
      builder: (context, audioService, child) {
        final currentShow = audioService.currentShow;
        final duration = audioService.duration;
        final position = audioService.position;
        final isPlaying = audioService.isPlaying;

        // Only show controls if a show's audio is loaded/playing/paused
        if (currentShow == null || duration <= Duration.zero) {
          return const SizedBox.shrink(); // Hide if nothing is playing
        }

        final maxSeconds = duration.inSeconds.toDouble();
        final currentSeconds = position.inSeconds.toDouble().clamp(
              0.0,
              maxSeconds > 0 ? maxSeconds : 0.0,
            );

        return Material( // Wrap with Material for elevation and theming
          elevation: 4.0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .5), // Background color
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '正在播放: ${currentShow.name}',
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Play/Pause Button
                    IconButton(
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                      ),
                      iconSize: 40.0,
                      color: Theme.of(context).colorScheme.primary,
                      tooltip: isPlaying ? '暂停' : '播放',
                      onPressed: () async {
                        if (isPlaying) {
                          await audioService.pause();
                        } else {
                          await audioService.resume();
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    // Stop Button
                    IconButton(
                      icon: const Icon(Icons.stop_circle_outlined),
                      iconSize: 40.0,
                      color: Theme.of(context).colorScheme.secondary,
                      tooltip: '停止',
                      onPressed: () async {
                        await audioService.stop();
                      },
                    ),
                    // TODO: Add Shuffle/Random button if needed later
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
                  padding: const EdgeInsets.symmetric(horizontal: 0.0), // Adjust padding
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
          ),
        );
      },
    );
  }
}


// --- Stateful Dialog for Interval Picker ---
class _IntervalPickerDialog extends StatefulWidget {
  final Duration initialInterval;

  const _IntervalPickerDialog({required this.initialInterval});

  @override
  State<_IntervalPickerDialog> createState() => _IntervalPickerDialogState();
}

class _IntervalPickerDialogState extends State<_IntervalPickerDialog> {
  late TextEditingController _hoursController;
  late TextEditingController _minutesController;
  late TextEditingController _secondsController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _hoursController = TextEditingController(text: widget.initialInterval.inHours.toString());
    final remainingMinutes = widget.initialInterval.inMinutes.remainder(60);
    _minutesController = TextEditingController(text: remainingMinutes.toString());
    final remainingSeconds = widget.initialInterval.inSeconds.remainder(60);
    _secondsController = TextEditingController(text: remainingSeconds.toString());
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  // Helper for interval text fields
  Widget _buildIntervalTextField(TextEditingController controller, String label, int min, int max) {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 4.0),
       child: TextFormField(
         controller: controller,
         decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
         keyboardType: TextInputType.number,
         validator: (value) {
           if (value == null || value.isEmpty) {
             // Allow empty input, treat as 0
             return null;
           }
           final number = int.tryParse(value);
           if (number == null) {
             return '请输入有效数字';
           }
           if (number < min || number > max) {
             return '请输入 $min 到 $max 之间的数字';
           }
           return null;
         },
       ),
     );
  }

  @override
  Widget build(BuildContext context) {
     return AlertDialog(
        title: const Text('设置更新间隔'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIntervalTextField(_hoursController, '小时', 0, 99), // Max 99 hours
              _buildIntervalTextField(_minutesController, '分钟', 0, 59),
              _buildIntervalTextField(_secondsController, '秒', 0, 59),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('取消'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('确定'),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                // Use ?? 0 to handle empty inputs safely
                final hours = int.tryParse(_hoursController.text) ?? 0;
                final minutes = int.tryParse(_minutesController.text) ?? 0;
                final seconds = int.tryParse(_secondsController.text) ?? 0;
                final totalSeconds = hours * 3600 + minutes * 60 + seconds;
                // Ensure minimum interval of 10 seconds
                Navigator.of(context).pop(Duration(seconds: totalSeconds < 10 ? 10 : totalSeconds));
              }
            },
          ),
        ],
      );
  }
}
