import 'dart:io';

import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';

class PlantCard extends StatelessWidget {
  const PlantCard({super.key, required this.plant, this.onTap});

  final Plant plant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AppCard(
        child: Row(
          children: [
            _PlantThumb(
              imagePath: plant.imagePath ?? plant.diagnosis.imagePath,
              imageUrl: plant.imageUrl ?? plant.diagnosis.imageUrl,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plant.name, style: AppTextStyles.section),
                  const SizedBox(height: 4),
                  Text(
                    '${plant.healthStatus} · Son teşhis: ${plant.lastDiagnosisAt.day}.${plant.lastDiagnosisAt.month}.${plant.lastDiagnosisAt.year}',
                    style: AppTextStyles.muted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plant.nextTask.title,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _PlantThumb extends StatelessWidget {
  const _PlantThumb({this.imagePath, this.imageUrl});

  final String? imagePath;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.lightGreen.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.local_florist, color: AppColors.green, size: 34),
    );

    final localPath = imagePath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            file,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
          ),
        );
      }
    }

    final remoteUrl = imageUrl?.trim();
    if (remoteUrl == null || remoteUrl.isEmpty) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        remoteUrl,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}
