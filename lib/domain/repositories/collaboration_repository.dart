import '../entities/listening_room.dart';
import '../entities/song.dart';

abstract class CollaborationRepository {
  /// Create a new collaborative listening room
  Future<ListeningRoom> createRoom(String hostId);

  /// Join an existing room by its ID
  Future<ListeningRoom> joinRoom(String roomId, String participantId);

  /// Leave the active room
  Future<void> leaveRoom(String roomId, String participantId);

  /// Stream to listen to real-time room updates (participants, playback state)
  Stream<ListeningRoom> watchRoom(String roomId);

  /// Push playback state updates (for host use only)
  Future<void> updatePlaybackState(
    String roomId, {
    required Song? currentSong,
    required Duration position,
    required bool isPlaying,
  });
}
