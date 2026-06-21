import '../entities/song.dart';

abstract class SongRecognitionRepository {
  /// Stream of microphone amplitude values (0.0 to 1.0) to feed UI wave visualizers.
  Stream<double> get microphoneAmplitudeStream;

  /// Starts capturing audio from the microphone and attempts to identify the ambient song.
  /// Returns the identified [Song] or null if identification failed or was cancelled.
  Future<Song?> identifySong();

  /// Cancels the current identification process.
  void cancelIdentification();
}
