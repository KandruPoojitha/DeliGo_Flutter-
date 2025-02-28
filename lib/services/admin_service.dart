import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User Management
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final QuerySnapshot querySnapshot = await _firestore.collection('users').get();
      return querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }

  Future<bool> blockUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': 'blocked',
        'blockedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error blocking user: $e');
      return false;
    }
  }

  Future<bool> unblockUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': 'active',
        'blockedAt': null,
      });
      return true;
    } catch (e) {
      print('Error unblocking user: $e');
      return false;
    }
  }

  // Chat Management
  Future<List<Map<String, dynamic>>> getAllChats() async {
    try {
      final QuerySnapshot querySnapshot = await _firestore.collection('chats').get();
      return querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error getting chats: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getReportedChats() async {
    try {
      final QuerySnapshot querySnapshot = await _firestore
          .collection('chats')
          .where('isReported', isEqualTo: true)
          .get();
      return querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error getting reported chats: $e');
      return [];
    }
  }

  Future<bool> blockChat(String chatId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'status': 'blocked',
        'blockedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error blocking chat: $e');
      return false;
    }
  }

  Future<bool> deleteChat(String chatId) async {
    try {
      // Delete chat messages
      final QuerySnapshot messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();
      
      final batch = _firestore.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete chat document
      batch.delete(_firestore.collection('chats').doc(chatId));
      
      await batch.commit();
      return true;
    } catch (e) {
      print('Error deleting chat: $e');
      return false;
    }
  }

  // Chat Reports
  Future<List<Map<String, dynamic>>> getChatReports(String chatId) async {
    try {
      final QuerySnapshot querySnapshot = await _firestore
          .collection('chatReports')
          .where('chatId', isEqualTo: chatId)
          .get();
      return querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error getting chat reports: $e');
      return [];
    }
  }

  Future<bool> resolveChatReport(String reportId, String resolution) async {
    try {
      await _firestore.collection('chatReports').doc(reportId).update({
        'status': 'resolved',
        'resolution': resolution,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error resolving chat report: $e');
      return false;
    }
  }
} 