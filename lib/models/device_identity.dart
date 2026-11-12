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
  String? get iconAsset => slug == null
      ? null
      : 'assets/device-brands/$slug.${slug == 'aqara' ? 'png' : 'svg'}';
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
    final value = name.trim().toLowerCase();
    final separated = name
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]} ${m[2]}',
        )
        .replaceAllMapped(
          RegExp(r'([A-Z])([A-Z][a-z])'),
          (m) => '${m[1]} ${m[2]}',
        )
        .toLowerCase();
    bool has(String expression) {
      final pattern = _deviceNamePatterns.putIfAbsent(
        expression,
        () => RegExp('(?:^|[^a-z0-9])(?:$expression)(?=\u0024|[^a-z0-9])'),
      );
      return pattern.hasMatch(value) || pattern.hasMatch(separated);
    }

    bool named(String expression, [List<String> localized = const []]) =>
        has(expression) ||
        localized.any((term) => value.contains(term.toLowerCase()));
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
        named(
          r'apple|imac(?:\d+[a-z0-9]*)?|mac|mac[ _-]?(?:mini|studio|pro)|homepod(?:mini)?|apple[ _-]?tv(?:\d+[a-z0-9]*)?',
          ['苹果'],
        )) {
      brand = 'Apple';
      slug = 'apple';
    } else {
      for (final rule in _deviceBrands) {
        if (named(rule.pattern, rule.localized)) {
          brand = rule.name;
          slug = rule.slug;
          break;
        }
      }
    }
    final kind = switch (value) {
      _ when appleWatch => DeviceKind.watch,
      _ when iphone => DeviceKind.phone,
      _ when ipad => DeviceKind.tablet,
      _ when macbook => DeviceKind.laptop,
      _ when named(r'smart[ _-]?plug|plug|socket', ['插座']) => DeviceKind.plug,
      _ when named(r'sensor', ['传感器']) => DeviceKind.sensor,
      _ when named(r'vacuum', ['扫地', '吸尘器']) => DeviceKind.vacuum,
      _
          when named(
            r'speaker|homepod(?:mini)?|echo[ _-]?(?:dot|show|studio)',
            ['音箱', '小爱同学'],
          ) =>
        DeviceKind.speaker,
      _ when named(r'smart[ _-]?light|light|bulb', ['灯']) => DeviceKind.light,
      _
          when named(r'air[ _-]?conditioner|fridge|refrigerator|washer', [
            '空调',
            '冰箱',
            '洗衣机',
          ]) =>
        DeviceKind.appliance,
      _
          when named(r'watch\d*|galaxy[ _-]?watch\d*|pixel[ _-]?watch\d*', [
            '手表',
          ]) =>
        DeviceKind.watch,
      _
          when named(
            r'tablet|matepad[a-z0-9]*|magicpad[a-z0-9]*|(?:mi|redmi|xiaomi|lenovo|oneplus|vivo|oppo|honor)[ _-]?pad\d*|galaxy[ _-]?tab(?:[ _-]?[as]\d+[a-z0-9]*)?',
            ['平板', '小新Pad'],
          ) =>
        DeviceKind.tablet,
      _ when named(r'tv\d*|television|apple[ _-]?tv\d*|mitv', ['电视']) =>
        DeviceKind.tv,
      _
          when macbook ||
              named(
                r'laptop|thinkpad(?:[a-z]?\d+[a-z0-9]*)?|thinkbook(?:[a-z]?\d+[a-z0-9]*)?|ideapad(?:[a-z]?\d+[a-z0-9]*)?|yoga(?:[a-z]?\d+[a-z0-9]*)?|legion(?:[a-z]?\d+[a-z0-9]*)?|xiaoxin(?:pro|air)?\d*|matebook[a-z0-9]*|magicbook[a-z0-9]*|(?:xiaomi|redmi|mi)[ _-]?book[a-z0-9]*|zenbook\d*|vivobook\d*|elitebook\d*|probook\d*|xps\d*|latitude\d*|inspiron\d*',
                ['笔记本', '小新Pro', '小新Air'],
              ) =>
        DeviceKind.laptop,
      _
          when iphone ||
              named(
                r'pixel\d*|phone|xiaomi[ _-]?\d+[a-z0-9]*|galaxy[ _-]?(?:[sazmf]\d+[a-z0-9]*|note\d+)|z[ _-]?(?:flip|fold)\d*|pura\d+[a-z0-9]*|mate\d+[a-z0-9]*|redmi[ _-]?(?:note|[kac])?[ _-]?\d+[a-z0-9]*|poco[ _-]?[fxm]\d+[a-z0-9]*|sm[ _-]?[safgnmw]\d+[a-z0-9]*',
                ['手机'],
              ) =>
        DeviceKind.phone,
      _ when named(r'nas|synology|qnap|asustor', ['群晖', '威联通', '华芸']) =>
        DeviceKind.nas,
      _
          when named(
            r'playstation[ _-]?\d*|ps[345]|nintendo[ _-]?switch|xbox(?:[ _-]?(?:series|one|360))?',
            ['游戏主机'],
          ) =>
        DeviceKind.console,
      _
          when named(
            r'printer|laserjet|deskjet|officejet|pixma|imageclass|ecosys',
            ['打印机'],
          ) =>
        DeviceKind.printer,
      _ when named(r'camera|webcam|ipcam|hikvision', ['摄像头', '摄像机', '海康威视']) =>
        DeviceKind.camera,
      _
          when named(r'router|deco(?:[ _-]?[mx]\d+[a-z0-9]*)?|orbi|nighthawk', [
            '路由器',
          ]) =>
        DeviceKind.router,
      _
          when named(
            r'pc|desktop|imac\d*|mac|mac[ _-]?(?:mini|studio|pro)|surface(?:pro\d*)?|optiplex\d*',
            ['电脑'],
          ) =>
        DeviceKind.desktop,
      _ when named(r'iot|esp32|esp8266|tuya|aqara', ['智能设备', '网关']) =>
        DeviceKind.iot,
      _ => DeviceKind.unknown,
    };
    return DeviceIdentity(kind, brand, slug);
  }
}

// Product families identify a maker; they never manufacture a model number or
// imply that every device of a diversified maker is a phone. Short ambiguous
// names (Mi, Mate, Magic, Moto, etc.) need a product/model qualifier.
class _DeviceBrand {
  const _DeviceBrand(
    this.name,
    this.slug,
    this.pattern, [
    this.localized = const [],
  ]);
  final String name;
  final String? slug;
  final String pattern;
  final List<String> localized;
}

const _deviceBrands = [
  _DeviceBrand('Google', 'google', r'google|pixel\d*|chromecast\d*'),
  _DeviceBrand(
    'Huawei',
    'huawei',
    r'huawei\d*|matebook[a-z0-9]*|matepad[a-z0-9]*|pura\d+[a-z0-9]*|mate\d+[a-z0-9]*',
    ['华为'],
  ),
  _DeviceBrand(
    'HONOR',
    'honor',
    r'honor\d*|magicbook[a-z0-9]*|magicpad[a-z0-9]*',
    ['荣耀'],
  ),
  _DeviceBrand(
    'Xiaomi',
    'xiaomi',
    r'xiaomi\d*|mipad\d*|mi[ _-]?\d{1,2}[a-z0-9]*|redmi(?:[ _-]?(?:note|[kac]))?[ _-]?\d*[a-z0-9]*|poco(?:[ _-]?[fxm]\d+[a-z0-9]*)?|mijia|(?:xiaomi|redmi|mi)[ _-]?book[a-z0-9]*|mitv',
    ['小米', '红米', '米家', '小爱'],
  ),
  _DeviceBrand(
    'Samsung',
    'samsung',
    r'samsung|galaxy|z[ _-]?(?:flip|fold)\d*|sm[ _-]?[safgnmw]\d+[a-z0-9]*',
    ['三星'],
  ),
  _DeviceBrand('OPPO', 'oppo', r'oppo\d*', ['欧珀']),
  _DeviceBrand('OnePlus', 'oneplus', r'oneplus\d*|one[ _-]plus', ['一加']),
  _DeviceBrand('vivo', 'vivo', r'vivo\d*|iqoo\d*', ['维沃']),
  _DeviceBrand('realme', 'realme', r'realme\d*', ['真我']),
  _DeviceBrand(
    'Motorola',
    'motorola',
    r'motorola|moto[ _-]?(?:[gez]\d+[a-z0-9]*|edge\d*|razr\d*)',
    ['摩托罗拉'],
  ),
  _DeviceBrand('ZTE', 'zte', r'zte|nubia\d*|redmagic\d*', ['中兴', '努比亚', '红魔']),
  _DeviceBrand('Meizu', 'meizu', r'meizu\d*', ['魅族']),
  _DeviceBrand('Sony', 'sony', r'sony|xperia\d*|bravia\d*', ['索尼']),
  _DeviceBrand('Nokia', 'nokia', r'nokia\d*', ['诺基亚']),
  _DeviceBrand('Synology', 'synology', r'synology', ['群晖']),
  _DeviceBrand('QNAP', 'qnap', r'qnap', ['威联通']),
  _DeviceBrand('ASUSTOR', 'asustor', r'asustor', ['华芸']),
  _DeviceBrand('UGREEN', 'ugreen', r'ugreen|ugos', ['绿联']),
  _DeviceBrand('PlayStation', 'playstation', r'playstation[ _-]?\d*|ps[345]'),
  _DeviceBrand('Nintendo', 'nintendo', r'nintendo', ['任天堂']),
  _DeviceBrand(
    'Dell',
    'dell',
    r'dell|optiplex\d*|xps\d*|latitude\d*|inspiron\d*|alienware',
    ['戴尔', '外星人'],
  ),
  _DeviceBrand(
    'Lenovo',
    'lenovo',
    r'lenovo\d*|thinkpad(?:[a-z]?\d+[a-z0-9]*)?|thinkbook(?:[a-z]?\d+[a-z0-9]*)?|ideapad(?:[a-z]?\d+[a-z0-9]*)?|thinkcentre(?:[a-z]?\d+[a-z0-9]*)?|ideacentre(?:[a-z]?\d+[a-z0-9]*)?|legion(?:[a-z]?\d+[a-z0-9]*)?|yoga(?:[a-z]?\d+[a-z0-9]*)?|xiaoxin(?:pro|air)?\d*',
    ['联想', '拯救者', '小新'],
  ),
  _DeviceBrand(
    'ASUS',
    'asus',
    r'asus|rog|zenbook\d*|vivobook\d*|rt[ _-]?(?:ax|be)\d+[a-z0-9]*',
    ['华硕', '玩家国度'],
  ),
  _DeviceBrand(
    'HP',
    'hp',
    r'hp|hewlett[ _-]?packard|elitebook\d*|probook\d*|laserjet|deskjet|officejet',
    ['惠普'],
  ),
  _DeviceBrand('Acer', 'acer', r'acer', ['宏碁']),
  _DeviceBrand('MSI', 'msi', r'msi', ['微星']),
  _DeviceBrand('Gigabyte', 'gigabyte', r'gigabyte|aorus', ['技嘉']),
  _DeviceBrand('Razer', 'razer', r'razer', ['雷蛇']),
  _DeviceBrand('Microsoft', 'microsoft', r'microsoft|surface(?:pro\d*)?|xbox', [
    '微软',
  ]),
  _DeviceBrand(
    'TP-Link',
    'tp-link',
    r'tp[ _-]?link|tapo|deco(?:[ _-]?[mx]\d+[a-z0-9]*)?',
    ['普联'],
  ),
  _DeviceBrand('NETGEAR', 'netgear', r'netgear|orbi|nighthawk', ['网件']),
  _DeviceBrand('Ubiquiti', 'ubiquiti', r'ubiquiti|unifi|ubnt'),
  _DeviceBrand('D-Link', 'd-link', r'd[ _-]?link', ['友讯']),
  _DeviceBrand('Tenda', 'tenda', r'tenda', ['腾达']),
  _DeviceBrand('Ruijie', null, r'ruijie|reyee', ['锐捷']),
  _DeviceBrand('H3C', null, r'h3c', ['新华三']),
  _DeviceBrand('Canon', 'canon', r'canon|pixma|imageclass', ['佳能']),
  _DeviceBrand('Epson', 'epson', r'epson|ecotank', ['爱普生']),
  _DeviceBrand('Brother', 'brother', r'brother', ['兄弟打印机']),
  _DeviceBrand('Hikvision', 'hikvision', r'hikvision', ['海康威视', '萤石']),
  _DeviceBrand('Dahua', 'dahua', r'dahua|imou', ['大华', '乐橙']),
  _DeviceBrand('DJI', 'dji', r'dji', ['大疆']),
  _DeviceBrand('Aqara', 'aqara', r'aqara', ['绿米']),
  _DeviceBrand('Roborock', 'roborock', r'roborock', ['石头']),
  _DeviceBrand('Dreame', 'dreame', r'dreame', ['追觅']),
  _DeviceBrand('Dyson', 'dyson', r'dyson', ['戴森']),
  _DeviceBrand('Sonos', 'sonos', r'sonos'),
  _DeviceBrand('Philips', 'philips', r'philips|philips[ _-]?hue', ['飞利浦']),
  _DeviceBrand('Tuya', 'tuya', r'tuya|smartlife', ['涂鸦']),
  _DeviceBrand(
    'Amazon',
    'amazon',
    r'amazon|kindle\d*|echo[ _-]?(?:dot|show|studio)',
  ),
  _DeviceBrand('Haier', 'haier', r'haier', ['海尔']),
  _DeviceBrand('Hisense', 'hisense', r'hisense', ['海信']),
  _DeviceBrand('TCL', 'tcl', r'tcl'),
  _DeviceBrand('Espressif', 'espressif', r'espressif|esp32|esp8266', ['乐鑫']),
];

final _deviceNamePatterns = <String, RegExp>{};
