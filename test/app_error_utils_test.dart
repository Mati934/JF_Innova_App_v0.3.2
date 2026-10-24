import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/core/errors/app_error_utils.dart';

void main() {
  group('AppErrorUtils', () {
    test('newCode genera formato con prefijo', () {
      final code = AppErrorUtils.newCode(scope: 'sync');

      expect(code.startsWith('SYN-'), true);
      expect(code.length > 10, true);
    });

    test('messageWithCode concatena codigo en nueva linea', () {
      const msg = 'Error al sincronizar';
      const code = 'SNC-20260803-101010-ABCD';

      final out = AppErrorUtils.messageWithCode(msg, code);

      expect(out, contains(msg));
      expect(out, contains('Codigo: $code'));
    });
  });
}
