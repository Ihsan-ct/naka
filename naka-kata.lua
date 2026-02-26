-- =========================================================
-- NAKA AUTO KATA v4.0 — LINORIA UI EDITION
-- UI: LinoriaLib (violin-suzutsuki)
-- =========================================================

if game:IsLoaded() == false then
    game.Loaded:Wait()
end

-- =========================
-- LOAD LINORIA
-- =========================
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library     = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager  = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

-- =========================
-- SERVICES
-- =========================
local httpget           = game.HttpGet
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
    filterEnding   = {},
    antiDetectMode = true,
    preferRare     = false,
}

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
-- ANTI-DETECT: DELAY NATURAL
-- =========================
local function naturalDelay(charIndex, wordLength)
    local base = math.random(config.minDelay, config.maxDelay)
    if config.antiDetectMode then
        if charIndex == 1 then base = base + math.random(80, 200) end
        if wordLength > 7 and charIndex == math.floor(wordLength / 2) then
            base = base + math.random(50, 150)
        end
        if math.random(1, 10) <= 2 then base = math.floor(base * 0.5) end
        if math.random(1, 10) == 1  then base = base + math.random(100, 300) end
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
-- WORD MANAGEMENT
-- =========================
local labelTurnStatus   = nil
local labelHuruf        = nil
local labelLawan        = nil
local labelKataDikirim  = nil
local labelKataPanjang  = nil
local labelDurasi       = nil
local labelRiwayat      = nil
local labelFilterAktif  = nil

local function safeLabel(lbl, text)
    if lbl == nil then return end
    pcall(function() lbl:SetText(tostring(text or "")) end)
end

local function isUsed(word)
    return usedWords[string.lower(word)] == true
end

local function updateKataLabel()
    local count = #usedWordsList
    if count == 0 then
        safeLabel(labelRiwayat, "Riwayat  :  (belum ada)")
    else
        local display = ""
        local start = math.max(1, count - 7)
        for i = start, count do
            display = display .. usedWordsList[i]
            if i < count then display = display .. "  ·  " end
        end
        if count > 8 then display = "…  " .. display end
        safeLabel(labelRiwayat, "Riwayat  [" .. count .. "]  :  " .. display)
    end
end

local function addUsedWord(word)
    if not word then return end
    local w = string.lower(tostring(word))
    if not usedWords[w] then
        usedWords[w] = true
        table.insert(usedWordsList, w)
        stats.totalWords = (stats.totalWords or 0) + 1
        local longest = tostring(stats.longestWord or "")
        if string.len(w) > string.len(longest) then
            stats.longestWord = w
        end
        updateKataLabel()
    end
end

local function resetUsedWords()
    usedWords     = {}
    usedWordsList = {}
    updateKataLabel()
end

local function updateStatsLabels()
    local elapsed        = os.time() - (stats.sessionStart or os.time())
    local minutes        = math.floor(elapsed / 60)
    local seconds        = elapsed % 60
    local longest        = tostring(stats.longestWord or "")
    local displayLongest = (longest ~= "") and longest or "—"
    safeLabel(labelKataDikirim, "Kata Dikirim    :  " .. tostring(stats.totalWords or 0))
    safeLabel(labelKataPanjang, "Kata Terpanjang :  " .. displayLongest)
    safeLabel(labelDurasi,      "Durasi Sesi     :  " .. tostring(minutes) .. "m " .. tostring(seconds) .. "s")
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

    for i = 1, #kataModule do
        local word = kataModule[i]
        if string.sub(word, 1, #lowerPrefix) == lowerPrefix and not isUsed(word) then
            local len = string.len(word)
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

-- Stats auto-update setiap 10 detik
task.spawn(function()
    while true do
        task.wait(10)
        if matchActive then pcall(updateStatsLabels) end
    end
end)

-- =========================
-- BUILD UI — LINORIA
-- =========================
local Window = Library:CreateWindow({
    Title        = 'NAKA  ⚔  AUTO KATA',
    Center       = true,
    AutoShow     = true,
    TabPadding   = 8,
    MenuFadeTime = 0.2,
    MenuKeybind  = 'J',   -- Tekan J untuk buka/tutup UI
})

local Tabs = {
    Battle   = Window:AddTab('⚔  Battle'),
    Settings = Window:AddTab('⚙  Settings'),
    Info     = Window:AddTab('📋  Info'),
}

-- ╔══════════════════════════════════╗
-- ║  TAB 1 — BATTLE                  ║
-- ╚══════════════════════════════════╝

-- ── LEFT: STATUS LIVE ───────────────
local StatusBox = Tabs.Battle:AddLeftGroupbox('◈  Status Live')

labelTurnStatus = StatusBox:AddLabel('Giliran      :  ⏳ Menunggu...')
labelHuruf      = StatusBox:AddLabel('Huruf Awalan :  —')
labelLawan      = StatusBox:AddLabel('Lawan        :  ⏳ Menunggu...')

StatusBox:AddDivider()

-- Toggle utama
StatusBox:AddToggle('AutoKataToggle', {
    Text    = '⚡  Auto Kata',
    Default = false,
    Tooltip = 'Aktifkan AI untuk bermain otomatis',
    Callback = function(Value)
        autoEnabled = Value
        if Value then
            Library:Notify('⚡  Auto Kata ON — AI siap dominasi!', 3)
            if matchActive and isMyTurn and serverLetter ~= "" then
                task.spawn(startUltraAI)
            end
        else
            Library:Notify('⚡  Auto Kata OFF', 2)
        end
    end
})

StatusBox:AddToggle('RareModeToggle', {
    Text    = '🃏  Mode Kata Langka',
    Default = false,
    Tooltip = 'Pilih kata yang jarang dipakai orang lain',
    Callback = function(Value) config.preferRare = Value end
})

-- ── RIGHT: FILTER TRAP ──────────────
local FilterBox = Tabs.Battle:AddRightGroupbox('◈  Filter Akhiran  ( Trap )')

labelFilterAktif = FilterBox:AddLabel('Filter  :  semua kata')

FilterBox:AddDropdown('FilterDropdown', {
    Text    = 'Pilih Akhiran (multi)',
    Values  = {"a","i","u","e","o","n","r","s","t","k","h","l","m","p","g","j","f","v","z","x","q","w","y"},
    Default = {},
    Multi   = true,
    Tooltip = 'Pilih beberapa huruf akhiran sekaligus',
    Callback = function(Value)
        local selected = {}
        if type(Value) == "table" then
            for k, v in pairs(Value) do
                if v == true then
                    table.insert(selected, string.lower(tostring(k)))
                end
            end
        end
        config.filterEnding = selected
        if #selected == 0 then
            safeLabel(labelFilterAktif, "Filter  :  semua kata")
        else
            local display = table.concat(selected, "  ·  ")
            safeLabel(labelFilterAktif, "Filter  :  " .. display)
        end
    end
})

FilterBox:AddDivider()

FilterBox:AddButton({
    Text        = '💀  TRAP MODE  ( x·q·z·f·v )',
    Func        = function()
        config.filterEnding = {"x","q","z","f","v"}
        safeLabel(labelFilterAktif, "Filter  :  x  ·  q  ·  z  ·  f  ·  v   💀")
        Library:Notify('💀  TRAP MODE ON — Lawan akan kesulitan!', 4)
    end,
    Tooltip = 'Set filter ke huruf paling susah sekaligus',
})

FilterBox:AddButton({
    Text = '↺  Reset Filter',
    Func = function()
        config.filterEnding = {}
        safeLabel(labelFilterAktif, "Filter  :  semua kata")
        Library:Notify('Filter direset', 2)
    end,
})

FilterBox:AddDivider()

-- Statistik ringkas di kanan bawah
local StatsBox = Tabs.Battle:AddRightGroupbox('◈  Statistik')

labelKataDikirim = StatsBox:AddLabel('Kata Dikirim    :  0')
labelKataPanjang = StatsBox:AddLabel('Kata Terpanjang :  —')
labelDurasi      = StatsBox:AddLabel('Durasi Sesi     :  0m 0s')
labelRiwayat     = StatsBox:AddLabel('Riwayat  :  (belum ada)')

StatsBox:AddDivider()

StatsBox:AddButton({
    Text = '↺  Reset Semua',
    Func = function()
        stats.totalWords   = 0
        stats.longestWord  = ""
        stats.sessionStart = os.time()
        usedWords          = {}
        usedWordsList      = {}
        updateStatsLabels()
        updateKataLabel()
        Library:Notify('Statistik & riwayat direset', 3)
    end,
})

-- ╔══════════════════════════════════╗
-- ║  TAB 2 — SETTINGS                ║
-- ╚══════════════════════════════════╝

-- ── LEFT: AI PARAMETER ─────────────
local AIBox = Tabs.Settings:AddLeftGroupbox('◈  Parameter AI')

AIBox:AddSlider('AggressionSlider', {
    Text    = 'Agresivitas',
    Default = config.aggression,
    Min     = 0,
    Max     = 100,
    Rounding = 0,
    Tooltip = '0 = santai  |  100 = pilih kata terpanjang selalu',
    Callback = function(Value) config.aggression = Value end
})

AIBox:AddSlider('MinLenSlider', {
    Text    = 'Panjang Minimum',
    Default = config.minLength,
    Min     = 2,
    Max     = 6,
    Rounding = 0,
    Callback = function(Value) config.minLength = Value end
})

AIBox:AddSlider('MaxLenSlider', {
    Text    = 'Panjang Maksimum',
    Default = config.maxLength,
    Min     = 5,
    Max     = 20,
    Rounding = 0,
    Callback = function(Value) config.maxLength = Value end
})

-- ── RIGHT: ANTI DETECT ─────────────
local AntiBox = Tabs.Settings:AddRightGroupbox('◈  Anti-Detect')

AntiBox:AddToggle('AntiDetectToggle', {
    Text    = '🛡  Simulasi Manusia',
    Default = true,
    Tooltip = 'Variasi delay agar terlihat seperti manusia mengetik',
    Callback = function(Value)
        config.antiDetectMode = Value
        Library:Notify(Value and '🛡  Anti-Detect ON' or '🛡  Anti-Detect OFF', 2)
    end
})

AntiBox:AddDivider()

AntiBox:AddSlider('MinDelaySlider', {
    Text    = 'Delay Minimum (ms)',
    Default = config.minDelay,
    Min     = 50,
    Max     = 600,
    Rounding = 0,
    Callback = function(Value) config.minDelay = Value end
})

AntiBox:AddSlider('MaxDelaySlider', {
    Text    = 'Delay Maksimum (ms)',
    Default = config.maxDelay,
    Min     = 100,
    Max     = 1200,
    Rounding = 0,
    Callback = function(Value) config.maxDelay = Value end
})

AntiBox:AddDivider()
AntiBox:AddLabel('🟢  AMAN        →  500ms – 800ms')
AntiBox:AddLabel('🟡  SEDANG    →  300ms – 499ms')
AntiBox:AddLabel('🔴  BERISIKO  →  50ms  – 299ms')

-- ╔══════════════════════════════════╗
-- ║  TAB 3 — INFO                    ║
-- ╚══════════════════════════════════╝

local AboutBox = Tabs.Info:AddLeftGroupbox('◈  Tentang')

AboutBox:AddLabel('NAKA AUTO KATA  —  v4.0')
AboutBox:AddLabel('Pembuat   :  NAKA')
AboutBox:AddLabel('Kamus     :  80.000+ kata Indonesia')
AboutBox:AddLabel('UI        :  LinoriaLib')
AboutBox:AddLabel('Wordlist  :  danzzy1we')
AboutBox:AddDivider()
AboutBox:AddLabel('⌨  Keybind')
AboutBox:AddLabel('[ J ]  →  Buka / Tutup UI')

local GuideBox = Tabs.Info:AddRightGroupbox('◈  Cara Pakai')

GuideBox:AddLabel('1.  Buka tab  ⚔ Battle')
GuideBox:AddLabel('2.  Aktifkan  ⚡ Auto Kata')
GuideBox:AddLabel('3.  Set filter akhiran jika perlu')
GuideBox:AddLabel('4.  Masuk pertandingan')
GuideBox:AddLabel('5.  AI otomatis bermain!')
GuideBox:AddDivider()
GuideBox:AddLabel('💀  TRAP MODE = dominasi total')
GuideBox:AddLabel('⚡  Agresivitas 80+ = kata terpanjang')
GuideBox:AddLabel('🛡  Delay 500ms+ = paling aman')
GuideBox:AddLabel('🔡  Multi akhiran = variasi trap')
GuideBox:AddLabel('[ J ]  = sembunyikan UI saat diperlukan')

-- =========================
-- THEME & SAVE MANAGER
-- =========================
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

ThemeManager:SetFolder('NAKA')
SaveManager:SetFolder('NAKA/AutoKata')

-- Tab Theme + Keybind
local UISettingsTab = Window:AddTab('🎨  Theme')

local KeybindBox = UISettingsTab:AddLeftGroupbox('◈  Keybind')
KeybindBox:AddLabel('Buka / Tutup UI')
KeybindBox:AddKeybind('MenuKeybind', {
    Text    = 'Toggle UI',
    Default = 'J',
    Tooltip = 'Tekan tombol ini untuk buka/tutup UI',
    Callback = function(Value)
        -- Linoria handle toggle UI otomatis via MenuKeybind
    end
})

local MenuGroup = UISettingsTab:AddRightGroupbox('◈  Theme')
ThemeManager:ApplyToGroupbox(MenuGroup)

local SaveGroup = UISettingsTab:AddLeftGroupbox('◈  Config')
SaveManager:AddIgnoreButton(SaveGroup)
SaveManager:AddSaveSection(SaveGroup)

SaveManager:LoadAutoloadConfig()

-- Hubungkan keybind J ke toggle UI
Library.Toggleable = true
Options.MenuKeybind:OnChanged(function()
    Library:SetVisible(not Library.Visible)
end)

-- =========================
-- REMOTE EVENT HANDLERS
-- =========================
local function onMatchUI(cmd, value)
    if cmd == "ShowMatchUI" then
        matchActive = true
        isMyTurn    = false
        resetUsedWords()
        safeLabel(labelTurnStatus, "Giliran      :  ⏳ Menunggu giliran...")
        safeLabel(labelLawan,      "Lawan        :  👀 Pertandingan dimulai!")
        updateStatsLabels()

    elseif cmd == "HideMatchUI" then
        matchActive  = false
        isMyTurn     = false
        serverLetter = ""
        resetUsedWords()
        safeLabel(labelTurnStatus, "Giliran      :  ❌ Pertandingan selesai")
        safeLabel(labelLawan,      "Lawan        :  ⏳ Menunggu...")
        safeLabel(labelHuruf,      "Huruf Awalan :  —")
        updateStatsLabels()

    elseif cmd == "StartTurn" then
        isMyTurn = true
        safeLabel(labelTurnStatus, "Giliran      :  ✅ GILIRAN KAMU!")
        updateStatsLabels()
        if autoEnabled and serverLetter ~= "" then
            task.spawn(startUltraAI)
        end

    elseif cmd == "EndTurn" then
        isMyTurn = false
        safeLabel(labelTurnStatus, "Giliran      :  ⏳ Giliran lawan...")
        updateStatsLabels()

    elseif cmd == "UpdateServerLetter" then
        serverLetter = tostring(value or "")
        local display = (serverLetter ~= "") and string.upper(serverLetter) or "—"
        safeLabel(labelHuruf, "Huruf Awalan :  " .. display)
        if autoEnabled and matchActive and isMyTurn then
            task.spawn(startUltraAI)
        end
    end
end

local function onBillboard(word)
    if matchActive and not isMyTurn then
        opponentStreamWord = tostring(word or "")
        local dw = (opponentStreamWord ~= "") and opponentStreamWord or "..."
        safeLabel(labelLawan, "Lawan        :  ✍ " .. dw)
    end
end

local function onUsedWarn(word)
    if word then
        addUsedWord(word)
        updateStatsLabels()
        if autoEnabled and matchActive and isMyTurn then
            task.wait(math.random(200, 400) / 1000)
            task.spawn(startUltraAI)
        end
    end
end

MatchUI.OnClientEvent:Connect(onMatchUI)
BillboardUpdate.OnClientEvent:Connect(onBillboard)
UsedWordWarn.OnClientEvent:Connect(onUsedWarn)

print("NAKA AUTO KATA v4.0 LINORIA — LOADED SUCCESSFULLY")
