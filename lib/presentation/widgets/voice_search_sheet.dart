import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceSearchSheet extends StatefulWidget {
  const VoiceSearchSheet({super.key});

  @override
  State<VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<VoiceSearchSheet> {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _transcription = '';
  String _statusText = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux) {
      setState(() {
        _statusText = 'Voice search is only supported on Android/iOS/macOS';
      });
      return;
    }

    try {
      final available = await _speech.initialize(
        onError: (val) => setState(() => _statusText = 'Error: ${val.errorMsg}'),
        onStatus: (val) {
          if (val == 'listening') {
            setState(() => _isListening = true);
          } else if (val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
      );
      if (available) {
        setState(() {
          _isInitialized = true;
          _statusText = 'Listening...';
        });
        _startListening();
      } else {
        setState(() {
          _statusText = 'Speech recognition not available';
        });
      }
    } catch (e) {
      setState(() {
        _statusText = 'Initialization error: $e';
      });
    }
  }

  void _startListening() async {
    setState(() {
      _transcription = '';
      _statusText = 'Listening...';
    });
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _transcription = result.recognizedWords;
          if (result.finalResult) {
            _statusText = 'Tap Check to search';
          }
        });
      },
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Text(
            _isListening ? 'Speak Now' : 'Voice Search',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            _transcription.isEmpty ? _statusText : _transcription,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: _transcription.isEmpty ? Colors.white54 : Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
              GestureDetector(
                onTap: () {
                  if (!_isInitialized) return;
                  if (_isListening) {
                    _stopListening();
                  } else {
                    _startListening();
                  }
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? theme.colorScheme.primary : Colors.white24,
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.check, color: Colors.white, size: 28),
                onPressed: _transcription.isNotEmpty
                    ? () => Navigator.pop(context, _transcription)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
