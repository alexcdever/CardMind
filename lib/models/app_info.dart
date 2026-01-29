/// 应用信息模型
class AppInfo {
  /// 应用版本号
  final String version;

  /// 构建号
  final String buildNumber;

  /// 应用描述
  final String description;

  /// 项目主页 URL
  final String homepage;

  /// 问题反馈 URL
  final String issuesUrl;

  /// 贡献者列表
  final List<String> contributors;

  /// 更新日志
  final List<ChangelogEntry> changelog;

  const AppInfo({
    required this.version,
    required this.buildNumber,
    required this.description,
    required this.homepage,
    required this.issuesUrl,
    required this.contributors,
    required this.changelog,
  });

  /// 创建默认的应用信息
  factory AppInfo.defaultInfo() {
    return const AppInfo(
      version: '0.1.0',
      buildNumber: '1',
      description: 'CardMind - A spaced repetition learning app',
      homepage: 'https://github.com/yourusername/cardmind',
      issuesUrl: 'https://github.com/yourusername/cardmind/issues',
      contributors: ['CardMind Team'],
      changelog: [
        ChangelogEntry(
          version: '0.1.0',
          date: '2026-01-29',
          changes: [
            'Initial release',
            'Basic card management',
            'Spaced repetition algorithm',
          ],
        ),
      ],
    );
  }

  /// 从 JSON 创建
  factory AppInfo.fromJson(Map<String, dynamic> json) {
    return AppInfo(
      version: json['version'] as String? ?? '0.0.0',
      buildNumber: json['buildNumber'] as String? ?? '0',
      description: json['description'] as String? ?? '',
      homepage: json['homepage'] as String? ?? '',
      issuesUrl: json['issuesUrl'] as String? ?? '',
      contributors: (json['contributors'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      changelog: (json['changelog'] as List<dynamic>?)
              ?.map((e) => ChangelogEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'buildNumber': buildNumber,
      'description': description,
      'homepage': homepage,
      'issuesUrl': issuesUrl,
      'contributors': contributors,
      'changelog': changelog.map((e) => e.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppInfo &&
        other.version == version &&
        other.buildNumber == buildNumber &&
        other.description == description &&
        other.homepage == homepage &&
        other.issuesUrl == issuesUrl &&
        _listEquals(other.contributors, contributors) &&
        _listEquals(other.changelog, changelog);
  }

  @override
  int get hashCode {
    return Object.hash(
      version,
      buildNumber,
      description,
      homepage,
      issuesUrl,
      Object.hashAll(contributors),
      Object.hashAll(changelog),
    );
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// 更新日志条目
class ChangelogEntry {
  /// 版本号
  final String version;

  /// 发布日期
  final String date;

  /// 变更列表
  final List<String> changes;

  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.changes,
  });

  /// 从 JSON 创建
  factory ChangelogEntry.fromJson(Map<String, dynamic> json) {
    return ChangelogEntry(
      version: json['version'] as String? ?? '',
      date: json['date'] as String? ?? '',
      changes: (json['changes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'date': date,
      'changes': changes,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChangelogEntry &&
        other.version == version &&
        other.date == date &&
        _listEquals(other.changes, changes);
  }

  @override
  int get hashCode {
    return Object.hash(
      version,
      date,
      Object.hashAll(changes),
    );
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
