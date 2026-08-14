import 'package:flutter/material.dart';

import '../services/language_service.dart';
import '../services/plant_safety_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

Future<bool?> showSafetyProfileSheet(
  BuildContext context, {
  bool initialSetup = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _SafetyProfileSheet(initialSetup: initialSetup),
  );
}

class _SafetyProfileSheet extends StatefulWidget {
  const _SafetyProfileSheet({required this.initialSetup});

  final bool initialSetup;

  @override
  State<_SafetyProfileSheet> createState() => _SafetyProfileSheetState();
}

class _SafetyProfileSheetState extends State<_SafetyProfileSheet> {
  SafetyProfile _profile = const SafetyProfile(
    hasCat: false,
    hasDog: false,
    hasChild: false,
    configured: false,
  );
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await PlantSafetyService.instance.loadProfile();
    if (!mounted) {
      return;
    }
    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await PlantSafetyService.instance.saveProfile(
      _profile.copyWith(configured: true),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkGreen.withValues(alpha: .16),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.green),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.health_and_safety_outlined,
                          color: AppColors.darkGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.initialSetup
                                  ? context.tr(
                                      'Güvenlik profilini ayarla',
                                      'Set your safety profile',
                                    )
                                  : context.tr(
                                      'Evcil ve çocuk güvenliği',
                                      'Pet and child safety',
                                    ),
                              style: AppTextStyles.section,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              context.tr(
                                'Bitki önerileri ve uyarılar bu bilgilere göre şekillenir.',
                                'Plant suggestions and warnings are shaped by these details.',
                              ),
                              style: AppTextStyles.muted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SafetySwitch(
                    icon: '🐱',
                    label: context.tr(
                      'Evde kedi var mı?',
                      'Do you have a cat?',
                    ),
                    value: _profile.hasCat,
                    onChanged: (value) => setState(
                      () => _profile = _profile.copyWith(hasCat: value),
                    ),
                  ),
                  _SafetySwitch(
                    icon: '🐶',
                    label: context.tr(
                      'Evde köpek var mı?',
                      'Do you have a dog?',
                    ),
                    value: _profile.hasDog,
                    onChanged: (value) => setState(
                      () => _profile = _profile.copyWith(hasDog: value),
                    ),
                  ),
                  _SafetySwitch(
                    icon: '👶',
                    label: context.tr(
                      'Evde 0-6 yaş arası çocuk var mı?',
                      'Is there a child aged 0-6 at home?',
                    ),
                    value: _profile.hasChild,
                    onChanged: (value) => setState(
                      () => _profile = _profile.copyWith(hasChild: value),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppButton(
                    label: _saving
                        ? context.tr('Kaydediliyor...', 'Saving...')
                        : context.tr(
                            'Güvenlik Profilini Kaydet',
                            'Save Safety Profile',
                          ),
                    icon: Icons.check_circle_outline,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
      ),
    );
  }
}

class _SafetySwitch extends StatelessWidget {
  const _SafetySwitch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      activeThumbColor: AppColors.green,
      title: Row(
        children: [
          Text(icon),
          const SizedBox(width: 9),
          Expanded(child: Text(label, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}
