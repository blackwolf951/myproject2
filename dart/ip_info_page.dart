//ip_info_page.dart
import 'package:flutter/material.dart';
import 'package:process_run/process_run.dart';
import 'dart:io';

class IpInfoPage extends StatefulWidget {
  @override
  _IpInfoPageState createState() => _IpInfoPageState();
}

class _IpInfoPageState extends State<IpInfoPage> {
  String? _ipConfigOutput;

  @override
  void initState() {
    super.initState();
    _getIpConfigOutput();
  }

  Future<void> _getIpConfigOutput() async {
    String? ipConfigOutput;
    try {
      // 執行 ipconfig 命令
      List<ProcessResult> results = await run('ipconfig');
      ipConfigOutput = results.map((result) => result.stdout).join('\n');
    } catch (e) {
      ipConfigOutput = 'Failed to get ipconfig output.';
    }

    setState(() {
      _ipConfigOutput = ipConfigOutput;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('IP Information'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('IP Config Output:'),
            SizedBox(height: 10),
            Text(_ipConfigOutput ?? 'Loading...'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
