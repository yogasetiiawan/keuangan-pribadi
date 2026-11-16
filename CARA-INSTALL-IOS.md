# Panduan Install Aplikasi Native iOS (`.ipa`) ke iPhone dari Laptop Windows

Karena Apple mewajibkan proses *compile* iOS menggunakan macOS/Xcode, sedangkan laptop Anda menggunakan **Windows**, berikut adalah cara paling mudah dan **100% Gratis** menggunakan **GitHub Actions (Cloud Mac)** + **Sideloadly (Installer Windows ke iPhone)**.

---

## Keunggulan yang Sudah Disiapkan di Kode Flutter Anda
1. **Bisa Dipakai Offline / Di Luar Rumah:** Kode di `mobile_flutter/lib/services/api_service.dart` sudah di-upgrade menjadi **Hybrid**. Artinya:
   - Saat di rumah (terhubung ke Wi-Fi laptop `192.168.31.156`), aplikasi terhubung ke **Backend Laravel**.
   - Saat di luar rumah / laptop mati, aplikasi **tetap berjalan normal 100%** menggunakan penyimpanan internal iPhone dan **bisa langsung sinkron ke Google Sheets** menggunakan kuota data HP Anda!
2. **Auto-Build File `.ipa`:** Sudah disiapkan file `.github/workflows/build-ios-ipa.yml` yang otomatis merakit file **`KeuanganPribadi-iOS.ipa`** di server Mac milik GitHub.

---

## Langkah 1: Dapatkan File `KeuanganPribadi-iOS.ipa` (Gratis via GitHub)

1. Buat akun di [GitHub.com](https://github.com) (jika belum punya) dan buat **New Repository** (misalnya `keuangan-pribadi`).
2. Upload isi folder `C:\Users\User\.gemini\antigravity\scratch\keuangan-pribadi` ke repository GitHub tersebut:
   ```powershell
   cd C:\Users\User\.gemini\antigravity\scratch\keuangan-pribadi
   git init
   git add .
   git commit -m "Initial commit aplikasi keuangan iOS"
   git branch -M main
   git remote add origin https://github.com/USERNAME_ANDA/keuangan-pribadi.git
   git push -u origin main
   ```
3. Buka halaman repository GitHub Anda di browser -> klik tab **Actions**.
4. Anda akan melihat proses **"Build File IPA iOS (Tanpa Mac)"** sedang berjalan otomatis (sekitar 3–5 menit).
5. Setelah centang hijau ✅, klik proses tersebut, gulir ke bagian paling bawah (**Artifacts**), lalu klik **`KeuanganPribadi-iOS-IPA`** untuk men-download file `.zip` yang berisi **`KeuanganPribadi-iOS.ipa`** (ekstrak dulu file `.zip`-nya sehingga muncul file `.ipa`).

---

## Langkah 2: Install File `.ipa` dari Laptop Windows ke iPhone (via Sideloadly)

1. Di laptop Windows Anda, pastikan sudah terpasang **iTunes** dan **iCloud** (versi non-Microsoft Store, tersedia di halaman Sideloadly).
2. Download dan install aplikasi gratis **[Sideloadly](https://sideloadly.io/)** untuk Windows.
3. Hubungkan **iPhone ke Laptop Windows** menggunakan kabel data USB (ketuk **Trust / Percayai Komputer Ini** di layar iPhone jika muncul).
4. Buka aplikasi **Sideloadly** di Windows:
   - Pastikan nama iPhone Anda muncul di kolom **iDevice**.
   - Masukkan alamat email **Apple ID** Anda di kolom **Apple account**.
   - Klik kotak ikon **IPA** di sebelah kiri, lalu pilih file **`KeuanganPribadi-iOS.ipa`** yang sudah di-download dari GitHub tadi.
   - Klik tombol **Start** (masukkan password Apple ID & kode OTP 6 digit jika diminta pertama kali).
5. Tunggu hingga muncul tulisan **Done!** — Ikon aplikasi **KeuanganKu** akan langsung muncul di layar utama iPhone Anda!

---

## Langkah 3: Izinkan Aplikasi di Pengaturan iPhone (Hanya Sekali)

Karena di-install tanpa melalui App Store berbayar, lakukan izin sekali saja di iPhone Anda:
1. Buka **Settings (Pengaturan) > General (Umum) > VPN & Device Management (Manajemen Perangkat)**.
2. Ketuk email **Apple ID** Anda di bawah bagian *Developer App*, lalu ketuk **Trust (Percayai)**.
3. *(Khusus iOS 16 ke atas)* Buka **Settings > Privacy & Security**, gulir ke paling bawah, aktifkan **Developer Mode**, lalu *restart* iPhone dan ketuk **Turn On**.
4. Sekarang aplikasi **KeuanganKu** bisa langsung dibuka kapan saja dari iPhone Anda tanpa melalui Safari!
