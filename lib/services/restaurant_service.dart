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
    final snapshot = await _database.ref().child('restaurants').child(id).get();
    if (snapshot.exists && snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      return Restaurant.fromJson({
        'id': id,
        ...data,
      });
    }
    return null;
  }

  Future<String> uploadImage(File image, String path) async {
    final ref = _storage.ref().child(path);
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  Future<void> updateRestaurantApproval(String id, bool approved) async {
    await _database.ref().child('restaurants').child(id).update({
      'status': approved ? 'approved' : 'rejected',
      'updatedAt': ServerValue.timestamp,
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
        return Restaurant.fromJson({
          'id': id,
          ...data,
        });
      }
      return null;
    });
  }
} 