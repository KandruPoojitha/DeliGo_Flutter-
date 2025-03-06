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
    final snapshot = await _database.ref().child('drivers').child(uid).get();
    if (!snapshot.exists) return null;

    final data = snapshot.value as Map<dynamic, dynamic>;
    return Driver.fromJson({
      'uid': uid,
      ...data,
    });
  }

  Future<String> uploadImage(File image, String path) async {
    final ref = _storage.ref().child(path);
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  Future<void> updateDriverApproval(String uid, bool isApproved) async {
    await _database.ref().child('drivers').child(uid).update({
      'status': isApproved ? 'approved' : 'pending_review',
      'updatedAt': DateTime.now().toIso8601String(),
    });
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