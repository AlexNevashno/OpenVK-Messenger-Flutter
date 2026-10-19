class VKGroup {
  final int id;
  final String name;
  final String screenName;
  final String? photo50;
  final String? photo100;
  final String? photo200;
  final bool isUserAdmin;

  VKGroup({
    required this.id,
    required this.name,
    this.screenName = '',
    this.photo50,
    this.photo100,
    this.photo200,
    this.isUserAdmin = false,
  });

  String? get avatarURL => photo200 ?? photo100 ?? photo50;
  String? get avatarUrl => avatarURL;

  factory VKGroup.fromJson(Map<String, dynamic> json) {
    int id = json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0;
    bool isAdmin = json['is_admin'] == 1 || json['is_admin'] == true || json['admin_level'] != null;

    return VKGroup(
      id: id,
      name: json['name']?.toString() ?? 'Сообщество',
      screenName: json['screen_name']?.toString() ?? '',
      photo50: json['photo_50']?.toString(),
      photo100: json['photo_100']?.toString(),
      photo200: json['photo_200']?.toString(),
      isUserAdmin: isAdmin,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'screen_name': screenName,
        'photo_50': photo50,
        'photo_100': photo100,
        'photo_200': photo200,
        'is_admin': isUserAdmin ? 1 : 0,
      };
}
