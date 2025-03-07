import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/driver_service.dart';
import 'package:firebase_database/firebase_database.dart';

class DriverPage extends StatefulWidget {
  const DriverPage({super.key});

  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  final _formKey = GlobalKey<FormState>();
  final _driverService = DriverService();
  final _user = FirebaseAuth.instance.currentUser;
  
  File? _licenseImage;
  File? _govtIdImage;
  bool _isLoading = false;
  bool _isApproved = false;

  @override
  void initState() {
    super.initState();
    _checkDriverStatus();
  }

  Future<void> _checkDriverStatus() async {
    if (_user != null) {
      final driver = await _driverService.getDriver(_user!.uid);
      if (driver != null) {
        setState(() {
          _isApproved = driver.isApproved;
        });
      }
    }
  }

  Future<void> _pickImage(bool isLicense) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        if (isLicense) {
          _licenseImage = File(image.path);
        } else {
          _govtIdImage = File(image.path);
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (_licenseImage == null || _govtIdImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both documents')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload images to Firebase Storage
      final licenseUrl = await _driverService.uploadImage(
        _licenseImage!,
        'drivers/${_user!.uid}/license.jpg',
      );
      
      final govtIdUrl = await _driverService.uploadImage(
        _govtIdImage!,
        'drivers/${_user!.uid}/govt_id.jpg',
      );

      final now = DateTime.now().toIso8601String();

      // Update driver information with document URLs
      await FirebaseDatabase.instance
          .ref()
          .child('drivers')
          .child(_user!.uid)
          .update({
        'documentsSubmitted': true,
        'documents': {
          'status': 'pending_review',
          'govt_id': {
            'url': govtIdUrl,
            'uploadTime': now,
          },
          'license': {
            'url': licenseUrl,
            'uploadTime': now,
          },
          'updatedAt': now,
        },
        'updatedAt': now,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documents submitted for approval')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Documents'),
      ),
      body: _isApproved
          ? const Center(
              child: Text('Your profile has been approved!'),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Please upload your documents for verification',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    const Text('Driver License Image:'),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(true),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Choose from Gallery'),
                    ),
                    if (_licenseImage != null) ...[
                      const SizedBox(height: 8),
                      Image.file(_licenseImage!, height: 100),
                    ],
                    const SizedBox(height: 24),
                    const Text('Government ID Image:'),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(false),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Choose from Gallery'),
                    ),
                    if (_govtIdImage != null) ...[
                      const SizedBox(height: 8),
                      Image.file(_govtIdImage!, height: 100),
                    ],
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Submit Documents'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 