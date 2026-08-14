import 'dart:io';

import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';
import 'premium_badge.dart';

class PlantStatusCard extends StatelessWidget {
  const PlantStatusCard({
    super.key,
    required this.plant,
    this.onTap,
    this.onDelete,
  });

  final Plant plant;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final score = plant.diagnosis.healthScore;
    final tone = score >= 80
        ? AppColors.green
        : score >= 50
        ? AppColors.warning
        : AppColors.critical;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _PlantCover(
              imagePath: plant.imagePath ?? plant.diagnosis.imagePath,
              imageUrl: plant.imageUrl ?? plant.diagnosis.imageUrl,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(plant.name, style: AppTextStyles.section),
                      ),
                      PremiumBadge(label: plant.healthStatus, tone: tone),
                      if (onDelete != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Bitkiyi sil',
                          visualDensity: VisualDensity.compact,
                          onPressed: onDelete,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: score / 100,
                      minHeight: 7,
                      backgroundColor: AppColors.mint,
                      color: tone,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Son teşhis: ${plant.lastDiagnosisAt.day}.${plant.lastDiagnosisAt.month}.${plant.lastDiagnosisAt.year}',
                    style: AppTextStyles.muted,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    plant.nextTask.title,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.green,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantCover extends StatelessWidget {
  const _PlantCover({this.imagePath, this.imageUrl});

  final String? imagePath;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.mint, AppColors.lightGreen],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Icon(
        Icons.local_florist,
        color: AppColors.darkGreen,
        size: 38,
      ),
    );

    final localPath = imagePath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.file(
            file,
            width: 76,
            height: 76,
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
      borderRadius: BorderRadius.circular(22),
      child: Image.network(
        remoteUrl,
        width: 76,
        height: 76,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}
