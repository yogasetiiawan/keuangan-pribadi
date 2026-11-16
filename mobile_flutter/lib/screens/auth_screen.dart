import 'dart:async';
import 'dart:math' as math;
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
  bool _isOtpStep = false;
  UserAccountModel? _pendingUser;
  String _pendingSheetId = '';
  String _generatedOtp = '';
  int _resendSeconds = 60;
  Timer? _countdownTimer;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _sheetIdCtrl = TextEditingController();

  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

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
    _countdownTimer?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _sheetIdCtrl.dispose();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startOtpFlow(UserAccountModel user, {String sheetId = ''}) {
    final rng = math.Random();
    final code = (100000 + rng.nextInt(900000)).toString();

    for (final c in _otpCtrls) {
      c.clear();
    }

    setState(() {
      _pendingUser = user;
      _pendingSheetId = sheetId;
      _generatedOtp = code;
      _isOtpStep = true;
      _resendSeconds = 60;
    });

    // Kirim email OTP via Google Apps Script di background (jika URL sudah terhubung)
    ApiService.sendOtpEmail(
      email: user.email,
      name: user.name,
      otpCode: code,
    );

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  void _autoFillOtp() {
    HapticFeedback.mediumImpact();
    for (int i = 0; i < 6 && i < _generatedOtp.length; i++) {
      _otpCtrls[i].text = _generatedOtp[i];
    }
    setState(() {});
    _verifyOtpAndComplete();
  }

  Future<void> _verifyOtpAndComplete() async {
    final typed = _otpCtrls.map((c) => c.text.trim()).join();
    if (typed.length < 6) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan 6 digit Kode OTP terlebih dahulu')),
      );
      return;
    }

    if (typed != _generatedOtp) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: const Text('Kode OTP tidak sesuai, silakan periksa kembali'),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);
    try {
      final user = _pendingUser!;
      await ApiService.completeAuthenticatedSession(user);
      if (_pendingSheetId.trim().isNotEmpty) {
        await ApiService.saveSettings(
          webhookUrl: '',
          spreadsheetId: _pendingSheetId.trim(),
          tabName: 'Transaksi',
        );
      }
      if (mounted) widget.onAuthenticated();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitCredentials() async {
    setState(() => _isSubmitting = true);
    try {
      if (_mode == 'login') {
        final user = await ApiService.verifyCredentialsForOtp(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
        HapticFeedback.lightImpact();
        _startOtpFlow(user);
      } else {
        if (_nameCtrl.text.trim().isEmpty ||
            _emailCtrl.text.trim().isEmpty ||
            _passCtrl.text.length < 4) {
          throw Exception('Lengkapi Nama, Email, dan Password (min. 4 karakter)');
        }
        final newUser = await ApiService.register(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          spreadsheetId: _sheetIdCtrl.text.trim(),
        );
        await ApiService.logout();
        HapticFeedback.lightImpact();
        _startOtpFlow(newUser, sheetId: _sheetIdCtrl.text.trim());
      }
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

  Future<void> _showGoogleSignInSheet() async {
    HapticFeedback.selectionClick();
    final customEmailCtrl = TextEditingController();
    final customNameCtrl = TextEditingController();
    bool showCustomInput = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(22, 16, 22, 28 + bottomInset),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'G',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pilih Akun Google',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Untuk melanjutkan ke KeuanganKu + Verifikasi OTP',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._savedAccounts.map((acc) {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF2563EB),
                        child: Text(
                          acc.initials,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        acc.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      subtitle: Text(
                        acc.email,
                        style: const TextStyle(
                            fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                      trailing: const Icon(CupertinoIcons.chevron_right,
                          size: 16, color: Color(0xFF94A3B8)),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _startOtpFlow(acc);
                      },
                    );
                  }),
                  const Divider(),
                  if (!showCustomInput)
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFF1F5F9),
                        child: Icon(CupertinoIcons.person_add,
                            color: Color(0xFF0F172A), size: 18),
                      ),
                      title: const Text(
                        'Gunakan akun Google yang lain',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      onTap: () =>
                          setSheetState(() => showCustomInput = true),
                    )
                  else ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: customNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nama Akun Google',
                        hintText: 'Contoh: Yoga Setiawan',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: customEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Alamat Gmail (@gmail.com)',
                        hintText: 'nama@gmail.com',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final em = customEmailCtrl.text.trim();
                          if (em.isEmpty || !em.contains('@')) return;
                          final acc =
                              await ApiService.findOrCreateGoogleAccount(
                            email: em,
                            name: customNameCtrl.text.trim(),
                          );
                          await _loadSavedAccounts();
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          _startOtpFlow(acc);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Lanjutkan & Kirim Kode OTP',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
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
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isOtpStep
                          ? _buildOtpVerificationCard(
                              cardBg, textColor, mutedColor)
                          : _buildLoginRegisterCard(
                              cardBg, textColor, mutedColor),
                    ),
                  ),
                ),
              ),

              // Banner Notifikasi Kode OTP iOS (Auto-Fill 1 Klik)
              if (_isOtpStep)
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutBack,
                    builder: (context, val, child) {
                      return Transform.translate(
                        offset: Offset(0, -40 * (1 - val)),
                        child: Opacity(
                          opacity: val.clamp(0.0, 1.0),
                          child: child,
                        ),
                      );
                    },
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF1E293B).withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFF38BDF8)
                                  .withValues(alpha: 0.5),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  CupertinoIcons.shield_lefthalf_fill,
                                  color: Color(0xFF34D399),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'KeuanganKu Security • Sekarang',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Kode OTP Anda: $_generatedOtp',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _autoFillOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF38BDF8),
                                  foregroundColor: const Color(0xFF0F172A),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Isi Otomatis',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpVerificationCard(
      Color cardBg, Color textColor, Color mutedColor) {
    final email = _pendingUser?.email ?? '';

    return Container(
      key: const ValueKey('otp_card'),
      margin: const EdgeInsets.only(top: 64),
      padding: const EdgeInsets.all(24),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.envelope_badge_fill,
              color: Color(0xFF3B82F6),
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Verifikasi Kode OTP',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Masukkan 6 digit kode keamanan untuk akun\n$email',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: mutedColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (idx) {
              return SizedBox(
                width: 44,
                height: 54,
                child: TextField(
                  controller: _otpCtrls[idx],
                  focusNode: _otpFocusNodes[idx],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC)
                        .withValues(alpha: cardBg == Colors.white ? 1.0 : 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (val) {
                    if (val.isNotEmpty && idx < 5) {
                      _otpFocusNodes[idx + 1].requestFocus();
                    } else if (val.isEmpty && idx > 0) {
                      _otpFocusNodes[idx - 1].requestFocus();
                    }
                    if (idx == 5 && val.isNotEmpty) {
                      _verifyOtpAndComplete();
                    }
                  },
                ),
              );
            }),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _verifyOtpAndComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(CupertinoIcons.checkmark_shield_fill),
              label: Text(
                _isSubmitting ? 'Memverifikasi...' : 'Verifikasi & Masuk',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  _countdownTimer?.cancel();
                  setState(() => _isOtpStep = false);
                },
                icon: const Icon(CupertinoIcons.arrow_left, size: 15),
                label: const Text('Kembali'),
              ),
              TextButton(
                onPressed: _resendSeconds > 0
                    ? null
                    : () => _startOtpFlow(_pendingUser!,
                        sheetId: _pendingSheetId),
                child: Text(
                  _resendSeconds > 0
                      ? 'Kirim ulang (${_resendSeconds}d)'
                      : 'Kirim Ulang OTP',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginRegisterCard(
      Color cardBg, Color textColor, Color mutedColor) {
    return Column(
      key: const ValueKey('login_card'),
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
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    'register': Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('Daftar Akun',
                          style: TextStyle(fontWeight: FontWeight.w700)),
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
                  labelText:
                      _mode == 'login' ? 'Email atau Nama Akun' : 'Alamat Email',
                  hintText: 'yogasetiawan1499@gmail.com',
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
                    labelText: 'Spreadsheet ID Google Sheets (Opsional)',
                    hintText: 'Bisa diatur nanti di menu Sheets',
                    prefixIcon: const Icon(CupertinoIcons.table),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitCredentials,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(CupertinoIcons.lock_shield_fill),
                  label: Text(
                    _isSubmitting
                        ? 'Memproses...'
                        : (_mode == 'login'
                            ? 'Lanjut & Kirim Kode OTP'
                            : 'Daftar & Kirim Kode OTP'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Tombol Login via Google
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _showGoogleSignInSheet,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: mutedColor.withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Text(
                          'G',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Masuk dengan Akun Google',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
