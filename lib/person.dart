// lib/models/person.dart
class Person {
  final String id;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? dob;
  final String? dod;
  final String? occupation;
  final String? education;
  final String? description;
  final String? address;
  final String? facebook;
  final String? instagram;
  final String? phone;
  final String? email;
  final String? partnerName;
  final String? photoUrl;        // ← New: For storing image URL from Supabase Storage
  final String? fatherId;
  final String? motherId;
  int parentCount;

  Person({
    required this.id,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.dob,
    this.dod,
    this.occupation,
    this.education,
    this.description,
    this.address,
    this.facebook,
    this.instagram,
    this.phone,
    this.email,
    this.partnerName,
    this.photoUrl,               // ← New
    this.fatherId,
    this.motherId,
    this.parentCount = 0,
  });

  String get fullName => [firstName, middleName, lastName]
      .where((e) => e != null && e.isNotEmpty)
      .join(' ');

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] as String,
      firstName: map['first_name'] as String,
      middleName: map['middle_name'] as String?,
      lastName: map['last_name'] as String,
      dob: map['dob'] as String?,
      dod: map['dod'] as String?,
      occupation: map['occupation'] as String?,
      education: map['education'] as String?,
      description: map['description'] as String?,
      address: map['address'] as String?,
      facebook: map['facebook_url'] as String?,
      instagram: map['instagram_url'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      partnerName: map['partner_name'] as String?,
      photoUrl: map['photo_url'] as String?,           // ← New
      fatherId: map['father_id'] as String?,
      motherId: map['mother_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'dob': dob,
      'dod': dod,
      'occupation': occupation,
      'education': education,
      'description': description,
      'address': address,
      'facebook_url': facebook,
      'instagram_url': instagram,
      'phone': phone,
      'email': email,
      'partner_name': partnerName,
      'photo_url': photoUrl,                           // ← New
      'father_id': fatherId,
      'mother_id': motherId,
    };
  }

  // copyWith updated too
  Person copyWith({
    String? firstName,
    String? middleName,
    String? lastName,
    String? dob,
    String? dod,
    String? occupation,
    String? education,
    String? description,
    String? address,
    String? facebook,
    String? instagram,
    String? phone,
    String? email,
    String? partnerName,
    String? photoUrl,
    String? fatherId,
    String? motherId,
    int? parentCount,
  }) {
    return Person(
      id: id,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      dob: dob ?? this.dob,
      dod: dod ?? this.dod,
      occupation: occupation ?? this.occupation,
      education: education ?? this.education,
      description: description ?? this.description,
      address: address ?? this.address,
      facebook: facebook ?? this.facebook,
      instagram: instagram ?? this.instagram,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      partnerName: partnerName ?? this.partnerName,
      photoUrl: photoUrl ?? this.photoUrl,
      fatherId: fatherId ?? this.fatherId,
      motherId: motherId ?? this.motherId,
      parentCount: parentCount ?? this.parentCount,
    );
  }
}