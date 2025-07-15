class Host {
  final String id;
  final String name;
  final String email;
  final String department;
  final String phone;
  final DateTime createdAt;

  Host({
    required this.id,
    required this.name,
    required this.email,
    required this.department,
    required this.phone,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'department': department,
      'phone': phone,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Host.fromMap(Map<String, dynamic> map) {
    return Host(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      department: map['department'] ?? '',
      phone: map['phone'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  get position => null;
}