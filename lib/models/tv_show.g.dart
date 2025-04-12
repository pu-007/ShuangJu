// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tv_show.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TvShow _$TvShowFromJson(Map<String, dynamic> json) => TvShow(
  name: json['name'] as String,
  tmdb_id: (json['tmdb_id'] as num?)?.toInt(),
  overview: json['overview'] as String,
  progress: Progress.fromJson(json['progress'] as Map<String, dynamic>),
  favorite: json['favorite'] as bool,
  lines: (json['lines'] as List<dynamic>).map((e) => e as String).toList(),
  inline_lines: Map<String, String>.from(json['inline_lines'] as Map),
  media_type: json['media_type'] as String,
  thoughts:
      (json['thoughts'] as List<dynamic>).map((e) => e as String).toList(),
  alias: json['alias'] as String?,
);

Map<String, dynamic> _$TvShowToJson(TvShow instance) => <String, dynamic>{
  'name': instance.name,
  'tmdb_id': instance.tmdb_id,
  'overview': instance.overview,
  'progress': instance.progress.toJson(),
  'favorite': instance.favorite,
  'lines': instance.lines,
  'inline_lines': instance.inline_lines,
  'media_type': instance.media_type,
  'thoughts': instance.thoughts,
  'alias': instance.alias,
};
