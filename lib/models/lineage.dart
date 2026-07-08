// lib/models/lineage.dart
class Lineage {
  final String id;
  final String name;

  Lineage({
    required this.id,
    required this.name,
  });

  factory Lineage.fromMap(Map<String, dynamic> map) {
    return Lineage(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }
}