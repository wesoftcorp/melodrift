import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/collaboration_repository_impl.dart';
import '../../domain/entities/listening_room.dart';
import '../../domain/repositories/collaboration_repository.dart';
import 'player_notifier.dart';

class CollaborationState {
  final ListeningRoom? room;
  final String userId;
  final bool isHost;
  final bool isLoading;
  final String? error;

  const CollaborationState({
    required this.userId,
    this.room,
    this.isHost = false,
    this.isLoading = false,
    this.error,
  });

  CollaborationState copyWith({
    ListeningRoom? room,
    String? userId,
    bool? isHost,
    bool? isLoading,
    String? error,
  }) {
    return CollaborationState(
      room: room ?? this.room,
      userId: userId ?? this.userId,
      isHost: isHost ?? this.isHost,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final collaborationProvider = StateNotifierProvider<CollaborationNotifier, CollaborationState>((ref) {
  final repo = ref.watch(collaborationRepositoryProvider);
  return CollaborationNotifier(repo, ref);
});

class CollaborationNotifier extends StateNotifier<CollaborationState> {
  final CollaborationRepository _repo;
  final Ref _ref;
  StreamSubscription<ListeningRoom>? _subscription;

  CollaborationNotifier(this._repo, this._ref)
      : super(CollaborationState(userId: 'user_${1000 + Random().nextInt(9000)}')) {
    _listenToPlayer();
  }

  void _listenToPlayer() {
    _ref.listen(playerStateProvider, (prev, next) {
      final room = state.room;
      if (state.isHost && room != null) {
        _repo.updatePlaybackState(
          room.roomId,
          currentSong: next.currentSong,
          position: next.position,
          isPlaying: next.isPlaying,
        );
      }
    });
  }

  Future<void> createRoom() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final room = await _repo.createRoom(state.userId);
      state = state.copyWith(room: room, isHost: true, isLoading: false);
      _startListening(room.roomId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> joinRoom(String roomId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final room = await _repo.joinRoom(roomId, state.userId);
      state = state.copyWith(room: room, isHost: false, isLoading: false);
      _startListening(roomId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> leaveRoom() async {
    final room = state.room;
    if (room != null) {
      await _repo.leaveRoom(room.roomId, state.userId);
    }
    await _subscription?.cancel();
    state = CollaborationState(userId: state.userId);
  }

  void _startListening(String roomId) {
    _subscription?.cancel();
    _subscription = _repo.watchRoom(roomId).listen((room) {
      state = state.copyWith(room: room);
      if (!state.isHost) {
        _syncPlayerState(room);
      }
    });
  }

  void _syncPlayerState(ListeningRoom room) {
    final playerNotifier = _ref.read(playerStateProvider.notifier);
    final playerState = _ref.read(playerStateProvider);

    // Sync song
    if (room.currentSong != null && playerState.currentSong?.id != room.currentSong?.id) {
      playerNotifier.playSong(room.currentSong!);
    }

    // Sync playing status
    if (playerState.isPlaying != room.isPlaying) {
      playerNotifier.togglePlay();
    }

    // Sync position (if drift > 3 seconds)
    final drift = (playerState.position.inMilliseconds - room.position.inMilliseconds).abs();
    if (drift > 3000) {
      playerNotifier.seek(room.position);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
