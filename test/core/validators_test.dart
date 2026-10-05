import 'package:flutter_test/flutter_test.dart';
import 'package:quranic_competition/core/utils/validators.dart';

void main() {
  test('emails valides, y compris extensions longues et espaces', () {
    expect(Validators.isValidEmail('ali@mail.com'), isTrue);
    expect(Validators.isValidEmail('ali.b@site.online'), isTrue);
    expect(Validators.isValidEmail('ali@mail.mr '), isTrue);
  });

  test('emails invalides', () {
    expect(Validators.isValidEmail('ali@mail'), isFalse);
    expect(Validators.isValidEmail('ali mail@x.com'), isFalse);
    expect(Validators.isValidEmail(''), isFalse);
  });
}
