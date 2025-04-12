// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart'
    show ByteData, rootBundle; // Keep for sources.json
import 'package:path_provider/path_provider.dart'; // Reverted alias
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart'; // Re-import archive package
// Removed: import 'package:gbk_codec/gbk_codec.dart';
// Removed: import 'package:permission_handler/permission_handler.dart';

import '../models/tv_show.dart';
import '../models/play_source.dart';

class DataService {
  // --- Paths ---

  Future<String> _getAppDirectoryPath() async {
    // Internal documents directory (used for sources.json)
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // --- NEW: Path for tv_shows in app-specific EXTERNAL files directory ---
  Future<String> _getWritableTvShowsPath() async {
    // Use getExternalStorageDirectories (plural 'Storage') to get a list of potential directories
    // This directory is automatically managed by the OS (cleared on uninstall)
    // and doesn't require special permissions on most Android versions.
    final List<Directory>? directories =
        await getExternalStorageDirectories(); // Call without arguments
    if (directories == null || directories.isEmpty) {
      throw Exception("无法获取应用专属外部存储目录列表。");
    }
    // Use the first directory in the list (usually the primary external storage)
    final Directory directory = directories.first;
    final tvShowsPath = p.join(directory.path, 'tv_shows');
    // Ensure the directory exists (will be created during extraction if needed)
    await Directory(tvShowsPath).create(recursive: true);
    print(
      "[DataService] Target writable tv_shows path (external files): $tvShowsPath",
    );
    return tvShowsPath;
  }

  // 公开方法，用于获取电视剧目录路径
  Future<String> getTvShowsPath() async {
    return _getWritableTvShowsPath();
  }

  // Path for editable sources.json (internal storage - unchanged)
  Future<String> _getWritableSourcesPath() async {
    final appDirPath = await _getAppDirectoryPath();
    return p.join(appDirPath, 'sources.json');
  }

  // --- REMOVED: _getExternalTvShowsPath ---
  // --- REMOVED: _requestStoragePermission ---

  // --- Initialization (Checks both sources.json and tv_shows dir) ---
  Future<void> initializeDataIfNeeded() async {
    final writableSourcesPath = await _getWritableSourcesPath();
    final writableTvShowsPath =
        await _getWritableTvShowsPath(); // Use new external files path
    final sourcesFile = File(writableSourcesPath);
    final tvShowsDir = Directory(writableTvShowsPath);

    bool sourcesExist = await sourcesFile.exists();
    bool tvShowsExist = await tvShowsDir.exists();
    // Check if tvShowsDir is empty *after* ensuring it exists
    bool tvShowsIsEmpty = tvShowsExist ? await tvShowsDir.list().isEmpty : true;

    // Initialize if sources.json doesn't exist OR tv_shows dir doesn't exist OR tv_shows dir is empty
    if (!sourcesExist || !tvShowsExist || tvShowsIsEmpty) {
      if (!sourcesExist) {
        print("[DataService] Writable sources.json (internal) not found.");
      }
      if (!tvShowsExist) {
        print(
          "[DataService] Writable tv_shows directory (external files) not found.",
        );
      }
      if (tvShowsExist && tvShowsIsEmpty) {
        print(
          "[DataService] Writable tv_shows directory (external files) is empty.",
        );
      }
      print("[DataService] Initializing data from assets...");
      await _copyAssetsToWritableDir(); // This copies sources and extracts zip
      print("[DataService] Data initialization complete.");
    } else {
      print(
        "[DataService] Writable sources.json and non-empty tv_shows directory found. Skipping initialization.",
      );
    }
  }

  /// Copies sources.json and extracts tv_shows_archive.zip from assets to the writable directories.
  Future<void> _copyAssetsToWritableDir() async {
    final writableSourcesPath = await _getWritableSourcesPath(); // Internal
    final writableTvShowsPath =
        await _getWritableTvShowsPath(); // External Files Dir
    print("[DataService] Starting asset copy/extraction...");
    print("[DataService]   Sources target: $writableSourcesPath");
    print("[DataService]   TV Shows target: $writableTvShowsPath");

    // 1. Copy sources.json to internal storage
    try {
      final byteData = await rootBundle.load('assets/sources.json');
      await File(
        writableSourcesPath,
      ).writeAsBytes(byteData.buffer.asUint8List());
      print("[DataService] Copied sources.json");
    } catch (e) {
      print("Error copying sources.json: $e");
    }

    // 2. Extract tv_shows_archive.zip to app-specific external files directory
    try {
      print("[DataService] Loading tv_shows_archive.zip...");
      final ByteData data = await rootBundle.load(
        'assets/tv_shows_archive.zip',
      );
      final List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      print("[DataService] Decoding zip archive..."); // Reverted log
      // Reverted call - assuming UTF-8 filenames in zip
      final archive = ZipDecoder().decodeBytes(bytes);
      print("[DataService] Zip decoded. Found ${archive.length} files/dirs.");

      // Ensure the base extraction directory exists (redundant but safe)
      await Directory(writableTvShowsPath).create(recursive: true);

      int extractedCount = 0;
      for (final file in archive) {
        final filename = file.name;
        // IMPORTANT: Ensure extracted path is within the target directory
        final destinationPath = p.join(writableTvShowsPath, filename);
        // Basic security check (optional but recommended)
        if (!p.isWithin(writableTvShowsPath, destinationPath)) {
          print(
            "Warning: Skipping potentially unsafe path during extraction: $filename",
          );
          continue;
        }

        if (file.isFile) {
          final fileData = file.content as List<int>;
          final parentDir = p.dirname(destinationPath);
          await Directory(parentDir).create(recursive: true);
          final outFile = File(destinationPath);
          await outFile.writeAsBytes(fileData);
          extractedCount++;
        } else {
          await Directory(destinationPath).create(recursive: true);
        }
      }
      print(
        "[DataService] Finished extracting $extractedCount files from zip archive to $writableTvShowsPath.",
      );
    } catch (e) {
      print("[DataService] Error extracting tv_shows_archive.zip: $e");
    }
  }

  // --- Data Loading ---

  // Load sources from internal storage (Unchanged)
  Future<List<PlaySource>> loadPlaySources() async {
    // Ensure sources.json exists internally (copied if needed)
    final path = await _getWritableSourcesPath();
    final file = File(path);
    if (!await file.exists()) {
      print("[DataService] sources.json missing, attempting initialization...");
      await initializeDataIfNeeded(); // This should copy sources.json
      if (!await file.exists()) {
        throw Exception(
          "Failed to load sources.json after initialization attempt.",
        );
      }
    }

    try {
      final jsonString = await file.readAsString();
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      final sources =
          jsonMap.entries.map((entry) {
            return PlaySource(
              name: entry.key,
              urlTemplate: entry.value as String,
            );
          }).toList();
      return sources;
    } catch (e) {
      print("Error loading play sources from $path: $e");
      return [];
    }
  }

  // Load TV Shows from app-specific external files directory
  Future<List<TvShow>> loadTvShows() async {
    // Ensure data is initialized (zip extracted if needed)
    await initializeDataIfNeeded();

    final tvShowsPath =
        await _getWritableTvShowsPath(); // Path in external files dir
    final tvShowsDir = Directory(tvShowsPath);
    final List<TvShow> tvShows = [];

    if (!await tvShowsDir.exists()) {
      // This shouldn't happen if initializeDataIfNeeded worked correctly
      print(
        "[DataService] Writable tv_shows directory (external files) not found at $tvShowsPath even after init check.",
      );
      throw Exception("无法加载电视剧数据：目标目录不存在。");
    }

    try {
      if (await tvShowsDir.list().isEmpty) {
        print(
          "[DataService] Writable tv_shows directory (external files) is empty at $tvShowsPath.",
        );
        return []; // Return empty list if nothing was extracted or present
      }

      final entities = tvShowsDir.listSync();
      for (final entity in entities) {
        if (entity is Directory) {
          final showDirPath = entity.path; // Path is now in external files dir
          final initJsonPath = p.join(showDirPath, 'init.json');
          final initJsonFile = File(initJsonPath);

          if (await initJsonFile.exists()) {
            try {
              final jsonString = await initJsonFile.readAsString();
              final Map<String, dynamic> jsonMap = json.decode(jsonString);
              final tvShow = TvShow.fromJson(jsonMap);
              // Set the correct directoryPath pointing to external files dir
              final tvShowWithDir = tvShow.copyWith(directoryPath: showDirPath);

              // --- Add check for cover and theme song ---
              final coverPath = tvShowWithDir.coverImagePath;
              final songPath = tvShowWithDir.themeSongPath;
              final coverExists = await File(coverPath).exists();
              final songExists = await File(songPath).exists();

              if (!coverExists) {
                print("Warning: Cover image not found at $coverPath");
              }
              if (!songExists) {
                print("Warning: Theme song not found at $songPath");
              }
              // --- End check ---

              tvShows.add(tvShowWithDir);
            } catch (e) {
              print("Error parsing init.json in $showDirPath: $e");
            }
          } else {
            print("Warning: init.json not found in $showDirPath");
          }
        }
      }
      print(
        "[DataService] Loaded ${tvShows.length} TV shows from $tvShowsPath",
      );
      return tvShows;
    } catch (e) {
      print(
        "[DataService] Error listing or processing tv_shows directory $tvShowsPath: $e",
      );
      throw Exception("读取电视剧数据时出错: $e");
    }
  }

  // --- Data Saving ---

  // Save TvShow back to app-specific external files directory
  Future<void> saveTvShow(TvShow tvShow) async {
    if (tvShow.directoryPath == null) {
      print("Error saving TvShow ${tvShow.name}: directoryPath is null.");
      return;
    }
    // Check if the path seems to be within an expected external files directory structure
    // This is a basic check and might need refinement
    if (!tvShow.directoryPath!.contains('/Android/data/') &&
        !tvShow.directoryPath!.contains('\\Android\\data\\') &&
        !tvShow.directoryPath!.contains('/files/tv_shows') &&
        !tvShow.directoryPath!.contains('\\files\\tv_shows')) {
      print(
        "Error saving TvShow ${tvShow.name}: directoryPath '${tvShow.directoryPath}' does not appear to be in the app-specific external files directory.",
      );
      return;
    }

    final initJsonPath = p.join(tvShow.directoryPath!, 'init.json');
    try {
      final jsonString = json.encode(tvShow.toJson());
      await File(initJsonPath).writeAsString(jsonString);
      print("Saved TvShow: ${tvShow.name} to $initJsonPath");
    } catch (e) {
      print("Error saving TvShow ${tvShow.name}: $e");
      throw Exception("保存电视剧数据失败: $e");
    }
  }
  
  // 删除电视剧
  Future<void> deleteTvShow(TvShow tvShow) async {
    if (tvShow.directoryPath == null) {
      print("Error deleting TvShow ${tvShow.name}: directoryPath is null.");
      throw Exception("无法删除电视剧：路径未知");
    }
    
    // 安全检查，确保路径在应用的特定目录中
    if (!tvShow.directoryPath!.contains('/Android/data/') &&
        !tvShow.directoryPath!.contains('\\Android\\data\\') &&
        !tvShow.directoryPath!.contains('/files/tv_shows') &&
        !tvShow.directoryPath!.contains('\\files\\tv_shows')) {
      print(
        "Error deleting TvShow ${tvShow.name}: directoryPath '${tvShow.directoryPath}' does not appear to be in the app-specific external files directory.",
      );
      throw Exception("无法删除电视剧：路径不在应用目录中");
    }
    
    try {
      final directory = Directory(tvShow.directoryPath!);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
        print("Deleted TvShow directory: ${tvShow.directoryPath}");
      } else {
        print("Warning: TvShow directory does not exist: ${tvShow.directoryPath}");
      }
    } catch (e) {
      print("Error deleting TvShow ${tvShow.name}: $e");
      throw Exception("删除电视剧数据失败: $e");
    }
  }

  // Save sources to internal storage (Unchanged)
  Future<void> savePlaySources(List<PlaySource> sources) async {
    final path = await _getWritableSourcesPath();
    try {
      final Map<String, String> jsonMap = {
        for (var source in sources) source.name: source.urlTemplate,
      };
      final jsonString = json.encode(jsonMap);
      await File(path).writeAsString(jsonString);
      print("Saved play sources.");
    } catch (e) {
      print("Error saving play sources to $path: $e");
    }
  }

  // --- Image Loading --- (Unchanged, uses directoryPath)
  Future<List<String>> getImagePathsForShow(TvShow tvShow) async {
    final List<String> imagePaths = [];
    if (tvShow.directoryPath == null) {
      print(
        "Error getting images for TvShow ${tvShow.name}: directoryPath is null.",
      );
      return imagePaths;
    }
    final showDir = Directory(tvShow.directoryPath!);
    if (!await showDir.exists()) return imagePaths;

    try {
      final entities = showDir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final filename = p.basename(entity.path);
          if (filename.endsWith('.jpg') ||
              filename.endsWith('.jpeg') ||
              filename.endsWith('.png')) {
            if (filename.toLowerCase() != 'cover.jpg') {
              imagePaths.add(entity.path);
            }
          }
        }
      }
      imagePaths.sort();
      return imagePaths;
    } catch (e) {
      print("Error listing images for ${tvShow.name}: $e");
      return [];
    }
  }
}
