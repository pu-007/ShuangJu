import 'package:flutter/material.dart';
import '../models/tv_show.dart';

class TvShowDetailScreen extends StatelessWidget {
  final TvShow tvShow;

  const TvShowDetailScreen({super.key, required this.tvShow});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tvShow.name),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
                Text('详情页: ${tvShow.name}', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 20),
                const Text('此处将显示简介、相册、进度管理等功能。'),
             ],
          ),
        ),
      ),
    );
  }
}