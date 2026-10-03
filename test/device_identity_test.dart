import 'package:flutter_test/flutter_test.dart';
import 'package:immortalwrt_app/models/device_identity.dart';

void main() {
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
      'myiphonebackup',
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
