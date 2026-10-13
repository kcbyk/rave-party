import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/mock_data_service.dart';
import '../theme/app_theme.dart';
import 'main_navigation_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _bio = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _name.dispose(); _bio.dispose(); super.dispose(); }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await MockDataService.register(name: _name.text, bio: _bio.text);
    await ApiService().syncUserProfile();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainNavigationScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.background,
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.auto_awesome, size: 58, color: AppTheme.ravePurple),
        const SizedBox(height: 20),
        const Text('Party Rave’e hoş geldin', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Arkadaşlarınla aynı odada izle, konuş ve senkron kal.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 32),
        TextFormField(controller: _name, autofocus: true, maxLength: 40, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Görünen adın', hintText: 'Örn. Şenol'), validator: (v) => v == null || v.trim().length < 2 ? 'En az 2 karakter gir.' : null),
        const SizedBox(height: 12),
        TextFormField(controller: _bio, maxLength: 100, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Kısa biyografi (isteğe bağlı)', hintText: 'Ne izlemeyi seversin?')),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: _saving ? null : _register, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.ravePurple, padding: const EdgeInsets.symmetric(vertical: 15)), child: Text(_saving ? 'Kaydediliyor…' : 'Hesabımı oluştur')),
        const SizedBox(height: 12),
        Text('Kimliğin bu cihazda kalıcı olarak saklanır.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 12)),
      ]),
    )))),
  );
}
