import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immortalwrt_app/main.dart';

void main() {
  testWidgets('offline shell presents connection and all four sections',
      (tester) async {
    await tester.pumpWidget(const ImmortalWrtApp());
    await tester.pump();
    expect(find.text('连接路由器'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('总览'), findsWidgets);
    expect(find.text('设备'), findsOneWidget);
    expect(find.text('Wi-Fi'), findsOneWidget);
    expect(find.text('流量'), findsOneWidget);
  });
}
