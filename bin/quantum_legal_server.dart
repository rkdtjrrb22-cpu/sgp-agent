/// Sprint S6 — 참조 REST 서버 (온톨로지·경찰 IAM JWT·프로덕션 설정).
///
/// 실행: `dart run bin/quantum_legal_server.dart`
library;

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:sgp_agent/features/agent/sgp_legal_hierarchy.dart';
import 'package:sgp_agent/features/agent/sgp_legal_ontology.dart';
import 'package:sgp_agent/features/agent/sgp_legal_ontology_api.dart';
import 'package:sgp_agent/features/agent/sgp_npa_iam_jwt.dart';
import 'package:sgp_agent/features/agent/sgp_npa_iam_jwks.dart';
import 'package:sgp_agent/features/agent/sgp_quantum_legal_api.dart';

late LegalOntologyGraph _ontologyGraph;
late NpaIamJwtConfig _iamConfig;
late NpaIamJwksVerifier _jwksVerifier;

Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final seedPath = Platform.environment['SEED_PATH'] ?? 'assets/data/legal_hierarchy_seed.json';
  _iamConfig = NpaIamJwtConfig.fromEnvironment(Platform.environment);
  _jwksVerifier = NpaIamJwksVerifier();

  if (_iamConfig.shouldVerifyJwksSignature) {
    final warmed = await _jwksVerifier.warmUp(_iamConfig.jwksUrl);
    stderr.writeln('JWKS warm-up: ${warmed ? 'ok' : 'failed'} (${_iamConfig.jwksUrl})');
  }

  final seedFile = File(seedPath);
  if (!seedFile.existsSync()) {
    stderr.writeln('Seed not found: $seedPath');
    exit(1);
  }
  SgpLegalHierarchyRegistry.instance.loadFromJson(await seedFile.readAsString());
  _ontologyGraph = LegalOntologyMigrator.graphFromRegistry(
    SgpLegalHierarchyRegistry.instance,
  );

  stderr.writeln(
    'Loaded ${SgpLegalHierarchyRegistry.instance.allNodes.length} nodes, '
    '${_ontologyGraph.triples.length} ontology triples',
  );
  stderr.writeln('IAM JWT mode: ${_iamConfig.mode.name} | JWKS verify: ${_iamConfig.shouldVerifyJwksSignature}');

  final router = Router();
  router.get('/health', (_) => Response.ok('ok'));
  router.post('/v1/quantum-legal/resolve', _resolveHandler);
  router.get('/v1/legal-ontology/graph', _ontologyGraphHandler);
  router.post('/v1/legal-ontology/triples/query', _ontologyQueryHandler);
  router.get('/v1/legal-ontology/migrate/preview', _ontologyMigratePreviewHandler);

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(router.call);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stderr.writeln('Quantum legal server listening on http://${server.address.host}:${server.port}');
}

Response _unauthorized(String error) => Response(
      401,
      body: jsonEncode({'error': 'unauthorized', 'message': error}),
      headers: {'Content-Type': 'application/json'},
    );

bool _authorize(Request request, QuantumLegalActorContext actor) {
  final authHeader = request.headers['authorization'];
  if (_iamConfig.mode == NpaIamJwtMode.none) {
    return authorizeResolveRequest(request: _dummyRequest(actor), bearerToken: authHeader);
  }
  return NpaIamJwtVerifier.authorizeActor(
    actor: actor,
    bearerToken: authHeader,
    config: _iamConfig,
    jwksVerifier: _jwksVerifier,
  );
}

QuantumLegalResolveRequest _dummyRequest(QuantumLegalActorContext actor) {
  return QuantumLegalResolveRequest(
    actor: actor,
    situation: const QuantumLegalSituation(rawText: ''),
  );
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
  if (!_authorize(request, resolveRequest.actor)) {
    final authHeader = request.headers['authorization'];
    final verify = NpaIamJwtVerifier.verify(
      bearerToken: authHeader,
      config: _iamConfig,
      jwksVerifier: _jwksVerifier,
    );
    return _unauthorized(verify.error ?? 'JWT org_id mismatch');
  }

  final authHeader = request.headers['authorization'];
  final claims = NpaIamClaims.fromBearerToken(authHeader) ??
      ActorSessionClaims.fromJwtPayloadString(
        authHeader!.startsWith('Bearer ') ? authHeader.substring(7) : authHeader,
      );

  final comparison = executeQuantumLegalResolve(
    resolveRequest,
    orgIdOverride: claims?.orgId ?? resolveRequest.actor.orgId,
  );

  final response = QuantumLegalResolveResponse.fromComparison(
    comparison,
    resolvedBy: 'server',
    ontologyGraph: _ontologyGraph,
  );

  return Response.ok(
    jsonEncode(response.toJson()),
    headers: {'Content-Type': 'application/json; charset=utf-8'},
  );
}

Future<Response> _ontologyGraphHandler(Request request) async {
  final actor = QuantumLegalActorContext(orgId: 'KR-NPA');
  if (!_authorize(request, actor)) {
    return _unauthorized('ontology_graph_requires_auth');
  }

  final root = request.url.queryParameters['root_id'];
  final depth = int.tryParse(request.url.queryParameters['depth'] ?? '') ?? 0;

  if (root != null && root.isNotEmpty && depth > 0) {
    final subgraph = _ontologyGraph.subgraphFrom(
      rootSubjectId: root,
      maxDepth: depth,
    );
    return Response.ok(
      jsonEncode({
        'schema_version': '1.0',
        'subgraph': subgraph.toJson(),
      }),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    );
  }

  final payload = LegalOntologyGraphResponse(graph: _ontologyGraph);
  return Response.ok(
    jsonEncode(payload.toJson()),
    headers: {'Content-Type': 'application/json; charset=utf-8'},
  );
}

Future<Response> _ontologyQueryHandler(Request request) async {
  final actor = QuantumLegalActorContext(orgId: 'KR-NPA');
  if (!_authorize(request, actor)) {
    return _unauthorized('ontology_query_requires_auth');
  }

  final body = await request.readAsString();
  Map<String, dynamic> json;
  try {
    json = jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    return Response(400, body: jsonEncode({'error': 'invalid_json'}));
  }

  final query = LegalOntologyTripleQueryRequest.fromJson(json);
  LegalOntologySubgraph? subgraph;

  if (query.rootSubjectId != null) {
    subgraph = _ontologyGraph.subgraphFrom(
      rootSubjectId: query.rootSubjectId!,
      maxDepth: query.maxDepth,
      predicates: query.predicate != null
          ? {LegalPredicate.fromApiValue(query.predicate!)!}
          : null,
    );
  }

  final predicate = query.predicate != null
      ? LegalPredicate.fromApiValue(query.predicate!)
      : null;

  final triples = _ontologyGraph.query(
    subjectId: query.subjectId,
    predicate: predicate,
    objectId: query.objectId,
    objectValue: query.objectValue,
  );

  final response = LegalOntologyTripleQueryResponse(
    triples: triples,
    subgraph: subgraph,
  );

  return Response.ok(
    jsonEncode(response.toJson()),
    headers: {'Content-Type': 'application/json; charset=utf-8'},
  );
}

Future<Response> _ontologyMigratePreviewHandler(Request request) async {
  final actor = QuantumLegalActorContext(orgId: 'KR-NPA');
  if (!_authorize(request, actor)) {
    return _unauthorized('migrate_preview_requires_auth');
  }

  final triples = _ontologyGraph.triples;
  final counts = <String, int>{};
  for (final t in triples) {
    counts[t.predicate.apiValue] = (counts[t.predicate.apiValue] ?? 0) + 1;
  }

  final preview = LegalOntologyMigratePreviewResponse(
    nodeCount: _ontologyGraph.nodes.length,
    tripleCount: triples.length,
    sampleTriples: triples.take(20).toList(),
    predicateCounts: counts,
  );

  return Response.ok(
    jsonEncode(preview.toJson()),
    headers: {'Content-Type': 'application/json; charset=utf-8'},
  );
}
