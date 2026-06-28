class SavedLocation {
  final double latitude;
  final double longitude;
  final DateTime savedAt;

  const SavedLocation({
    required this.latitude,
    required this.longitude,
    required this.savedAt,
  });

  @override
  String toString() =>
      'SavedLocation(lat: $latitude, lng: $longitude, savedAt: $savedAt)';
}
