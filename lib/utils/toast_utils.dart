import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cardmind/theme/app_theme.dart';

/// Toast 通知工具类
class ToastUtils {
  // Private constructor to prevent instantiation
  ToastUtils._();

  /// 显示成功 Toast
  static void showSuccess(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      backgroundColor: AppTheme.successColor,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  /// 显示错误 Toast
  static void showError(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 4,
      backgroundColor: AppTheme.errorColor,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  /// 显示信息 Toast
  static void showInfo(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      backgroundColor: AppTheme.infoColor,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  /// 显示警告 Toast
  static void showWarning(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      backgroundColor: AppTheme.warningColor,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  /// 取消所有 Toast
  static void cancelAll() {
    Fluttertoast.cancel();
  }
}
