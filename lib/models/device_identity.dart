enum DeviceKind {
  unknown,
  phone,
  tablet,
  watch,
  speaker,
  light,
  plug,
  sensor,
  vacuum,
  appliance,
  iot,
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
    DeviceKind.watch => '手表',
    DeviceKind.speaker => '智能音箱',
    DeviceKind.light => '智能灯',
    DeviceKind.plug => '智能插座',
    DeviceKind.sensor => '传感器',
    DeviceKind.vacuum => '扫地机器人',
    DeviceKind.appliance => '家电',
    DeviceKind.iot => '智能设备',
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
    final iphone = value.contains('iphone');
    final ipad = value.contains('ipad');
    final appleWatch = RegExp(r'apple[ _-]?watch').hasMatch(value);
    final macbook = value.contains('macbook');
    String? brand;
    String? slug;
    if (iphone ||
        ipad ||
        appleWatch ||
        macbook ||
        has(r'apple|imac|mac|homepod|apple[ -]?tv')) {
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
    } else if (has(r'dell|戴尔|optiplex')) {
      brand = 'Dell';
      slug = 'dell';
    } else if (has(r'lenovo|thinkpad|thinkbook|ideapad|联想')) {
      brand = 'Lenovo';
      slug = 'lenovo';
    } else if (has(r'asus|华硕')) {
      brand = 'ASUS';
      slug = 'asus';
    } else if (has(r'hp|惠普')) {
      brand = 'HP';
      slug = 'hp';
    } else if (has(r'acer|宏碁')) {
      brand = 'Acer';
      slug = 'acer';
    } else if (has(r'msi|微星')) {
      brand = 'MSI';
      slug = 'msi';
    } else if (has(r'gigabyte|技嘉')) {
      brand = 'Gigabyte';
    } else if (has(r'razer|雷蛇')) {
      brand = 'Razer';
      slug = 'razer';
    } else if (has(r'microsoft|surface|微软')) {
      brand = 'Microsoft';
      slug = 'microsoft';
    } else if (has(r'aqara|绿米')) {
      brand = 'Aqara';
    } else if (has(r'roborock|石头')) {
      brand = 'Roborock';
    } else if (has(r'sonos')) {
      brand = 'Sonos';
      slug = 'sonos';
    } else if (has(r'philips|飞利浦')) {
      brand = 'Philips';
    } else if (has(r'tuya|涂鸦')) {
      brand = 'Tuya';
    } else if (has(r'espressif|esp32|esp8266')) {
      brand = 'Espressif';
      slug = 'espressif';
    }
    final kind = switch (value) {
      _ when appleWatch => DeviceKind.watch,
      _ when iphone => DeviceKind.phone,
      _ when ipad => DeviceKind.tablet,
      _ when macbook => DeviceKind.laptop,
      _ when has(r'smart[ -]?plug|plug|socket|插座') => DeviceKind.plug,
      _ when has(r'sensor|传感器') => DeviceKind.sensor,
      _ when has(r'vacuum|扫地|扫地机器人') => DeviceKind.vacuum,
      _ when has(r'speaker|homepod|音箱') => DeviceKind.speaker,
      _ when has(r'smart[ -]?light|light|bulb|灯') => DeviceKind.light,
      _ when has(r'air[ -]?conditioner|fridge|refrigerator|washer|空调|冰箱|洗衣机') =>
        DeviceKind.appliance,
      _ when has(r'tablet|平板') => DeviceKind.tablet,
      _ when has(r'tv|television|电视|apple[ -]?tv') => DeviceKind.tv,
      _
          when macbook ||
              has(
                r'laptop|thinkpad|thinkbook|ideapad|zenbook|vivobook|elitebook|probook|xps|latitude|inspiron|笔记本',
              ) =>
        DeviceKind.laptop,
      _ when iphone || has(r'pixel\d*|phone|手机|z[ -]?(?:flip|fold)\d*') =>
        DeviceKind.phone,
      _ when has(r'nas|synology|群晖') => DeviceKind.nas,
      _ when has(r'playstation[ -]?\d*|ps[345]|nintendo[ -]?switch|游戏主机') =>
        DeviceKind.console,
      _ when has(r'printer|打印机') => DeviceKind.printer,
      _ when has(r'camera|摄像头') => DeviceKind.camera,
      _ when has(r'router|路由器') => DeviceKind.router,
      _ when has(r'pc|desktop|imac|mac|surface|optiplex|电脑') =>
        DeviceKind.desktop,
      _ when has(r'iot|esp32|esp8266|tuya|aqara|智能设备|网关') => DeviceKind.iot,
      _ => DeviceKind.unknown,
    };
    return DeviceIdentity(kind, brand, slug);
  }
}
