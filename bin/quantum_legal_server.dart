/// Sprint S5 — 참조 REST 서버: POST /v1/quantum-legal/resolve
///
/// 실행: `dart run bin/quantum_legal_server.dart` (프로젝트 루트)
library;

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:sgp_agent/features/agent/sgp_legal_hierarchy.dart';
import 'package:sgp_agent/features/agent/sgp_quantum_legal_api.dart';

Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final seedPath = Platform.environment['SEED_PATH'] ?? 'assets/data/legal_hierarchy_seed.json';

  final seedFile = File(seedPath);
  if (!seedFile.existsSync()) {
    stderr.writeln('Seed not found: $seedPath');
    exit(1);
  }
  SgpLegalHierarchyRegistry.instance.loadFromJson(await seedFile.readAsString());
  stderr.writeln('Loaded ${SgpLegalHierarchyRegistry.instance.allNodes.length} hierarchy nodes');

  final router = Router();
  router.get('/health', (_) => Response.ok('ok'));
  router.post('/v1/quantum-legal/resolve', _resolveHandler);

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(router.call);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stderr.writeln('Quantum legal server listening on http://${server.address.host}:${server.port}');
}

Future<Response> _resolveHandler(Request request) async {
  if (request.method != 'POST') {
    return Response(405, body: 'Method Not Allowed');
  }

  final body = await request.readAsString();
  Map<String, dynamic> json;
  try {
    json = jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    return Response(400, body: jsonEncode({'error': 'invalid_json'}));
  }

  final resolveRequest = QuantumLegalResolveRequest.fromJson(json);
  final authHeader = request.headers['authorization'];
  if (!authorizeResolveRequest(
    request: resolveRequest,
    bearerToken: authHeader,
  )) {
    return Response(
      401,
      body: jsonEncode({'error': 'unauthorized', 'message': 'JWT org_id mismatch'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final claims = ActorSessionClaims.fromJwtPayloadString(
    authHeader!.startsWith('Bearer ') ? authHeader.substring(7) : authHeader,
  );

  final comparison = executeQuantumLegalResolve(
    resolveRequest,
    orgIdOverride: claims?.orgId ?? resolveRequest.actor.orgId,
  );

  final response = QuantumLegalResolveResponse.fromComparison(
    comparison,
    resolvedBy: 'server',
  );

  return Response.ok(
    jsonEncode(response.toJson()),
    headers: {'Content-Type': 'application/json; charset=utf-8'},
  );
}
