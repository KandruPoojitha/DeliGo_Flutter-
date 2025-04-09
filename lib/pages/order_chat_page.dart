import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class OrderChatPage extends StatefulWidget {
  final String orderId;
  final String restaurantId;
  final String restaurantName;
  final String customerName;
  final String userType; // 'customer' or 'restaurant'

  const OrderChatPage({
    Key? key,
    required this.orderId,
    required this.restaurantId,
    required this.restaurantName,
    required this.customerName,
    required this.userType,
  }) : super(key: key);

  @override
  State<OrderChatPage> createState() => _OrderChatPageState();
}

class _OrderChatPageState extends State<OrderChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final DatabaseReference _messagesRef;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;
  
  // Local variables to store updated names
  String _customerName = '';
  String _restaurantName = '';

  @override
  void initState() {
    super.initState();
    // Initialize with widget values
    _customerName = widget.customerName;
    _restaurantName = widget.restaurantName;
    
    _messagesRef = FirebaseDatabase.instance
        .ref()
        .child('orders')
        .child(widget.orderId)
        .child('messages');
    
    // Fetch the latest order data to ensure we have correct names
    _fetchOrderDetails();
    
    _scrollToBottom();
    _markAllMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final newMessageRef = _messagesRef.push();

      String senderName = widget.userType == 'customer' 
          ? _customerName 
          : _restaurantName;
      
      String senderId = _currentUser?.uid ?? '';

      await newMessageRef.set({
        'message': message,
        'timestamp': ServerValue.timestamp,
        'senderId': senderId,
        'senderName': senderName,
        'senderType': widget.userType,
        'isRead': false,
      });

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatTimestamp(int timestamp) {
    final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('h:mm a').format(dateTime);
  }

  // Mark all messages from the other user as read
  Future<void> _markAllMessagesAsRead() async {
    try {
      final snapshot = await _messagesRef.get();
      if (snapshot.exists) {
        final messages = snapshot.value as Map<dynamic, dynamic>;
        for (final entry in messages.entries) {
          final message = entry.value as Map<dynamic, dynamic>;
          final messageId = entry.key;
          final senderType = message['senderType'] as String? ?? '';
          
          // Only mark messages from the other user as read
          if (senderType != widget.userType && message['isRead'] == false) {
            await _messagesRef.child(messageId).update({'isRead': true});
          }
        }
      }
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  // Fetch the latest order details to ensure customer name is correct
  Future<void> _fetchOrderDetails() async {
    try {
      final orderSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('orders')
          .child(widget.orderId)
          .get();
      
      if (orderSnapshot.exists) {
        final orderData = orderSnapshot.value as Map<dynamic, dynamic>;
        if (mounted) {
          setState(() {
            // Update customer name if it exists in the order
            if (orderData['customerName'] != null) {
              _customerName = orderData['customerName'];
            }
            
            // Update restaurant name if needed (for customer view)
            if (orderData['restaurantName'] != null) {
              _restaurantName = orderData['restaurantName'];
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching order details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String otherUserName = widget.userType == 'customer' 
        ? _restaurantName 
        : _customerName;
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(otherUserName),
            Text(
              'Order #${widget.orderId.substring(0, 8)}...',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _messagesRef.orderByChild('timestamp').onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                  return const Center(child: Text('No messages yet'));
                }

                try {
                  Map<dynamic, dynamic> messages = 
                      snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

                  List<MapEntry<dynamic, dynamic>> chatMessages = messages.entries.toList();
                  chatMessages.sort((a, b) => 
                      (a.value['timestamp'] as num).compareTo(b.value['timestamp'] as num));
                  
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatMessages.length,
                    itemBuilder: (context, index) {
                      final message = chatMessages[index].value as Map<dynamic, dynamic>;
                      final String senderType = message['senderType'] as String? ?? '';
                      final String senderName = message['senderName'] as String? ?? '';
                      final String messageText = message['message'] as String? ?? '';
                      final int timestamp = message['timestamp'] as int? ?? 0;
                      final bool isCurrentUser = senderType == widget.userType;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: isCurrentUser 
                              ? MainAxisAlignment.end 
                              : MainAxisAlignment.start,
                          children: [
                            if (!isCurrentUser) 
                              CircleAvatar(
                                backgroundColor: const Color(0xFFF4A261),
                                radius: 16,
                                child: Text(
                                  senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: isCurrentUser 
                                      ? const Color(0xFFF4A261) 
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isCurrentUser)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          senderName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: isCurrentUser 
                                                ? Colors.white 
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      messageText,
                                      style: TextStyle(
                                        color: isCurrentUser 
                                            ? Colors.white 
                                            : Colors.black87,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        _formatTimestamp(timestamp),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isCurrentUser 
                                              ? Colors.white.withOpacity(0.7) 
                                              : Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isCurrentUser) 
                              CircleAvatar(
                                backgroundColor: const Color(0xFFF4A261),
                                radius: 16,
                                child: Text(
                                  senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                } catch (e) {
                  return Center(child: Text('Error loading messages: $e'));
                }
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFF4A261),
                          ),
                        )
                      : const Icon(Icons.send, color: Color(0xFFF4A261)),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 