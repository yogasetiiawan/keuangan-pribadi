import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/finance_models.dart';
import '../services/api_service.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String _mode = 'login'; // 'login' | 'register'
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _sheetIdCtrl = TextEditingController();
  List<UserAccountModel> _savedAccounts = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    final accs = await ApiService.getAllAccounts();
    if (mounted) {
      setState(() {
        _savedAccounts = accs;
        if (accs.isNotEmpty && _emailCtrl.text.isEmpty) {
          _emailCtrl.text = accs.first.email;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _sheetIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      if (_mode == 'login') {
        await ApiService.login(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
      } else {
        if (_nameCtrl.text.trim().isEmpty ||
            _emailCtrl.text.trim().isEmpty ||
            _passCtrl.text.length < 4) {
          throw Exception('Lengkapi Nama, Email, dan Password (min. 4 karakter)');
        }
        await ApiService.register(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          spreadsheetId: _sheetIdCtrl.text.trim(),
        );
      }
      HapticFeedback.mediumImpact();
      if (mounted) widget.onAuthenticated();
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _quickLogin(UserAccountModel acc) async {
    HapticFeedback.mediumImpact();
    await ApiService.login(email: acc.email, password: acc.password);
    if (mounted) widget.onAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F2942)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(
                        CupertinoIcons.chart_pie_fill,
                        color: Color(0xFF34D399),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'KeuanganKu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pencatatan Keuangan Pribadi Terintegrasi Google Sheets',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoSlidingSegmentedControl<String>(
                              groupValue: _mode,
                              children: const {
                                'login': Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Text('Masuk (Login)',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ),
                                'register': Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Text('Daftar Akun',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ),
                              },
                              onValueChanged: (val) {
                                if (val == null) return;
                                HapticFeedback.selectionClick();
                                setState(() => _mode = val);
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (_mode == 'register') ...[
                            TextField(
                              controller: _nameCtrl,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: 'Nama Lengkap Anda',
                                hintText: 'Contoh: Budi Santoso',
                                prefixIcon: const Icon(CupertinoIcons.person),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              labelText: _mode == 'login'
                                  ? 'Email atau Nama Akun'
                                  : 'Alamat Email',
                              hintText: 'yoga@keuanganku.id',
                              prefixIcon: const Icon(CupertinoIcons.mail),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passCtrl,
                            obscureText: true,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: '••••••',
                              prefixIcon: const Icon(CupertinoIcons.lock),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          if (_mode == 'register') ...[
                            const SizedBox(height: 14),
                            TextField(
                              controller: _sheetIdCtrl,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText:
                                    'Spreadsheet ID Google Sheets (Opsional)',
                                hintText: 'Bisa diatur nanti di menu Sheets',
                                prefixIcon: const Icon(CupertinoIcons.table),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _isSubmitting ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: Icon(_mode == 'login'
                                  ? CupertinoIcons.arrow_right_circle_fill
                                  : CupertinoIcons.person_add_solid),
                              label: Text(
                                _isSubmitting
                                    ? 'Memproses...'
                                    : (_mode == 'login'
                                        ? 'Masuk ke Aplikasi'
                                        : 'Buat Akun Baru'),
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          if (_mode == 'login' &&
                              _savedAccounts.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Divider(
                                color: mutedColor.withValues(alpha: 0.25)),
                            const SizedBox(height: 8),
                            Text(
                              'Masuk Cepat (Akun di Perangkat Ini):',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: mutedColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _savedAccounts.map((acc) {
                                return ActionChip(
                                  avatar: CircleAvatar(
                                    backgroundColor: const Color(0xFF0F172A),
                                    child: Text(
                                      acc.initials,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  label: Text(acc.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  onPressed: () => _quickLogin(acc),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
