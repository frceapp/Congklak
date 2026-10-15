# Congklak — catatan untuk agen

Game papan biji bergaya piksel dengan aturan mancala (awalnya congklak), dibuat dengan **Godot 4.7.2** (GDScript, renderer GL Compatibility), target **Android** landscape. Nama paket: `com.mancala.lim`.

Terakhir diperbarui: 2026-10-13.

## Status saat ini

Gaya piksel, karakter besar di sisi papan, mode 2 pemain berhadapan, dan aturan mancala **sudah jadi dan diuji di desktop**. Tampilannya di ponsel belum diperiksa.

### Sudah jadi dan sudah diuji di desktop

- **Aturan mancala** (`scripts/congklak_logic.gd`), diganti dari aturan congklak atas permintaan pemilik proyek (2026-10-13): satu lubang disebar sekali per giliran searah jarum jam, **tanpa estafet** (biji terakhir yang jatuh di lubang berisi tidak diambil lagi). Main lagi bila biji terakhir masuk lumbung sendiri; "tembak" bila jatuh di lubang kosong sisi sendiri yang seberangnya berisi. Permainan selesai begitu salah satu baris kosong, dan sisa biji di baris lain masuk ke lumbung pemilik baris itu (langkah `sweep`).
- **Papan kustom**: 3–10 lubang per baris, 2–12 biji per lubang, diatur di menu dan tersimpan di `user://settings.cfg`.
- **Lawan komputer** (`scripts/ai.gd`): minimax alpha-beta, tiga tingkat (Mudah / Sedang / Sulit), berjalan di thread terpisah.
- **Mode 2 pemain** di satu perangkat, duduk berhadapan: sisi papan tiap pemain memakai warna karakternya (`board` di `characters.gd`), dan milik pemain atas (karakter, nama, angka, cut-in jurus) diputar 180 derajat.
- **Pilih karakter** sebelum tiap permainan: Frieren dan Maomao (Himmel dihapus atas permintaan pemilik proyek). Di mode 2 pemain, kartu pilihan Pemain 1 ditandai dan dikunci, lalu Pemain 2 memilih dari karakter yang tersisa (dua pemain tidak bisa memakai karakter yang sama). Jurus murni hiasan (tidak mengubah aturan): jurus *stun* dengan cut-in saat pemain main lagi, jurus serangan singkat saat menembak. Tiap karakter punya panorama latarnya sendiri (`scenery.gd`): Frieren (reruntuhan dan bunga biru), Maomao (paviliun dan taman herbal).
- **Karakter besar**: sprite berdiri 64×96 (`portrait.gd`) tampil di kiri papan (pemain bawah) dan kanan papan (pemain atas), diperbesar 2× di layar selebar 700 piksel ke atas (rasio ponsel) dan 1× di layar sempit. Cut-in jurus dan panel hasil memakai potongan dada sprite itu.
- **Jurus pamungkas pemenang** (`scripts/ultimate.gd`, hiasan): di akhir permainan, sebelum panel hasil, video milik karakter pemenang diputar sekali (`assets/scene/<id>_ult.ogv`; ketukan melewatinya; seri = tanpa video), lalu efek penutup menurut `style` karakternya: `magic` = lubang hitam di tengah papan yang melahap semua biji, `potion` = asap racun yang memenuhi layar dan menetap di belakang panel hasil. Di mode berhadapan, video pemain atas diputar 180 derajat.
- **Animasi sebar**: satu Tween per giliran, tangan meluncur dengan kecepatan tetap, biji melayang ke tempatnya, tiga laju (Normal / Cepat / Kilat).
- **Suara** dibangkitkan lewat kode (`scripts/sfx.gd`), tanpa berkas audio.
- **Gaya piksel**: render 640×360 diperbesar tanpa penghalusan, font piksel (dengan ekor huruf g, j, p, q, y), sprite biji/lubang/cincin/tangan, sprite karakter berdiri 64×96, latar panorama lingkungan pemandangan piksel 640×360 non-repetitif, kotak UI 9-iris, efek jurus piksel. Dilihat lewat tangkapan layar di 800×360 (papan 7×7, lawan komputer dan 2 pemain) dan 640×360 (papan 10×5); permainan penuh selesai tanpa error di ketiganya.
- **Uji aturan dan AI** lulus pada kondisi ini.

### Belum diverifikasi

1. **Tampilan gaya piksel di ponsel belum diperiksa.** APK terpasang, tapi belum dibuka dan dilihat di perangkat (termasuk margin aman di sekitar lubang kamera pada resolusi baru).
2. **Performa di ponsel belum diukur ulang.** Sebelum perbaikan, layar permainan hanya ~15 FPS di Pixel 6 (menu 60 FPS). Penyebabnya ratusan poligon dibangun ulang tiap frame; sekarang papan digambar sekali, biji memakai tekstur, dan render di resolusi rendah, tapi angka FPS barunya belum diketahui.
3. **Suara belum pernah didengar** oleh siapa pun yang mengujinya lewat skrip.
4. **Di layar sempit (640 piksel) karakter tetap kecil** (1×), karena memperbesarnya membuat papan terlalu sempit.

### Hal yang perlu diketahui

- Fitur combo pernah ada dan sudah dihapus atas permintaan pemilik proyek (2026-10-13); jangan ditambahkan lagi tanpa diminta.
- Video jurus pamungkas di `assets/scene/` disediakan pemilik proyek dan merupakan cuplikan anime berhak cipta: hanya untuk pemakaian pribadi, harus diganti sebelum game dibagikan atau dirilis. Berkas `.mp4` adalah sumbernya (tidak ikut diekspor); yang dipakai game adalah `.ogv` hasil konversi.
- Godot hanya memutar video Ogg Theora. Konversi video baru dengan: `ffmpeg -i <nama>.mp4 -vf scale=640:360 -c:v libtheora -q:v 6 -g:v 1 -c:a libvorbis -q:a 4 <id>_ult.ogv` (ffmpeg ada di `C:\ffmpeg\bin`). **`-g:v 1` wajib** (semua frame keyframe): encoder Theora di ffmpeg komputer ini menghasilkan frame antar-keyframe yang rusak, sehingga video tampil sebagai blok warna acak di Godot dan di ponsel. Periksa hasilnya dengan `ffmpeg -v error -i <berkas>.ogv -f null -` (harus tanpa keluaran) dan lihat gambarnya, jangan hanya memeriksa bahwa video "diputar".
- Potret karakter digambar lewat kode, bukan gambar resmi anime. Nama dan rupa karakter tetap milik pemegang haknya: aman untuk pemakaian pribadi, perlu lisensi atau diganti bila dirilis ke Play Store.
- Pencarian model 3D berlisensi bebas untuk ketiga karakter tidak menemukan yang bisa dipakai.
- Belum ada repositori git.

## Struktur

| Berkas | Isi |
|---|---|
| `scripts/congklak_logic.gd` | Aturan murni, tanpa tampilan. Mencatat langkah (`pickup` / `drop` / `capture` / `sweep`) untuk animasi. |
| `scripts/ai.gd` | Lawan komputer. |
| `scripts/game_config.gd` | Pilihan pemain (mode, tingkat, suara, laju, ukuran papan, karakter) sebagai `static var`. |
| `scripts/ui.gd` | Pembuat tombol, label, kotak piksel 9-iris, latar panorama, margin aman. |
| `scripts/scenery.gd` | Pembangkit panorama pemandangan seni piksel 640×360 unik per karakter (non-repetitif). |
| `scripts/board.gd` | Papan: tata letak, sprite, sentuhan, animasi sebar, dan penempatan karakter di kiri-kanan papan. |
| `scripts/portrait.gd` | Sprite karakter berdiri 64×96 yang dirasterkan lewat kode (atau dari gambar milik sendiri); bisa menampilkan potongan dada (`crop_rows`). |
| `scripts/characters.gd` | Daftar karakter, tema latar, dan nama jurusnya. |
| `scripts/skill_fx.gd` | Efek jurus (cut-in, proyektil, stun). Anak dari papan. |
| `scripts/ultimate.gd` | Jurus pamungkas pemenang: pemutar video selayar penuh, lalu efek lubang hitam atau asap racun. |
| `scripts/game.gd` | Layar permainan: giliran, AI, hasil. |
| `scripts/menu.gd`, `scripts/character_select.gd` | Menu utama dan layar pilih karakter. |
| `scripts/sfx.gd` | Efek suara sintetis. |
| `scenes/*.tscn` | Tiga scene tipis (menu, character_select, game); seluruh UI dibangun lewat kode. |
| `tools/make_pixel_font.gd` | Pembangkit font piksel (BMFont). |
| `tests/test_logic.gd` | Uji aturan dan AI (headless). |
| `tests/screenshot.gd` | Memainkan satu permainan penuh otomatis sambil menyimpan tangkapan layar. |
| `assets/fonts/` | Font piksel hasil bangkitan. |
| `assets/scene/` | Video jurus pamungkas: `<id>_ult.ogv` (dipakai game) dan `<id>_ult.mp4` (sumber, dikecualikan dari ekspor). |
| `assets/characters/` | Kosong. Taruh `frieren.png` atau `maomao.png` (juga `.webp` / `.jpg`) untuk mengganti sprite bawaan; otomatis dikecilkan ke 64×96 (rasio 2:3, sebaiknya berlatar transparan). |

Alur scene: `menu` → `character_select` → `game`.

## Perintah

Godot ada di PATH sebagai `godot`; untuk keluaran konsol pakai `Godot_v4.7.2-stable_win64_console.exe` di folder WinGet (`%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_...`). Semua perintah dijalankan dari akar proyek.

Uji aturan dan AI:

```bash
godot --headless --path . --script res://tests/test_logic.gd
```

Permainan penuh otomatis dengan tangkapan layar (butuh jendela, tidak bisa headless). Argumen: folder keluaran, lalu opsional jumlah lubang dan biji, lalu `2p` untuk mode 2 pemain. Tambahkan `--resolution 1600x720` sebelum `--script` untuk meniru layar ponsel (800×360):

```bash
godot --path . --script res://tests/screenshot.gd -- C:/temp/shots 7 7
```

Membangkitkan font, lalu mengimpor ulang:

```bash
godot --headless --path . --script res://tools/make_pixel_font.gd
```

```bash
godot --headless --path . --import
```

Setelah impor, pastikan `assets/fonts/pixel.fnt.import` berisi `scaling_mode=1` (hanya skala bulat).

Ekspor APK debug:

```bash
godot --headless --path . --export-debug "Android" build/congklak.apk
```

Pasang ke ponsel (Pixel 6 lewat adb nirkabel; SDK di `C:\Android\Sdk`):

```bash
"C:/Android/Sdk/platform-tools/adb.exe" install -r build/congklak.apk
```

Bila `adb devices` kosong setelah daemon mulai ulang, tunggu beberapa detik atau `adb connect` ke alamat ponsel. Bila ponsel muncul dua kali, pakai `-s <serial>`.

Template ekspor yang terpasang hanya untuk Android (`%APPDATA%\Godot\export_templates\4.7.2.stable`).

## Konvensi

- **Bahasa**: komentar dan teks di layar berbahasa Indonesia; nama variabel dan fungsi berbahasa Inggris.
- **Tanpa `class_name`**: skrip saling memuat lewat `const X = preload(...)`, supaya bisa dijalankan dengan `--script` tanpa cache kelas global.
- **GDScript bertipe** (`var x := ...`, parameter dan nilai balik bertipe).
- **Aturan terpisah dari tampilan**: `congklak_logic.gd` tidak tahu apa pun soal node. Ubah aturan di sana dan tambahkan ujinya di `tests/test_logic.gd`.
- **Jurus karakter hanya hiasan.** Jangan sampai memengaruhi logika permainan.

### Aturan gaya piksel

- Viewport 640×360, mode stretch `viewport`, filter tekstur *nearest*. Semua ukuran UI dalam piksel layar-rendah.
- Font piksel tingginya 8: pakai ukuran **kelipatan 8** (`UI.SMALL` 8, `UI.NORMAL` 16, `UI.BIG` 24).
- Sprite digambar pada **ukuran asli di koordinat bulat** (`.round()`), jangan diskalakan pecahan.
- Sprite karakter ditampilkan pada **kelipatan bulat 64×96** (64×96, 128×192); potongan dada pada kelipatan 64×52.
- Tanpa antialiasing dan tanpa pudar halus: pakai kedip atau pudar bertingkat.
- Teks di bilah atas harus pendek (sekitar 26 karakter); font piksel lebar.

### Performa di ponsel

- Jangan membangun poligon (`draw_circle`, `draw_arc`, `draw_colored_polygon`, `StyleBoxFlat`) ratusan kali tiap frame. Yang statis masuk ke lapisan `_backdrop` di `board.gd` (digambar ulang hanya saat ukuran berubah); yang bergerak pakai `draw_texture*` supaya ter-batch.
- Tekstur yang bergantung ukuran papan di-cache per jari-jari (`_pit_textures`, `_ring_textures`, `_hand_textures`).

## Cara kerja yang diminta pemilik proyek

- Uji di perangkat dilakukan dengan ekspor APK debug lalu `adb install`, kecuali diminta untuk tidak mengecek di HP.
- **Jangan pakai server MCP Godot** (`mcp__godot__*`). Jalankan Godot langsung dari baris perintah seperti di bagian Perintah.
