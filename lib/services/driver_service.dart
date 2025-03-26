import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/driver.dart';

class DriverService {
  final _storage = FirebaseStorage.instance;
  final _database = FirebaseDatabase.instance;

  Future<void> createDriver(Driver driver) async {
    await _database.ref().child('drivers').child(driver.uid).set(driver.toMap());
  }

  Future<Driver?> getDriver(String uid) async {
    try {
      final snapshot = await _database.ref().child('drivers').child(uid).get();
      if (!snapshot.exists) return null;

      final data = snapshot.value as Map<dynamic, dynamic>;
      
      // Convert dynamic map to Map<String, dynamic>
      final Map<String, dynamic> driverData = {};
      data.forEach((key, value) {
        driverData[key.toString()] = value;
      });
      
      // Debug: Print driver data
      print('Driver data from Firebase: $driverData');
      print('Driver status: ${driverData['status']}');
      
      return Driver.fromJson({
        'uid': uid,
        ...driverData,
      });
    } catch (e) {
      print('Error getting driver: $e');
      return null;
    }
  }

  Future<String> uploadImage(File image, String path) async {
    final ref = _storage.ref().child(path);
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  Future<void> updateDriverApproval(String uid, bool isApproved) async {
    final now = DateTime.now().toIso8601String();
    
    // Update only the status in documents without affecting other fields
    await _database.ref().child('drivers').child(uid).child('documents').update({
      'status': isApproved ? 'approved' : 'rejected',
    });
    
    // Update the timestamp at root level
    await _database.ref().child('drivers').child(uid).update({
      'updatedAt': now,
    });
    
    print('Updated driver approval status: ${isApproved ? 'approved' : 'rejected'}');
  }

  Future<void> updateDriverStatus(
    String uid, {
    bool? isOnline,
    bool? availableForOrders,
    String? status,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updatedAt': ServerValue.timestamp,
      };

      if (isOnline != null) {
        updates['isOnline'] = isOnline;
      }
      if (availableForOrders != null) {
        updates['availableForOrders'] = availableForOrders;
      }
      if (status != null) {
        updates['status'] = status;
      }

      await _database
          .ref()
          .child('drivers')
          .child(uid)
          .update(updates);
    } catch (e) {
      throw Exception('Failed to update driver status: $e');
    }
  }

  Stream<Driver?> getDriverStream(String uid) {
    return _database.ref().child('drivers').child(uid).onValue.map((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        return Driver.fromJson({
          'uid': uid,
          ...data,
        });
      }
      return null;
    });
  }
} 