import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/restaurant.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class RestaurantService {
  final _storage = FirebaseStorage.instance;
  final _database = FirebaseDatabase.instance;

  Future<void> createRestaurant(Restaurant restaurant) async {
    await _database.ref().child('restaurants').child(restaurant.id).set(restaurant.toMap());
  }

  Future<Restaurant?> getRestaurant(String id) async {
    print('Fetching restaurant data from Firebase for ID: $id');
    try {
      final snapshot = await _database.ref().child('restaurants').child(id).get();
      print('Firebase snapshot exists: ${snapshot.exists}');
      
      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        print('Raw data from Firebase: $data');
        
        // Convert the data to match the Restaurant model structure
        final restaurantData = {
          'id': id,
          'fullName': data['fullName'] ?? '',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'address': data['address'],
          'documents': data['documents'],
          'documentsSubmitted': data['documentsSubmitted'] ?? false,
          'hours': data['hours'],
          'createdAt': data['createdAt'] != null 
              ? DateTime.parse(data['createdAt']).millisecondsSinceEpoch
              : DateTime.now().millisecondsSinceEpoch,
          'updatedAt': data['updatedAt'] != null 
              ? DateTime.parse(data['updatedAt']).millisecondsSinceEpoch
              : null,
          'profileImageUrl': data['profileImageUrl'],
          'about': data['about'],
        };
        print('Converted restaurant data: $restaurantData');
        
        final restaurant = Restaurant.fromJson(restaurantData);
        print('Created Restaurant object with:');
        print('Full Name: ${restaurant.fullName}');
        print('Email: ${restaurant.email}');
        return restaurant;
      }
      print('No restaurant data found in Firebase for ID: $id');
      return null;
    } catch (e) {
      print('Error in getRestaurant: $e');
      return null;
    }
  }

  Future<String> uploadImage(File image, String path) async {
    final ref = _storage.ref().child(path);
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  Future<void> updateRestaurantApproval(String uid, bool isApproved) async {
    await _database.ref().child('restaurants').child(uid).update({
      'documents.status': isApproved ? 'approved' : 'rejected',
      'documents.updatedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateRestaurantHours(String id, Map<String, dynamic> hours) async {
    await _database.ref().child('restaurants').child(id).update({
      'hours': hours,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Stream<Restaurant?> getRestaurantStream(String id) {
    return _database.ref().child('restaurants').child(id).onValue.map((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        // Convert the data to match the Restaurant model structure
        final restaurantData = {
          'id': id,
          'fullName': data['fullName'] ?? '',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'address': data['address'],
          'documents': data['documents'],
          'documentsSubmitted': data['documentsSubmitted'] ?? false,
          'hours': data['hours'],
          'createdAt': data['createdAt'] != null 
              ? DateTime.parse(data['createdAt']).millisecondsSinceEpoch
              : DateTime.now().millisecondsSinceEpoch,
          'updatedAt': data['updatedAt'] != null 
              ? DateTime.parse(data['updatedAt']).millisecondsSinceEpoch
              : null,
          'profileImageUrl': data['profileImageUrl'],
          'about': data['about'],
        };
        return Restaurant.fromJson(restaurantData);
      }
      return null;
    });
  }

  // Helper method to get raw restaurant data
  Future<Map<String, dynamic>?> getRestaurantData(String uid) async {
    final snapshot = await _database.ref().child('restaurants').child(uid).get();
    if (!snapshot.exists) return null;
    return snapshot.value as Map<String, dynamic>;
  }

  // Helper method to get raw restaurant data stream
  Stream<Map<String, dynamic>?> getRestaurantDataStream(String uid) {
    return _database.ref().child('restaurants').child(uid).onValue.map((event) {
      if (event.snapshot.exists) {
        return event.snapshot.value as Map<String, dynamic>;
      }
      return null;
    });
  }
} 