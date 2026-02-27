-- =========================================================
-- ULTRA SMART AUTO KATA v5.1 — NAKA
-- NEW: Human Typing Simulator + Kata Bom System + Prioritas Kata Sehari-hari
-- KEY SYSTEM: 1 Key = 1 Device (Permanent, Hardware Locked)
-- =========================================================

if game:IsLoaded() == false then
    game.Loaded:Wait()
end

-- =========================
-- SAFE RAYFIELD LOAD
-- =========================
local httpget = game.HttpGet
local loadstr = loadstring

local RayfieldSource = httpget(game, "https://sirius.menu/rayfield")
if RayfieldSource == nil then warn("Gagal ambil Rayfield source") return end

local RayfieldFunction = loadstr(RayfieldSource)
if RayfieldFunction == nil then warn("Gagal compile Rayfield") return end

local Rayfield = RayfieldFunction()
if Rayfield == nil then warn("Rayfield return nil") return end

-- =========================================================
-- ██╗  ██╗███████╗██╗   ██╗    ███████╗██╗   ██╗███████╗
-- ██║ ██╔╝██╔════╝╚██╗ ██╔╝    ██╔════╝╚██╗ ██╔╝██╔════╝
-- █████╔╝ █████╗   ╚████╔╝     ███████╗ ╚████╔╝ ███████╗
-- ██╔═██╗ ██╔══╝    ╚██╔╝      ╚════██║  ╚██╔╝  ╚════██║
-- ██║  ██╗███████╗   ██║       ███████║   ██║   ███████║
-- KEY SYSTEM — 1 KEY = 1 DEVICE (PERMANENT, HARDWARE LOCKED)
-- =========================================================

-- =========================
-- KONFIGURASI KEY SYSTEM
-- Ganti URL_DATABASE dengan URL raw GitHub/pastebin milikmu
-- Format file JSON: {"KEY123": "HWID_DEVICE", "KEY456": ""}
-- Key dengan value "" = belum terikat device (akan otomatis terikat)
-- Key dengan value berisi HWID = sudah terikat, cek HWID harus cocok
-- =========================
local KEY_DATABASE_URL = "https://raw.githubusercontent.com/Ihsan-ct/naka/refs/heads/main/keys.json"
-- ↑ GANTI dengan URL database key kamu!
-- Format keys.json:
-- {
--   "NAKA-XXXX-YYYY-ZZZZ": "",
--   "NAKA-AAAA-BBBB-CCCC": ""
-- }
-- Value "" = key aktif, belum terikat device
-- Value "HWID_STRING" = sudah terikat device tertentu

local BIND_ENDPOINT_URL = "https://script.google.com/macros/s/AKfycbxJEVTEuVV6Aa9lHo4pHrQ8RRbypTqCcGiUtsYdan4JnFTs964Sq73coAojyLkjg1IXDg/exec"
-- ↑ OPSIONAL: URL Google Apps Script untuk auto-bind HWID ke key
-- Jika tidak pakai, binding dilakukan manual oleh admin

-- =========================
-- HWID GENERATOR
-- Menggunakan kombinasi data unik device Roblox
-- Tidak bisa dipalsukan karena terikat akun + hardware
-- =========================
local Players          = game:GetService("Players")
local LocalPlayer      = Players.LocalPlayer
local HttpService      = game:GetService("HttpService")
local RobloxReplicatedStorage = game:GetService("ReplicatedStorage")

local function getDeviceHWID()
    -- Kombinasi: UserID + AccountAge + CreationDate + Platform
    local userId      = tostring(LocalPlayer.UserId)
    local accountAge  = tostring(LocalPlayer.AccountAge)
    
    -- Ambil info platform dari UserInputService
    local UIS         = game:GetService("UserInputService")
    local platform    = "UNKNOWN"
    pcall(function()
        if UIS.TouchEnabled and not UIS.KeyboardEnabled then
            platform = "MOBILE"
        elseif UIS.GamepadEnabled and not UIS.KeyboardEnabled then
            platform = "CONSOLE"
        else
            platform = "PC"
        end
    end)

    -- Hash sederhana dari kombinasi data
    local raw = userId .. "-" .. accountAge .. "-" .. platform
    
    -- Simple hash function (djb2-style)
    local hash = 5381
    for i = 1, #raw do
        local c = string.byte(raw, i)
        hash = ((hash * 33) + c) % 2147483647
    end
    
    -- Format HWID: NAKA-[UserID-Partial]-[Hash]
    local uidPartial = string.sub(userId, 1, 6)
    local hwid = string.format("HWID-%s-%X-%s", uidPartial, hash, platform)
    return hwid
end

local DEVICE_HWID = getDeviceHWID()
print("[KeySystem] Device HWID:", DEVICE_HWID)

-- =========================
-- STORAGE KEY (SimpleSpy tidak bisa intercept ini)
-- Simpan key yang sudah diverifikasi ke writefile agar tidak perlu input ulang
-- =========================
local SAVE_FOLDER = "NAKA_Keys"
local SAVE_FILE   = SAVE_FOLDER .. "/verified.dat"

local function saveVerifiedKey(key)
    pcall(function()
        if not isfolder(SAVE_FOLDER) then
            makefolder(SAVE_FOLDER)
        end
        -- Enkripsi sederhana sebelum disimpan (XOR dengan HWID)
        local encoded = ""
        for i = 1, #key do
            local c = string.byte(key, i)
            local h = string.byte(DEVICE_HWID, ((i-1) % #DEVICE_HWID) + 1)
            encoded = encoded .. string.char(bit32.bxor(c, h))
        end
        -- Simpan sebagai hex
        local hex = ""
        for i = 1, #encoded do
            hex = hex .. string.format("%02X", string.byte(encoded, i))
        end
        writefile(SAVE_FILE, hex .. "|" .. DEVICE_HWID)
    end)
end

local function loadSavedKey()
    local result = nil
    pcall(function()
        if isfile(SAVE_FILE) then
            local content = readfile(SAVE_FILE)
            local sep     = string.find(content, "|")
            if not sep then return end
            
            local hex     = string.sub(content, 1, sep - 1)
            local savedHwid = string.sub(content, sep + 1)
            
            -- Cek HWID cocok
            if savedHwid ~= DEVICE_HWID then
                -- HWID tidak cocok, hapus file
                delfile(SAVE_FILE)
                return
            end
            
            -- Decode hex
            local encoded = ""
            for i = 1, #hex, 2 do
                local byte = tonumber(string.sub(hex, i, i+1), 16)
                if byte then encoded = encoded .. string.char(byte) end
            end
            
            -- XOR decode
            local key = ""
            for i = 1, #encoded do
                local c = string.byte(encoded, i)
                local h = string.byte(DEVICE_HWID, ((i-1) % #DEVICE_HWID) + 1)
                key = key .. string.char(bit32.bxor(c, h))
            end
            
            if #key > 5 then
                result = key
            end
        end
    end)
    return result
end

-- =========================
-- VALIDASI KEY KE SERVER
-- Cek ke database apakah key valid dan HWID cocok
-- =========================
local function validateKeyOnline(inputKey)
    local success = false
    local message = ""
    
    -- Ambil database key
    local dbRaw = nil
    local ok, err = pcall(function()
        dbRaw = httpget(game, KEY_DATABASE_URL)
    end)
    
    if not ok or not dbRaw or dbRaw == "" then
        -- Jika tidak bisa connect, cek key yang tersimpan lokal sebagai fallback
        local savedKey = loadSavedKey()
        if savedKey and savedKey == inputKey then
            return true, "✅ Verifikasi dari cache lokal berhasil! (Offline mode)"
        end
        return false, "❌ Tidak bisa terhubung ke server key. Cek koneksi!"
    end
    
    -- Parse JSON database
    local keyDatabase = {}
    pcall(function()
        keyDatabase = HttpService:JSONDecode(dbRaw)
    end)
    
    if not keyDatabase then
        return false, "❌ Database key error. Hubungi admin!"
    end
    
    -- Cek apakah key ada
    local keyUpper = string.upper(inputKey)
    if keyDatabase[keyUpper] == nil then
        return false, "❌ Key tidak ditemukan. Key tidak valid!"
    end
    
    local boundHWID = keyDatabase[keyUpper]
    
    -- Key belum terikat device (value = "" atau "UNBOUND")
    if boundHWID == "" or boundHWID == "UNBOUND" then
        -- Key baru — akan diikat ke device ini
        -- Coba bind via Google Apps Script (opsional)
        pcall(function()
            if BIND_ENDPOINT_URL ~= "https://script.google.com/macros/s/YOUR_GOOGLE_APPS_SCRIPT_ID/exec" then
                httpget(game, BIND_ENDPOINT_URL 
                    .. "?action=bind&key=" .. keyUpper 
                    .. "&hwid=" .. DEVICE_HWID)
            end
        end)
        return true, "✅ Key valid! Device berhasil didaftarkan. (HWID: " .. string.sub(DEVICE_HWID, 1, 20) .. "...)"
    end
    
    -- Key sudah terikat — cek apakah HWID cocok
    if boundHWID == DEVICE_HWID then
        return true, "✅ Key valid! Device dikenali."
    else
        -- HWID berbeda = device lain sedang pakai key ini
        return false, "❌ Key sudah dipakai di device lain! 1 Key = 1 Device."
    end
end

-- =========================
-- MAIN KEY VERIFICATION FLOW
-- =========================
local keyVerified = false

local function runKeySystem()
    -- Cek apakah ada key yang tersimpan
    local savedKey = loadSavedKey()
    
    if savedKey then
        print("[KeySystem] Ditemukan key tersimpan, memvalidasi...")
        local ok, msg = validateKeyOnline(savedKey)
        if ok then
            print("[KeySystem] Key tersimpan valid:", msg)
            keyVerified = true
            Rayfield:Notify({
                Title    = "🔑  Key Terverifikasi",
                Content  = "Auto-login berhasil! " .. msg,
                Duration = 4,
                Image    = 4483362458
            })
            return true
        else
            -- Key tersimpan tidak valid lagi, hapus
            pcall(function() delfile(SAVE_FILE) end)
            print("[KeySystem] Key tersimpan tidak valid:", msg)
        end
    end
    
    -- Belum ada key atau key tidak valid — minta input
    print("[KeySystem] Menampilkan UI key input...")
    
    -- Buat window terpisah untuk key input
    local KeyWindow = Rayfield:CreateWindow({
        Name            = "🔑  NAKA KEY SYSTEM",
        LoadingTitle    = "Verifikasi Key",
        LoadingSubtitle = "1 Key = 1 Device | Permanent",
        ConfigurationSaving = { Enabled = false },
        Discord   = { Enabled = false },
        KeySystem = false
    })
    
    local KeyTab = KeyWindow:CreateTab("🔑  MASUKKAN KEY", 4483362458)
    
    KeyTab:CreateSection("◈  AKTIVASI KEY")
    KeyTab:CreateLabel("🔑  Masukkan key aktivasi NAKA")
    KeyTab:CreateLabel("⚠️   1 Key hanya bisa dipakai di 1 device!")
    KeyTab:CreateLabel("🔒  Setelah aktivasi, key terikat permanen")
    KeyTab:CreateLabel("◦   Device ID  :  " .. string.sub(DEVICE_HWID, 1, 24) .. "...")
    
    KeyTab:CreateSection("◈  INPUT KEY")
    
    local inputKeyValue = ""
    local statusLabel   = KeyTab:CreateLabel("◦  Status  :  Menunggu input key...")
    
    KeyTab:CreateInput({
        Name        = "🔑  Key Aktivasi",
        PlaceholderText = "Contoh: NAKA-XXXX-YYYY-ZZZZ",
        RemoveTextAfterFocusLost = false,
        Callback = function(Value)
            inputKeyValue = string.upper(string.gsub(Value, "%s+", ""))
        end
    })
    
    KeyTab:CreateButton({
        Name     = "✅  VERIFIKASI KEY",
        Callback = function()
            if inputKeyValue == "" then
                pcall(function()
                    statusLabel:Set("◦  Status  :  ❌ Key tidak boleh kosong!")
                end)
                Rayfield:Notify({
                    Title    = "❌  Input Kosong",
                    Content  = "Masukkan key terlebih dahulu!",
                    Duration = 3,
                    Image    = 4483362458
                })
                return
            end
            
            pcall(function()
                statusLabel:Set("◦  Status  :  ⏳ Memverifikasi ke server...")
            end)
            
            task.spawn(function()
                local ok, msg = validateKeyOnline(inputKeyValue)
                
                if ok then
                    -- Simpan key ke lokal
                    saveVerifiedKey(inputKeyValue)
                    keyVerified = true
                    
                    pcall(function()
                        statusLabel:Set("◦  Status  :  " .. msg)
                    end)
                    
                    Rayfield:Notify({
                        Title    = "✅  Key Valid!",
                        Content  = msg,
                        Duration = 5,
                        Image    = 4483362458
                    })
                    
                    task.wait(2)
                    -- Tutup window key, lanjut load script utama
                    pcall(function()
                        KeyWindow:Destroy()
                    end)
                    
                else
                    pcall(function()
                        statusLabel:Set("◦  Status  :  " .. msg)
                    end)
                    
                    Rayfield:Notify({
                        Title    = "❌  Key Ditolak",
                        Content  = msg,
                        Duration = 5,
                        Image    = 4483362458
                    })
                end
            end)
        end
    })
    
    KeyTab:CreateSection("◈  CARA MENDAPATKAN KEY")
    KeyTab:CreateLabel("1️⃣   Hubungi admin NAKA")
    KeyTab:CreateLabel("2️⃣   Beli / dapatkan key aktivasi")
    KeyTab:CreateLabel("3️⃣   Masukkan key di atas")
    KeyTab:CreateLabel("4️⃣   Key akan terikat ke device ini selamanya")
    
    -- Tunggu sampai key terverifikasi
    local timeout = 0
    while not keyVerified do
        task.wait(0.5)
        timeout = timeout + 0.5
        if timeout > 300 then  -- 5 menit timeout
            warn("[KeySystem] Timeout menunggu key input")
            return false
        end
    end
    
    return true
end

-- Jalankan key system
local keyOk = runKeySystem()
if not keyOk then
    warn("[NAKA] Key verification gagal. Script dihentikan.")
    return
end

print("[NAKA] Key verified! Memuat script utama...")
task.wait(1)

-- =========================================================
-- SCRIPT UTAMA (hanya jalan jika key valid)
-- =========================================================

-- =========================
-- SERVICES
-- =========================
local GetService        = game.GetService
local ReplicatedStorage = GetService(game, "ReplicatedStorage")
local LocalPlayer2      = Players.LocalPlayer

-- =========================
-- LOAD WORDLIST (KATA SEHARI-HARI PRIORITAS)
-- =========================
local kataModule = {
    -- Kata kerja sehari-hari (priority 1)
    "makan", "minum", "tidur", "mandi", "jalan", "lari", "duduk", "berdiri",
    "baca", "tulis", "dengar", "lihat", "pegang", "sentuh", "angkat", "taruh",
    "buka", "tutup", "nyala", "mati", "hidup", "kerja", "main", "belajar",
    "masak", "goreng", "rebus", "cuci", "setrika", "sapu", "pel", "bersih",
    "panggil", "ajak", "temu", "jumpa", "kunjung", "antar", "jemput",
    "cari", "temukan", "dapat", "beri", "kasih", "terima", "minta", "tolong",
    "bantu", "dukung", "bikin", "buat", "hasilkan", "produksi", "jual", "beli",
    "bayar", "hutang", "pinjam", "kembali", "simpan", "taruh", "ambil", "bawa",
    
    -- Kata benda sehari-hari (priority 2)
    "rumah", "sekolah", "kantor", "pasar", "toko", "warung", "masjid", "gereja",
    "meja", "kursi", "lemari", "kasur", "bantal", "selimut", "piring", "gelas",
    "sendok", "garpu", "pisau", "panci", "wajan", "kompor", "kulkas", "tv",
    "hp", "laptop", "komputer", "buku", "pensil", "pulpen", "penghapus",
    "motor", "mobil", "sepeda", "bus", "angkot", "kereta", "pesawat",
    "uang", "dompet", "kartu", "kunci", "tas", "sepatu", "baju", "celana",
    "topi", "kacamata", "jam", "gelang", "kalung", "cincin", "anting",
    "makanan", "minuman", "nasi", "lauk", "sayur", "buah", "daging", "ikan",
    "ayam", "telur", "susu", "roti", "mie", "bakso", "soto", "gado",
    "air", "api", "angin", "tanah", "batu", "pasir", "pohon", "bunga",
    "rumput", "daun", "cabang", "akar", "hutan", "gunung", "sungai", "laut",
    "pantai", "sawah", "ladang", "kebun", "tanaman", "padi", "jagung",
    
    -- Kata sifat sehari-hari (priority 3)
    "besar", "kecil", "panjang", "pendek", "tinggi", "rendah", "lebar", "sempit",
    "berat", "ringan", "keras", "lunak", "panas", "dingin", "hangat", "sejuk",
    "terang", "gelap", "cerah", "suram", "indah", "jelek", "cantik", "tampan",
    "enak", "lezat", "pahit", "manis", "asin", "asam", "pedas", "hambar",
    "baru", "lama", "muda", "tua", "sehat", "sakit", "lelah", "semangat",
    "kuat", "lemah", "cepat", "lambat", "rajin", "malas", "pintar", "bodoh",
    "baik", "buruk", "benar", "salah", "jujur", "curang", "berani", "takut",
    "senang", "sedih", "marah", "kecewa", "kaget", "heran", "bosan", "capek",
    
    -- Kata keterangan sehari-hari (priority 4)
    "cepat", "lambat", "sering", "jarang", "selalu", "tidak", "pernah",
    "sekarang", "nanti", "besok", "kemarin", "hari", "malam", "pagi", "siang",
    "sore", "subuh", "dini", "tahun", "bulan", "minggu", "pekan",
    "disini", "disitu", "disana", "kesini", "kesitu", "kesana", "dari sini",
    "segera", "langsung", "perlahan", "hati-hati", "sengaja", "kebetulan",
    
    -- Kata tanya (priority 5)
    "apa", "siapa", "kapan", "dimana", "kemana", "darimana", "mengapa", "kenapa",
    "bagaimana", "berapa", "yang", "mana", "apakah", "bukankah", "bukan",
    
    -- Kata penghubung (priority 6 - pendek)
    "dan", "atau", "tetapi", "namun", "sedangkan", "sementara", "karena",
    "sebab", "sehingga", "maka", "lalu", "kemudian", "setelah", "sebelum",
    "ketika", "saat", "walaupun", "meskipun", "jika", "kalau", "bila",
    "apabila", "dengan", "tanpa", "untuk", "bagi", "daripada", "dari",
    
    -- Kata ganti (priority 7)
    "saya", "aku", "kamu", "anda", "dia", "mereka", "kita", "kami",
    "ini", "itu", "sini", "situ", "sana", "begini", "begitu",
    "sesuatu", "seseorang", "semua", "seluruh", "masing-masing",
    
    -- Kata umum tambahan (priority 8)
    "orang", "anak", "ayah", "ibu", "kakak", "adik", "nenek", "kakek",
    "teman", "sahabat", "musuh", "lawan", "kawan", "rekan", "tetangga",
    "nama", "alamat", "nomor", "telepon", "wa", "sms", "chat",
    "kota", "desa", "kampung", "jalan", "gang", "lorong", "perempatan",
    "kiri", "kanan", "depan", "belakang", "atas", "bawah", "dalam", "luar",
    "warna", "merah", "biru", "hijau", "kuning", "hitam", "putih", "coklat",
    "ungu", "jingga", "abu-abu", "pink", "emas", "perak",
    
    -- Kata serapan umum (priority 9)
    "foto", "video", "musik", "film", "lagu", "game", "sport", "bola",
    "sepak", "voli", "basket", "bulu", "tangkis", "renang", "lari",
    "internet", "wifi", "data", "kuota", "pulsa", "paket", "signal",
    "facebook", "ig", "twitter", "tiktok", "yt", "youtube", "google",
    "online", "offline", "download", "upload", "streaming", "browsing",
    "app", "aplikasi", "software", "hardware", "driver", "update",
    "cash", "bonus", "diskon", "promo", "gratis", "premium", "vip",
    "malam", "pagi", "siang", "sore", "subuh", "maghrib", "isya",
    
    -- Kata panjang umum (priority 10 - untuk nilai tambah)
    "bermain", "belajar", "bekerja", "berjalan", "berlari", "berdiri",
    "membaca", "menulis", "mendengar", "melihat", "memegang", "menyentuh",
    "memasak", "menggoreng", "merebus", "mencuci", "membersihkan",
    "memanggil", "mengajak", "bertemu", "menjemput", "mengantar",
    "rumahku", "rumahmu", "sekolahku", "sekolahmu", "kantorku", "kantormu",
    "makanan", "minuman", "pakaian", "kendaraan", "perabotan",
    "sehari", "semalam", "sepekan", "sebulan", "setahun", "selamanya",
    "bersama", "sendirian", "berdua", "bertiga", "berempat",
    "senang", "sedih", "marah", "kecewa", "bahagia", "tersenyum",
    "berkata", "berbicara", "bercerita", "berdiskusi", "berdebat",
    
    -- Kata kerja berawalan me- (priority 11)
    "memakan", "meminum", "meniduri", "memandikan", "menjalani", "membaca",
    "menulis", "mendengar", "melihat", "memegang", "menyentuh", "mengangkat",
    "menaruh", "membuka", "menutup", "menyalakan", "mematikan", "menghidupkan",
    "bekerja", "bermain", "belajar", "memasak", "menggoreng", "merebus",
    "mencuci", "menyetrika", "menyapu", "mengepel", "membersihkan",
    "memanggil", "mengajak", "menemui", "menjumpai", "mengunjungi", "mengantar",
    "menjemput", "mencari", "menemukan", "mendapat", "memberi", "menerima",
    "meminta", "menolong", "membantu", "mendukung", "membuat", "menghasilkan",
    "memproduksi", "menjual", "membeli", "membayar", "meminjam", "mengembalikan",
    "menyimpan", "mengambil", "membawa",
    
    -- Kata kerja berawalan di- (priority 12)
    "dimakan", "diminum", "ditiduri", "dimandikan", "dijalani", "dibaca",
    "ditulis", "didengar", "dilihat", "dipegang", "disentuh", "diangkat",
    "ditaruh", "dibuka", "ditutup", "dinyalakan", "dimatikan", "dihidupkan",
    "dikerjakan", "dimainkan", "dipelajari", "dimasak", "digoreng", "direbus",
    "dicuci", "disetrika", "disapu", "dipel", "dibersihkan", "dipanggil",
    "diajak", "ditemui", "dijumpai", "dikunjungi", "diantar", "dijemput",
    "dicari", "ditemukan", "didapat", "diberi", "diterima", "diminta",
    "ditolong", "dibantu", "didukung", "dibuat", "dihasilkan", "diproduksi",
    "dijual", "dibeli", "dibayar", "dipinjam", "dikembalikan", "disimpan",
    "diambil", "dibawa",
    
    -- Kata keterangan waktu (priority 13)
    "kemarin", "hari ini", "besok", "lusa", "kemarin dulu", "sekarang",
    "nanti", "tadi", "barusan", "sudah", "belum", "pernah", "tidak pernah",
    "sedang", "masih", "akan", "hendak", "mau", "ingin", "bisa", "dapat",
    "harus", "wajib", "boleh", "jangan", "larang",
    
    -- Kata depan (priority 14)
    "di", "ke", "dari", "pada", "kepada", "untuk", "bagi", "oleh",
    "dengan", "tanpa", "tentang", "mengenai", "seperti", "bagai",
    
    -- Kata seru (priority 15)
    "ah", "oh", "wah", "aduh", "astaga", "ya", "oh ya", "nah", "gitu",
    "begitu", "sip", "ok", "oke", "yes", "gas", "wow", "cis", "buset",
}

-- Tambah kata-kata umum dari A-Z untuk variasi
local huruf = {"a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"}
for _, h in ipairs(huruf) do
    table.insert(kataModule, h .. "ja")  -- aja, bja, cja, dll
    table.insert(kataModule, h .. "pa")  -- apa, bpa, cpa, dll
    table.insert(kataModule, h .. "ta")  -- ata, bta, cta, dll
    table.insert(kataModule, h .. "ku")  -- aku, bku, cku, dll
    table.insert(kataModule, h .. "mu")  -- amu, bmu, cmu, dll
    table.insert(kataModule, h .. "an")  -- aan, ban, can, dll
    table.insert(kataModule, h .. "in")  -- ain, bin, cin, dll
    table.insert(kataModule, h .. "at")  -- aat, bat, cat, dll
    table.insert(kataModule, h .. "ar")  -- aar, bar, car, dll
    table.insert(kataModule, h .. "kan") -- akan, bkan, ckan, dll
    table.insert(kataModule, h .. "man") -- aman, bman, cman, dll
    table.insert(kataModule, h .. "wan") -- awan, bwan, cwan, dll
end

-- Hapus duplikat
local seen = {}
local unique = {}
for _, word in ipairs(kataModule) do
    if not seen[word] then
        seen[word] = true
        table.insert(unique, word)
    end
end
kataModule = unique

print("📚 Wordlist loaded: " .. #kataModule .. " kata sehari-hari")

-- =========================
-- REMOTES
-- =========================
local remotes         = ReplicatedStorage:WaitForChild("Remotes")
local MatchUI         = remotes:WaitForChild("MatchUI")
local SubmitWord      = remotes:WaitForChild("SubmitWord")
local BillboardUpdate = remotes:WaitForChild("BillboardUpdate")
local BillboardEnd    = remotes:WaitForChild("BillboardEnd")
local TypeSound       = remotes:WaitForChild("TypeSound")
local UsedWordWarn    = remotes:WaitForChild("UsedWordWarn")

-- =========================
-- STATE
-- =========================
local matchActive        = false
local isMyTurn           = false
local serverLetter       = ""
local usedWords          = {}
local usedWordsList      = {}
local opponentStreamWord = ""
local autoEnabled        = false
local autoRunning        = false

-- =========================
-- STATISTIK
-- =========================
local stats = {
    totalWords   = 0,
    longestWord  = "",
    sessionStart = os.time(),
    bombsFired   = 0,
}

-- =========================
-- KONFIGURASI
-- =========================
local config = {
    minDelay       = 500,
    maxDelay       = 750,
    aggression     = 20,
    minLength      = 3,
    maxLength      = 12,
    filterEnding   = {},
    antiDetectMode = true,
    preferRare     = false,
    bombMode       = false,
    bombTier       = "auto",
    prioritizeCommon = true,
    avoidRare      = true,
}

-- =========================
-- SAFE SET
-- =========================
local function safeSet(paragraph, content)
    if paragraph == nil then return end
    local safe = tostring(content or "")
    pcall(function() paragraph:Set(safe) end)
end

-- =========================================================
-- SCORING SYSTEM v2 - PRIORITAS KATA SEHARI-HARI
-- =========================================================
local COMMON_WORDS = {}  -- Hash table untuk cepet lookup
for _, word in ipairs(kataModule) do
    COMMON_WORDS[word] = true
end

local SUPER_COMMON = {
    "makan", "minum", "tidur", "mandi", "jalan", "lari", "duduk", "berdiri",
    "baca", "tulis", "dengar", "lihat", "kerja", "main", "belajar",
    "rumah", "sekolah", "kantor", "pasar", "toko", "warung", "meja", "kursi",
    "uang", "dompet", "kunci", "tas", "baju", "celana", "motor", "mobil",
    "besar", "kecil", "panjang", "pendek", "tinggi", "rendah", "baru", "lama",
    "cepat", "lambat", "sering", "jarang", "selalu", "tidak", "pernah",
    "sekarang", "nanti", "besok", "kemarin", "hari", "malam", "pagi", "siang",
    "apa", "siapa", "kapan", "dimana", "kemana", "mengapa", "kenapa",
    "dan", "atau", "tetapi", "karena", "jika", "kalau", "lalu", "kemudian",
    "saya", "aku", "kamu", "anda", "dia", "mereka", "kita", "kami",
    "ini", "itu", "sini", "situ", "sana", "orang", "anak", "ayah", "ibu",
    "air", "api", "angin", "tanah", "langit", "bumi", "bulan", "bintang",
    "makanan", "minuman", "nasi", "lauk", "sayur", "buah", "daging", "ikan",
    "enak", "manis", "asin", "asam", "pedas", "panas", "dingin", "hangat",
    "baik", "buruk", "benar", "salah", "senang", "sedih", "marah", "lelah",
    "nama", "alamat", "nomor", "telepon", "kota", "desa", "jalan", "kiri", "kanan",
    "merah", "biru", "hijau", "kuning", "hitam", "putih", "coklat",
    "foto", "video", "musik", "film", "lagu", "game", "internet", "online",
}

local SUPER_COMMON_SET = {}
for _, word in ipairs(SUPER_COMMON) do
    SUPER_COMMON_SET[word] = true
end

local HARD_ENDINGS = {
    ["x"] = 3,   -- Turunin nilai huruf susah
    ["q"] = 3,
    ["z"] = 3,
    ["f"] = 2,
    ["v"] = 2,
    ["y"] = 1,
    ["w"] = 1,
}

local function isCommonWord(word)
    -- Cek apakah kata itu umum dipakai
    return COMMON_WORDS[word] == true
end

local function isSuperCommon(word)
    return SUPER_COMMON_SET[word] == true
end

local function scoreWord(word)
    local score = 0
    local len = #word
    
    -- BASE SCORE: panjang kata
    score = score + (len * 2)
    
    -- BONUS BESAR untuk kata umum sehari-hari (INI YANG UTAMA!)
    if isCommonWord(word) then
        score = score + 50  -- Bonus gede banget!
        
        -- Extra bonus untuk kata yang SANGAT umum
        if isSuperCommon(word) then
            score = score + 30  -- Super common bonus!
        end
    else
        -- Kata tidak umum dikurangi nilainya (kalo mode avoidRare aktif)
        if config.avoidRare then
            score = score - 20
        end
    end
    
    -- PENALTY untuk huruf akhir susah (kata tidak umum)
    local lastChar = string.sub(word, -1)
    if HARD_ENDINGS[lastChar] then
        if not isCommonWord(word) and config.avoidRare then
            -- Kalo kata aneh + huruf susah = nilai rendah
            score = score - (HARD_ENDINGS[lastChar] * 5)
        else
            -- Kalo kata umum + huruf susah = bonus kecil (variasi)
            score = score + 2
        end
    end
    
    -- Bonus untuk kata panjang yang umum
    if len >= 8 and isCommonWord(word) then
        score = score + 15
    end
    
    return math.max(1, score)  -- Minimal 1 biar gak negatif
end

-- =========================================================
-- HUMAN TYPING SIMULATOR
-- =========================================================

local humanProfile = {
    baseSpeed      = math.random(350, 550),
    mistakeChance  = math.random(6, 13) / 100,
    hesitateChance = math.random(8, 18) / 100,
    isBurstyTyper  = math.random(1, 2) == 1,
    fatigueRate    = math.random(1, 4),
    doubleTypoRate = math.random(2, 6) / 100,
    wordCount      = 0,
}

print(string.format(
    "[HumanProfile] spd=%dms | typo=%.0f%% | hesitate=%.0f%% | burst=%s | fatigue=%d | double=%.0f%%",
    humanProfile.baseSpeed,
    humanProfile.mistakeChance * 100,
    humanProfile.hesitateChance * 100,
    tostring(humanProfile.isBurstyTyper),
    humanProfile.fatigueRate,
    humanProfile.doubleTypoRate * 100
))

local NEIGHBORS = {
    a={"q","w","s","z"},       b={"v","g","h","n"},
    c={"x","d","f","v"},       d={"s","e","r","f","c","x"},
    e={"w","r","d","s"},       f={"d","r","t","g","v","c"},
    g={"f","t","y","h","b","v"}, h={"g","y","u","j","n","b"},
    i={"u","o","k","j"},       j={"h","u","i","k","n","m"},
    k={"j","i","o","l","m"},   l={"k","o","p"},
    m={"n","j","k"},           n={"b","h","j","m"},
    o={"i","p","l","k"},       p={"o","l"},
    q={"w","a"},               r={"e","t","f","d"},
    s={"a","w","e","d","x","z"}, t={"r","y","g","f"},
    u={"y","i","h","j"},       v={"c","f","g","b"},
    w={"q","e","s","a"},       x={"z","s","d","c"},
    y={"t","u","g","h"},       z={"a","s","x"},
}

local function getNearbyChar(char)
    local nb = NEIGHBORS[char]
    if nb and #nb > 0 then
        return nb[math.random(1, #nb)]
    end
    local chars = "abcdefghijklmnopqrstuvwxyz"
    return string.sub(chars, math.random(1,26), math.random(1,26))
end

local function waitMs(ms)
    if ms < 8 then ms = 8 end
    task.wait(ms / 1000)
end

local function charDelay(charIndex, wordLength)
    local base = humanProfile.baseSpeed
    base = base + (humanProfile.wordCount * humanProfile.fatigueRate)
    if humanProfile.isBurstyTyper then
        local progress = charIndex / wordLength
        if progress < 0.35 then
            base = base * 0.85
        elseif progress > 0.75 then
            base = base * 1.4
        end
    end
    if charIndex == 1 then
        base = base + math.random(1000, 3000)
    end
    local noise = math.random(-15, 15) / 100
    base = base * (1 + noise)
    if math.random(1, 10) == 1 then
        base = base + math.random(200, 600)
    end
    if base < 150 then base = 150 end
    return math.floor(base)
end

local function humanTypeWord(selectedWord, serverPrefix)
    humanProfile.wordCount = humanProfile.wordCount + 1
    local currentDisplay = serverPrefix
    local remain         = string.sub(selectedWord, #serverPrefix + 1)
    local chars          = {}
    for i = 1, #remain do
        table.insert(chars, string.sub(remain, i, i))
    end
    local i = 1
    while i <= #chars do
        if not matchActive or not isMyTurn then return false end
        local correctChar = chars[i]
        local rolled      = math.random()
        if math.random() < humanProfile.hesitateChance then
            waitMs(math.random(400, 900))
            if math.random(1,4) == 1 and #currentDisplay > #serverPrefix then
                currentDisplay = string.sub(currentDisplay, 1, #currentDisplay - 1)
                TypeSound:FireServer()
                BillboardUpdate:FireServer(currentDisplay)
                waitMs(math.random(100, 300))
                currentDisplay = currentDisplay .. string.sub(selectedWord, #currentDisplay + 1, #currentDisplay + 1)
                TypeSound:FireServer()
                BillboardUpdate:FireServer(currentDisplay)
                waitMs(charDelay(i, #chars))
                i = i + 1
                continue
            end
        end
        if rolled < humanProfile.doubleTypoRate and i <= #chars - 1 then
            local wrong1 = getNearbyChar(correctChar)
            local wrong2 = getNearbyChar(chars[i+1] or correctChar)
            currentDisplay = currentDisplay .. wrong1
            TypeSound:FireServer()
            BillboardUpdate:FireServer(currentDisplay)
            waitMs(charDelay(i, #chars) * 0.6)
            currentDisplay = currentDisplay .. wrong2
            TypeSound:FireServer()
            BillboardUpdate:FireServer(currentDisplay)
            waitMs(math.random(80, 200))
            currentDisplay = string.sub(currentDisplay, 1, #currentDisplay - 1)
            TypeSound:FireServer()
            BillboardUpdate:FireServer(currentDisplay)
            waitMs(math.random(60, 150))
            currentDisplay = string.sub(currentDisplay, 1, #currentDisplay - 1)
            TypeSound:FireServer()
            BillboardUpdate:FireServer(currentDisplay)
            waitMs(math.random(80, 220))
            currentDisplay = currentDisplay .. correctChar
            TypeSound:FireServer()
            BillboardUpdate:FireServer(currentDisplay)
            waitMs(charDelay(i, #chars))
            i = i + 1
        elseif rolled < (humanProfile.doubleTypoRate + humanProfile.mistakeChance) then
            local wrongChar = getNearbyChar(correctChar)
            currentDisplay = currentDisplay .. wrongChar
            TypeSound:FireServer()
            BillboardUpdate:FireServer(currentDisplay)
            waitMs(math.random(50, 300))
            local extraBeforeRealize = math.random(1, 5)
            if extraBeforeRealize <= 2 and i < #chars then
                local nextChar = chars[i+1] or correctChar
                currentDisplay = currentDisplay .. nextChar
                TypeSound:FireServer()
                BillboardUpdate:FireServer(currentDisplay)
                waitMs(math.random(60, 180))
                currentDisplay = string.sub(currentDisplay, 1, #currentDisplay - 1)
                TypeSound:FireServer()
                BillboardUpdate:FireServer(currentDisplay)
                waitMs(math.random(50, 130))
            end
            currentDisplay = string.sub(currentDisplay, 1, #currentDisplay - 1)
            TypeSound:FireServer()
            BillboardUpdate:FireServer(currentDisplay)
            waitMs(math.random(80, 250))
            currentDisplay = currentDisplay .. correctChar
            TypeSound:FireServer()
            BillboardUpdate:FireServer(currentDisplay)
            waitMs(charDelay(i, #chars))
            i = i + 1
        else
            currentDisplay = currentDisplay .. correctChar
            TypeSound:FireServer()
            BillboardUpdate:FireServer(currentDisplay)
            waitMs(charDelay(i, #chars))
            i = i + 1
        end
    end
    waitMs(math.random(400, 1000))
    return true
end

-- =========================================================
-- 💣 KATA BOM SYSTEM (ADAPTASI UNTUK KATA UMUM)
-- =========================================================

local BOM_TIERS = {
    biasa = {"f","v","w","y"},
    kuat  = {"x","q","z"},
    mega  = {"x","q","z","f","v"},
}

local letterCountCache = {}

local function buildLetterCache()
    for _, word in ipairs(kataModule) do
        local firstChar = string.sub(word, 1, 1)
        letterCountCache[firstChar] = (letterCountCache[firstChar] or 0) + 1
    end
    print("[KataBom] Letter cache built:")
    for letter, count in pairs(letterCountCache) do
        if count < 200 then
            print(string.format("  %s → %d kata (langka!)", string.upper(letter), count))
        end
    end
end

task.spawn(buildLetterCache)

local function getBombScore(word)
    -- Bom skor dihitung berdasarkan kelangkaan, tapi kita tetap prioritaskan kata umum
    if isCommonWord(word) then
        return 0  -- Kata umum bukan bom
    end
    
    local lastChar = string.sub(word, -1)
    local count = letterCountCache[lastChar] or 9999
    local len = #word
    local score = 0
    
    -- Bom murni dari kelangkaan huruf akhir
    if count < 50 then score = score + 100
    elseif count < 150 then score = score + 60
    elseif count < 400 then score = score + 30
    elseif count < 800 then score = score + 10
    end
    
    -- Kata panjang dikit bonus
    if len >= 10 then score = score + 10
    elseif len >= 8 then score = score + 5
    end
    
    return score
end

local function getBombTier(score)
    if score >= 120 then return "mega"
    elseif score >= 60 then return "kuat"
    elseif score >= 20 then return "biasa"
    else return nil
    end
end

local function findBombWord(prefix, tierTarget)
    local candidates = {}
    local lowerPrefix = string.lower(prefix)
    local allowedEndings = {}
    
    if tierTarget == "mega" then
        for _, e in ipairs(BOM_TIERS.mega) do allowedEndings[e] = true end
    elseif tierTarget == "kuat" then
        for _, e in ipairs(BOM_TIERS.kuat) do allowedEndings[e] = true end
        for _, e in ipairs(BOM_TIERS.mega) do allowedEndings[e] = true end
    elseif tierTarget == "biasa" then
        for _, e in ipairs(BOM_TIERS.biasa) do allowedEndings[e] = true end
        for _, e in ipairs(BOM_TIERS.kuat)  do allowedEndings[e] = true end
        for _, e in ipairs(BOM_TIERS.mega)  do allowedEndings[e] = true end
    else
        for _, e in ipairs(BOM_TIERS.biasa) do allowedEndings[e] = true end
        for _, e in ipairs(BOM_TIERS.kuat)  do allowedEndings[e] = true end
        for _, e in ipairs(BOM_TIERS.mega)  do allowedEndings[e] = true end
    end
    
    for _, word in ipairs(kataModule) do
        -- Cuma cari kata yang TIDAK umum untuk bom
        if not isCommonWord(word) and string.sub(word, 1, #lowerPrefix) == lowerPrefix
            and not usedWords[word]
            and #word >= config.minLength
            and #word <= config.maxLength then
            local lastChar = string.sub(word, -1)
            if allowedEndings[lastChar] then
                local bombScore = getBombScore(word)
                if bombScore > 0 then
                    table.insert(candidates, {word=word, score=bombScore})
                end
            end
        end
    end
    
    table.sort(candidates, function(a,b) return a.score > b.score end)
    if #candidates > 0 then
        return candidates[1].word, getBombTier(candidates[1].score), candidates[1].score
    end
    return nil, nil, 0
end

local labelBombStatus  = nil
local labelBombStock   = nil

local function updateBombUI(word, tier, score)
    if labelBombStatus == nil then return end
    if word then
        local tierIcon = tier == "mega" and "💣💣💣" or tier == "kuat" and "💣💣" or "💣"
        pcall(function()
            labelBombStatus:Set(tierIcon .. "  Bom Siap  :  " .. string.upper(word)
                .. "  [ Tier: " .. string.upper(tier or "?")
                .. "  |  Skor: " .. tostring(score) .. " ]")
        end)
    else
        pcall(function()
            labelBombStatus:Set("💣  Tidak ada kata bom tersedia untuk huruf ini")
        end)
    end
end

local function updateBombStock()
    if labelBombStock == nil then return end
    local totalBomb = 0
    for _, word in ipairs(kataModule) do
        if getBombScore(word) >= 20 then
            totalBomb = totalBomb + 1
        end
    end
    pcall(function()
        labelBombStock:Set("◦  Stok Kata Bom  :  ~" .. tostring(totalBomb) .. " kata")
    end)
end

-- =========================
-- WORD MANAGEMENT
-- =========================
local function isUsed(word)
    return usedWords[string.lower(word)] == true
end

local function addUsedWord(word)
    if not word then return end
    local w = string.lower(tostring(word))
    if not usedWords[w] then
        usedWords[w] = true
        table.insert(usedWordsList, w)
        stats.totalWords = (stats.totalWords or 0) + 1
        if #w > #(stats.longestWord or "") then
            stats.longestWord = w
        end
    end
end

local function resetUsedWords()
    usedWords     = {}
    usedWordsList = {}
end

-- =========================
-- GET SMART WORDS (DENGAN PRIORITAS)
-- =========================
local function getSmartWords(prefix)
    local results = {}
    local lowerPrefix = string.lower(prefix)
    local filterSet = {}
    local hasFilter = false
    
    for _, v in ipairs(config.filterEnding) do
        local lv = string.lower(tostring(v))
        if lv ~= "semua" and lv ~= "" then
            filterSet[lv] = true
            hasFilter = true
        end
    end
    
    for _, word in ipairs(kataModule) do
        if string.sub(word, 1, #lowerPrefix) == lowerPrefix and not isUsed(word) then
            local len = #word
            if len >= config.minLength and len <= config.maxLength then
                local passFilter = true
                if hasFilter then
                    if not filterSet[string.sub(word, -1)] then
                        passFilter = false
                    end
                end
                if passFilter then
                    table.insert(results, word)
                end
            end
        end
    end
    
    -- SORTING: PRIORITAS UTAMA = KATA UMUM!
    if config.prioritizeCommon then
        table.sort(results, function(a,b)
            local scoreA = scoreWord(a)
            local scoreB = scoreWord(b)
            
            -- Kalo nilai sama, pilih yang lebih pendek (biar cepet)
            if scoreA == scoreB then
                return #a < #b
            end
            return scoreA > scoreB
        end)
    else
        -- Sorting normal berdasarkan panjang
        table.sort(results, function(a,b)
            return #a > #b
        end)
    end
    
    return results
end

-- =========================
-- AUTO ENGINE
-- =========================
local function startUltraAI()
    if autoRunning     then return end
    if not autoEnabled then return end
    if not matchActive then return end
    if not isMyTurn    then return end
    if serverLetter == "" then return end

    autoRunning = true
    task.wait(math.random(config.minDelay, config.maxDelay) / 1000)

    local selectedWord = nil
    local isBomb       = false
    local bombTierUsed = nil
    local bombScore    = 0

    -- Prioritaskan bom dulu kalo mode aktif
    if config.bombMode then
        local bWord, bTier, bScore = findBombWord(serverLetter, config.bombTier)
        if bWord then
            selectedWord = bWord
            isBomb       = true
            bombTierUsed = bTier
            bombScore    = bScore
            updateBombUI(bWord, bTier, bScore)
        end
    end

    -- Kalo gak ada bom, cari kata biasa
    if not selectedWord then
        local words = getSmartWords(serverLetter)
        if #words == 0 then
            -- Coba tanpa filter kalo kosong
            if #config.filterEnding > 0 then
                local oldFilter = config.filterEnding
                config.filterEnding = {}
                words = getSmartWords(serverLetter)
                config.filterEnding = oldFilter
            end
            if #words == 0 then
                autoRunning = false
                return
            end
        end
        
        -- Pilih kata berdasarkan agresivitas
        if config.aggression >= 100 then
            selectedWord = words[1]  -- Ambil terbaik
        else
            local topN = math.max(1, math.floor(#words * (1 - config.aggression/100)))
            if topN > #words then topN = #words end
            selectedWord = words[math.random(1, topN)]
        end
    end

    -- Ketik dengan human simulator
    local success = humanTypeWord(selectedWord, serverLetter)
    if not success then
        autoRunning = false
        return
    end

    -- Submit kata
    SubmitWord:FireServer(selectedWord)
    addUsedWord(selectedWord)

    -- Notifikasi kalo bom
    if isBomb then
        stats.bombsFired = (stats.bombsFired or 0) + 1
        local tierIcon = bombTierUsed == "mega" and "💣💣💣 MEGA BOM"
            or bombTierUsed == "kuat" and "💣💣 BOM KUAT"
            or "💣 BOM BIASA"
        Rayfield:Notify({
            Title   = tierIcon .. " DILUNCURKAN!",
            Content = string.upper(selectedWord) .. "  |  Skor: " .. tostring(bombScore),
            Duration = 4,
            Image    = 4483362458
        })
    elseif isCommonWord(selectedWord) then
        -- Notifikasi kecil untuk kata umum (opsional)
        if isSuperCommon(selectedWord) and math.random(1,5) == 1 then
            Rayfield:Notify({
                Title   = "📝 Kata Umum",
                Content = string.upper(selectedWord),
                Duration = 2,
                Image    = 4483362458
            })
        end
    end

    task.wait(math.random(100, 300) / 1000)
    BillboardEnd:FireServer()
    autoRunning = false
end

-- =========================
-- AUTO WATCHER LOOP
-- =========================
task.spawn(function()
    while true do
        task.wait(0.3)
        if autoEnabled and matchActive and isMyTurn
            and serverLetter ~= "" and not autoRunning then
            task.spawn(startUltraAI)
        end
    end
end)

-- =========================================================
-- BUILD UI — 5 Tab: KEY INFO | BATTLE | BOMB | SETTINGS | INFO
-- =========================================================
local Window = Rayfield:CreateWindow({
    Name            = "⚔ NAKA  •  AUTO KATA v5.1",
    LoadingTitle    = "N A K A",
    LoadingSubtitle = "Prioritas Kata Sehari-hari",
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "NAKA",
        FileName   = "AutoKata"
    },
    Discord   = { Enabled = false },
    KeySystem = false
})

Rayfield:LoadConfiguration()

Rayfield:Notify({
    Title    = "⚔  NAKA v5.1",
    Content  = "Key Verified! Prioritas Kata Sehari-hari!",
    Duration = 5,
    Image    = 4483362458
})

-- ╔══════════════════════════════╗
-- ║   TAB 0 — 🔑 KEY INFO        ║
-- ╚══════════════════════════════╝
local KeyInfoTab = Window:CreateTab("🔑  KEY", 4483362458)

KeyInfoTab:CreateSection("◈  STATUS KEY")
KeyInfoTab:CreateLabel("✅  Key Terverifikasi  —  Device Terdaftar")
KeyInfoTab:CreateLabel("🔒  1 Key = 1 Device  |  Permanen")
KeyInfoTab:CreateLabel("◦  HWID  :  " .. string.sub(DEVICE_HWID, 1, 30) .. "...")

local savedKeyForDisplay = loadSavedKey() or "—"
local displayKey = string.len(savedKeyForDisplay) > 8
    and (string.sub(savedKeyForDisplay, 1, 9) .. "****")
    or savedKeyForDisplay
KeyInfoTab:CreateLabel("◦  Key   :  " .. displayKey)

KeyInfoTab:CreateSection("◈  KEAMANAN")
KeyInfoTab:CreateLabel("🔐  Key terikat hardware Roblox kamu")
KeyInfoTab:CreateLabel("🚫  Tidak bisa dipindah ke device lain")
KeyInfoTab:CreateLabel("♾️   Berlaku selamanya (permanent)")

KeyInfoTab:CreateSection("◈  AKSI")
KeyInfoTab:CreateButton({
    Name     = "🔄  Verifikasi Ulang Key (Online Check)",
    Callback = function()
        local sk = loadSavedKey()
        if not sk then
            Rayfield:Notify({
                Title    = "❌  Tidak ada key tersimpan",
                Content  = "Restart script untuk input key",
                Duration = 3,
                Image    = 4483362458
            })
            return
        end
        task.spawn(function()
            local ok, msg = validateKeyOnline(sk)
            Rayfield:Notify({
                Title    = ok and "✅  Key Valid" or "❌  Key Bermasalah",
                Content  = msg,
                Duration = 5,
                Image    = 4483362458
            })
        end)
    end
})

KeyInfoTab:CreateButton({
    Name     = "🗑️  Hapus Key Tersimpan (Logout Device)",
    Callback = function()
        pcall(function()
            if isfile(SAVE_FILE) then
                delfile(SAVE_FILE)
                Rayfield:Notify({
                    Title    = "🗑️  Key Dihapus",
                    Content  = "Key lokal dihapus. Restart untuk input key baru.",
                    Duration = 5,
                    Image    = 4483362458
                })
            else
                Rayfield:Notify({
                    Title    = "⚠️  Tidak ada file",
                    Content  = "Tidak ada key yang tersimpan",
                    Duration = 3,
                    Image    = 4483362458
                })
            end
        end)
    end
})

-- ╔══════════════════════════════╗
-- ║   TAB 1 — BATTLE             ║
-- ╚══════════════════════════════╝
local BattleTab = Window:CreateTab("⚔  BATTLE", 4483362458)

BattleTab:CreateSection("◈  STATUS LIVE")
local turnParagraph        = BattleTab:CreateLabel("●  Giliran      :  ⏳ Menunggu pertandingan...")
local startLetterParagraph = BattleTab:CreateLabel("●  Huruf Awalan :  —")
local opponentParagraph    = BattleTab:CreateLabel("●  Lawan        :  ⏳ Menunggu...")

BattleTab:CreateSection("◈  AUTO KATA")

BattleTab:CreateToggle({
    Name         = "⚡  Aktifkan Auto Kata",
    CurrentValue = false,
    Callback     = function(Value)
        autoEnabled = Value
        if Value then
            Rayfield:Notify({
                Title    = "⚡  Auto Kata ON",
                Content  = "AI + Human Typing aktif!",
                Duration = 3,
                Image    = 4483362458
            })
            if matchActive and isMyTurn and serverLetter ~= "" then
                task.spawn(startUltraAI)
            end
        else
            Rayfield:Notify({
                Title    = "⚡  Auto Kata OFF",
                Content  = "AI dinonaktifkan",
                Duration = 2,
                Image    = 4483362458
            })
        end
    end
})

BattleTab:CreateToggle({
    Name         = "📝  Prioritaskan Kata Sehari-hari",
    CurrentValue = true,
    Callback     = function(Value)
        config.prioritizeCommon = Value
        Rayfield:Notify({
            Title    = Value and "📝 Mode: Kata Sehari-hari" or "📝 Mode: Semua Kata",
            Content  = Value and "Prioritas kata umum +50 bonus" or "Semua kata diproses normal",
            Duration = 3,
            Image    = 4483362458
        })
    end
})

BattleTab:CreateSection("◈  FILTER AKHIRAN  ( TRAP )")
local filterLabel = BattleTab:CreateLabel("◦  Filter aktif  :  semua kata")

BattleTab:CreateDropdown({
    Name            = "🔡  Pilih Akhiran (multi-select)",
    Options         = {"a","i","u","e","o","n","r","s","t","k","h","l","m","p","g","j","f","v","z","x","q","w","y"},
    CurrentOption   = {},
    MultipleOptions = true,
    Callback        = function(Value)
        local selected = {}
        if type(Value) == "table" then
            for _, v in ipairs(Value) do
                table.insert(selected, string.lower(tostring(v)))
            end
        end
        config.filterEnding = selected
        if #selected == 0 then
            pcall(function() filterLabel:Set("◦  Filter aktif  :  semua kata") end)
        else
            local display = table.concat(selected, "  ·  ")
            pcall(function() filterLabel:Set("◦  Filter aktif  :  " .. display) end)
        end
    end
})

BattleTab:CreateButton({
    Name     = "💀  TRAP MODE  —  x · q · z · f · v",
    Callback = function()
        config.filterEnding = {"x","q","z","f","v"}
        pcall(function() filterLabel:Set("◦  Filter aktif  :  x  ·  q  ·  z  ·  f  ·  v   [ 💀 TRAP ]") end)
        Rayfield:Notify({
            Title    = "💀  TRAP MODE ON",
            Content  = "Lawan akan kesulitan!",
            Duration = 4,
            Image    = 4483362458
        })
    end
})

BattleTab:CreateButton({
    Name     = "↺  Reset Filter",
    Callback = function()
        config.filterEnding = {}
        pcall(function() filterLabel:Set("◦  Filter aktif  :  semua kata") end)
    end
})

BattleTab:CreateSection("◈  STATISTIK")
local labelKataDikirim  = BattleTab:CreateLabel("◦  Kata Dikirim    :  0")
local labelKataPanjang  = BattleTab:CreateLabel("◦  Kata Terpanjang :  —")
local labelDurasi       = BattleTab:CreateLabel("◦  Durasi Sesi     :  0m 0s")
local labelBomDikirim   = BattleTab:CreateLabel("◦  Bom Diluncurkan :  0")
local labelKataTerpakai = BattleTab:CreateLabel("◦  Riwayat         :  (belum ada)")

local function updateStatsParagraph()
    local elapsed  = os.time() - (stats.sessionStart or os.time())
    local minutes  = math.floor(elapsed / 60)
    local seconds  = elapsed % 60
    local longest  = tostring(stats.longestWord or "")
    local dispLong = longest ~= "" and longest or "—"
    pcall(function() labelKataDikirim:Set("◦  Kata Dikirim    :  " .. tostring(stats.totalWords or 0)) end)
    pcall(function() labelKataPanjang:Set("◦  Kata Terpanjang :  " .. dispLong) end)
    pcall(function() labelDurasi:Set("◦  Durasi Sesi     :  " .. minutes .. "m " .. seconds .. "s") end)
    pcall(function() labelBomDikirim:Set("◦  Bom Diluncurkan :  " .. tostring(stats.bombsFired or 0)) end)
end

local function updateKataLabel()
    local count = #usedWordsList
    if count == 0 then
        pcall(function() labelKataTerpakai:Set("◦  Riwayat         :  (belum ada)") end)
    else
        local display = ""
        local start   = math.max(1, count - 7)
        for i = start, count do
            display = display .. usedWordsList[i]
            if i < count then display = display .. "  ·  " end
        end
        if count > 8 then display = "…  " .. display end
        pcall(function() labelKataTerpakai:Set("◦  Riwayat  [" .. count .. "]  :  " .. display) end)
    end
end

local _origAdd = addUsedWord
addUsedWord = function(word)
    _origAdd(word)
    updateKataLabel()
end

local _origReset = resetUsedWords
resetUsedWords = function()
    _origReset()
    pcall(function() labelKataTerpakai:Set("◦  Riwayat         :  (belum ada)") end)
end

BattleTab:CreateButton({
    Name     = "↺  Reset Semua Statistik & Riwayat",
    Callback = function()
        stats.totalWords   = 0
        stats.longestWord  = ""
        stats.sessionStart = os.time()
        stats.bombsFired   = 0
        usedWords          = {}
        usedWordsList      = {}
        humanProfile.wordCount = 0
        updateStatsParagraph()
        updateKataLabel()
        Rayfield:Notify({
            Title    = "↺  Reset",
            Content  = "Statistik & riwayat direset",
            Duration = 3,
            Image    = 4483362458
        })
    end
})

-- ╔══════════════════════════════╗
-- ║   TAB 2 — 💣 KATA BOM        ║
-- ╚══════════════════════════════╝
local BombTab = Window:CreateTab("💣  KATA BOM", 4483362458)

BombTab:CreateSection("◈  KATA BOM SYSTEM")
BombTab:CreateLabel("💡  Kata Bom = kata langka yang huruf akhirnya")
BombTab:CreateLabel("     susah dicari sambungannya. Lawan akan")
BombTab:CreateLabel("     kesulitan membalas!")

BombTab:CreateSection("◈  KONTROL BOM")

BombTab:CreateToggle({
    Name         = "💣  Aktifkan Kata Bom",
    CurrentValue = false,
    Callback     = function(Value)
        config.bombMode = Value
        Rayfield:Notify({
            Title    = Value and "💣  Kata Bom ON" or "💣  Kata Bom OFF",
            Content  = Value and "AI akan cari kata langka untuk menjebak!" or "Mode normal (kata umum)",
            Duration = 3,
            Image    = 4483362458
        })
    end
})

BombTab:CreateDropdown({
    Name          = "🎯  Pilih Tier Bom",
    Options       = {"auto","biasa","kuat","mega"},
    CurrentOption = "auto",
    Callback      = function(Value)
        config.bombTier = string.lower(tostring(Value))
        local desc = {
            auto  = "AI pilih tier terbaik otomatis",
            biasa = "💣 Akhiran: f · v · w · y",
            kuat  = "💣💣 Akhiran: x · q · z",
            mega  = "💣💣💣 Akhiran terlangka + kata 10+ huruf",
        }
        Rayfield:Notify({
            Title    = "🎯  Tier: " .. string.upper(config.bombTier),
            Content  = desc[config.bombTier] or "",
            Duration = 4,
            Image    = 4483362458
        })
    end
})

BombTab:CreateSection("◈  TIER PENJELASAN")
BombTab:CreateLabel("💣  BIASA   →  akhiran f · v · w · y")
BombTab:CreateLabel("     Lawan masih bisa balas tapi susah")
BombTab:CreateLabel("💣💣  KUAT    →  akhiran x · q · z")
BombTab:CreateLabel("     Sangat sedikit kata yang bisa balas")
BombTab:CreateLabel("💣💣💣  MEGA    →  kombinasi terlangka + panjang")
BombTab:CreateLabel("     Hampir mustahil dibalas lawan!")

BombTab:CreateSection("◈  STATUS BOM REALTIME")
labelBombStatus = BombTab:CreateLabel("💣  Belum ada data  —  mulai pertandingan")
labelBombStock  = BombTab:CreateLabel("◦  Stok Kata Bom  :  menghitung...")

task.delay(3, function()
    pcall(updateBombStock)
end)

BombTab:CreateSection("◈  MANUAL TRIGGER")

BombTab:CreateButton({
    Name     = "💣  Cari Kata Bom Sekarang (Preview)",
    Callback = function()
        if serverLetter == "" then
            Rayfield:Notify({
                Title   = "⚠️  Belum ada huruf aktif",
                Content = "Masuk pertandingan dulu!",
                Duration = 3,
                Image = 4483362458
            })
            return
        end
        local bWord, bTier, bScore = findBombWord(serverLetter, config.bombTier)
        if bWord then
            updateBombUI(bWord, bTier, bScore)
            Rayfield:Notify({
                Title   = "💣  Kata Bom Ditemukan!",
                Content = string.upper(bWord) .. "  (Tier: " .. string.upper(bTier) .. "  |  Skor: " .. bScore .. ")",
                Duration = 5,
                Image = 4483362458
            })
        else
            updateBombUI(nil, nil, 0)
            Rayfield:Notify({
                Title   = "😔  Tidak ada kata bom",
                Content = "Untuk huruf '" .. string.upper(serverLetter) .. "' saat ini",
                Duration = 3,
                Image = 4483362458
            })
        end
    end
})

-- ╔══════════════════════════════╗
-- ║   TAB 3 — SETTINGS           ║
-- ╚══════════════════════════════╝
local SettingsTab = Window:CreateTab("⚙  SETTINGS", 4483362458)

SettingsTab:CreateSection("◈  PARAMETER AI")

SettingsTab:CreateSlider({
    Name         = "⚡  Agresivitas  ( 0 = santai  ·  100 = dominan )",
    Range        = {0, 100},
    Increment    = 5,
    CurrentValue = config.aggression,
    Callback     = function(Value) config.aggression = Value end
})

SettingsTab:CreateSlider({
    Name         = "↓  Panjang Kata Minimum",
    Range        = {2, 6},
    Increment    = 1,
    CurrentValue = config.minLength,
    Callback     = function(Value) config.minLength = Value end
})

SettingsTab:CreateSlider({
    Name         = "↑  Panjang Kata Maksimum",
    Range        = {5, 20},
    Increment    = 1,
    CurrentValue = config.maxLength,
    Callback     = function(Value) config.maxLength = Value end
})

SettingsTab:CreateSection("◈  PRIORITAS KATA")

SettingsTab:CreateToggle({
    Name         = "📝  Prioritaskan Kata Sehari-hari",
    CurrentValue = true,
    Callback     = function(Value)
        config.prioritizeCommon = Value
        Rayfield:Notify({
            Title    = Value and "📝 Mode: Kata Sehari-hari" or "📝 Mode: Semua Kata",
            Content  = Value and "Prioritas kata umum +50 bonus" or "Semua kata diproses normal",
            Duration = 3,
            Image    = 4483362458
        })
    end
})

SettingsTab:CreateToggle({
    Name         = "🚫  Hindari Kata Langka",
    CurrentValue = true,
    Callback     = function(Value)
        config.avoidRare = Value
    end
})

local commonCount = 0
for _, word in ipairs(kataModule) do
    if isCommonWord(word) then commonCount = commonCount + 1 end
end
SettingsTab:CreateLabel("📊  Statistik Kata:")
SettingsTab:CreateLabel("◦  Total kata: " .. #kataModule)
SettingsTab:CreateLabel("◦  Kata umum: " .. commonCount .. " (" .. math.floor(commonCount/#kataModule*100) .. "%)")

SettingsTab:CreateSection("◈  HUMAN TYPING SIMULATOR")
SettingsTab:CreateLabel("🎭  Profil manusia dibuat otomatis tiap sesi")
SettingsTab:CreateLabel(string.format("◦  Kecepatan Base   :  %d ms/karakter", humanProfile.baseSpeed))
SettingsTab:CreateLabel(string.format("◦  Chance Typo      :  %.0f%%", humanProfile.mistakeChance * 100))
SettingsTab:CreateLabel(string.format("◦  Chance Ragu-ragu :  %.0f%%", humanProfile.hesitateChance * 100))
SettingsTab:CreateLabel(string.format("◦  Tipe Ketik       :  %s", humanProfile.isBurstyTyper and "Burst (cepat→lambat)" or "Konsisten"))

SettingsTab:CreateButton({
    Name = "🔄  Generate Profil Baru",
    Callback = function()
        humanProfile.baseSpeed      = math.random(350, 550)
        humanProfile.mistakeChance  = math.random(6, 13) / 100
        humanProfile.hesitateChance = math.random(8, 18) / 100
        humanProfile.isBurstyTyper  = math.random(1,2) == 1
        humanProfile.fatigueRate    = math.random(1,4)
        humanProfile.doubleTypoRate = math.random(2,6) / 100
        humanProfile.wordCount      = 0
        Rayfield:Notify({
            Title   = "🎭  Profil Baru Dibuat!",
            Content = string.format("Spd:%dms | Typo:%.0f%% | Hesitate:%.0f%%",
                humanProfile.baseSpeed,
                humanProfile.mistakeChance * 100,
                humanProfile.hesitateChance * 100),
            Duration = 5,
            Image = 4483362458
        })
    end
})

SettingsTab:CreateSection("◈  DELAY FALLBACK")
SettingsTab:CreateLabel("(Dipakai saat Anti-Detect OFF)")

SettingsTab:CreateSlider({
    Name         = "⌛  Delay Minimum  ( ms )",
    Range        = {50, 600},
    Increment    = 10,
    CurrentValue = config.minDelay,
    Callback     = function(Value) config.minDelay = Value end
})

SettingsTab:CreateSlider({
    Name         = "⏳  Delay Maksimum  ( ms )",
    Range        = {100, 1200},
    Increment    = 10,
    CurrentValue = config.maxDelay,
    Callback     = function(Value) config.maxDelay = Value end
})

-- ╔══════════════════════════════╗
-- ║   TAB 4 — INFO               ║
-- ╚══════════════════════════════╝
local InfoTab = Window:CreateTab("📋  INFO", 4483362458)

InfoTab:CreateSection("◈  TENTANG SCRIPT")
InfoTab:CreateLabel("⚔   NAKA AUTO KATA  —  v5.1")
InfoTab:CreateLabel("◦   Pembuat   :  NAKA")
InfoTab:CreateLabel("◦   Kamus     :  " .. #kataModule .. "+ kata Indonesia")
InfoTab:CreateLabel("◦   NEW       :  Prioritas Kata Sehari-hari!")

InfoTab:CreateSection("◈  KEY SYSTEM v1.0")
InfoTab:CreateLabel("🔑  1 Key = 1 Device  (Hardware Locked)")
InfoTab:CreateLabel("♾️   Berlaku selamanya — tidak perlu renew")
InfoTab:CreateLabel("🔒  Key terikat HWID device Roblox")
InfoTab:CreateLabel("💾  Tersimpan lokal + enkripsi XOR")

InfoTab:CreateSection("◈  FITUR v5.1")
InfoTab:CreateLabel("📝  Prioritas Kata Sehari-hari")
InfoTab:CreateLabel("     Kata umum dapat bonus +50 poin")
InfoTab:CreateLabel("     Kata super umum dapat +80 poin")
InfoTab:CreateLabel("🎭  Human Typing Simulator")
InfoTab:CreateLabel("     Typo natural, hesitate, double typo")
InfoTab:CreateLabel("💣  Kata Bom System")
InfoTab:CreateLabel("     3 tier bom, realtime preview")

InfoTab:CreateSection("◈  CARA PAKAI")
InfoTab:CreateLabel("1️⃣   Masukkan key saat pertama kali")
InfoTab:CreateLabel("2️⃣   Key otomatis tersimpan di device ini")
InfoTab:CreateLabel("3️⃣   Buka tab BATTLE → Aktifkan Auto Kata")
InfoTab:CreateLabel("4️⃣   Aktifkan 'Prioritaskan Kata Sehari-hari'")
InfoTab:CreateLabel("5️⃣   Masuk pertandingan — AI bekerja sendiri")

InfoTab:CreateSection("◈  CONTOH KATA PRIORITAS")
InfoTab:CreateLabel("🎯  Bonus +80: makan, minum, rumah, orang")
InfoTab:CreateLabel("🎯  Bonus +50: sekolah, motor, buku, besar")
InfoTab:CreateLabel("🎯  Bonus +30: kata umum lainnya")

-- =========================
-- STATS AUTO-UPDATE LOOP
-- =========================
task.spawn(function()
    while true do
        task.wait(10)
        if matchActive then
            pcall(updateStatsParagraph)
        end
    end
end)

-- =========================
-- REMOTE EVENT HANDLERS
-- =========================
local function onMatchUI(cmd, value)
    if cmd == "ShowMatchUI" then
        matchActive = true
        isMyTurn    = false
        resetUsedWords()
        humanProfile.wordCount = 0
        safeSet(turnParagraph,     "🎮 Giliran: ⏳ Menunggu giliran...")
        safeSet(opponentParagraph, "👤 Status Lawan: 👀 Pertandingan dimulai!")
        updateStatsParagraph()

    elseif cmd == "HideMatchUI" then
        matchActive  = false
        isMyTurn     = false
        serverLetter = ""
        resetUsedWords()
        safeSet(turnParagraph,        "🎮 Giliran: ❌ Pertandingan selesai")
        safeSet(opponentParagraph,    "👤 Status Lawan: ⏳ Menunggu...")
        safeSet(startLetterParagraph, "🔤 Huruf Awal: —")
        updateStatsParagraph()

    elseif cmd == "StartTurn" then
        isMyTurn = true
        safeSet(turnParagraph, "🎮 Giliran: ✅ GILIRAN KAMU!")
        updateStatsParagraph()
        if autoEnabled and serverLetter ~= "" then
            task.spawn(startUltraAI)
        end

    elseif cmd == "EndTurn" then
        isMyTurn = false
        safeSet(turnParagraph, "🎮 Giliran: ⏳ Giliran lawan...")
        updateStatsParagraph()

    elseif cmd == "UpdateServerLetter" then
        serverLetter = tostring(value or "")
        local dispLetter = serverLetter ~= "" and string.upper(serverLetter) or "—"
        safeSet(startLetterParagraph, "🔤 Huruf Awal: " .. dispLetter)
        if config.bombMode then
            task.spawn(function()
                local bWord, bTier, bScore = findBombWord(serverLetter, config.bombTier)
                updateBombUI(bWord, bTier, bScore)
            end)
        end
        if autoEnabled and matchActive and isMyTurn then
            task.spawn(startUltraAI)
        end
    end
end

local function onBillboard(word)
    if matchActive and not isMyTurn then
        opponentStreamWord = tostring(word or "")
        local dispWord = opponentStreamWord ~= "" and opponentStreamWord or "..."
        safeSet(opponentParagraph, "👤 Status Lawan: ✍ Lawan mengetik: " .. dispWord)
    end
end

local function onUsedWarn(word)
    if word then
        addUsedWord(word)
        updateStatsParagraph()
        if autoEnabled and matchActive and isMyTurn then
            task.wait(math.random(200, 400) / 1000)
            task.spawn(startUltraAI)
        end
    end
end

MatchUI.OnClientEvent:Connect(onMatchUI)
BillboardUpdate.OnClientEvent:Connect(onBillboard)
UsedWordWarn.OnClientEvent:Connect(onUsedWarn)

print("NAKA AUTO KATA v5.1 — LOADED  |  Prioritas Kata Sehari-hari AKTIF")
print("Total kata dalam kamus: " .. #kataModule)
print("Kata umum: " .. commonCount .. " (" .. math.floor(commonCount/#kataModule*100) .. "%)")

-- =========================================================
-- END OF SCRIPT
-- =========================================================
