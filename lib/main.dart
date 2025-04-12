import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:shuang_ju/providers/play_source_notifier.dart'; // Import PlaySourceNotifier
import 'package:shuang_ju/providers/tv_show_notifier.dart'; // Import Notifier
import 'package:shuang_ju/services/data_service.dart'; // Import Service
import 'package:shuang_ju/services/audio_service.dart'; // Import AudioService
// Import the main screen widget
import 'package:shuang_ju/screens/main_screen.dart'; // Uncommented import

void main() async {
  // Make main async
  // Ensure Flutter bindings are initialized before using async/await
  WidgetsFlutterBinding.ensureInitialized();

  // Create DataService instance
  final dataService = DataService();
  // Initialize data (copy/extract assets if needed) before running the app
  // Consider showing a splash screen while this happens in a real app
  await dataService.initializeDataIfNeeded(); // Corrected method name back

  runApp(
    // Use MultiProvider to provide multiple notifiers
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => TvShowNotifier(dataService)..loadTvShows(),
        ),
        ChangeNotifierProvider(
          create: (context) => PlaySourceNotifier(dataService), // Provide PlaySourceNotifier
        ),
        // Provider for managing Audio Playback globally
        ChangeNotifierProvider(create: (_) => AudioService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShuangJu - 爽剧', // Update app title
      theme: ThemeData(
        // Define a base theme
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.pinkAccent, // Choose a seed color
          brightness: Brightness.light, // Or Brightness.dark
        ),
        useMaterial3: true, // Enable Material 3
        // Customize further theme elements here (appBarTheme, textTheme, etc.)
        appBarTheme: const AppBarTheme(
          elevation: 1, // Subtle shadow
          centerTitle: true,
        ),
      ),
      // Set the actual main screen containing bottom navigation
      // home: const PlaceholderMainScreen(), // Removed placeholder
      home: const MainScreen(), // Use the actual MainScreen
      debugShowCheckedModeBanner: false, // Hide debug banner
    );
  }
}

// Removed the PlaceholderMainScreen class as it's no longer needed.
// The old MyHomePage and _MyHomePageState classes were removed previously.
