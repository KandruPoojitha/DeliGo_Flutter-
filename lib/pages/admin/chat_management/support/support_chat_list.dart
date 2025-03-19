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

        Map<dynamic, dynamic> conversations = 
            snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        
        // Group conversations by user
        Map<String, List<MapEntry<String, Map<String, dynamic>>>> userConversations = {};
        
        conversations.forEach((conversationId, messages) {
          if (messages is Map) {
            // Get the first message to determine the user
            MapEntry<dynamic, dynamic> firstMessage = (messages as Map<dynamic, dynamic>)
                .entries
                .reduce((a, b) => 
                    (a.value['timestamp'] as num) < (b.value['timestamp'] as num) ? a : b);
            
            if (firstMessage.value['senderType'] == userType) {
              String userId = firstMessage.value['senderId'] as String;
              String userName = firstMessage.value['senderName'] as String;
              
              if (!userConversations.containsKey(userId)) {
                userConversations[userId] = [];
              }
              
              userConversations[userId]!.add(MapEntry(
                conversationId as String,
                {
                  'messages': messages,
                  'userName': userName,
                  'userId': userId,
                },
              ));
            }
          }
        });

        // Convert to list and sort by latest message
        List<MapEntry<String, List<MapEntry<String, Map<String, dynamic>>>>> sortedUsers = 
            userConversations.entries.toList();

        // Sort users by their most recent message
        sortedUsers.sort((a, b) {
          DateTime latestA = a.value.map((conv) {
            var messages = conv.value['messages'] as Map<dynamic, dynamic>;
            return messages.entries.map((msg) => 
                DateTime.fromMillisecondsSinceEpoch((msg.value['timestamp'] as num).toInt())
            ).reduce((max, date) => date.isAfter(max) ? date : max);
          }).reduce((max, date) => date.isAfter(max) ? date : max);

          DateTime latestB = b.value.map((conv) {
            var messages = conv.value['messages'] as Map<dynamic, dynamic>;
            return messages.entries.map((msg) => 
                DateTime.fromMillisecondsSinceEpoch((msg.value['timestamp'] as num).toInt())
            ).reduce((max, date) => date.isAfter(max) ? date : max);
          }).reduce((max, date) => date.isAfter(max) ? date : max);

          return latestB.compareTo(latestA);
        });

        return ListView.builder(
          itemCount: sortedUsers.length,
          itemBuilder: (context, index) {
            String userId = sortedUsers[index].key;
            List<MapEntry<String, Map<String, dynamic>>> userConvs = sortedUsers[index].value;
            
            // Get the most recent conversation
            MapEntry<String, Map<String, dynamic>> latestConv = userConvs.reduce((a, b) {
              DateTime latestA = (a.value['messages'] as Map<dynamic, dynamic>)
                  .entries
                  .map((msg) => DateTime.fromMillisecondsSinceEpoch((msg.value['timestamp'] as num).toInt()))
                  .reduce((max, date) => date.isAfter(max) ? date : max);

              DateTime latestB = (b.value['messages'] as Map<dynamic, dynamic>)
                  .entries
                  .map((msg) => DateTime.fromMillisecondsSinceEpoch((msg.value['timestamp'] as num).toInt()))
                  .reduce((max, date) => date.isAfter(max) ? date : max);

              return latestA.isAfter(latestB) ? a : b;
            });

            // Get the latest message
            var messages = latestConv.value['messages'] as Map<dynamic, dynamic>;
            var latestMessage = messages.entries.reduce((a, b) => 
                (a.value['timestamp'] as num) > (b.value['timestamp'] as num) ? a : b);

            bool hasUnread = messages.entries
                .where((msg) => msg.value['senderType'] == userType)
                .any((msg) => !(msg.value['isRead'] as bool? ?? false));

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Text(latestConv.value['userName'].toString()[0].toUpperCase()),
                ),
                title: Text(latestConv.value['userName'].toString()),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latestMessage.value['message'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasUnread)
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatDetailPage(
                        userId: userId,
                        userName: latestConv.value['userName'].toString(),
                        userType: userType,
                        conversationId: latestConv.key,
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
} 