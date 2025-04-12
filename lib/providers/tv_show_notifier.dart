// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math'; // Import Random
import 'package:flutter/foundation.dart'; // For ChangeNotifier, ValueNotifier
import 'package:path/path.dart' as p;
import '../models/tv_show.dart';
import '../models/progress.dart';
import '../services/data_service.dart';

class TvShowNotifier extends ChangeNotifier {
  final DataService _dataService;

  List<TvShow> _tvShows = [];
  bool _isLoading = false;
  String? _error;

  // State for HomeScreen display
  TvShow? _currentHomeScreenShow;
  String? _currentHomeScreenQuote;
  bool _initialHomeScreenShowSelected = false; // Flag for initial selection

  TvShowNotifier(this._dataService); // Removed immediate load call

  // --- Getters ---
  List<TvShow> get tvShows => _tvShows;
  List<TvShow> get favoriteTvShows =>
      _tvShows.where((show) => show.favorite).toList();
  List<TvShow> get nonFavoriteTvShows =>
      _tvShows.where((show) => !show.favorite).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  TvShow? get currentHomeScreenShow => _currentHomeScreenShow;
  String? get currentHomeScreenQuote => _currentHomeScreenQuote;
  bool get initialHomeScreenShowSelected =>
      _initialHomeScreenShowSelected; // Getter for the flag
  ValueNotifier<int> get settingsChangeNotifier =>
      _settingsChangeNotifier; // Getter for the settings change signal

  // --- State for Settings Change Signal ---
  final ValueNotifier<int> _settingsChangeNotifier = ValueNotifier<int>(0);

  // --- Methods ---

  /// Loads TV shows from the DataService.
  Future<void> loadTvShows() async {
    _isLoading = true;
    _error = null;
    notifyListeners(); // Notify UI about loading start
    try {
      // Initialization/Permission check is now handled within loadTvShows
      // await _dataService.initializeDataIfNeeded(); // Removed this line
      _tvShows = await _dataService.loadTvShows();
      // Sort shows: favorites first, then by name
      _tvShows.sort((a, b) {
        if (a.favorite != b.favorite) {
          return b.favorite ? 1 : -1; // Favorites come first
        }
        return a.name.compareTo(b.name); // Then sort by name
      });
      _isLoading = false;
      print(
        "[TvShowNotifier] TvShows loaded successfully: ${_tvShows.length} shows.",
      ); // Added Log Tag
    } catch (e) {
      print("[TvShowNotifier] Error loading TV shows: $e"); // Added Log Tag
      _error = "加载电视剧数据失败: $e";
      _isLoading = false;
    } finally {
      notifyListeners(); // Notify UI about loading end (success or error)
    }
  }

  /// Updates a specific TV show (e.g., progress, favorite status, thoughts)
  /// and saves it using DataService.
  Future<void> updateTvShow(
    TvShow updatedShow, {
    TvShow? originalShow,
    bool forceJsonSave = false,
  }) async {
    // 如果提供了原始电视剧对象，使用它来查找索引（用于处理名称变更）
    final index =
        originalShow != null
            ? _tvShows.indexWhere((show) => show.name == originalShow.name)
            : _tvShows.indexWhere((show) => show.name == updatedShow.name);

    if (index != -1) {
      // Save to persistence first
      try {
        // 如果名称发生变更且有原始路径，需要处理目录重命名
        if (originalShow != null &&
            originalShow.name != updatedShow.name &&
            originalShow.directoryPath != null) {
          // 获取父目录路径
          final parentDir = p.dirname(originalShow.directoryPath!);
          final newDirPath = p.join(parentDir, updatedShow.name);

          // 创建新目录
          await Directory(newDirPath).create(recursive: true);

          // 复制所有文件到新目录
          final oldDir = Directory(originalShow.directoryPath!);
          if (await oldDir.exists()) {
            await for (final entity in oldDir.list()) {
              if (entity is File) {
                final newPath = p.join(newDirPath, p.basename(entity.path));
                await entity.copy(newPath);
              }
            }
          }

          // 创建新电视剧

          // 删除电视剧
          // 更新目录路径
          final updatedShowWithNewPath = updatedShow.copyWith(
            directoryPath: newDirPath,
          );

          // 保存到新位置
          await _dataService.saveTvShow(updatedShowWithNewPath);

          // 删除旧目录
          await oldDir.delete(recursive: true);

          // 更新内存中的电视剧对象
          _tvShows[index] = updatedShowWithNewPath;
        } else {
          // 正常保存更新（无名称变更）
          await _dataService.saveTvShow(updatedShow);
          // 更新内存中的列表
          _tvShows[index] = updatedShow;

          // 如果强制保存JSON，则重新加载所有电视剧以确保数据一致性
          if (forceJsonSave) {
            print("强制重新加载电视剧数据以确保一致性");
            await loadTvShows();
          }
        }

        // 重新排序（如果收藏状态变更）
        if (_tvShows[index].favorite != updatedShow.favorite) {
          _tvShows.sort((a, b) {
            if (a.favorite != b.favorite) {
              return b.favorite ? 1 : -1;
            }
            return a.name.compareTo(b.name);
          });
        }

        print("TvShow updated successfully: ${updatedShow.name}");
        notifyListeners(); // 通知UI更新
      } catch (e) {
        print("Error saving updated TvShow ${updatedShow.name}: $e");
        _error = "保存 '${updatedShow.name}' 更新失败: $e";
        notifyListeners(); // 通知UI错误
      }
    } else {
      print("Error: Could not find TvShow to update.");
      _error = "找不到要更新的电视剧";
      notifyListeners();
    }
  }

  /// Toggles the favorite status of a TV show.
  Future<void> toggleFavorite(TvShow show) async {
    final updatedShow = show.copyWith(favorite: !show.favorite);
    await updateTvShow(updatedShow);
  }

  /// Updates the progress of a TV show.
  Future<void> updateProgress(TvShow show, num current, num total) async {
    final updatedProgress = show.progress.copyWith(
      current: current,
      total: total,
    );
    final updatedShow = show.copyWith(progress: updatedProgress);
    await updateTvShow(updatedShow);
  }

  /// Adds a thought to a TV show.
  Future<void> addThought(TvShow show, String thought) async {
    final updatedThoughts = List<String>.from(show.thoughts)..add(thought);
    final updatedShow = show.copyWith(thoughts: updatedThoughts);
    await updateTvShow(updatedShow);
  }

  /// Removes a thought from a TV show by index.
  Future<void> removeThought(TvShow show, int index) async {
    if (index >= 0 && index < show.thoughts.length) {
      final updatedThoughts = List<String>.from(show.thoughts)..removeAt(index);
      final updatedShow = show.copyWith(thoughts: updatedThoughts);
      await updateTvShow(updatedShow);
    }
  }

  /// Edits a thought at a specific index.
  Future<void> editThought(TvShow show, int index, String newThought) async {
    if (index >= 0 && index < show.thoughts.length) {
      final updatedThoughts = List<String>.from(show.thoughts);
      updatedThoughts[index] = newThought;
      final updatedShow = show.copyWith(thoughts: updatedThoughts);
      await updateTvShow(updatedShow);
    }
  }

  /// 更新电视剧的台词列表
  Future<void> updateLines(TvShow show, List<String> updatedLines) async {
    final updatedShow = show.copyWith(lines: updatedLines);
    await updateTvShow(updatedShow);
  }

  /// 删除电视剧
  Future<void> deleteTvShow(TvShow tvShow) async {
    try {
      // 首先从数据服务中删除
      await _dataService.deleteTvShow(tvShow);

      // 然后从内存中移除
      _tvShows.removeWhere((show) => show.name == tvShow.name);

      // 如果删除的是当前主页显示的电视剧，则重新选择一个
      if (_currentHomeScreenShow?.name == tvShow.name) {
        _currentHomeScreenShow = null;
        _currentHomeScreenQuote = null;
        selectRandomHomeScreenShow();
      }

      notifyListeners();
    } catch (e) {
      print("Error in TvShowNotifier.deleteTvShow: $e");
      _error = "删除电视剧失败: $e";
      notifyListeners();
      rethrow; // 重新抛出异常以便上层处理
    }
  }

  /// 获取电视剧存储路径
  Future<String> getTvShowsPath() async {
    return await _dataService.getTvShowsPath();
  }

  /// 创建新电视剧
  Future<TvShow> createNewTvShow({
    required String name,
    required String overview,
    required String mediaType,
    required Progress progress,
    required bool favorite,
    required List<String> lines,
    required Map<String, String> inlineLines,
    String? alias,
    required File coverImage,
    File? themeSong,
    required List<File> additionalImages,
  }) async {
    try {
      // 创建新的电视剧目录
      final tvShowsPath = await _dataService.getTvShowsPath();
      final showDirPath = p.join(tvShowsPath, name);

      // 确保目录存在
      await Directory(showDirPath).create(recursive: true);

      // 保存封面图片
      final coverPath = p.join(showDirPath, 'cover.jpg');
      await File(coverPath).writeAsBytes(await coverImage.readAsBytes());

      // 保存主题曲（如果有）
      if (themeSong != null) {
        final themeSongPath = p.join(showDirPath, 'themesong.mp3');
        await File(themeSongPath).writeAsBytes(await themeSong.readAsBytes());
      }

      // 保存额外的图片
      // 创建一个映射，用于存储原始图片名称和新图片名称的对应关系
      Map<String, String> imageNameMap = {};

      for (var image in additionalImages) {
        final originalImageName = p.basename(image.path);
        // 重命名图片
        final newImageName = '$name-${additionalImages.indexOf(image)}.jpg';
        final imagePath = p.join(showDirPath, newImageName);
        await File(imagePath).writeAsBytes(await image.readAsBytes());

        // 记录原始图片名称和新图片名称的映射关系
        imageNameMap[originalImageName] = newImageName;
        print('保存图片: $originalImageName -> $newImageName');
      }

      // 更新 inline_lines 中的键名，确保使用新的图片文件名
      Map<String, String> updatedInlineLines = {};
      inlineLines.forEach((key, value) {
        // 如果键在映射中存在，使用新的图片名称作为键
        if (imageNameMap.containsKey(key)) {
          updatedInlineLines[imageNameMap[key]!] = value;
          print('更新图片台词键名: $key -> ${imageNameMap[key]} = $value');
        } else {
          // 否则保持原样
          updatedInlineLines[key] = value;
        }
      });

      // 创建新的电视剧对象
      final newShow = TvShow(
        name: name,
        overview: overview,
        media_type: mediaType,
        progress: progress,
        favorite: favorite,
        lines: lines,
        inline_lines: updatedInlineLines, // 使用更新后的图片台词映射
        thoughts: [],
        alias: alias,
        directoryPath: showDirPath,
      );

      // 保存电视剧信息
      await _dataService.saveTvShow(newShow);

      // 重新加载电视剧列表
      await loadTvShows();

      return newShow;
    } catch (e) {
      print("Error creating new TV show: $e");
      _error = "创建新电视剧失败: $e";
      notifyListeners();
      rethrow; // 重新抛出异常以便上层处理
    }
  }

  /// Finds a TvShow by its name. Returns null if not found.
  TvShow? findTvShowByName(String name) {
    try {
      return _tvShows.firstWhere((show) => show.name == name);
    } catch (e) {
      return null; // Not found
    }
  }

  /// Selects a random TV show and quote for the HomeScreen display.
  void selectRandomHomeScreenShow() {
    if (_tvShows.isNotEmpty) {
      final random = Random();
      final previousShowName =
          _currentHomeScreenShow?.name; // Keep track of previous show name
      TvShow selectedShow;

      // Try not to select the same show twice in a row if possible
      if (_tvShows.length > 1 && previousShowName != null) {
        List<TvShow> eligibleShows =
            _tvShows.where((s) => s.name != previousShowName).toList();
        // If all shows are the same (unlikely but possible), fall back to any show
        if (eligibleShows.isEmpty) eligibleShows = _tvShows;
        final randomIndex = random.nextInt(eligibleShows.length);
        selectedShow = eligibleShows[randomIndex];
      } else {
        // If only one show or no previous show, select from all
        final randomIndex = random.nextInt(_tvShows.length);
        selectedShow = _tvShows[randomIndex];
      }

      String? selectedQuote;
      if (selectedShow.lines.isNotEmpty) {
        final quoteIndex = random.nextInt(selectedShow.lines.length);
        selectedQuote = selectedShow.lines[quoteIndex];
      }

      bool showChanged = _currentHomeScreenShow?.name != selectedShow.name;
      _currentHomeScreenShow = selectedShow;
      _currentHomeScreenQuote = selectedQuote;

      // Set the flag only on the *first* successful selection
      if (!_initialHomeScreenShowSelected) {
        _initialHomeScreenShowSelected = true;
        print(
          "[TvShowNotifier] Initial HomeScreen show selected: ${selectedShow.name}",
        );
      } else {
        print(
          "[TvShowNotifier] Selected new HomeScreen show: ${selectedShow.name}",
        );
      }

      // Notify listeners only if the show actually changed or if it's the initial selection
      if (showChanged || _initialHomeScreenShowSelected) {
        // Notify on first selection too
        notifyListeners();
      }
    } else {
      print(
        "[TvShowNotifier] Cannot select random home screen show, tvShows list is empty.",
      );
      if (_currentHomeScreenShow != null) {
        // Clear if list becomes empty
        _currentHomeScreenShow = null;
        _currentHomeScreenQuote = null;
        _initialHomeScreenShowSelected = false; // Reset flag if list is empty
        notifyListeners();
      }
    }
  }

  /// Sets the current HomeScreen show and quote based on a show name.
  /// Used for restoring state.
  void setCurrentHomeScreenShowByName(String name) {
    final TvShow? show = findTvShowByName(name);
    if (show != null) {
      String? selectedQuote;
      if (show.lines.isNotEmpty) {
        final random = Random();
        final quoteIndex = random.nextInt(show.lines.length);
        selectedQuote = show.lines[quoteIndex];
      }

      bool showChanged = _currentHomeScreenShow?.name != show.name;
      _currentHomeScreenShow = show;
      _currentHomeScreenQuote = selectedQuote;

      // Mark initial selection as done if we successfully restore a show
      if (!_initialHomeScreenShowSelected) {
        _initialHomeScreenShowSelected = true;
        print("[TvShowNotifier] Restored HomeScreen show: ${show.name}");
      } else {
        print("[TvShowNotifier] Set HomeScreen show by name: ${show.name}");
      }

      // Notify listeners if the show changed
      if (showChanged) {
        notifyListeners();
      }
    } else {
      print(
        "[TvShowNotifier] Could not find show '$name' to set for HomeScreen.",
      );
      // Optionally select a random one if the saved one isn't found?
      // selectRandomHomeScreenShow();
    }
  }

  /// Notifies listeners that settings potentially affecting HomeScreen might have changed.
  void notifySettingsChanged() {
    print("[TvShowNotifier] Settings changed notification triggered.");
    // Increment the value to signal a change. Listeners will react to this.
    _settingsChangeNotifier.value++;
    // We might not need the general notifyListeners() here anymore for this specific purpose,
    // but let's keep it for now in case other parts rely on it.
    // Consider removing if only the timer needs to react.
    notifyListeners();
  }
}
