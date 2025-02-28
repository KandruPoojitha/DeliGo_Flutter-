import 'package:flutter/material.dart';
import '../../../services/admin_service.dart';

class ChatManagementScreen extends StatefulWidget {
  const ChatManagementScreen({Key? key}) : super(key: key);

  @override
  _ChatManagementScreenState createState() => _ChatManagementScreenState();
}

class _ChatManagementScreenState extends State<ChatManagementScreen> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  bool _showOnlyReported = false;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
    });

    final chats = _showOnlyReported
        ? await _adminService.getReportedChats()
        : await _adminService.getAllChats();

    setState(() {
      _chats = chats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Management'),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? const Center(child: Text('No chats found'))
              : ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    final isBlocked = chat['status'] == 'blocked';
                    final isReported = chat['isReported'] == true;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text('${chat['user1Name']} - ${chat['user2Name']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(chat['lastMessage'] ?? 'No messages'),
                            Row(
                              children: [
                                if (isBlocked)
                                  _buildStatusChip('Blocked', Colors.red),
                                if (isReported)
                                  _buildStatusChip('Reported', Colors.orange),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) => _handleChatAction(value, chat),
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem(
                              value: 'view',
                              child: Text('View Chat'),
                            ),
                            if (isReported)
                              const PopupMenuItem(
                                value: 'reports',
                                child: Text('View Reports'),
                              ),
                            PopupMenuItem(
                              value: isBlocked ? 'unblock' : 'block',
                              child: Text(isBlocked ? 'Unblock Chat' : 'Block Chat'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete Chat'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showFilterOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Chats'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Chats'),
              leading: Radio<bool>(
                value: false,
                groupValue: _showOnlyReported,
                onChanged: (value) {
                  setState(() {
                    _showOnlyReported = value!;
                  });
                  Navigator.pop(context);
                  _loadChats();
                },
              ),
            ),
            ListTile(
              title: const Text('Reported Chats Only'),
              leading: Radio<bool>(
                value: true,
                groupValue: _showOnlyReported,
                onChanged: (value) {
                  setState(() {
                    _showOnlyReported = value!;
                  });
                  Navigator.pop(context);
                  _loadChats();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleChatAction(String action, Map<String, dynamic> chat) async {
    final chatId = chat['id'];

    switch (action) {
      case 'view':
        _viewChat(chat);
        break;
      case 'reports':
        _viewReports(chat);
        break;
      case 'block':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Block Chat'),
            content: const Text(
              'Are you sure you want to block this chat? Users will not be able to send messages.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Block'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          final success = await _adminService.blockChat(chatId);
          if (success) {
            _loadChats();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat blocked successfully')),
              );
            }
          }
        }
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Chat'),
            content: const Text(
              'Are you sure you want to delete this chat? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          final success = await _adminService.deleteChat(chatId);
          if (success) {
            _loadChats();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat deleted successfully')),
              );
            }
          }
        }
        break;
    }
  }

  void _viewChat(Map<String, dynamic> chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(chat: chat),
      ),
    );
  }

  void _viewReports(Map<String, dynamic> chat) async {
    final reports = await _adminService.getChatReports(chat['id']);
    
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chat Reports'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return ListTile(
                title: Text('Reported by: ${report['reporterName']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reason: ${report['reason']}'),
                    Text('Status: ${report['status']}'),
                    if (report['resolution'] != null)
                      Text('Resolution: ${report['resolution']}'),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class ChatDetailScreen extends StatelessWidget {
  final Map<String, dynamic> chat;

  const ChatDetailScreen({Key? key, required this.chat}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${chat['user1Name']} - ${chat['user2Name']}'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: const Center(
        child: Text('Chat details will be displayed here'),
      ),
    );
  }
} 