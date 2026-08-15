import 'dart:io';

import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../services/plant_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/premium_care_tips.dart';
import 'scan_plant_screen.dart';

class PlantDetailScreen extends StatelessWidget {
  const PlantDetailScreen({super.key});

  static const routeName = '/plant-detail';

  @override
  Widget build(BuildContext context) {
    final plant = ModalRoute.of(context)?.settings.arguments as Plant?;
    if (plant == null) {
      return FutureBuilder(
        future: PlantRepository().getPlants(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Scaffold(
              appBar: AppBar(title: const Text('Bitki Detayı')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return _PlantDetailBody(plant: snapshot.data!.first);
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Bitki Detayı')),
            body: const Center(child: Text('Bitki bulunamadı.')),
          );
        },
      );
    }
    return _PlantDetailBody(plant: plant);
  }
}

class _PlantDetailBody extends StatefulWidget {
  const _PlantDetailBody({required this.plant});

  final Plant plant;

  @override
  State<_PlantDetailBody> createState() => _PlantDetailBodyState();
}

class _PlantDetailBodyState extends State<_PlantDetailBody> {
  late Plant plant;

  @override
  void initState() {
    super.initState();
    plant = widget.plant;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(plant.name),
        actions: [
          IconButton(
            tooltip: 'Bitki bilgilerini düzenle',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editProfile,
          ),
          IconButton(
            tooltip: 'Bitkiyi sil',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _deletePlant(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PlantHeroImage(
            imageUrl: plant.imageUrl,
            imagePath: plant.imagePath ?? plant.diagnosis.imagePath,
          ),
          const SizedBox(height: 16),
          _OverviewCard(plant: plant),
          _CareArea(plant: plant),
          _DiagnosisArea(actions: plant.diagnosis.actions),
          _HistoryArea(plant: plant),
          const SizedBox(height: 6),
          AppButton(
            label: 'Tekrar Tara',
            icon: Icons.camera_alt_outlined,
            onPressed: () =>
                Navigator.of(context).pushNamed(ScanPlantScreen.routeName),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile() async {
    final updated = await showModalBottomSheet<Plant>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditPlantSheet(plant: plant),
    );
    if (updated == null || !mounted) {
      return;
    }
    setState(() => plant = updated);
  }

  Future<void> _deletePlant(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bitki silinsin mi?'),
        content: Text('${plant.name} ve bağlı bakım görevleri silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await PlantRepository().deletePlant(plant.id);
      if (!context.mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text('${plant.name} silindi.')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.plant});

  final Plant plant;

  Color get _healthColor {
    if (plant.diagnosis.healthScore >= 80) return AppColors.green;
    if (plant.diagnosis.healthScore >= 50) return AppColors.warning;
    return AppColors.critical;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        showPattern: false,
        variant: AppCardVariant.elevated,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 68,
                  height: 68,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: plant.diagnosis.healthScore / 100,
                        strokeWidth: 8,
                        color: _healthColor,
                        backgroundColor: _healthColor.withValues(alpha: .15),
                      ),
                      Text(
                        '${plant.diagnosis.healthScore}',
                        style: AppTextStyles.section.copyWith(
                          color: _healthColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bitki sağlığı', style: AppTextStyles.muted),
                      const SizedBox(height: 3),
                      Text(
                        plant.healthStatus,
                        style: AppTextStyles.title.copyWith(
                          color: _healthColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  color: AppColors.green,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sıradaki bakım', style: AppTextStyles.muted),
                      const SizedBox(height: 3),
                      Text(
                        plant.nextTask.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dateText(plant.nextTask.dueDate),
                        style: AppTextStyles.muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            Text('Ortam ve bakım bilgileri', style: AppTextStyles.section),
            const SizedBox(height: 12),
            _ProfileRow(
              icon: Icons.place_outlined,
              label: 'Konum',
              value: _valueOrEmpty(plant.location, 'Belirtilmedi'),
            ),
            _ProfileRow(
              icon: Icons.water_drop_outlined,
              label: 'Son sulama',
              value: _valueOrEmpty(plant.lastWatered, 'Belirtilmedi'),
            ),
            _ProfileRow(
              icon: Icons.wb_sunny_outlined,
              label: 'Işık',
              value: _valueOrEmpty(plant.sunlight, 'Belirtilmedi'),
            ),
            _ProfileRow(
              icon: Icons.inventory_2_outlined,
              label: 'Drenaj',
              value: _valueOrEmpty(plant.hasDrainage, 'Belirtilmedi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CareArea extends StatelessWidget {
  const _CareArea({required this.plant});

  final Plant plant;

  @override
  Widget build(BuildContext context) {
    final profile = plant.diagnosis.careProfile;
    final avoid = profile?.avoid.take(3).toList() ?? const <String>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        color: AppColors.mint.withValues(alpha: .82),
        showPattern: false,
        variant: AppCardVariant.tinted,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .72),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.spa_outlined, color: AppColors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Bakım rehberi', style: AppTextStyles.section),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _CareInfoTile(
              icon: Icons.water_drop_outlined,
              title: 'Sulama',
              text: profile == null
                  ? _wateringGuide(plant)
                  : '${profile.watering.soilTrigger} ${profile.watering.intervalText}',
            ),
            if (profile != null) ...[
              _CareInfoTile(
                icon: Icons.wb_sunny_outlined,
                title: 'Işık',
                text: profile.light.isEmpty
                    ? 'Aydınlık ve dengeli bir konum önerilir.'
                    : profile.light,
              ),
              if (profile.watering.note.trim().isNotEmpty)
                _CareInfoTile(
                  icon: Icons.info_outline,
                  title: 'Bakım notu',
                  text: profile.watering.note,
                ),
              PremiumCareTips(profile: profile),
              if (avoid.isNotEmpty) ...[
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 4),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(
                    'Kaçınılması gerekenler',
                    style: AppTextStyles.body,
                  ),
                  children: avoid
                      .map((item) => _MiniLine(text: item, warning: true))
                      .toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _DiagnosisArea extends StatefulWidget {
  const _DiagnosisArea({required this.actions});

  final List<String> actions;

  @override
  State<_DiagnosisArea> createState() => _DiagnosisAreaState();
}

class _DiagnosisAreaState extends State<_DiagnosisArea> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final actions = widget.actions
        .where((action) => action.trim().isNotEmpty)
        .toList();
    final visible = _expanded ? actions : actions.take(1).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        color: Colors.transparent,
        radius: 0,
        showPattern: false,
        variant: AppCardVariant.flat,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fact_check_outlined, color: AppColors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Son teşhis', style: AppTextStyles.section),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (actions.isEmpty)
              Text(
                'Son teşhiste özel bir bakım adımı bulunamadı.',
                style: AppTextStyles.body,
              )
            else ...[
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                alignment: Alignment.topCenter,
                child: Column(
                  children: [
                    for (var index = 0; index < visible.length; index++)
                      _NumberedAction(index: index + 1, text: visible[index]),
                  ],
                ),
              ),
              if (actions.length > 1)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    label: Text(
                      _expanded
                          ? 'Teşhisi daralt'
                          : '${actions.length - 1} öneri daha gör',
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NumberedAction extends StatelessWidget {
  const _NumberedAction({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: AppTextStyles.muted.copyWith(
                color: AppColors.darkGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

class _HistoryArea extends StatelessWidget {
  const _HistoryArea({required this.plant});

  final Plant plant;

  @override
  Widget build(BuildContext context) {
    final notes = plant.notes?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        color: AppColors.warmCream.withValues(alpha: .82),
        showPattern: false,
        variant: AppCardVariant.tinted,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline_outlined, color: AppColors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Gelişim takibi', style: AppTextStyles.section),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${_dateText(plant.lastDiagnosisAt)} tarihli analiz: '
              '${plant.diagnosis.healthScore}/100 · ${plant.healthStatus}',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Aynı açıdan düzenli fotoğraf çekerek ${plant.name} gelişimini karşılaştırabilirsin.',
              style: AppTextStyles.muted,
            ),
            if (notes.isNotEmpty) ...[
              const Divider(height: 28),
              Text('Notun', style: AppTextStyles.muted),
              const SizedBox(height: 5),
              Text(notes, style: AppTextStyles.body),
            ],
          ],
        ),
      ),
    );
  }
}

class _CareInfoTile extends StatelessWidget {
  const _CareInfoTile({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(text, style: AppTextStyles.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLine extends StatelessWidget {
  const _MiniLine({required this.text, this.warning = false});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.do_not_disturb_on_outlined : Icons.check_circle,
            color: warning ? AppColors.warning : AppColors.green,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppTextStyles.muted)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditPlantSheet extends StatefulWidget {
  const _EditPlantSheet({required this.plant});

  final Plant plant;

  @override
  State<_EditPlantSheet> createState() => _EditPlantSheetState();
}

class _EditPlantSheetState extends State<_EditPlantSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _lastWateredController;
  late final TextEditingController _sunlightController;
  late final TextEditingController _notesController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.plant.name);
    _locationController = TextEditingController(
      text: widget.plant.location ?? '',
    );
    _lastWateredController = TextEditingController(
      text: widget.plant.lastWatered ?? '',
    );
    _sunlightController = TextEditingController(
      text: widget.plant.sunlight ?? '',
    );
    _notesController = TextEditingController(text: widget.plant.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _lastWateredController.dispose();
    _sunlightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await PlantRepository().updatePlantProfile(
        plant: widget.plant,
        name: _nameController.text.trim().isEmpty
            ? widget.plant.name
            : _nameController.text.trim(),
        location: _locationController.text.trim(),
        lastWatered: _lastWateredController.text.trim(),
        sunlight: _sunlightController.text.trim(),
        notes: _notesController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(updated);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bitki bilgileri', style: AppTextStyles.title),
              const SizedBox(height: 14),
              _EditField(controller: _nameController, label: 'Bitki adı'),
              _EditField(controller: _locationController, label: 'Konum'),
              _EditField(
                controller: _lastWateredController,
                label: 'Son sulama',
              ),
              _EditField(controller: _sunlightController, label: 'Işık durumu'),
              _EditField(
                controller: _notesController,
                label: 'Not',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: _saving ? 'Kaydediliyor...' : 'Bilgileri Kaydet',
                icon: _saving
                    ? Icons.hourglass_top_rounded
                    : Icons.check_rounded,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white.withValues(alpha: .72),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

String _valueOrEmpty(String? value, String fallback) {
  return value?.trim().isNotEmpty == true ? value!.trim() : fallback;
}

String _dateText(DateTime date) {
  return '${date.day}.${date.month}.${date.year}';
}

String _wateringGuide(Plant plant) {
  final name = plant.name.toLowerCase();
  if (name.contains('paşa') ||
      name.contains('sansevieria') ||
      name.contains('sukulent') ||
      name.contains('kaktüs')) {
    return 'Bu tür fazla sudan hoşlanmaz. Sulamadan önce toprağın tamamen kuruduğunu ve saksı tabağında su kalmadığını kontrol et.';
  }
  if (name.contains('barış') ||
      name.contains('calathea') ||
      name.contains('orkide') ||
      name.contains('eğrelti')) {
    return 'Toprağı uzun süre kupkuru bırakma. Üst 2-3 cm kuruduğunda, saksı drenajını kontrol ederek ölçülü sulama planla.';
  }
  return 'Sulama kararını takvimden çok toprağın üst 2-3 cm nemine göre ver. Emin değilsen bugün gözlem yapıp yarın tekrar kontrol et.';
}

class _PlantHeroImage extends StatelessWidget {
  const _PlantHeroImage({this.imageUrl, this.imagePath});

  final String? imageUrl;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: 210,
      decoration: BoxDecoration(
        color: AppColors.lightGreen.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.local_florist, size: 78, color: AppColors.green),
    );

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          imageUrl!,
          height: 230,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      );
    }

    if (imagePath != null && File(imagePath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.file(
          File(imagePath!),
          height: 230,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    return fallback;
  }
}
