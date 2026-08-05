class SubTermEntity {
  final String subTermId;
  final String title;
  final String content;
  final int sortOrder;

  const SubTermEntity({
    required this.subTermId,
    required this.title,
    required this.content,
    required this.sortOrder,
  });

  factory SubTermEntity.fromJson(Map<String, dynamic> json) {
    return SubTermEntity(
      subTermId: json['subTermId'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      sortOrder: (json['sortOrder'] as num).toInt(),
    );
  }
}

class UsageTermEntity {
  final String usageTermId;
  final String title;
  final List<SubTermEntity> subTerms;

  const UsageTermEntity({
    required this.usageTermId,
    required this.title,
    required this.subTerms,
  });

  factory UsageTermEntity.fromJson(Map<String, dynamic> json) {
    return UsageTermEntity(
      usageTermId: json['usageTermId'] as String,
      title: json['title'] as String,
      subTerms: (json['subTerms'] as List<dynamic>)
          .map((e) => SubTermEntity.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AcceptanceStatusEntity {
  final String? activeUsageTermId;
  final bool accepted;
  final DateTime? acceptedAt;

  const AcceptanceStatusEntity({
    this.activeUsageTermId,
    required this.accepted,
    this.acceptedAt,
  });

  /// Retorna true se o usuário precisa aceitar os termos
  /// (termo ativo existe E não foi aceito)
  bool get mustAccept => activeUsageTermId != null && !accepted;

  factory AcceptanceStatusEntity.fromJson(Map<String, dynamic> json) {
    return AcceptanceStatusEntity(
      activeUsageTermId: json['activeUsageTermId'] as String?,
      accepted: json['accepted'] as bool? ?? false,
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.parse(json['acceptedAt'] as String)
          : null,
    );
  }
}

class AcceptResponseEntity {
  final String usageTermId;
  final DateTime acceptedAt;

  const AcceptResponseEntity({
    required this.usageTermId,
    required this.acceptedAt,
  });

  factory AcceptResponseEntity.fromJson(Map<String, dynamic> json) {
    return AcceptResponseEntity(
      usageTermId: json['usageTermId'] as String,
      acceptedAt: DateTime.parse(json['acceptedAt'] as String),
    );
  }
}
