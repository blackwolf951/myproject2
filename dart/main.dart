import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // 引入 sqflite_ffi
import 'pass_io.dart'; // 引入登入界面
import 'mqtt_api.dart'; // 引入 MQTT 和 API

void main() {
  // 初始化数据库工厂用于桌面环境
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  runApp(MyApp());
  startApiServer(); // 启动 API 服务器
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LoginPage(),
    );
  }
}
