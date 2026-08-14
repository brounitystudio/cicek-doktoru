import 'package:flutter/material.dart';

import '../screens/plant_detail_screen.dart';
import '../screens/scan_plant_screen.dart';
import '../models/care_task.dart';
import '../models/plant.dart';
import '../services/language_service.dart';
import '../services/plant_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/botanical_background.dart';
import '../widgets/branded_header.dart';
import '../widgets/plant_status_card.dart';

class MyPlantsScreen extends StatefulWidget {
  const MyPlantsScreen({super.key});

  @override
  State<MyPlantsScreen> createState() => _MyPlantsScreenState();
}

class _MyPlantsScreenState extends State<MyPlantsScreen> {
  late Future<List<Plant>> _plantsFuture;
  _PlantFilter _filter = _PlantFilter.all;

  @override
  void initState() {
    super.initState();
    _plantsFuture = PlantRepository().getPlants();
    PlantRepository.plantsRevision.addListener(_refreshPlants);
  }

  @override
  void dispose() {
    PlantRepository.plantsRevision.removeListener(_refreshPlants);
    super.dispose();
  }

  void _refreshPlants() {
    setState(() {
      _plantsFuture = PlantRepository().getPlants();
    });
  }

  Future<void> _deletePlant(Plant plant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Bitki silinsin mi?', 'Delete this plant?')),
        content: Text(
          context.tr(
            '${plant.name} ve bağlı bakım görevleri silinecek.',
            '${plant.name} and its care tasks will be deleted.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Vazgeç', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('Sil', 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await PlantRepository().deletePlant(plant.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('${plant.name} silindi.', '${plant.name} was deleted.'),
          ),
        ),
      );
      _refreshPlants();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BotanicalBackground(
        child: SafeArea(
          child: FutureBuilder<List<Plant>>(
            future: _plantsFuture,
            builder: (context, snapshot) {
              final plants = snapshot.data ?? [];
              final filteredPlants = plants
                  .where((plant) => _matchesFilter(plant, _filter))
                  .toList(growable: false);
              return ListView(
                padding: const EdgeInsets.only(bottom: 118),
                children: [
                  BrandedHeader(
                    eyebrow: context.tr(
                      'Botanik kataloğun',
                      'Your botanical catalog',
                    ),
                    title: context.tr('Bitkilerim', 'My Plants'),
                    subtitle: context.tr(
                      'Sağlık, görev ve gelişim durumları bir arada.',
                      'Health, tasks and progress in one place.',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _FilterChips(
                      selected: _filter,
                      onSelected: (filter) => setState(() => _filter = filter),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState != ConnectionState.done)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: AppCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(
                                'Bitkiler yüklenemedi.',
                                'Plants could not be loaded.',
                              ),
                              style: AppTextStyles.section,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${snapshot.error}',
                              style: AppTextStyles.muted,
                            ),
                            const SizedBox(height: 14),
                            FilledButton(
                              onPressed: _refreshPlants,
                              child: Text(
                                context.tr('Tekrar dene', 'Try again'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (plants.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: AppCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(
                                'Henüz bitki eklemedin.',
                                'You have not added a plant yet.',
                              ),
                              style: AppTextStyles.section,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.tr(
                                'İlk bitkini tarayarak başlayabilirsin.',
                                'Start by scanning your first plant.',
                              ),
                              style: AppTextStyles.muted,
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: () => Navigator.of(
                                context,
                              ).pushNamed(ScanPlantScreen.routeName),
                              icon: const Icon(Icons.document_scanner_outlined),
                              label: Text(
                                context.tr('Bitki Tara', 'Scan Plant'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (filteredPlants.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: AppCard(
                        child: Text(
                          context.tr(
                            'Bu filtreye uyan bitki yok.',
                            'No plants match this filter.',
                          ),
                          style: AppTextStyles.body,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: filteredPlants.map((plant) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: PlantStatusCard(
                              plant: plant,
                              onDelete: () => _deletePlant(plant),
                              onTap: () => Navigator.of(context).pushNamed(
                                PlantDetailScreen.routeName,
                                arguments: plant,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _PlantFilter { all, healthy, attention, watering }

bool _matchesFilter(Plant plant, _PlantFilter filter) {
  return switch (filter) {
    _PlantFilter.all => true,
    _PlantFilter.healthy => plant.healthStatus == 'İyi',
    _PlantFilter.attention => plant.healthStatus != 'İyi',
    _PlantFilter.watering =>
      plant.nextTask.type == CareTaskType.watering &&
          !plant.nextTask.completed &&
          !plant.nextTask.dueDate.isAfter(DateTime.now()),
  };
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final _PlantFilter selected;
  final ValueChanged<_PlantFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final chips = [
      (_PlantFilter.all, context.tr('Tümü', 'All')),
      (_PlantFilter.healthy, context.tr('Sağlıklı', 'Healthy')),
      (
        _PlantFilter.attention,
        context.tr('Kontrol gerekli', 'Needs attention'),
      ),
      (_PlantFilter.watering, context.tr('Sulama zamanı', 'Watering due')),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((chip) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: chip.$1 == selected,
              label: Text(chip.$2),
              selectedColor: AppColors.darkGreen,
              labelStyle: TextStyle(
                color: chip.$1 == selected ? Colors.white : AppColors.darkGreen,
                fontWeight: FontWeight.w900,
              ),
              onSelected: (_) => onSelected(chip.$1),
            ),
          );
        }).toList(),
      ),
    );
  }
}
