import 'package:cardmind/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<BuildContext> _pumpSnackBar(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return captured;
}

void main() {
  testWidgets('it_should_show_success_snackbar', (tester) async {
    final context = await _pumpSnackBar(tester);
    SnackBarUtils.showSuccess(context, 'ok');
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, Colors.green.shade600);
    expect(find.text('ok'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('it_should_show_error_snackbar', (tester) async {
    final context = await _pumpSnackBar(tester);
    SnackBarUtils.showError(context, 'error');
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, Colors.red.shade600);
    expect(find.text('error'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);
  });

  testWidgets('it_should_show_info_snackbar', (tester) async {
    final context = await _pumpSnackBar(tester);
    SnackBarUtils.showInfo(context, 'info');
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, Colors.blue.shade600);
    expect(find.text('info'), findsOneWidget);
    expect(find.byIcon(Icons.info), findsOneWidget);
  });

  testWidgets('it_should_show_warning_snackbar', (tester) async {
    final context = await _pumpSnackBar(tester);
    SnackBarUtils.showWarning(context, 'warn');
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, Colors.orange.shade600);
    expect(find.text('warn'), findsOneWidget);
    expect(find.byIcon(Icons.warning), findsOneWidget);
  });

  testWidgets('it_should_snackbar_have_dismiss_action', (tester) async {
    final context = await _pumpSnackBar(tester);
    SnackBarUtils.showInfo(context, 'info');
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));

    expect(snackBar.action, isNotNull);
    expect(snackBar.action!.label, 'Dismiss');
  });

  testWidgets('it_should_snackbar_duration_is_three_seconds', (tester) async {
    final context = await _pumpSnackBar(tester);
    SnackBarUtils.showSuccess(context, 'ok');
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));

    expect(snackBar.duration, const Duration(seconds: 3));
  });
}
