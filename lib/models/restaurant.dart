class Restaurant {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String? address;
  final Map<String, dynamic>? documents;
  final String status;
  final bool documentsSubmitted;
  final Map<String, dynamic>? store_hours;
  final Map<String, dynamic>? hours;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? profileImageUrl;
  final String? about;
  final double? latitude;
  final double? longitude;

  Restaurant({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.address,
    this.documents,
    required this.status,
    required this.documentsSubmitted,
    this.store_hours,
    this.hours,
    required this.createdAt,
    this.updatedAt,
    this.profileImageUrl,
    this.about,
    this.latitude,
    this.longitude,
  });

  bool get isApproved => status == 'approved';

  String? get opening => hours?['opening'] as String?;
  String? get closing => hours?['closing'] as String?;
  bool get isOpen => hours?['isOpen'] == true;

  Restaurant copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? address,
    Map<String, dynamic>? documents,
    String? status,
    bool? documentsSubmitted,
    Map<String, dynamic>? store_hours,
    Map<String, dynamic>? hours,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? profileImageUrl,
    String? about,
    double? latitude,
    double? longitude,
  }) {
    return Restaurant(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      documents: documents ?? this.documents,
      status: status ?? this.status,
      documentsSubmitted: documentsSubmitted ?? this.documentsSubmitted,
      store_hours: store_hours ?? this.store_hours,
      hours: hours ?? this.hours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      about: about ?? this.about,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'],
      documents: json['documents'],
      status: json['status'] ?? 'pending_review',
      documentsSubmitted: json['documentsSubmitted'] ?? false,
      store_hours: json['store_hours'],
      hours: json['hours'],
      createdAt: json['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'])
          : null,
      profileImageUrl: json['profileImageUrl'],
      about: json['about'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'address': address,
      'documents': documents,
      'status': status,
      'documentsSubmitted': documentsSubmitted,
      'store_hours': store_hours,
      'hours': hours,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'profileImageUrl': profileImageUrl,
      'about': about,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Restaurant.fromMap(String id, Map<dynamic, dynamic> map) {
    return Restaurant(
      id: id,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      about: map['about'],
      address: map['address'],
      profileImageUrl: map['profileImageUrl'],
      status: map['status'] ?? 'pending_review',
      documentsSubmitted: map['documentsSubmitted'] ?? false,
      createdAt: map['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      store_hours: map['store_hours'] != null
          ? Map<String, Map<String, dynamic>>.from(map['store_hours'])
          : null,
      hours: map['hours'] != null
          ? Map<String, dynamic>.from(map['hours'])
          : null,
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
    );
  }
} 