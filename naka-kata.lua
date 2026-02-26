-- =========================================================
-- ULTRA SMART AUTO KATA (ANTI LUAOBFUSCATOR V1 BUILD)
-- =========================================================

if game:IsLoaded() == false then
    game.Loaded:Wait()
end

-- =========================
-- SAFE RAYFIELD LOAD
-- =========================
-- =========================
-- LOAD RAYFIELD (OBF SAFE)
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
-- SERVICES (NO COLON RAW)
-- =========================
local GetService = game.GetService
local ReplicatedStorage = GetService(game, "ReplicatedStorage")
local Players = GetService(game, "Players")
local LocalPlayer = Players.LocalPlayer

-- =========================
-- LOAD WORDLIST (NO INLINE)
-- =========================
local kataModule = {}

local function downloadWordlist()
    local response = httpget(game, "https://raw.githubusercontent.com/danzzy1we/roblox-script-dump/refs/heads/main/WordListDump/Dump_IndonesianWords.lua")
    if not response then
        return false
    end

    local content = string.match(response, "return%s*(.+)")
    if not content then
        return false
    end

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
-- REMOTES (SAFE ACCESS)
-- =========================
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local MatchUI = remotes:WaitForChild("MatchUI")
local SubmitWord = remotes:WaitForChild("SubmitWord")
local BillboardUpdate = remotes:WaitForChild("BillboardUpdate")
local BillboardEnd = remotes:WaitForChild("BillboardEnd")
local TypeSound = remotes:WaitForChild("TypeSound")
local UsedWordWarn = remotes:WaitForChild("UsedWordWarn")

-- =========================
-- STATE
-- =========================
local matchActive = false
local isMyTurn = false
local serverLetter = ""

local usedWords = {}
local usedWordsList = {}
local opponentStreamWord = ""

local autoEnabled = false
local autoRunning = false

local config = {
    minDelay = 500,
    maxDelay = 750,
    aggression = 20,
    minLength = 3,
    maxLength = 12
}

-- =========================
-- LOGIC FUNCTIONS (FLAT)
-- =========================
local function isUsed(word)
    return usedWords[string.lower(word)] == true
end

local usedWordsDropdown = nil

local function addUsedWord(word)
    local w = string.lower(word)
    if usedWords[w] == nil then
        usedWords[w] = true
        table.insert(usedWordsList, word)
        if usedWordsDropdown ~= nil then
            usedWordsDropdown:Set(usedWordsList)
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

    for i = 1, #kataModule do
        local word = kataModule[i]
        if string.sub(word, 1, #lowerPrefix) == lowerPrefix then
            if not isUsed(word) then
                local len = string.len(word)
                if len >= config.minLength and len <= config.maxLength then
                    table.insert(results, word)
                end
            end
        end
    end

    table.sort(results, function(a,b)
        return string.len(a) > string.len(b)
    end)

    return results
end

local function humanDelay()
    local min = config.minDelay
    local max = config.maxDelay
    if min > max then
        min = max
    end
    task.wait(math.random(min, max) / 1000)
end

-- =========================
-- AUTO ENGINE (NO SPAWN)
-- =========================
local function startUltraAI()

    if autoRunning then return end
    if not autoEnabled then return end
    if not matchActive then return end
    if not isMyTurn then return end
    if serverLetter == "" then return end

    autoRunning = true

    humanDelay()

    local words = getSmartWords(serverLetter)
    if #words == 0 then
        autoRunning = false
        return
    end

    local selectedWord = words[1]

    if config.aggression < 100 then
        local topN = math.floor(#words * (1 - config.aggression/100))
        if topN < 1 then topN = 1 end
        if topN > #words then topN = #words end
        selectedWord = words[math.random(1, topN)]
    end

    local currentWord = serverLetter
    local remain = string.sub(selectedWord, #serverLetter + 1)

    for i = 1, string.len(remain) do

        if not matchActive or not isMyTurn then
            autoRunning = false
            return
        end

        currentWord = currentWord .. string.sub(remain, i, i)

        TypeSound:FireServer()
        BillboardUpdate:FireServer(currentWord)

        humanDelay()
    end

    humanDelay()

    SubmitWord:FireServer(selectedWord)
    addUsedWord(selectedWord)

    humanDelay()
    BillboardEnd:FireServer()

    autoRunning = false
end

-- =========================
-- UI
-- =========================
-- =========================
-- WINDOW UTAMA
-- =========================
local Window = Rayfield:CreateWindow({
    Name = "🔥 NAKA AUTO KATA",
    LoadingTitle = "Memuat Sistem NAKA",
    LoadingSubtitle = "AI Penjawab Kata Otomatis",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "NAKA",
        FileName = "AutoKata"
    },
    Discord = {
        Enabled = false
    },
    KeySystem = false
})

Rayfield:LoadConfiguration()

Rayfield:Notify({
    Title = "✅ NAKA Siap",
    Content = "Auto Kata berhasil dimuat",
    Duration = 5,
    Image = 4483362458
})

-- =========================
-- TAB UTAMA
-- =========================
local MainTab = Window:CreateTab("🎮 PENGATURAN UTAMA", 4483362458)

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

-- =========================
-- PENGATURAN AI
-- =========================
MainTab:CreateSection("🧠 PENGATURAN KECERDASAN")

MainTab:CreateSlider({
    Name = "⚡ Tingkat Agresif",
    Range = {0,100},
    Increment = 5,
    CurrentValue = config.aggression,
    Callback = function(Value)
        config.aggression = Value
    end
})

MainTab:CreateSlider({
    Name = "🔤 Panjang Kata Minimum",
    Range = {2, 6},
    Increment = 1,
    CurrentValue = config.minLength,
    Callback = function(Value)
        config.minLength = Value
    end
})

MainTab:CreateSlider({
    Name = "🔠 Panjang Kata Maksimum",
    Range = {5, 20},
    Increment = 1,
    CurrentValue = config.maxLength,
    Callback = function(Value)
        config.maxLength = Value
    end
})

-- =========================
-- SIMULASI MANUSIA
-- =========================
MainTab:CreateSection("⏱ JEDA KETIK (AGAR TERLIHAT MANUSIA)")

MainTab:CreateSlider({
    Name = "⌛ Jeda Minimum (ms)",
    Range = {50, 600},
    Increment = 10,
    CurrentValue = config.minDelay,
    Callback = function(Value)
        config.minDelay = Value
    end
})

MainTab:CreateSlider({
    Name = "⏳ Jeda Maksimum (ms)",
    Range = {100, 1200},
    Increment = 10,
    CurrentValue = config.maxDelay,
    Callback = function(Value)
        config.maxDelay = Value
    end
})

-- =========================
-- INFO MATCH
-- =========================
MainTab:CreateSection("📊 INFO PERTANDINGAN")

usedWordsDropdown = MainTab:CreateDropdown({
    Name = "📚 Daftar Kata yang Sudah Dipakai",
    Options = usedWordsList,
    CurrentOption = {},
    MultipleOptions = false,
    Callback = function() end
})

-- =========================
-- STATUS LANGSUNG
-- =========================
MainTab:CreateSection("🎯 STATUS SAAT INI")

local opponentParagraph = MainTab:CreateParagraph({
    Title = "👤 Status Lawan",
    Content = "⏳ Menunggu pertandingan..."
})

local startLetterParagraph = MainTab:CreateParagraph({
    Title = "🔤 Huruf Awal",
    Content = "—"
})

-- =========================
-- TAB TENTANG SCRIPT
-- =========================
local AboutTab = Window:CreateTab("ℹ TENTANG SCRIPT", 4483362458)

AboutTab:CreateSection("📜 INFORMASI")

AboutTab:CreateParagraph({
    Title = "🔥 NAKA AUTO KATA",
    Content =
        "Versi : 2.5\n" ..
        "Pembuat : NAKA\n\n" ..
        "Fitur:\n" ..
        "• Menjawab kata otomatis\n" ..
        "• Bisa atur tingkat agresif\n" ..
        "• Jeda ketik seperti manusia\n" ..
        "• Melihat status pertandingan\n\n" ..
        "Kamus kata oleh:\n" ..
        "danzzy1we"
})

AboutTab:CreateSection("📖 CARA PAKAI")

AboutTab:CreateParagraph({
    Title = "🎮 Langkah Penggunaan",
    Content =
        "1️⃣ Aktifkan 'Auto Kata'\n" ..
        "2️⃣ Atur tingkat agresif & jeda\n" ..
        "3️⃣ Masuk ke pertandingan\n" ..
        "4️⃣ AI akan bermain otomatis"
})

AboutTab:CreateSection("⚠ CATATAN")

AboutTab:CreateParagraph({
    Title = "🛑 Penting",
    Content =
        "• Gunakan internet stabil\n" ..
        "• Jangan spam tombol on/off\n" ..
        "• Jika error, jalankan ulang script"
})
-- =========================
-- REMOTE EVENTS (NO INLINE)
-- =========================
local function onMatchUI(cmd, value)

    if cmd == "ShowMatchUI" then
        matchActive = true
        isMyTurn = false
        resetUsedWords()

    elseif cmd == "HideMatchUI" then
        matchActive = false
        isMyTurn = false
        serverLetter = ""
        resetUsedWords()

    elseif cmd == "StartTurn" then
        isMyTurn = true
        if autoEnabled then
            startUltraAI()
        end

    elseif cmd == "EndTurn" then
        isMyTurn = false

    elseif cmd == "UpdateServerLetter" then
        serverLetter = value or ""
    end
end

local function onBillboard(word)
    if matchActive and not isMyTurn then
        opponentStreamWord = word or ""
    end
end

local function onUsedWarn(word)
    if word then
        addUsedWord(word)
        if autoEnabled and matchActive and isMyTurn then
            humanDelay()
            startUltraAI()
        end
    end
end

MatchUI.OnClientEvent:Connect(onMatchUI)
BillboardUpdate.OnClientEvent:Connect(onBillboard)
UsedWordWarn.OnClientEvent:Connect(onUsedWarn)

print("ANTI LUAOBFUSCATOR BUILD LOADED SUCCESSFULLY")
