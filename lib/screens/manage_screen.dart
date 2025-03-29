import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../providers/tv_show_notifier.dart';
import '../providers/play_source_notifier.dart'; // Import PlaySourceNotifier
import '../models/tv_show.dart';
import '../models/play_source.dart'; // Import PlaySource model
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher
// Import the detail screen
import 'tv_show_detail_screen.dart';
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
      body:
          tvShowNotifier.isLoading
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
    final crossAxisCount = (screenWidth / 200).floor().clamp(
      2,
      4,
    ); // Adjust 200 based on desired card width

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
          return TvShowCardPlaceholder(
            tvShow: tvShow,
            onPlayPressed: _showPlaySourcesDialog, // Pass the method reference
          );
          // return TvShowCard(tvShow: tvShow);
        },
      ),
    );
  }

  // --- Helper method to show play sources (Copied from HomeScreen - Refactor later) ---
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
      isScrollControlled: true,
      builder: (BuildContext ctx) {
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
                 Flexible(
                   child: ListView.separated(
                     shrinkWrap: true,
                     itemCount: sources.length,
                     separatorBuilder: (context, index) => const Divider(height: 1),
                     itemBuilder: (context, index) {
                       final source = sources[index];
                       return ListTile(
                         title: Text(source.name),
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
                               Navigator.pop(ctx);
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

// Placeholder for the TvShowCard widget
class TvShowCardPlaceholder extends StatelessWidget {
  final TvShow tvShow;
  final Function(BuildContext, TvShow) onPlayPressed; // Add callback function parameter

  const TvShowCardPlaceholder({
    super.key,
    required this.tvShow,
    required this.onPlayPressed, // Make callback required
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      clipBehavior: Clip.antiAlias, // Clip the image to the card shape
      child: Column(
        // Main column for image and row below
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrap image with GestureDetector for navigation
          GestureDetector(
            onTap: () {
              // Navigate to detail screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TvShowDetailScreen(tvShow: tvShow),
                ),
              );
            },
            child: Image.file(
              File(tvShow.coverImagePath),
              fit: BoxFit.cover,
              // Make image taller for a larger card feel
              height: 220, // Increased height
              width: double.infinity, // Take full width of the card
              errorBuilder:
                  (context, error, stackTrace) => Container(
                    height: 220, // Match height
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
            ),
          ),
          // Row for Title and Play Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Expanded to allow text ellipsis
                Expanded(
                  child: Text(
                    tvShow.name,
                    style:
                        Theme.of(
                          context,
                        ).textTheme.titleSmall, // Slightly smaller title
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Play Button (implement similar logic as HomeScreen)
                IconButton(
                  icon: const Icon(Icons.play_circle_outline),
                  iconSize: 28, // Slightly larger icon
                  tooltip: '播放 ${tvShow.name}',
                  onPressed: () {
                     // Call the passed callback function
                     onPlayPressed(context, tvShow);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
