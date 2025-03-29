import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // For potential links later
import 'package:video_player/video_player.dart'; // For birthday video

// Import screens/dialogs for editing sources
import 'edit_sources_screen.dart'; // Import the screen

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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