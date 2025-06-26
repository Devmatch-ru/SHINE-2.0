import 'package:flutter/material.dart';
import 'package:shine/screens/user/role_select.dart';

import '../../widgets/common/ModernPageTransition.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modern Transitions')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
              ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  CameraPageRoute(
                    child: const SecondScreen(),
                    type: CameraTransitionType.blur,
                  ),
                );
              },
              child: const Text('Slide & Fade Transition'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  CameraPageRoute(
                    child: const SecondScreen(),
                    type: CameraTransitionType.focus,
                  ),
                );
              },
              child: const Text('Scale Transition'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  CameraPageRoute(
                    child: const SecondScreen(),
                    type: CameraTransitionType.pan,
                  ),
                );
              },
              child: const Text('Fade Transition'),
            ),const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  CameraPageRoute(
                    child: const RoleSelectScreen(),
                    type: CameraTransitionType.zoom,
                  ),
                );
              },
              child: const Text('Fade Transition'),
            ),
          ],
        ),
      ),
    );
  }
}

class SecondScreen extends StatelessWidget {
  const SecondScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Second Screen')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Go Back'),
        ),
      ),
    );
  }
}

void main() {
  runApp(
    MaterialApp(
      home: const HomeScreen(),
      theme: ThemeData(primarySwatch: Colors.blue),
    ),
  );
}