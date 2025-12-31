#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Quick lint checker for CardMind project
///
/// This script runs all static analysis tools in check-only mode.
/// Use this before committing code.
///
/// Usage:
///   dart tool/check_lint.dart

import 'fix_lint.dart' as fix_lint;

void main(List<String> arguments) {
  // Always run in check-only mode
  fix_lint.main(['--check-only']);
}
