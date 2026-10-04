import 'package:flutter_test/flutter_test.dart';
import 'package:immortalwrt_app/models/device_identity.dart';

void main() {
  test('IoT types do not imply that every brand device is a phone', () {
    for (final entry in <(String, String)>[
      ('Xiaomi-Smart-Plug', '智能插座'),
      ('Philips-Hue-Light', '智能灯'),
      ('Aqara-Temperature-Sensor', '传感器'),
      ('Sonos-Speaker', '智能音箱'),
      ('Roborock-Vacuum', '扫地机器人'),
      ('ESP32', '智能设备'),
      ('Tuya-Air-Conditioner', '家电'),
      ('Xiaomi-Camera', '摄像头'),
      ('Samsung-TV', '电视'),
      ('Xiaomi', '设备'),
    ]) {
      final identity = DeviceIdentity.fromName(entry.$1);
      expect(identity.typeLabel, entry.$2, reason: entry.$1);
      expect(identity.kind, isNot(DeviceKind.phone), reason: entry.$1);
      expect(identity.model, isNull);
    }
    expect(DeviceIdentity.fromName('Aqara-Sensor').brand, 'Aqara');
    expect(DeviceIdentity.fromName('Roborock-Vacuum').brand, 'Roborock');
    expect(DeviceIdentity.fromName('Office-PC').typeLabel, '电脑');
  });

  test('Apple product names attached to owner names keep Apple identity', () {
    for (final name in [
      'MZYtekiiPhone',
      'AliceiPhone17Pro',
      'myiphonebackup',
    ]) {
      final identity = DeviceIdentity.fromName(name);
      expect(identity.brand, 'Apple', reason: name);
      expect(identity.slug, 'apple', reason: name);
      expect(identity.kind, DeviceKind.phone, reason: name);
    }
    expect(DeviceIdentity.fromName('MZYiPadAir').kind, DeviceKind.tablet);
    expect(DeviceIdentity.fromName('MZYAppleWatch').brand, 'Apple');
    expect(DeviceIdentity.fromName('MZYAppleWatch').typeLabel, '手表');
    expect(DeviceIdentity.fromName('MacBookPro').kind, DeviceKind.laptop);
  });
  test(
    'computer brands and product families retain only supported identity',
    () {
      for (final entry in <(String, String)>[
        ('Dell-PC', 'Dell'),
        ('DELL-XPS-13', 'Dell'),
        ('ThinkPad-T14', 'Lenovo'),
        ('ThinkBook-14', 'Lenovo'),
        ('IdeaPad-5', 'Lenovo'),
        ('ASUS-Zenbook', 'ASUS'),
        ('HP-EliteBook', 'HP'),
        ('Acer-PC', 'Acer'),
        ('MSI-PC', 'MSI'),
        ('GIGABYTE-PC', 'Gigabyte'),
        ('Razer-PC', 'Razer'),
        ('Surface-Pro-11', 'Microsoft'),
      ]) {
        final identity = DeviceIdentity.fromName(entry.$1);
        expect(identity.brand, entry.$2, reason: entry.$1);
        expect(
          identity.kind,
          isIn([DeviceKind.desktop, DeviceKind.laptop]),
          reason: entry.$1,
        );
        expect(identity.model, isNull);
      }
      expect(DeviceIdentity.fromName('PC').kind, DeviceKind.desktop);
      expect(DeviceIdentity.fromName('PC').brand, isNull);
      expect(DeviceIdentity.fromName('rpcserver').brand, isNull);
      expect(DeviceIdentity.fromName('helpdesk').brand, isNull);
    },
  );

  test(
    'Samsung Z Flip and Fold variants are phones without guessed generations',
    () {
      for (final name in [
        'Z-flip',
        'Z Flip',
        'ZFlip',
        'Galaxy-Z-Flip6',
        'Z-Fold5',
        'Galaxy Z Fold 6',
      ]) {
        final identity = DeviceIdentity.fromName(name);
        expect(identity.brand, 'Samsung', reason: name);
        expect(identity.kind, DeviceKind.phone, reason: name);
        expect(identity.model, isNull, reason: name);
      }
      expect(DeviceIdentity.fromName('flip-camera').brand, isNull);
      expect(DeviceIdentity.fromName('z-flipbackup').brand, isNull);
    },
  );
  test('recognizes explicit product names without inventing a model', () {
    final phone = DeviceIdentity.fromName('Alice-iPhone-17-Pro');
    expect(phone.brand, 'Apple');
    expect(phone.kind, DeviceKind.phone);
    expect(DeviceIdentity.fromName('MacBook-Pro').kind, DeviceKind.laptop);
    expect(DeviceIdentity.fromName('Synology-NAS').brand, 'Synology');
    expect(DeviceIdentity.fromName('PS5').kind, DeviceKind.console);
    expect(DeviceIdentity.fromName('Nintendo-Switch').brand, 'Nintendo');
    expect(DeviceIdentity.fromName('HUAWEI-Pura').brand, 'Huawei');
    expect(DeviceIdentity.fromName('Xiaomi-TV').kind, DeviceKind.tv);
  });
  test('ambiguous hostnames do not imply a brand or a device type', () {
    for (final name in [
      'Switch',
      '192.168.2.1',
      'fd00::1',
      'tvarchive',
      'rpcserver',
      '',
    ]) {
      final identity = DeviceIdentity.fromName(name);
      expect(identity.brand, isNull, reason: name);
      expect(identity.kind, DeviceKind.unknown, reason: name);
    }
  });
  test('brand alone does not imply phone, model or operating system', () {
    final identity = DeviceIdentity.fromName('Samsung');
    expect(identity.brand, 'Samsung');
    expect(identity.kind, DeviceKind.unknown);
    expect(DeviceIdentity.fromName('Office-PC').kind, DeviceKind.desktop);
    expect(DeviceIdentity.fromName('Pixel9').brand, 'Google');
    expect(DeviceIdentity.fromName('iPad-Air').kind, DeviceKind.tablet);
  });
  test('user confirmed XiaoQiang maps to Xiaomi router', () {
    final identity = DeviceIdentity.fromName('XiaoQiang');
    expect(identity.brand, '小米');
    expect(identity.kind, DeviceKind.router);
    expect(identity.evidence, '用户确认的名称映射');
    expect(identity.model, 'AX9000');
    expect(DeviceIdentity.fromName('Xiaomi').model, isNull);
  });
}
