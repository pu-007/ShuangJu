import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tmdb_api/tmdb_api.dart';

class TMDBService {
  static const String _apiKey = '931bee821ab732112295061b96637896'; // 替换为你的TMDB API密钥
  static const String _readAccessToken = 'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI5MzFiZWU4MjFhYjczMjExMjI5NTA2MWI5NjYzNzg5NiIsIm5iZiI6MTc0MzE3NzM1My42NDksInN1YiI6IjY3ZTZjNjg5NWYzZTBhYzE4ODAwNjQ0NyIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.NbGd4ilqOI03RTksme0OO0_1XlVMlX-fwgSj-3Mg_yk'; // 替换为你的读取访问令牌
  
  late TMDB _tmdb;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _tmdb = TMDB(
      ApiKeys(_apiKey, _readAccessToken),
      logConfig: const ConfigLogger(
        showLogs: kDebugMode,
        showErrorLogs: true,
      ),
    );
    
    _isInitialized = true;
  }

  // 搜索电视剧
  Future<List<Map<String, dynamic>>> searchTVShows(String query) async {
    await initialize();
    try {
      final result = await _tmdb.v3.search.queryTvShows(
        query,
        language: 'zh-CN', // 指定中文语言
      );
      return List<Map<String, dynamic>>.from(result['results']);
    } catch (e) {
      debugPrint('搜索电视剧出错: $e');
      return [];
    }
  }

  // 搜索电影
  Future<List<Map<String, dynamic>>> searchMovies(String query) async {
    await initialize();
    try {
      final result = await _tmdb.v3.search.queryMovies(
        query,
        language: 'zh-CN', // 指定中文语言
      );
      return List<Map<String, dynamic>>.from(result['results']);
    } catch (e) {
      debugPrint('搜索电影出错: $e');
      return [];
    }
  }

  // 获取电视剧详情
  Future<Map<String, dynamic>?> getTVShowDetails(int id) async {
    await initialize();
    try {
      final result = await _tmdb.v3.tv.getDetails(
        id,
        language: 'zh-CN', // 指定中文语言
      );
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('获取电视剧详情出错: $e');
      return null;
    }
  }

  // 获取电影详情
  Future<Map<String, dynamic>?> getMovieDetails(int id) async {
    await initialize();
    try {
      final result = await _tmdb.v3.movies.getDetails(
        id,
        language: 'zh-CN', // 指定中文语言
      );
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('获取电影详情出错: $e');
      return null;
    }
  }

  // 获取电视剧图片
  Future<List<String>> getTVShowImages(int id) async {
    await initialize();
    try {
      final result = await _tmdb.v3.tv.getImages(
        id,
        includeImageLanguage: 'en,null', // 包含英文和无语言的图片
      );
      final backdrops = List<Map<String, dynamic>>.from(result['backdrops']);
      return backdrops.map((image) => 'https://image.tmdb.org/t/p/original${image['file_path']}').toList();
    } catch (e) {
      debugPrint('获取电视剧图片出错: $e');
      return [];
    }
  }

  // 获取电影图片
  Future<List<String>> getMovieImages(int id) async {
    await initialize();
    try {
      final result = await _tmdb.v3.movies.getImages(
        id,
        includeImageLanguage: 'en,null', // 包含英文和无语言的图片
      );
      final backdrops = List<Map<String, dynamic>>.from(result['backdrops']);
      return backdrops.map((image) => 'https://image.tmdb.org/t/p/original${image['file_path']}').toList();
    } catch (e) {
      debugPrint('获取电影图片出错: $e');
      return [];
    }
  }

  // 下载图片并保存到临时目录
  Future<File?> downloadImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final fileName = p.basename(imageUrl);
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('下载图片出错: $e');
      return null;
    }
  }
}