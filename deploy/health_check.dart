/// API /health 프로브 (docker-compose healthcheck).
import 'dart:io';

Future<void> main() async {
  final port = Platform.environment['PORT'] ?? '8080';
  final client = HttpClient();
  try {
    final request = await client
        .getUrl(Uri.parse('http://127.0.0.1:$port/health'))
        .timeout(const Duration(seconds: 8));
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      exit(0);
    }
    stderr.writeln('health status: ${response.statusCode}');
    exit(1);
  } catch (e) {
    stderr.writeln('health check failed: $e');
    exit(1);
  } finally {
    client.close(force: true);
  }
}
