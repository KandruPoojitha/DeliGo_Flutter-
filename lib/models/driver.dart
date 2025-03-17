class Driver {
  final String uid;
  final String email;
  final String fullName;
  final String phone;
  final String role;
  final bool documentsSubmitted;
  final Map<String, dynamic>? documents;
  final Map<String, dynamic>? hours;
  final String status;
  final String createdAt;
  final String? updatedAt;
  final bool? isOnline;
  final bool? availableForOrders;

  Driver({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.documentsSubmitted,
    this.documents,
    this.hours,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.isOnline,
    this.availableForOrders,
  });

  bool get isApproved => status == 'approved';

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      documentsSubmitted: json['documentsSubmitted'] ?? false,
      documents: json['documents'],
      hours: json['hours'],
      status: json['status'] ?? 'pending_review',
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'],
      isOnline: json['isOnline'],
      availableForOrders: json['availableForOrders'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'role': role,
      'documentsSubmitted': documentsSubmitted,
      'documents': documents,
      'hours': hours,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isOnline': isOnline,
      'availableForOrders': availableForOrders,
    };
  }
  
  @override
  String toString() {
    return 'Driver{uid: $uid, status: $status, isApproved: $isApproved, documentsSubmitted: $documentsSubmitted}';
  }
} 