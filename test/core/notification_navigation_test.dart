import 'package:flutter_test/flutter_test.dart';
import 'package:quranic_competition/core/services/notification_navigation.dart';

void main() {
  test('une notification de فائدة ouvre son détail', () {
    expect(
      NotificationNavigation.routeForData({
        'type': 'benefit_created',
        'benefit_id': 'abc-123',
      }),
      '/participant/benefits/abc-123',
    );
  });

  test('une ancienne notification sans identifiant ouvre la liste', () {
    expect(
      NotificationNavigation.routeForData({'type': 'benefit_created'}),
      '/participant/benefits',
    );
  });
}
