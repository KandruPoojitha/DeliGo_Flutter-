import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class UnreadMessageCount extends StatelessWidget {
  final String orderId;
  final String userType; // 'customer' or 'restaurant'
  final bool isGroupChat; // Whether this is for group chat messages

  const UnreadMessageCount({
    Key? key,
    required this.orderId,
    required this.userType,
    this.isGroupChat = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref()
          .child('orders')
          .child(orderId)
          .child(isGroupChat ? 'group_chat' : 'messages')
          .onValue,
      builder: (context, snapshot) {
        // If there's an error or no data, don't show anything
        if (snapshot.hasError || !snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const SizedBox.shrink();
        }

        try {
          final messages = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          
          // Count unread messages from the other user type
          int unreadCount = 0;
          for (final message in messages.values) {
            if (message is Map<dynamic, dynamic> && 
                message['senderType'] != userType && 
                message['isRead'] == false) {
              unreadCount++;
            }
          }
          
          if (unreadCount > 0) {
            return Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                unreadCount > 9 ? '9+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint('Error calculating unread messages: $e');
        }
        
        return const SizedBox.shrink();
      },
    );
  }
} 