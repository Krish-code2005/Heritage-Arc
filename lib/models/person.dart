// lib/models/person.dart
import 'partner.dart';

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
  final String? photoUrl;

  final String? fatherId;
  final String? lineageId;
  int parentCount;

  // Partner details
  final Partner? partner1;
  final Partner? partner2;

  // Display names for parents (filled after fetching)
  String? fatherName;
  String? motherName;        // ← Added even without mother_id

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
    this.photoUrl,
    this.fatherId,
    this.lineageId,
    this.parentCount = 0,
    this.partner1,
    this.partner2,
    this.fatherName,
    this.motherName,
  });

  String get fullName => [firstName, middleName, lastName]
      .where((e) => e != null && e.isNotEmpty)
      .join(' ');

  String get fatherFullName => fatherName ?? '';
  String get motherFullName => motherName ?? '';

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
      photoUrl: map['photo_url'] as String?,
      fatherId: map['father_id'] as String?,
      lineageId: map['lineage_id'] as String?,
      fatherName: map['father_name'] as String?,      // ← From join or extra column
      motherName: map['mother_name'] as String?,      // ← From join or extra column
      partner1: map['partner1'] != null 
          ? Partner.fromMap(map['partner1'] as Map<String, dynamic>)
          : null,
      partner2: map['partner2'] != null 
          ? Partner.fromMap(map['partner2'] as Map<String, dynamic>)
          : null,
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
      'photo_url': photoUrl,
      'father_id': fatherId,
      'lineage_id': lineageId,
      'father_name': fatherName,
    'mother_name': motherName,
      // Names are usually not saved, but fetched via joins
      'partner1': partner1?.toMap(),
      'partner2': partner2?.toMap(),
    };
  }

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
    String? photoUrl,
    String? fatherId,
    String? lineageId,
    int? parentCount,
    Partner? partner1,
    Partner? partner2,
    String? fatherName,
    String? motherName,
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
      photoUrl: photoUrl ?? this.photoUrl,
      fatherId: fatherId ?? this.fatherId,
      lineageId: lineageId ?? this.lineageId,
      parentCount: parentCount ?? this.parentCount,
      partner1: partner1 ?? this.partner1,
      partner2: partner2 ?? this.partner2,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
    );
  }
}