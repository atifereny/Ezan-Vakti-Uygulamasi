import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../domain/models/dhikr.dart';

class ZikirOlusturScreen extends StatefulWidget {
  const ZikirOlusturScreen({super.key});

  @override
  State<ZikirOlusturScreen> createState() => _ZikirOlusturScreenState();
}

class _ZikirOlusturScreenState extends State<ZikirOlusturScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _customCtrl = TextEditingController();

  static const _presets = [33, 99, 100, 500, 1000];
  int _target = 33;
  bool _useCustom = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final int? target;
    if (_useCustom) {
      target = int.tryParse(_customCtrl.text.trim());
      if (target == null || target <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geçerli bir hedef sayı girin.')),
        );
        return;
      }
    } else {
      target = _target;
    }

    Navigator.pop(
      context,
      Dhikr(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameCtrl.text.trim(),
        target: target,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zikir Oluştur')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Zikir adı',
                hintText: 'Örn. Sübhanallah',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ad boş olamaz' : null,
            ),
            const SizedBox(height: 28),
            const Text(
              'Hedef',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 15, color: kOnSurface),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((p) {
                final selected = !_useCustom && _target == p;
                return ChoiceChip(
                  label: Text('$p'),
                  selected: selected,
                  selectedColor: kPrimary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : kOnSurface,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() {
                    _useCustom = false;
                    _target = p;
                    _customCtrl.clear();
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _customCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Özel hedef',
                border: const OutlineInputBorder(),
                suffixIcon:
                    _useCustom ? const Icon(Icons.check, color: kPrimary) : null,
              ),
              onChanged: (v) => setState(() => _useCustom = v.trim().isNotEmpty),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Kaydet', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
