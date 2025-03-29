import 'package:flutter/material.dart';
// For potential links later
import 'package:video_player/video_player.dart'; // For birthday video
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences

// Import screens/dialogs for editing sources
import 'edit_sources_screen.dart'; // Import the screen

// Define update frequency options
enum UpdateFrequency { hourly, daily, weekly } // Define enum for clarity

// Helper to get display string for frequency
String _getFrequencyDisplayString(UpdateFrequency frequency) {
  switch (frequency) {
    case UpdateFrequency.hourly:
      return '每小时';
    case UpdateFrequency.daily:
      return '每日';
    case UpdateFrequency.weekly:
      return '每周';
    default:
      return '未知';
  }
}

// Helper to get frequency from string (for loading from prefs)
UpdateFrequency _getFrequencyFromString(String? freqString) {
  if (freqString == UpdateFrequency.hourly.toString()) {
    return UpdateFrequency.hourly;
  } else if (freqString == UpdateFrequency.weekly.toString()) {
     return UpdateFrequency.weekly;
  }
  // Default to daily if null or unrecognized
  return UpdateFrequency.daily;
}


class SettingsScreen extends StatefulWidget { // Convert to StatefulWidget
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> { // Create State class
  static const String _updateFrequencyKey = 'update_frequency'; // SharedPreferences key
  UpdateFrequency _selectedFrequency = UpdateFrequency.daily; // Default value

  @override
  void initState() {
    super.initState();
    _loadUpdateFrequency(); // Load saved frequency on init
  }

  // Load saved frequency from SharedPreferences
  Future<void> _loadUpdateFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFrequencyString = prefs.getString(_updateFrequencyKey);
    setState(() {
      _selectedFrequency = _getFrequencyFromString(savedFrequencyString);
    });
  }

  // Save selected frequency to SharedPreferences
  Future<void> _saveUpdateFrequency(UpdateFrequency? newFrequency) async {
    if (newFrequency == null) return; // Do nothing if null

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_updateFrequencyKey, newFrequency.toString());
    setState(() {
      _selectedFrequency = newFrequency;
    });
     // Optional: Show a confirmation SnackBar
     // ignore: use_build_context_synchronously
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
          content: Text('更新频率已保存为: ${_getFrequencyDisplayString(newFrequency)}'),
          duration: const Duration(seconds: 2),
       ),
     );
  }

  // Function to play the birthday video
  void _playBirthdayVideo(BuildContext context) async {
    // In a real app, you'd likely navigate to a dedicated video player screen.
    // For simplicity here, we might try to launch it if possible,
    // but a dedicated screen is better for controls.

    // Let's create a simple dialog showing the video for now.
    // NOTE: This requires the video_player package.
    final videoPlayerController = VideoPlayerController.asset('assets/birthday_mv.mp4');

    try {
      await videoPlayerController.initialize();
      await videoPlayerController.setLooping(true); // Optional: loop the video
      await videoPlayerController.play();

      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          contentPadding: EdgeInsets.zero, // Remove default padding
          content: AspectRatio(
            aspectRatio: videoPlayerController.value.aspectRatio,
            child: VideoPlayer(videoPlayerController),
          ),
          actions: [
            TextButton(
              child: const Text('关闭'),
              onPressed: () {
                videoPlayerController.dispose(); // Stop and release resources
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        // Ensure controller is disposed when dialog is dismissed externally
      ).then((_) => videoPlayerController.dispose());

    } catch (e) {
       print("Error playing birthday video: $e");
       // ignore: use_build_context_synchronously
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法播放生日祝福视频: $e')),
       );
    }
  }

  // Function to navigate to edit sources screen
  void _navigateToEditSources(BuildContext context) {
     Navigator.push(
       context,
       MaterialPageRoute(builder: (context) => const EditSourcesScreen()),
     );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.edit_location_alt_outlined),
            title: const Text('编辑数据源'),
            subtitle: const Text('管理跳转播放链接'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _navigateToEditSources(context),
          ),
          const Divider(),
          // Add Update Frequency Setting ListTile
          ListTile(
            leading: const Icon(Icons.update),
            title: const Text('检查更新频率'),
            subtitle: Text('当前: ${_getFrequencyDisplayString(_selectedFrequency)}'),
            trailing: DropdownButton<UpdateFrequency>(
              value: _selectedFrequency,
              // Use enum values directly
              items: UpdateFrequency.values.map((UpdateFrequency frequency) {
                return DropdownMenuItem<UpdateFrequency>(
                  value: frequency,
                  child: Text(_getFrequencyDisplayString(frequency)),
                );
              }).toList(),
              onChanged: (UpdateFrequency? newValue) {
                 _saveUpdateFrequency(newValue); // Call save method on change
              },
              underline: Container(), // Hide default underline if desired
            ),
            // No onTap needed for the ListTile itself if using DropdownButton
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
          // Add more settings items here if needed
          // Example: About section
          // ListTile(
          //   leading: const Icon(Icons.info_outline),
          //   title: const Text('关于应用'),
          //   onTap: () {
          //     showAboutDialog(
          //       context: context,
          //       applicationName: 'ShuangJu - 爽剧',
          //       applicationVersion: '1.0.0', // TODO: Get version dynamically
          //       applicationLegalese: '© 2025 为梁爽定制',
          //     );
          //   },
          // ),
        ],
      ),
    );
  }
}