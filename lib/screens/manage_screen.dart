import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../providers/tv_show_notifier.dart';
import '../models/tv_show.dart';
// Import a future widget for the TV show card
// import '../widgets/tv_show_card.dart';

class ManageScreen extends StatelessWidget {
  const ManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the TvShowNotifier
    final tvShowNotifier = Provider.of<TvShowNotifier>(context);
    final tvShows = tvShowNotifier.tvShows; // Get the sorted list

    return Scaffold(
      appBar: AppBar(
        title: const Text('电视剧管理'),
        // Potentially add actions like search or filter later
      ),
      body: tvShowNotifier.isLoading
          ? const Center(child: CircularProgressIndicator())
          : tvShowNotifier.error != null
              ? Center(child: Text("加载管理数据出错: ${tvShowNotifier.error}"))
              : tvShows.isEmpty
                  ? const Center(child: Text('没有电视剧数据'))
                  : _buildTvShowGrid(context, tvShows),
    );
  }

  Widget _buildTvShowGrid(BuildContext context, List<TvShow> tvShows) {
    // Determine cross axis count based on screen width (simple example)
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = (screenWidth / 200).floor().clamp(2, 4); // Adjust 200 based on desired card width

    return Padding(
      padding: const EdgeInsets.all(8.0), // Add padding around the grid
      child: MasonryGridView.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8.0, // Spacing between items vertically
        crossAxisSpacing: 8.0, // Spacing between items horizontally
        itemCount: tvShows.length,
        itemBuilder: (context, index) {
          final tvShow = tvShows[index];
          // Replace with the actual TvShowCard widget later
          return TvShowCardPlaceholder(tvShow: tvShow);
          // return TvShowCard(tvShow: tvShow);
        },
      ),
    );
  }
}


// Placeholder for the TvShowCard widget
class TvShowCardPlaceholder extends StatelessWidget {
  final TvShow tvShow;

  const TvShowCardPlaceholder({super.key, required this.tvShow});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      clipBehavior: Clip.antiAlias, // Clip the image to the card shape
      child: InkWell( // Make the card tappable
        onTap: () {
          // TODO: Navigate to detail screen or show actions
          print('Tapped on ${tvShow.name}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            Image.file(
              File(tvShow.coverImagePath),
              fit: BoxFit.cover,
              // Add height constraint or use AspectRatio if needed
              height: 150, // Example fixed height
              width: double.infinity, // Take full width of the card
              errorBuilder: (context, error, stackTrace) => Container(
                height: 150,
                color: Colors.grey[300],
                child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
              ),
            ),
            // Title and basic info padding
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    Text(
                      tvShow.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Add favorite icon if needed
                    if (tvShow.favorite)
                       Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                    // Placeholder for other info/buttons
                    Text('进度: ${tvShow.progress.current}/${tvShow.progress.total}', style: Theme.of(context).textTheme.bodySmall),
                 ],
              ),
            ),
             // Placeholder for action buttons row
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 4.0),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceAround,
                 children: [
                   IconButton(icon: Icon(Icons.music_note_outlined, size: 20), onPressed: () {}, tooltip: '播放音乐'),
                   IconButton(icon: Icon(Icons.play_circle_outline, size: 20), onPressed: () {}, tooltip: '播放剧集'),
                   IconButton(icon: Icon(Icons.edit_note_outlined, size: 20), onPressed: () {}, tooltip: '查看/编辑想法'),
                 ],
               ),
             )
          ],
        ),
      ),
    );
  }
}