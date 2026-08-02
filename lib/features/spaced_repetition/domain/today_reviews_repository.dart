import 'review_item.dart';

/// Bugün tekrar zamanı gelen soruları sağlayan veri kaynağı.
///
/// MVP'de bellek içi (mock) bir uygulama kullanılır. İleride bu arayüz
/// değişmeden yerel veritabanı (drift) veya uzak bir backend (ör. Supabase)
/// ile değiştirilebilir.
abstract interface class TodayReviewsRepository {
  /// [today] gününe kadar (dahil) tekrarı gelen soruları döndürür.
  Future<List<ReviewItem>> dueReviews({required DateTime today});
}
