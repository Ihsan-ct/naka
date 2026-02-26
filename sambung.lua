-- =========================================================
-- ULTRA SMART AUTO KATA v3.0 (ANTI LUAOBFUSCATOR BUILD)
-- Tambahan: Filter Akhiran Huruf, UI Lengkap, Anti-Detect
--           Improved, Scoring Accuracy System
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
if RayfieldSource == nil then
    warn("Gagal ambil Rayfield source")
    return
end

local RayfieldFunction = loadstr(RayfieldSource)
if RayfieldFunction == nil then
    warn("Gagal compile Rayfield")
    return
end

local Rayfield = RayfieldFunction()
if Rayfield == nil then
    warn("Rayfield return nil")
    return
end

print("Rayfield type:", typeof(Rayfield))

-- =========================
-- SERVICES
-- =========================
local GetService = game.GetService
local ReplicatedStorage = GetService(game, "ReplicatedStorage")
local Players = GetService(game, "Players")
local LocalPlayer = Players.LocalPlayer

-- =========================
-- LOAD WORDLIST
-- =========================
local kataModule = {}

local function downloadWordlist()
    local response = httpget(game, "https://raw.githubusercontent.com/danzzy1we/roblox-script-dump/refs/heads/main/WordListDump/Dump_IndonesianWords.lua")
    if not response then return false end

    local content = string.match(response, "return%s*(.+)")
    if not content then return false end

    content = string.gsub(content, "^%s*{", "")
    content = string.gsub(content, "}%s*$", "")

    for word in string.gmatch(content, '"([^"]+)"') do
        local w = string.lower(word)
        if string.len(w) > 1 then
            table.insert(kataModule, w)
        end
    end

    return true
end

local wordOk = downloadWordlist()
if not wordOk or #kataModule == 0 then
    warn("Wordlist gagal dimuat!")
    return
end

print("Wordlist Loaded:", #kataModule)

-- =========================
-- REMOTES
-- =========================
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local MatchUI       = remotes:WaitForChild("MatchUI")
local SubmitWord    = remotes:WaitForChild("SubmitWord")
local BillboardUpdate = remotes:WaitForChild("BillboardUpdate")
local BillboardEnd  = remotes:WaitForChild("BillboardEnd")
local TypeSound     = remotes:WaitForChild("TypeSound")
local UsedWordWarn  = remotes:WaitForChild("UsedWordWarn")

-- =========================
-- STATE
-- =========================
local matchActive       = false
local isMyTurn          = false
local serverLetter      = ""

local usedWords         = {}
local usedWordsList     = {}
local opponentStreamWord = ""

local autoEnabled       = false
local autoRunning       = false

-- =========================
-- STATISTIK
-- =========================
local stats = {
    totalWords  = 0,
    matchWins   = 0,
    matchLosses = 0,
    longestWord = "",
    sessionStart = os.time()
}

-- =========================
-- KONFIGURASI
-- =========================
local config = {
    minDelay        = 500,
    maxDelay        = 750,
    aggression      = 20,
    minLength       = 3,
    maxLength       = 12,
    filterEnding    = "semua",   -- huruf akhiran filter, "semua" = tidak difilter
    antiDetectMode  = true,      -- variasi delay lebih natural
    preferRare      = false,     -- pilih kata jarang dulu
}

-- =========================
-- ANTI-DETECT: DELAY NATURAL
-- =========================
-- Menyimulasikan pola ketik manusia: kadang cepat, kadang lambat, kadang typo-pause

local function naturalDelay(charIndex, wordLength)
    local base = math.random(config.minDelay, config.maxDelay)

    if config.antiDetectMode then
        -- Simulasi manusia membaca kata di awal
        if charIndex == 1 then
            base = base + math.random(80, 200)
        end

        -- Simulasi sedikit ragu di tengah kata panjang
        if wordLength > 7 and charIndex == math.floor(wordLength / 2) then
            base = base + math.random(50, 150)
        end

        -- Variasi micro-burst: sesekali ketik cepat beruntun
        if math.random(1, 10) <= 2 then
            base = math.floor(base * 0.5)
        end

        -- Variasi micro-pause: sesekali sedikit lebih lambat
        if math.random(1, 10) == 1 then
            base = base + math.random(100, 300)
        end
    end

    -- Pastikan dalam batas aman
    if base < 50 then base = 50 end

    task.wait(base / 1000)
end

local function preSubmitDelay()
    -- Jeda sebelum submit: simulasi membaca ulang
    if config.antiDetectMode then
        task.wait(math.random(200, 500) / 1000)
    else
        task.wait(math.random(config.minDelay, config.maxDelay) / 1000)
    end
end

-- =========================
-- SCORING SYSTEM (AKURASI)
-- =========================
-- Scoring kata: lebih panjang + akhiran yang membuat lawan susah = skor lebih tinggi

local HARD_ENDINGS = {
    -- Akhiran yang jarang jadi awalan kata lain = susah untuk lawan
    ["x"] = 10, ["q"] = 10, ["f"] = 8, ["v"] = 8,
    ["z"] = 9,  ["y"] = 6,  ["w"] = 5, ["j"] = 7,
    ["k"] = 4,  ["h"] = 3,
}

local function scoreWord(word)
    local score = 0
    local len = string.len(word)

    -- Skor dari panjang kata
    score = score + (len * 2)

    -- Bonus kata sangat panjang
    if len >= 9 then score = score + 15 end
    if len >= 12 then score = score + 20 end

    -- Skor dari akhiran yang susah
    local lastChar = string.sub(word, -1)
    if HARD_ENDINGS[lastChar] ~= nil then
        score = score + HARD_ENDINGS[lastChar]
    end

    return score
end

-- =========================
-- FILTER & PENCARIAN KATA
-- =========================
local usedWordsDropdown = nil

local function isUsed(word)
    return usedWords[string.lower(word)] == true
end

local function addUsedWord(word)
    local w = string.lower(word)
    if usedWords[w] == nil then
        usedWords[w] = true
        table.insert(usedWordsList, word)
        if usedWordsDropdown ~= nil then
            usedWordsDropdown:Set(usedWordsList)
        end
        -- Update statistik
        stats.totalWords = stats.totalWords + 1
        if string.len(word) > string.len(stats.longestWord) then
            stats.longestWord = word
        end
    end
end

local function resetUsedWords()
    usedWords = {}
    usedWordsList = {}
    if usedWordsDropdown ~= nil then
        usedWordsDropdown:Set({})
    end
end

local function getSmartWords(prefix)
    local results = {}
    local lowerPrefix = string.lower(prefix)
    local filterEnd = string.lower(config.filterEnding)

    for i = 1, #kataModule do
        local word = kataModule[i]
        if string.sub(word, 1, #lowerPrefix) == lowerPrefix then
            if not isUsed(word) then
                local len = string.len(word)
                if len >= config.minLength and len <= config.maxLength then

                    -- === FILTER AKHIRAN HURUF ===
                    local passFilter = true
                    if filterEnd ~= "semua" and filterEnd ~= "" then
                        local wordEnd = string.sub(word, -1)
                        if wordEnd ~= filterEnd then
                            passFilter = false
                        end
                    end

                    if passFilter then
                        table.insert(results, word)
                    end
                end
            end
        end
    end

    -- === SORTING BERDASARKAN SKOR (AKURASI) ===
    table.sort(results, function(a, b)
        return scoreWord(a) > scoreWord(b)
    end)

    return results
end

-- =========================
-- AUTO ENGINE
-- =========================
local function startUltraAI()
    if autoRunning then return end
    if not autoEnabled then return end
    if not matchActive then return end
    if not isMyTurn then return end
    if serverLetter == "" then return end

    autoRunning = true

    -- Jeda awal sebelum mulai (natural)
    task.wait(math.random(config.minDelay, config.maxDelay) / 1000)

    local words = getSmartWords(serverLetter)
    if #words == 0 then
        -- Fallback: coba tanpa filter akhiran
        if config.filterEnding ~= "semua" then
            local oldFilter = config.filterEnding
            config.filterEnding = "semua"
            words = getSmartWords(serverLetter)
            config.filterEnding = oldFilter
        end

        if #words == 0 then
            autoRunning = false
            return
        end
    end

    -- Pilih kata berdasarkan aggression + scoring
    local selectedWord = words[1]

    if config.aggression < 100 then
        local topN = math.floor(#words * (1 - config.aggression / 100))
        if topN < 1 then topN = 1 end
        if topN > #words then topN = #words end

        if config.preferRare then
            -- Pilih dari bawah top (kata lebih jarang)
            selectedWord = words[math.random(math.max(1, topN - 3), topN)]
        else
            selectedWord = words[math.random(1, topN)]
        end
    end

    -- Ketik karakter per karakter
    local currentWord = serverLetter
    local remain = string.sub(selectedWord, #serverLetter + 1)
    local remainLen = string.len(remain)

    for i = 1, remainLen do
        if not matchActive or not isMyTurn then
            autoRunning = false
            return
        end

        currentWord = currentWord .. string.sub(remain, i, i)
        TypeSound:FireServer()
        BillboardUpdate:FireServer(currentWord)
        naturalDelay(i, remainLen)
    end

    preSubmitDelay()

    SubmitWord:FireServer(selectedWord)
    addUsedWord(selectedWord)

    task.wait(math.random(100, 300) / 1000)
    BillboardEnd:FireServer()

    autoRunning = false
end

-- =========================
-- BUILD UI
-- =========================
local Window = Rayfield:CreateWindow({
    Name = "🔥 NAKA AUTO KATA v3.0",
    LoadingTitle = "Memuat Sistem NAKA",
    LoadingSubtitle = "AI Penjawab Kata Otomatis",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "NAKA",
        FileName = "AutoKata"
    },
    Discord = { Enabled = false },
    KeySystem = false
})

Rayfield:LoadConfiguration()

Rayfield:Notify({
    Title = "✅ NAKA v3.0 Siap",
    Content = "Auto Kata + Filter Akhiran + Anti-Detect berhasil dimuat",
    Duration = 6,
    Image = 4483362458
})

-- ==============================
-- TAB 1: PENGATURAN UTAMA
-- ==============================
local MainTab = Window:CreateTab("🎮 UTAMA", 4483362458)

-- ---- SECTION: AUTO KATA ----
MainTab:CreateSection("🤖 AUTO KATA")

MainTab:CreateToggle({
    Name = "🔥 Aktifkan Auto Kata",
    CurrentValue = false,
    Callback = function(Value)
        autoEnabled = Value
        if Value then
            startUltraAI()
        end
    end
})

-- ---- SECTION: FILTER AKHIRAN ----
MainTab:CreateSection("🔚 FILTER AKHIRAN HURUF")

MainTab:CreateParagraph({
    Title = "ℹ Cara Kerja Filter",
    Content =
        "Pilih huruf akhiran untuk memaksa AI memilih kata yang berakhiran huruf tersebut.\n" ..
        "Contoh: pilih 'k' maka AI akan selalu mencari kata berakhiran 'k'.\n" ..
        "Pilih 'Semua' untuk menonaktifkan filter."
})

local endingOptions = {
    "Semua", "a", "i", "u", "e", "o",
    "n", "r", "s", "t", "k", "h",
    "l", "m", "p", "g", "j", "f",
    "v", "z", "x", "q", "w", "y"
}

MainTab:CreateDropdown({
    Name = "🔚 Pilih Akhiran Huruf",
    Options = endingOptions,
    CurrentOption = {"Semua"},
    MultipleOptions = false,
    Callback = function(Value)
        local v = Value
        if type(v) == "table" then v = v[1] end
        if v == nil then v = "Semua" end
        config.filterEnding = string.lower(v)
        Rayfield:Notify({
            Title = "🔚 Filter Akhiran",
            Content = "Filter akhiran diset ke: " .. tostring(v),
            Duration = 3,
            Image = 4483362458
        })
    end
})

MainTab:CreateToggle({
    Name = "⚡ Auto Fallback (jika kata berakhiran tidak ada)",
    CurrentValue = true,
    Callback = function(Value)
        -- Auto fallback sudah built-in, toggle ini sebagai info visual
        -- Fallback selalu aktif di engine untuk keamanan
    end
})

-- ==============================
-- TAB 2: KECERDASAN AI
-- ==============================
local AITab = Window:CreateTab("🧠 KECERDASAN AI", 4483362458)

AITab:CreateSection("⚙ PARAMETER KATA")

AITab:CreateSlider({
    Name = "⚡ Tingkat Agresif",
    Range = {0, 100},
    Increment = 5,
    CurrentValue = config.aggression,
    Callback = function(Value)
        config.aggression = Value
    end
})

AITab:CreateSlider({
    Name = "🔤 Panjang Kata Minimum",
    Range = {2, 6},
    Increment = 1,
    CurrentValue = config.minLength,
    Callback = function(Value)
        config.minLength = Value
    end
})

AITab:CreateSlider({
    Name = "🔠 Panjang Kata Maksimum",
    Range = {5, 20},
    Increment = 1,
    CurrentValue = config.maxLength,
    Callback = function(Value)
        config.maxLength = Value
    end
})

AITab:CreateSection("🎯 STRATEGI PILIH KATA")

AITab:CreateParagraph({
    Title = "📖 Penjelasan Scoring",
    Content =
        "AI menggunakan sistem scoring untuk memilih kata terbaik:\n\n" ..
        "• Panjang kata → skor lebih tinggi\n" ..
        "• Akhiran susah (x, q, z, j, v) → skor bonus tinggi\n" ..
        "• Tujuan: membuat lawan kesulitan menemukan kata berikutnya"
})

AITab:CreateToggle({
    Name = "🃏 Mode Kata Langka (Pilih Kata Jarang)",
    CurrentValue = false,
    Callback = function(Value)
        config.preferRare = Value
    end
})

-- ==============================
-- TAB 3: ANTI DETECT
-- ==============================
local AntiTab = Window:CreateTab("🛡 ANTI DETECT", 4483362458)

AntiTab:CreateSection("🕵 SIMULASI MANUSIA")

AntiTab:CreateParagraph({
    Title = "🛡 Cara Kerja Anti-Detect",
    Content =
        "Sistem ini mensimulasikan pola ketik manusia nyata:\n\n" ..
        "• Jeda lebih lama di huruf pertama (membaca kata)\n" ..
        "• Variasi kecepatan di tengah kata panjang\n" ..
        "• Micro-burst: kadang ketik cepat\n" ..
        "• Micro-pause: kadang sedikit ragu\n" ..
        "• Jeda pra-submit: simulasi membaca ulang\n\n" ..
        "⚠ Gunakan delay 400ms+ untuk keamanan optimal"
})

AntiTab:CreateToggle({
    Name = "🛡 Aktifkan Mode Anti-Detect",
    CurrentValue = true,
    Callback = function(Value)
        config.antiDetectMode = Value
        Rayfield:Notify({
            Title = "🛡 Anti-Detect",
            Content = Value and "Anti-Detect AKTIF" or "Anti-Detect NONAKTIF",
            Duration = 3,
            Image = 4483362458
        })
    end
})

AntiTab:CreateSection("⏱ JEDA KETIK DASAR")

AntiTab:CreateSlider({
    Name = "⌛ Jeda Minimum (ms)",
    Range = {50, 600},
    Increment = 10,
    CurrentValue = config.minDelay,
    Callback = function(Value)
        config.minDelay = Value
    end
})

AntiTab:CreateSlider({
    Name = "⏳ Jeda Maksimum (ms)",
    Range = {100, 1200},
    Increment = 10,
    CurrentValue = config.maxDelay,
    Callback = function(Value)
        config.maxDelay = Value
    end
})

AntiTab:CreateSection("⚠ LEVEL RISIKO")

AntiTab:CreateParagraph({
    Title = "🔴 Panduan Keamanan Delay",
    Content =
        "🟢 AMAN       → 500ms – 800ms\n" ..
        "🟡 SEDANG   → 300ms – 499ms\n" ..
        "🔴 BERISIKO → 50ms  – 299ms\n\n" ..
        "Semakin rendah delay, semakin berisiko terdeteksi.\n" ..
        "Disarankan aktifkan Anti-Detect Mode pada delay rendah."
})

-- ==============================
-- TAB 4: STATISTIK & INFO MATCH
-- ==============================
local StatsTab = Window:CreateTab("📊 STATISTIK", 4483362458)

StatsTab:CreateSection("🏆 STATISTIK SESI")

local statsParagraph = StatsTab:CreateParagraph({
    Title = "📈 Performa Sesi Ini",
    Content = "⏳ Belum ada data..."
})

local function updateStatsParagraph()
    local elapsed = os.time() - stats.sessionStart
    local minutes = math.floor(elapsed / 60)
    local seconds = elapsed % 60
    statsParagraph:Set(
        "📈 Performa Sesi Ini",
        "🔤 Kata Dikirim  : " .. stats.totalWords .. "\n" ..
        "🏆 Kata Terpanjang : " .. (stats.longestWord ~= "" and stats.longestWord or "—") .. "\n" ..
        "⏱ Durasi Sesi    : " .. minutes .. "m " .. seconds .. "s"
    )
end

StatsTab:CreateButton({
    Name = "🔄 Refresh Statistik",
    Callback = function()
        updateStatsParagraph()
        Rayfield:Notify({
            Title = "📊 Statistik",
            Content = "Data diperbarui!",
            Duration = 2,
            Image = 4483362458
        })
    end
})

StatsTab:CreateButton({
    Name = "🗑 Reset Statistik",
    Callback = function()
        stats.totalWords  = 0
        stats.longestWord = ""
        stats.sessionStart = os.time()
        updateStatsParagraph()
        Rayfield:Notify({
            Title = "🗑 Reset",
            Content = "Statistik direset!",
            Duration = 3,
            Image = 4483362458
        })
    end
})

StatsTab:CreateSection("📚 KATA YANG SUDAH DIPAKAI")

usedWordsDropdown = StatsTab:CreateDropdown({
    Name = "📚 Daftar Kata Terpakai",
    Options = usedWordsList,
    CurrentOption = {},
    MultipleOptions = false,
    Callback = function() end
})

StatsTab:CreateButton({
    Name = "🗑 Reset Daftar Kata",
    Callback = function()
        resetUsedWords()
        Rayfield:Notify({
            Title = "🗑 Reset",
            Content = "Daftar kata direset!",
            Duration = 3,
            Image = 4483362458
        })
    end
})

StatsTab:CreateSection("🎯 STATUS PERTANDINGAN")

local opponentParagraph = StatsTab:CreateParagraph({
    Title = "👤 Status Lawan",
    Content = "⏳ Menunggu pertandingan..."
})

local startLetterParagraph = StatsTab:CreateParagraph({
    Title = "🔤 Huruf Awal Server",
    Content = "—"
})

local turnParagraph = StatsTab:CreateParagraph({
    Title = "🎮 Giliran",
    Content = "⏳ Menunggu..."
})

-- ==============================
-- TAB 5: TENTANG & PANDUAN
-- ==============================
local AboutTab = Window:CreateTab("ℹ TENTANG", 4483362458)

AboutTab:CreateSection("📜 INFORMASI")

AboutTab:CreateParagraph({
    Title = "🔥 NAKA AUTO KATA v3.0",
    Content =
        "Versi  : 3.0\n" ..
        "Pembuat: NAKA\n\n" ..
        "Fitur Baru v3.0:\n" ..
        "• Filter akhiran huruf (AI pilih kata berakhiran X)\n" ..
        "• Scoring system (pilih kata yang bikin lawan susah)\n" ..
        "• Anti-detect natural delay (pola ketik manusia nyata)\n" ..
        "• Statistik sesi (kata terkirim, kata terpanjang, durasi)\n" ..
        "• Tab UI terpisah & lebih lengkap\n\n" ..
        "Kamus kata oleh:\n" ..
        "danzzy1we"
})

AboutTab:CreateSection("📖 CARA PAKAI")

AboutTab:CreateParagraph({
    Title = "🎮 Langkah Penggunaan",
    Content =
        "1️⃣ Atur filter akhiran huruf (tab UTAMA)\n" ..
        "2️⃣ Atur kecerdasan AI (tab KECERDASAN AI)\n" ..
        "3️⃣ Aktifkan Anti-Detect Mode (tab ANTI DETECT)\n" ..
        "4️⃣ Aktifkan 'Auto Kata' (tab UTAMA)\n" ..
        "5️⃣ Masuk ke pertandingan\n" ..
        "6️⃣ AI akan bermain otomatis!"
})

AboutTab:CreateSection("⚠ CATATAN PENTING")

AboutTab:CreateParagraph({
    Title = "🛑 Perhatikan",
    Content =
        "• Gunakan internet stabil\n" ..
        "• Jangan spam toggle on/off\n" ..
        "• Filter akhiran otomatis fallback jika tidak ada kata\n" ..
        "• Jika error → jalankan ulang script\n" ..
        "• Delay 500ms+ sangat disarankan untuk keamanan"
})

-- =========================
-- REMOTE EVENT HANDLERS
-- =========================
local function onMatchUI(cmd, value)

    if cmd == "ShowMatchUI" then
        matchActive = true
        isMyTurn    = false
        resetUsedWords()
        turnParagraph:Set("🎮 Giliran", "⏳ Menunggu giliran...")
        opponentParagraph:Set("👤 Status Lawan", "👀 Pertandingan dimulai!")

    elseif cmd == "HideMatchUI" then
        matchActive  = false
        isMyTurn     = false
        serverLetter = ""
        resetUsedWords()
        turnParagraph:Set("🎮 Giliran", "❌ Pertandingan selesai")
        opponentParagraph:Set("👤 Status Lawan", "⏳ Menunggu pertandingan...")
        startLetterParagraph:Set("🔤 Huruf Awal Server", "—")
        updateStatsParagraph()

    elseif cmd == "StartTurn" then
        isMyTurn = true
        turnParagraph:Set("🎮 Giliran", "✅ GILIRAN KAMU!")
        if autoEnabled then
            task.spawn(startUltraAI)
        end

    elseif cmd == "EndTurn" then
        isMyTurn = false
        turnParagraph:Set("🎮 Giliran", "⏳ Giliran lawan...")

    elseif cmd == "UpdateServerLetter" then
        serverLetter = value or ""
        startLetterParagraph:Set("🔤 Huruf Awal Server", "Huruf: " .. string.upper(serverLetter))
    end
end

local function onBillboard(word)
    if matchActive and not isMyTurn then
        opponentStreamWord = word or ""
        opponentParagraph:Set(
            "👤 Status Lawan",
            "✍ Lawan mengetik: " .. opponentStreamWord
        )
    end
end

local function onUsedWarn(word)
    if word then
        addUsedWord(word)
        if autoEnabled and matchActive and isMyTurn then
            task.wait(math.random(200, 400) / 1000)
            task.spawn(startUltraAI)
        end
    end
end

MatchUI.OnClientEvent:Connect(onMatchUI)
BillboardUpdate.OnClientEvent:Connect(onBillboard)
UsedWordWarn.OnClientEvent:Connect(onUsedWarn)

print("NAKA AUTO KATA v3.0 — LOADED SUCCESSFULLY")
