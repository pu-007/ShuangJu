import 'package:json_annotation/json_annotation.dart';

part 'progress.g.dart'; // Generated part file

@JsonSerializable()
class Progress {
  /// 当前观看进度 (例如: 集数, 百分比的小数形式等)
  final num current;
  /// 总进度 (例如: 总集数, 1.0 代表 100% 等)
  final num total;

  Progress({
    required this.current,
    required this.total,
  });

  /// 从 JSON map 创建 Progress 实例
  factory Progress.fromJson(Map<String, dynamic> json) => _$ProgressFromJson(json);

  /// 将 Progress 实例转换为 JSON map
  Map<String, dynamic> toJson() => _$ProgressToJson(this);

  /// 计算进度的百分比 (0.0 to 1.0)
  double get percentage {
    if (total <= 0) {
      return 0.0;
    }
    // 确保 current 不超过 total
    final cappedCurrent = current.clamp(0, total);
    return cappedCurrent / total;
  }

  /// 创建一个进度更新后的新 Progress 实例
  Progress copyWith({ // Corrected method name
    num? current,
    num? total,
  }) {
    return Progress(
      current: current ?? this.current,
      total: total ?? this.total,
    );
  }

  @override
  String toString() {
    return 'Progress(current: $current, total: $total)';
  }
}