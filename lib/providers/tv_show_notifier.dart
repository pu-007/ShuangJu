// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart'; // For ChangeNotifier
import '../models/tv_show.dart';
import '../services/data_service.dart';

class TvShowNotifier extends ChangeNotifier {
  final DataService _dataService;

  List<TvShow> _tvShows = [];
  bool _isLoading = false;
  String? _error;

  TvShowNotifier(this._dataService) {
    // Optionally load data immediately upon creation
    // loadTvShows();
  }

  // --- Getters ---
  List<TvShow> get tvShows => _tvShows;
  List<TvShow> get favoriteTvShows => _tvShows.where((show) => show.favorite).toList();
  List<TvShow> get nonFavoriteTvShows => _tvShows.where((show) => !show.favorite).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

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
      print("[TvShowNotifier] TvShows loaded successfully: ${_tvShows.length} shows."); // Added Log Tag
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
  Future<void> updateTvShow(TvShow updatedShow) async {
     final index = _tvShows.indexWhere((show) => show.name == updatedShow.name);
     if (index != -1) {
        // Save to persistence first
        try {
           await _dataService.saveTvShow(updatedShow);
           // Update in-memory list only after successful save
           _tvShows[index] = updatedShow;
           // Re-sort if favorite status changed
           if (_tvShows[index].favorite != updatedShow.favorite) {
              _tvShows.sort((a, b) {
                 if (a.favorite != b.favorite) {
                   return b.favorite ? 1 : -1;
                 }
                 return a.name.compareTo(b.name);
              });
           }
           print("TvShow updated successfully: ${updatedShow.name}");
           notifyListeners(); // Notify UI about the change
        } catch (e) {
           print("Error saving updated TvShow ${updatedShow.name}: $e");
           _error = "保存 '${updatedShow.name}' 更新失败: $e";
           notifyListeners(); // Notify UI about the error
           // Optionally revert the change in UI or handle differently
        }
     } else {
        print("Error: Could not find TvShow ${updatedShow.name} to update.");
        _error = "找不到要更新的电视剧: ${updatedShow.name}";
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
     final updatedProgress = show.progress.copyWith(current: current, total: total);
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

   /// Finds a TvShow by its name. Returns null if not found.
   TvShow? findTvShowByName(String name) {
      try {
        return _tvShows.firstWhere((show) => show.name == name);
      } catch (e) {
        return null; // Not found
      }
   }

}