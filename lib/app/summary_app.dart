import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_settings.dart';
import '../models/history_item.dart';
import '../models/summary_result.dart';
import '../services/local_storage_service.dart';
import '../services/summary_service.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Note Summary',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F1E8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E5E6F),
          brightness: Brightness.light,
        ),
        textTheme: const TextTheme(
          displaySmall: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
            color: Color(0xFF10212A),
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF10212A),
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF10212A),
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.45,
            color: Color(0xFF2E3D44),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Color(0xFF445A63),
          ),
        ),
      ),
      home: const SummaryAppScreen(),
    );
  }
}

class SummaryAppScreen extends StatefulWidget {
  const SummaryAppScreen({super.key});

  @override
  State<SummaryAppScreen> createState() => _SummaryAppScreenState();
}

class _SummaryAppScreenState extends State<SummaryAppScreen> {
  final TextEditingController _transcriptController = TextEditingController();
  final TextEditingController _backendUrlController = TextEditingController();
  final LocalStorageService _storage = const LocalStorageService();
  final SummaryService _summaryService = SummaryService();

  AppSettings _settings = AppSettings.defaults();
  List<HistoryItem> _history = <HistoryItem>[];

  int _selectedIndex = 0;
  bool _isBootstrapping = true;
  bool _isProcessing = false;
  bool _isSyncingBackend = false;
  bool _isImportingAudio = false;
  bool _backendReachable = false;
  String _selectedLanguage = 'Hindi';
  String _selectedMode = 'Short + bullets';
  String _sourceLabel = 'Demo voice note';
  String _backendStatusLabel = 'Mock mode is active.';
  String? _errorMessage;
  SummaryResult? _currentResult;

  @override
  void initState() {
    super.initState();
    _loadPersistedState();
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    _backendUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadPersistedState() async {
    final AppSettings settings = await _storage.loadSettings();
    final List<HistoryItem> history = await _storage.loadHistory();

    if (!mounted) {
      return;
    }

    setState(() {
      _settings = settings;
      _history = history;
      _backendUrlController.text = settings.backendBaseUrl;
      _isBootstrapping = false;
    });

    await _syncBackendState();
  }

  Future<void> _persistSettings() async {
    await _storage.saveSettings(_settings);
  }

  Future<void> _persistHistory() async {
    await _storage.saveHistory(_history);
  }

  Future<void> _summarize({
    String? seededTranscript,
    String? sourceLabel,
  }) async {
    if (_selectedMode == 'Detailed Pro mode' && !_settings.isPro) {
      setState(() {
        _selectedIndex = 2;
      });
      _showMessage('Detailed Pro mode is only available in Pro preview.');
      return;
    }

    if (!_settings.useMockService) {
      final bool synced = await _syncBackendState();
      if (!synced) {
        return;
      }
    }

    if (!_settings.isPro && _settings.remainingFreeUses == 0) {
      setState(() {
        _selectedIndex = 2;
      });
      return;
    }

    final String transcript = (seededTranscript ?? _transcriptController.text)
        .trim();
    if (transcript.isEmpty) {
      _showMessage('Add or generate a transcript first.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _sourceLabel = sourceLabel ?? _sourceLabel;
    });

    try {
      final SummaryResult result = await _summaryService.summarize(
        transcript: transcript,
        language: _selectedLanguage,
        mode: _selectedMode,
        sourceLabel: _sourceLabel,
        settings: _settings,
      );

      final HistoryItem item = HistoryItem(
        source: result.sourceLabel,
        language: result.language,
        summary: result.shortSummary,
        bulletPoints: result.bulletPoints,
        transcriptPreview: _preview(result.transcript, 140),
        createdAt: result.createdAt,
        serviceLabel: result.serviceLabel,
      );

      setState(() {
        _currentResult = result;
        _history = <HistoryItem>[item, ..._history].take(20).toList();
        _isProcessing = false;
        _selectedIndex = 0;
      });

      await _persistHistory();
      await _consumeUsageAfterSummary();
    } on SummaryServiceException catch (error) {
      setState(() {
        _isProcessing = false;
        _errorMessage = error.message;
      });
      _showMessage(error.message);
    } catch (_) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Something went wrong while generating the summary.';
      });
      _showMessage('Something went wrong while generating the summary.');
    }
  }

  Future<bool> _syncBackendState({bool showMessage = false}) async {
    if (_settings.useMockService || _settings.backendBaseUrl.trim().isEmpty) {
      if (!mounted) {
        return true;
      }

      setState(() {
        _backendReachable = false;
        _backendStatusLabel = _settings.useMockService
            ? 'Mock mode is active.'
            : 'Add a backend URL to enable backend mode.';
      });
      return true;
    }

    setState(() {
      _isSyncingBackend = true;
      _errorMessage = null;
    });

    bool isHealthy = await _summaryService.checkBackendHealth(_settings);
    if (!isHealthy) {
      final String? fallbackUrl = _localBackendFallback(
        _settings.backendBaseUrl,
      );
      if (fallbackUrl != null) {
        final AppSettings fallbackSettings = _settings.copyWith(
          backendBaseUrl: fallbackUrl,
        );
        final bool fallbackHealthy = await _summaryService.checkBackendHealth(
          fallbackSettings,
        );
        if (fallbackHealthy) {
          if (!mounted) {
            return false;
          }
          setState(() {
            _settings = fallbackSettings;
            _backendUrlController.text = fallbackUrl;
          });
          await _persistSettings();
          isHealthy = true;
        }
      }
    }
    if (!mounted) {
      return false;
    }

    if (!isHealthy) {
      setState(() {
        _isSyncingBackend = false;
        _backendReachable = false;
        _backendStatusLabel = 'Backend is unreachable.';
        _errorMessage =
            'Could not reach the backend. Check the API URL or switch mock mode back on.';
      });
      if (showMessage) {
        _showMessage(_errorMessage!);
      }
      return false;
    }

    try {
      UsageSnapshot? snapshot;
      if (!_settings.isPro) {
        snapshot = await _summaryService.checkUsage(_settings);
      }

      if (!mounted) {
        return false;
      }

      setState(() {
        _backendReachable = true;
        _backendStatusLabel = snapshot == null
            ? 'Backend connected. Pro preview skips free usage checks.'
            : 'Backend connected. ${snapshot.remainingFreeUses} free summaries remaining.';
        if (snapshot != null) {
          _settings = _settings.copyWith(
            remainingFreeUses: snapshot.remainingFreeUses,
          );
        }
        _isSyncingBackend = false;
      });
      await _persistSettings();
      if (showMessage) {
        _showMessage('Backend connection verified.');
      }
      return true;
    } on SummaryServiceException catch (error) {
      setState(() {
        _isSyncingBackend = false;
        _backendReachable = false;
        _backendStatusLabel = 'Backend usage sync failed.';
        _errorMessage = error.message;
      });
      if (showMessage) {
        _showMessage(error.message);
      }
      return false;
    }
  }

  String? _localBackendFallback(String currentUrl) {
    final Uri? uri = Uri.tryParse(currentUrl.trim());
    if (uri == null) {
      return null;
    }

    final bool isLocalHost =
        uri.host == '127.0.0.1' || uri.host == 'localhost';
    if (!isLocalHost || uri.port != 8000) {
      return null;
    }

    return uri.replace(port: 8010).toString();
  }

  Future<void> _consumeUsageAfterSummary() async {
    if (_settings.isPro) {
      await _persistSettings();
      return;
    }

    if (_settings.useMockService || !_backendReachable) {
      if (_settings.remainingFreeUses > 0) {
        setState(() {
          _settings = _settings.copyWith(
            remainingFreeUses: _settings.remainingFreeUses - 1,
          );
        });
      }
      await _persistSettings();
      return;
    }

    try {
      final UsageSnapshot snapshot = await _summaryService.incrementUsage(
        _settings,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = _settings.copyWith(
          remainingFreeUses: snapshot.remainingFreeUses,
        );
        _backendStatusLabel =
            'Backend connected. ${snapshot.remainingFreeUses} free summaries remaining.';
      });
      await _persistSettings();
    } on SummaryServiceException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _importAudioFile() async {
    if (_isImportingAudio || _isProcessing) {
      return;
    }

    if (_settings.useMockService) {
      _showMessage(
        'Audio import requires backend mode. Save a backend URL and keep mock mode off.',
      );
      setState(() {
        _selectedIndex = 2;
      });
      return;
    }

    final bool synced = await _syncBackendState();
    if (!synced) {
      setState(() {
        _selectedIndex = 2;
      });
      return;
    }

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        withData: true,
        allowedExtensions: <String>['aac', 'm4a', 'mp3', 'wav', 'ogg', 'webm'],
      );
    } catch (_) {
      _showMessage('Could not open the file picker on this platform.');
      return;
    }

    if (result == null || result.files.isEmpty) {
      return;
    }

    final PlatformFile file = result.files.single;
    final Uint8List? bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showMessage('The selected file could not be read.');
      return;
    }

    setState(() {
      _isImportingAudio = true;
      _errorMessage = null;
    });

    try {
      final TranscriptionResult transcription = await _summaryService
          .transcribeAudio(
            filename: file.name,
            bytes: bytes,
            language: _selectedLanguage,
            settings: _settings,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _sourceLabel = 'Imported audio: ${transcription.filename}';
        _transcriptController.text = transcription.transcript;
        _isImportingAudio = false;
      });
      _showMessage(transcription.message);
    } on SummaryServiceException catch (error) {
      setState(() {
        _isImportingAudio = false;
        _errorMessage = error.message;
      });
      _showMessage(error.message);
    } catch (_) {
      setState(() {
        _isImportingAudio = false;
        _errorMessage = 'Something went wrong while importing the audio file.';
      });
      _showMessage('Something went wrong while importing the audio file.');
    }
  }

  void _loadDemoTranscript(String source) {
    final String transcript = switch (_selectedLanguage) {
      'Gujarati' =>
        'કાલે 11 વાગ્યા સુધી ડિઝાઇન ફાઈલ મોકલવી છે. ક્લાયન્ટે ખાસ કહ્યું કે હોમ સ્ક્રીન સરળ હોવી જોઈએ અને વોટ્સએપ શેર બટન ખૂબ દેખાતું હોવું જોઈએ. ફ્રી યુઝર્સ માટે 2 મિનિટની મર્યાદા રાખવી અને પ્રો માટે 10 મિનિટ. આવતીકાલે ફરી રિવ્યૂ રાખીએ.',
      'English' =>
        'Please send the revised design by 11 AM tomorrow. The client wants the home screen to stay minimal and the WhatsApp share button to be obvious. Keep the free tier at a two minute audio limit and give Pro users up to ten minutes. Let us review the build again tomorrow.',
      _ =>
        'Kal subah 11 baje tak updated design bhejna. Client ne bola home screen simple honi chahiye aur WhatsApp share button clearly visible hona chahiye. Free users ke liye 2 minute audio limit rakho aur Pro users ko 10 minute tak allow karo. Kal ek aur review call karte hain.',
    };

    setState(() {
      _sourceLabel = source;
      _transcriptController.text = transcript;
    });
  }

  Future<void> _copySummary() async {
    final SummaryResult? result = _currentResult;
    if (result == null) {
      return;
    }

    final String payload = _buildShareText(result);
    try {
      await Clipboard.setData(ClipboardData(text: payload));
      _showMessage('Summary copied to clipboard.');
    } catch (_) {
      _showMessage('Could not copy the summary on this platform.');
    }
  }

  Future<void> _shareSummary() async {
    final SummaryResult? result = _currentResult;
    if (result == null) {
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: _buildShareText(result),
          subject: 'Voice note summary',
        ),
      );
    } catch (_) {
      _showMessage('Sharing is not available here. Try copy instead.');
    }
  }

  String _buildShareText(SummaryResult result) {
    final StringBuffer buffer = StringBuffer()
      ..writeln(result.shortSummary)
      ..writeln();

    if (result.bulletPoints.isNotEmpty) {
      buffer.writeln('Key points:');
      for (final String point in result.bulletPoints) {
        buffer.writeln('• $point');
      }
      buffer.writeln();
    }

    buffer.writeln('Source: ${result.sourceLabel}');
    buffer.writeln('Summary mode: ${result.requestedMode}');
    buffer.writeln('Service: ${result.serviceLabel}');
    return buffer.toString().trim();
  }

  Future<void> _saveBackendSettings() async {
    setState(() {
      _settings = _settings.copyWith(
        backendBaseUrl: _backendUrlController.text.trim(),
      );
    });
    await _persistSettings();
    await _syncBackendState(showMessage: true);
  }

  Future<void> _resetLocalIdentity() async {
    final AppSettings refreshed = _settings.copyWith(
      deviceId: _storage.createDeviceId(),
      remainingFreeUses: AppSettings.defaults().remainingFreeUses,
    );

    setState(() {
      _settings = refreshed;
      _backendReachable = false;
      _backendStatusLabel = _settings.useMockService
          ? 'Mock mode is active.'
          : 'Local identity reset. Rechecking backend usage...';
      _errorMessage = null;
    });

    await _persistSettings();

    if (_settings.useMockService) {
      _showMessage('Local app identity reset. Free usage is fresh again.');
      return;
    }

    await _syncBackendState(showMessage: true);
  }

  Future<void> _resetHistory() async {
    setState(() {
      _history = <HistoryItem>[];
      _currentResult = null;
    });
    await _persistHistory();
    _showMessage('History cleared.');
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _preview(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength - 1).trimRight()}…';
  }

  @override
  Widget build(BuildContext context) {
    if (_isBootstrapping) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final Widget body = switch (_selectedIndex) {
      1 => _buildHistoryView(),
      2 => _buildSettingsView(),
      _ => _buildHomeView(),
    };

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Color(0xFFEEE7DB),
              Color(0xFFF9F5EE),
              Color(0xFFF3E7D4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 28,
                  ),
                  child: body,
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.auto_awesome),
            label: 'Studio',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildHomeView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _HeroPanel(settings: _settings),
        const SizedBox(height: 18),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Client status',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _settings.useMockService
                    ? 'Mock summarization is enabled, so the app works without a backend while the flow is being built.'
                    : 'Backend mode is enabled. The app will call `${_settings.backendBaseUrl}/summarize` for real summaries.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 10),
              Text(
                _backendStatusLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _settings.useMockService || _backendReachable
                      ? const Color(0xFF0E5E6F)
                      : const Color(0xFF9A3412),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_errorMessage != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF9A3412),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_isSyncingBackend)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _QuickActionChip(
                    icon: Icons.mic_rounded,
                    label: 'Record demo note',
                    onTap: () => _loadDemoTranscript('Recorded voice note'),
                  ),
                  _QuickActionChip(
                    icon: Icons.audio_file_rounded,
                    label: _isImportingAudio
                        ? 'Importing audio...'
                        : 'Import audio file',
                    onTap: _isImportingAudio ? () {} : _importAudioFile,
                  ),
                  _QuickActionChip(
                    icon: Icons.description_rounded,
                    label: 'Paste transcript',
                    onTap: () {
                      setState(() {
                        _sourceLabel = 'Pasted transcript';
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Input controls',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text('Language', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <String>['Hindi', 'Gujarati', 'English'].map((
                  String language,
                ) {
                  final bool selected = _selectedLanguage == language;
                  return ChoiceChip(
                    label: Text(language),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _selectedLanguage = language;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                'Summary output',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    <String>[
                      'Short + bullets',
                      'Short only',
                      'Detailed Pro mode',
                    ].map((String mode) {
                      final bool selected = _selectedMode == mode;
                      return ChoiceChip(
                        label: Text(mode),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _selectedMode = mode;
                          });
                        },
                      );
                    }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _transcriptController,
                minLines: 5,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: 'Transcript or captured note',
                  alignLabelWithHint: true,
                  hintText:
                      'Paste a transcript here, or use one of the demo actions above.',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.76),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Current source: $_sourceLabel',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_isProcessing || _isImportingAudio)
                      ? null
                      : () => _summarize(),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(
                    _isImportingAudio
                        ? 'Importing audio…'
                        : _isProcessing
                        ? 'Processing…'
                        : 'Generate summary',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (_currentResult != null) _buildResultCard(_currentResult!),
      ],
    );
  }

  Widget _buildResultCard(SummaryResult result) {
    return _SectionCard(
      accentColor: const Color(0xFFCB6E17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Latest result',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _PillLabel(label: result.serviceLabel),
            ],
          ),
          const SizedBox(height: 16),
          _SurfacePanel(
            title: 'Short summary',
            child: Text(
              result.shortSummary,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 12),
          if (result.requestedMode != 'Short only')
            _SurfacePanel(
              title: 'Bullet points',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: result.bulletPoints.isEmpty
                    ? <Widget>[
                        Text(
                          'No bullet points were returned for this summary.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ]
                    : result.bulletPoints
                          .map(
                            (String point) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '• $point',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          )
                          .toList(),
              ),
            ),
          if (result.requestedMode == 'Detailed Pro mode') ...<Widget>[
            const SizedBox(height: 12),
            _SurfacePanel(
              title: 'Detailed summary',
              child: Text(
                result.detailedSummary,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _SurfacePanel(
            title: 'Transcript',
            child: Text(
              result.transcript,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _copySummary,
                icon: const Icon(Icons.content_copy_rounded),
                label: const Text('Copy'),
              ),
              FilledButton.tonalIcon(
                onPressed: _shareSummary,
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('History', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 10),
        Text(
          'Summaries now persist locally with shared preferences, so the recent result list survives app restarts.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 18),
        if (_history.isEmpty)
          const _EmptyState(
            title: 'No summaries yet',
            message:
                'Generate a transcript summary from the Studio tab to start building history.',
          )
        else
          ..._history.map((HistoryItem item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.source,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        _PillLabel(label: item.serviceLabel),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.summary,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (item.bulletPoints.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      ...item.bulletPoints.map(
                        (String point) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '• $point',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      item.transcriptPreview,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.language} · ${_formatTimestamp(item.createdAt)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildSettingsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Settings', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 10),
        Text(
          'This is the first backend-ready step: you can keep using the app in mock mode, or point it at a real summarization service when the endpoint is ready.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 18),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Backend mode',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use mock service'),
                subtitle: const Text(
                  'Keep this on until `/summarize` exists on your backend.',
                ),
                value: _settings.useMockService,
                onChanged: (bool value) async {
                  setState(() {
                    _settings = _settings.copyWith(useMockService: value);
                    _backendStatusLabel = value
                        ? 'Mock mode is active.'
                        : _backendStatusLabel;
                    if (value) {
                      _backendReachable = false;
                      _errorMessage = null;
                    }
                  });
                  await _persistSettings();
                  if (!value) {
                    await _syncBackendState(showMessage: true);
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _backendUrlController,
                decoration: InputDecoration(
                  labelText: 'Backend base URL',
                  hintText: 'https://api.example.com',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.76),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saveBackendSettings,
                  child: const Text('Save settings'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSyncingBackend
                    ? null
                    : () => _syncBackendState(showMessage: true),
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Test backend connection'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Usage tracking',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Usage is currently tracked per local device/browser, not per signed-in account.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Device ID: ${_preview(_settings.deviceId, 28)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _resetLocalIdentity,
                icon: const Icon(Icons.person_outline_rounded),
                label: const Text('Reset local app identity'),
              ),
              const SizedBox(height: 18),
              Text(
                'Plan preview',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable Pro preview'),
                subtitle: const Text(
                  'Temporary toggle until in-app purchases are wired.',
                ),
                value: _settings.isPro,
                onChanged: (bool value) async {
                  setState(() {
                    _settings = _settings.copyWith(
                      isPro: value,
                      remainingFreeUses: value
                          ? 2
                          : _settings.remainingFreeUses,
                    );
                  });
                  await _persistSettings();
                  if (!value && !_settings.useMockService) {
                    await _syncBackendState();
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Free summaries remaining today: ${_settings.remainingFreeUses}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  if (_settings.useMockService || !_backendReachable) {
                    setState(() {
                      _settings = _settings.copyWith(remainingFreeUses: 2);
                    });
                    await _persistSettings();
                    _showMessage('Free usage counter reset.');
                    return;
                  }

                  try {
                    final UsageSnapshot snapshot = await _summaryService
                        .resetUsage(_settings);
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _settings = _settings.copyWith(
                        remainingFreeUses: snapshot.remainingFreeUses,
                      );
                      _backendStatusLabel =
                          'Backend connected. ${snapshot.remainingFreeUses} free summaries remaining.';
                    });
                    await _persistSettings();
                    _showMessage('Free usage counter reset.');
                  } on SummaryServiceException catch (error) {
                    _showMessage(error.message);
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reset free usage'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Data', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(
                'History is saved locally as structured JSON in shared preferences for now.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _resetHistory,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Clear history'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime time) {
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return '${time.day}/${time.month}/${time.year} · $hour:$minute';
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF12384A),
            Color(0xFF0E5E6F),
            Color(0xFF1D8A8A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              settings.isPro
                  ? 'Pro active · 10 minute voice notes'
                  : '${settings.remainingFreeUses} free summaries left today',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Voice notes into fast, clean summaries.',
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            'Now structured as a real client: persistent state, share and copy actions, and a summary service that can switch from mock mode to backend mode.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFFE3F3F4)),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _HeroStat(label: 'Free audio', value: '2 min'),
              _HeroStat(label: 'Pro audio', value: '10 min'),
              _HeroStat(
                label: 'Mode',
                value: settings.useMockService ? 'Mock' : 'Backend',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFD0EDEE), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFAF3),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE9D9C2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.accentColor = const Color(0xFF0E5E6F),
  });

  final Widget child;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }
}

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0E0C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E6D0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF7C3A00),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
