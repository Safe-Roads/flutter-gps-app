import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? cameras;

  // 🔥 CONTROL FLAGS
  bool _isProcessing = false;
  bool _isSending = false;
  DateTime _lastSent = DateTime.now();

  double latitude = 0.0;
  double longitude = 0.0;

  Timer? _gpsTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initLocation();
  }

  // ================== LOCATION ==================
  Future<void> _initLocation() async {
    try {
      Position pos = await getCurrentLocation();

      setState(() {
        latitude = pos.latitude;
        longitude = pos.longitude;
      });

      _startLocationUpdates();
    } catch (e) {
      debugPrint('GPS init error: $e');
    }
  }

  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permanently denied.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  void _startLocationUpdates() {
    _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        Position pos = await getCurrentLocation();

        setState(() {
          latitude = pos.latitude;
          longitude = pos.longitude;
        });
      } catch (e) {
        debugPrint('GPS error: $e');
      }
    });
  }

  // ================== CAMERA ==================
  Future<void> _initializeCamera() async {
    cameras = await availableCameras();

    final rearCamera = cameras!.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => cameras![0],
    );

    _controller = CameraController(
      rearCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();

    if (!mounted) return;

    setState(() {});

    // 🔥 START STREAM
    _controller!.startImageStream(_processCameraImage);
  }

  // ================== FRAME PROCESSING ==================
  void _processCameraImage(CameraImage image) {
    if (_isProcessing) return;

    final now = DateTime.now();

    // 🔥 LIMIT: 1 request every 2 seconds
    if (now.difference(_lastSent).inMilliseconds < 2000) return;

    _isProcessing = true;

    try {
      final bytes = image.planes[0].bytes;

      // 🔥 PREVENT OVERLAPPING API CALLS
      if (!_isSending) {
        _isSending = true;
        _lastSent = now;

        _sendFrameToAPI(bytes).whenComplete(() {
          _isSending = false;
        });
      }
    } catch (e) {
      debugPrint("Processing error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // ================== API CALL ==================
  Future<void> _sendFrameToAPI(Uint8List bytes) async {
    try {
      final uri = Uri.parse('https://yolo-backend-server.onrender.com/detect');

      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'frame.jpg',
        ),
      );

      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();

      final response = await request.send();

      debugPrint("Response: ${response.statusCode}");
    } catch (e) {
      debugPrint("API error: $e");
    }
  }

  // ================== DISPOSE ==================
  @override
  void dispose() {
    _gpsTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Live Detection')),
      body: Stack(
        children: [
          CameraPreview(_controller!),

          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black54,
              child: Text(
                'Lat: $latitude\nLon: $longitude',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}