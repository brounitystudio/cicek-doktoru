import 'care_task.dart';
import 'diagnosis_result.dart';

class Plant {
  const Plant({
    required this.id,
    required this.name,
    required this.healthStatus,
    required this.lastDiagnosisAt,
    required this.nextTask,
    required this.diagnosis,
    this.imagePath,
    this.imageUrl,
    this.storagePath,
    this.location,
    this.lastWatered,
    this.sunlight,
    this.hasDrainage,
    this.notes,
  });

  final String id;
  final String name;
  final String healthStatus;
  final DateTime lastDiagnosisAt;
  final CareTask nextTask;
  final DiagnosisResult diagnosis;
  final String? imagePath;
  final String? imageUrl;
  final String? storagePath;
  final String? location;
  final String? lastWatered;
  final String? sunlight;
  final String? hasDrainage;
  final String? notes;
}
