import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/config/api_keys.dart';
import '../../../core/localization/app_text.dart';

enum _SosState { idle, listening, processing, speaking, error }

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  final _stt = SpeechToText();
  final _tts = FlutterTts();

  _SosState _state = _SosState.idle;
  String _spokenText = '';
  String _thaiText = '';
  String _errorKey = 'sos_error_translation';
  bool _sttAvailable = false;

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
    if (_state != _SosState.idle) return;

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

    if (!_sttAvailable) {
      _sttAvailable = await _stt.initialize(
        onError: (_) {
          if (mounted && _state == _SosState.listening) {
            setState(() {
              _state = _SosState.error;
              _errorKey = 'sos_error_mic';
            });
          }
        },
      );
    }

    if (!_sttAvailable) {
      setState(() {
        _state = _SosState.error;
        _errorKey = 'sos_error_mic';
      });
      return;
    }

    setState(() {
      _state = _SosState.listening;
      _spokenText = '';
      _thaiText = '';
    });
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) {
        if (mounted) setState(() => _spokenText = r.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        localeId: 'en_US',
        pauseFor: const Duration(seconds: 3),
        listenMode: ListenMode.confirmation,
        cancelOnError: true,
      ),
    );
  }

  Future<void> _stopAndProcess() async {
    if (_state != _SosState.listening) return;
    await _stt.stop();
    final text = _spokenText.trim();
    if (text.isEmpty) {
      setState(() {
        _state = _SosState.error;
        _errorKey = 'sos_error_no_speech';
      });
      return;
    }
    setState(() => _state = _SosState.processing);
    try {
      final thai = await _translateToThai(text);
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

  Future<String?> _translateToThai(String english) async {
    const model = 'gemini-2.5-flash';
    const endpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';

    final prompt =
        'You are an emergency communication assistant for foreign tourists in Thailand. '
        'The tourist said in English: "$english"\n'
        'Translate this into natural, concise spoken Thai (1–2 sentences) so a local '
        'Thai person can understand immediately. '
        'The response MUST end with "ครับ". '
        'Reply with ONLY the Thai text — no explanation, no quotes, no transliteration.';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 200},
    });

    final response = await http
        .post(
          Uri.parse('$endpoint?key=${ApiKeys.gemini}'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;
    final parts = (candidates.first['content']?['parts'] as List?) ?? [];
    if (parts.isEmpty) return null;
    return (parts.first['text'] as String?)?.trim();
  }

  Future<void> _replay() async {
    if (_thaiText.isEmpty) return;
    setState(() => _state = _SosState.speaking);
    await _tts.speak(_thaiText);
  }

  void _reset() {
    _stt.stop();
    _tts.stop();
    setState(() {
      _state = _SosState.idle;
      _spokenText = '';
      _thaiText = '';
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _stt.stop();
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
          spokenText: _spokenText,
          onRelease: _stopAndProcess,
          pulseCtrl: _pulseCtrl,
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
// Listening view
// ═══════════════════════════════════════════════════

class _ListeningView extends StatelessWidget {
  const _ListeningView({
    required this.spokenText,
    required this.onRelease,
    required this.pulseCtrl,
  });
  final String spokenText;
  final VoidCallback onRelease;
  final AnimationController pulseCtrl;

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
          const SizedBox(height: 32),
          _HoldButton(
            isListening: true,
            pulseCtrl: pulseCtrl,
            onHoldStart: () {},
            onHoldEnd: onRelease,
          ),
          const SizedBox(height: 28),
          if (spokenText.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: const Color(0xFFEF5350).withValues(alpha: 0.3)),
              ),
              child: Text(
                '"$spokenText"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF0D1B2A), fontSize: 15, height: 1.5),
              ),
            ),
          ],
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
                          color: Color(0xFF0D1B2A), fontSize: 14, height: 1.4)),
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
          // English input card
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
                        color: Color(0xFF0D1B2A), fontSize: 14, height: 1.5)),
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
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
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
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
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
            style:
                const TextStyle(color: Color(0xFF0D1B2A), fontSize: 14, height: 1.5),
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
