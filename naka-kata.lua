-- =========================================================
-- ULTRA SMART AUTO KATA v5.0 — NAKA
-- NEW: Human Typing Simulator + Kata Bom System
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
    bombMode       = false,     -- aktifkan kata bom
    bombTier       = "auto",    -- "biasa" | "kuat" | "mega" | "auto"
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
-- ██╗  ██╗██╗   ██╗███╗   ███╗ █████╗ ███╗   ██╗
-- ██║  ██║██║   ██║████╗ ████║██╔══██╗████╗  ██║
-- ███████║██║   ██║██╔████╔██║███████║██╔██╗ ██║
-- ██╔══██║██║   ██║██║╚██╔╝██║██╔══██║██║╚██╗██║
-- ██║  ██║╚██████╔╝██║ ╚═╝ ██║██║  ██║██║ ╚████║
-- TYPING SIMULATOR
-- =========================================================

-- =========================
-- PROFIL MANUSIA
-- Dibuat SEKALI per sesi — setiap sesi punya kepribadian unik
-- =========================
local humanProfile = {
    baseSpeed      = math.random(95, 210),      -- ms per karakter
    mistakeChance  = math.random(6, 13) / 100,  -- 6-13% chance typo per char
    hesitateChance = math.random(8, 18) / 100,  -- 8-18% chance pause tiba2
    isBurstyTyper  = math.random(1, 2) == 1,    -- cepat di awal lambat di akhir
    fatigueRate    = math.random(1, 4),          -- ms tambahan per kata
    doubleTypoRate = math.random(2, 6) / 100,   -- 2-6% chance salah 2 huruf sekaligus
    wordCount      = 0,                          -- counter fatigue
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

-- =========================
-- KEYBOARD LAYOUT — HURUF TETANGGA
-- Typo realistis berdasarkan posisi keyboard QWERTY
-- =========================
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

-- =========================
-- WAIT HELPER
-- =========================
local function waitMs(ms)
    if ms < 8 then ms = 8 end
    task.wait(ms / 1000)
end

-- =========================
-- CHAR DELAY — NATURAL PER KARAKTER
-- =========================
local function charDelay(charIndex, wordLength)
    local base = humanProfile.baseSpeed
    base = base + (humanProfile.wordCount * humanProfile.fatigueRate)

    -- Bursty typer: cepat di awal, melambat di akhir
    if humanProfile.isBurstyTyper then
        local progress = charIndex / wordLength
        if progress < 0.35 then
            base = base * 0.65
        elseif progress > 0.75 then
            base = base * 1.35
        end
    end

    -- Karakter pertama: jeda tangan bersiap
    if charIndex == 1 then
        base = base + math.random(70, 200)
    end

    -- Variasi noise natural ±20%
    local noise = math.random(-20, 20) / 100
    base = base * (1 + noise)

    -- Sesekali microlag (lag internet / pikir sebentar)
    if math.random(1, 15) == 1 then
        base = base + math.random(80, 250)
    end

    if base < 40 then base = 40 end
    return math.floor(base)
end

-- =========================
-- HUMAN TYPING ENGINE
-- Kirim kata dengan simulasi manusia:
-- - Kadang typo lalu hapus (tidak selalu)
-- - Kadang hesitate / pause
-- - Kadang double typo
-- - Kecepatan bervariasi alami
-- =========================
local function humanTypeWord(selectedWord, serverPrefix)
    humanProfile.wordCount = humanProfile.wordCount + 1

    local currentDisplay = serverPrefix   -- kata yang tampil di layar saat ini
    local remain         = string.sub(selectedWord, #serverPrefix + 1)
    local chars          = {}

    -- Pecah remain jadi array karakter
    for i = 1, #remain do
        table.insert(chars, string.sub(remain, i, i))
    end

    local i = 1
    while i <= #chars do
        if not matchActive or not isMyTurn then return false end

        local correctChar = chars[i]
        local rolled      = math.random()

        -- ── HESITATE: pause tiba-tiba sebelum ketik ──
        if math.random() < humanProfile.hesitateChance then
            -- Berhenti sebentar, tidak ada input
            waitMs(math.random(180, 600))
            -- Kadang pas hesitate justru hapus 1 char (kayak mau edit)
            if math.random(1,4) == 1 and #currentDisplay > #serverPrefix then
                currentDisplay = string.sub(currentDisplay, 1, #currentDisplay - 1)
                TypeSound:FireServer()
                BillboardUpdate:FireServer(currentDisplay)
                waitMs(math.random(100, 300))
                -- Ketik lagi char yang dihapus
                currentDisplay = currentDisplay .. string.sub(
                    selectedWord, #currentDisplay + 1, #currentDisplay + 1)
                TypeSound:FireServer()
                BillboardUpdate:FireServer(currentDisplay)
                waitMs(charDelay(i, #chars))
                i = i + 1
                continue
            end
        end

        -- ── DOUBLE TYPO: salah 2 huruf sekaligus ──
        if rolled < humanProfile.doubleTypoRate and i <= #chars - 1 then
            -- Ketik 2 huruf salah
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

            -- Hapus 2 huruf salah
            currentDisplay = string.sub(currentDisplay, 1, #currentDisplay - 1)
            TypeSound:FireServer()
            BillboardUpdate:FireServer(currentDisplay)
            waitMs(math.random(60, 150))

            currentDisplay = string.sub(currentDisplay, 1, #currentDisplay - 1)
            TypeSound:FireServer()
            BillboardUpdate:FireServer(currentDisplay)
            waitMs(math.random(80, 220))

            -- Ketik benar
            currentDisplay = currentDisplay .. correctChar
            TypeSound:FireServer()
            BillboardUpdate:FireServer(currentDisplay)
            waitMs(charDelay(i, #chars))
            i = i + 1

        -- ── SINGLE TYPO: salah 1 huruf lalu hapus ──
        elseif rolled < (humanProfile.doubleTypoRate + humanProfile.mistakeChance) then
            local wrongChar = getNearbyChar(correctChar)

            -- Ketik huruf salah
            currentDisplay = currentDisplay .. wrongChar
            TypeSound:FireServer()
            BillboardUpdate:FireServer(currentDisplay)

            -- Durasi sebelum sadar salah (50-300ms)
            waitMs(math.random(50, 300))

            -- Kadang lanjut 1-2 huruf lagi baru sadar salah (lebih human)
            local extraBeforeRealize = math.random(1, 5)
            if extraBeforeRealize <= 2 and i < #chars then
                -- Ketik 1 huruf lagi sebelum sadar salah
                local nextChar = chars[i+1] or correctChar
                currentDisplay = currentDisplay .. nextChar
                TypeSound:FireServer()
                BillboardUpdate:FireServer(currentDisplay)
                waitMs(math.random(60, 180))

                -- Hapus 2: huruf tambahan + huruf salah
                currentDisplay = string.sub(currentDisplay, 1, #currentDisplay - 1)
                TypeSound:FireServer()
                BillboardUpdate:FireServer(currentDisplay)
                waitMs(math.random(50, 130))
            end

            -- Hapus huruf salah
            currentDisplay = string.sub(currentDisplay, 1, #currentDisplay - 1)
            TypeSound:FireServer()
            BillboardUpdate:FireServer(currentDisplay)
            waitMs(math.random(80, 250))

            -- Ketik benar
            currentDisplay = currentDisplay .. correctChar
            TypeSound:FireServer()
            BillboardUpdate:FireServer(currentDisplay)
            waitMs(charDelay(i, #chars))
            i = i + 1

        -- ── NORMAL: ketik benar ──
        else
            currentDisplay = currentDisplay .. correctChar
            TypeSound:FireServer()
            BillboardUpdate:FireServer(currentDisplay)
            waitMs(charDelay(i, #chars))
            i = i + 1
        end
    end

    -- Jeda kecil sebelum submit (baca ulang sebentar)
    waitMs(math.random(150, 450))
    return true
end

-- =========================================================
-- 💣 KATA BOM SYSTEM
-- =========================================================

-- =========================
-- DEFINISI TIER BOM
-- Tier ditentukan berdasarkan jumlah kata di kamus
-- yang bisa dipakai lawan dari huruf akhir kata ini
-- =========================
local BOM_TIERS = {
    -- Tier 1 — Bom Biasa: akhiran langka tapi masih ada beberapa kata
    biasa = {"f","v","w","y"},
    -- Tier 2 — Bom Kuat: akhiran sangat langka
    kuat  = {"x","q","z"},
    -- Tier 3 — Mega Bom: akhiran hampir tidak ada sambungannya + kata panjang
    mega  = {"x","q","z","f","v"},
}

-- Cache hasil analisis kamus per huruf (dibangun satu kali)
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

-- Hitung skor "kelangkaan" huruf akhir
-- Makin sedikit kata yang bisa dipakai lawan = makin tinggi skor bom
local function getBombScore(word)
    local lastChar = string.sub(word, -1)
    local count    = letterCountCache[lastChar] or 9999
    local len      = #word

    local score = 0
    -- Makin sedikit kata untuk huruf itu = makin berbahaya
    if count < 50  then score = score + 100
    elseif count < 150 then score = score + 60
    elseif count < 400 then score = score + 30
    elseif count < 800 then score = score + 10
    end

    -- Kata panjang lebih sulit dibalas
    if len >= 12 then score = score + 30
    elseif len >= 9 then score = score + 15
    elseif len >= 7 then score = score + 5
    end

    return score
end

-- Tentukan tier bom berdasarkan skor
local function getBombTier(score)
    if score >= 120 then return "mega"
    elseif score >= 60 then return "kuat"
    elseif score >= 20 then return "biasa"
    else return nil
    end
end

-- Cari kata bom terbaik untuk huruf awalan tertentu
-- tierTarget: "biasa" | "kuat" | "mega" | "auto"
local function findBombWord(prefix, tierTarget)
    local candidates = {}
    local lowerPrefix = string.lower(prefix)

    -- Tentukan set akhiran yang boleh berdasarkan tier
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
        -- auto: semua langka
        for _, e in ipairs(BOM_TIERS.biasa) do allowedEndings[e] = true end
        for _, e in ipairs(BOM_TIERS.kuat)  do allowedEndings[e] = true end
        for _, e in ipairs(BOM_TIERS.mega)  do allowedEndings[e] = true end
    end

    for _, word in ipairs(kataModule) do
        if string.sub(word, 1, #lowerPrefix) == lowerPrefix
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

    -- Sort by bomb score tertinggi
    table.sort(candidates, function(a,b) return a.score > b.score end)

    if #candidates > 0 then
        return candidates[1].word, getBombTier(candidates[1].score), candidates[1].score
    end
    return nil, nil, 0
end

-- Label bom di UI (diset nanti)
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
-- SCORING SYSTEM (asli)
-- =========================
local HARD_ENDINGS = {
    ["x"]=10, ["q"]=10, ["f"]=8, ["v"]=8,
    ["z"]=9,  ["y"]=6,  ["w"]=5, ["j"]=7,
    ["k"]=4,  ["h"]=3,
}

local function scoreWord(word)
    local score = 0
    local len   = #word
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

local function getSmartWords(prefix)
    local results     = {}
    local lowerPrefix = string.lower(prefix)
    local filterSet   = {}
    local hasFilter   = false

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

    table.sort(results, function(a,b) return scoreWord(a) > scoreWord(b) end)
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

    -- ── Cek apakah pakai bom ──
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

    -- ── Fallback ke normal jika bom tidak tersedia ──
    if not selectedWord then
        local words = getSmartWords(serverLetter)
        if #words == 0 then
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

        if config.aggression >= 100 then
            selectedWord = words[1]
        else
            local topN = math.max(1, math.floor(#words * (1 - config.aggression/100)))
            if topN > #words then topN = #words end
            selectedWord = words[math.random(1, topN)]
        end
    end

    -- ── Human Typing ──
    local success = humanTypeWord(selectedWord, serverLetter)
    if not success then
        autoRunning = false
        return
    end

    -- ── Submit ──
    SubmitWord:FireServer(selectedWord)
    addUsedWord(selectedWord)

    -- Notif jika bom berhasil
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
-- BUILD UI
-- 4 Tab: BATTLE | BOMB | SETTINGS | INFO
-- =========================================================
local Window = Rayfield:CreateWindow({
    Name            = "⚔ NAKA  •  AUTO KATA",
    LoadingTitle    = "N A K A",
    LoadingSubtitle = "Ultra Smart Word AI — v5.0",
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
    Title    = "⚔  NAKA v5.0",
    Content  = "Human Typing + Kata Bom aktif!",
    Duration = 5,
    Image    = 4483362458
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
    Name         = "🃏  Mode Kata Langka",
    CurrentValue = false,
    Callback     = function(Value) config.preferRare = Value end
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

BombTab:CreateLabel("💡  Kata Bom = kata yang huruf akhirnya")
BombTab:CreateLabel("     hampir tidak ada sambungannya di kamus.")
BombTab:CreateLabel("     Lawan hampir pasti tidak bisa balas!")

BombTab:CreateSection("◈  KONTROL BOM")

BombTab:CreateToggle({
    Name         = "💣  Aktifkan Kata Bom",
    CurrentValue = false,
    Callback     = function(Value)
        config.bombMode = Value
        Rayfield:Notify({
            Title    = Value and "💣  Kata Bom ON" or "💣  Kata Bom OFF",
            Content  = Value and "AI akan prioritaskan kata mematikan!" or "Mode normal",
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

-- Hitung stok setelah cache siap
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

BombTab:CreateButton({
    Name     = "💣💣💣  PAKSA MEGA BOM SEKARANG",
    Callback = function()
        if not matchActive or not isMyTurn then
            Rayfield:Notify({
                Title   = "⚠️  Bukan giliran kamu!",
                Content = "Tunggu giliran dulu",
                Duration = 3,
                Image = 4483362458
            })
            return
        end
        local oldBomb = config.bombMode
        local oldTier = config.bombTier
        config.bombMode = true
        config.bombTier = "mega"
        task.spawn(startUltraAI)
        task.delay(2, function()
            config.bombMode = oldBomb
            config.bombTier = oldTier
        end)
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

SettingsTab:CreateSection("◈  HUMAN TYPING SIMULATOR")

SettingsTab:CreateLabel("🎭  Profil manusia dibuat otomatis tiap sesi")
SettingsTab:CreateLabel(string.format("◦  Kecepatan Base   :  %d ms/karakter", humanProfile.baseSpeed))
SettingsTab:CreateLabel(string.format("◦  Chance Typo      :  %.0f%%", humanProfile.mistakeChance * 100))
SettingsTab:CreateLabel(string.format("◦  Chance Ragu-ragu :  %.0f%%", humanProfile.hesitateChance * 100))
SettingsTab:CreateLabel(string.format("◦  Tipe Ketik       :  %s", humanProfile.isBurstyTyper and "Burst (cepat→lambat)" or "Konsisten"))
SettingsTab:CreateLabel(string.format("◦  Fatigue Rate     :  +%d ms/kata", humanProfile.fatigueRate))

SettingsTab:CreateButton({
    Name = "🔄  Generate Profil Baru",
    Callback = function()
        humanProfile.baseSpeed      = math.random(95, 210)
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

SettingsTab:CreateSection("◈  PANDUAN KEAMANAN")
SettingsTab:CreateLabel("🟢  AMAN        →  Human Typing ON")
SettingsTab:CreateLabel("🟡  SEDANG    →  Delay 400ms+")
SettingsTab:CreateLabel("🔴  BERISIKO  →  Delay < 200ms")

-- ╔══════════════════════════════╗
-- ║   TAB 4 — INFO               ║
-- ╚══════════════════════════════╝
local InfoTab = Window:CreateTab("📋  INFO", 4483362458)

InfoTab:CreateSection("◈  TENTANG SCRIPT")
InfoTab:CreateLabel("⚔   NAKA AUTO KATA  —  v5.0")
InfoTab:CreateLabel("◦   Pembuat   :  NAKA")
InfoTab:CreateLabel("◦   Kamus     :  80.000+ kata Indonesia")
InfoTab:CreateLabel("◦   NEW       :  Human Typing + Kata Bom!")

InfoTab:CreateSection("◈  FITUR BARU v5.0")
InfoTab:CreateLabel("🎭  Human Typing Simulator")
InfoTab:CreateLabel("     Typo natural, hesitate, double typo,")
InfoTab:CreateLabel("     profil unik tiap sesi, fatigue system")
InfoTab:CreateLabel("💣  Kata Bom System")
InfoTab:CreateLabel("     3 tier bom, realtime preview,")
InfoTab:CreateLabel("     auto pilih kata paling mematikan")

InfoTab:CreateSection("◈  CARA PAKAI")
InfoTab:CreateLabel("1️⃣   Buka tab BATTLE → Aktifkan Auto Kata")
InfoTab:CreateLabel("2️⃣   Buka tab BOMB → Aktifkan Kata Bom")
InfoTab:CreateLabel("3️⃣   Pilih tier bom (auto = disarankan)")
InfoTab:CreateLabel("4️⃣   Masuk pertandingan — AI bekerja sendiri")

InfoTab:CreateSection("◈  TIPS")
InfoTab:CreateLabel("💣   Tier MEGA untuk lawan kuat")
InfoTab:CreateLabel("🎭   Human Typing = anti-ban terbaik")
InfoTab:CreateLabel("🔄   Generate profil baru tiap sesi baru")
InfoTab:CreateLabel("⚡   Agresivitas 80+ = pilih kata terpanjang")

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
        -- Preview bom saat huruf berubah
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

print("NAKA AUTO KATA v5.0 — LOADED  |  Human Typing + Kata Bom AKTIF")
