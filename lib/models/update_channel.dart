enum UpdateChannel {
  stable(
    'stable',
    '正式版',
    '只接收稳定发布版本',
    'https://github.com/alexcdever/CardMind/releases/download/channel-stable/stable.json',
  ),
  beta(
    'beta',
    '测试版',
    '提前获取测试版本，可能包含未完成或不稳定功能',
    'https://github.com/alexcdever/CardMind/releases/download/channel-beta/beta.json',
  );

  const UpdateChannel(
    this.value,
    this.label,
    this.description,
    this.manifestUrl,
  );

  final String value;
  final String label;
  final String description;
  final String manifestUrl;

  static UpdateChannel fromValue(Object? value) => values.firstWhere(
    (channel) => channel.value == value,
    orElse: () => UpdateChannel.stable,
  );
}
