import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/pothole_model.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://pbocfnysxusngjbbbopz.supabase.co'; // Replace with your Supabase URL
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBib2NmbnlzeHVzbmdqYmJib3B6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzMjc0OTcsImV4cCI6MjA4OTkwMzQ5N30.k7_GwbgqMRi7oFeF_lx315_z86FygE5m--s8TqpBllg'; // Replace with your Supabase anon key
  static const String bucketName = 'pothole-images'; // Storage bucket name

  late SupabaseClient _client;

  SupabaseService() {
    _initializeSupabase();
  }

  void _initializeSupabase() {
    Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    _client = Supabase.instance.client;
  }

  // Upload image to Supabase Storage
  Future<String> uploadImage(File imageFile) async {
    final fileName = '${const Uuid().v4()}.jpg';
    final filePath = 'potholes/$fileName';

    await _client.storage.from(bucketName).upload(
      filePath,
      imageFile,
      fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
    );

    // Get public URL
    final publicUrl = _client.storage.from(bucketName).getPublicUrl(filePath);
    return publicUrl;
  }

  // Insert pothole data
  Future<void> insertPothole(Pothole pothole) async {
    await _client.from('potholes').insert(pothole.toJson());
  }

  // Fetch all potholes
  Future<List<Pothole>> fetchPotholes() async {
    final response = await _client
        .from('potholes')
        .select()
        .order('detected_at', ascending: false);

    return response.map<Pothole>((json) => Pothole.fromJson(json)).toList();
  }

  // Subscribe to real-time changes
  Stream<List<Pothole>> subscribeToPotholes() {
    return _client
        .from('potholes')
        .stream(primaryKey: ['id'])
        .order('detected_at', ascending: false)
        .map((data) => data.map<Pothole>((json) => Pothole.fromJson(json)).toList());
  }
}