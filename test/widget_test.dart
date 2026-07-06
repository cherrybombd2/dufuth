import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcare/src/app.dart';

void main() {
  testWidgets('shows DUFUTH SmartCare landing content', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SmartCareApp(),
      ),
    );

    expect(find.text('DUFUTH SmartCare'), findsOneWidget);
    expect(find.text('Patient Experience'), findsOneWidget);
    expect(find.text('Doctor Workspace'), findsOneWidget);
    expect(find.text('Admin Control Center'), findsOneWidget);
  });
}
