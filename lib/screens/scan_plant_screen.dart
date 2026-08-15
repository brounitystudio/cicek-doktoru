import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/analytics_service.dart';
import '../services/diagnosis_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/botanical_background.dart';
import '../widgets/branded_header.dart';
import 'diagnosis_loading_screen.dart';
import 'multi_photo_camera_screen.dart';

class ScanPlantScreen extends StatefulWidget {
  const ScanPlantScreen({super.key});

  static const routeName = '/scan';

  @override
  State<ScanPlantScreen> createState() => _ScanPlantScreenState();
}

class _ScanPlantScreenState extends State<ScanPlantScreen> {
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  String _location = 'İç mekân';
  String _lastWatered = '1-3 gün önce';
  String _sunlight = 'Aydınlık ama direkt değil';
  String _drainage = 'Bilmiyorum';
  String _symptomType = 'Sararma / solma';
  String _symptomDuration = 'Birkaç gündür';
  bool _openingDiagnosis = false;

  Future<void> _pickCamera() async {
    if (_images.length >= 3) {
      _showPhotoLimitMessage();
      return;
    }
    final photos = await Navigator.of(context).push<List<XFile>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MultiPhotoCameraScreen(
          initialPhotoPaths: _images.map((image) => image.path).toList(),
        ),
      ),
    );
    if (photos == null || photos.isEmpty || !mounted) {
      return;
    }
    setState(() {
      _images
        ..clear()
        ..addAll(photos.take(3));
    });
  }

  Future<void> _pickGallery() async {
    final images = await _picker.pickMultiImage(
      imageQuality: 65,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (images.isEmpty) return;
    setState(() {
      _images
        ..clear()
        ..addAll(images.take(3));
    });
    if (images.length > 3) {
      _showPhotoLimitMessage();
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  void _showPhotoLimitMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            'Analiz için en fazla 3 fotoğraf eklenir.',
            'You can add up to 3 photos for analysis.',
          ),
        ),
      ),
    );
  }

  void _startDiagnosis() {
    if (_openingDiagnosis) {
      return;
    }
    if (_images.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Daha net teşhis için 3 fotoğraf ekle: genel, belirti ve toprak/dip.',
              'For a clearer diagnosis, add 3 photos: full plant, symptom close-up and soil/base.',
            ),
          ),
        ),
      );
      return;
    }
    final input = PlantScanInput(
      location: _location,
      lastWatered: _lastWatered,
      sunlight: _sunlight,
      hasDrainage: _drainage,
      symptomType: _symptomType,
      symptomDuration: _symptomDuration,
      imagePaths: _images.map((image) => image.path).toList(growable: false),
    );
    setState(() => _openingDiagnosis = true);
    unawaited(
      AnalyticsService.instance.logDiagnosisStarted(
        photoCount: input.imagePaths.length,
      ),
    );
    Navigator.of(context)
        .pushNamed(DiagnosisLoadingScreen.routeName, arguments: input)
        .whenComplete(() {
          if (mounted) {
            setState(() => _openingDiagnosis = false);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BotanicalBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 118),
            children: [
              BrandedHeader(
                eyebrow: context.tr(
                  'Görüntüye göre bakım analizi',
                  'Image-based care analysis',
                ),
                title: context.tr('Bitkini Tara', 'Scan Your Plant'),
                subtitle: context.tr(
                  'Fotoğraf ve birkaç bakım bilgisi yeterli.',
                  'Photos and a few care details are enough.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppCard(
                  child: Column(
                    children: [
                      _PhotoCaptureGrid(
                        images: _images,
                        onRemove: _removeImage,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: _images.length >= 3
                                  ? context.tr('3 foto hazır', '3 photos ready')
                                  : context.tr(
                                      '3 Fotoğraf Çek',
                                      'Take 3 Photos',
                                    ),
                              icon: Icons.photo_camera,
                              onPressed: _images.length >= 3
                                  ? null
                                  : _pickCamera,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppButton(
                              label: context.tr(
                                'Galeriden seç',
                                'Choose from Gallery',
                              ),
                              icon: Icons.photo_library,
                              onPressed: _pickGallery,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr(
                          'En iyi sonuç için: genel görünüm, sorunlu bölge yakın çekim, toprak/saksı dibi.',
                          'Best results: full plant, close-up of the problem area, soil/pot base.',
                        ),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.muted.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _ChoiceGroup(
                title: context.tr(
                  'Bitki nerede duruyor?',
                  'Where is the plant?',
                ),
                value: _location,
                options: const ['İç mekân', 'Dış mekân'],
                onChanged: (value) => setState(() => _location = value),
              ),
              _ChoiceGroup(
                title: context.tr(
                  'En son ne zaman suladın?',
                  'When did you last water it?',
                ),
                value: _lastWatered,
                options: const [
                  'Bugün',
                  '1-3 gün önce',
                  '4-7 gün önce',
                  'Hatırlamıyorum',
                ],
                onChanged: (value) => setState(() => _lastWatered = value),
              ),
              _ChoiceGroup(
                title: context.tr('Güneş görüyor mu?', 'Does it get sunlight?'),
                value: _sunlight,
                options: const [
                  'Direkt güneş',
                  'Aydınlık ama direkt değil',
                  'Az ışık',
                ],
                onChanged: (value) => setState(() => _sunlight = value),
              ),
              _ChoiceGroup(
                title: context.tr(
                  'Saksının altında delik var mı?',
                  'Does the pot have drainage holes?',
                ),
                value: _drainage,
                options: const ['Evet', 'Hayır', 'Bilmiyorum'],
                onChanged: (value) => setState(() => _drainage = value),
              ),
              _ChoiceGroup(
                title: context.tr(
                  'Bitkide en belirgin sorun ne?',
                  'What is the clearest issue?',
                ),
                value: _symptomType,
                options: const [
                  'Sararma / solma',
                  'Leke / çürüme',
                  'Böcek / yapışkanlık',
                  'Sadece kontrol',
                ],
                onChanged: (value) => setState(() => _symptomType = value),
              ),
              _ChoiceGroup(
                title: context.tr(
                  'Bu durum ne zamandır var?',
                  'How long has this been happening?',
                ),
                value: _symptomDuration,
                options: const [
                  'Bugün fark ettim',
                  'Birkaç gündür',
                  '1 haftadan fazla',
                  'Bilmiyorum',
                ],
                onChanged: (value) => setState(() => _symptomDuration = value),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppButton(
                  label: _openingDiagnosis
                      ? context.tr('Teşhis açılıyor...', 'Opening diagnosis...')
                      : context.tr('Teşhisi Başlat', 'Start Diagnosis'),
                  icon: Icons.health_and_safety_outlined,
                  onPressed: _openingDiagnosis ? null : _startDiagnosis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoCaptureGrid extends StatelessWidget {
  const _PhotoCaptureGrid({required this.images, required this.onRemove});

  final List<XFile> images;
  final ValueChanged<int> onRemove;

  static const _icons = [
    Icons.spa_outlined,
    Icons.center_focus_strong_outlined,
    Icons.grass_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final titles = [
      context.tr('Genel', 'Full'),
      context.tr('Belirti', 'Symptom'),
      context.tr('Toprak', 'Soil'),
    ];
    final subtitles = [
      context.tr('Tüm bitki', 'Whole plant'),
      context.tr('Yakın çekim', 'Close-up'),
      context.tr('Dip/saksı', 'Base/pot'),
    ];
    final activeIndex = images.isEmpty ? 0 : (images.length - 1).clamp(0, 2);
    final nextIndex = images.length.clamp(0, 2);

    return Column(
      children: [
        _PhotoPreviewHero(
          title: images.length >= 3
              ? context.tr('Fotoğraflar hazır', 'Photos ready')
              : titles[nextIndex],
          subtitle: images.length >= 3
              ? context.tr(
                  'Analiz için genel, belirti ve toprak fotoğrafı tamam.',
                  'Full, symptom and soil photos are ready for analysis.',
                )
              : context.tr(
                  '${nextIndex + 1}. adım: ${subtitles[nextIndex]}',
                  'Step ${nextIndex + 1}: ${subtitles[nextIndex]}',
                ),
          icon: _icons[nextIndex],
          image: images.isEmpty ? null : images[activeIndex],
          complete: images.length >= 3,
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(3, (index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == 2 ? 0 : 10),
                child: _PhotoSlot(
                  index: index,
                  title: titles[index],
                  subtitle: subtitles[index],
                  icon: _icons[index],
                  image: index < images.length ? images[index] : null,
                  active:
                      index == nextIndex || (images.length >= 3 && index == 2),
                  onRemove: () => onRemove(index),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _PhotoPreviewHero extends StatelessWidget {
  const _PhotoPreviewHero({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.complete,
    this.image,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool complete;
  final XFile? image;

  @override
  Widget build(BuildContext context) {
    final selected = image != null;

    return AspectRatio(
      aspectRatio: 1.38,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: selected
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFEAF6EE), Color(0xFFFFF7E9)],
                  ),
            color: selected ? Colors.black : null,
            border: Border.all(
              color: AppColors.lightGreen.withValues(alpha: .5),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.darkGreen.withValues(alpha: .12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (selected)
                Image.file(File(image!.path), fit: BoxFit.cover)
              else ...[
                Positioned(
                  right: -22,
                  top: -18,
                  child: Icon(
                    Icons.local_florist_rounded,
                    size: 150,
                    color: AppColors.green.withValues(alpha: .08),
                  ),
                ),
                Center(
                  child: Container(
                    width: 118,
                    height: 118,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(color: Colors.white),
                    ),
                    child: Icon(icon, color: AppColors.green, size: 52),
                  ),
                ),
              ],
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.black.withValues(alpha: .52)
                        : Colors.white.withValues(alpha: .82),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: selected ? .18 : .75,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: complete
                              ? AppColors.green
                              : AppColors.mint.withValues(
                                  alpha: selected ? .95 : 1,
                                ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          complete ? Icons.check_rounded : icon,
                          color: complete ? Colors.white : AppColors.green,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body.copyWith(
                                color: selected
                                    ? Colors.white
                                    : AppColors.darkGreen,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.muted.copyWith(
                                color: selected
                                    ? Colors.white.withValues(alpha: .78)
                                    : AppColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onRemove,
    required this.active,
    this.image,
  });

  final int index;
  final String title;
  final String subtitle;
  final IconData icon;
  final XFile? image;
  final VoidCallback onRemove;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final selected = image != null;
    return AspectRatio(
      aspectRatio: .92,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : AppColors.mint.withValues(alpha: .75),
            border: Border.all(
              color: active || selected
                  ? AppColors.green
                  : AppColors.lightGreen.withValues(alpha: .7),
              width: active || selected ? 2 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (selected)
                Image.file(File(image!.path), fit: BoxFit.cover)
              else
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: AppColors.green, size: 24),
                      const SizedBox(height: 6),
                      Text(
                        '${index + 1}. $title',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.darkGreen,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              if (selected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: InkWell(
                    onTap: onRemove,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 7,
                bottom: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.black.withValues(alpha: .55)
                        : Colors.white.withValues(alpha: .72),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.darkGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceGroup extends StatelessWidget {
  const _ChoiceGroup({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.spa,
                    color: AppColors.green,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: AppTextStyles.section)),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 9,
              runSpacing: 10,
              children: options.map((option) {
                return _AnswerChip(
                  label: _scanOptionLabel(context, option),
                  selected: option == value,
                  onTap: () => onChanged(option),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

String _scanOptionLabel(BuildContext context, String option) {
  return switch (option) {
    'İç mekân' => context.tr('İç mekân', 'Indoor'),
    'Dış mekân' => context.tr('Dış mekân', 'Outdoor'),
    'Bugün' => context.tr('Bugün', 'Today'),
    '1-3 gün önce' => context.tr('1-3 gün önce', '1-3 days ago'),
    '4-7 gün önce' => context.tr('4-7 gün önce', '4-7 days ago'),
    'Hatırlamıyorum' => context.tr('Hatırlamıyorum', 'I do not remember'),
    'Direkt güneş' => context.tr('Direkt güneş', 'Direct sun'),
    'Aydınlık ama direkt değil' => context.tr(
      'Aydınlık ama direkt değil',
      'Bright but indirect',
    ),
    'Az ışık' => context.tr('Az ışık', 'Low light'),
    'Evet' => context.tr('Evet', 'Yes'),
    'Hayır' => context.tr('Hayır', 'No'),
    'Bilmiyorum' => context.tr('Bilmiyorum', 'Not sure'),
    'Sararma / solma' => context.tr('Sararma / solma', 'Yellowing / wilting'),
    'Leke / çürüme' => context.tr('Leke / çürüme', 'Spots / rot'),
    'Böcek / yapışkanlık' => context.tr(
      'Böcek / yapışkanlık',
      'Pests / sticky leaves',
    ),
    'Sadece kontrol' => context.tr('Sadece kontrol', 'Just checking'),
    'Bugün fark ettim' => context.tr('Bugün fark ettim', 'Noticed today'),
    'Birkaç gündür' => context.tr('Birkaç gündür', 'A few days'),
    '1 haftadan fazla' => context.tr('1 haftadan fazla', 'More than a week'),
    _ => option,
  };
}

class _AnswerChip extends StatelessWidget {
  const _AnswerChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.green
              : AppColors.mint.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.green
                : AppColors.lightGreen.withValues(alpha: .45),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.green.withValues(alpha: .20),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, color: Colors.white, size: 15),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.darkGreen,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
