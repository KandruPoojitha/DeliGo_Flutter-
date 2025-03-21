import 'package:flutter/material.dart';
import 'chat_support_page.dart';

class ChatManagementPage extends StatelessWidget {
  const ChatManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chat Management'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Customer Support'),
              Tab(text: 'Driver Support'),
              Tab(text: 'Restaurant Support'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ChatSupportPage(userType: 'customer'),
            ChatSupportPage(userType: 'driver'),
            ChatSupportPage(userType: 'restaurant'),
          ],
        ),
      ),
    );
  }
} 