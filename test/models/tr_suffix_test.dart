import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/models/tr_suffix.dart';

/// Türkçe bulunma hâli eki saf bir tablo; testi de saf.
///
/// NEDEN BU TEST VAR: tasarımın verdiği iki örnek (`14:30'da`, `1 Ekim'de`)
/// doğru ama değerler keyfî. Sabit bir `'da` yazmak üretilen zamanların
/// kabaca yarısını bozardı ve bu, hiçbir derleyici hatası vermeden olurdu.
void main() {
  _dativeTests();
  group('saat — dakika 0 DEĞİLSE ek dakikadan gelir', () {
    const Map<String, String> cases = <String, String>{
      '14:30': "14:30'da",   // otuz
      '14:05': "14:05'te",   // beş
      '14:20': "14:20'de",   // yirmi
      '14:45': "14:45'te",   // beş
      '09:40': "09:40'ta",   // kırk  → SERT ünsüz, 'ta
      '23:01': "23:01'de",   // bir
      '07:50': "07:50'de",   // elli
      '12:09': "12:09'da",   // dokuz
      '18:13': "18:13'te",   // üç
      '21:24': "21:24'te",   // dört
      '06:16': "06:16'da",   // altı
      '11:07': "11:07'de",   // yedi
      '03:18': "03:18'de",   // sekiz
      '19:02': "19:02'de",   // iki
    };
    cases.forEach((String input, String expected) {
      test('$input → $expected', () {
        expect(trLocativeTime(input), expected);
      });
    });
  });

  group('saat — dakika 0 İSE ek saatten gelir (24 saatin hepsi)', () {
    const Map<String, String> cases = <String, String>{
      '00:00': "00:00'da",   // sıfır
      '01:00': "01:00'de",   // bir
      '02:00': "02:00'de",   // iki
      '03:00': "03:00'te",   // üç    → sert
      '04:00': "04:00'te",   // dört  → sert
      '05:00': "05:00'te",   // beş   → sert
      '06:00': "06:00'da",   // altı
      '07:00': "07:00'de",   // yedi
      '08:00': "08:00'de",   // sekiz
      '09:00': "09:00'da",   // dokuz
      '10:00': "10:00'da",   // on
      '11:00': "11:00'de",   // on bir
      '12:00': "12:00'de",   // on iki
      '13:00': "13:00'te",   // on üç
      '14:00': "14:00'te",   // on dört
      '15:00': "15:00'te",   // on beş
      '16:00': "16:00'da",   // on altı
      '17:00': "17:00'de",   // on yedi
      '18:00': "18:00'de",   // on sekiz
      '19:00': "19:00'da",   // on dokuz
      '20:00': "20:00'de",   // yirmi
      '21:00': "21:00'de",   // yirmi bir
      '22:00': "22:00'de",   // yirmi iki
      '23:00': "23:00'te",   // yirmi üç
    };
    cases.forEach((String input, String expected) {
      test('$input → $expected', () {
        expect(trLocativeTime(input), expected);
      });
    });
  });

  group('saat — bozuk girdi hiçbir şey döndürmez', () {
    for (final String? bad in <String?>[
      null, '', '14', '14:60', '24:00', '-1:00', 'ab:cd', '14:30:00',
    ]) {
      test('${bad ?? "null"} → null', () {
        expect(trLocativeTime(bad), isNull);
      });
    }
  });

  group('ay — on iki ayın hepsi', () {
    const Map<int, String> cases = <int, String>{
      1: "1 Ocak'ta",
      2: "1 Şubat'ta",
      3: "1 Mart'ta",
      4: "1 Nisan'da",
      5: "1 Mayıs'ta",
      6: "1 Haziran'da",
      7: "1 Temmuz'da",
      8: "1 Ağustos'ta",
      9: "1 Eylül'de",
      10: "1 Ekim'de",
      11: "1 Kasım'da",
      12: "1 Aralık'ta",
    };
    cases.forEach((int month, String expected) {
      test('ay $month → $expected', () {
        expect(trLocativeMonthDay(DateTime(2026, month, 1)), expected);
      });
    });

    test('gün numarası olduğu gibi geçiyor', () {
      expect(trLocativeMonthDay(DateTime(2026, 10, 27)), "27 Ekim'de");
    });

    test('null → null', () {
      expect(trLocativeMonthDay(null), isNull);
    });
  });
}

/// Yönelme hâli eki — takma adlar (Task 16).
void _dativeTests() {
  group('trDative', () {
    test('ünsüzle biten ad: kaynaştırma YOK', () {
      expect(trDative('Berk'), "Berk'e");
      expect(trDative('Burak'), "Burak'a");
      expect(trDative('Deniz'), "Deniz'e");
    });

    test('ünlüyle biten ad: kaynaştırma y GİRİYOR', () {
      // Bu satır hatanın ta kendisiydi: ekranda "Ayla''e" yazıyordu.
      expect(trDative('Ayla'), "Ayla'ya");
      expect(trDative('Ece'), "Ece'ye");
      expect(trDative('Tugba'), "Tugba'ya");
    });

    test('ek SON ünlüye göre kalınlaşıyor', () {
      expect(trDative('Elif'), "Elif'e");
      expect(trDative('Mustafa'), "Mustafa'ya");
      expect(trDative('Zeynep'), "Zeynep'e");
      expect(trDative('Oğuz'), "Oğuz'a");
    });

    test('bozuk girdide delik açmıyor', () {
      expect(trDative(''), '');
      expect(trDative('  Ayla  '), "Ayla'ya");
      // Ünlüsüz girdi Türkçede yok; yine de bir cümle üretilmeli.
      expect(trDative('42'), "42'e");
    });

    test('ÇIKTIDA ÇİFT KESME YOK', () {
      // ARB'deki `''` kaçışı ekrana literal olarak düşüyordu.
      for (final String n in <String>['Ayla', 'Berk', 'Ece']) {
        expect(trDative(n), isNot(contains("''")));
      }
    });
  });
}
