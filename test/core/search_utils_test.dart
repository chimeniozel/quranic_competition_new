import 'package:flutter_test/flutter_test.dart';
import 'package:quranic_competition/core/utils/search_utils.dart';

void main() {
  test('une saisie numérique est reconnue (chiffres latins et arabes)', () {
    expect(SearchUtils.numericQuery('4'), '4');
    expect(SearchUtils.numericQuery(' ٤٢ '), '42');
    expect(SearchUtils.numericQuery('+222 36 12'), '2223612');
    expect(SearchUtils.numericQuery('محمد'), isNull);
    expect(SearchUtils.numericQuery('a4'), isNull);
  });

  test('la correspondance numérique est exacte', () {
    expect(SearchUtils.numberMatches(4, '4'), isTrue);
    expect(SearchUtils.numberMatches(14, '4'), isFalse);
    expect(SearchUtils.numberMatches(40, '4'), isFalse);
    expect(SearchUtils.numberMatches(404, '4'), isFalse);
    expect(SearchUtils.numberMatches('004', '4'), isTrue);
    expect(SearchUtils.numberMatches('36 12 45', '361245'), isTrue);
    expect(SearchUtils.numberMatches(null, '4'), isFalse);
  });
}
