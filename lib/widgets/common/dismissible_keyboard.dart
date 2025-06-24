import 'package:flutter/material.dart';
import '../../utils/keyboard_utils.dart';

class DismissibleKeyboard extends StatelessWidget {
  final Widget child;

  const DismissibleKeyboard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => KeyboardUtils.hideKeyboard(context),
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}