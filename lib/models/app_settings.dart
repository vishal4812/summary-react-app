class AppSettings {
  const AppSettings({
    required this.backendBaseUrl,
    required this.useMockService,
    required this.isPro,
    required this.remainingFreeUses,
  });

  final String backendBaseUrl;
  final bool useMockService;
  final bool isPro;
  final int remainingFreeUses;

  factory AppSettings.defaults() {
    return const AppSettings(
      backendBaseUrl: 'http://127.0.0.1:8000',
      useMockService: false,
      isPro: false,
      remainingFreeUses: 2,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      backendBaseUrl: (json['backendBaseUrl'] as String?) ?? '',
      useMockService: (json['useMockService'] as bool?) ?? true,
      isPro: (json['isPro'] as bool?) ?? false,
      remainingFreeUses: (json['remainingFreeUses'] as int?) ?? 2,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'backendBaseUrl': backendBaseUrl,
      'useMockService': useMockService,
      'isPro': isPro,
      'remainingFreeUses': remainingFreeUses,
    };
  }

  AppSettings copyWith({
    String? backendBaseUrl,
    bool? useMockService,
    bool? isPro,
    int? remainingFreeUses,
  }) {
    return AppSettings(
      backendBaseUrl: backendBaseUrl ?? this.backendBaseUrl,
      useMockService: useMockService ?? this.useMockService,
      isPro: isPro ?? this.isPro,
      remainingFreeUses: remainingFreeUses ?? this.remainingFreeUses,
    );
  }
}
