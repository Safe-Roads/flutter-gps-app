import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/supabase_service.dart';
import '../models/pothole_model.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Pothole> _potholes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPotholes();
    _subscribeToUpdates();
  }

  Future<void> _fetchPotholes() async {
    try {
      final potholes = await _supabaseService.fetchPotholes();
      setState(() {
        _potholes = potholes;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching potholes: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToUpdates() {
    _supabaseService.subscribeToPotholes().listen((potholes) {
      setState(() => _potholes = potholes);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pothole Map'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(37.7749, -122.4194), // Default to San Francisco
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.pothole_app',
                ),
                MarkerLayer(
                  markers: _potholes.map((pothole) {
                    return Marker(
                      point: LatLng(pothole.latitude, pothole.longitude),
                      child: GestureDetector(
                        onTap: () => _showPotholeDetails(pothole),
                        child: const Icon(
                          Icons.warning,
                          color: Colors.red,
                          size: 30,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }

  void _showPotholeDetails(Pothole pothole) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pothole Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              pothole.imageUrl,
              height: 150,
              width: 150,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.error),
            ),
            const SizedBox(height: 10),
            Text('Confidence: ${(pothole.confidence * 100).toStringAsFixed(1)}%'),
            Text('Status: ${pothole.status}'),
            Text('Detected: ${pothole.detectedAt.toString()}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}