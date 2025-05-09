import 'package:flutter/material.dart';

class CaptureButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const CaptureButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: onPressed,
    child: Text('Capture'),
  );
}
