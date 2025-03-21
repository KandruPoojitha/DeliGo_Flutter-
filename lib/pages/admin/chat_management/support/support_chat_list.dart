import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../admin_chat_page.dart';

class SupportChatList extends StatelessWidget {
  final String userType;

  const SupportChatList({super.key, required this.userType});

  Future<String?> _getUserType(String userId) async {
    try {
      // Check in drivers collection
      final driverSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('drivers')
          .child(userId)
          .get();
      if (driverSnapshot.exists) {
        return 'driver';
      }

      // Check in restaurants collection
      final restaurantSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('restaurants')
          .child(userId)
          .get();
      if (restaurantSnapshot.exists) {
        return 'restaurant';
      }

      // If not found in drivers or restaurants, assume it's a customer
      return 'customer';
    } catch (e) {
      print('Error getting user type: $e');
      return null;
    }
  }

  Future<String> _getUsername(String userId, String userType) async {
    try {
      switch (userType) {
        case 'customer':
          final snapshot = await FirebaseDatabase.instance
              .ref()
              .child('customers')
              .child(userId)
              .child('fullName')
              .get();
          return snapshot.value?.toString() ?? 'Unknown Customer';

        case 'driver':
          final snapshot = await FirebaseDatabase.instance
              .ref()
              .child('drivers')
              .child(userId)
              .child('fullName')
              .get();
          return snapshot.value?.toString() ?? 'Unknown Driver';

        case 'restaurant':
          final snapshot = await FirebaseDatabase.instance
              .ref()
              .child('restaurants')
              .child(userId)
              .child('store_info')
              .child('name')
              .get();
          return snapshot.value?.toString() ?? 'Unknown Restaurant';

        default:
          return 'Unknown User';
      }
    } catch (e) {
      print('Error getting username for $userId ($userType): $e');
      return 'Unknown User';
    }
  }

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
          print('Stream Error: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          print('No data in snapshot');
          return Center(child: Text('No ${userType} chats available'));
        }

        Map<dynamic, dynamic> allMessages =
        snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

        print('All messages: ${allMessages.keys.length} conversations found');

        return FutureBuilder<Map<String, Map<String, dynamic>>>(
          future: Future.wait(
            allMessages.entries.map((entry) async {
              final userId = entry.key;
              final messages = entry.value as Map<dynamic, dynamic>;

              print('Processing userId: $userId');

              // Get the actual user type from Firebase collections
              String? actualUserType = await _getUserType(userId);
              print('User $userId type: $actualUserType');

              // Only include if user type matches the requested tab
              if (actualUserType == userType) {
                var userMessages = messages as Map<dynamic, dynamic>;

                // Get the actual username from the respective collection
                String userName = await _getUsername(userId, actualUserType ?? 'customer');
                print('Got username for $userId: $userName');

                // Get the latest message
                var latestMessage = userMessages.entries.reduce((a, b) =>
                (a.value['timestamp'] as num) > (b.value['timestamp'] as num) ? a : b);

                // Check for unread messages
                bool hasUnread = userMessages.values.any((message) =>
                !(message['isRead'] as bool? ?? false)
                );

                return MapEntry<String, Map<String, dynamic>>(
                  userId,
                  {
                    'userName': userName,
                    'lastMessage': latestMessage.value['message'],
                    'timestamp': latestMessage.value['timestamp'],
                    'hasUnread': hasUnread,
                    'messages': userMessages,
                  },
                );
              }
              return const MapEntry<String, Map<String, dynamic>>('', {});
            }),
          ).then((entries) => Map.fromEntries(entries.where((entry) => entry.key.isNotEmpty))),
          builder: (context, AsyncSnapshot<Map<String, Map<String, dynamic>>> chatSnapshot) {
            if (chatSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!chatSnapshot.hasData || chatSnapshot.data!.isEmpty) {
              print('No chats found for $userType');
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

            print('Found ${chatSnapshot.data!.length} chats for $userType');

            // Convert to list and sort by timestamp
            var sortedChats = chatSnapshot.data!.entries.toList()
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
                          builder: (context) => AdminChatPage(
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