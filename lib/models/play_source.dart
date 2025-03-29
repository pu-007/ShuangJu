// ignore_for_file: avoid_print, unintended_html_in_doc_comment

import 'package:json_annotation/json_annotation.dart';

part 'play_source.g.dart'; // Generated part file

@JsonSerializable()
class PlaySource {
  /// 播放源名称 (例如: "[信息]TMDB", "[在线]爱壹帆")
  final String name;
  /// 播放源 URL 模板 (包含占位符如 {name}, {tmdb_id}, {media_type})
  final String urlTemplate;

  PlaySource({
    required this.name,
    required this.urlTemplate,
  });

  /// 从 JSON map 创建 PlaySource 实例
  /// 注意: 在实际加载 sources.json 时, key 是 name, value 是 urlTemplate
  /// 这个 fromJson 主要用于可能的列表存储场景, 但标准用法是直接从 Map<String, String> 构建
  factory PlaySource.fromJson(Map<String, dynamic> json) => _$PlaySourceFromJson(json);

  /// 将 PlaySource 实例转换为 JSON map
  /// 注意: 标准用法是构建 Map<String, String> 而不是 List<Map>
  Map<String, dynamic> toJson() => _$PlaySourceToJson(this);

  /// 根据电视剧信息生成实际可播放的 URL
  String getUrlForTvShow({
    required String tvShowName,
    int? tmdbId,
    String? mediaType,
  }) {
    String url = urlTemplate;
    url = url.replaceAll('{name}', Uri.encodeComponent(tvShowName)); // URL编码剧名
    if (tmdbId != null) {
      url = url.replaceAll('{tmdb_id}', tmdbId.toString());
    }
    if (mediaType != null) {
      url = url.replaceAll('{media_type}', mediaType);
    }
    // 如果模板中还有未替换的占位符 (例如 tmdb_id 或 media_type 为 null),
    // 可能需要返回 null 或空字符串来表示无法生成有效 URL
    if (url.contains('{tmdb_id}') || url.contains('{media_type}')) {
       // 或者可以抛出异常, 或返回一个默认搜索页等
       print("Warning: Could not fully replace placeholders for source '$name' and show '$tvShowName'. URL: $url");
       // 尝试返回一个基础搜索链接 (如果适用)
       if (name.contains("豆瓣") || name.contains("TMDB")) {
         // 对于信息源, 即使没有 ID 也可以尝试搜索
       } else if (urlTemplate.contains("{name}")) {
         // 对于播放源, 如果只依赖 name, 仍然可以尝试
       }
       else {
         return ''; // 表示无法生成有效播放链接
       }
    }
    return url;
  }


  @override
  String toString() {
    return 'PlaySource(name: $name, urlTemplate: $urlTemplate)';
  }
}