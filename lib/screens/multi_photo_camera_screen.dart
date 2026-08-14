import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class MultiPhotoCameraScreen extends StatefulWidget {
  const MultiPhotoCameraScreen({super.key, this.initialPhotoPaths = const []});

  static const routeName = '/multi-photo-camera';

  final List<String> initialPhotoPaths;

  @override
  State<MultiPhotoCameraScreen> createState() => _MultiPhotoCameraScreenState();
}

class _MultiPhotoCameraScreenState extends State<MultiPhotoCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeFuture;
  List<CameraDescription> _cameras = const [];
  final List<XFile> _photos = [];
  bool _isTakingPhoto = false;
  String? _error;

  static const _labels = [
    ('Genel', 'Tüm bitki'),
    ('Belirti', 'Yakın çekim'),
    ('Toprak', 'Dip/saksı'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _photos.addAll(widget.initialPhotoPaths.take(3).map(XFile.new));
    _setupCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupCamera();
    }
  }

  Future<void> _setupCamera() async {
    try {
      _cameras = await availableCameras();
      if (!mounted) return;
      if (_cameras.isEmpty) {
        setState(() => _error = 'Kamera bulunamadı.');
        return;
      }

      final backCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = controller;
      _initializeFuture = controller.initialize();
      await _initializeFuture;
      if (!mounted) return;
      await controller.setFlashMode(FlashMode.off);
      setState(() => _error = null);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Kamera açılamadı. İzinleri kontrol edip tekrar deneyin.';
      });
    }
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null ||
        _isTakingPhoto ||
        _photos.length >= 3 ||
        !controller.value.isInitialized) {
      return;
    }

    setState(() => _isTakingPhoto = true);
    try {
      final photo = await controller.takePicture();
      if (!mounted) return;
      setState(() => _photos.add(photo));

      if (_photos.length == 3) {
        await Future<void>.delayed(const Duration(milliseconds: 260));
        if (!mounted) return;
        Navigator.of(context).pop(_photos);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoğraf çekilemedi, tekrar deneyin.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isTakingPhoto = false);
      }
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  void _finish() {
    Navigator.of(context).pop(_photos);
  }

  @override
  Widget build(BuildContext context) {
    final nextIndex = _photos.length.clamp(0, 2);
    final nextLabel = _labels[nextIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _CameraBody(
                controller: _controller,
                initializeFuture: _initializeFuture,
              ),
            ),
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: _TopBar(
                photoCount: _photos.length,
                nextTitle: nextLabel.$1,
                nextSubtitle: nextLabel.$2,
                onClose: _finish,
              ),
            ),
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _ErrorCard(message: _error!, onRetry: _setupCamera),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _CapturePanel(
                photos: _photos,
                isTakingPhoto: _isTakingPhoto,
                onTakePhoto: _takePhoto,
                onRemovePhoto: _removePhoto,
                onFinish: _finish,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraBody extends StatelessWidget {
  const _CameraBody({required this.controller, required this.initializeFuture});

  final CameraController? controller;
  final Future<void>? initializeFuture;

  @override
  Widget build(BuildContext context) {
    final camera = controller;
    if (camera == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return FutureBuilder<void>(
      future: initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !camera.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        return Center(
          child: AspectRatio(
            aspectRatio: 1 / camera.value.aspectRatio,
            child: CameraPreview(camera),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.photoCount,
    required this.nextTitle,
    required this.nextSubtitle,
    required this.onClose,
  });

  final int photoCount;
  final String nextTitle;
  final String nextSubtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: .44),
          ),
          onPressed: onClose,
          icon: const Icon(Icons.close, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .44),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: .16)),
            ),
            child: Row(
              children: [
                Text(
                  '${photoCount + 1 > 3 ? 3 : photoCount + 1}/3',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        photoCount >= 3 ? 'Fotoğraflar hazır' : nextTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        photoCount >= 3 ? 'Analize dönebilirsin' : nextSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .75),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
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
    );
  }
}

class _CapturePanel extends StatelessWidget {
  const _CapturePanel({
    required this.photos,
    required this.isTakingPhoto,
    required this.onTakePhoto,
    required this.onRemovePhoto,
    required this.onFinish,
  });

  final List<XFile> photos;
  final bool isTakingPhoto;
  final VoidCallback onTakePhoto;
  final ValueChanged<int> onRemovePhoto;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final complete = photos.length >= 3;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .66),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: .14)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: List.generate(3, (index) {
              final photo = index < photos.length ? photos[index] : null;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == 2 ? 0 : 10),
                  child: _MiniSlot(
                    index: index,
                    photo: photo,
                    onRemove: photo == null ? null : () => onRemovePhoto(index),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (photos.isNotEmpty)
                _RoundActionButton(
                  icon: Icons.check_rounded,
                  label: 'Tamam',
                  onTap: onFinish,
                ),
              if (photos.isNotEmpty) const SizedBox(width: 24),
              GestureDetector(
                onTap: complete ? onFinish : onTakePhoto,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: complete ? AppColors.green : Colors.white,
                    border: Border.all(
                      color: complete ? AppColors.green : Colors.white,
                      width: 5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .28),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isTakingPhoto
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: AppColors.green,
                            ),
                          )
                        : Icon(
                            complete
                                ? Icons.check_rounded
                                : Icons.camera_alt_rounded,
                            color: complete ? Colors.white : AppColors.green,
                            size: 34,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            complete
                ? '3 fotoğraf hazır'
                : 'Sıradaki fotoğrafı çekmek için dokun',
            style: AppTextStyles.muted.copyWith(
              color: Colors.white.withValues(alpha: .76),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSlot extends StatelessWidget {
  const _MiniSlot({required this.index, this.photo, this.onRemove});

  final int index;
  final XFile? photo;
  final VoidCallback? onRemove;

  static const _titles = ['Genel', 'Belirti', 'Toprak'];

  @override
  Widget build(BuildContext context) {
    final selected = photo != null;
    return AspectRatio(
      aspectRatio: 1.08,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: .08)
                : Colors.white.withValues(alpha: .12),
            border: Border.all(
              color: selected ? AppColors.lightGreen : Colors.white24,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (selected) Image.file(File(photo!.path), fit: BoxFit.cover),
              if (!selected)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _titles[index],
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .74),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              if (onRemove != null)
                Positioned(
                  top: 5,
                  right: 5,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .58),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 15,
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

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 25),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .75),
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            color: AppColors.green,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}
