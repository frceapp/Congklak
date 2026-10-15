extends RefCounted
## Daftar karakter yang bisa dipilih. Jurus hanya efek visual: tidak ada
## pengaruhnya pada aturan permainan.
##
## style menentukan gaya efek di skill_fx.gd: "magic" atau "potion".
## stun    = jurus saat pemain mendapat giliran lagi (lawan "terkunci").
## capture = jurus saat pemain menembak lubang lawan.
## board dan backdrop = warna sisi papan dan latar layar milik pemain itu
## di mode 2 pemain.

const ROSTER: Array[Dictionary] = [
	{
		"id": "frieren",
		"name": "Frieren",
		"title": "Penyihir Elf",
		"style": "magic",
		"color": Color("8fe3ff"),
		"background": Color("86c2bd"),
		"board": Color("4f9a8e"),
		"backdrop": Color("12403a"),
		"bg_style": "magic_flower",
		"bg_accent": Color("8fe3ff"),
		"bg_title": "Bunga Biru & Sihir Elf",
		"bg_elements": ["Bunga Biru", "Kilau Mana", "Bintang Sihir"],
		"stun": "Sihir Pengikat",
		"stun_info": "Lingkaran sihir mengunci lawan saat kamu main lagi.",
		"capture": "Zoltraak",
		"capture_info": "Sinar sihir menghantam lawan saat kamu menembak.",
	},
	{
		"id": "maomao",
		"name": "Maomao",
		"title": "Ahli Obat",
		"style": "potion",
		"color": Color("c79bff"),
		"background": Color("dfa39e"),
		"board": Color("b9636c"),
		"backdrop": Color("4a1c2a"),
		"bg_style": "herb_potion",
		"bg_accent": Color("a3e4b7"),
		"bg_title": "Ramuan & Daun Herbal",
		"bg_elements": ["Botol Ramuan", "Daun Herbal", "Gelembung Obat"],
		"stun": "Asap Bius",
		"stun_info": "Botol ramuan bius membuat lawan pusing saat kamu main lagi.",
		"capture": "Racun Ampuh",
		"capture_info": "Ramuan beracun dilempar ke lawan saat kamu menembak.",
	},
]
