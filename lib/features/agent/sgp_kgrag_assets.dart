/// S10 — KG-RAG 에셋 로더 (Flutter).
library;

import 'package:flutter/services.dart';

import 'sgp_kgrag_loader.dart';
import 'sgp_kgrag_router.dart';
import 'sgp_vector_store.dart';

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
}
