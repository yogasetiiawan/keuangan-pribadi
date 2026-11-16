import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onSettingsSaved;
  final VoidCallback onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.onSettingsSaved,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _webhookUrlCtrl = TextEditingController();
  final TextEditingController _spreadsheetIdCtrl = TextEditingController();
  final TextEditingController _tabNameCtrl =
      TextEditingController(text: 'Transaksi');

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSyncing = false;
  bool _isPulling = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final s = await ApiService.fetchSettings();
      if (mounted) {
        setState(() {
          _webhookUrlCtrl.text = s['google_sheets_webhook_url'] ?? '';
          _spreadsheetIdCtrl.text = s['google_sheets_spreadsheet_id'] ?? '';
          _tabNameCtrl.text = s['google_sheets_tab_name'] ?? 'Transaksi';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveAll() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);
    try {
      await ApiService.saveSettings(
        webhookUrl: _webhookUrlCtrl.text.trim(),
        spreadsheetId: _spreadsheetIdCtrl.text.trim(),
        tabName: _tabNameCtrl.text.trim().isEmpty
            ? 'Transaksi'
            : _tabNameCtrl.text.trim(),
      );

      if (!mounted) return;
      widget.onSettingsSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: const Color(0xFF10B981),
          content: const Text('✓ Pengaturan Google Sheets berhasil disimpan!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal menyimpan: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _syncAllPush() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSyncing = true);
    try {
      await ApiService.saveSettings(
        webhookUrl: _webhookUrlCtrl.text.trim(),
        spreadsheetId: _spreadsheetIdCtrl.text.trim(),
        tabName: _tabNameCtrl.text.trim().isEmpty
            ? 'Transaksi'
            : _tabNameCtrl.text.trim(),
      );
      final res = await ApiService.syncToGoogleSheets();
      if (!mounted) return;
      final ok = res['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor:
              ok ? const Color(0xFF10B981) : Colors.orange.shade800,
          content: Text((res['message'] ?? 'Sinkronisasi selesai').toString()),
        ),
      );
      widget.onSettingsSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal sinkronisasi: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _pullFromSheets() async {
    HapticFeedback.mediumImpact();
    setState(() => _isPulling = true);
    try {
      await ApiService.saveSettings(
        webhookUrl: _webhookUrlCtrl.text.trim(),
        spreadsheetId: _spreadsheetIdCtrl.text.trim(),
        tabName: _tabNameCtrl.text.trim().isEmpty
            ? 'Transaksi'
            : _tabNameCtrl.text.trim(),
      );
      final res = await ApiService.pullFromGoogleSheets();
      if (!mounted) return;
      final ok = res['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor:
              ok ? const Color(0xFF3B82F6) : Colors.orange.shade800,
          content: Text((res['message'] ?? 'Selesai menarik data').toString()),
        ),
      );
      widget.onSettingsSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal menarik data: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPulling = false);
    }
  }

  Future<void> _showPinSetupDialog() async {
    final pinCtrl = TextEditingController(text: ApiService.pinCode);
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Kunci Keamanan PIN (4 Digit)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Masukkan 4 angka PIN untuk mengunci aplikasi saat dibuka (kosongkan jika ingin menonaktifkan PIN):',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'PIN 4 Digit',
                  hintText: 'Contoh: 1234',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            if (ApiService.hasPin)
              TextButton(
                onPressed: () async {
                  await ApiService.setPinCode('');
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  setState(() {});
                },
                child: const Text('Hapus PIN',
                    style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final p = pinCtrl.text.trim();
                if (p.isNotEmpty && p.length != 4) return;
                await ApiService.setPinCode(p);
                if (ctx.mounted) Navigator.of(ctx).pop();
                setState(() {});
              },
              child: const Text('Simpan PIN'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator(radius: 15));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
      children: [
        // FITUR 4 & 5: Tampilan Mode Gelap, Sensor Saldo, & Kunci PIN
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.shield_fill,
                      color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Text(
                    'Tampilan & Keamanan Privasi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Mode Gelap (iOS Dark Mode)',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: textColor)),
                subtitle: Text('Tampilan gelap elegan & hemat baterai OLED',
                    style: TextStyle(fontSize: 12, color: mutedColor)),
                value: ApiService.isDarkMode,
                onChanged: (val) async {
                  HapticFeedback.selectionClick();
                  await ApiService.setDarkMode(val);
                  widget.onThemeChanged();
                  setState(() {});
                },
              ),
              Divider(color: borderColor),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Sensor Nominal Saldo (Privacy Mode)',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: textColor)),
                subtitle: Text('Sembunyikan angka saldo menjadi Rp ••••••••',
                    style: TextStyle(fontSize: 12, color: mutedColor)),
                value: ApiService.isBalanceHidden,
                onChanged: (val) async {
                  HapticFeedback.selectionClick();
                  await ApiService.setBalanceHidden(val);
                  widget.onSettingsSaved();
                  setState(() {});
                },
              ),
              Divider(color: borderColor),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Kunci Aplikasi dengan PIN 4 Digit',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: textColor)),
                subtitle: Text(
                  ApiService.hasPin
                      ? 'Status: PIN Aktif (••••)'
                      : 'Status: Belum Diaktifkan',
                  style: TextStyle(
                    fontSize: 12,
                    color: ApiService.hasPin
                        ? const Color(0xFF10B981)
                        : mutedColor,
                  ),
                ),
                trailing: OutlinedButton(
                  onPressed: _showPinSetupDialog,
                  child: Text(ApiService.hasPin ? 'Ubah PIN' : 'Pasang PIN'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // FITUR 3: Sinkronisasi 2 Arah Google Sheets (Push & Pull)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.table_fill,
                      color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text(
                    'Sinkronisasi 2 Arah Google Sheets',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Masukkan URL Web App Google Apps Script Anda untuk menyinkronkan data dari iPhone ke Google Sheets maupun sebaliknya:',
                style: TextStyle(fontSize: 12.5, color: mutedColor),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _webhookUrlCtrl,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Google Apps Script Web App URL',
                  hintText: 'https://script.google.com/macros/s/.../exec',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _spreadsheetIdCtrl,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Spreadsheet ID',
                  hintText: '1-k8FqqSIn_ZrOG7Cw5qFaau96o4j8XoKYPcPjaBy7dw',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tabNameCtrl,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Nama Sheet / Tab',
                  hintText: 'Transaksi',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(CupertinoIcons.floppy_disk, size: 18),
                  label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Pengaturan'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSyncing ? null : _syncAllPush,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(CupertinoIcons.cloud_upload, size: 17),
                      label: Text(
                        _isSyncing ? 'Mengirim...' : 'Kirim ke Sheets',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isPulling ? null : _pullFromSheets,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF3B82F6)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(CupertinoIcons.cloud_download, size: 17),
                      label: Text(
                        _isPulling ? 'Menarik...' : 'Tarik dari Sheets',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
