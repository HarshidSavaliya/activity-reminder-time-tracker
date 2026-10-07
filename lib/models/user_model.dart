/// UserModel encapsulates user profile and preference details.
class UserModel {
  final String id;
  final String name;
  final String username;
  final String email;
  final String password;
  final String college;
  final String studentId;
  final String bio;
  final String avatarSeed;
  final bool remindersEnabled;
  final bool dailyDigestEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.password,
    this.college = 'College of Engineering & Technology',
    this.studentId = 'STD-2026',
    this.bio = 'CS Undergrad | Focused on routines & algorithms',
    this.avatarSeed = '1',
    this.remindersEnabled = true,
    this.dailyDigestEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    required this.createdAt,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? username,
    String? email,
    String? password,
    String? college,
    String? studentId,
    String? bio,
    String? avatarSeed,
    bool? remindersEnabled,
    bool? dailyDigestEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      college: college ?? this.college,
      studentId: studentId ?? this.studentId,
      bio: bio ?? this.bio,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      dailyDigestEnabled: dailyDigestEnabled ?? this.dailyDigestEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'password': password,
      'college': college,
      'studentId': studentId,
      'bio': bio,
      'avatarSeed': avatarSeed,
      'remindersEnabled': remindersEnabled,
      'dailyDigestEnabled': dailyDigestEnabled,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      password: json['password'] as String,
      college: json['college'] as String? ?? 'College of Engineering & Technology',
      studentId: json['studentId'] as String? ?? 'STD-2026',
      bio: json['bio'] as String? ?? 'CS Undergrad | Focused on routines & algorithms',
      avatarSeed: json['avatarSeed'] as String? ?? '1',
      remindersEnabled: json['remindersEnabled'] as bool? ?? true,
      dailyDigestEnabled: json['dailyDigestEnabled'] as bool? ?? true,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
