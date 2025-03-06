import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/restaurant_service.dart';
import '../models/restaurant.dart';
import 'package:firebase_database/firebase_database.dart';

class RestaurantDocumentPage extends StatefulWidget {
  const RestaurantDocumentPage({super.key});

  @override
  State<RestaurantDocumentPage> createState() => _RestaurantDocumentPageState();
}

class _RestaurantDocumentPageState extends State<RestaurantDocumentPage> {
  final _formKey = GlobalKey<FormState>();
  final _restaurantService = RestaurantService();
  final _user = FirebaseAuth.instance.currentUser;
  
  File? _licenseImage;
  File? _ownerIdImage;
  bool _isLoading = false;
  bool _isApproved = false;
  TimeOfDay? _openingTime;
  TimeOfDay? _closingTime;
  Restaurant? _restaurant;

  @override
  void initState() {
    super.initState();
    _loadRestaurantData();
  }

  void _loadRestaurantData() async {
    if (_user != null) {
      final restaurant = await _restaurantService.getRestaurant(_user!.uid);
      if (restaurant != null) {
        setState(() {
          _restaurant = restaurant;
          _isApproved = restaurant.isApproved;
          if (restaurant.opening != null) {
            final openingParts = restaurant.opening!.split(':');
            _openingTime = TimeOfDay(
              hour: int.parse(openingParts[0]),
              minute: int.parse(openingParts[1]),
            );
          }
          if (restaurant.closing != null) {
            final closingParts = restaurant.closing!.split(':');
            _closingTime = TimeOfDay(
              hour: int.parse(closingParts[0]),
              minute: int.parse(closingParts[1]),
            );
          }
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
          _ownerIdImage = File(image.path);
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isOpening) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isOpening ? _openingTime ?? const TimeOfDay(hour: 10, minute: 0) : _closingTime ?? const TimeOfDay(hour: 23, minute: 0),
    );
    
    if (picked != null) {
      setState(() {
        if (isOpening) {
          _openingTime = picked;
        } else {
          _closingTime = picked;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (_licenseImage == null || _ownerIdImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both documents')),
      );
      return;
    }

    if (_openingTime == null || _closingTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select business hours')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload images to Firebase Storage
      final licenseUrl = await _restaurantService.uploadImage(
        _licenseImage!,
        'restaurants/${_user!.uid}/license.jpg',
      );
      
      final ownerIdUrl = await _restaurantService.uploadImage(
        _ownerIdImage!,
        'restaurants/${_user!.uid}/owner_id.jpg',
      );

      final now = DateTime.now().toIso8601String();

      // Format time strings
      final openingStr = '${_openingTime!.hour.toString().padLeft(2, '0')}:${_openingTime!.minute.toString().padLeft(2, '0')}';
      final closingStr = '${_closingTime!.hour.toString().padLeft(2, '0')}:${_closingTime!.minute.toString().padLeft(2, '0')}';

      // Update restaurant information with document URLs and business hours
      await FirebaseDatabase.instance
          .ref()
          .child('restaurants')
          .child(_user!.uid)
          .update({
        'documentsSubmitted': true,
        'status': 'pending_review',
        'documents': {
          'owner_id': {
            'url': ownerIdUrl,
            'uploadTime': now,
          },
          'license': {
            'url': licenseUrl,
            'uploadTime': now,
          }
        },
        'hours': {
          'opening': openingStr,
          'closing': closingStr,
          'isOpen': true,
        },
        'updatedAt': now,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documents and business hours submitted for approval')),
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
        title: const Text('Restaurant Documents'),
      ),
      body: _isApproved
          ? const Center(
              child: Text('Your restaurant has been approved!'),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Please upload your restaurant documents for verification',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    const Text('Restaurant License Image:'),
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
                    const Text('Owner ID Image:'),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(false),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Choose from Gallery'),
                    ),
                    if (_ownerIdImage != null) ...[
                      const SizedBox(height: 8),
                      Image.file(_ownerIdImage!, height: 100),
                    ],
                    const SizedBox(height: 32),
                    const Text(
                      'Business Hours',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Opening Time:'),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => _selectTime(context, true),
                                icon: const Icon(Icons.access_time),
                                label: Text(_openingTime != null 
                                    ? '${_openingTime!.hour.toString().padLeft(2, '0')}:${_openingTime!.minute.toString().padLeft(2, '0')}'
                                    : 'Select Time'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Closing Time:'),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => _selectTime(context, false),
                                icon: const Icon(Icons.access_time),
                                label: Text(_closingTime != null 
                                    ? '${_closingTime!.hour.toString().padLeft(2, '0')}:${_closingTime!.minute.toString().padLeft(2, '0')}'
                                    : 'Select Time'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Submit Documents and Hours'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 