class AppSettings {
  const AppSettings({
    required this.deviceId,
    required this.backendBaseUrl,
    required this.useMockService,
    required this.isPro,
    required this.remainingFreeUses,
  });

  final String deviceId;
  final String backendBaseUrl;
  final bool useMockService;
  final bool isPro;
  final int remainingFreeUses;

  factory AppSettings.defaults({String deviceId = ''}) {
    return AppSettings(
      deviceId: deviceId,
      backendBaseUrl: 'http://127.0.0.1:8000',
      useMockService: false,
      isPro: false,
      remainingFreeUses: 2,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final AppSettings defaults = AppSettings.defaults();
    return AppSettings(
      deviceId: (json['deviceId'] as String?) ?? '',
      backendBaseUrl:
          (json['backendBaseUrl'] as String?) ?? defaults.backendBaseUrl,
      useMockService:
          (json['useMockService'] as bool?) ?? defaults.useMockService,
      isPro: (json['isPro'] as bool?) ?? false,
      remainingFreeUses: (json['remainingFreeUses'] as int?) ?? 2,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'deviceId': deviceId,
      'backendBaseUrl': backendBaseUrl,
      'useMockService': useMockService,
      'isPro': isPro,
      'remainingFreeUses': remainingFreeUses,
    };
  }

  AppSettings copyWith({
    String? deviceId,
    String? backendBaseUrl,
    bool? useMockService,
    bool? isPro,
    int? remainingFreeUses,
  }) {
    return AppSettings(
      deviceId: deviceId ?? this.deviceId,
      backendBaseUrl: backendBaseUrl ?? this.backendBaseUrl,
      useMockService: useMockService ?? this.useMockService,
      isPro: isPro ?? this.isPro,
      remainingFreeUses: remainingFreeUses ?? this.remainingFreeUses,
    );
  }
}
