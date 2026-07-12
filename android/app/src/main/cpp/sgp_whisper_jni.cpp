#include <jni.h>
#include <android/log.h>
#include <cstring>
#include <string>

#define LOG_TAG "sgp_whisper_jni"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

extern "C" JNIEXPORT jstring JNICALL
Java_com_sgp_sgp_agent_SgpWhisperEngine_nativeTranscribePcm(
        JNIEnv *env,
        jobject /* thiz */,
        jstring modelPath,
        jfloatArray pcm,
        jint sampleRate,
        jstring locale) {
    const char *model = env->GetStringUTFChars(modelPath, nullptr);
    const char *lang = env->GetStringUTFChars(locale, nullptr);
    jsize pcmLen = env->GetArrayLength(pcm);

    LOGI(
            "Whisper JNI stub: model=%s samples=%d rate=%d locale=%s",
            model ? model : "(null)",
            pcmLen,
            sampleRate,
            lang ? lang : "ko");

    if (model != nullptr) env->ReleaseStringUTFChars(modelPath, model);
    if (lang != nullptr) env->ReleaseStringUTFChars(locale, lang);

    // whisper.cpp 연동 빌드(SGP_WHISPER_CPP=1)에서 이 함수를 실제 inference로 교체한다.
    // PCM·모델·JNI 계약은 SM-S918N 실기기 검증으로 확인한다.
    return nullptr;
}
