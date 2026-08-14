import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as image_lib;

import '../models/diagnosis_result.dart';
import 'dev_auth_config.dart';
import 'firebase_bootstrap.dart';
import 'language_service.dart';

class PlantScanInput {
  const PlantScanInput({
    required this.location,
    required this.lastWatered,
    required this.sunlight,
    required this.hasDrainage,
    required this.symptomType,
    required this.symptomDuration,
    this.imagePath,
    this.imagePaths = const [],
  });

  final String location;
  final String lastWatered;
  final String sunlight;
  final String hasDrainage;
  final String symptomType;
  final String symptomDuration;
  final String? imagePath;
  final List<String> imagePaths;

  List<String> get allImagePaths {
    if (imagePaths.isNotEmpty) {
      return imagePaths.take(3).toList(growable: false);
    }
    final path = imagePath;
    return path == null ? const [] : [path];
  }

  Map<String, String> get backendAnswers {
    return {
      'location': location == 'İç mekân' ? 'indoor' : 'outdoor',
      'lastWatered': lastWatered,
      'sunlight': sunlight,
      'hasDrainage': hasDrainage,
      'symptomType': symptomType,
      'symptomDuration': symptomDuration,
      'language': LanguageService.instance.language.code,
    };
  }
}

class DiagnosisService {
  Future<DiagnosisResult> diagnose(
    PlantScanInput input, {
    String? requestId,
  }) async {
    const useMock = bool.fromEnvironment('USE_MOCK_DIAGNOSIS');
    if (useMock) {
      return _mockDiagnose(input);
    }

    final firebaseReady = await FirebaseBootstrap.ensureInitialized();
    if (!firebaseReady) {
      throw const DiagnosisException(
        'Firebase config hazır değil. FlutterFire config eklendikten sonra tekrar deneyin.',
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null ||
        (user.isAnonymous && !DevAuthConfig.allowEmulatorLogin)) {
      throw const DiagnosisException(
        'Teşhis için Google hesabınla giriş yapmalısın.',
      );
    }

    final imageBase64List = <String>[];
    for (final path in input.allImagePaths) {
      imageBase64List.add(await _encodeImageForAnalysis(path));
    }
    final callable = FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('analyzePlantPhoto');
    late final HttpsCallableResult<Map<String, dynamic>> response;
    try {
      response = await callable
          .call<Map<String, dynamic>>({
            // ignore: use_null_aware_elements
            if (imageBase64List.length == 1)
              'imageBase64': imageBase64List.first,
            if (imageBase64List.length > 1) 'imageBase64List': imageBase64List,
            'mimeType': 'image/jpeg',
            'answers': input.backendAnswers,
            // ignore: use_null_aware_elements
            if (requestId != null) 'requestId': requestId,
          })
          .timeout(const Duration(seconds: 100));
    } on TimeoutException {
      throw const DiagnosisException(
        'Analiz beklenenden uzun sürdü. Aynı isteği hemen tekrar göndermeden kısa süre sonra yeniden dene.',
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'resource-exhausted' || error.message == 'NO_CREDITS') {
        throw const DiagnosisNoCreditsException();
      }
      if (error.code == 'not-found') {
        throw const DiagnosisException(
          'Analiz altyapısı hazırlanıyor. Firestore Database etkinleştirildikten sonra tekrar deneyin.',
        );
      }
      if (error.code == 'failed-precondition') {
        throw const DiagnosisException(
          'AI analiz servisi şu anda hazır değil. Hakkın düşmedi; birazdan tekrar deneyebilirsin.',
        );
      }
      if (error.code == 'unauthenticated') {
        throw const DiagnosisException(
          'Teşhis için Google hesabınla tekrar giriş yapmalısın.',
        );
      }
      throw DiagnosisException(
        error.message ??
            'Fotoğrafı şu an işleyemedik. Hakkın düşmediyse tekrar deneyebilirsin.',
      );
    }

    return DiagnosisResult.fromCloudFunction(
      Map<String, dynamic>.from(response.data),
      localImagePath: input.allImagePaths.isEmpty
          ? null
          : input.allImagePaths.first,
    );
  }

  Future<DiagnosisResult> _mockDiagnose(PlantScanInput input) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));

    var score = 74;
    if (input.lastWatered == 'Bugün' && input.hasDrainage == 'Hayır') {
      score -= 14;
    }
    if (input.sunlight == 'Az ışık') {
      score -= 8;
    }
    if (input.location == 'Dış mekân') {
      score += 4;
    }

    return DiagnosisResult(
      plantName: 'Barış Çiçeği',
      healthScore: score.clamp(32, 92),
      visualFindings: const [
        'Yaprak uçları, yaprak rengi ve toprak yüzeyi birlikte değerlendirildi.',
      ],
      imagePath: input.allImagePaths.isEmpty ? null : input.allImagePaths.first,
      createdAt: DateTime.now(),
      symptoms: const [
        'Yaprak sararması',
        'Yaprak ucu kahverengileşmesi',
        'Toprak nemli görünüyor',
      ],
      causes: const [
        CauseProbability(
          title: 'Fazla sulama',
          percent: 68,
          code: 'overwatering',
          confidence: .68,
        ),
        CauseProbability(
          title: 'Düşük nem',
          percent: 21,
          code: 'low_humidity',
          confidence: .21,
        ),
        CauseProbability(
          title: 'Işık dengesizliği',
          percent: 11,
          code: 'low_light',
          confidence: .11,
        ),
      ],
      actions: const [
        'Toprak tamamen kurumadan tekrar sulama yapma.',
        'Bitkiyi aydınlık ama direkt güneş almayan bir yere taşı.',
        'Saksı drenajını kontrol et ve tabakta su bekletme.',
      ],
      sevenDayPlan: const [
        '1. Gün: Sulama yapma, toprak nemini kontrol et.',
        '2. Gün: Saksı tabağını ve drenajı kontrol et.',
        '3. Gün: Sararmış yaprakları temiz makasla al.',
        '7. Gün: Aynı açıdan tekrar fotoğraf çekerek gelişimi kontrol et.',
      ],
      answers: input.backendAnswers,
    );
  }
}

Future<String> _encodeImageForAnalysis(String path) async {
  final bytes = await File(path).readAsBytes();
  final decoded = image_lib.decodeImage(bytes);
  if (decoded == null) {
    return base64Encode(bytes);
  }

  final oriented = image_lib.bakeOrientation(decoded);
  var prepared = _resizeToLongestSide(oriented, 1280);
  var jpeg = image_lib.encodeJpg(prepared, quality: 78);

  var quality = 72;
  while (jpeg.length > 620000 && quality >= 60) {
    jpeg = image_lib.encodeJpg(prepared, quality: quality);
    quality -= 6;
  }

  if (jpeg.length > 620000) {
    prepared = _resizeToLongestSide(prepared, 1040);
    jpeg = image_lib.encodeJpg(prepared, quality: 68);
  }

  return base64Encode(jpeg);
}

image_lib.Image _resizeToLongestSide(image_lib.Image source, int maxSide) {
  final longest = math.max(source.width, source.height);
  if (longest <= maxSide) {
    return source;
  }
  final scale = maxSide / longest;
  return image_lib.copyResize(
    source,
    width: math.max(1, (source.width * scale).round()),
    height: math.max(1, (source.height * scale).round()),
    interpolation: image_lib.Interpolation.average,
  );
}

class DiagnosisException implements Exception {
  const DiagnosisException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DiagnosisNoCreditsException implements Exception {
  const DiagnosisNoCreditsException();

  @override
  String toString() => 'Teşhis hakkın bitti.';
}
