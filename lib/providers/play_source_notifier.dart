// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import '../models/play_source.dart';
import '../services/data_service.dart';

class PlaySourceNotifier extends ChangeNotifier {
  final DataService _dataService;

  List<PlaySource> _sources = [];
  bool _isLoading = false;
  String? _error;

  PlaySourceNotifier(this._dataService) {
    loadPlaySources(); // Load immediately
  }

  // --- Getters ---
  List<PlaySource> get sources => _sources;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // --- Methods ---
  Future<void> loadPlaySources() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Initialization is handled by DataService internally now
      _sources = await _dataService.loadPlaySources();
      _isLoading = false;
      print("[PlaySourceNotifier] Sources loaded successfully: ${_sources.length} sources.");
    } catch (e) {
      print("[PlaySourceNotifier] Error loading play sources: $e");
      _error = "加载播放源失败: $e";
      _isLoading = false;
    } finally {
      notifyListeners();
    }
  }

  /// Reloads play sources from the DataService.
  Future<void> reloadPlaySources() async {
     print("[PlaySourceNotifier] Reloading play sources...");
     // Simply call the existing load method which handles state updates
     await loadPlaySources();
  }

  // Add methods for adding/editing/deleting sources if needed later
  // For now, focus is on loading and using them.
  Future<void> saveSources(List<PlaySource> updatedSources) async {
     // Show loading indicator maybe?
    try {
      await _dataService.savePlaySources(updatedSources);
      _sources = updatedSources; // Update local state
       print("[PlaySourceNotifier] Sources saved successfully.");
       notifyListeners();
      // Show success message
    } catch (e) {
       print("[PlaySourceNotifier] Error saving play sources: $e");
       _error = "保存播放源失败: $e";
       notifyListeners();
      // Show error message
    }
  }
}