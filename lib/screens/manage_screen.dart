// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../providers/tv_show_notifier.dart';
import '../providers/play_source_notifier.dart';
import '../models/tv_show.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tv_show_detail_screen.dart';
import 'edit_tv_show_screen.dart'; // 导入编辑电视剧页面

class ManageScreen extends StatefulWidget {
  const ManageScreen({super.key});

  @override
  State<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen> {
  bool _isEditMode = false;
  String? _searchQuery;

  @override
  Widget build(BuildContext context) {
    // Access the TvShowNotifier
    final tvShowNotifier = Provider.of<TvShowNotifier>(context);
    final tvShows = tvShowNotifier.tvShows; // Get the sorted list

    return Scaffold(
      appBar: AppBar(
        title:
            _searchQuery == null
                ? const Text('爽剧 - 管理')
                : TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '搜索电视剧...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.isEmpty ? null : value;
                    });
                  },
                ),
        actions: [
          // 搜索按钮
          IconButton(
            icon: Icon(_searchQuery == null ? Icons.search : Icons.clear),
            tooltip: _searchQuery == null ? '搜索' : '清除搜索',
            onPressed: () {
              setState(() {
                _searchQuery = _searchQuery == null ? '' : null;
              });
            },
          ),
          // 编辑模式切换按钮
          IconButton(
            icon: Icon(_isEditMode ? Icons.done : Icons.edit),
            tooltip: _isEditMode ? '完成编辑' : '进入编辑模式',
            onPressed: () {
              setState(() {
                _isEditMode = !_isEditMode;
              });
            },
          ),
          // 添加新电视剧按钮
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加新电视剧',
            onPressed: () => _navigateToAddTvShow(context),
          ),
        ],
      ),
      body:
          tvShowNotifier.isLoading
              ? const Center(child: CircularProgressIndicator())
              : tvShowNotifier.error != null
              ? Center(child: Text("加载管理数据出错: ${tvShowNotifier.error}"))
              : tvShows.isEmpty
              ? _buildEmptyState(context)
              : _buildTvShowGrid(context, tvShows),
    );
  }

  // 导航到添加电视剧页面
  void _navigateToAddTvShow(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditTvShowScreen()),
    );
  }

  // 导航到编辑电视剧页面
  void _navigateToEditTvShow(BuildContext context, TvShow tvShow) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditTvShowScreen(tvShow: tvShow, isEditing: true),
      ),
    );
  }

  // 确认删除电视剧对话框
  void _confirmDeleteTvShow(BuildContext context, TvShow tvShow) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除电视剧"${tvShow.name}"吗？此操作不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteTvShow(context, tvShow);
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  // 删除电视剧
  void _deleteTvShow(BuildContext context, TvShow tvShow) async {
    try {
      final tvShowNotifier = Provider.of<TvShowNotifier>(
        context,
        listen: false,
      );
      await tvShowNotifier.deleteTvShow(tvShow);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('电视剧"${tvShow.name}"已删除')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  // 快速编辑图片

  // 快速编辑台词

  // 快速编辑主题曲

  // 切换收藏状态
  void _toggleFavorite(BuildContext context, TvShow tvShow) async {
    try {
      final tvShowNotifier = Provider.of<TvShowNotifier>(
        context,
        listen: false,
      );
      await tvShowNotifier.toggleFavorite(tvShow);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tvShow.favorite
                  ? '已将"${tvShow.name}"从收藏中移除'
                  : '已将"${tvShow.name}"添加到收藏',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  // 空状态视图
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.movie_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('没有电视剧数据'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddTvShow(context),
            icon: const Icon(Icons.add),
            label: const Text('添加电视剧'),
          ),
        ],
      ),
    );
  }

  Widget _buildTvShowGrid(BuildContext context, List<TvShow> tvShows) {
    // 如果有搜索查询，过滤电视剧列表
    final filteredShows =
        _searchQuery != null && _searchQuery!.isNotEmpty
            ? tvShows
                .where(
                  (show) =>
                      show.name.toLowerCase().contains(
                        _searchQuery!.toLowerCase(),
                      ) ||
                      (show.alias != null &&
                          show.alias!.toLowerCase().contains(
                            _searchQuery!.toLowerCase(),
                          )) ||
                      show.overview.toLowerCase().contains(
                        _searchQuery!.toLowerCase(),
                      ),
                )
                .toList()
            : tvShows;

    // 如果过滤后没有结果
    if (filteredShows.isEmpty &&
        _searchQuery != null &&
        _searchQuery!.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text('没有找到与"$_searchQuery"相关的电视剧'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() => _searchQuery = null),
              icon: const Icon(Icons.clear),
              label: const Text('清除搜索'),
            ),
          ],
        ),
      );
    }

    // Determine cross axis count based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = (screenWidth / 200).floor().clamp(2, 4);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: MasonryGridView.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8.0,
        crossAxisSpacing: 8.0,
        itemCount: filteredShows.length,
        itemBuilder: (context, index) {
          final tvShow = filteredShows[index];
          return TvShowCardPlaceholder(
            tvShow: tvShow,
            isEditMode: _isEditMode,
            onPlayPressed: _showPlaySourcesDialog,
            onEditPressed: _navigateToEditTvShow,
            onDeletePressed: _confirmDeleteTvShow,
            onToggleFavorite: _toggleFavorite,
          );
        },
      ),
    );
  }

  // --- Helper method to show play sources (Copied from HomeScreen - Refactor later) ---
  void _showPlaySourcesDialog(BuildContext context, TvShow show) {
    final playSourceNotifier = Provider.of<PlaySourceNotifier>(
      context,
      listen: false,
    );
    final sources = playSourceNotifier.sources;

    if (sources.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有可用的播放源')));
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
                    separatorBuilder:
                        (context, index) => const Divider(height: 1),
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
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                              // ignore: use_build_context_synchronously
                              Navigator.pop(ctx);
                            } else {
                              print("Could not launch $url");
                              if (!ctx.mounted) return; // Add mounted check
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('无法打开链接: $urlString')),
                              );
                            }
                          } else {
                            print(
                              "Could not generate valid URL for ${source.name}",
                            );
                            if (!ctx.mounted) return; // Add mounted check
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('无法为 ${source.name} 生成有效链接'),
                              ),
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
  final bool isEditMode;
  final Function(BuildContext, TvShow) onPlayPressed;
  final Function(BuildContext, TvShow) onEditPressed;
  final Function(BuildContext, TvShow) onDeletePressed;
  final Function(BuildContext, TvShow) onToggleFavorite;

  const TvShowCardPlaceholder({
    super.key,
    required this.tvShow,
    required this.isEditMode,
    required this.onPlayPressed,
    required this.onEditPressed,
    required this.onDeletePressed,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图片和操作按钮
          Stack(
            children: [
              GestureDetector(
                onTap: () {
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
                  height: 220,
                  width: double.infinity,
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        height: 220,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                ),
              ),
              // 显示进度信息
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  child: Text(
                    '进度: ${tvShow.progress.current}/${tvShow.progress.total}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              // 收藏按钮
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: Icon(
                      tvShow.favorite ? Icons.favorite : Icons.favorite_border,
                      color: tvShow.favorite ? Colors.red : Colors.white,
                      size: 24,
                    ),
                    tooltip: tvShow.favorite ? '取消收藏' : '收藏',
                    onPressed: () => onToggleFavorite(context, tvShow),
                  ),
                ),
              ),

              // 编辑模式下的操作按钮
              if (isEditMode)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        // 编辑按钮
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: '编辑电视剧',
                          onPressed: () => onEditPressed(context, tvShow),
                        ),
                        // 删除按钮
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: '删除电视剧',
                          onPressed: () => onDeletePressed(context, tvShow),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          // 标题、别名和操作按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题和播放按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tvShow.name,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (tvShow.alias != null && tvShow.alias!.isNotEmpty)
                            Text(
                              tvShow.alias!,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_circle_outline),
                          iconSize: 28,
                          tooltip: '播放 ${tvShow.name}',
                          onPressed: () => onPlayPressed(context, tvShow),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
