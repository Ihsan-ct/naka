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
    filterEnding   = {},        -- table huruf akhiran, kosong = semua
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

    -- Buat set huruf akhiran yang dipilih untuk lookup cepat
    local filterSet = {}
    local hasFilter = false
    for _, v in ipairs(config.filterEnding) do
        local lv = string.lower(tostring(v))
        if lv ~= "semua" and lv ~= "" then
            filterSet[lv] = true
            hasFilter = true
        end
    end

    for i = 1, #kataModule do
        local word = kataModule[i]
        if string.sub(word, 1, #lowerPrefix) == lowerPrefix and not isUsed(word) then
            local len = string.len(word)
            if len >= config.minLength and len <= config.maxLength then
                local passFilter = true
                if hasFilter then
                    local wordEnd = string.sub(word, -1)
                    if not filterSet[wordEnd] then
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
        -- Fallback: coba tanpa filter akhiran
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
        "Pilih BEBERAPA huruf akhiran sekaligus.\n" ..
        "AI akan pilih kata berakhiran salah satu dari huruf yang dipilih.\n" ..
        "Kosongkan pilihan = tidak ada filter (semua kata boleh).\n" ..
        "💡 Rekomendasi Trap: pilih x, q, z, f, v"
})

local filterLabel = MainTab:CreateLabel("🔚 Filter aktif: (tidak ada — semua kata boleh)")

MainTab:CreateDropdown({
    Name            = "🔚 Pilih Akhiran Huruf (bisa lebih dari satu)",
    Options         = {"a","i","u","e","o","n","r","s","t","k","h","l","m","p","g","j","f","v","z","x","q","w","y"},
    CurrentOption   = {},
    MultipleOptions = true,
    Callback        = function(Value)
        -- Value adalah table berisi huruf-huruf yang dipilih
        local selected = {}
        if type(Value) == "table" then
            for _, v in ipairs(Value) do
                table.insert(selected, string.lower(tostring(v)))
            end
        end
        config.filterEnding = selected

        -- Update label info
        if #selected == 0 then
            pcall(function() filterLabel:Set("🔚 Filter aktif: (tidak ada — semua kata boleh)") end)
        else
            local display = table.concat(selected, ", ")
            pcall(function() filterLabel:Set("🔚 Filter aktif: " .. display) end)
            Rayfield:Notify({
                Title    = "🔚 Filter Akhiran",
                Content  = "Filter: " .. display,
                Duration = 3,
                Image    = 4483362458
            })
        end
    end
})

-- Tombol preset trap letter
MainTab:CreateButton({
    Name     = "💀 Preset TRAP (x, q, z, f, v)",
    Callback = function()
        config.filterEnding = {"x", "q", "z", "f", "v"}
        pcall(function() filterLabel:Set("🔚 Filter aktif: x, q, z, f, v  💀 TRAP MODE") end)
        Rayfield:Notify({
            Title    = "💀 TRAP MODE",
            Content  = "Filter akhiran diset ke: x, q, z, f, v\nLawan akan kesulitan!",
            Duration = 4,
            Image    = 4483362458
        })
    end
})

MainTab:CreateButton({
    Name     = "🔄 Reset Filter (semua kata)",
    Callback = function()
        config.filterEnding = {}
        pcall(function() filterLabel:Set("🔚 Filter aktif: (tidak ada — semua kata boleh)") end)
        Rayfield:Notify({
            Title    = "🔄 Filter Reset",
            Content  = "Filter akhiran dihapus",
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

-- 3 Label terpisah per stat agar Set() pasti bekerja di Rayfield
local labelKataDikirim = StatsTab:CreateLabel("🔤 Kata Dikirim    : 0")
local labelKataPanjang = StatsTab:CreateLabel("🏆 Kata Terpanjang : —")
local labelDurasi      = StatsTab:CreateLabel("⏱ Durasi Sesi     : 0m 0s")

local function updateStatsParagraph()
    local elapsed        = os.time() - (stats.sessionStart or os.time())
    local minutes        = math.floor(elapsed / 60)
    local seconds        = elapsed % 60
    local longest        = tostring(stats.longestWord or "")
    local displayLongest = (longest ~= "") and longest or "—"
    pcall(function() labelKataDikirim:Set("🔤 Kata Dikirim    : " .. tostring(stats.totalWords or 0)) end)
    pcall(function() labelKataPanjang:Set("🏆 Kata Terpanjang : " .. displayLongest) end)
    pcall(function() labelDurasi:Set("⏱ Durasi Sesi     : " .. tostring(minutes) .. "m " .. tostring(seconds) .. "s") end)
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

-- Label untuk menampilkan kata terpakai (lebih reliable dari Dropdown)
local labelKataTerpakai = StatsTab:CreateLabel("📚 Kata terpakai: (belum ada)")

-- Override addUsedWord agar update label
local function updateKataLabel()
    local count = #usedWordsList
    if count == 0 then
        pcall(function() labelKataTerpakai:Set("📚 Kata terpakai: (belum ada)") end)
    else
        -- Tampilkan 10 kata terakhir
        local display = ""
        local start = math.max(1, count - 9)
        for i = start, count do
            display = display .. usedWordsList[i]
            if i < count then display = display .. ", " end
        end
        if count > 10 then
            display = "..." .. display
        end
        pcall(function() labelKataTerpakai:Set("📚 [" .. count .. " kata] " .. display) end)
    end
end

-- Patch addUsedWord untuk update label juga
local _origAddUsedWord = addUsedWord
addUsedWord = function(word)
    _origAddUsedWord(word)
    updateKataLabel()
end

-- Patch resetUsedWords untuk update label juga
local _origResetUsedWords = resetUsedWords
resetUsedWords = function()
    _origResetUsedWords()
    pcall(function() labelKataTerpakai:Set("📚 Kata terpakai: (belum ada)") end)
end

StatsTab:CreateButton({
    Name     = "🗑 Reset Daftar Kata",
    Callback = function()
        usedWords     = {}
        usedWordsList = {}
        pcall(function() labelKataTerpakai:Set("📚 Kata terpakai: (belum ada)") end)
        Rayfield:Notify({
            Title    = "🗑 Reset",
            Content  = "Daftar kata direset!",
            Duration = 3,
            Image    = 4483362458
        })
    end
})

StatsTab:CreateSection("🎯 STATUS PERTANDINGAN")

local opponentParagraph    = StatsTab:CreateLabel("👤 Status Lawan: ⏳ Menunggu pertandingan...")
local startLetterParagraph = StatsTab:CreateLabel("🔤 Huruf Awal Server: —")
local turnParagraph        = StatsTab:CreateLabel("🎮 Giliran: ⏳ Menunggu...")

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
        safeSet(turnParagraph,     "🎮 Giliran: ⏳ Menunggu giliran...")
        safeSet(opponentParagraph, "👤 Status Lawan: 👀 Pertandingan dimulai!")
        updateStatsParagraph()

    elseif cmd == "HideMatchUI" then
        matchActive  = false
        isMyTurn     = false
        serverLetter = ""
        resetUsedWords()
        safeSet(turnParagraph,        "🎮 Giliran: ❌ Pertandingan selesai")
        safeSet(opponentParagraph,    "👤 Status Lawan: ⏳ Menunggu pertandingan...")
        safeSet(startLetterParagraph, "🔤 Huruf Awal Server: —")
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
        local displayLetter = (serverLetter ~= "") and string.upper(serverLetter) or "—"
        safeSet(startLetterParagraph, "🔤 Huruf Awal Server: " .. displayLetter)
        if autoEnabled and matchActive and isMyTurn then
            task.spawn(startUltraAI)
        end
    end
end

local function onBillboard(word)
    if matchActive and not isMyTurn then
        opponentStreamWord = tostring(word or "")
        local displayWord  = (opponentStreamWord ~= "") and opponentStreamWord or "..."
        safeSet(opponentParagraph, "👤 Status Lawan: ✍ Lawan mengetik: " .. displayWord)
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
