import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/models.dart';

/// Hata bankasının bellek içi (mock) deposu. Yeni hata eklendiğinde dinleyen
/// ekranlar güncellenir.
class MistakeStore extends ChangeNotifier {
  MistakeStore._() : _items = MockData.seedMistakes();
  static final MistakeStore instance = MistakeStore._();

  final List<MistakeEntry> _items;

  List<MistakeEntry> get items => List<MistakeEntry>.unmodifiable(_items);
  int get count => _items.length;

  void add(MistakeEntry entry) {
    _items.insert(0, entry);
    notifyListeners();
  }
}

final MistakeStore mistakeStore = MistakeStore.instance;
