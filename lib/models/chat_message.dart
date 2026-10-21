/// A single chat bubble or action card in the Ell-ena assistant transcript.
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isCard;
  final String? cardType;
  final Map<String, dynamic>? cardData;
  final String? avatarUrl;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isCard = false,
    this.cardType,
    this.cardData,
    this.avatarUrl,
  });
}
