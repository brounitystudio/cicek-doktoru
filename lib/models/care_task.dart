enum CareTaskType {
  watering,
  fertilizing,
  leafCleaning,
  potCheck,
  diseaseCheck,
}

class CareTask {
  const CareTask({
    required this.title,
    required this.type,
    required this.dueDate,
    this.completed = false,
    this.id,
    this.plantId,
    this.plantName,
  });

  final String? id;
  final String? plantId;
  final String? plantName;
  final String title;
  final CareTaskType type;
  final DateTime dueDate;
  final bool completed;
}
