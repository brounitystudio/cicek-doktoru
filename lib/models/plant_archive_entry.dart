class PlantArchiveEntry {
  const PlantArchiveEntry({
    required this.id,
    required this.title,
    required this.turkishName,
    required this.scientificName,
    required this.group,
    required this.light,
    required this.water,
    required this.soil,
    required this.temperatureHumidity,
    required this.likes,
    required this.dislikes,
    required this.idealLocation,
    required this.growthTips,
    required this.fertilizer,
    required this.repotting,
    required this.propagation,
    required this.diseasesPests,
    required this.difficulty,
    required this.checklist,
    required this.specialNote,
    required this.catFriendly,
    required this.dogFriendly,
    required this.childFriendly,
    required this.toxicity,
    required this.riskTypes,
    required this.safetyWarning,
    required this.safetyRecommendation,
    required this.searchText,
  });

  final int id;
  final String title;
  final String turkishName;
  final String scientificName;
  final String group;
  final String light;
  final String water;
  final String soil;
  final String temperatureHumidity;
  final String likes;
  final String dislikes;
  final String idealLocation;
  final String growthTips;
  final String fertilizer;
  final String repotting;
  final String propagation;
  final String diseasesPests;
  final String difficulty;
  final List<String> checklist;
  final String specialNote;
  final String catFriendly;
  final String dogFriendly;
  final String childFriendly;
  final String toxicity;
  final List<String> riskTypes;
  final String safetyWarning;
  final String safetyRecommendation;
  final String searchText;

  factory PlantArchiveEntry.fromJson(Map<String, dynamic> json) {
    return PlantArchiveEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: _string(json['title']),
      turkishName: _string(json['turkishName']),
      scientificName: _string(json['scientificName']),
      group: _string(json['group']),
      light: _string(json['light']),
      water: _string(json['water']),
      soil: _string(json['soil']),
      temperatureHumidity: _string(json['temperatureHumidity']),
      likes: _string(json['likes']),
      dislikes: _string(json['dislikes']),
      idealLocation: _string(json['idealLocation']),
      growthTips: _string(json['growthTips']),
      fertilizer: _string(json['fertilizer']),
      repotting: _string(json['repotting']),
      propagation: _string(json['propagation']),
      diseasesPests: _string(json['diseasesPests']),
      difficulty: _string(json['difficulty']),
      checklist: _stringList(json['checklist']),
      specialNote: _string(json['specialNote']),
      catFriendly: _string(json['catFriendly']),
      dogFriendly: _string(json['dogFriendly']),
      childFriendly: _string(json['childFriendly']),
      toxicity: _string(json['toxicity']),
      riskTypes: _stringList(json['riskTypes']),
      safetyWarning: _string(json['safetyWarning']),
      safetyRecommendation: _string(json['safetyRecommendation']),
      searchText: _string(json['searchText']),
    );
  }

  String get displayName => turkishName.isNotEmpty ? turkishName : title;

  String get searchableText => [
    searchText,
    displayName,
    scientificName,
    group,
    light,
    water,
    diseasesPests,
  ].join(' ');
}

String _string(Object? value) => value?.toString() ?? '';

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.map((item) => item.toString()).toList();
}
