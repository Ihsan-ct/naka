-- =========================================================
-- ULTRA SMART AUTO KATA v3.1 (ANTI LUAOBFUSCATOR BUILD)
-- Fix: Statistik realtime, Auto Watcher Loop, safeSet order
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

print("Rayfield type:", typeof(Rayfield))

-- =========================
-- SERVICES
-- =========================
local GetService        = game.GetService
local ReplicatedStorage = GetService(game, "ReplicatedStorage")
local Players           = GetService(game, "Players")
local LocalPlayer       = Players.LocalPlayer

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
    filterEnding   = "semua",
    antiDetectMode = true,
    preferRare     = false,
}

-- =========================
-- SAFE SET
-- HARUS DIDEFINISIKAN PALING ATAS sebelum fungsi lain
-- Rayfield Paragraph:Set() hanya terima 1 argumen string
-- =========================
local function safeSet(paragraph, content)
    if paragraph == nil then return end
    local safe = tostring(content or "")
    pcall(function()
        paragraph:Set(safe)
    end)
end

-- =========================
-- ANTI-DETECT: DELAY NATURAL
-- =========================
local function naturalDelay(charIndex, wordLength)
    local base = math.random(config.minDelay, config.maxDelay)
    if config.antiDetectMode then
        if charIndex == 1 then
            base = base + math.random(80, 200)
        end
        if wordLength > 7 and charIndex == math.floor(wordLength / 2) then
            base = base + math.random(50, 150)
        end
        if math.random(1, 10) <= 2 then
            base = math.floor(base * 0.5)
        end
        if math.random(1, 10) == 1 then
            base = base + math.random(100, 300)
        end
    end
    if base < 50 then base = 50 end
    task.wait(base / 1000)
end

local function preSubmitDelay()
    if config.antiDetectMode then
        task.wait(math.random(200, 500) / 1000)
    else
        task.wait(math.random(config.minDelay, config.maxDelay) / 1000)
    end
end

-- =========================
-- SCORING SYSTEM
-- =========================
local HARD_ENDINGS = {
    ["x"]=10, ["q"]=10, ["f"]=8, ["v"]=8,
    ["z"]=9,  ["y"]=6,  ["w"]=5, ["j"]=7,
    ["k"]=4,  ["h"]=3,
}

local function scoreWord(word)
    local score = 0
    local len   = string.len(word)
    score = score + (len * 2)
    if len >= 9  then score = score + 15 end
    if len >= 12 then score = score + 20 end
    local lastChar = string.sub(word, -1)
    if HARD_ENDINGS[lastChar] then
        score = score + HARD_ENDINGS[lastChar]
    end
    return score
end

-- =========================
-- WORD MANAGEMENT
-- =========================
local usedWordsDropdown = nil

local function isUsed(word)
    return usedWords[string.lower(word)] == true
end

local function addUsedWord(word)
    if not word then return end
    local w = string.lower(tostring(word))
    if not usedWords[w] then
        usedWords[w] = true
        table.insert(usedWordsList, w)
        if usedWordsDropdown ~= nil then
            pcall(function() usedWordsDropdown:Set(usedWordsList) end)
        end
        stats.totalWords = (stats.totalWords or 0) + 1
        local longest = tostring(stats.longestWord or "")
        if string.len(w) > string.len(longest) then
            stats.longestWord = w
        end
    end
end

local function resetUsedWords()
    usedWords     = {}
    usedWordsList = {}
    if usedWordsDropdown ~= nil then
        pcall(function() usedWordsDropdown:Set({" "}) end)
    end
end

local function getSmartWords(prefix)
    local results     = {}
    local lowerPrefix = string.lower(prefix)
    local filterEnd   = string.lower(config.filterEnding)

    for i = 1, #kataModule do
        local word = kataModule[i]
        if string.sub(word, 1, #lowerPrefix) == lowerPrefix and not isUsed(word) then
            local len = string.len(word)
            if len >= config.minLength and len <= config.maxLength then
                local passFilter = true
                if filterEnd ~= "semua" and filterEnd ~= "" then
                    if string.sub(word, -1) ~= filterEnd then
                        passFilter = false
                    end
                end
                if passFilter then
                    table.insert(results, word)
                end
            end
        end
    end

    table.sort(results, function(a, b)
        return scoreWord(a) > scoreWord(b)
    end)
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

    local words = getSmartWords(serverLetter)
    if #words == 0 then
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

    local selectedWord = words[1]
    if config.aggression < 100 then
        local topN = math.floor(#words * (1 - config.aggression / 100))
        if topN < 1 then topN = 1 end
        if topN > #words then topN = #words end
        if config.preferRare then
            selectedWord = words[math.random(math.max(1, topN - 3), topN)]
        else
            selectedWord = words[math.random(1, topN)]
        end
    end

    local currentWord = serverLetter
    local remain      = string.sub(selectedWord, #serverLetter + 1)
    local remainLen   = string.len(remain)

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
-- AUTO WATCHER LOOP
-- Polling 0.3 detik — trigger AI jika kondisi lengkap
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

-- =========================
-- BUILD UI
-- =========================
local Window = Rayfield:CreateWindow({
    Name = "🔥 NAKA AUTO KATA v3.1",
    LoadingTitle    = "Memuat Sistem NAKA",
    LoadingSubtitle = "AI Penjawab Kata Otomatis",
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
    Title    = "✅ NAKA v3.1 Siap",
    Content  = "Auto Kata + Filter Akhiran + Anti-Detect dimuat!",
    Duration = 5,
    Image    = 4483362458
})

-- ==============================
-- TAB 1: PENGATURAN UTAMA
-- ==============================
local MainTab = Window:CreateTab("🎮 UTAMA", 4483362458)

MainTab:CreateSection("🤖 AUTO KATA")

MainTab:CreateToggle({
    Name         = "🔥 Aktifkan Auto Kata",
    CurrentValue = false,
    Callback     = function(Value)
        autoEnabled = Value
        if Value then
            Rayfield:Notify({
                Title    = "🤖 Auto Kata",
                Content  = "Auto Kata AKTIF — AI siap bermain!",
                Duration = 3,
                Image    = 4483362458
            })
            if matchActive and isMyTurn and serverLetter ~= "" then
                task.spawn(startUltraAI)
            end
        else
            Rayfield:Notify({
                Title    = "🤖 Auto Kata",
                Content  = "Auto Kata NONAKTIF",
                Duration = 3,
                Image    = 4483362458
            })
        end
    end
})

MainTab:CreateSection("🔚 FILTER AKHIRAN HURUF")

MainTab:CreateParagraph({
    Title   = "ℹ Cara Kerja Filter",
    Content =
        "Pilih huruf akhiran untuk memaksa AI memilih kata berakhiran huruf tersebut.\n" ..
        "Pilih 'Semua' untuk menonaktifkan filter.\n" ..
        "Jika tidak ada kata, AI otomatis fallback ke semua kata."
})

MainTab:CreateDropdown({
    Name            = "🔚 Pilih Akhiran Huruf",
    Options         = {"Semua","a","i","u","e","o","n","r","s","t","k","h","l","m","p","g","j","f","v","z","x","q","w","y"},
    CurrentOption   = {"Semua"},
    MultipleOptions = false,
    Callback        = function(Value)
        local v = type(Value) == "table" and Value[1] or Value
        config.filterEnding = string.lower(tostring(v or "semua"))
        Rayfield:Notify({
            Title    = "🔚 Filter Akhiran",
            Content  = "Diset ke: " .. tostring(v),
            Duration = 3,
            Image    = 4483362458
        })
    end
})

-- ==============================
-- TAB 2: KECERDASAN AI
-- ==============================
local AITab = Window:CreateTab("🧠 KECERDASAN AI", 4483362458)

AITab:CreateSection("⚙ PARAMETER KATA")

AITab:CreateSlider({
    Name         = "⚡ Tingkat Agresif",
    Range        = {0, 100},
    Increment    = 5,
    CurrentValue = config.aggression,
    Callback     = function(Value) config.aggression = Value end
})

AITab:CreateSlider({
    Name         = "🔤 Panjang Kata Minimum",
    Range        = {2, 6},
    Increment    = 1,
    CurrentValue = config.minLength,
    Callback     = function(Value) config.minLength = Value end
})

AITab:CreateSlider({
    Name         = "🔠 Panjang Kata Maksimum",
    Range        = {5, 20},
    Increment    = 1,
    CurrentValue = config.maxLength,
    Callback     = function(Value) config.maxLength = Value end
})

AITab:CreateSection("🎯 STRATEGI")

AITab:CreateParagraph({
    Title   = "📖 Sistem Scoring",
    Content =
        "AI menilai setiap kata dengan skor:\n" ..
        "• Panjang kata → skor lebih tinggi\n" ..
        "• Akhiran susah (x, q, z, j, v) → bonus skor\n" ..
        "• Tujuan: bikin lawan kesulitan cari kata berikutnya"
})

AITab:CreateToggle({
    Name         = "🃏 Mode Kata Langka",
    CurrentValue = false,
    Callback     = function(Value) config.preferRare = Value end
})

-- ==============================
-- TAB 3: ANTI DETECT
-- ==============================
local AntiTab = Window:CreateTab("🛡 ANTI DETECT", 4483362458)

AntiTab:CreateSection("🕵 SIMULASI MANUSIA")

AntiTab:CreateParagraph({
    Title   = "🛡 Cara Kerja Anti-Detect",
    Content =
        "• Jeda lebih lama di huruf pertama (simulasi membaca)\n" ..
        "• Variasi kecepatan di tengah kata panjang\n" ..
        "• Micro-burst: kadang ketik cepat\n" ..
        "• Micro-pause: kadang sedikit ragu\n" ..
        "• Jeda pra-submit: simulasi baca ulang\n\n" ..
        "⚠ Gunakan delay 400ms+ untuk keamanan optimal"
})

AntiTab:CreateToggle({
    Name         = "🛡 Aktifkan Mode Anti-Detect",
    CurrentValue = true,
    Callback     = function(Value)
        config.antiDetectMode = Value
        Rayfield:Notify({
            Title    = "🛡 Anti-Detect",
            Content  = Value and "Anti-Detect AKTIF" or "Anti-Detect NONAKTIF",
            Duration = 3,
            Image    = 4483362458
        })
    end
})

AntiTab:CreateSection("⏱ JEDA KETIK")

AntiTab:CreateSlider({
    Name         = "⌛ Jeda Minimum (ms)",
    Range        = {50, 600},
    Increment    = 10,
    CurrentValue = config.minDelay,
    Callback     = function(Value) config.minDelay = Value end
})

AntiTab:CreateSlider({
    Name         = "⏳ Jeda Maksimum (ms)",
    Range        = {100, 1200},
    Increment    = 10,
    CurrentValue = config.maxDelay,
    Callback     = function(Value) config.maxDelay = Value end
})

AntiTab:CreateSection("⚠ PANDUAN DELAY")

AntiTab:CreateParagraph({
    Title   = "🔴 Level Risiko",
    Content =
        "🟢 AMAN       → 500ms – 800ms\n" ..
        "🟡 SEDANG   → 300ms – 499ms\n" ..
        "🔴 BERISIKO → 50ms  – 299ms\n\n" ..
        "Semakin rendah delay, semakin berisiko terdeteksi."
})

-- ==============================
-- TAB 4: STATISTIK
-- ==============================
local StatsTab = Window:CreateTab("📊 STATISTIK", 4483362458)

StatsTab:CreateSection("🏆 STATISTIK SESI")

local statsParagraph = StatsTab:CreateParagraph({
    Title   = "📈 Performa Sesi Ini",
    Content = "⏳ Belum ada data..."
})

-- updateStatsParagraph: safeSet sudah terdefinisi di atas
local function updateStatsParagraph()
    local elapsed        = os.time() - (stats.sessionStart or os.time())
    local minutes        = math.floor(elapsed / 60)
    local seconds        = elapsed % 60
    local longest        = tostring(stats.longestWord or "")
    local displayLongest = (longest ~= "") and longest or "—"
    local content =
        "🔤 Kata Dikirim    : " .. tostring(stats.totalWords or 0) .. "\n" ..
        "🏆 Kata Terpanjang : " .. displayLongest .. "\n" ..
        "⏱ Durasi Sesi     : " .. tostring(minutes) .. "m " .. tostring(seconds) .. "s"
    safeSet(statsParagraph, content)
end

StatsTab:CreateButton({
    Name     = "🔄 Refresh Statistik",
    Callback = function()
        updateStatsParagraph()
        Rayfield:Notify({
            Title    = "📊 Statistik",
            Content  = "Data diperbarui!",
            Duration = 2,
            Image    = 4483362458
        })
    end
})

StatsTab:CreateButton({
    Name     = "🗑 Reset Statistik",
    Callback = function()
        stats.totalWords   = 0
        stats.longestWord  = ""
        stats.sessionStart = os.time()
        updateStatsParagraph()
        Rayfield:Notify({
            Title    = "🗑 Reset",
            Content  = "Statistik direset!",
            Duration = 3,
            Image    = 4483362458
        })
    end
})

StatsTab:CreateSection("📚 KATA TERPAKAI")

usedWordsDropdown = StatsTab:CreateDropdown({
    Name            = "📚 Daftar Kata Terpakai",
    Options         = {" "},
    CurrentOption   = {},
    MultipleOptions = false,
    Callback        = function() end
})

StatsTab:CreateButton({
    Name     = "🗑 Reset Daftar Kata",
    Callback = function()
        resetUsedWords()
        Rayfield:Notify({
            Title    = "🗑 Reset",
            Content  = "Daftar kata direset!",
            Duration = 3,
            Image    = 4483362458
        })
    end
})

StatsTab:CreateSection("🎯 STATUS PERTANDINGAN")

local opponentParagraph = StatsTab:CreateParagraph({
    Title   = "👤 Status Lawan",
    Content = "⏳ Menunggu pertandingan..."
})

local startLetterParagraph = StatsTab:CreateParagraph({
    Title   = "🔤 Huruf Awal Server",
    Content = "—"
})

local turnParagraph = StatsTab:CreateParagraph({
    Title   = "🎮 Giliran",
    Content = "⏳ Menunggu..."
})

-- ==============================
-- TAB 5: TENTANG
-- ==============================
local AboutTab = Window:CreateTab("ℹ TENTANG", 4483362458)

AboutTab:CreateSection("📜 INFORMASI")

AboutTab:CreateParagraph({
    Title   = "🔥 NAKA AUTO KATA v3.1",
    Content =
        "Versi  : 3.1\n" ..
        "Pembuat: NAKA\n\n" ..
        "Changelog v3.1:\n" ..
        "• Fix statistik realtime (auto-update tiap event)\n" ..
        "• Auto Watcher Loop (tidak perlu on/off manual)\n" ..
        "• Fix safeSet urutan definisi\n" ..
        "• Fix semua nil paragraph error\n\n" ..
        "Kamus kata oleh: danzzy1we"
})

AboutTab:CreateSection("📖 CARA PAKAI")

AboutTab:CreateParagraph({
    Title   = "🎮 Langkah",
    Content =
        "1️⃣ Aktifkan 'Auto Kata' (tab UTAMA)\n" ..
        "2️⃣ Atur filter akhiran huruf jika perlu\n" ..
        "3️⃣ Atur kecerdasan AI (tab KECERDASAN AI)\n" ..
        "4️⃣ Masuk ke pertandingan\n" ..
        "5️⃣ AI otomatis bermain saat giliran kamu!"
})

AboutTab:CreateSection("⚠ CATATAN")

AboutTab:CreateParagraph({
    Title   = "🛑 Penting",
    Content =
        "• Gunakan internet stabil\n" ..
        "• Delay 500ms+ sangat disarankan\n" ..
        "• Filter akhiran auto-fallback jika tidak ada kata\n" ..
        "• Jika error → jalankan ulang script"
})

-- =========================
-- STATS AUTO-UPDATE LOOP
-- Update statistik otomatis setiap 10 detik saat match aktif
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
        safeSet(turnParagraph,     "⏳ Menunggu giliran...")
        safeSet(opponentParagraph, "👀 Pertandingan dimulai!")
        updateStatsParagraph()

    elseif cmd == "HideMatchUI" then
        matchActive  = false
        isMyTurn     = false
        serverLetter = ""
        resetUsedWords()
        safeSet(turnParagraph,        "❌ Pertandingan selesai")
        safeSet(opponentParagraph,    "⏳ Menunggu pertandingan...")
        safeSet(startLetterParagraph, "Huruf: —")
        updateStatsParagraph()

    elseif cmd == "StartTurn" then
        isMyTurn = true
        safeSet(turnParagraph, "✅ GILIRAN KAMU!")
        updateStatsParagraph()
        if autoEnabled and serverLetter ~= "" then
            task.spawn(startUltraAI)
        end

    elseif cmd == "EndTurn" then
        isMyTurn = false
        safeSet(turnParagraph, "⏳ Giliran lawan...")
        updateStatsParagraph()

    elseif cmd == "UpdateServerLetter" then
        serverLetter = tostring(value or "")
        local displayLetter = (serverLetter ~= "") and string.upper(serverLetter) or "—"
        safeSet(startLetterParagraph, "Huruf: " .. displayLetter)
        if autoEnabled and matchActive and isMyTurn then
            task.spawn(startUltraAI)
        end
    end
end

local function onBillboard(word)
    if matchActive and not isMyTurn then
        opponentStreamWord = tostring(word or "")
        local displayWord  = (opponentStreamWord ~= "") and opponentStreamWord or "..."
        safeSet(opponentParagraph, "✍ Lawan mengetik: " .. displayWord)
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

print("NAKA AUTO KATA v3.1 — LOADED SUCCESSFULLY")
