// ignore_for_file: non_constant_identifier_names

import 'package:json_annotation/json_annotation.dart';
import 'progress.dart'; // 引入 Progress 模型

part 'tv_show.g.dart'; // Generated part file

@JsonSerializable(
  explicitToJson: true,
) // explicitToJson needed for nested Progress object
class TvShow {
  /// 电视剧名称 (也是文件夹名称)
  final String name;

  /// TMDB ID (可选)
  final int? tmdb_id;

  /// 简介
  final String overview;

  /// 观看进度
  final Progress progress;

  /// 是否收藏
  final bool favorite;

  /// 著名台词列表
  final List<String> lines;

  /// 带内嵌台词的剧照 (文件名 -> 台词)
  final Map<String, String> inline_lines;

  /// 类型 (例如: "movie", "tv")
  final String media_type;

  /// 个人想法列表
  final List<String> thoughts;

  /// 别名 (可选)
  final String? alias;

  // --- 非 JSON 字段 ---
  /// 电视剧数据在文件系统中的路径 (用于后续加载图片/音乐)
  /// 这个字段不由 JSON 提供, 而是在加载时由 DataService 设置。
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? directoryPath; // Made nullable

  TvShow({
    required this.name,
    this.tmdb_id,
    required this.overview,
    required this.progress,
    required this.favorite,
    required this.lines,
    required this.inline_lines,
    required this.media_type,
    required this.thoughts,
    this.alias,
    this.directoryPath, // Removed required, now optional
  });

  /// 从 JSON map 创建 TvShow 实例
  /// 注意: directoryPath 需要在调用此工厂方法后手动设置或通过特定加载逻辑传入
  factory TvShow.fromJson(Map<String, dynamic> json) => _$TvShowFromJson(json);

  /// 将 TvShow 实例转换为 JSON map
  Map<String, dynamic> toJson() => _$TvShowToJson(this);

  /// 创建一个包含更新后信息的新 TvShow 实例
  TvShow copyWith({
    String? name,
    int? tmdb_id,
    String? overview,
    Progress? progress,
    bool? favorite,
    List<String>? lines,
    Map<String, String>? inline_lines,
    String? media_type,
    List<String>? thoughts,
    String? alias,
    String? directoryPath,
  }) {
    return TvShow(
      name: name ?? this.name,
      tmdb_id: tmdb_id ?? this.tmdb_id,
      overview: overview ?? this.overview,
      progress: progress ?? this.progress,
      favorite: favorite ?? this.favorite,
      lines: lines ?? this.lines,
      inline_lines: inline_lines ?? this.inline_lines,
      media_type: media_type ?? this.media_type,
      thoughts: thoughts ?? this.thoughts,
      alias: alias ?? this.alias,
      directoryPath: directoryPath ?? this.directoryPath,
    );
  }

  /// 获取封面图片路径
  /// Assumes directoryPath is non-null when called.
  String get coverImagePath => '$directoryPath/cover.jpg';

  /// 获取主题曲路径
  /// Assumes directoryPath is non-null when called.
  String get themeSongPath => '$directoryPath/themesong.mp3'; // 使用确认后的正确文件名

  @override
  String toString() {
    return 'TvShow(name: $name, favorite: $favorite, progress: $progress)';
  }
}
