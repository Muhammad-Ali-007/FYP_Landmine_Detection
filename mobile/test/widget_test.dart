import 'package:flutter_test/flutter_test.dart';
import 'package:landmine_detection/config.dart';

void main() {
  test('backend URL defaults to the local Flask API and has no trailing slash', () {
    expect(apiBaseUrl, 'http://127.0.0.1:5000/flutter');
    expect(apiBaseUrl.endsWith('/'), isFalse);
  });
}
