import 'package:flutter/material.dart';
import 'support_chat_list.dart';

class SupportChatPage extends StatelessWidget {
  const SupportChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Support Chats'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Customer Support'),
              Tab(text: 'Driver Support'),
              Tab(text: 'Restaurant Support'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SupportChatList(userType: 'customer'),
            SupportChatList(userType: 'driver'),
            SupportChatList(userType: 'restaurant'),
          ],
        ),
      ),
    );
  }
} 