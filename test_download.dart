import 'package:dio/dio.dart';
import 'dart:io';

void main() async {
  final dio = Dio();
  final response = await dio.get(
    'https://aac.saavncdn.com/685/10ab095871edf5db7de13af2644b23cd_320.mp4',
    options: Options(responseType: ResponseType.stream)
  );
  
  final file = File('test.mp4');
  final raf = file.openSync(mode: FileMode.write);
  await for (final chunk in response.data.stream) {
    raf.writeFromSync(chunk);
  }
  raf.closeSync();
  print('Downloaded: \${file.lengthSync()} bytes');
}
