import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/tmdb_service.dart';

class TMDBSearchDialog extends StatefulWidget {
  final String initialQuery;
  final String mediaType; // 'tv' 或 'movie'

  const TMDBSearchDialog({
    super.key,
    required this.initialQuery,
    required this.mediaType,
  });

  @override
  State<TMDBSearchDialog> createState() => _TMDBSearchDialogState();
}

class _TMDBSearchDialogState extends State<TMDBSearchDialog> {
  final TMDBService _tmdbService = TMDBService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    if (widget.initialQuery.isNotEmpty) {
      _performSearch();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.mediaType == 'tv') {
        _searchResults = await _tmdbService.searchTVShows(query);
      } else {
        _searchResults = await _tmdbService.searchMovies(query);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '搜索出错: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '搜索${widget.mediaType == 'tv' ? '电视剧' : '电影'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: '搜索',
                        hintText: '输入名称',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _performSearch(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _performSearch,
                    tooltip: '搜索',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            else if (_searchResults.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('没有找到结果'),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    final title = widget.mediaType == 'tv'
                        ? result['name'] ?? 'Unknown'
                        : result['title'] ?? 'Unknown';
                    final posterPath = result['poster_path'];
                    final overview = result['overview'] ?? '暂无简介';
                    final year = _getYear(result);

                    return ListTile(
                      leading: posterPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: CachedNetworkImage(
                                imageUrl:
                                    'https://image.tmdb.org/t/p/w92$posterPath',
                                width: 50,
                                height: 75,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 50,
                                  height: 75,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 50,
                                  height: 75,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image),
                                ),
                              ),
                            )
                          : Container(
                              width: 50,
                              height: 75,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image),
                            ),
                      title: Text('$title ${year != null ? "($year)" : ""}'),
                      subtitle: Text(
                        overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectResult(result),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _getYear(Map<String, dynamic> result) {
    final dateStr = widget.mediaType == 'tv'
        ? result['first_air_date']
        : result['release_date'];
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      final date = DateTime.parse(dateStr);
      return date.year.toString();
    } catch (e) {
      return null;
    }
  }

  void _selectResult(Map<String, dynamic> result) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final id = result['id'];
      Map<String, dynamic>? details;
      List<String> images = [];

      if (widget.mediaType == 'tv') {
        details = await _tmdbService.getTVShowDetails(id);
        images = await _tmdbService.getTVShowImages(id);
      } else {
        details = await _tmdbService.getMovieDetails(id);
        images = await _tmdbService.getMovieImages(id);
      }

      if (details != null) {
        final posterPath = details['poster_path'];
        File? posterFile;

        if (posterPath != null) {
          final posterUrl = 'https://image.tmdb.org/t/p/original$posterPath';
          posterFile = await _tmdbService.downloadImage(posterUrl);
        }

        List<File> imageFiles = [];
        // 最多获取5张图片
        final imagesToDownload = images.take(5).toList();
        for (final imageUrl in imagesToDownload) {
          final imageFile = await _tmdbService.downloadImage(imageUrl);
          if (imageFile != null) {
            imageFiles.add(imageFile);
          }
        }

        if (!mounted) return;

        Navigator.pop(
          context,
          {
            'details': details,
            'posterFile': posterFile,
            'imageFiles': imageFiles,
          },
        );
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = '无法获取详细信息';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '获取详细信息出错: $e';
      });
    }
  }
}