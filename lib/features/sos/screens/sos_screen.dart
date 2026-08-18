import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'package:provider/provider.dart';

import '../../../core/config/api_keys.dart';
import '../../../core/localization/app_text.dart';
import '../../../core/providers/locale_provider.dart';
import '../services/sos_response_parsing.dart';

enum _SosState { idle, listening, processing, speaking, error }

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  final _tts = FlutterTts();

  _SosState _state = _SosState.idle;
  String _spokenText = '';
  String _thaiText = '';
  String _errorKey = 'sos_error_translation';
  String _sourceLangName = 'English';
  String _currentLangCode = 'en';
  double _soundLevel = 0.0;
  bool _isRecording = false;
  bool _starting = false;
  int _elapsedSeconds = 0;

  /// Hard cap on a single recording. Keeps the base64 upload small, and is
  /// surfaced in the UI so hitting it does not look like a crash.
  static const _maxRecordSeconds = 30;

  Timer? _ampTimer;
  Timer? _maxDurationTimer;

  // BCP-47 codes for Google Cloud Speech-to-Text
  static String _gcsLocale(String langCode) {
    switch (langCode) {
      case 'zh': return 'zh-CN';
      case 'ko': return 'ko-KR';
      case 'ru': return 'ru-RU';
      case 'ja': return 'ja-JP';
      case 'th': return 'th-TH';
      default:   return 'en-US';
    }
  }

  static String _langName(String langCode) {
    switch (langCode) {
      case 'zh': return 'Chinese';
      case 'ko': return 'Korean';
      case 'ru': return 'Russian';
      case 'ja': return 'Japanese';
      case 'th': return 'Thai';
      default:   return 'English';
    }
  }

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _initServices();
  }

  Future<void> _initServices() async {
    await _tts.setLanguage('th-TH');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      if (mounted && _state == _SosState.speaking) {
        setState(() => _state = _SosState.speaking);
      }
    });
  }

  Future<bool> _ensureMicPermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _startListening() async {
    // `_state` alone is not enough of a guard: everything below the check is
    // asynchronous, so a second press can arrive while the first is still
    // waiting on the permission dialog or on the recorder, and two starts
    // against one recorder is one of the ways this screen used to lock up.
    if (_state != _SosState.idle || _starting) return;
    _starting = true;
    try {
      await _startListeningInner();
    } finally {
      _starting = false;
    }
  }

  Future<void> _startListeningInner() async {
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    final granted = await _ensureMicPermission();
    if (!granted) {
      if (mounted) {
        setState(() {
          _state = _SosState.error;
          _errorKey = 'sos_error_mic';
        });
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final audioPath = '${dir.path}/sos_recording.wav';

    setState(() {
      _state = _SosState.listening;
      _spokenText = '';
      _thaiText = '';
      _sourceLangName = _langName(langCode);
      _currentLangCode = langCode;
      _soundLevel = 0.0;
      _elapsedSeconds = 0;
      _isRecording = true;
    });

    // The previous run may still be tearing down — the TTS engine holds audio
    // focus until it is stopped, and the recorder plugin throws if start()
    // lands while a stop is in flight. This await used to be unguarded, so
    // that throw escaped an async callback with nobody to catch it and left
    // the screen sitting in `listening` with nothing recording: the freeze on
    // the second "speak again", where the button no longer did anything at
    // all.
    try {
      await _tts.stop();
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: audioPath,
      );
    } catch (error) {
      debugPrint('[SOS] recorder start failed: $error');
      _isRecording = false;
      if (mounted) {
        setState(() {
          _state = _SosState.error;
          _errorKey = 'sos_error_mic';
        });
      }
      return;
    }

    // Poll amplitude every 120ms for the sound level bar
    final startedAt = DateTime.now();
    _ampTimer = Timer.periodic(const Duration(milliseconds: 120), (_) async {
      if (!_isRecording) return;
      try {
        final amp = await _recorder.getAmplitude();
        if (mounted && _isRecording) {
          // amp.current is dBFS: -40 (silence) to 0 (max) → 0.0–1.0
          setState(() {
            _soundLevel = ((amp.current + 40) / 40).clamp(0.0, 1.0);
            _elapsedSeconds = DateTime.now().difference(startedAt).inSeconds;
          });
        }
      } catch (_) {}
    });

    // Safety cap — see _maxRecordSeconds.
    _maxDurationTimer = Timer(const Duration(seconds: _maxRecordSeconds), () {
      if (_state == _SosState.listening) _stopAndProcess();
    });
  }

  Future<void> _stopAndProcess() async {
    if (_state != _SosState.listening) return;

    _ampTimer?.cancel();
    _maxDurationTimer?.cancel();
    _isRecording = false;

    // Guarded for the same reason as start(): this await sat outside the
    // try below, so a plugin-level failure here skipped the error state
    // entirely and stranded the screen on `listening`.
    String? path;
    try {
      path = await _recorder.stop();
    } catch (error) {
      debugPrint('[SOS] recorder stop failed: $error');
    }

    if (!mounted) return;
    setState(() => _state = _SosState.processing);

    try {
      if (path == null) {
        setState(() {
          _state = _SosState.error;
          _errorKey = 'sos_error_no_speech';
        });
        return;
      }

      final audioFile = File(path);
      // < 1 KB means essentially no audio was captured
      if (!await audioFile.exists() || await audioFile.length() < 1000) {
        setState(() {
          _state = _SosState.error;
          _errorKey = 'sos_error_no_speech';
        });
        try { await audioFile.delete(); } catch (_) {}
        return;
      }

      final audioBase64 = base64Encode(await audioFile.readAsBytes());
      try { await audioFile.delete(); } catch (_) {}

      final transcript = await _transcribeWithGCS(
        audioBase64,
        _gcsLocale(_currentLangCode),
      );

      if (!mounted) return;
      if (transcript == null || transcript.trim().isEmpty) {
        setState(() {
          _state = _SosState.error;
          _errorKey = 'sos_error_no_speech';
        });
        return;
      }

      setState(() => _spokenText = transcript.trim());

      final thai = await _translateToThai(transcript.trim());
      if (!mounted) return;
      if (thai == null || thai.isEmpty) {
        setState(() {
          _state = _SosState.error;
          _errorKey = 'sos_error_translation';
        });
        return;
      }

      setState(() {
        _thaiText = thai;
        _state = _SosState.speaking;
      });
      await _tts.speak(thai);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _SosState.error;
        _errorKey = 'sos_error_translation';
      });
    }
  }

  /// Calls Google Cloud Speech-to-Text **v1** via REST. Key is injected at
  /// build time: --dart-define=GCS_STT_KEY=... Restrict the key in Cloud
  /// Console to the Speech-to-Text API only.
  ///
  /// **Why v1 and not v2/Chirp.** v2 does not accept API keys at all — every
  /// correctly formed v2 request answers
  /// `403 Permission 'speech.recognizers.recognize' denied`, in every region,
  /// because an API key carries no IAM principal. It needs OAuth, i.e. a
  /// service account, i.e. a server. The v2 code this replaced also aimed a
  /// `locations/us-central1` resource path at the *global* host, which failed
  /// earlier still with `400 Expected resource location to be global` — so
  /// SOS transcription has never worked since it was introduced.
  ///
  /// Going back to v1 loses the Chirp model. If its accuracy proves too low
  /// for tourists speaking under stress, the fix is a Cloud Function proxy
  /// holding a service account, not another attempt from the client.
  ///
  /// Verified against the live API for all six app languages before shipping:
  /// en-US, th-TH, ko-KR, ru-RU and ja-JP accept `latest_short`; zh-CN does
  /// not, hence the retry below.
  ///
  /// The recorder is configured for WAV 16 kHz mono (see `RecordConfig`
  /// above), which is exactly LINEAR16 — v1 needs that spelled out, unlike
  /// v2's `autoDecodingConfig`. Keep the two in step.
  Future<String?> _transcribeWithGCS(
    String audioBase64,
    String languageCode,
  ) async {
    const apiKey = ApiKeys.speechToText;
    if (apiKey.isEmpty) {
      debugPrint('[STT] GCS_STT_KEY not set');
      return null;
    }

    const endpoint =
        'https://speech.googleapis.com/v1/speech:recognize?key=$apiKey';

    Future<http.Response> send({required bool withModel}) {
      return http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'config': {
            'encoding': 'LINEAR16',
            'sampleRateHertz': 16000,
            'audioChannelCount': 1,
            'languageCode': languageCode,
            'enableAutomaticPunctuation': true,
            // `latest_long`, not `latest_short`, despite the recording being
            // capped at 30 seconds. The short model is tuned for commands —
            // a word or two — and someone describing an emergency pauses
            // mid-sentence, which is spontaneous speech, what the long model
            // is for. Probed against the live API on 2026-08-18: the same
            // five languages accept it as accepted `latest_short`
            // (th-TH, en-US, ko-KR, ru-RU, ja-JP), and zh-CN rejects both,
            // which the retry below already handles.
            if (withModel) 'model': 'latest_long',
          },
          'audio': {'content': audioBase64},
        }),
      ).timeout(const Duration(seconds: 30));
    }

    var response = await send(withModel: true);

    // `latest_short` is not offered for every language — zh-CN answers
    // "The requested model is currently not supported for language" with a
    // 400, and `useEnhanced` does NOT quietly fall back the way the docs
    // suggest. Retrying without the model rather than hardcoding which
    // languages support it means this keeps working whichever way Google
    // changes that list: the worst case is one wasted round trip on a request
    // that would otherwise have failed outright.
    if (response.statusCode == 400 && response.body.contains('model')) {
      debugPrint('[STT] latest_short rejected for $languageCode — retrying without it');
      response = await send(withModel: false);
    }

    debugPrint('[STT] GCS status: ${response.statusCode}');
    if (response.statusCode != 200) {
      debugPrint('[STT] GCS error: ${response.body}');
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return transcriptFromSpeechResponse(data);
  }

  Future<String?> _translateToThai(String spokenInput) async {
    const model = 'gemini-3.5-flash';
    const endpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';

    const systemInstruction =
        'You are an emergency translation assistant for tourists in Thailand. '
        'Your job: translate what the tourist says into clear, natural spoken Thai '
        'so a local Thai person understands immediately. '
        'The input may contain speech-recognition errors or incomplete words — '
        'always infer the most likely emergency meaning and produce a helpful translation. '
        'Common situations: medical emergency, theft, accident, getting lost, '
        'feeling unsafe, needing police/ambulance, overcharging, lost passport. '
        'Output ONLY the Thai translation — no explanation, no quotes, no transliteration. '
        'Always end with "ครับ".';

    final userMessage =
        'The tourist said in $_sourceLangName: "$spokenInput"';

    final body = jsonEncode({
      'systemInstruction': {
        'parts': [{'text': systemInstruction}],
      },
      'contents': [
        {
          'parts': [{'text': userMessage}],
        }
      ],
      // 200 was tight enough to clip a long sentence: Thai runs several tokens
      // per word, and any reasoning the model emits is charged against the
      // same budget before a single character of the answer is.
      'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 512},
    });

    if (ApiKeys.gemini.isEmpty) return null;

    final response = await http
        .post(
          Uri.parse('$endpoint?key=${ApiKeys.gemini}'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 20));

    debugPrint('[SOS] Gemini status: ${response.statusCode}');
    if (response.statusCode != 200) {
      debugPrint('[SOS] Gemini error body: ${response.body}');
      return null;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return textFromGeminiResponse(decoded);
  }

  Future<void> _replay() async {
    if (_thaiText.isEmpty) return;
    setState(() => _state = _SosState.speaking);
    await _tts.speak(_thaiText);
  }

  Future<void> _reset() async {
    _ampTimer?.cancel();
    _maxDurationTimer?.cancel();
    _isRecording = false;

    // The UI goes back to idle immediately; the teardown below is what the
    // user is not waiting for.
    if (mounted) {
      setState(() {
        _state = _SosState.idle;
        _spokenText = '';
        _thaiText = '';
        _soundLevel = 0.0;
      });
    }

    // Awaited now. These two were fire-and-forget, which is how a press of
    // "speak again" could reach _startListening() while the TTS engine still
    // held audio focus and the recorder was still stopping.
    try {
      await _tts.stop();
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (error) {
      debugPrint('[SOS] reset teardown failed: $error');
    }
  }

  @override
  void dispose() {
    _ampTimer?.cancel();
    _maxDurationTimer?.cancel();
    _pulseCtrl.dispose();
    _recorder.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      body: SafeArea(
        child: Column(
          children: [
            const _SosHeader(),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return switch (_state) {
      _SosState.idle => _IdleView(
          onHoldStart: _startListening,
          onHoldEnd: _stopAndProcess,
          pulseCtrl: _pulseCtrl,
        ),
      _SosState.listening => _ListeningView(
          onRelease: _stopAndProcess,
          pulseCtrl: _pulseCtrl,
          soundLevel: _soundLevel,
          elapsedSeconds: _elapsedSeconds,
          maxSeconds: _maxRecordSeconds,
        ),
      _SosState.processing => _ProcessingView(spokenText: _spokenText),
      _SosState.speaking => _SpeakingView(
          spokenText: _spokenText,
          thaiText: _thaiText,
          onReplay: _replay,
          onDone: _reset,
        ),
      _SosState.error => _ErrorView(
          errorKey: _errorKey,
          onRetry: _reset,
        ),
    };
  }
}

// ═══════════════════════════════════════════════════
// Header
// ═══════════════════════════════════════════════════

class _SosHeader extends StatelessWidget {
  const _SosHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        color: Color(0xFF0A1810),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/logo.jpg',
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ThaiShield AI',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                'AI Voice SOS',
                style: TextStyle(color: Color(0xFFFFB300), fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          Icon(Icons.help_outline_rounded,
              color: Colors.white.withValues(alpha: 0.7), size: 22),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Idle view
// ═══════════════════════════════════════════════════

class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.pulseCtrl,
  });
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final AnimationController pulseCtrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.record_voice_over_rounded,
              color: Color(0xFFEF5350), size: 52),
          const SizedBox(height: 16),
          Text(
            appText(context, 'sos_instructions'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF5D6E7F), fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 40),
          _HoldButton(
            isListening: false,
            pulseCtrl: pulseCtrl,
            onHoldStart: onHoldStart,
            onHoldEnd: onHoldEnd,
          ),
          const SizedBox(height: 16),
          Text(
            appText(context, 'sos_hold_to_speak'),
            style: const TextStyle(
                color: Color(0xFF0D1B2A),
                fontSize: 15,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 40),
          _DisclaimerBox(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Listening view — shows sound level bar, no partial text
// (transcript arrives only after the Cloud Function returns)
// ═══════════════════════════════════════════════════

class _ListeningView extends StatelessWidget {
  const _ListeningView({
    required this.onRelease,
    required this.pulseCtrl,
    required this.soundLevel,
    required this.elapsedSeconds,
    required this.maxSeconds,
  });
  final VoidCallback onRelease;
  final AnimationController pulseCtrl;
  final double soundLevel;
  final int elapsedSeconds;
  final int maxSeconds;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            appText(context, 'sos_listening'),
            style: const TextStyle(
                color: Color(0xFFEF5350),
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Live microphone level indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: soundLevel,
              minHeight: 6,
              backgroundColor: const Color(0xFFFFCDD2),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFEF5350)),
            ),
          ),
          const SizedBox(height: 20),
          _HoldButton(
            isListening: true,
            pulseCtrl: pulseCtrl,
            onHoldStart: () {},
            onHoldEnd: onRelease,
          ),
          const SizedBox(height: 28),
          // This used to be a white card containing "...", left over from the
          // device-native STT that streamed words in as you spoke. Cloud
          // recognition is a single request made after you let go, so that
          // card could never fill in — it just looked like the app had
          // stopped working. Guidance is the honest use of the space.
          Text(
            appText(context, 'sos_hold_hint'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF78909C), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 10),
          // The recorder force-stops at 30 s to keep the upload small. Before
          // this, that cap fired with no warning and looked like a crash.
          Text(
            '$elapsedSeconds / $maxSeconds s',
            style: TextStyle(
              color: elapsedSeconds >= maxSeconds - 5
                  ? const Color(0xFFEF5350)
                  : const Color(0xFF90A4AE),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Processing view
// ═══════════════════════════════════════════════════

class _ProcessingView extends StatelessWidget {
  const _ProcessingView({required this.spokenText});
  final String spokenText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
              color: Color(0xFFEF5350), strokeWidth: 3),
          const SizedBox(height: 20),
          Text(
            appText(context, 'sos_processing'),
            style: const TextStyle(
                color: Color(0xFF0D1B2A),
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          if (spokenText.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appText(context, 'sos_you_said'),
                      style: const TextStyle(
                          color: Color(0xFF90A4AE),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('"$spokenText"',
                      style: const TextStyle(
                          color: Color(0xFF0D1B2A),
                          fontSize: 14,
                          height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Speaking view
// ═══════════════════════════════════════════════════

class _SpeakingView extends StatelessWidget {
  const _SpeakingView({
    required this.spokenText,
    required this.thaiText,
    required this.onReplay,
    required this.onDone,
  });
  final String spokenText;
  final String thaiText;
  final VoidCallback onReplay;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Transcription card (what GCS Chirp heard)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mic_rounded,
                        color: Color(0xFF90A4AE), size: 16),
                    const SizedBox(width: 6),
                    Text(appText(context, 'sos_you_said'),
                        style: const TextStyle(
                            color: Color(0xFF90A4AE),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('"$spokenText"',
                    style: const TextStyle(
                        color: Color(0xFF0D1B2A),
                        fontSize: 14,
                        height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Thai response card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1810),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF0A1810).withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.volume_up_rounded,
                        color: Color(0xFFFFB300), size: 18),
                    const SizedBox(width: 8),
                    Text(appText(context, 'sos_speaking_th'),
                        style: const TextStyle(
                            color: Color(0xFFFFB300),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  thaiText,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 22, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReplay,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF5350),
                    side: const BorderSide(color: Color(0xFFEF5350)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: Text(appText(context, 'sos_replay'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A1810),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                  icon: const Icon(Icons.mic_rounded, size: 18),
                  label: Text(appText(context, 'sos_done'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _DisclaimerBox(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Error view
// ═══════════════════════════════════════════════════

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.errorKey, required this.onRetry});
  final String errorKey;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.error_outline_rounded,
                color: Color(0xFFEF5350), size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            appText(context, errorKey),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF0D1B2A), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(appText(context, 'sos_try_again'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Hold button with pulse animation
// ═══════════════════════════════════════════════════

class _HoldButton extends StatelessWidget {
  const _HoldButton({
    required this.isListening,
    required this.pulseCtrl,
    required this.onHoldStart,
    required this.onHoldEnd,
  });
  final bool isListening;
  final AnimationController pulseCtrl;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (context, child) {
        final pulse = isListening ? (1.0 + pulseCtrl.value * 0.25) : 1.0;
        return Listener(
          onPointerDown: (_) => onHoldStart(),
          onPointerUp: (_) => onHoldEnd(),
          onPointerCancel: (_) => onHoldEnd(),
          child: Transform.scale(
            scale: pulse,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isListening
                    ? const Color(0xFFEF5350)
                    : const Color(0xFFFFEBEE),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF5350)
                        .withValues(alpha: isListening ? 0.5 : 0.2),
                    blurRadius: isListening ? 28 : 12,
                    spreadRadius: isListening ? 6 : 2,
                  ),
                ],
              ),
              child: Icon(
                isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color:
                    isListening ? Colors.white : const Color(0xFFEF5350),
                size: 48,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════
// Disclaimer box
// ═══════════════════════════════════════════════════

class _DisclaimerBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFFFB300).withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFFFFB300), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              appText(context, 'sos_disclaimer'),
              style: const TextStyle(
                  color: Color(0xFF5D4037), fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
