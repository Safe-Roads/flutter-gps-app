import 'dart:async';
import 'dart:io';
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
  Timer? _timer;
  Timer? _gpsTimer;

  bool _isCapturing = false;

  double latitude = 0.0;
  double longitude = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initLocation(); // 🔥 fetch immediately
  }

  Future<void> _initLocation() async {
    try {
      Position pos = await getCurrentLocation();

      setState(() {
        latitude = pos.latitude;
        longitude = pos.longitude;
      });
        debugPrint("Initial GPS -> Lat: $latitude, Lon: $longitude");
      _startLocationUpdates(); // 🔥 start periodic updates AFTER first fetch
    } catch (e) {
      debugPrint('Initial GPS error: $e');
    }
  }

  // 🚀 GPS FUNCTION
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // 🔥 UPDATE LOCATION EVERY 5 SECONDS
  void _startLocationUpdates() {
    _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        Position pos = await getCurrentLocation();

        setState(() {
          latitude = pos.latitude;
          longitude = pos.longitude;
        });

        debugPrint("Updated GPS -> Lat: $latitude, Lon: $longitude");
      } catch (e) {
        debugPrint('GPS error: $e');
      }
    });
  }

  // 🚀 CAMERA INIT
  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        final rearCamera = cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras![0],
        );

        _controller = CameraController(rearCamera, ResolutionPreset.medium);
        await _controller!.initialize();

        if (mounted) {
          setState(() {});
          _startPeriodicCapture();
        }
      }
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  // 🔥 FRAME LOOP
  void _startPeriodicCapture() {
    _timer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (!_isCapturing) {
        _captureAndSendFrame();
      }
    });
  }

  Future<void> _captureAndSendFrame() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    _isCapturing = true;

    try {
      final XFile imageFile = await _controller!.takePicture();
      final File file = File(imageFile.path);

      _sendFrameToAPI(file); // 🔥 fire and forget
    } catch (e) {
      debugPrint('Capture error: $e');
    } finally {
      _isCapturing = false;
    }
  }

  // 🚀 API CALL
  Future<void> _sendFrameToAPI(File imageFile) async {
    try {
      final uri = Uri.parse('http://YOUR_IP:8000/detect');

      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();

      request
          .send()
          .then((response) {
            debugPrint('Sent: ${response.statusCode}');
          })
          .catchError((error) {
            debugPrint('API error: $error');
          });
    } catch (e) {
      debugPrint('Request error: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gpsTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Live Pothole Detection')),
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
