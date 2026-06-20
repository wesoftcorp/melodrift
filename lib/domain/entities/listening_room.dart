import 'song.dart';

class ListeningRoom {
  final String roomId;
  final String hostId;
  final Song? currentSong;
  final Duration position;
  final bool isPlaying;
  final List<String> participants;

  const ListeningRoom({
    required this.roomId,
    required this.hostId,
    required this.position,
    required this.isPlaying,
    required this.participants,
    this.currentSong,
  });
}
