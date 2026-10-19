class VKUser {
  final int id;
  final String firstName;
  final String lastName;
  final String? photo50;
  final String? photo100;
  final String? photo200;
  final bool isOnline;
  final bool isMobileOnline;
  final bool isVerified;
  final int? sex; // 1 = female, 2 = male, 0 = unknown
  final DateTime? lastSeen;

  VKUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.photo50,
    this.photo100,
    this.photo200,
    this.isOnline = false,
    this.isMobileOnline = false,
    this.isVerified = false,
    this.sex,
    this.lastSeen,
  });

  String get fullName => '$firstName $lastName'.trim().isEmpty
      ? (firstName.isEmpty ? 'Пользователь id$id' : firstName)
      : '$firstName $lastName'.trim();

  String? get photoURL => photo200 ?? photo100 ?? photo50;
  String? get avatarUrl => photoURL;
  String? get photoMaxUrl => photoURL;
  bool get isMobile => isMobileOnline;

  factory VKUser.fromJson(Map<String, dynamic> json) {
    int id = json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0;
    String first = json['first_name']?.toString() ?? '';
    String last = json['last_name']?.toString() ?? '';

    bool online = false;
    if (json['online'] != null) {
      online = json['online'] == 1 || json['online'] == true || json['online'] == '1';
    }

    bool mobile = false;
    if (json['online_mobile'] != null) {
      mobile = json['online_mobile'] == 1 || json['online_mobile'] == true || json['online_mobile'] == '1';
    }

    bool verified = false;
    if (json['verified'] != null) {
      verified = json['verified'] == 1 || json['verified'] == true || json['verified'] == '1';
    }

    DateTime? ls;
    if (json['last_seen'] is Map) {
      final t = json['last_seen']['time'];
      if (t != null) {
        final sec = t is int ? t : int.tryParse('$t') ?? 0;
        if (sec > 0) {
          ls = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
        }
      }
    }

    return VKUser(
      id: id,
      firstName: first,
      lastName: last,
      photo50: json['photo_50']?.toString(),
      photo100: json['photo_100']?.toString(),
      photo200: json['photo_200']?.toString() ?? json['photo_max']?.toString(),
      isOnline: online,
      isMobileOnline: mobile,
      isVerified: verified,
      sex: json['sex'] is int ? json['sex'] : int.tryParse('${json['sex']}'),
      lastSeen: ls,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'photo_50': photo50,
        'photo_100': photo100,
        'photo_200': photo200,
        'online': isOnline ? 1 : 0,
        'online_mobile': isMobileOnline ? 1 : 0,
        'verified': isVerified ? 1 : 0,
        'sex': sex,
        'last_seen': lastSeen != null ? {'time': lastSeen!.millisecondsSinceEpoch ~/ 1000} : null,
      };
}
