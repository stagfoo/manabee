/// Photographing a book page by page.
///
/// The camera stays up between shots: frame the page, tap the shutter,
/// turn the page, tap again. The last few shots show along the bottom so a
/// blurred one can be retaken, and Done returns them all, in the order
/// taken, for the importer to make a chapter of. Made for picture books,
/// where a whole book is twenty-odd pages in a couple of minutes.
library;

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

class PageCameraScreen extends StatefulWidget {
  const PageCameraScreen({super.key});

  @override
  State<PageCameraScreen> createState() => _PageCameraScreenState();
}

class _PageCameraScreenState extends State<PageCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  String? _problem;
  bool _taking = false;
  bool _flash = false;

  /// The photos taken, as files, in order.
  final List<String> _shots = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  /// The camera is let go when the app goes to the background and taken
  /// back when it returns — Android won't share it with another app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (state == AppLifecycleState.inactive) {
      _camera = null;
      camera?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && camera == null) {
      _open();
    }
  }

  Future<void> _open() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.where(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (cameras.isEmpty) {
        setState(() => _problem = 'No camera found on this device.');
        return;
      }
      final controller = CameraController(
        back.isNotEmpty ? back.first : cameras.first,
        // Full resolution; the importer scales each page down to what
        // reading and OCR need.
        ResolutionPreset.max,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _problem = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(
        () => _problem = e.code.contains('Access')
            ? 'Camera access was refused — allow it in Android settings.'
            : 'The camera couldn\'t start (${e.code}).',
      );
    }
  }

  Future<void> _take() async {
    final camera = _camera;
    if (camera == null || _taking || !camera.value.isInitialized) return;
    setState(() {
      _taking = true;
      _flash = true;
    });
    HapticFeedback.mediumImpact();
    try {
      final shot = await camera.takePicture();
      _shots.add(shot.path);
    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t take it (${e.code}).')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _taking = false;
          _flash = false;
        });
      }
    }
  }

  void _retakeLast() {
    if (_shots.isEmpty) return;
    final last = _shots.removeLast();
    File(last).delete().catchError((_) => File(last));
    setState(() {});
  }

  Future<bool> _confirmLeave() async {
    if (_shots.isEmpty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Discard ${_shots.length} pages?'),
        content: const Text('Tap Done instead to keep them as a chapter.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep shooting'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(color: C.danger)),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return PopScope(
      canPop: _shots.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          Navigator.pop(context, const <String>[]);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: Center(
                  child: _problem != null
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _problem!,
                            textAlign: TextAlign.center,
                            style: T.bodyLg,
                          ),
                        )
                      : camera == null || !camera.value.isInitialized
                      ? const CircularProgressIndicator()
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            CameraPreview(camera),
                            // A frame guide: fill it with the page.
                            IgnorePointer(
                              child: FractionallySizedBox(
                                widthFactor: 0.88,
                                heightFactor: 0.88,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: C.lime.withValues(alpha: 0.6),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            if (_flash)
                              Positioned.fill(
                                child: ColoredBox(
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              _thumbnails(),
              _controls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        Expanded(
          child: Text(
            _shots.isEmpty
                ? 'Photograph each page'
                : '${_shots.length} page${_shots.length == 1 ? '' : 's'}',
            style: T.headlineMd,
          ),
        ),
      ],
    ),
  );

  Widget _thumbnails() {
    if (_shots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Fill the frame with the page, tap the shutter, turn the page.',
          textAlign: TextAlign.center,
          style: T.bodyMd.copyWith(color: C.textDim),
        ),
      );
    }
    final recent = _shots.reversed.take(6).toList();
    return SizedBox(
      height: 84,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: recent.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Image.file(
                File(recent[i]),
                width: 50,
                height: 68,
                fit: BoxFit.cover,
                cacheWidth: 120,
              ),
              Positioned(
                left: 3,
                bottom: 2,
                child: Text(
                  '${_shots.length - i}',
                  style: T.monoSm.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
    child: Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _shots.isEmpty ? null : _retakeLast,
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Retake last'),
            ),
          ),
        ),
        GestureDetector(
          onTap: _take,
          child: Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _taking ? C.inactive : Colors.white,
              border: Border.all(color: C.lime, width: 4),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: Colors.black,
              size: 32,
              semanticLabel: 'Take photo',
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: C.lime,
                foregroundColor: C.onLime,
              ),
              onPressed: _shots.isEmpty
                  ? null
                  : () => Navigator.pop(context, List<String>.of(_shots)),
              child: const Text('Done'),
            ),
          ),
        ),
      ],
    ),
  );
}
