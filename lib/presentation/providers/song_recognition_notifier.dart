import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/song_recognition_repository.dart';
import '../../data/repositories/song_recognition_repository_impl.dart';

enum SongRecognitionStatus { idle, listening, success, error }

class SongRecognitionState {
  final SongRecognitionStatus status;
  final double amplitude;
  final Song? recognizedSong;
  final String? errorMessage;

  const SongRecognitionState({
    required this.status,
    required this.amplitude,
    this.recognizedSong,
    this.errorMessage,
  });

  SongRecognitionState copyWith({
    SongRecognitionStatus? status,
    double? amplitude,
    Song? recognizedSong,
    String? errorMessage,
  }) {
    return SongRecognitionState(
      status: status ?? this.status,
      amplitude: amplitude ?? this.amplitude,
      recognizedSong: recognizedSong ?? this.recognizedSong,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final songRecognitionProvider =
    StateNotifierProvider<SongRecognitionNotifier, SongRecognitionState>((ref) {
  final repository = ref.watch(songRecognitionRepositoryProvider);
  return SongRecognitionNotifier(repository);
});

class SongRecognitionNotifier extends StateNotifier<SongRecognitionState> {
  final SongRecognitionRepository _repository;
  StreamSubscription<double>? _amplitudeSubscription;

  SongRecognitionNotifier(this._repository)
      : super(const SongRecognitionState(
          status: SongRecognitionStatus.idle,
          amplitude: 0.0,
        ));

  Future<void> startListening() async {
    if (state.status == SongRecognitionStatus.listening) return;

    state = const SongRecognitionState(
      status: SongRecognitionStatus.listening,
      amplitude: 0.0,
    );

    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _repository.microphoneAmplitudeStream.listen((amp) {
      if (state.status == SongRecognitionStatus.listening) {
        state = state.copyWith(amplitude: amp);
      }
    });

    try {
      final song = await _repository.identifySong();
      if (song != null) {
        state = state.copyWith(
          status: SongRecognitionStatus.success,
          recognizedSong: song,
        );
      } else {
        state = state.copyWith(
          status: SongRecognitionStatus.error,
          errorMessage: 'Could not identify song.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: SongRecognitionStatus.error,
        errorMessage: e.toString(),
      );
    } finally {
      await _amplitudeSubscription?.cancel();
    }
  }

  void cancel() {
    _repository.cancelIdentification();
    _amplitudeSubscription?.cancel();
    state = const SongRecognitionState(
      status: SongRecognitionStatus.idle,
      amplitude: 0.0,
    );
  }

  @override
  void dispose() {
    _amplitudeSubscription?.cancel();
    super.dispose();
  }
}
