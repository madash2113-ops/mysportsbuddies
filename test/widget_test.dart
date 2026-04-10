import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mysportsbuddies/main.dart';
import 'package:mysportsbuddies/controllers/profile_controller.dart';

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
