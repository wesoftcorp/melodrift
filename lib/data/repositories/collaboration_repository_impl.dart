import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../domain/entities/listening_room.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/collaboration_repository.dart';
import '../../flavors.dart';
import '../../core/theme/theme_provider.dart';

final collaborationRepositoryProvider = Provider<CollaborationRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CollaborationRepositoryImpl(prefs);
});

class CollaborationRepositoryImpl implements CollaborationRepository {
  static final Map<String, ListeningRoom> _rooms = {};
  static final Map<String, StreamController<ListeningRoom>> _controllers = {};
  final SharedPreferences _prefs;
  final Random _random = Random();

  CollaborationRepositoryImpl(this._prefs);

  bool get _useFirebase => F.isFull && (_prefs.getBool('use_firebase') ?? false);

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

    if (_useFirebase) {
      try {
        final ref = FirebaseDatabase.instance.ref('rooms/$roomId');
        await ref.set({
          'roomId': roomId,
          'hostId': hostId,
          'positionMs': 0,
          'isPlaying': false,
          'participants': [hostId],
          'currentSong': null,
        });
        return room;
      } catch (_) {
        // Fall back to local room
      }
    }

    _rooms[roomId] = room;
    _getOrCreateController(roomId).add(room);
    return room;
  }

  @override
  Future<ListeningRoom> joinRoom(String roomId, String participantId) async {
    if (_useFirebase) {
      try {
        final ref = FirebaseDatabase.instance.ref('rooms/$roomId');
        final snapshot = await ref.get();
        if (!snapshot.exists) {
          throw Exception('Room $roomId not found on server');
        }

        final data = snapshot.value as Map;
        final participants = <String>[];
        final parts = data['participants'];
        if (parts is List) {
          participants.addAll(parts.map((e) => e.toString()));
        }

        if (!participants.contains(participantId)) {
          participants.add(participantId);
          await ref.update({'participants': participants});
        }

        return _mapSnapshotToRoom(roomId, data);
      } catch (e) {
        if (e.toString().contains('not found')) rethrow;
        // Fall back to local room
      }
    }

    final room = _rooms[roomId];
    if (room == null) {
      throw Exception('Room $roomId not found locally');
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
    if (_useFirebase) {
      try {
        final ref = FirebaseDatabase.instance.ref('rooms/$roomId');
        final snapshot = await ref.get();
        if (snapshot.exists) {
          final data = snapshot.value as Map;
          final participants = <String>[];
          final parts = data['participants'];
          if (parts is List) {
            participants.addAll(parts.map((e) => e.toString()));
          }

          participants.remove(participantId);
          if (participants.isEmpty) {
            await ref.remove();
          } else {
            await ref.update({'participants': participants});
          }
          return;
        }
      } catch (_) {
        // Fall back to local room
      }
    }

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
    if (_useFirebase) {
      try {
        final ref = FirebaseDatabase.instance.ref('rooms/$roomId');
        return ref.onValue.map((event) {
          final val = event.snapshot.value;
          if (val is Map) {
            return _mapSnapshotToRoom(roomId, val);
          }
          throw Exception('Invalid room data');
        });
      } catch (_) {}
    }
    return _getOrCreateController(roomId).stream;
  }

  @override
  Future<void> updatePlaybackState(
    String roomId, {
    required Song? currentSong,
    required Duration position,
    required bool isPlaying,
  }) async {
    if (_useFirebase) {
      try {
        final ref = FirebaseDatabase.instance.ref('rooms/$roomId');
        final Map<String, dynamic>? songMap = currentSong == null
            ? null
            : {
                'id': currentSong.id,
                'title': currentSong.title,
                'artist': currentSong.artist,
                'album': currentSong.album,
                'durationMs': currentSong.duration.inMilliseconds,
                'artworkUrl': currentSong.artworkUrl,
                'videoId': currentSong.videoId,
                'streamUrl': currentSong.streamUrl,
              };

        await ref.update({
          'currentSong': songMap,
          'positionMs': position.inMilliseconds,
          'isPlaying': isPlaying,
        });
        return;
      } catch (_) {
        // Fall back to local room
      }
    }

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

  ListeningRoom _mapSnapshotToRoom(String roomId, Map<dynamic, dynamic> data) {
    final hostId = data['hostId'] as String? ?? '';
    final positionMs = data['positionMs'] as int? ?? 0;
    final isPlaying = data['isPlaying'] as bool? ?? false;

    final participantsList = <String>[];
    final parts = data['participants'];
    if (parts is List) {
      participantsList.addAll(parts.map((e) => e.toString()));
    }

    Song? song;
    final songData = data['currentSong'];
    if (songData is Map) {
      song = Song(
        id: songData['id'] as String? ?? '',
        title: songData['title'] as String? ?? '',
        artist: songData['artist'] as String? ?? '',
        album: songData['album'] as String? ?? '',
        duration: Duration(milliseconds: songData['durationMs'] as int? ?? 0),
        artworkUrl: songData['artworkUrl'] as String? ?? '',
        videoId: songData['videoId'] as String? ?? '',
        streamUrl: songData['streamUrl'] as String?,
      );
    }

    return ListeningRoom(
      roomId: roomId,
      hostId: hostId,
      position: Duration(milliseconds: positionMs),
      isPlaying: isPlaying,
      participants: participantsList,
      currentSong: song,
    );
  }

  StreamController<ListeningRoom> _getOrCreateController(String roomId) {
    return _controllers.putIfAbsent(
      roomId,
      () => StreamController<ListeningRoom>.broadcast(),
    );
  }
}
