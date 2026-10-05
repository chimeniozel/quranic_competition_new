import 'package:flutter_test/flutter_test.dart';
import 'package:quranic_competition/core/services/benefit_read_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('une فائدة ouverte est mémorisée comme lue', () async {
    SharedPreferences.setMockInitialValues({});
    final store = BenefitReadStore();

    expect(await store.readIds(), isEmpty);
    await store.markRead('b1');
    await store.markRead('b1'); // pas de doublon
    expect(await store.readIds(), {'b1'});

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('read_benefit_ids'), ['b1']);
  });
}
