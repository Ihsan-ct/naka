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
-- BUILD UI — PREMIUM REDESIGN
-- 3 Tab: BATTLE | SETTINGS | INFO
-- =========================
local Window = Rayfield:CreateWindow({
    Name            = "⚔ NAKA  •  AUTO KATA",
    LoadingTitle    = "N A K A",
    LoadingSubtitle = "Ultra Smart Word AI — v4.0",
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
    Title    = "⚔  NAKA v4.0",
    Content  = "Sistem dimuat  •  80K+ kata siap",
    Duration = 4,
    Image    = 4483362458
})

-- ╔══════════════════════════════╗
-- ║   TAB 1 — BATTLE             ║
-- ║   Status + Toggle + Filter   ║
-- ╚══════════════════════════════╝
local BattleTab = Window:CreateTab("⚔  BATTLE", 4483362458)

-- ── STATUS LIVE ──────────────────
BattleTab:CreateSection("◈  STATUS LIVE")

local turnParagraph        = BattleTab:CreateLabel("●  Giliran      :  ⏳ Menunggu pertandingan...")
local startLetterParagraph = BattleTab:CreateLabel("●  Huruf Awalan :  —")
local opponentParagraph    = BattleTab:CreateLabel("●  Lawan        :  ⏳ Menunggu...")

-- ── AUTO KATA ────────────────────
BattleTab:CreateSection("◈  AUTO KATA")

BattleTab:CreateToggle({
    Name         = "⚡  Aktifkan Auto Kata",
    CurrentValue = false,
    Callback     = function(Value)
        autoEnabled = Value
        if Value then
            Rayfield:Notify({
                Title    = "⚡  Auto Kata ON",
                Content  = "AI aktif — siap dominasi!",
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
    Name         = "🃏  Mode Kata Langka",
    CurrentValue = false,
    Callback     = function(Value) config.preferRare = Value end
})

-- ── FILTER AKHIRAN ───────────────
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
            Rayfield:Notify({
                Title    = "🔡  Filter Diset",
                Content  = display,
                Duration = 3,
                Image    = 4483362458
            })
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
            Content  = "Lawan akan kesulitan menemukan kata!",
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

-- ── STATISTIK RINGKAS ────────────
BattleTab:CreateSection("◈  STATISTIK")

local labelKataDikirim = BattleTab:CreateLabel("◦  Kata Dikirim    :  0")
local labelKataPanjang = BattleTab:CreateLabel("◦  Kata Terpanjang :  —")
local labelDurasi      = BattleTab:CreateLabel("◦  Durasi Sesi     :  0m 0s")
local labelKataTerpakai = BattleTab:CreateLabel("◦  Riwayat         :  (belum ada)")

local function updateStatsParagraph()
    local elapsed        = os.time() - (stats.sessionStart or os.time())
    local minutes        = math.floor(elapsed / 60)
    local seconds        = elapsed % 60
    local longest        = tostring(stats.longestWord or "")
    local displayLongest = (longest ~= "") and longest or "—"
    pcall(function() labelKataDikirim:Set("◦  Kata Dikirim    :  " .. tostring(stats.totalWords or 0)) end)
    pcall(function() labelKataPanjang:Set("◦  Kata Terpanjang :  " .. displayLongest) end)
    pcall(function() labelDurasi:Set("◦  Durasi Sesi     :  " .. tostring(minutes) .. "m " .. tostring(seconds) .. "s") end)
end

local function updateKataLabel()
    local count = #usedWordsList
    if count == 0 then
        pcall(function() labelKataTerpakai:Set("◦  Riwayat         :  (belum ada)") end)
    else
        local display = ""
        local start = math.max(1, count - 7)
        for i = start, count do
            display = display .. usedWordsList[i]
            if i < count then display = display .. "  ·  " end
        end
        if count > 8 then display = "…  " .. display end
        pcall(function() labelKataTerpakai:Set("◦  Riwayat  [" .. count .. "]  :  " .. display) end)
    end
end

local _origAddUsedWord = addUsedWord
addUsedWord = function(word)
    _origAddUsedWord(word)
    updateKataLabel()
end

local _origResetUsedWords = resetUsedWords
resetUsedWords = function()
    _origResetUsedWords()
    pcall(function() labelKataTerpakai:Set("◦  Riwayat         :  (belum ada)") end)
end

BattleTab:CreateButton({
    Name     = "↺  Reset Semua Statistik & Riwayat",
    Callback = function()
        stats.totalWords   = 0
        stats.longestWord  = ""
        stats.sessionStart = os.time()
        usedWords          = {}
        usedWordsList      = {}
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
-- ║   TAB 2 — SETTINGS           ║
-- ║   AI + Anti-Detect + Delay   ║
-- ╚══════════════════════════════╝
local SettingsTab = Window:CreateTab("⚙  SETTINGS", 4483362458)

-- ── AI PARAMETER ─────────────────
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

-- ── ANTI DETECT ──────────────────
SettingsTab:CreateSection("◈  ANTI-DETECT")

SettingsTab:CreateToggle({
    Name         = "🛡  Mode Anti-Detect  ( Simulasi Manusia )",
    CurrentValue = true,
    Callback     = function(Value)
        config.antiDetectMode = Value
        Rayfield:Notify({
            Title    = "🛡  Anti-Detect",
            Content  = Value and "ON — pola ketik manusia aktif" or "OFF — ketik langsung",
            Duration = 3,
            Image    = 4483362458
        })
    end
})

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

SettingsTab:CreateSection("◈  PANDUAN DELAY")

SettingsTab:CreateLabel("🟢  AMAN        →  500ms – 800ms")
SettingsTab:CreateLabel("🟡  SEDANG    →  300ms – 499ms")
SettingsTab:CreateLabel("🔴  BERISIKO  →  50ms  – 299ms")

-- ╔══════════════════════════════╗
-- ║   TAB 3 — INFO               ║
-- ║   Tentang + Cara Pakai       ║
-- ╚══════════════════════════════╝
local InfoTab = Window:CreateTab("📋  INFO", 4483362458)

InfoTab:CreateSection("◈  TENTANG SCRIPT")

InfoTab:CreateLabel("⚔   NAKA AUTO KATA  —  v4.0")
InfoTab:CreateLabel("◦   Pembuat   :  NAKA")
InfoTab:CreateLabel("◦   Kamus     :  80.000+ kata Indonesia")
InfoTab:CreateLabel("◦   Library   :  danzzy1we")

InfoTab:CreateSection("◈  CARA PAKAI")

InfoTab:CreateLabel("1️⃣   Buka tab BATTLE")
InfoTab:CreateLabel("2️⃣   Aktifkan  ⚡ Auto Kata")
InfoTab:CreateLabel("3️⃣   Set filter akhiran jika perlu")
InfoTab:CreateLabel("4️⃣   Masuk pertandingan")
InfoTab:CreateLabel("5️⃣   AI otomatis bermain!")

InfoTab:CreateSection("◈  TIPS MENANG")

InfoTab:CreateLabel("💀   Aktifkan TRAP MODE untuk dominasi")
InfoTab:CreateLabel("⚡   Agresivitas 80–100 = pilih kata terpanjang")
InfoTab:CreateLabel("🛡   Delay 500ms+ agar tidak terdeteksi")
InfoTab:CreateLabel("🔡   Pilih multi akhiran untuk variasi trap")

InfoTab:CreateSection("◈  CATATAN")

InfoTab:CreateLabel("◦   Gunakan koneksi internet stabil")
InfoTab:CreateLabel("◦   Jika stuck → jalankan ulang script")
InfoTab:CreateLabel("◦   Filter akhiran auto-fallback jika kosong")

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

print("NAKA AUTO KATA v4.0 — LOADED SUCCESSFULLY")
