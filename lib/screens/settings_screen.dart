import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _resolution = 720;
  int _fps = 30;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _resolution = prefs.getInt(Constants.prefResolution) ?? 720;
      _fps = prefs.getInt(Constants.prefFps) ?? 30;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(Constants.prefResolution, _resolution);
    await prefs.setInt(Constants.prefFps, _fps);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          DropdownButton<int>(
            value: _resolution,
            items: [720, 1080, 1440]
                .map((r) => DropdownMenuItem(value: r, child: Text('${r}p')))
                .toList(),
            onChanged: (v) => setState(() => _resolution = v!),
          ),
          DropdownButton<int>(
            value: _fps,
            items: [24, 30, 60]
                .map((f) => DropdownMenuItem(value: f, child: Text('$f fps')))
                .toList(),
            onChanged: (v) => setState(() => _fps = v!),
          ),
          SizedBox(height: 16),
          ElevatedButton(onPressed: _saveSettings, child: Text('Save')),
        ]),
      ),
    );
  }
}
