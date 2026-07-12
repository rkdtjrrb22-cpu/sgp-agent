/// deploy/quantum_legal_production.env 검증 스크립트.
///
/// 실행: `dart run deploy/validate_production_env.dart [env파일경로]`
import 'dart:io';

void main(List<String> args) {
  final envPath = args.isNotEmpty
      ? args[0]
      : 'deploy/quantum_legal_production.env';

  final file = File(envPath);
  if (!file.existsSync()) {
    stderr.writeln('FAIL: env file not found: $envPath');
    stderr.writeln('Hint: cp deploy/quantum_legal_production.env.example $envPath');
    exit(1);
  }

  final vars = _parseEnv(file.readAsStringSync());
  final errors = <String>[];
  final warnings = <String>[];

  _require(vars, 'PORT', errors);
  _require(vars, 'SEED_PATH', errors);
  _require(vars, 'NPA_IAM_JWT_MODE', errors);
  _require(vars, 'NPA_IAM_ISSUER', errors);
  _require(vars, 'NPA_IAM_AUDIENCE', errors);
  if ((vars['NPA_IAM_JWT_MODE'] ?? '').toLowerCase() == 'claims') {
    if ((vars['NPA_IAM_JWKS_URL'] ?? '').isEmpty) {
      warnings.add('NPA_IAM_JWT_MODE=claims but NPA_IAM_JWKS_URL empty — JWKS signature verify disabled');
    }
  }
  _require(vars, 'POSTGRES_USER', errors);
  _require(vars, 'POSTGRES_PASSWORD', errors);
  _require(vars, 'POSTGRES_DB', errors);
  _require(vars, 'DATABASE_URL', errors);

  final mode = vars['NPA_IAM_JWT_MODE']?.toLowerCase() ?? '';
  if (!{'none', 'claims', 'strict'}.contains(mode)) {
    errors.add('NPA_IAM_JWT_MODE must be none|claims|strict (got: $mode)');
  }

  if (mode == 'strict' && (vars['NPA_IAM_JWKS_URL'] ?? '').isEmpty) {
    errors.add('NPA_IAM_JWT_MODE=strict requires NPA_IAM_JWKS_URL');
  }

  if ((vars['POSTGRES_PASSWORD'] ?? '') == 'change_me_in_production') {
    warnings.add('POSTGRES_PASSWORD is still the example placeholder');
  }

  if ((vars['LAW_GO_KR_OC_KEY'] ?? '').isEmpty &&
      (vars['DATA_GO_KR_SERVICE_KEY'] ?? '').isEmpty) {
    warnings.add('LAW_GO_KR_OC_KEY / DATA_GO_KR_SERVICE_KEY empty — Cron uses offline stub');
  }

  final seed = File(vars['SEED_PATH'] ?? '');
  if (!seed.existsSync()) {
    errors.add('SEED_PATH not found: ${vars['SEED_PATH']}');
  }

  stdout.writeln('=== deploy env validation: $envPath ===');
  stdout.writeln('NPA_IAM_JWT_MODE=$mode');
  stdout.writeln('PORT=${vars['PORT']} | POSTGRES_DB=${vars['POSTGRES_DB']}');

  for (final w in warnings) {
    stdout.writeln('WARN: $w');
  }
  for (final e in errors) {
    stderr.writeln('ERROR: $e');
  }

  if (errors.isEmpty) {
    stdout.writeln('OK — ready for docker compose up -d');
    exit(0);
  }
  stdout.writeln('FAIL — fix errors before deployment');
  exit(1);
}

Map<String, String> _parseEnv(String source) {
  final map = <String, String>{};
  for (final line in source.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final idx = trimmed.indexOf('=');
    if (idx <= 0) continue;
    map[trimmed.substring(0, idx).trim()] = trimmed.substring(idx + 1).trim();
  }
  return map;
}

void _require(Map<String, String> vars, String key, List<String> errors) {
  if ((vars[key] ?? '').isEmpty) {
    errors.add('Missing or empty: $key');
  }
}
