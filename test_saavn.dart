import 'package:dio/dio.dart';
import 'lib/core/services/jiosaavn_service.dart';

void main() async {
  final dio = Dio();
  final saavn = JioSaavnService(dio);
  final url = await saavn.getStreamUrl('glfUm7JM');
  print('Resolved URL: $url');
}
