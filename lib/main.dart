import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_yks_coach/app.dart';

void main() {
  // ProviderScope: Riverpod'un tüm sağlayıcıları için kök kapsayıcı.
  runApp(const ProviderScope(child: AiYksCoachApp()));
}
