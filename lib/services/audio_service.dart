import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; // For ChangeNotifier
import 'package:audioplayers/audioplayers.dart';
import 'package:shuang_ju/models/tv_show.dart'; // Assuming TvShow model exists

class AudioService extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateChangeSubscription;

  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  TvShow? _currentShow; // Track the show whose theme is playing
  String? _currentTrackPath; // Track the path of the currently loaded track

  // --- Getters for UI ---
  PlayerState get playerState => _playerState;
  Duration get duration => _duration;
  Duration get position => _position;
  TvShow? get currentShow => _currentShow;
  bool get isPlaying => _playerState == PlayerState.playing;
  bool get isPaused => _playerState == PlayerState.paused;
  bool get isStopped => _playerState == PlayerState.stopped || _playerState == PlayerState.completed;


  AudioService() {
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    // Listen to player state changes
    _playerStateChangeSubscription = _audioPlayer.onPlayerStateChanged.listen(
      (state) {
        _playerState = state;
        if (state == PlayerState.stopped || state == PlayerState.completed) {
          // Reset position when stopped or completed naturally
          _position = Duration.zero;
           // Optionally clear current show when stopped manually or completed
           // if (state == PlayerState.stopped) {
           //   _currentShow = null;
           //   _currentTrackPath = null;
           // }
        }
        notifyListeners();
      },
      onError: (msg) {
        // Handle errors, perhaps log them or show a message
        print('Audio Player Error: $msg');
        _playerState = PlayerState.stopped;
        _currentShow = null;
        _currentTrackPath = null;
        _duration = Duration.zero;
        _position = Duration.zero;
        notifyListeners();
      },
    );

    // Listen to duration changes
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      // Sometimes duration reported can be 0 initially, handle this
      if (duration > Duration.zero) {
         _duration = duration;
         notifyListeners();
      }
    });

    // Listen to position changes
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      _position = position;
      notifyListeners();
    });

    // Listen to player completion
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      _playerState = PlayerState.completed; // Explicitly set to completed
      _position = _duration; // Set position to end
      // Consider options: stop, loop, play next? For now, just stop.
      // _currentShow = null; // Clear show on completion? Optional.
      // _currentTrackPath = null;
      notifyListeners();
    });

    // Optional: Configure player settings if needed
    // _audioPlayer.setReleaseMode(ReleaseMode.stop); // Stop on completion (default)
  }

  Future<void> playThemeSong(TvShow show) async {
    if (show.directoryPath == null) {
      print("Error: Directory path is null for ${show.name}");
      return; // Or throw an error
    }
    final themeSongPath = show.themeSongPath;
    final themeSongFile = File(themeSongPath);

    if (!await themeSongFile.exists()) {
      print("Error: Theme song file not found: $themeSongPath");
      return; // Or throw an error
    }

    // Stop current playback if it's a different track
    if (_currentTrackPath != themeSongPath && !isStopped) {
       await stop();
    }

    try {
      // Set the source and play
      await _audioPlayer.setSource(DeviceFileSource(themeSongFile.path));
      await _audioPlayer.resume(); // Use resume to start playing

      _currentShow = show;
      _currentTrackPath = themeSongPath;
      _playerState = PlayerState.playing; // Manually set state initially
      // Reset position/duration for new track display before listeners update
      _position = Duration.zero;
      // Duration might take a moment to update via listener, setting to zero initially
      // Let the listener handle the actual duration when available.
      // _duration = Duration.zero;
      notifyListeners(); // Notify immediately for UI update

    } catch (e) {
      print("Error playing theme song for ${show.name}: $e");
      _playerState = PlayerState.stopped;
      _currentShow = null;
      _currentTrackPath = null;
      notifyListeners();
      // Optionally rethrow or handle the error more gracefully
    }
  }

  Future<void> pause() async {
    if (isPlaying) {
      await _audioPlayer.pause();
      _playerState = PlayerState.paused;
      notifyListeners();
    }
  }

  Future<void> resume() async {
    // Resume only if paused or stopped/completed with a valid track loaded
    if ((isPaused || isStopped) && _currentTrackPath != null) {
       // If completed, seek to beginning before resuming
       if (_playerState == PlayerState.completed) {
          await seek(Duration.zero);
       }
       await _audioPlayer.resume();
       _playerState = PlayerState.playing;
       notifyListeners();
    } else if (isStopped && _currentTrackPath == null && _currentShow != null) {
       // If stopped and no track path but we have a show, try playing it again
       await playThemeSong(_currentShow!);
    }
  }

  Future<void> stop() async {
    if (!isStopped) {
      await _audioPlayer.stop();
      _playerState = PlayerState.stopped;
      _position = Duration.zero; // Reset position on stop
      // Keep duration so slider might still be visible but at start
      // _duration = Duration.zero; // Optionally reset duration too
      _currentShow = null; // Clear show on stop
      _currentTrackPath = null; // Clear track path
      notifyListeners();
    }
  }

  Future<void> seek(Duration position) async {
    // Allow seeking even if stopped, but only if a track is loaded
    if (_currentTrackPath != null) {
       // Clamp position to valid range
       final seekPosition = position.isNegative
           ? Duration.zero
           : (position > _duration ? _duration : position);
       await _audioPlayer.seek(seekPosition);
       _position = seekPosition; // Update position immediately for UI responsiveness
       notifyListeners();
    }
  }

  // Override dispose to cancel subscriptions and release player
  @override
  void dispose() {
    print("Disposing AudioService...");
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateChangeSubscription?.cancel();
    _audioPlayer.dispose(); // Release the player resources
    super.dispose();
  }
}