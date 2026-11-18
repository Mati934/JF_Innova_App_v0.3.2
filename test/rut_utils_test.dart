import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/core/utils/rut_utils.dart';

void main() {
  group('RutUtils.normalize', () {
    test('elimina puntos, guiones y espacios', () {
      expect(RutUtils.normalize('12.345.678-9'), '123456789');
    });

    test('pasa a minúscula', () {
      expect(RutUtils.normalize('12.345.678-K'), '12345678k');
    });

    test('elimina espacios y whitespace', () {
      expect(RutUtils.normalize('  12.345.678-9  '), '123456789');
    });

    test('elimina \\r\\n', () {
      expect(RutUtils.normalize('12345678-9\r\n'), '123456789');
    });

    test('elimina soft hyphens', () {
      expect(RutUtils.normalize('12345678\u00AD9'), '123456789');
    });

    test('maneja null y vacío', () {
      expect(RutUtils.normalize(null), '');
      expect(RutUtils.normalize(''), '');
    });

    test('sin formato devuelve igual (ya normalizado)', () {
      expect(RutUtils.normalize('123456789'), '123456789');
    });
  });

  group('RutUtils.isValid', () {
    // RUT: 11.111.111-1
    // Body: 11111111
    // 1*2+1*3+1*4+1*5+1*6+1*7+1*2+1*3 = 32
    // 11 - (32 % 11) = 11 - 10 = 1 → dígito "1" ✓
    test('acepta RUT válido 11.111.111-1', () {
      expect(RutUtils.isValid('11.111.111-1'), true);
    });

    // RUT: 12.345.678-5
    // Body: 12345678
    // 8*2+7*3+6*4+5*5+4*6+3*7+2*2+1*3 = 16+21+24+25+24+21+4+3 = 138
    // 11 - (138 % 11) = 11 - 6 = 5 → dígito "5" ✓
    test('acepta RUT válido 12.345.678-5', () {
      expect(RutUtils.isValid('12.345.678-5'), true);
    });

    test('acepta RUT sin formato', () {
      expect(RutUtils.isValid('123456785'), true);
    });

    test('rechaza RUT con dígito verificador incorrecto', () {
      expect(RutUtils.isValid('12.345.678-0'), false);
      expect(RutUtils.isValid('12.345.678-9'), false);
    });

    // RUT con dígito K
    // Body: 22222222
    // 2*2+2*3+2*4+2*5+2*6+2*7+2*2+2*3 = 4+6+8+10+12+14+4+6 = 64
    // 11 - (64 % 11) = 11 - 9 = 2 → dígito "2", no es K
    // Busquemos un RUT con K: Body 44444444
    // 4*2+4*3+4*4+4*5+4*6+4*7+4*2+4*3 = 8+12+16+20+24+28+8+12 = 128
    // 11 - (128 % 11) = 11 - 7 = 4 → dígito "4"
    // Body: 10034579
    // 9*2+7*3+5*4+4*5+3*6+0*7+0*2+1*3 = 18+21+20+20+18+0+0+3 = 100
    // 11 - (100 % 11) = 11 - 1 = 10 → dígito "k"
    test('acepta RUT con dígito verificador K', () {
      expect(RutUtils.isValid('10.034.579-K'), true);
      expect(RutUtils.isValid('10034579k'), true);
    });

    // Body: 11111112
    // 2*2+1*3+1*4+1*5+1*6+1*7+1*2+1*3 = 4+3+4+5+6+7+2+3 = 34
    // 11 - (34 % 11) = 11 - 1 = 10 → dígito "k"
    test('acepta otro RUT con K', () {
      expect(RutUtils.isValid('11.111.112-K'), true);
    });

    // Body: 33333333
    // 3*2+3*3+3*4+3*5+3*6+3*7+3*2+3*3 = 6+9+12+15+18+21+6+9 = 96
    // 11 - (96 % 11) = 11 - 8 = 3 → dígito "3"
    // Pero let's find one with digit = 0
    // When remainder = 11, digit = '0'
    // 11 - (sum%11) = 11 → sum%11 = 0
    // Body: 11111110
    // 0*2+1*3+1*4+1*5+1*6+1*7+1*2+1*3 = 0+3+4+5+6+7+2+3 = 30
    // 11 - (30 % 11) = 11 - 8 = 3 → not 0
    // Body: 16622668
    // 8*2+6*3+6*4+2*5+2*6+6*7+6*2+1*3 = 16+18+24+10+12+42+12+3 = 137
    // 11 - (137 % 11) = 11 - 5 = 6 → not 0
    // Mejor: sum%11==0 → sum is multiple of 11
    // Body: 11111127
    // 7*2+2*3+1*4+1*5+1*6+1*7+1*2+1*3 = 14+6+4+5+6+7+2+3 = 47
    // nope. Let me just test a known one:
    // Body: 22174484
    // 4*2+8*3+4*4+4*5+7*6+1*7+2*2+2*3 = 8+24+16+20+42+7+4+6 = 127
    // nope. This is getting complex, let's just test with isValid directly.

    test('rechaza RUT muy corto', () {
      expect(RutUtils.isValid('1234567'), false);
    });

    test('rechaza RUT vacío o null', () {
      expect(RutUtils.isValid(''), false);
      expect(RutUtils.isValid(null), false);
    });

    test('rechaza RUT con letras en el cuerpo', () {
      expect(RutUtils.isValid('1234A678-5'), false);
    });
  });

  group('RutUtils.format', () {
    test('formatea RUT normalizado corto (8 chars)', () {
      // Body 7 digits: 1.234.567-8
      expect(RutUtils.format('12345678'), '1.234.567-8');
    });

    test('formatea RUT normalizado largo (9 chars)', () {
      expect(RutUtils.format('123456785'), '12.345.678-5');
    });

    test('formatea K en mayúscula', () {
      expect(RutUtils.format('10034579k'), '10.034.579-K');
    });

    test('maneja vacío', () {
      expect(RutUtils.format(''), '');
      expect(RutUtils.format(null), '');
    });

    test('formatea desde RUT con formato (normaliza primero)', () {
      expect(RutUtils.format('12.345.678-5'), '12.345.678-5');
    });
  });

  group('RutInputFormatter', () {
    final formatter = RutInputFormatter();

    TextEditingValue apply(String text) {
      return formatter.formatEditUpdate(
        const TextEditingValue(),
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );
    }

    test('formatea mientras se escribe', () {
      expect(apply('12345').text, '12.345');
      expect(apply('1234567').text, '1.234.567');
      expect(apply('12345678').text, '1.234.567-8');
      expect(apply('123456785').text, '12.345.678-5');
    });

    test('maneja K como dígito verificador', () {
      expect(apply('12345678k').text, '12.345.678-K');
      expect(apply('12345678K').text, '12.345.678-K');
    });

    test('limita a 9 caracteres', () {
      expect(apply('1234567890').text, '12.345.678-9');
    });

    test('maneja entrada vacía', () {
      expect(apply('').text, '');
    });
  });
}
