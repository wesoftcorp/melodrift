import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/listening_room.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/collaboration_repository.dart';

final collaborationRepositoryProvider = Provider<CollaborationRepository>((ref) {
  return CollaborationRepositoryImpl();
});

class CollaborationRepositoryImpl implements CollaborationRepository {
  static final Map<String, ListeningRoom> _rooms = {};
  static final Map<String, StreamController<ListeningRoom>> _controllers = {};
  final Random _random = Random();

  @override
  Future<ListeningRoom> createRoom(String hostId) async {
    final roomId = (100000 + _random.nextInt(900000)).toString();
    final room = ListeningRoom(
      roomId: roomId,
      hostId: hostId,
      position: Duration.zero,
      isPlaying: false,
      participants: [hostId],
    );
    _rooms[roomId] = room;
    _getOrCreateController(roomId).add(room);
    return room;
  }

  @override
  Future<ListeningRoom> joinRoom(String roomId, String participantId) async {
    final room = _rooms[roomId];
    if (room == null) {
      throw Exception('Room $roomId not found');
    }

    final participants = List<String>.from(room.participants);
    if (!participants.contains(participantId)) {
      participants.add(participantId);
    }

    final updatedRoom = ListeningRoom(
      roomId: room.roomId,
      hostId: room.hostId,
      currentSong: room.currentSong,
      position: room.position,
      isPlaying: room.isPlaying,
      participants: participants,
    );

    _rooms[roomId] = updatedRoom;
    _getOrCreateController(roomId).add(updatedRoom);
    return updatedRoom;
  }

  @override
  Future<void> leaveRoom(String roomId, String participantId) async {
    final room = _rooms[roomId];
    if (room == null) return;

    final participants = List<String>.from(room.participants)..remove(participantId);
    final updatedRoom = ListeningRoom(
      roomId: room.roomId,
      hostId: room.hostId,
      currentSong: room.currentSong,
      position: room.position,
      isPlaying: room.isPlaying,
      participants: participants,
    );

    _rooms[roomId] = updatedRoom;
    _getOrCreateController(roomId).add(updatedRoom);
  }

  @override
  Stream<ListeningRoom> watchRoom(String roomId) {
    return _getOrCreateController(roomId).stream;
  }

  @override
  Future<void> updatePlaybackState(
    String roomId, {
    required Song? currentSong,
    required Duration position,
    required bool isPlaying,
  }) async {
    final room = _rooms[roomId];
    if (room == null) return;

    final updatedRoom = ListeningRoom(
      roomId: room.roomId,
      hostId: room.hostId,
      currentSong: currentSong,
      position: position,
      isPlaying: isPlaying,
      participants: room.participants,
    );

    _rooms[roomId] = updatedRoom;
    _getOrCreateController(roomId).add(updatedRoom);
  }

  StreamController<ListeningRoom> _getOrCreateController(String roomId) {
    return _controllers.putIfAbsent(
      roomId,
      () => StreamController<ListeningRoom>.broadcast(),
    );
  }
}
