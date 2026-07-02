import 'package:dio/dio.dart';
void main() async {
  final dio = Dio();
  final response = await dio.get('https://jiosaavn.softcorpllc.workers.dev/api/songs?ids=glfUm7JM');
  final data = response.data['data'] as List<dynamic>?;
  final songData = data!.first as Map<String, dynamic>;
  final downloadUrlsRaw = songData['downloadUrl'] as List<dynamic>? ?? [];
  final downloadUrls = downloadUrlsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  final urlObj = downloadUrls.firstWhere((e) => e['quality'] == '320kbps', orElse: () => downloadUrls.last);
  print(urlObj['link'] ?? urlObj['url']);
}
