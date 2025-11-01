class ChatEntry {
  final String text;
  final bool isBot;
  final DateTime time;
  final String? senderName;

  const ChatEntry({
    required this.text,
    required this.isBot,
    required this.time,
    this.senderName,
  });
}
