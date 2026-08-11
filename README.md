# 📄 PDF Merge & Reader (Android, Windows, & Web)

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?style=for-the-badge&logo=windows&logoColor=white)
![Android](https://img.shields.io/badge/Android-5.0+-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![Web](https://img.shields.io/badge/Web-HTML5-E34F26?style=for-the-badge&logo=html5&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-purple?style=for-the-badge)

Aplikasi modern lintas platform (Android, Windows Desktop, dan Web) berbasis Flutter untuk **menggabungkan (merge) PDF**, **memotong/mengekstrak halaman spesifik**, **membaca dokumen dengan warna asli**, serta manajemen riwayat dokumen yang cepat & hemat ruang.

---

## 📥 Download Aplikasi Lintas Platform

Dapatkan rilis terbaru untuk sistem operasi kamu langsung dari **GitHub Releases**:

<p align="center">
  <a href="https://github.com/DeruDJ22/pdf_merge/releases/latest">
    <img src="https://img.shields.io/badge/Download-Android%20APK%20(%2eapk)-3DDC84?style=for-the-badge&logo=android&logoColor=white" height="50" alt="Download Android APK" />
  </a>
  &nbsp;&nbsp;
  <a href="https://github.com/DeruDJ22/pdf_merge/releases/latest">
    <img src="https://img.shields.io/badge/Download-Windows%20App%20(%2ezip)-0078D6?style=for-the-badge&logo=windows&logoColor=white" height="50" alt="Download Windows App" />
  </a>
</p>

---

## ✨ Fitur-Fitur Utama

- ✂️ **Potong / Ekstrak Halaman PDF**: Ambil rentang halaman tertentu (misal halaman 100 s/d 200 dari 400 halaman) dan simpan sebagai file PDF baru dengan cepat & presisi.
- 🖼️ **Pratinjau Sampul (Cover Thumbnail)**: Menampilkan gambar miniatur halaman pertama untuk setiap PDF di perpustakaan riwayat kamu.
- 📊 **Dashboard Stats & Sorting**: Bar statistik aktivitas membaca (Total, Selesai, Dibaca) dan opsi pengurutan riwayat (Terbaru, Nama, Ukuran, Progres).
- 🔗 **Merge Banyak PDF**: Gabungkan 2 atau lebih file PDF menjadi 1 file PDF baru berkecepatan tinggi di background thread (anti ANR).
- 📖 **Multi-Tab Reader Lintas Platform**: Buka & baca banyak file PDF secara bersamaan di Android, Windows, dan Web dengan warna asli & mode malam/terang.
- 🧹 **Zero Duplication & Sapu Cache**: Pembacaan file tanpa menduplikasi storage + tombol pembersih cache 1x klik.
- 📤 **Ekspor & Share**: Bagikan hasil potongan/gabungan PDF ke WhatsApp, Email, Telegram, atau aplikasi lainnya.

---

## 💻 Platform yang Didukung

| Platform | Format Distribusi | Status Integrasi |
| :--- | :--- | :--- |
| 🤖 **Android** | `.apk` (Release Key Permanent) | ✅ 100% Full Native Stream & Intent |
| 💻 **Windows** | `.zip` (Standalone Executable) | ✅ 100% Native Desktop Windows |
| 🌐 **Web** | Web Application | ✅ 100% Canvas & Pdfrx Renderer |

---

## 🚀 GitHub Actions CI/CD (Otomatisasi Build)

Repository ini dilengkapi dengan **GitHub Actions Matrix Workflow** (`.github/workflows/build.yml`). Setiap kali ada `push` ke branch `main`, GitHub akan **secara otomatis mem-build versi Android APK dan Windows Executable** lalu mengunggahnya ke GitHub Releases.

```bash
git add .
git commit -m "feat: add Windows desktop app support & documentation"
git push origin main
```

---

## 🛠️ Build Lokal (Manual)

### Windows Desktop:
```bash
flutter config --enable-windows-desktop
flutter pub get
flutter build windows --release
```
📁 Hasil build Windows: `build/windows/x64/runner/Release/`

### Android APK:
```bash
flutter build apk --release
```
📁 Hasil build Android: `build/app/outputs/flutter-apk/app-release.apk`

---

Developed with ❤️ for Android, Windows, & Web.
