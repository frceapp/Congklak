# Congklak (Mancala Pixel)

[![CI](https://github.com/frceapp/Congklak/actions/workflows/ci.yml/badge.svg)](https://github.com/frceapp/Congklak/actions/workflows/ci.yml)
![Godot Engine](https://img.shields.io/badge/Godot-v4.7.2-478cbf?logo=godot-engine&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Desktop-green)
![Target](https://img.shields.io/badge/Package-com.mancala.lim-orange)

Game papan biji bergaya seni piksel retro (*pixel art*) dengan aturan Mancala modern untuk platform **Android** (orientasi landscape) dan desktop, dikembangkan menggunakan **Godot Engine 4.7.2** (GDScript, GL Compatibility renderer).

---

## 🎮 Fitur Permainan

- **Aturan Mancala Modern**:
  - Sebar biji searah jarum jam satu putaran tanpa estafet.
  - Giliran tambahan (*extra turn*) bila biji terakhir masuk ke lumbung (*store*) sendiri.
  - Mekanisme **Tembak** (*Capture*): jika biji terakhir jatuh di lubang kosong di sisi sendiri dan lubang seberang milik lawan memiliki biji, seluruh biji lawan beserta biji penembak masuk ke lumbung pemain.
  - Penyelesaian otomatis (*Sweep*): saat salah satu baris kosong, seluruh sisa biji di baris lawan dikumpulkan ke lumbung pemilik baris.
- **Konfigurasi Papan Fleksibel**:
  - Ukuran lubang dapat diatur: **3 hingga 10 lubang** per baris.
  - Jumlah biji awal: **2 hingga 12 biji** per lubang.
  - Pengaturan tersimpan secara otomatis di `user://settings.cfg`.
- **Mode Permainan**:
  - **1 Pemain (vs Komputer / AI)**: Menggunakan algoritma Minimax Alpha-Beta dengan 3 tingkat kecerdasan (Mudah, Sedang, Sulit) yang berjalan pada background thread tanpa membuat UI tersendat.
  - **2 Pemain (Berhadapan di 1 Perangkat)**: Pemain duduk berhadapan langsung; elemen pemain atas (nama, angka, potret karakter, dan cut-in jurus) otomatis diputar 180°.
- **Karakter & Estetika Visual**:
  - Karakter bawaan: **Frieren** dan **Maomao** dengan sprite berdiri 64×96 piksel.
  - Latar belakang panorama pemandangan piksel 640×360 yang unik dan dinamis per karakter (*Ruins & Blue Flowers* untuk Frieren, *Pavilion & Herbal Garden* untuk Maomao).
  - Efek cut-in jurus kosmetik saat giliran ekstra atau tembakan berhasil.
  - Animasi jurus pamungkas pemenang di akhir permainan (pemutaran klip video OGV selayar penuh + efek lubang hitam / asap racun).
- **Pixel-Perfect Rendering**:
  - Resolusi native **640×360** dengan penskalaan *nearest-neighbor* integer viewport.
  - Font piksel kustom (BMFont dengan baseline yang mendukung ekor huruf g, j, p, q, y).
  - Pilihan kecepatan animasi tangan dan sebar biji (Normal, Cepat, Kilat).
- **Audio Prosedural**:
  - Suara sintetis dinamis dibangkitkan sepenuhnya lewat kode (`scripts/sfx.gd`) tanpa beban berkas audio eksternal.

---

## 📁 Struktur Direktori

```text
Congklak/
├── .github/
│   └── workflows/
│       └── ci.yml               # GitHub Actions CI (Automated Testing)
├── assets/
│   ├── characters/              # Tempat kustom sprite karakter (PNG/WebP 64x96)
│   ├── fonts/                   # BMFont piksel hasil bangkitan (pixel.fnt, pixel.png)
│   └── scene/                   # Video jurus pamungkas (*_ult.ogv)
├── scenes/
│   ├── menu.tscn                # Scene menu utama
│   ├── character_select.tscn    # Scene pemilihan karakter
│   └── game.tscn                # Scene papan permainan
├── scripts/
│   ├── congklak_logic.gd        # Logika inti permainan & pencatat event animasi
│   ├── ai.gd                    # Minimax Alpha-Beta AI
│   ├── board.gd                 # Visual papan, sprite, input sentuh, dan animasi
│   ├── game.gd                  # Controller alur permainan (turn management, hasil)
│   ├── game_config.gd           # Konfigurasi global & state antar-scene
│   ├── characters.gd            # Data karakter, tema latar, dan jurus
│   ├── portrait.gd              # Rasterizer sprite karakter 64x96
│   ├── scenery.gd               # Pembangkit panorama latar piksel
│   ├── skill_fx.gd              # Efek visual cut-in jurus dan stun
│   ├── ultimate.gd              # Pemutar video dan efek pamungkas pemenang
│   ├── ui.gd                    # Komponen UI 9-slice dan layout responsif
│   └── sfx.gd                   # Generator audio sintetis
├── tests/
│   ├── test_logic.gd            # Uji logika aturan & evaluasi AI (headless)
│   └── screenshot.gd            # Skrip otomatis simulasi permainan & tangkapan layar
├── tools/
│   └── make_pixel_font.gd       # Generator font piksel BMFont
├── export_presets.cfg           # Konfigurasi ekspor Android
└── project.godot                # Konfigurasi proyek Godot 4.7.2
```

---

## 🛠️ Persyaratan Sistem

- **Godot Engine 4.7.2** (Standard / GDScript)
- **Android SDK & Build Tools** (untuk ekspor APK)
- **FFmpeg** (opsional, jika ingin mengonversi video jurus pamungkas ke format `.ogv` Theora)

---

## 🧪 Pengujian & Passing Check

Proyek ini telah dilengkapi dengan unit test otomatis untuk memvalidasi kepatuhan aturan Mancala, simulasi permainan acak, dan performa kecerdasan buatan (AI).

### 1. Menjalankan Uji Logika & AI (Headless)

Jalankan perintah berikut di terminal:

```bash
godot --headless --path . --script res://tests/test_logic.gd
```

Uji ini mencakup:
- Status awal papan (total 98 biji pada papan standar 7×7).
- Validasi giliran tambahan (*extra turn* di lumbung sendiri).
- Validasi tembak (*capture* lubang seberang lawan).
- Validasi lubang kosong di sisi lawan (tidak boleh menembak).
- Validasi tanpa estafet (*no relay*).
- Validasi *skip* lumbung lawan.
- Kondisi selesai dan langkah *sweep*.
- Variasi ukuran papan kustom (3×2, 4×12, 10×12, 5×5, 10×2).
- Playout simulasi acak ratusan giliran.
- Performa & winrate AI tingkat Sulit vs langkah acak (20/20 menang).

### 2. Continuous Integration (CI)

Setiap `push` dan `pull request` ke repositori akan otomatis memicu GitHub Actions workflow di [`.github/workflows/ci.yml`](.github/workflows/ci.yml). Workflow ini:
1. Memasang lingkungan headless Godot 4.7.2 pada Ubuntu runner.
2. Mengeksekusi seluruh pengujian di `tests/test_logic.gd`.
3. Memastikan status build berstatus **Passing Check** (hijau).

---

## 🚀 Kompilasi & Pemasangan

### Ekspor APK Android (Debug)

Pastikan Android SDK dan export template Godot 4.7.2 sudah terpasang:

```bash
godot --headless --path . --export-debug "Android" build/congklak.apk
```

### Memasang ke Perangkat Android via ADB

Hubungkan perangkat Android melalui USB Debugging atau Wi-Fi ADB:

```bash
adb install -r build/congklak.apk
```

---

## 🎨 Menyesuaikan Karakter & Video

- **Sprite Karakter**: Masukkan gambar PNG/WebP transparan ke dalam folder `assets/characters/` dengan nama `frieren.png` atau `maomao.png`. Game akan otomatis menyesuaikan ukuran ke rasio 64×96.
- **Video Jurus Pamungkas**: Godot memutar video format Ogg Theora. Konversi video MP4 dengan parameter keyframe penuh (`-g:v 1`):
  ```bash
  ffmpeg -i input.mp4 -vf scale=640:360 -c:v libtheora -q:v 6 -g:v 1 -c:a libvorbis -q:a 4 assets/scene/<id>_ult.ogv
  ```

---

## 📜 Lisensi & Catatan

- Proyek ini ditujukan untuk pembelajaran dan penggunaan pribadi.
- Aset video dan karakter terinspirasi dari karya anime terkait dan tetap merupakan hak cipta dari masing-masing pemilik hak cipta.
