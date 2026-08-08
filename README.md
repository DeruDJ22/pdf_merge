# 📄 PDF Merge & Reader (Android)

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Android](https://img.shields.io/badge/Android-5.0+-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-purple?style=for-the-badge)

Aplikasi Android modern berbasis Flutter untuk **menggabungkan (merge) beberapa file PDF menjadi 1 file** dan **membaca dokumen PDF dengan warna asli** serta dukungan penuh integrasi File Manager Android.

---

## 📥 Download Aplikasi (.apk)

Dapatkan file `.apk` siap install langsung dari GitHub Releases:

<p align="center">
  <a href="https://github.com/DeruDJ22/pdf_merge/releases/latest">
    <img src="https://img.shields.io/badge/Download-Latest%20APK-6C63FF?style=for-the-badge&logo=android&logoColor=white" height="50" alt="Download APK" />
  </a>
</p>

---

## ✨ Fitur Utama

- 🔗 **Merge Banyak PDF**: Gabungkan 2 atau lebih file PDF menjadi 1 file PDF baru berkecepatan tinggi menggunakan Native Android `PdfDocument` API.
- 🔀 **Modal Dialog Pilihan Aksi**: Saat memilih/membuka file PDF, muncul pilihan:
  - 📖 **Baca PDF Ini**: Buka tampilan membaca langsung.
  - 🔗 **Tambahkan ke Merge**: Masukkan file ke antrean penggabungan.
- 🖐️ **Drag & Drop Reorder**: Geser dan atur urutan file PDF sebelum digabungkan.
- 🎨 **Tampilan Warna Asli**: PDF ditampilkan dengan presisi warna asli (bebas bug warna terbalik/inversi).
- ☀️/🌙 **Toggle Mode Gelap/Terang**: Bebas ganti mode tampilan membaca kapan saja.
- 📱 **Dukungan Penuh File Manager Android**: Muncul di opsi *"Buka dengan..."* (Open With) pada semua File Manager (Xiaomi/Miui, Samsung My Files, Files by Google, Oppo, dll).
- 📂 **Multi-File Queue**: Buka banyak PDF secara fleksibel tanpa menutup file sebelumnya.
- 📤 **Share Langsung**: Bagikan hasil gabungan PDF ke WhatsApp, Telegram, Email, atau aplikasi lainnya.

---

## 🏗️ Alur Penggunaan

```
File Manager / App ➔ [ Pilih PDF ] ➔ Modal Sheet ➔ ┬➔ [ 📖 Baca PDF ] ➔ Reader (Warna Asli)
                                                  └➔ [ 🔗 Tambahkan ke Merge ] ➔ Drag & Drop ➔ Export PDF
```

---

## 🚀 Otomatisasi Release (GitHub Actions)

Proyek ini sudah dikonfigurasi dengan **GitHub Actions CI/CD** (`.github/workflows/build.yml`). Setiap kali kamu melakukan `push` ke branch `main`, GitHub akan **otomatis mem-build file APK rilis** dan mempublikasikannya ke halaman **Releases**.

### Perintah Push ke GitHub:

```bash
git add .
git commit -m "feat: update PDF Merge & Reader"
git push origin main
```

---

## 🛠️ Build APK Lokal (Manual)

Jika ingin mem-build APK di komputer sendiri:

```bash
# Get dependencies
flutter pub get

# Build Release APK
flutter build apk --release
```

File APK tersimpan di:  
📁 `build/app/outputs/flutter-apk/app-release.apk`

---

## 💻 Teknologi & Spesifikasi

- **Framework**: Flutter (Dart)
- **Engine Native**: Kotlin (`android.graphics.pdf.PdfDocument` & `PdfRenderer`)
- **Min SDK**: Android 21 (Lollipop 5.0+)
- **Target SDK**: Android 34 / Latest
- **Desain UI**: Material 3 Dark Glassmorphism, Google Fonts (Inter)

---

Developed with ❤️ for Android.
