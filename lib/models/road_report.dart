class RoadReport {
  const RoadReport({
    required this.id,
    required this.label,
    required this.confidence,
    required this.timestamp,
    this.reviewStatus = 'needs review',
    this.photoPath,
    this.synced = false,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String label;
  final double confidence;
  final DateTime timestamp;
  final String reviewStatus;
  final String? photoPath;
  final bool synced;
  final double? latitude;
  final double? longitude;

  Map<String, Object?> toMap() => {
        'id': id,
        'label': label,
        'confidence': confidence,
        'timestamp': timestamp.toIso8601String(),
        'reviewStatus': reviewStatus,
        'photoPath': photoPath,
        'synced': synced,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory RoadReport.fromMap(Map<String, dynamic> map) => RoadReport(
        id: map['id'] as String,
        label: map['label'] as String,
        confidence: (map['confidence'] as num).toDouble(),
        timestamp: DateTime.parse(map['timestamp'] as String),
        reviewStatus: map['reviewStatus'] as String? ?? 'needs review',
        photoPath: map['photoPath'] as String?,
        synced: map['synced'] as bool? ?? false,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
      );

  RoadReport copyWith({String? reviewStatus, String? photoPath, bool? synced}) =>
      RoadReport(
        id: id,
        label: label,
        confidence: confidence,
        timestamp: timestamp,
        reviewStatus: reviewStatus ?? this.reviewStatus,
        photoPath: photoPath ?? this.photoPath,
        synced: synced ?? this.synced,
        latitude: latitude,
        longitude: longitude,
      );
}
