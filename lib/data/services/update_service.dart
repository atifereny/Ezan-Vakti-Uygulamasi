import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

class UpdateInfo {
  final String version; // "1.2.0" (başındaki v atılmış)
  final String url; // release sayfası
  final String notes; // release açıklaması (boş olabilir)

  const UpdateInfo({
    required this.version,
    required this.url,
    required this.notes,
  });
}

/// GitHub'daki son release'i kontrol eder.
class UpdateService {
  static const _dismissedKey = 'update_dismissed_version';

  /// Yüklü sürümden yeni bir release varsa döner; yoksa, kullanıcı o sürümü
  /// "sonra" dediyse, depo ayarlanmadıysa ya da ağ hatası olduysa null.
  Future<UpdateInfo?> checkForUpdate() async {
    if (AppConstants.githubRepo.isEmpty) return null;

    try {
      final r = await http.get(
        Uri.parse(
          'https://api.github.com/repos/${AppConstants.githubRepo}/releases/latest',
        ),
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'EzanVaktiApp',
        },
      ).timeout(const Duration(seconds: 8));

      if (r.statusCode != 200) {
        debugPrint('UpdateService: ${r.statusCode}');
        return null;
      }

      final json = jsonDecode(r.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String?) ?? '';
      final url = (json['html_url'] as String?) ?? '';
      if (tag.isEmpty || url.isEmpty) return null;

      final latest = _clean(tag);
      final current = (await PackageInfo.fromPlatform()).version;
      if (!isNewer(latest, current)) return null;

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_dismissedKey) == latest) return null;

      return UpdateInfo(
        version: latest,
        url: url,
        notes: ((json['body'] as String?) ?? '').trim(),
      );
    } catch (e) {
      debugPrint('UpdateService: kontrol başarısız → $e');
      return null; // güncelleme kontrolü uygulamayı asla bozmamalı
    }
  }

  /// Kullanıcı "Sonra" dedi: bu sürüm bir daha sorulmaz, daha yenisi gelince sorulur.
  Future<void> dismiss(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedKey, version);
  }

  /// "v1.2.0+3" / "1.2.0-beta" → "1.2.0"
  static String _clean(String v) {
    var s = v.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    return s.split(RegExp(r'[+\-]')).first;
  }

  /// Sürümleri sayısal karşılaştırır (1.10.0 > 1.9.0).
  @visibleForTesting
  static bool isNewer(String latest, String current) {
    List<int> parts(String v) => [
          for (final p in _clean(v).split('.')) int.tryParse(p) ?? 0,
        ];
    final a = parts(latest);
    final b = parts(current);
    for (var i = 0; i < a.length || i < b.length; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
