import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/care_task.dart';
import '../models/diagnosis_result.dart';
import '../models/plant.dart';
import 'dev_auth_config.dart';
import 'firebase_bootstrap.dart';

class PlantRepository {
  static final plantsRevision = ValueNotifier<int>(0);

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  Future<List<Plant>> getPlants() async {
    final firebaseReady = await FirebaseBootstrap.ensureInitialized();
    final user = FirebaseAuth.instance.currentUser;
    if (!firebaseReady || user == null || _blocksAnonymous(user)) {
      return const [];
    }

    final callable = _functions.httpsCallable('getUserPlants');
    final response = await callable.call<Map<String, dynamic>>();
    final plants = response.data['plants'];
    if (plants is! List) {
      return const [];
    }

    return plants
        .whereType<Map>()
        .map((item) => _plantFromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Plant> saveDiagnosis(DiagnosisResult diagnosis) async {
    final firebaseReady = await FirebaseBootstrap.ensureInitialized();
    final user = FirebaseAuth.instance.currentUser;
    if (!firebaseReady || user == null || _blocksAnonymous(user)) {
      throw const PlantSaveException(
        'Bitki kaydetmek için Google hesabınla giriş yapmalısın.',
      );
    }

    final callable = _functions.httpsCallable('savePlantFromDiagnosis');
    try {
      final response = await callable.call<Map<String, dynamic>>({
        'diagnosis': _diagnosisToJson(diagnosis),
      });
      final plant = response.data['plant'];
      if (plant is! Map) {
        throw const PlantSaveException('Bitki kaydı alınamadı.');
      }
      final savedPlant = _plantFromJson(Map<String, dynamic>.from(plant));
      plantsRevision.value++;
      return savedPlant;
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'resource-exhausted' ||
          error.message == 'PLANT_LIMIT_REACHED') {
        throw const PlantLimitException();
      }
      if (error.code == 'unauthenticated') {
        throw const PlantSaveException(
          'Bitki kaydetmek için Google hesabınla tekrar giriş yapmalısın.',
        );
      }
      throw PlantSaveException(
        error.message ?? 'Bitki kaydedilemedi, lütfen tekrar deneyin.',
      );
    }
  }

  Future<Plant> updatePlantProfile({
    required Plant plant,
    required String name,
    required String location,
    required String lastWatered,
    required String sunlight,
    required String notes,
  }) async {
    final firebaseReady = await FirebaseBootstrap.ensureInitialized();
    final user = FirebaseAuth.instance.currentUser;
    if (!firebaseReady || user == null || _blocksAnonymous(user)) {
      throw const PlantSaveException(
        'Bitkiyi düzenlemek için Google hesabınla giriş yapmalısın.',
      );
    }

    final callable = _functions.httpsCallable('updateUserPlantProfile');
    try {
      final response = await callable.call<Map<String, dynamic>>({
        'plantId': plant.id,
        'name': name,
        'location': location,
        'lastWatered': lastWatered,
        'sunlight': sunlight,
        'notes': notes,
      });
      final updated = response.data['plant'];
      if (updated is! Map) {
        throw const PlantSaveException('Bitki bilgileri güncellenemedi.');
      }
      final updatedPlant = _plantFromJson(Map<String, dynamic>.from(updated));
      plantsRevision.value++;
      return updatedPlant;
    } on FirebaseFunctionsException catch (error) {
      throw PlantSaveException(
        error.message ?? 'Bitki bilgileri güncellenemedi, tekrar deneyin.',
      );
    }
  }

  Future<void> deletePlant(String plantId) async {
    final firebaseReady = await FirebaseBootstrap.ensureInitialized();
    final user = FirebaseAuth.instance.currentUser;
    if (!firebaseReady || user == null || _blocksAnonymous(user)) {
      throw const PlantSaveException(
        'Bitki silmek için Google hesabınla giriş yapmalısın.',
      );
    }

    final callable = _functions.httpsCallable('deleteUserPlant');
    try {
      await callable.call<Map<String, dynamic>>({'plantId': plantId});
      plantsRevision.value++;
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'not-found' || error.message == 'PLANT_NOT_FOUND') {
        plantsRevision.value++;
        return;
      }
      throw PlantSaveException(
        error.message ?? 'Bitki silinemedi, lütfen tekrar deneyin.',
      );
    }
  }

  Future<List<CareTask>> getCareTasks() async {
    final firebaseReady = await FirebaseBootstrap.ensureInitialized();
    final user = FirebaseAuth.instance.currentUser;
    if (!firebaseReady || user == null || _blocksAnonymous(user)) {
      return const [];
    }

    final callable = _functions.httpsCallable('getCareTasks');
    final response = await callable.call<Map<String, dynamic>>();
    final tasks = response.data['tasks'];
    if (tasks is! List) {
      return const [];
    }

    return tasks
        .whereType<Map>()
        .map((item) => _taskFromJson(Map<String, dynamic>.from(item)))
        .where((task) => !task.completed)
        .toList();
  }

  Future<void> completeCareTask(String taskId) async {
    final firebaseReady = await FirebaseBootstrap.ensureInitialized();
    final user = FirebaseAuth.instance.currentUser;
    if (!firebaseReady || user == null || _blocksAnonymous(user)) {
      return;
    }

    final callable = _functions.httpsCallable('completeCareTask');
    await callable.call<Map<String, dynamic>>({'taskId': taskId});
  }
}

bool _blocksAnonymous(User user) {
  return user.isAnonymous && !DevAuthConfig.allowEmulatorLogin;
}

Plant _plantFromJson(Map<String, dynamic> json) {
  final diagnosisJson = Map<String, dynamic>.from(
    (json['latestDiagnosis'] as Map?) ?? const {},
  );
  final diagnosis = _diagnosisFromJson(
    diagnosisJson,
    fallbackName: json['name'],
    fallbackCareProfile: json['careProfile'],
  );
  final taskJson = Map<String, dynamic>.from(
    (json['nextTask'] as Map?) ?? const {},
  );

  return Plant(
    id: (json['id'] as String?) ?? '',
    name: (json['name'] as String?) ?? diagnosis.plantName,
    healthStatus: (json['healthStatus'] as String?) ?? diagnosis.status,
    lastDiagnosisAt: _dateFrom(json['lastDiagnosisAt']) ?? diagnosis.createdAt,
    diagnosis: diagnosis,
    nextTask: _taskFromJson(taskJson),
    imagePath: json['imagePath'] as String?,
    imageUrl: json['imageUrl'] as String?,
    storagePath: json['storagePath'] as String?,
    location:
        json['location'] as String? ??
        diagnosis.answers['location'] ??
        diagnosis.answers['Konum'],
    lastWatered:
        json['lastWatered'] as String? ??
        diagnosis.answers['lastWatered'] ??
        diagnosis.answers['Sulama'],
    sunlight:
        json['sunlight'] as String? ??
        diagnosis.answers['sunlight'] ??
        diagnosis.answers['Işık'],
    hasDrainage:
        json['hasDrainage'] as String? ??
        diagnosis.answers['hasDrainage'] ??
        diagnosis.answers['Drenaj'],
    notes: json['notes'] as String?,
  );
}

DiagnosisResult _diagnosisFromJson(
  Map<String, dynamic> json, {
  Object? fallbackName,
  Object? fallbackCareProfile,
}) {
  return DiagnosisResult(
    id: json['id'] as String?,
    plantName:
        (json['plantName'] as String?) ??
        (json['plantGuess'] as String?) ??
        (fallbackName as String?) ??
        'Bitkim',
    healthScore: ((json['healthScore'] as num?) ?? 60).round().clamp(0, 100),
    visualFindings: _stringList(json['visualFindings']),
    symptoms: _stringList(json['symptoms']),
    causes: _mapList(
      json['possibleCauses'],
    ).map(CauseProbability.fromJson).toList(),
    actions: _stringList(json['quickActions'] ?? json['actions']),
    createdAt: _dateFrom(json['createdAt']) ?? DateTime.now(),
    imagePath: json['imagePath'] as String?,
    imageUrl: json['imageUrl'] as String?,
    storagePath: json['storagePath'] as String?,
    isPlant: (json['isPlant'] as bool?) ?? true,
    needsCloseup: (json['needsCloseup'] as bool?) ?? false,
    sevenDayPlan: _stringList(json['sevenDayPlan']),
    safetyNote:
        (json['safetyNote'] as String?) ??
        'Kesin teşhis değildir. Sorun yayılıyorsa uzman/çiçekçi desteği alın.',
    confidenceNote: json['confidenceNote'] as String?,
    source: (json['source'] as String?) ?? 'gemini',
    analysisTier: (json['analysisTier'] as String?) ?? 'standard',
    careProfile: _careProfileFrom(json['careProfile'] ?? fallbackCareProfile),
    answers: _stringMap(json['answers']),
  );
}

CareTask _taskFromJson(Map<String, dynamic> json) {
  return CareTask(
    id: json['id'] as String?,
    plantId: json['plantId'] as String?,
    plantName: json['plantName'] as String?,
    title: (json['title'] as String?) ?? 'Bakım kontrolü',
    type: _taskTypeFrom(json['type']),
    dueDate:
        _dateFrom(json['dueDate']) ??
        DateTime.now().add(const Duration(days: 1)),
    completed: (json['completed'] as bool?) ?? false,
  );
}

CareTaskType _taskTypeFrom(Object? value) {
  return CareTaskType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => CareTaskType.diseaseCheck,
  );
}

Map<String, dynamic> _diagnosisToJson(DiagnosisResult diagnosis) {
  return {
    'id': diagnosis.id,
    'plantName': diagnosis.plantName,
    'healthScore': diagnosis.healthScore,
    'visualFindings': diagnosis.visualFindings,
    'symptoms': diagnosis.symptoms,
    'possibleCauses': diagnosis.causes
        .map(
          (cause) => {
            'label': cause.title,
            'title': cause.title,
            'percent': cause.percent,
            'code': cause.code,
            'confidence': cause.confidence ?? cause.percent / 100,
          },
        )
        .toList(),
    'quickActions': diagnosis.actions,
    'sevenDayPlan': diagnosis.sevenDayPlan,
    'safetyNote': diagnosis.safetyNote,
    'confidenceNote': diagnosis.confidenceNote,
    'source': diagnosis.source,
    'analysisTier': diagnosis.analysisTier,
    'careProfile': diagnosis.careProfile?.toJson(),
    'answers': diagnosis.answers,
    'imagePath': diagnosis.imagePath,
    'imageUrl': diagnosis.imageUrl,
    'storagePath': diagnosis.storagePath,
    'createdAt': diagnosis.createdAt.toIso8601String(),
    'isPlant': diagnosis.isPlant,
    'needsCloseup': diagnosis.needsCloseup,
  };
}

PlantCareProfile? _careProfileFrom(Object? value) {
  if (value is! Map) {
    return null;
  }
  return PlantCareProfile.fromJson(Map<String, dynamic>.from(value));
}

DateTime? _dateFrom(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value);
  }
  if (value is Map) {
    final seconds = value['_seconds'] ?? value['seconds'];
    if (seconds is num) {
      return DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000);
    }
  }
  return null;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<String>().toList();
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return value.map(
    (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
  );
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

class PlantSaveException implements Exception {
  const PlantSaveException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PlantLimitException extends PlantSaveException {
  const PlantLimitException() : super('Bitki kayıt limitine ulaştın.');
}
