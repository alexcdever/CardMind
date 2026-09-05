import 'dart:io';

class UpdateAsset {
  const UpdateAsset({
    required this.artifact,
    required this.url,
    required this.sha256,
    required this.size,
  });

  final String artifact;
  final String url;
  final String sha256;
  final int size;
}

class UpdateManifest {
  const UpdateManifest({
    required this.schemaVersion,
    required this.appId,
    required this.channel,
    required this.version,
    required this.build,
    required this.publishedAt,
    required this.minimumSupportedVersion,
    required this.mandatory,
    required this.releaseNotes,
    required this.releasePage,
    required this.platforms,
  });

  static final _versionPattern = RegExp(
    r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );
  static final _sha256Pattern = RegExp(r'^[0-9a-fA-F]{64}$');

  final int schemaVersion;
  final String appId;
  final String channel;
  final String version;
  final int build;
  final String publishedAt;
  final String minimumSupportedVersion;
  final bool mandatory;
  final List<String> releaseNotes;
  final String releasePage;
  final Map<String, UpdateAsset> platforms;

  static String get currentPlatform => Platform.isWindows
      ? 'windows-x64'
      : Platform.isAndroid
      ? 'android'
      : 'linux-x64';

  UpdateAsset? get currentAsset => platforms[currentPlatform];

  static UpdateManifest? tryParse(
    Map<String, dynamic> json, {
    required String channel,
  }) {
    try {
      if ((channel != 'stable' && channel != 'beta') ||
          json['schemaVersion'] != 1 ||
          json['appId'] != 'com.cardmind.v2' ||
          json['channel'] != channel) {
        return null;
      }

      final version = json['version'];
      final build = json['build'];
      final publishedAt = json['publishedAt'];
      final minimumSupportedVersion = json['minimumSupportedVersion'];
      final mandatory = json['mandatory'];
      final rawNotes = json['releaseNotes'];
      final releasePage = json['releasePage'];
      if (version is! String ||
          !_versionPattern.hasMatch(version) ||
          build is! int ||
          build <= 0 ||
          publishedAt is! String ||
          publishedAt.isEmpty ||
          minimumSupportedVersion is! String ||
          !_versionPattern.hasMatch(minimumSupportedVersion) ||
          mandatory is! bool ||
          rawNotes is! List ||
          rawNotes.any((note) => note is! String) ||
          releasePage is! String ||
          !_isHttps(releasePage)) {
        return null;
      }

      final rawPlatforms = json['platforms'];
      if (rawPlatforms is! Map || rawPlatforms.isEmpty) return null;

      final platforms = <String, UpdateAsset>{};
      for (final entry in rawPlatforms.entries) {
        if (entry.key is! String || entry.value is! Map) return null;
        final value = entry.value as Map;
        final artifact = value['artifact'];
        final url = value['url'];
        final hash = value['sha256'];
        final size = value['size'];
        final channelManifestUrl = value['channelManifestUrl'];
        final expectedChannelManifestUrl =
            'https://github.com/alexcdever/CardMind/releases/download/'
            'channel-$channel/$channel.json';

        if (artifact is! String ||
            artifact.isEmpty ||
            url is! String ||
            !_isHttps(url) ||
            hash is! String ||
            !_sha256Pattern.hasMatch(hash) ||
            size is! int ||
            size <= 0 ||
            channelManifestUrl != expectedChannelManifestUrl) {
          return null;
        }
        platforms[entry.key as String] = UpdateAsset(
          artifact: artifact,
          url: url,
          sha256: hash,
          size: size,
        );
      }

      if (!platforms.containsKey(currentPlatform)) return null;
      return UpdateManifest(
        schemaVersion: 1,
        appId: 'com.cardmind.v2',
        channel: channel,
        version: version,
        build: build,
        publishedAt: publishedAt,
        minimumSupportedVersion: minimumSupportedVersion,
        mandatory: mandatory,
        releaseNotes: List<String>.from(rawNotes),
        releasePage: releasePage,
        platforms: platforms,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isHttps(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}
