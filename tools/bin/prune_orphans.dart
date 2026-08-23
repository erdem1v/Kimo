import 'dart:io';

import 'supabase_admin.dart';

/// Depoda kalmış sahipsiz hazır soru fotoğraflarını siler.
///
///   dart run bin/prune_orphans.dart --dry-run
///   dart run bin/prune_orphans.dart
///
/// Sahipsiz = `mistakes` tablosunda o yola işaret eden satır yok. Bu ancak
/// soruları SQL ile sildikten sonra oluşur. Yalnızca sistem hesabının
/// `<uid>/meb/` klasörüne bakar; gerçek kullanıcıların fotoğraflarına
/// dokunmaz.
///
/// Ortam değişkenleri gerekir: SUPABASE_URL, SUPABASE_SERVICE_KEY
Future<void> main(List<String> args) async {
  final bool dryRun = args.contains('--dry-run');
  final SupabaseAdmin admin = await SupabaseAdmin.fromEnv();
  stdout.writeln('Havuz hesabı: ${admin.ownerId}');

  final List<String> orphans = await admin.findOrphans('meb');
  if (orphans.isEmpty) {
    stdout.writeln('Sahipsiz fotoğraf yok.');
    return;
  }

  stdout.writeln('Sahipsiz fotoğraf: ${orphans.length}');
  for (final String p in orphans.take(10)) {
    stdout.writeln('  $p');
  }
  if (orphans.length > 10) {
    stdout.writeln('  ... ve ${orphans.length - 10} tane daha');
  }

  if (dryRun) {
    stdout.writeln('\nKURU ÇALIŞMA — hiçbir şey silinmedi.');
    return;
  }
  await admin.deleteObjects(orphans);
  stdout.writeln('\n${orphans.length} fotoğraf silindi.');
}
