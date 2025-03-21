import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../chat_detail_page.dart';

class SupportChatList extends StatelessWidget {
  final String userType;
  
  const SupportChatList({super.key, required this.userType});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseDatabase.instance
          .ref()
          .child('chat_management')
          .child('messages')
          .onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return Center(child: Text('No ${userType} chats available'));
        }

        Map<dynamic, dynamic> allMessages = 
            snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        
        // Group messages by userId
        Map<String, Map<String, dynamic>> userChats = {};
        
        allMessages.forEach((userId, messages) {
          if (messages is Map) {
            Map<dynamic, dynamic> userMessages = messages as Map<dynamic, dynamic>;
            
            // Get user info from any message in the conversation
            var firstMessage = userMessages.values.first;
            String userName = firstMessage['senderName'] as String;
            String messageUserType = firstMessage['senderType'] as String;
            
            print('Debug - User: $userName, Type: $messageUserType, Requested Type: $userType'); // Debug print
            
            // Include if it matches the requested user type
            // For customers, include if senderType is not 'driver' or 'restaurant'
            bool shouldInclude = userType == 'customer' 
                ? (messageUserType != 'driver' && messageUserType != 'restaurant')
                : messageUserType == userType;
                
            if (shouldInclude) {
              // Get the latest message
              var latestMessage = userMessages.entries.reduce((a, b) => 
                (a.value['timestamp'] as num) > (b.value['timestamp'] as num) ? a : b);
              
              // Check for unread messages
              bool hasUnread = userMessages.values.any((message) => 
                !(message['isRead'] as bool? ?? false)
              );
              
              userChats[userId] = {
                'userName': userName,
                'lastMessage': latestMessage.value['message'],
                'timestamp': latestMessage.value['timestamp'],
                'hasUnread': hasUnread,
                'messages': userMessages,
              };
            }
          }
        });

        if (userChats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${userType} chats available',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        // Convert to list and sort by timestamp
        var sortedChats = userChats.entries.toList()
          ..sort((a, b) => (b.value['timestamp'] as num)
              .compareTo(a.value['timestamp'] as num));

        return ListView.builder(
          itemCount: sortedChats.length,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final chat = sortedChats[index];
            final userId = chat.key;
            final chatData = chat.value;
            
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFF4A261),
                  child: Text(chatData['userName'].toString()[0].toUpperCase()),
                ),
                title: Text(chatData['userName'].toString()),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chatData['lastMessage'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (chatData['hasUnread'])
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red),
                        ),
                        child: const Text(
                          'New Message',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: Text(
                  _formatTimestamp(chatData['timestamp'] as num),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatDetailPage(
                        userId: userId,
                        userName: chatData['userName'],
                        userType: userType,
                        conversationId: userId,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
  
  String _formatTimestamp(num timestamp) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
} 