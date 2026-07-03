import 'dart:io';
import '../utils/logger.dart';

class AudioProxy {
  HttpServer? _server;
  final _log = AppLogger('AudioProxy');

  int get port => _server?.port ?? 0;

  /// Starts the local HTTP server on a random loopback port
  Future<void> start() async {
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _log.info('AudioProxy listening locally on 127.0.0.1:$port');
      _server!.listen(_handleRequest, onError: (Object e) {
        _log.error('AudioProxy request listener error: $e');
      });
    } catch (e, s) {
      _log.error('Failed to start AudioProxy server: $e', e, s);
    }
  }

  /// Closes the proxy server
  void close() {
    _server?.close(force: true);
  }

  /// Pipes stream bytes from the resolved URL to the player
  void _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    if (!path.startsWith('/stream/')) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final encodedUrl = path.substring('/stream/'.length);
    if (encodedUrl.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final decodedUrl = Uri.decodeComponent(encodedUrl);
    _log.info('Proxying stream request for URL: ${decodedUrl.length > 80 ? '${decodedUrl.substring(0, 80)}...' : decodedUrl}');

    HttpClient? client;
    try {
      client = HttpClient();
      final rangeHeader = request.headers.value('range');
      _log.debug('Incoming request Range header: $rangeHeader');

      // Forward request to target resolved URL
      final proxyRequest = await client.getUrl(Uri.parse(decodedUrl));
      if (rangeHeader != null) {
        proxyRequest.headers.set(HttpHeaders.rangeHeader, rangeHeader);
      }

      final proxyResponse = await proxyRequest.close();
      _log.info('Proxy response status: ${proxyResponse.statusCode}, contentLength: ${proxyResponse.contentLength}');

      // Copy headers from proxyResponse to client response
      request.response.statusCode = proxyResponse.statusCode;
      proxyResponse.headers.forEach((name, values) {
        // Exclude headers managed by addStream/HttpClient connection
        final lowerName = name.toLowerCase();
        if (lowerName != 'transfer-encoding' && 
            lowerName != 'content-encoding' &&
            lowerName != 'connection') {
          for (final value in values) {
            request.response.headers.add(name, value);
          }
        }
      });

      // Stream the response body
      await request.response.addStream(proxyResponse);
      await request.response.close();
    } catch (e, s) {
      _log.error('AudioProxy failed to stream resolved URL: $e', e, s);
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    } finally {
      client?.close();
    }
  }
}
