// mqtt_api.dart
import 'dart:async'; // 引入 async 庫
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_cors_headers/shelf_cors_headers.dart'; // 保留
import 'package:shared_preferences/shared_preferences.dart';
import 'sqlite_db.dart'; //  SQLite 資料庫
import 'ip_info_page.dart'; // 引入 IP 訊息方便做固定IP NAT5轉發
import 'pass_io.dart'; // 引入登入介面
import 'package:intl/intl.dart'; // 引入 intl 包

final Map<String, String> messages = {}; // 存儲 MQTT 的消息
final List<String> topics = [
  'isu/esp32s_Hellow',
  'isu/esp32s_1/wen/soilmoisture_1',
  'isu/esp32s_1/wen/soilmoisture_2',
  'isu/esp32s_1/wen/soilmoisture_3',
  'isu/esp32s_/wen/isu_school/soilmoisture_1',
  'isu/esp32s_/wen/isu_school/soilmoisture_2',
  'isu/esp32s_/wen/isu_school/soilmoisture_3'
];

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late MqttServerClient client;
  Completer<void>? allMessagesReceivedCompleter;

  @override
  void initState() {
    super.initState();
    _loadData();
    _connectMQTT();
  }

  Future<void> _connectMQTT() async {
    client = MqttServerClient('broker.emqx.io', 'flutter_client_V3');
    client.port = 1883;
    client.logging(on: true);
    client.keepAlivePeriod = 60;
    client.onDisconnected = _onDisconnected;
    client.onConnected = _onConnected;
    client.onSubscribed = _onSubscribed;

    final connMessage = MqttConnectMessage()
        .authenticateAs('emqx', 'public')
        .withWillTopic('willtopic')
        .withWillMessage('Will message')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    client.connectionMessage = connMessage;

    try {
      await client.connect();
    } catch (e) {
      print('Exception: $e');
      client.disconnect();
    }

    client.updates!.listen(
      (List<MqttReceivedMessage<MqttMessage>> c) async {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        final String topic = c[0].topic;
        print("MQTT Message: $pt");

        final DateTime currentTime = DateTime.now();
        // 留小時、分鐘、秒，精確到小數點後6位
        final String currentTimeStr = DateFormat('HH:mm:ss.SSSSSS').format(currentTime);

        // mqtt_received_timestamp，留小時、分鐘、秒，精確到小數點後6位
        final String mqttReceiveTimestampStr = DateFormat('HH:mm:ss.SSSSSS').format(currentTime);

        // 處理消息内容和時間戳
        String mqttDelay = "N/A";
        String messageContent = pt;
        String mqttSentTimestampStr = "N/A";

        if (pt.contains('|')) {
          List<String> mqttMessageParts = pt.split('|');
          messageContent = mqttMessageParts[0];
          if (mqttMessageParts.length == 2) {
            try {
              final DateTime mqttSentTime = DateTime.parse(mqttMessageParts[1]);
              // mqtt_sent_timestamp，留小時、分鐘、秒，精確到小數點後6位
              mqttSentTimestampStr = DateFormat('HH:mm:ss.SSSSSS').format(mqttSentTime);
              mqttDelay = (currentTime.difference(mqttSentTime).inMicroseconds / 1000000).toStringAsFixed(6);
            } catch (e) {
              mqttDelay = "N/A";
            }
          }
        }

        setState(() {
          messages[topic] = messageContent;
        });

        final dbHelper = DatabaseHelper();
        final Map<String, dynamic> mqttData = {
          'time': currentTimeStr,
          'mqtt_topic': topic,
          'api_data': '',
          'value': messageContent,
          'mqtt_sent_timestamp': mqttSentTimestampStr,
          'mqtt_received_timestamp': mqttReceiveTimestampStr,
          'api_elapsed_microseconds': 'N/A',
          'mqtt_response_time': mqttDelay,
          'api_response_time': 'N/A'
        };
        await dbHelper.insertData(mqttData);

        if (allMessagesReceivedCompleter != null && !allMessagesReceivedCompleter!.isCompleted) {
          bool allMessagesReceived = true;
          for (String t in topics) {
            if (!messages.containsKey(t)) {
              allMessagesReceived = false;
              break;
            }
          }
          if (allMessagesReceived) {
            allMessagesReceivedCompleter!.complete();
          }
        }
      },
    );

    for (String topic in topics) {
      client.subscribe(topic, MqttQos.atLeastOnce);
    }
  }

  void _onDisconnected() {
    print('Disconnected');
    _connectMQTT(); // 自動重連(避免斷線
  }

  void _onConnected() {
    print('Connected');
  }

  void _onSubscribed(String topic) {
    print('Subscribed to $topic');
  }

  void _publishZeroToAllTopics() async {
    allMessagesReceivedCompleter = Completer<void>();

    // 發送 MQTT 消息
    _publishMessage('0');

    // 發送 API 請求
    _triggerApiCall();

    // 等待所有主題的消息更新
    try {
      await allMessagesReceivedCompleter!.future.timeout(Duration(seconds: 5));
    } catch (e) {
      print('Timeout waiting for all messages');
    }
  }

  // 發送 API 請求
  void _triggerApiCall() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('http://localhost:7799/isu/wen/school/idi/api/data'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final decodedData = jsonDecode(responseBody);

        setState(() {
          messages['API Data'] = decodedData.toString(); // 將整個 API 數據顯示
        });
        print('API Response: $decodedData');
      } else {
        print('Failed to get API data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in API call: $e');
    } finally {
      client.close();
    }
  }

  void _publishMessage(String message) {
    final builder = MqttClientPayloadBuilder();
    final String messageWithTimestamp = '$message|${DateTime.now().toIso8601String()}';
    builder.addString(messageWithTimestamp);
    for (String topic in topics) {
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('messages', jsonEncode(messages));
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedMessages = prefs.getString('messages');
    if (savedMessages != null) {
      setState(() {
        messages.addAll(Map<String, String>.from(jsonDecode(savedMessages)));
      });
    }
  }

  void _restartApp() {
    _saveData().then((_) {
      exit(0);
    });
  }

  void _closeApp() {
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MQTT Client with SQLite'),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 100.0),
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final topic = messages.keys.elementAt(index);
                final displayMessage = messages[topic]!;
                return ListTile(
                  title: Text('$topic: $displayMessage'),
                );
              },
            ),
          ),
          Positioned(
            top: 100,
            right: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ElevatedButton(
                  onPressed: () => _publishMessage('Hello MQTT'),
                  child: Text('MQTT測試按鈕'),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _publishZeroToAllTopics,
                  child: Text('所有數字歸零'),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => IpInfoPage()),
                    );
                  },
                  child: Text('查看 IP'),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                    );
                  },
                  child: Text('回到登入畫面'),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SqlitePage()),
                    );
                  },
                  child: Text('跳轉到 SQLite 頁面'),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _closeApp,
                  child: Text('關閉程式'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// API 伺服器
void startApiServer() async {
  final app = shelf_router.Router();

  app.get('/isu/wen/school/idi/api/data', (Request request) async {
    final stopwatch = Stopwatch()..start();

    // 紀錄 API 請求的時間
    final DateTime apiSentTime = DateTime.now();
    final String apiSentTimestampStr = DateFormat('HH:mm:ss.SSSSSS').format(apiSentTime);

    final data = {
      'isu/esp32s_Hellow': messages['isu/esp32s_Hellow'] ?? 'no data',
      'humidity1': messages['isu/esp32s_1/wen/soilmoisture_1'] ?? 'no data',
      'humidity2': messages['isu/esp32s_1/wen/soilmoisture_2'] ?? 'no data',
      'humidity3': messages['isu/esp32s_1/wen/soilmoisture_3'] ?? 'no data',
      'humidity11': messages['isu/esp32s_/wen/isu_school/soilmoisture_1'] ?? 'no data',
      'humidity22': messages['isu/esp32s_/wen/isu_school/soilmoisture_2'] ?? 'no data',
      'humidity33': messages['isu/esp32s_/wen/isu_school/soilmoisture_3'] ?? 'no data',
    };

    stopwatch.stop();
    final int apiElapsedMicroseconds = stopwatch.elapsedMicroseconds;

    final DateTime endTime = DateTime.now();
    final String apiResponseTime = DateFormat('HH:mm:ss.SSSSSS').format(endTime);
    final String apiDelayString = (apiElapsedMicroseconds / 1000000).toStringAsFixed(6);

    // 获取当前时间，精确到6位小数
    final String currentTimeStr = DateFormat('HH:mm:ss.SSSSSS').format(DateTime.now());

    final dbHelper = DatabaseHelper();
    await dbHelper.insertData({
      'time': currentTimeStr,
      'mqtt_topic': 'API Data',
      'api_data': 'API Data',
      'value': 'API Response',
      'mqtt_sent_timestamp': apiSentTimestampStr, // 紀錄發送時間
      'mqtt_received_timestamp': apiResponseTime,
      'api_elapsed_microseconds': apiElapsedMicroseconds.toString(),
      'mqtt_response_time': 'N/A',
      'api_response_time': apiDelayString,
    });

    return Response.ok(jsonEncode(data), headers: {'Content-Type': 'application/json'});
  });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(app);

  final server = await io.serve(handler, InternetAddress.anyIPv4, 7799);
  print('Server listening on port ${server.port}');
}
