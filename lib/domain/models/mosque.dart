class Mosque {
  static const unnamedLabel = 'İsimsiz Cami';

  final String id;
  final String name;
  final double lat;
  final double lng;
  final double distanceKm;

  const Mosque({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.distanceKm,
  });

  /// OSM'de adı kayıtlı olmayan cami (name boş ya da yer tutucu)
  bool get isUnnamed => name.isEmpty || name == unnamedLabel;
}
