import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/song_recognition_repository.dart';

final songRecognitionRepositoryProvider = Provider<SongRecognitionRepository>((ref) {
  return SongRecognitionRepositoryImpl();
});

class SongRecognitionRepositoryImpl implements SongRecognitionRepository {
  final _random = Random();
  StreamController<double>? _amplitudeController;
  Timer? _amplitudeTimer;
  bool _isIdentifying = false;

  @override
  Stream<double> get microphoneAmplitudeStream {
    _amplitudeController?.close();
    _amplitudeTimer?.cancel();

    _amplitudeController = StreamController<double>.broadcast(
      onListen: () {
        _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
          if (_amplitudeController != null && !_amplitudeController!.isClosed) {
            // Generate standard background voice/music amplitude simulation (0.1 to 0.9)
            final base = 0.2 + 0.4 * sin(timer.tick * 0.5);
            final noise = _random.nextDouble() * 0.3;
            _amplitudeController!.add((base + noise).clamp(0.0, 1.0));
          }
        });
      },
      onCancel: () {
        _amplitudeTimer?.cancel();
      },
    );

    return _amplitudeController!.stream;
  }

  @override
  Future<Song?> identifySong() async {
    _isIdentifying = true;
    
    // Simulate 4 seconds of listening and network lookup latency
    await Future<void>.delayed(const Duration(seconds: 4));

    if (!_isIdentifying) return null;
    _isIdentifying = false;

    // Return a premium mock identified song
    return const Song(
      id: 'dQw4w9WgXcQ',
      title: 'Never Gonna Give You Up',
      artist: 'Rick Astley',
      album: 'Whenever You Need Somebody',
      duration: Duration(minutes: 3, seconds: 32),
      artworkUrl: 'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      videoId: 'dQw4w9WgXcQ',
    );
  }

  @override
  void cancelIdentification() {
    _isIdentifying = false;
    _amplitudeTimer?.cancel();
    _amplitudeController?.close();
  }
}
