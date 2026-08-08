# 📄 PDF Merge & Viewer (Android)

Aplikasi Android berbasis Flutter untuk **menggabungkan (merge) beberapa file PDF menjadi 1 file** serta **membaca banyak file PDF sekaligus** tanpa menutup file sebelumnya.

---

## 📥 Download Aplikasi (.apk)

Kamu bisa mendownload file `.apk` siap install melalui tautan di bawah ini:

| Versi | Download Link | Status |
|-------|---------------|--------|
| **Latest Release (APK)** | [![Download APK](https://img.shields.io/badge/Download-APK-6C63FF?style=for-the-badge&logo=android&logoColor=white)](https://github.com/DeruDJ22/pdf_merge/releases/latest) | `v1.0.0` |

*(Catatan: Ganti `USERNAME/REPO_NAME` pada URL di atas dengan nama username & repository GitHub kamu)*

---

## ✨ Fitur Utama

- 🔗 **Merge Banyak PDF**: Gabungkan 2 atau lebih file PDF menjadi 1 file PDF baru.
- 🖐️ **Drag & Drop Reorder**: Ubah urutan halaman PDF dengan mudah sebelum digabungkan.
- 📱 **Integrasi Intent Android**: Buka PDF langsung dari File Manager HP. Aplikasi akan otomatis muncul di opsi *"Buka dengan..."* atau *"Share ke..."*.
- 📂 **Multi-File Viewer**: Buka banyak file PDF secara berurutan tanpa menutup file sebelumnya.
- 🌙 **Night Mode PDF Viewer**: Mode gelap otomatis saat membaca PDF agar nyaman di mata.
- 📤 **Share Langsung**: Bagikan hasil merge atau file PDF langsung dari aplikasi.

---

## 🚀 Cara Otomatis (Via GitHub Actions)

Proyek ini sudah dilengkapi dengan **GitHub Actions Workflow** (`.github/workflows/build.yml`). 

Setiap kali kamu mem-push kode ke GitHub atau membuat tag release (`v1.0.0`), GitHub akan **otomatis me-render & membuatkan file `.apk`** di menu **Releases / Actions** repository kamu!

### Langkah Push ke GitHub:

```bash
git init
git add .
git commit -m "feat: PDF Merge & Viewer App v1.0.0"
git branch -M main
git remote add origin https://github.com/DeruDJ22/pdf_merge.git
git push -u origin main
```

Untuk membuat **Release Resmi** dengan tombol download otomatis:
```bash
git tag v1.0.0
git push origin v1.0.0
```

---

## 🛠️ Cara Manual (Build APK di Lokal)

Jika ingin mem-build APK secara manual di komputer kamu:

1. Pastikan Flutter SDK sudah terinstall.
2. Jalankan perintah build:
   ```bash
   flutter build apk --release
   ```
3. File APK akan dihasilkan di lokasi:
   `build/app/outputs/flutter-apk/app-release.apk`

---

## 💻 Spesifikasi Teknis

- **Framework**: Flutter 3.x (Dart)
- **Min SDK**: Android 21 (Android 5.0 Lollipop+)
- **Target SDK**: Android 34 / Latest
- **Native API**: Android `PdfDocument` & `PdfRenderer`
- **UI Theme**: Material 3 Dark Theme dengan Google Fonts Inter

---

Developed with ❤️ using Flutter & Android Native APIs.
