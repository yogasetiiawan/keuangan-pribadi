import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onSettingsSaved;

  const SettingsScreen({super.key, required this.onSettingsSaved});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _serverUrlCtrl = TextEditingController();
  final TextEditingController _webhookUrlCtrl = TextEditingController();
  final TextEditingController _spreadsheetIdCtrl = TextEditingController();
  final TextEditingController _tabNameCtrl = TextEditingController(text: 'Transaksi');

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _serverUrlCtrl.text = ApiService.baseUrl;
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
    setState(() => _isSaving = true);
    try {
      await ApiService.setBaseUrl(_serverUrlCtrl.text);
      _serverUrlCtrl.text = ApiService.baseUrl;

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
        const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Text('Pengaturan Server & Google Sheets berhasil disimpan!'),
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

  Future<void> _syncAll() async {
    setState(() => _isSyncing = true);
    try {
      final res = await ApiService.syncToGoogleSheets();
      if (!mounted) return;
      final ok = res['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ok ? const Color(0xFF10B981) : Colors.orange.shade800,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator(radius: 15));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(CupertinoIcons.cloud_fill, color: Color(0xFF3B82F6)),
                  SizedBox(width: 8),
                  Text(
                    'Koneksi Backend Laravel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Jika membuka dari iPhone melalui Wi-Fi rumah/kantor yang sama, ganti localhost dengan IP Laptop Windows Anda (contoh: http://192.168.1.10:8000/api).',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _serverUrlCtrl,
                decoration: InputDecoration(
                  labelText: 'URL API Laravel',
                  hintText: 'http://192.168.1.10:8000/api',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(CupertinoIcons.table_fill, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text(
                    'Integrasi Google Sheets',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Opsi 1 (Rekomendasi & Tercepat): Tempel kode dari file google-sheets-connector/Code.gs ke menu Extensions > Apps Script di Google Sheet Anda, klik Deploy > Web App, lalu masukkan URL-nya di bawah ini:',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _webhookUrlCtrl,
                decoration: InputDecoration(
                  labelText: 'Google Apps Script Web App URL',
                  hintText: 'https://script.google.com/macros/s/.../exec',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Opsi 2 (Google Cloud Service Account REST API v4): Masukkan Spreadsheet ID jika Anda menggunakan file google-service-account.json di server Laravel:',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _spreadsheetIdCtrl,
                decoration: InputDecoration(
                  labelText: 'Spreadsheet ID (Opsional)',
                  hintText: '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tabNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Sheet / Tab',
                  hintText: 'Transaksi',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(CupertinoIcons.floppy_disk, size: 18),
                      label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Pengaturan'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSyncing ? null : _syncAll,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(CupertinoIcons.arrow_2_circlepath,
                          size: 18),
                      label: Text(_isSyncing ? 'Syncing...' : 'Sync Semua Data'),
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
