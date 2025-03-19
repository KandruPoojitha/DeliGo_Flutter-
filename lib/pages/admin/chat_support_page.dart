import 'package:flutter/material.dart';
import 'chat_management/support/support_chat_list.dart';

class ChatSupportPage extends StatelessWidget {
  final String userType;
  
  const ChatSupportPage({
    super.key,
    required this.userType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SupportChatList(userType: userType),
    );
  }
} 