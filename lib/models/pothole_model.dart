class Pothole {
  final String id;
  final String imageUrl;
  final double confidence;
  final double latitude;
  final double longitude;
  final String status;
  final DateTime detectedAt;

  Pothole({
    required this.id,
    required this.imageUrl,
    required this.confidence,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.detectedAt,
  });

  // Factory constructor to create Pothole from Supabase JSON
  factory Pothole.fromJson(Map<String, dynamic> json) {
    return Pothole(
      id: json['id'],
      imageUrl: json['image_url'],
      confidence: json['confidence'].toDouble(),
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      status: json['status'],
      detectedAt: DateTime.parse(json['detected_at']),
    );
  }

  // Convert Pothole to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      'confidence': confidence,
      'latitude': latitude,
      'longitude': longitude,
      'location': 'POINT($longitude $latitude)', // PostGIS format
      'status': status,
      'detected_at': detectedAt.toIso8601String(),
    };
  }
}