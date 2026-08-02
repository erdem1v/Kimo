import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Hata bankasının Supabase uygulaması: `mistakes` tablosu + `mistake-photos`
/// (özel) storage bucket'ı. Yalnızca Supabase yapılandırılmışken kullanılır.
class MistakeRepository {
  MistakeRepository._();
  static final MistakeRepository instance = MistakeRepository._();

  static const String _bucket = 'mistake-photos';

  SupabaseClient get _client => Supabase.instance.client;

  /// Kullanıcının hatalarını (en yeni önce) getirir. Fotoğraflar için kısa
  /// ömürlü imzalı URL üretir (bucket özel).
  Future<List<MistakeEntry>> fetch() async {
    final List<Map<String, dynamic>> rows = await _client
        .from('mistakes')
        .select()
        .order('created_at', ascending: false);

    final List<MistakeEntry> result = <MistakeEntry>[];
    for (final Map<String, dynamic> row in rows) {
      final String? path = row['photo_path'] as String?;
      String? url;
      if (path != null) {
        url = await _client.storage.from(_bucket).createSignedUrl(path, 3600);
      }
      result.add(
        MistakeEntry(
          subject: row['subject'] as String,
          concept: row['concept'] as String,
          type: MistakeType.fromDb(row['mistake_type'] as String),
          note: (row['note'] as String?) ?? '',
          date: DateTime.parse(row['created_at'] as String),
          hasPhoto: path != null,
          photoUrl: url,
        ),
      );
    }
    return result;
  }

  /// Yeni hata ekler; fotoğraf varsa önce Storage'a yükler.
  Future<void> add({
    required String subject,
    required String concept,
    required MistakeType type,
    required String note,
    Uint8List? imageBytes,
  }) async {
    String? path;
    if (imageBytes != null) {
      final String uid = _client.auth.currentUser!.id;
      path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from(_bucket).uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
    }

    await _client.from('mistakes').insert(<String, dynamic>{
      'subject': subject,
      'concept': concept,
      'mistake_type': type.dbValue,
      'note': note.isEmpty ? null : note,
      'photo_path': path,
    });
  }
}

final MistakeRepository mistakeRepository = MistakeRepository.instance;
