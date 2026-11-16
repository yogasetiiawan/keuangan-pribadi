# Aplikasi Pencatatan Keuangan Pribadi (Flutter iOS/PWA + Laravel + Google Sheets)

Proyek ini terdiri dari 3 komponen utama yang sudah saling terintegrasi:
1. **`backend-laravel/`** — REST API Backend berbasis Laravel + Database SQLite (otomatis siap pakai tanpa setup MySQL) + Service Sinkronisasi Otomatis ke Google Sheets.
2. **`mobile_flutter/`** — Aplikasi Mobile & Web menggunakan Flutter dengan desain bergaya **iOS / Cupertino** (Dashboard Saldo, Grafik Tren 6 Bulan, Grafik Donut Kategori, Pencatatan Pemasukan & Pengeluaran, serta Pengaturan Google Sheets).
3. **`google-sheets-connector/Code.gs`** — Script konektor Google Sheets (Apps Script) agar setiap transaksi di aplikasi otomatis tercatat rapi ke dalam Google Sheet Anda.

---

## Cara Cepat Menjalankan di Windows & iPhone (iOS)

### 1. Jalankan Server Backend Laravel
Klik dua kali file **`jalankan-server.bat`** atau jalankan perintah berikut di terminal:
```powershell
cd C:\Users\User\.gemini\antigravity\scratch\keuangan-pribadi\backend-laravel
php -S 0.0.0.0:8000 -t public
```
Database SQLite (`database/database.sqlite`) beserta kategori awal dan contoh transaksi akan otomatis dibuat saat pertama kali dijalankan.

### 2. Buka di iPhone (iOS) atau Flutter
Karena PC Anda menggunakan Windows, Anda memiliki **2 cara mudah** untuk menggunakannya di iPhone:

- **Cara Instan (iOS Safari Add to Home Screen / PWA - Tanpa perlu Mac):**
  1. Pastikan iPhone dan PC Windows terhubung ke Wi-Fi yang sama.
  2. Cek IP Wi-Fi PC Windows Anda (jalankan `ipconfig` di CMD, contoh: `192.168.1.10`).
  3. Buka **Safari** di iPhone, lalu kunjungi `http://192.168.1.10:8000/app`.
  4. Ketuk tombol **Share (Bagikan)** di Safari -> pilih **Add to Home Screen (Tambahkan ke Layar Utama)**. Aplikasi akan tampil layar penuh layaknya aplikasi native iOS!

- **Cara Flutter Native / Web (`mobile_flutter/`):**
  1. Untuk menjalankan via Flutter di PC:
     ```powershell
     cd C:\Users\User\.gemini\antigravity\scratch\keuangan-pribadi\mobile_flutter
     flutter pub get
     flutter run -d chrome
     ```
  2. Untuk mem-build file `.ipa` iOS tanpa Mac, gunakan file **`mobile_flutter/codemagic.yaml`** yang sudah disediakan dengan menghubungkan repositori ke [Codemagic.io](https://codemagic.io).

---

## Cara Menghubungkan ke Google Sheets (Hanya 2 Menit)

1. Buka [Google Sheets](https://sheets.new) dan buat spreadsheet baru.
2. Klik menu **Extensions (Ekstensi)** -> **Apps Script**.
3. Hapus kode bawaan, lalu salin dan tempel seluruh isi file [`google-sheets-connector/Code.gs`](./google-sheets-connector/Code.gs).
4. Klik tombol **Deploy (Terapkan)** -> **New deployment (Deployment baru)**:
   - Pilih jenis: **Web app**
   - *Execute as*: **Me (Saya)**
   - *Who has access*: **Anyone (Siapa saja)**
5. Klik **Deploy**, berikan izin akses, lalu salin **Web App URL** (`https://script.google.com/macros/s/.../exec`).
6. Buka aplikasi Keuangan Pribadi -> masuk ke tab **Sheets / Pengaturan** -> tempelkan URL tersebut pada kolom **Google Apps Script Web App URL** -> klik **Simpan Pengaturan**.
7. Klik **Sync Semua Data**. Sheet **`Transaksi`** dan **`Ringkasan`** akan otomatis terbuat dan terisi di Google Sheets Anda!
