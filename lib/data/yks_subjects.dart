import '../state/user_profile.dart';

/// Sınav + müfredat bazında DERS listesi (client tarafı; konu ağacı Edge
/// Function'daki taxonomy.ts'te). "Bugün" ekranında tüm dersleri (soru olmasa
/// bile) sırayla göstermek için kullanılır.
class YksSubjects {
  const YksSubjects._();

  static const List<String> _eskiTyt = <String>[
    'Türkçe', 'Matematik', 'Geometri', 'Fizik', 'Kimya', 'Biyoloji',
    'Tarih', 'Coğrafya', 'Felsefe', 'Din Kültürü',
  ];

  static const List<String> _eskiAyt = <String>[
    'Matematik', 'Geometri', 'Fizik', 'Kimya', 'Biyoloji', 'Edebiyat',
    'Tarih', 'Coğrafya', 'Felsefe Grubu', 'Din Kültürü',
  ];

  static const List<String> _maarifTyt = <String>[
    'Türkçe', 'Matematik', 'Fizik', 'Kimya', 'Biyoloji',
    'Tarih', 'Coğrafya', 'Felsefe', 'Din Kültürü',
  ];

  static const List<String> _maarifAyt = <String>[
    'Matematik', 'Fizik', 'Kimya', 'Biyoloji', 'Edebiyat', 'Tarih', 'Coğrafya',
  ];

  /// [curriculum] ('eski'|'maarif') ve [exam] ('TYT'|'AYT') için ders adları.
  static List<String> forExam(String curriculum, String exam) {
    final bool maarif = curriculum == UserProfile.maarif;
    if (exam == 'AYT') return maarif ? _maarifAyt : _eskiAyt;
    return maarif ? _maarifTyt : _eskiTyt;
  }
}
