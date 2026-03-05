import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/controllers/profile_controller.dart';

void main() {
  testWidgets('MySportsApp renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ProfileController(),
        child: const MySportsApp(),
      ),
    );

    // Verify the app renders without throwing
    expect(find.byType(MySportsApp), findsOneWidget);
  });
}
