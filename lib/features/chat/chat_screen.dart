import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../services/sound_service.dart';
import '../../theme/app_colors.dart';

/// Koç sohbet ekranı (mock chatbot). Kullanıcı yazar, kısa bir "yazıyor"
/// animasyonundan sonra hazır bir koç yanıtı gelir. Gerçek AI bağlantısı
/// ileride sunucu tarafı bir gateway üzerinden eklenecek.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = List<ChatMessage>.from(MockData.initialChat);
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _typing = false;
  int _replyIndex = 0;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _replyFor(String text) {
    final String t = text.toLowerCase();
    if (t.contains('motive') || t.contains('moral')) return MockData.coachReplies[2];
    if (t.contains('açıkla') || t.contains('konu') || t.contains('anlat')) {
      return MockData.coachReplies[3];
    }
    if (t.contains('çalış') || t.contains('ne yap') || t.contains('bugün')) {
      return MockData.coachReplies[0];
    }
    final String reply = MockData.coachReplies[_replyIndex % MockData.coachReplies.length];
    _replyIndex++;
    return reply;
  }

  Future<void> _send(String raw) async {
    final String text = raw.trim();
    if (text.isEmpty) return;
    sound.tap();
    setState(() {
      _messages.add(ChatMessage(text, isUser: true));
      _input.clear();
      _typing = true;
    });
    _scrollToEnd();

    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (!mounted) return;
    setState(() {
      _typing = false;
      _messages.add(ChatMessage(_replyFor(text)));
    });
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: AppColors.blueBg, shape: BoxShape.circle),
              child: const Text('🦉', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const <Widget>[
                Text('Koç Baykuş',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                Text('çevrimiçi',
                    style: TextStyle(fontSize: 12, color: AppColors.green)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          const Divider(height: 1, color: AppColors.line),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              itemCount: _messages.length + (_typing ? 1 : 0),
              itemBuilder: (BuildContext context, int i) {
                if (_typing && i == _messages.length) return const _TypingBubble();
                return _bubble(context, _messages[i]);
              },
            ),
          ),
          _quickReplies(),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, ChatMessage m) {
    final double maxW = MediaQuery.of(context).size.width * 0.76;
    final bool user = m.isUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxW),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: user ? AppColors.green : const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(user ? 18 : 4),
            bottomRight: Radius.circular(user ? 4 : 18),
          ),
        ),
        child: Text(
          m.text,
          style: TextStyle(
            color: user ? Colors.white : AppColors.ink,
            fontSize: 15,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _quickReplies() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: <Widget>[
          for (final String q in MockData.quickReplies)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(q),
                labelStyle: const TextStyle(
                    color: AppColors.blueDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
                backgroundColor: AppColors.blueBg,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                onPressed: () => _send(q),
              ),
            ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _input,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              decoration: InputDecoration(
                hintText: 'Koçuna bir şey yaz...',
                filled: true,
                fillColor: const Color(0xFFF4F4F4),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _send(_input.text),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Koç yazarken görünen üç noktalı animasyon.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: Color(0xFFF1F1F1),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (BuildContext context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: _dot(i),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dot(int i) {
    final double phase = (_c.value + i * 0.2) % 1.0;
    final double t = (phase < 0.5 ? phase : 1 - phase) * 2; // 0..1..0
    return Transform.translate(
      offset: Offset(0, -4 * t),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.inkLight.withValues(alpha: 0.4 + 0.6 * t),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
