import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class KeyboardUtils {
  static void hideKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  static bool isKeyboardVisible(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }

  static double getKeyboardHeight(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom;
  }

  static Widget keyboardListener({
    required Widget child,
    required VoidCallback? onKeyboardShow,
    required VoidCallback? onKeyboardHide,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isKeyboardVisible = KeyboardUtils.isKeyboardVisible(context);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (isKeyboardVisible && onKeyboardShow != null) {
            onKeyboardShow();
          } else if (!isKeyboardVisible && onKeyboardHide != null) {
            onKeyboardHide();
          }
        });

        return child;
      },
    );
  }
}
