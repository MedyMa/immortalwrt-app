enum DeviceKind {
  unknown,
  phone,
  tablet,
  laptop,
  desktop,
  tv,
  nas,
  console,
  printer,
  camera,
  router,
}

class DeviceIdentity {
  const DeviceIdentity(
    this.kind,
    this.brand,
    this.slug, {
    this.confirmedAlias = false,
    this.model,
  });
  final DeviceKind kind;
  final String? brand;
  final String? slug;
  final bool confirmedAlias;
  final String? model;
  String get evidence => confirmedAlias
      ? '用户确认的名称映射'
      : kind == DeviceKind.unknown && brand == null
      ? '名称不足以识别'
      : '根据设备名称推断';

  String get typeLabel => switch (kind) {
    DeviceKind.unknown => '设备',
    DeviceKind.phone => '手机',
    DeviceKind.tablet => '平板',
    DeviceKind.laptop => '笔记本',
    DeviceKind.desktop => '电脑',
    DeviceKind.tv => '电视',
    DeviceKind.nas => 'NAS',
    DeviceKind.console => '游戏主机',
    DeviceKind.printer => '打印机',
    DeviceKind.camera => '摄像头',
    DeviceKind.router => '路由器',
  };

  String get label => brand == null
      ? typeLabel
      : '$brand${model == null ? '' : ' $model'} · $typeLabel';

  factory DeviceIdentity.fromName(String name) {
    if (name.trim().toLowerCase() == 'xiaoqiang') {
      return const DeviceIdentity(
        DeviceKind.router,
        '小米',
        'xiaomi',
        confirmedAlias: true,
        model: 'AX9000',
      );
    }
    final value = name.toLowerCase();
    bool has(String expression) => RegExp(
      '(?:^|[^a-z0-9])(?:$expression)(?=\u0024|[^a-z0-9])',
    ).hasMatch(value);
    String? brand;
    String? slug;
    if (has(r'apple|iphone\d*|ipad\d*|macbook|imac|mac|apple[ -]?tv')) {
      brand = 'Apple';
      slug = 'apple';
    } else if (has(r'google|pixel\d*')) {
      brand = 'Google';
      slug = 'google';
    } else if (has(r'huawei|华为')) {
      brand = 'Huawei';
      slug = 'huawei';
    } else if (has(r'xiaomi|redmi\d*|小米|红米')) {
      brand = 'Xiaomi';
      slug = 'xiaomi';
    } else if (has(r'samsung|galaxy|三星|z[ -]?(?:flip|fold)\d*')) {
      brand = 'Samsung';
      slug = 'samsung';
    } else if (has(r'synology|群晖')) {
      brand = 'Synology';
      slug = 'synology';
    } else if (has(r'playstation[ -]?\d*|ps[345]')) {
      brand = 'PlayStation';
      slug = 'playstation';
    } else if (has(r'nintendo|任天堂')) {
      brand = 'Nintendo';
      slug = 'nintendo';
    } else if (has(r'dell|戴尔')) {
      brand = 'Dell';
      slug = 'dell';
    } else if (has(r'lenovo|thinkpad|联想')) {
      brand = 'Lenovo';
      slug = 'lenovo';
    } else if (has(r'asus|华硕')) {
      brand = 'ASUS';
      slug = 'asus';
    } else if (has(r'hp|惠普')) {
      brand = 'HP';
      slug = 'hp';
    }
    final kind = switch (value) {
      _ when has(r'ipad\d*|tablet|平板') => DeviceKind.tablet,
      _ when has(r'tv|television|电视|apple[ -]?tv') => DeviceKind.tv,
      _ when has(r'macbook|laptop|thinkpad|笔记本') => DeviceKind.laptop,
      _ when has(r'iphone\d*|pixel\d*|phone|手机|z[ -]?(?:flip|fold)\d*') =>
        DeviceKind.phone,
      _ when has(r'nas|synology|群晖') => DeviceKind.nas,
      _ when has(r'playstation[ -]?\d*|ps[345]|nintendo[ -]?switch|游戏主机') =>
        DeviceKind.console,
      _ when has(r'printer|打印机') => DeviceKind.printer,
      _ when has(r'camera|摄像头') => DeviceKind.camera,
      _ when has(r'router|路由器') => DeviceKind.router,
      _ when has(r'pc|desktop|imac|mac|电脑') => DeviceKind.desktop,
      _ => DeviceKind.unknown,
    };
    return DeviceIdentity(kind, brand, slug);
  }
}
