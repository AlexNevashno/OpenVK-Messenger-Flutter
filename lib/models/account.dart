class VKAccount {
  final String id;
  final int userId;
  final String firstName;
  final String lastName;
  final String? photoURL;
  final String token;
  final String serverURL;
  final String? chandlerSessCookie;

  VKAccount({
    String? id,
    required this.userId,
    String? firstName,
    String? lastName,
    String? name,
    String? photoURL,
    String? avatarUrl,
    required this.token,
    required this.serverURL,
    this.chandlerSessCookie,
  })  : id = id ?? '$userId@$serverURL',
        firstName = firstName ?? (name != null ? name.split(' ').first : ''),
        lastName = lastName ?? (name != null && name.contains(' ') ? name.split(' ').sublist(1).join(' ') : ''),
        photoURL = photoURL ?? avatarUrl;

  String get name => fullName;
  String? get avatarUrl => photoURL;

  String get fullName {
    final combined = '$firstName $lastName'.trim();
    return combined.isEmpty ? 'id$userId' : combined;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'first_name': firstName,
        'last_name': lastName,
        'photo_url': photoURL,
        'token': token,
        'server_url': serverURL,
        'chandler_sess_cookie': chandlerSessCookie,
      };

  factory VKAccount.fromJson(Map<String, dynamic> json) {
    return VKAccount(
      id: json['id']?.toString(),
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse('${json['user_id']}') ?? 0,
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      photoURL: json['photo_url']?.toString(),
      token: json['token']?.toString() ?? '',
      serverURL: json['server_url']?.toString() ?? 'https://openvk.org',
      chandlerSessCookie: json['chandler_sess_cookie']?.toString(),
    );
  }
}
