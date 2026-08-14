import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/plant_archive_entry.dart';

class PlantArchiveService {
  PlantArchiveService._();

  static final PlantArchiveService instance = PlantArchiveService._();

  Future<List<PlantArchiveEntry>>? _entriesFuture;

  Future<List<PlantArchiveEntry>> loadEntries() {
    return _entriesFuture ??= _loadEntries();
  }

  Future<List<PlantArchiveEntry>> _loadEntries() async {
    final raw = await rootBundle.loadString('assets/data/plant_archive.json');
    final items = jsonDecode(raw) as List<dynamic>;
    return items
        .whereType<Map<String, dynamic>>()
        .map(PlantArchiveEntry.fromJson)
        .toList(growable: false);
  }

  List<PlantArchiveEntry> search(
    List<PlantArchiveEntry> entries,
    String query,
  ) {
    final normalized = normalize(query);
    if (normalized.isEmpty) {
      return entries.take(40).toList(growable: false);
    }
    return entries
        .where((entry) => normalize(entry.searchableText).contains(normalized))
        .take(80)
        .toList(growable: false);
  }

  String normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }
}
