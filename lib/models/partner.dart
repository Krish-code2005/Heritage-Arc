// lib/models/partner.dart
class Partner {
  final String? id;
  final String? name;
  final String? photoUrl;
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

  Partner({
    this.id,
    this.name,
    this.photoUrl,
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
  });

  String get fullName => name ?? '';

  factory Partner.fromMap(Map<String, dynamic> map) {
    return Partner(
      id: map['id'] as String?,
      name: map['name'] as String?,
      photoUrl: map['photo_url'] as String?,
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'photo_url': photoUrl,
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
    };
  }

  Partner copyWith({
    String? id,
    String? name,
    String? photoUrl,
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
  }) {
    return Partner(
      id: id ?? this.id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
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
    );
  }
}