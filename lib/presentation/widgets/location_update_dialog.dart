import 'package:flutter/material.dart';

class LocationUpdateDialog extends StatelessWidget {
  final double distanceKm;
  final VoidCallback onUpdate;
  final VoidCallback onKeep;

  const LocationUpdateDialog({
    super.key,
    required this.distanceKm,
    required this.onUpdate,
    required this.onKeep,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.location_on, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Konumunuz Değişti mi?',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Text(
        'Yeni bir konum algılandı '
        '(yaklaşık ${distanceKm.toStringAsFixed(0)} km uzaklıkta).\n\n'
        'Uygulama konumunuz otomatik olarak güncellensin mi?',
      ),
      actions: [
        TextButton(
          onPressed: onKeep,
          child: const Text('Hayır, Kalsın'),
        ),
        ElevatedButton(
          onPressed: onUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B5E20),
            foregroundColor: Colors.white,
          ),
          child: const Text('Evet, Güncelle'),
        ),
      ],
    );
  }
}
