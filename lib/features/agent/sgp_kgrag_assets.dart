/// S10 — KG-RAG 에셋 로더 (Flutter).
library;

import 'package:flutter/services.dart';

import 'sgp_kgrag_loader.dart';
import 'sgp_kgrag_router.dart';
import 'sgp_vector_store.dart';
import '../security/sgp_secure_crypto.dart';

abstract final class SgpKgragAssetLoader {
  static const assetPath = SgpKgragLoader.assetPath;

  static Future<SgpVectorStore> loadFromAssets() async {
    if (SgpKgragLoader.cachedPack != null &&
        SgpVectorStoreSession.instance.corpusSize > 0) {
      return SgpVectorStoreSession.instance;
    }
    final json = await rootBundle.loadString(assetPath);
    final pack = SgpKgragLoader.parsePack(json);
    SgpKgragLoader.setCachedPack(pack);
    return SgpKgragRouter.initializeFromPack(pack);
  }

  /// 생체인증 성공 시에만 RAM에 복호화·적재 후 벡터 인덱스 구축.
  static Future<SgpVectorStore> loadSecureFromAssets({
    required SgpBiometricAuthPort biometric,
    required Uint8List key,
  }) async {
    SgpSecureCrypto.wipeRamCorpus();
    final json = await rootBundle.loadString(assetPath);
    final envelope = SgpSecureCrypto.sealCorpus(plainJson: json, key: key);
    await SgpSecureCrypto.unlockCorpusToRam(
      envelope: envelope,
      key: key,
      biometric: biometric,
    );
    final pack = SgpSecureCrypto.loadPackFromRam();
    SgpKgragLoader.setCachedPack(pack);
    return SgpKgragRouter.initializeFromPack(pack);
  }
}
