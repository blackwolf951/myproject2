// sqlite_db.dart
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart'; // 用於操作路徑
import 'dart:io'; // 打开 Windows 文件夹
import 'package:url_launcher/url_launcher.dart'; // 用於在 Windows 打开資料夾

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // 指定資料存放在 C:\MQTT_API_ISU_WEN 路徑下
    String path = 'C:/MQTT_API_ISU_WEN/mqtt_data.db';

    // 如果文件資料夾不存在，創建文件資料夾
    final directory = Directory('C:/MQTT_API_ISU_WEN');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          '''
          CREATE TABLE data(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            time TEXT,
            mqtt_topic TEXT,
            api_data TEXT,
            value TEXT,
            mqtt_sent_timestamp TEXT,
            mqtt_received_timestamp TEXT,
            api_elapsed_microseconds TEXT,
            mqtt_response_time TEXT,
            api_response_time TEXT
          )
          ''',
        );
      },
    );
  }

  Future<void> insertData(Map<String, dynamic> data) async {
    final db = await database;
    try {
      await db.insert(
        'data',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('Data inserted successfully: $data');
    } catch (e) {
      print('Error inserting data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllData() async {
    final db = await database;
    return await db.query('data',
        orderBy: 'mqtt_received_timestamp DESC'); // 按造接收時間倒序排序
  }

  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('data');
  }
}

class SqlitePage extends StatefulWidget {
  @override
  _SqlitePageState createState() => _SqlitePageState();
}

class _SqlitePageState extends State<SqlitePage> {
  List<Map<String, dynamic>> _data = [];

  @override
  void initState() {
    super.initState();
    _loadDataFromDatabase();
  }

  Future<void> _loadDataFromDatabase() async {
    final dbHelper = DatabaseHelper();
    final data = await dbHelper.getAllData();
    setState(() {
      _data = List.from(data); // 確保 _data 是一个可變的列表
    });
  }

  Future<void> _clearPageData() async {
    setState(() {
      _data.clear(); // 清除頁面顯示的數據
    });
  }

  Future<void> _reloadPageData() async {
    _loadDataFromDatabase(); // 重新加載數據据並顯示在頁面上
  }

  Future<void> _openDatabaseFolder() async {
    try {
      String path = join(await getDatabasesPath(), 'mqtt_data.db');
      final folderPath = Directory(path).parent.path;

      if (await canLaunch('file://$folderPath')) {
        await launch('file://$folderPath');
      } else {
        print("Cannot open folder: $folderPath");
      }
    } catch (e) {
      print('Error opening folder: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SQLite Data'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _clearPageData, // 清除頁面的顯示數據
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _reloadPageData, // 重新加載數據並顯示
          ),
          IconButton(
            icon: Icon(Icons.folder),
            onPressed: () async {
              const folderPath = 'C:/MQTT_API_ISU_WEN'; // 你想要打開的資料夾路徑
              final uri = Uri.file(folderPath); // 使用 Uri.file() 生成合法的 URI

              if (await canLaunch(uri.toString())) {
                await launch(uri.toString()); // 打開指定資料夾
              } else {
                print('Cannot open folder: $folderPath');
              }
            }, // 打开Windows資料夾，顯示資料庫位置
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _data.length,
        itemBuilder: (context, index) {
          final item = _data[index];
          return ListTile(
            title: Text('${item['time']} | ${item['mqtt_topic']}'),
            subtitle: Text(
              'API Data: ${item['api_data']} | Value: ${item['value']}\n'
              'Sent: ${item['mqtt_sent_timestamp']} | Received: ${item['mqtt_received_timestamp']}\n'
              'API Elapsed: ${item['api_elapsed_microseconds']} | '
              'MQTT Resp Time: ${item['mqtt_response_time']} | '
              'API Resp Time: ${item['api_response_time']}',
            ),
          );
        },
      ),
    );
  }
}
