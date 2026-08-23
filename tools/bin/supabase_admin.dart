import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Supabase'e yönetici yetkisiyle yazar (service_role).
///
/// GÜVENLİK: service_role anahtarı RLS'i tamamen atlar. Yalnızca ortam
/// değişkeninden okunur; dosyaya yazılmaz, depoya girmez, uygulamaya asla
/// konmaz. Bu araç senin bilgisayarında elle çalıştırılır.
class SupabaseAdmin {
  SupabaseAdmin._(this._baseUrl, this._key, this.ownerId);

  final String _baseUrl;
  final String _key;

  /// Hazır soruların sahibi olacak sistem hesabı (app_config.osym_user_id).
  final String ownerId;

  static const String _bucket = 'mistake-photos';

  Map<String, String> get _headers => <String, String>{
    'apikey': _key,
    'Authorization': 'Bearer $_key',
  };

  static Future<SupabaseAdmin> fromEnv() async {
    final String? url = Platform.environment['SUPABASE_URL'];
    final String? key = Platform.environment['SUPABASE_SERVICE_KEY'];
    if (url == null || key == null) {
      throw Exception(
        'SUPABASE_URL ve SUPABASE_SERVICE_KEY ortam değişkenleri gerekli. '
        'Bkz. tools/README.md',
      );
    }
    final String base = url.replaceAll(RegExp(r'/+$'), '');

    // Sistem hesabının kimliği 0025 göçünde app_config'e yazılmıştı.
    final http.Response r = await http.get(
      Uri.parse('$base/rest/v1/app_config?key=eq.osym_user_id&select=value'),
      headers: <String, String>{'apikey': key, 'Authorization': 'Bearer $key'},
    );
    if (r.statusCode != 200) {
      throw Exception('app_config okunamadı (${r.statusCode}): ${r.body}');
    }
    final List<dynamic> rows = jsonDecode(r.body) as List<dynamic>;
    if (rows.isEmpty) {
      throw Exception(
        'Sistem hesabı ayarlanmamış. Önce set_osym_account() çalıştır '
        '(bkz. 0025_official_questions.sql).',
      );
    }
    final String owner = ((rows.first as Map)['value'] as String).trim();
    return SupabaseAdmin._(base, key, owner);
  }

  /// Bir soruyu havuza koyar: fotoğrafı yükler, satırı yazar.
  ///
  /// Aynı dosya yolu zaten varsa atlanır — betiği ikinci kez çalıştırmak
  /// havuzu kopyalarla doldurmaz.
  Future<void> publishQuestion({
    required List<int> jpeg,
    required String fileName,
    required String exam,
    required String subject,
    required String concept,
    required int correctIndex,
    required String source,
    int? sourceYear,
    String? sourceSession,
  }) async {
    final String path = '$ownerId/$source/$fileName';
    if (await _questionExists(path)) return;

    await _upload(path, jpeg);
    await _insert(<String, dynamic>{
      'user_id': ownerId,
      'subject': subject,
      'concept': concept,
      'exam': exam,
      // Zorunlu bir alan; hazır sorularda "hata türü" kavramı yok.
      'mistake_type': 'kavram_eksikligi',
      'photo_path': path,
      'options': <Map<String, String>>[
        for (final String l in <String>['A', 'B', 'C', 'D', 'E'])
          <String, String>{'label': l, 'text': ''},
      ],
      'correct_index': correctIndex,
      'is_public': true,
      'source': source,
      'source_year': sourceYear,
      'source_session': sourceSession,
    });
  }

  Future<bool> _questionExists(String path) async {
    final http.Response r = await http.get(
      Uri.parse(
        '$_baseUrl/rest/v1/mistakes'
        '?photo_path=eq.${Uri.encodeQueryComponent(path)}&select=id&limit=1',
      ),
      headers: _headers,
    );
    if (r.statusCode != 200) return false;
    return (jsonDecode(r.body) as List<dynamic>).isNotEmpty;
  }

  Future<void> _upload(String path, List<int> bytes) async {
    final http.Response r = await http.post(
      Uri.parse('$_baseUrl/storage/v1/object/$_bucket/$path'),
      headers: <String, String>{
        ..._headers,
        'Content-Type': 'image/jpeg',
        'x-upsert': 'true',
      },
      body: bytes,
    );
    if (r.statusCode >= 300) {
      throw Exception('Fotoğraf yüklenemedi (${r.statusCode}): ${r.body}');
    }
  }

  Future<void> _insert(Map<String, dynamic> row) async {
    final http.Response r = await http.post(
      Uri.parse('$_baseUrl/rest/v1/mistakes'),
      headers: <String, String>{
        ..._headers,
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal',
      },
      body: jsonEncode(row),
    );
    if (r.statusCode >= 300) {
      throw Exception('Soru kaydedilemedi (${r.statusCode}): ${r.body}');
    }
  }
}
