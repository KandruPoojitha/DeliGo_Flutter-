class Driver {
  final String uid;
  final String email;
  final String fullName;
  final String phone;
  final String role;
  final bool documentsSubmitted;
  final String status;
  final Map<String, dynamic>? documents;
  final String createdAt;
  final String? updatedAt;

  Driver({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.documentsSubmitted,
    required this.status,
    this.documents,
    required this.createdAt,
    this.updatedAt,
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
      status: json['status'] ?? 'pending_review',
      documents: json['documents'],
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'],
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
      'status': status,
      'documents': documents,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
} 