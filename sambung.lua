-- =========================================================
-- ULTRA SMART AUTO KATA v5.0 — NAKA
-- NEW: Human Typing Simulator + Kata Bom System
-- KEY SYSTEM: 1 Key = 1 Device (Permanent, Hardware Locked)
-- MODE SYSTEM: Natural / Seimbang / Kompetitif
-- =========================================================

if game:IsLoaded() == false then
    game.Loaded:Wait()
end

local httpget = game.HttpGet
local loadstr = loadstring

local RayfieldSource = httpget(game, "https://sirius.menu/rayfield")
if RayfieldSource == nil then warn("Gagal ambil Rayfield source") return end
local RayfieldFunction = loadstr(RayfieldSource)
if RayfieldFunction == nil then warn("Gagal compile Rayfield") return end
local Rayfield = RayfieldFunction()
if Rayfield == nil then warn("Rayfield return nil") return end

-- =========================================================
-- KEY SYSTEM
-- =========================================================
local KEY_DATABASE_URL  = "https://raw.githubusercontent.com/Ihsan-ct/naka/refs/heads/main/keys.json"
local BIND_ENDPOINT_URL = "https://script.google.com/macros/s/AKfycbxJEVTEuVV6Aa9lHo4pHrQ8RRbypTqCcGiUtsYdan4JnFTs964Sq73coAojyLkjg1IXDg/exec"

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

local function getDeviceHWID()
    local userId     = tostring(LocalPlayer.UserId)
    local accountAge = tostring(LocalPlayer.AccountAge)
    local UIS        = game:GetService("UserInputService")
    local platform   = "UNKNOWN"
    pcall(function()
        if UIS.TouchEnabled and not UIS.KeyboardEnabled then platform = "MOBILE"
        elseif UIS.GamepadEnabled and not UIS.KeyboardEnabled then platform = "CONSOLE"
        else platform = "PC" end
    end)
    local raw  = userId .. "-" .. accountAge .. "-" .. platform
    local hash = 5381
    for i = 1, #raw do
        local c = string.byte(raw, i)
        hash = ((hash * 33) + c) % 2147483647
    end
    return string.format("HWID-%s-%X-%s", string.sub(userId,1,6), hash, platform)
end

local DEVICE_HWID = getDeviceHWID()
print("[KeySystem] Device HWID:", DEVICE_HWID)

local SAVE_FOLDER = "NAKA_Keys"
local SAVE_FILE   = SAVE_FOLDER .. "/verified.dat"

local function saveVerifiedKey(key)
    pcall(function()
        if not isfolder(SAVE_FOLDER) then makefolder(SAVE_FOLDER) end
        local encoded = ""
        for i = 1, #key do
            local c = string.byte(key, i)
            local h = string.byte(DEVICE_HWID, ((i-1) % #DEVICE_HWID) + 1)
            encoded = encoded .. string.char(bit32.bxor(c, h))
        end
        local hex = ""
        for i = 1, #encoded do hex = hex .. string.format("%02X", string.byte(encoded, i)) end
        writefile(SAVE_FILE, hex .. "|" .. DEVICE_HWID)
    end)
end

local function loadSavedKey()
    local result = nil
    pcall(function()
        if isfile(SAVE_FILE) then
            local content   = readfile(SAVE_FILE)
            local sep       = string.find(content, "|")
            if not sep then return end
            local hex       = string.sub(content, 1, sep - 1)
            local savedHwid = string.sub(content, sep + 1)
            if savedHwid ~= DEVICE_HWID then delfile(SAVE_FILE) return end
            local encoded = ""
            for i = 1, #hex, 2 do
                local byte = tonumber(string.sub(hex, i, i+1), 16)
                if byte then encoded = encoded .. string.char(byte) end
            end
            local key = ""
            for i = 1, #encoded do
                local c = string.byte(encoded, i)
                local h = string.byte(DEVICE_HWID, ((i-1) % #DEVICE_HWID) + 1)
                key = key .. string.char(bit32.bxor(c, h))
            end
            if #key > 5 then result = key end
        end
    end)
    return result
end

local function validateKeyOnline(inputKey)
    local dbRaw = nil
    local ok = pcall(function() dbRaw = httpget(game, KEY_DATABASE_URL) end)
    if not ok or not dbRaw or dbRaw == "" then
        local savedKey = loadSavedKey()
        if savedKey and savedKey == inputKey then
            return true, "✅ Verifikasi cache lokal berhasil! (Offline mode)"
        end
        return false, "❌ Tidak bisa terhubung ke server key!"
    end
    local keyDatabase = {}
    pcall(function() keyDatabase = HttpService:JSONDecode(dbRaw) end)
    if not keyDatabase then return false, "❌ Database key error. Hubungi admin!" end
    local keyUpper = string.upper(inputKey)
    if keyDatabase[keyUpper] == nil then return false, "❌ Key tidak ditemukan!" end
    local boundHWID = keyDatabase[keyUpper]
    if boundHWID == "" or boundHWID == "UNBOUND" then
        pcall(function()
            httpget(game, BIND_ENDPOINT_URL .. "?action=bind&key=" .. keyUpper .. "&hwid=" .. DEVICE_HWID)
        end)
        return true, "✅ Key valid! Device berhasil didaftarkan."
    end
    if boundHWID == DEVICE_HWID then return true, "✅ Key valid! Device dikenali." end
    return false, "❌ Key sudah dipakai di device lain! 1 Key = 1 Device."
end

local keyVerified = false

local function runKeySystem()
    local savedKey = loadSavedKey()
    if savedKey then
        local ok, msg = validateKeyOnline(savedKey)
        if ok then
            keyVerified = true
            Rayfield:Notify({ Title="🔑 Key Terverifikasi", Content="Auto-login berhasil! "..msg, Duration=4, Image=4483362458 })
            return true
        else
            pcall(function() delfile(SAVE_FILE) end)
        end
    end

    local KeyWindow = Rayfield:CreateWindow({
        Name="🔑  NAKA KEY SYSTEM", LoadingTitle="Verifikasi Key",
        LoadingSubtitle="1 Key = 1 Device | Permanent",
        ConfigurationSaving={Enabled=false}, Discord={Enabled=false}, KeySystem=false
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
        Name="🔑  Key Aktivasi", PlaceholderText="Contoh: NAKA-XXXX-YYYY-ZZZZ",
        RemoveTextAfterFocusLost=false,
        Callback=function(Value) inputKeyValue = string.upper(string.gsub(Value, "%s+", "")) end
    })
    KeyTab:CreateButton({
        Name="✅  VERIFIKASI KEY",
        Callback=function()
            if inputKeyValue == "" then
                pcall(function() statusLabel:Set("◦  Status  :  ❌ Key tidak boleh kosong!") end)
                return
            end
            pcall(function() statusLabel:Set("◦  Status  :  ⏳ Memverifikasi ke server...") end)
            task.spawn(function()
                local ok, msg = validateKeyOnline(inputKeyValue)
                if ok then
                    saveVerifiedKey(inputKeyValue)
                    keyVerified = true
                    pcall(function() statusLabel:Set("◦  Status  :  " .. msg) end)
                    Rayfield:Notify({ Title="✅  Key Valid!", Content=msg, Duration=5, Image=4483362458 })
                    task.wait(2)
                    pcall(function() KeyWindow:Destroy() end)
                else
                    pcall(function() statusLabel:Set("◦  Status  :  " .. msg) end)
                    Rayfield:Notify({ Title="❌  Key Ditolak", Content=msg, Duration=5, Image=4483362458 })
                end
            end)
        end
    })
    KeyTab:CreateSection("◈  CARA MENDAPATKAN KEY")
    KeyTab:CreateLabel("1️⃣   Hubungi admin NAKA — Discord: qin")
    KeyTab:CreateLabel("2️⃣   Harga Rp20.000 / key (permanent)")
    KeyTab:CreateLabel("3️⃣   Masukkan key di atas")
    KeyTab:CreateLabel("4️⃣   Key terikat ke device ini selamanya")

    local timeout = 0
    while not keyVerified do
        task.wait(0.5)
        timeout = timeout + 0.5
        if timeout > 300 then warn("[KeySystem] Timeout") return false end
    end
    return true
end

local keyOk = runKeySystem()
if not keyOk then warn("[NAKA] Key verification gagal.") return end
print("[NAKA] Key verified! Memuat script utama...")
task.wait(1)

-- =========================================================
-- SCRIPT UTAMA
-- =========================================================

local GetService        = game.GetService
local ReplicatedStorage = GetService(game, "ReplicatedStorage")

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
        if string.len(w) > 1 then table.insert(kataModule, w) end
    end
    return true
end
local wordOk = downloadWordlist()
if not wordOk or #kataModule == 0 then warn("Wordlist gagal dimuat!") return end
print("Wordlist Loaded:", #kataModule)

local remotes         = ReplicatedStorage:WaitForChild("Remotes")
local MatchUI         = remotes:WaitForChild("MatchUI")
local SubmitWord      = remotes:WaitForChild("SubmitWord")
local BillboardUpdate = remotes:WaitForChild("BillboardUpdate")
local BillboardEnd    = remotes:WaitForChild("BillboardEnd")
local TypeSound       = remotes:WaitForChild("TypeSound")
local UsedWordWarn    = remotes:WaitForChild("UsedWordWarn")

local matchActive        = false
local isMyTurn           = false
local serverLetter       = ""
local usedWords          = {}
local usedWordsList      = {}
local opponentStreamWord = ""
local autoEnabled        = false
local autoRunning        = false

local stats = { totalWords=0, longestWord="", sessionStart=os.time(), bombsFired=0 }

-- =========================================================
-- KONFIGURASI + MODE SYSTEM
-- =========================================================
local config = {
    minDelay       = 500,
    maxDelay       = 750,
    aggression     = 50,
    minLength      = 3,
    maxLength      = 12,
    filterEnding   = {},
    antiDetectMode = true,
    preferRare     = false,
    bombMode       = false,
    bombTier       = "auto",
    playMode       = "seimbang",  -- "natural" | "seimbang" | "kompetitif"
}

local function safeSet(p, c)
    if p == nil then return end
    pcall(function() p:Set(tostring(c or "")) end)
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

-- Terapkan profil typing sesuai mode
local function applyModeToProfile()
    if config.playMode == "natural" then
        humanProfile.baseSpeed      = math.random(450, 650)
        humanProfile.mistakeChance  = math.random(10, 18) / 100
        humanProfile.hesitateChance = math.random(15, 25) / 100
        humanProfile.isBurstyTyper  = false
        humanProfile.fatigueRate    = math.random(3, 6)
        humanProfile.doubleTypoRate = math.random(5, 10) / 100
    elseif config.playMode == "kompetitif" then
        humanProfile.baseSpeed      = math.random(200, 350)
        humanProfile.mistakeChance  = math.random(3, 7) / 100
        humanProfile.hesitateChance = math.random(4, 9) / 100
        humanProfile.isBurstyTyper  = true
        humanProfile.fatigueRate    = math.random(1, 2)
        humanProfile.doubleTypoRate = math.random(1, 3) / 100
    else -- seimbang
        humanProfile.baseSpeed      = math.random(350, 550)
        humanProfile.mistakeChance  = math.random(6, 13) / 100
        humanProfile.hesitateChance = math.random(8, 18) / 100
        humanProfile.isBurstyTyper  = math.random(1,2) == 1
        humanProfile.fatigueRate    = math.random(1, 4)
        humanProfile.doubleTypoRate = math.random(2, 6) / 100
    end
    humanProfile.wordCount = 0
    print(string.format("[Mode: %s] spd=%dms typo=%.0f%% hesitate=%.0f%%",
        config.playMode, humanProfile.baseSpeed,
        humanProfile.mistakeChance*100, humanProfile.hesitateChance*100))
end

applyModeToProfile()

print(string.format("[HumanProfile] spd=%dms | typo=%.0f%% | hesitate=%.0f%%",
    humanProfile.baseSpeed, humanProfile.mistakeChance*100, humanProfile.hesitateChance*100))

local NEIGHBORS = {
    a={"q","w","s","z"}, b={"v","g","h","n"}, c={"x","d","f","v"},
    d={"s","e","r","f","c","x"}, e={"w","r","d","s"}, f={"d","r","t","g","v","c"},
    g={"f","t","y","h","b","v"}, h={"g","y","u","j","n","b"}, i={"u","o","k","j"},
    j={"h","u","i","k","n","m"}, k={"j","i","o","l","m"}, l={"k","o","p"},
    m={"n","j","k"}, n={"b","h","j","m"}, o={"i","p","l","k"}, p={"o","l"},
    q={"w","a"}, r={"e","t","f","d"}, s={"a","w","e","d","x","z"},
    t={"r","y","g","f"}, u={"y","i","h","j"}, v={"c","f","g","b"},
    w={"q","e","s","a"}, x={"z","s","d","c"}, y={"t","u","g","h"}, z={"a","s","x"},
}

local function getNearbyChar(char)
    local nb = NEIGHBORS[char]
    if nb and #nb > 0 then return nb[math.random(1, #nb)] end
    return string.sub("abcdefghijklmnopqrstuvwxyz", math.random(1,26), math.random(1,26))
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
        if progress < 0.35 then base = base * 0.85
        elseif progress > 0.75 then base = base * 1.4 end
    end
    if charIndex == 1 then base = base + math.random(800, 2500) end
    local noise = math.random(-15, 15) / 100
    base = base * (1 + noise)
    if math.random(1, 10) == 1 then base = base + math.random(200, 600) end
    if base < 120 then base = 120 end
    return math.floor(base)
end

local function humanTypeWord(selectedWord, serverPrefix)
    humanProfile.wordCount = humanProfile.wordCount + 1
    local currentDisplay = serverPrefix
    local remain         = string.sub(selectedWord, #serverPrefix + 1)
    local chars          = {}
    for i = 1, #remain do table.insert(chars, string.sub(remain, i, i)) end
    local i = 1
    while i <= #chars do
        if not matchActive or not isMyTurn then return false end
        local correctChar = chars[i]
        local rolled      = math.random()
        if math.random() < humanProfile.hesitateChance then
            waitMs(math.random(400, 900))
            if math.random(1,4) == 1 and #currentDisplay > #serverPrefix then
                currentDisplay = string.sub(currentDisplay, 1, #currentDisplay - 1)
                TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay)
                waitMs(math.random(100, 300))
                currentDisplay = currentDisplay .. string.sub(selectedWord, #currentDisplay+1, #currentDisplay+1)
                TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay)
                waitMs(charDelay(i, #chars)); i = i + 1; continue
            end
        end
        if rolled < humanProfile.doubleTypoRate and i <= #chars - 1 then
            local wrong1 = getNearbyChar(correctChar)
            local wrong2 = getNearbyChar(chars[i+1] or correctChar)
            currentDisplay = currentDisplay .. wrong1
            TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(charDelay(i,#chars)*0.6)
            currentDisplay = currentDisplay .. wrong2
            TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(math.random(80,200))
            currentDisplay = string.sub(currentDisplay,1,#currentDisplay-1)
            TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(math.random(60,150))
            currentDisplay = string.sub(currentDisplay,1,#currentDisplay-1)
            TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(math.random(80,220))
            currentDisplay = currentDisplay .. correctChar
            TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(charDelay(i,#chars)); i=i+1
        elseif rolled < (humanProfile.doubleTypoRate + humanProfile.mistakeChance) then
            local wrongChar = getNearbyChar(correctChar)
            currentDisplay = currentDisplay .. wrongChar
            TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(math.random(50,300))
            if math.random(1,5) <= 2 and i < #chars then
                currentDisplay = currentDisplay .. (chars[i+1] or correctChar)
                TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(math.random(60,180))
                currentDisplay = string.sub(currentDisplay,1,#currentDisplay-1)
                TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(math.random(50,130))
            end
            currentDisplay = string.sub(currentDisplay,1,#currentDisplay-1)
            TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(math.random(80,250))
            currentDisplay = currentDisplay .. correctChar
            TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(charDelay(i,#chars)); i=i+1
        else
            currentDisplay = currentDisplay .. correctChar
            TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(charDelay(i,#chars)); i=i+1
        end
    end
    waitMs(math.random(300, 800))
    return true
end

-- =========================================================
-- SCORING SYSTEM — MODE AWARE
-- =========================================================
local COMMON_WORDS = {
    makan=true,minum=true,pergi=true,pulang=true,tidur=true,
    bangun=true,jalan=true,lari=true,duduk=true,kerja=true,
    main=true,baca=true,tulis=true,lihat=true,dengar=true,
    bicara=true,mandi=true,cuci=true,datang=true,cari=true,
    masak=true,beli=true,jual=true,ambil=true,taruh=true,
    naik=true,turun=true,masuk=true,keluar=true,lewat=true,
    tanya=true,jawab=true,bantu=true,beri=true,kirim=true,
    rumah=true,sekolah=true,pasar=true,taman=true,kamar=true,
    dapur=true,meja=true,kursi=true,pintu=true,nasi=true,
    baju=true,sepatu=true,mobil=true,motor=true,uang=true,
    teman=true,keluarga=true,orang=true,ibu=true,bapak=true,
    kakak=true,adik=true,pohon=true,bunga=true,hujan=true,
    buku=true,pensil=true,kertas=true,toko=true,warung=true,
    kepala=true,tangan=true,kaki=true,mata=true,mulut=true,
    besar=true,kecil=true,cepat=true,lambat=true,bagus=true,
    senang=true,sedih=true,pintar=true,rajin=true,murah=true,
    mahal=true,baru=true,lama=true,penuh=true,cantik=true,
    indah=true,berani=true,jujur=true,baik=true,jahat=true,
    sudah=true,belum=true,sedang=true,selalu=true,sering=true,
    karena=true,supaya=true,tetapi=true,dengan=true,untuk=true,
    sangat=true,sekali=true,hampir=true,masih=true,terus=true,
    kembali=true,ternyata=true,memang=true,tentu=true,pasti=true,
    coba=true,tolong=true,mohon=true,harap=true,sayang=true,
    suka=true,cinta=true,rindu=true,kangen=true,ingin=true,
    minta=true,harap=true,usaha=true,kerja=true,latih=true,
}

local HARD_ENDINGS = {
    ["x"]=10,["q"]=10,["f"]=8,["v"]=8,
    ["z"]=9, ["y"]=6, ["w"]=5,["j"]=7,
    ["k"]=4, ["h"]=3,
}

local function scoreWord(word)
    local score = 0
    local len   = #word
    local mode  = config.playMode

    if mode == "natural" then
        if COMMON_WORDS[word] then score = score + 60 end
        if len >= 3 and len <= 5 then score = score + 20
        elseif len >= 6 and len <= 7 then score = score + 10
        elseif len >= 8 and len <= 9 then score = score + 3
        elseif len >= 10 then score = score - 15 end
        local lastChar = string.sub(word,-1)
        if HARD_ENDINGS[lastChar] then score = score + math.floor(HARD_ENDINGS[lastChar]/3) end

    elseif mode == "kompetitif" then
        if COMMON_WORDS[word] then score = score + 5 end
        score = score + (len * 3)
        if len >= 12 then score = score + 25
        elseif len >= 10 then score = score + 18
        elseif len >= 8 then score = score + 10
        elseif len >= 6 then score = score + 4 end
        local lastChar = string.sub(word,-1)
        if HARD_ENDINGS[lastChar] then score = score + (HARD_ENDINGS[lastChar] * 2) end

    else -- seimbang
        if COMMON_WORDS[word] then score = score + 30 end
        score = score + len
        if len >= 12 then score = score + 10
        elseif len >= 9 then score = score + 6
        elseif len >= 6 then score = score + 2 end
        local lastChar = string.sub(word,-1)
        if HARD_ENDINGS[lastChar] then score = score + HARD_ENDINGS[lastChar] end
    end

    return math.floor(score)
end

-- =========================================================
-- 💣 KATA BOM SYSTEM
-- =========================================================
local BOM_TIERS = {
    biasa={"f","v","w","y"}, kuat={"x","q","z"}, mega={"x","q","z","f","v"},
}
local letterCountCache = {}
local function buildLetterCache()
    for _, word in ipairs(kataModule) do
        local fc = string.sub(word,1,1)
        letterCountCache[fc] = (letterCountCache[fc] or 0) + 1
    end
end
task.spawn(buildLetterCache)

local function getBombScore(word)
    local lastChar = string.sub(word,-1)
    local count    = letterCountCache[lastChar] or 9999
    local len      = #word
    local score    = 0
    if count < 50 then score=score+100 elseif count<150 then score=score+60
    elseif count<400 then score=score+30 elseif count<800 then score=score+10 end
    if len>=12 then score=score+30 elseif len>=9 then score=score+15 elseif len>=7 then score=score+5 end
    return score
end

local function getBombTier(score)
    if score>=120 then return "mega" elseif score>=60 then return "kuat"
    elseif score>=20 then return "biasa" else return nil end
end

local function findBombWord(prefix, tierTarget)
    local candidates  = {}
    local lowerPrefix = string.lower(prefix)
    local allowedEndings = {}
    local tiers = tierTarget=="mega" and {BOM_TIERS.mega}
        or tierTarget=="kuat" and {BOM_TIERS.kuat,BOM_TIERS.mega}
        or {BOM_TIERS.biasa,BOM_TIERS.kuat,BOM_TIERS.mega}
    for _, t in ipairs(tiers) do for _, e in ipairs(t) do allowedEndings[e]=true end end
    for _, word in ipairs(kataModule) do
        if string.sub(word,1,#lowerPrefix)==lowerPrefix and not usedWords[word]
            and #word>=config.minLength and #word<=config.maxLength then
            if allowedEndings[string.sub(word,-1)] then
                local bs = getBombScore(word)
                if bs>0 then table.insert(candidates,{word=word,score=bs}) end
            end
        end
    end
    table.sort(candidates, function(a,b) return a.score>b.score end)
    if #candidates>0 then return candidates[1].word, getBombTier(candidates[1].score), candidates[1].score end
    return nil, nil, 0
end

local labelBombStatus = nil
local labelBombStock  = nil

local function updateBombUI(word, tier, score)
    if not labelBombStatus then return end
    if word then
        local icon = tier=="mega" and "💣💣💣" or tier=="kuat" and "💣💣" or "💣"
        pcall(function() labelBombStatus:Set(icon.."  Bom Siap  :  "..string.upper(word).."  [ Tier: "..string.upper(tier or "?").."  |  Skor: "..tostring(score).." ]") end)
    else
        pcall(function() labelBombStatus:Set("💣  Tidak ada kata bom untuk huruf ini") end)
    end
end

local function updateBombStock()
    if not labelBombStock then return end
    local n=0
    for _, word in ipairs(kataModule) do if getBombScore(word)>=20 then n=n+1 end end
    pcall(function() labelBombStock:Set("◦  Stok Kata Bom  :  ~"..tostring(n).." kata") end)
end

-- =========================================================
-- WORD MANAGEMENT
-- =========================================================
local function isUsed(word) return usedWords[string.lower(word)]==true end

local function addUsedWord(word)
    if not word then return end
    local w = string.lower(tostring(word))
    if not usedWords[w] then
        usedWords[w]=true; table.insert(usedWordsList,w)
        stats.totalWords=(stats.totalWords or 0)+1
        if #w>#(stats.longestWord or "") then stats.longestWord=w end
    end
end

local function resetUsedWords() usedWords={}; usedWordsList={} end

local function getSmartWords(prefix)
    local results     = {}
    local lowerPrefix = string.lower(prefix)
    local filterSet   = {}
    local hasFilter   = false
    for _, v in ipairs(config.filterEnding) do
        local lv = string.lower(tostring(v))
        if lv~="semua" and lv~="" then filterSet[lv]=true; hasFilter=true end
    end

    -- Range panjang kata otomatis per mode
    local minLen = config.minLength
    local maxLen = config.maxLength
    if config.playMode == "natural" then
        minLen = math.max(config.minLength, 3)
        maxLen = math.min(config.maxLength, 8)
    elseif config.playMode == "kompetitif" then
        minLen = math.max(config.minLength, 5)
        maxLen = config.maxLength
    end

    for _, word in ipairs(kataModule) do
        if string.sub(word,1,#lowerPrefix)==lowerPrefix and not isUsed(word) then
            local len = #word
            if len>=minLen and len<=maxLen then
                local pass = true
                if hasFilter and not filterSet[string.sub(word,-1)] then pass=false end
                if pass then table.insert(results, word) end
            end
        end
    end
    table.sort(results, function(a,b) return scoreWord(a)>scoreWord(b) end)
    return results
end

-- =========================================================
-- AUTO ENGINE
-- =========================================================
local function startUltraAI()
    if autoRunning or not autoEnabled or not matchActive
       or not isMyTurn or serverLetter=="" then return end
    autoRunning = true
    task.wait(math.random(config.minDelay, config.maxDelay)/1000)

    local selectedWord=nil; local isBomb=false; local bombTierUsed=nil; local bombScore=0

    -- Bom hanya aktif di mode kompetitif atau jika bombMode dinyalakan manual
    if config.bombMode or config.playMode=="kompetitif" then
        local bWord,bTier,bScore = findBombWord(serverLetter, config.bombTier)
        if bWord then
            selectedWord=bWord; isBomb=true; bombTierUsed=bTier; bombScore=bScore
            updateBombUI(bWord,bTier,bScore)
        end
    end

    if not selectedWord then
        local words = getSmartWords(serverLetter)
        if #words==0 then
            if #config.filterEnding>0 then
                local old=config.filterEnding; config.filterEnding={}
                words=getSmartWords(serverLetter); config.filterEnding=old
            end
            if #words==0 then autoRunning=false; return end
        end
        if config.aggression>=100 then
            selectedWord=words[1]
        else
            local topN=math.max(1, math.floor(#words*(1-config.aggression/100)))
            if topN>#words then topN=#words end
            selectedWord=words[math.random(1,topN)]
        end
    end

    local success = humanTypeWord(selectedWord, serverLetter)
    if not success then autoRunning=false; return end

    SubmitWord:FireServer(selectedWord)
    addUsedWord(selectedWord)

    if isBomb then
        stats.bombsFired=(stats.bombsFired or 0)+1
        local icon = bombTierUsed=="mega" and "💣💣💣 MEGA BOM"
            or bombTierUsed=="kuat" and "💣💣 BOM KUAT" or "💣 BOM BIASA"
        Rayfield:Notify({ Title=icon.." DILUNCURKAN!", Content=string.upper(selectedWord).."  |  Skor: "..tostring(bombScore), Duration=4, Image=4483362458 })
    end

    task.wait(math.random(100,300)/1000)
    BillboardEnd:FireServer()
    autoRunning = false
end

task.spawn(function()
    while true do
        task.wait(0.3)
        if autoEnabled and matchActive and isMyTurn and serverLetter~="" and not autoRunning then
            task.spawn(startUltraAI)
        end
    end
end)

-- =========================================================
-- BUILD UI
-- =========================================================
local Window = Rayfield:CreateWindow({
    Name="⚔ NAKA  •  AUTO KATA", LoadingTitle="N A K A",
    LoadingSubtitle="Ultra Smart Word AI — v5.0",
    ConfigurationSaving={Enabled=true,FolderName="NAKA",FileName="AutoKata"},
    Discord={Enabled=false}, KeySystem=false
})
Rayfield:LoadConfiguration()
Rayfield:Notify({ Title="⚔  NAKA v5.0", Content="Key Verified! Mode: "..string.upper(config.playMode), Duration=5, Image=4483362458 })

-- ╔══════════════╗
-- ║  TAB KEY     ║
-- ╚══════════════╝
local KeyInfoTab = Window:CreateTab("🔑  KEY", 4483362458)
KeyInfoTab:CreateSection("◈  STATUS KEY")
KeyInfoTab:CreateLabel("✅  Key Terverifikasi  —  Device Terdaftar")
KeyInfoTab:CreateLabel("🔒  1 Key = 1 Device  |  Permanen")
KeyInfoTab:CreateLabel("◦  HWID  :  "..string.sub(DEVICE_HWID,1,30).."...")
local savedKeyForDisplay = loadSavedKey() or "—"
local displayKey = #savedKeyForDisplay>8 and (string.sub(savedKeyForDisplay,1,9).."****") or savedKeyForDisplay
KeyInfoTab:CreateLabel("◦  Key   :  "..displayKey)
KeyInfoTab:CreateSection("◈  KEAMANAN")
KeyInfoTab:CreateLabel("🔐  Key terikat hardware Roblox kamu")
KeyInfoTab:CreateLabel("🚫  Tidak bisa dipindah ke device lain")
KeyInfoTab:CreateLabel("♾️   Berlaku selamanya (permanent)")
KeyInfoTab:CreateSection("◈  AKSI")
KeyInfoTab:CreateButton({ Name="🔄  Verifikasi Ulang Key", Callback=function()
    local sk=loadSavedKey()
    if not sk then Rayfield:Notify({Title="❌  Tidak ada key",Content="Restart script",Duration=3,Image=4483362458}) return end
    task.spawn(function()
        local ok,msg=validateKeyOnline(sk)
        Rayfield:Notify({Title=ok and "✅  Key Valid" or "❌  Key Bermasalah",Content=msg,Duration=5,Image=4483362458})
    end)
end})
KeyInfoTab:CreateButton({ Name="🗑️  Hapus Key Tersimpan (Logout)", Callback=function()
    pcall(function()
        if isfile(SAVE_FILE) then delfile(SAVE_FILE)
            Rayfield:Notify({Title="🗑️  Key Dihapus",Content="Restart untuk input key baru.",Duration=5,Image=4483362458})
        end
    end)
end})

-- ╔══════════════╗
-- ║  TAB BATTLE  ║
-- ╚══════════════╝
local BattleTab = Window:CreateTab("⚔  BATTLE", 4483362458)
BattleTab:CreateSection("◈  STATUS LIVE")
local turnParagraph        = BattleTab:CreateLabel("●  Giliran      :  ⏳ Menunggu pertandingan...")
local startLetterParagraph = BattleTab:CreateLabel("●  Huruf Awalan :  —")
local opponentParagraph    = BattleTab:CreateLabel("●  Lawan        :  ⏳ Menunggu...")
BattleTab:CreateSection("◈  AUTO KATA")
BattleTab:CreateToggle({ Name="⚡  Aktifkan Auto Kata", CurrentValue=false, Callback=function(Value)
    autoEnabled=Value
    Rayfield:Notify({ Title=Value and "⚡  Auto Kata ON" or "⚡  Auto Kata OFF",
        Content=Value and "AI aktif! Mode: "..string.upper(config.playMode) or "AI dinonaktifkan",
        Duration=3, Image=4483362458 })
    if Value and matchActive and isMyTurn and serverLetter~="" then task.spawn(startUltraAI) end
end})
BattleTab:CreateSection("◈  FILTER AKHIRAN  ( TRAP )")
local filterLabel = BattleTab:CreateLabel("◦  Filter aktif  :  semua kata")
BattleTab:CreateDropdown({
    Name="🔡  Pilih Akhiran (multi-select)",
    Options={"a","i","u","e","o","n","r","s","t","k","h","l","m","p","g","j","f","v","z","x","q","w","y"},
    CurrentOption={}, MultipleOptions=true,
    Callback=function(Value)
        local selected={}
        if type(Value)=="table" then for _,v in ipairs(Value) do table.insert(selected,string.lower(tostring(v))) end end
        config.filterEnding=selected
        pcall(function() filterLabel:Set(#selected==0 and "◦  Filter aktif  :  semua kata" or "◦  Filter aktif  :  "..table.concat(selected,"  ·  ")) end)
    end
})
BattleTab:CreateButton({ Name="💀  TRAP MODE  —  x · q · z · f · v", Callback=function()
    config.filterEnding={"x","q","z","f","v"}
    pcall(function() filterLabel:Set("◦  Filter aktif  :  x  ·  q  ·  z  ·  f  ·  v   [ 💀 TRAP ]") end)
    Rayfield:Notify({Title="💀  TRAP MODE ON",Content="Lawan akan kesulitan!",Duration=4,Image=4483362458})
end})
BattleTab:CreateButton({ Name="↺  Reset Filter", Callback=function()
    config.filterEnding={}
    pcall(function() filterLabel:Set("◦  Filter aktif  :  semua kata") end)
end})
BattleTab:CreateSection("◈  STATISTIK")
local labelKataDikirim  = BattleTab:CreateLabel("◦  Kata Dikirim    :  0")
local labelKataPanjang  = BattleTab:CreateLabel("◦  Kata Terpanjang :  —")
local labelDurasi       = BattleTab:CreateLabel("◦  Durasi Sesi     :  0m 0s")
local labelBomDikirim   = BattleTab:CreateLabel("◦  Bom Diluncurkan :  0")
local labelKataTerpakai = BattleTab:CreateLabel("◦  Riwayat         :  (belum ada)")
local function updateStatsParagraph()
    local e=os.time()-(stats.sessionStart or os.time())
    pcall(function() labelKataDikirim:Set("◦  Kata Dikirim    :  "..tostring(stats.totalWords or 0)) end)
    pcall(function() labelKataPanjang:Set("◦  Kata Terpanjang :  "..(stats.longestWord~="" and stats.longestWord or "—")) end)
    pcall(function() labelDurasi:Set("◦  Durasi Sesi     :  "..math.floor(e/60).."m "..(e%60).."s") end)
    pcall(function() labelBomDikirim:Set("◦  Bom Diluncurkan :  "..tostring(stats.bombsFired or 0)) end)
end
local function updateKataLabel()
    local count=#usedWordsList
    if count==0 then pcall(function() labelKataTerpakai:Set("◦  Riwayat         :  (belum ada)") end) return end
    local display=""; local s=math.max(1,count-7)
    for i=s,count do display=display..usedWordsList[i]; if i<count then display=display.."  ·  " end end
    if count>8 then display="…  "..display end
    pcall(function() labelKataTerpakai:Set("◦  Riwayat  ["..count.."]  :  "..display) end)
end
local _origAdd=addUsedWord
addUsedWord=function(word) _origAdd(word); updateKataLabel() end
local _origReset=resetUsedWords
resetUsedWords=function() _origReset(); pcall(function() labelKataTerpakai:Set("◦  Riwayat         :  (belum ada)") end) end
BattleTab:CreateButton({ Name="↺  Reset Semua Statistik & Riwayat", Callback=function()
    stats.totalWords=0; stats.longestWord=""; stats.sessionStart=os.time(); stats.bombsFired=0
    usedWords={}; usedWordsList={}; humanProfile.wordCount=0
    updateStatsParagraph(); updateKataLabel()
    Rayfield:Notify({Title="↺  Reset",Content="Statistik & riwayat direset",Duration=3,Image=4483362458})
end})

-- ╔══════════════╗
-- ║  TAB BOM     ║
-- ╚══════════════╝
local BombTab = Window:CreateTab("💣  KATA BOM", 4483362458)
BombTab:CreateSection("◈  KONTROL BOM")
BombTab:CreateToggle({ Name="💣  Aktifkan Kata Bom", CurrentValue=false, Callback=function(Value)
    config.bombMode=Value
    Rayfield:Notify({Title=Value and "💣  Kata Bom ON" or "💣  Kata Bom OFF",
        Content=Value and "AI prioritaskan kata mematikan!" or "Mode normal",Duration=3,Image=4483362458})
end})
BombTab:CreateDropdown({ Name="🎯  Pilih Tier Bom", Options={"auto","biasa","kuat","mega"}, CurrentOption="auto",
    Callback=function(Value) config.bombTier=string.lower(tostring(Value)) end})
BombTab:CreateSection("◈  STATUS BOM REALTIME")
labelBombStatus=BombTab:CreateLabel("💣  Belum ada data  —  mulai pertandingan")
labelBombStock=BombTab:CreateLabel("◦  Stok Kata Bom  :  menghitung...")
task.delay(3, function() pcall(updateBombStock) end)
BombTab:CreateSection("◈  MANUAL TRIGGER")
BombTab:CreateButton({ Name="💣  Cari Kata Bom (Preview)", Callback=function()
    if serverLetter=="" then Rayfield:Notify({Title="⚠️  Belum ada huruf",Content="Masuk pertandingan dulu!",Duration=3,Image=4483362458}) return end
    local bWord,bTier,bScore=findBombWord(serverLetter,config.bombTier)
    updateBombUI(bWord,bTier,bScore)
    if bWord then Rayfield:Notify({Title="💣  Ditemukan!",Content=string.upper(bWord).."  Skor: "..bScore,Duration=5,Image=4483362458})
    else Rayfield:Notify({Title="😔  Tidak ada",Content="Tidak ada bom untuk huruf ini",Duration=3,Image=4483362458}) end
end})
BombTab:CreateButton({ Name="💣💣💣  PAKSA MEGA BOM SEKARANG", Callback=function()
    if not matchActive or not isMyTurn then Rayfield:Notify({Title="⚠️  Bukan giliran!",Content="Tunggu giliran dulu",Duration=3,Image=4483362458}) return end
    local ob,ot=config.bombMode,config.bombTier; config.bombMode=true; config.bombTier="mega"
    task.spawn(startUltraAI)
    task.delay(2, function() config.bombMode=ob; config.bombTier=ot end)
end})

-- ╔══════════════╗
-- ║  TAB SETTINGS║
-- ╚══════════════╝
local SettingsTab = Window:CreateTab("⚙  SETTINGS", 4483362458)

-- ★ MODE BERMAIN
SettingsTab:CreateSection("◈  MODE BERMAIN")
local modeLabel = SettingsTab:CreateLabel("🎮  Mode Aktif  :  SEIMBANG")
SettingsTab:CreateDropdown({
    Name="🎮  Pilih Mode Bermain",
    Options={"seimbang","natural","kompetitif"},
    CurrentOption="seimbang",
    Callback=function(Value)
        config.playMode=string.lower(tostring(Value))
        applyModeToProfile()

        -- Auto-set aggression & bomb per mode
        if config.playMode=="natural" then
            config.aggression=30; config.bombMode=false
            config.minLength=3;   config.maxLength=8
        elseif config.playMode=="kompetitif" then
            config.aggression=90; config.bombMode=true; config.bombTier="auto"
            config.minLength=5;   config.maxLength=20
        else
            config.aggression=50; config.bombMode=false
            config.minLength=3;   config.maxLength=12
        end

        local icons={seimbang="⚖️",natural="🌿",kompetitif="⚔️"}
        local descs={
            seimbang   ="Campuran natural + kompetitif",
            natural    ="Kata sehari-hari pendek, banyak typo, sangat natural",
            kompetitif ="Kata panjang + bom aktif otomatis, dominasi lawan!",
        }
        pcall(function() modeLabel:Set("🎮  Mode Aktif  :  "..(icons[config.playMode] or "").."  "..string.upper(config.playMode)) end)
        Rayfield:Notify({
            Title=(icons[config.playMode] or "")..string.upper(config.playMode).." MODE",
            Content=descs[config.playMode] or "",
            Duration=5, Image=4483362458
        })
    end
})
SettingsTab:CreateLabel("🌿  NATURAL      →  kata 3-8 huruf, typo banyak, lambat")
SettingsTab:CreateLabel("     Cocok  :  agar tidak terdeteksi bot")
SettingsTab:CreateLabel("⚖️   SEIMBANG    →  campuran, default")
SettingsTab:CreateLabel("     Cocok  :  penggunaan sehari-hari")
SettingsTab:CreateLabel("⚔️   KOMPETITIF  →  kata panjang, cepat, bom otomatis")
SettingsTab:CreateLabel("     Cocok  :  lawan kuat, ranked, turnamen")

SettingsTab:CreateSection("◈  PARAMETER AI")
SettingsTab:CreateSlider({ Name="⚡  Agresivitas ( 0=santai · 100=dominan )", Range={0,100}, Increment=5, CurrentValue=config.aggression, Callback=function(Value) config.aggression=Value end})
SettingsTab:CreateSlider({ Name="↓  Panjang Kata Minimum", Range={2,6}, Increment=1, CurrentValue=config.minLength, Callback=function(Value) config.minLength=Value end})
SettingsTab:CreateSlider({ Name="↑  Panjang Kata Maksimum", Range={5,20}, Increment=1, CurrentValue=config.maxLength, Callback=function(Value) config.maxLength=Value end})

SettingsTab:CreateSection("◈  HUMAN TYPING SIMULATOR")
SettingsTab:CreateLabel("🎭  Profil otomatis menyesuaikan mode aktif")
local lblSpd  = SettingsTab:CreateLabel(string.format("◦  Kecepatan Base   :  %d ms/karakter", humanProfile.baseSpeed))
local lblTypo = SettingsTab:CreateLabel(string.format("◦  Chance Typo      :  %.0f%%", humanProfile.mistakeChance*100))
local lblHes  = SettingsTab:CreateLabel(string.format("◦  Chance Ragu-ragu :  %.0f%%", humanProfile.hesitateChance*100))
SettingsTab:CreateButton({ Name="🔄  Generate Profil Baru", Callback=function()
    applyModeToProfile()
    pcall(function() lblSpd:Set(string.format("◦  Kecepatan Base   :  %d ms/karakter", humanProfile.baseSpeed)) end)
    pcall(function() lblTypo:Set(string.format("◦  Chance Typo      :  %.0f%%", humanProfile.mistakeChance*100)) end)
    pcall(function() lblHes:Set(string.format("◦  Chance Ragu-ragu :  %.0f%%", humanProfile.hesitateChance*100)) end)
    Rayfield:Notify({Title="🎭  Profil Baru!",Content=string.format("Spd:%dms Typo:%.0f%%",humanProfile.baseSpeed,humanProfile.mistakeChance*100),Duration=4,Image=4483362458})
end})

SettingsTab:CreateSection("◈  PANDUAN KEAMANAN")
SettingsTab:CreateLabel("🟢  AMAN        →  Mode Natural ON")
SettingsTab:CreateLabel("🟡  SEDANG      →  Mode Seimbang")
SettingsTab:CreateLabel("🔴  BERISIKO    →  Mode Kompetitif terus-menerus")

-- ╔══════════════╗
-- ║  TAB INFO    ║
-- ╚══════════════╝
local InfoTab = Window:CreateTab("📋  INFO", 4483362458)
InfoTab:CreateSection("◈  TENTANG SCRIPT")
InfoTab:CreateLabel("⚔   NAKA AUTO KATA  —  v5.0")
InfoTab:CreateLabel("◦   Pembuat  :  NAKA  |  Discord: qin")
InfoTab:CreateLabel("◦   Kamus    :  80.000+ kata Indonesia")
InfoTab:CreateSection("◈  MODE SYSTEM")
InfoTab:CreateLabel("🌿  NATURAL     →  manusiawi, anti-ban maksimal")
InfoTab:CreateLabel("⚖️   SEIMBANG   →  default, stabil")
InfoTab:CreateLabel("⚔️   KOMPETITIF →  dominan, bom otomatis")
InfoTab:CreateSection("◈  CARA PAKAI")
InfoTab:CreateLabel("1️⃣   Masukkan key aktivasi")
InfoTab:CreateLabel("2️⃣   Pilih mode di tab SETTINGS")
InfoTab:CreateLabel("3️⃣   Aktifkan Auto Kata di tab BATTLE")
InfoTab:CreateLabel("4️⃣   Masuk pertandingan — AI bekerja sendiri")
InfoTab:CreateSection("◈  TIPS")
InfoTab:CreateLabel("🌿  Gunakan Natural saat ada moderator")
InfoTab:CreateLabel("⚔️   Ganti Kompetitif saat lawan kuat")
InfoTab:CreateLabel("💣   Tier MEGA untuk lawan yang susah dikalahkan")
InfoTab:CreateLabel("🔄   Generate profil baru tiap sesi baru")

-- =========================================================
-- STATS LOOP
-- =========================================================
task.spawn(function()
    while true do
        task.wait(10)
        if matchActive then pcall(updateStatsParagraph) end
    end
end)

-- =========================================================
-- REMOTE HANDLERS
-- =========================================================
local function onMatchUI(cmd, value)
    if cmd=="ShowMatchUI" then
        matchActive=true; isMyTurn=false; resetUsedWords(); humanProfile.wordCount=0
        safeSet(turnParagraph,"🎮 Giliran: ⏳ Menunggu giliran...")
        safeSet(opponentParagraph,"👤 Lawan: 👀 Pertandingan dimulai!")
        updateStatsParagraph()
    elseif cmd=="HideMatchUI" then
        matchActive=false; isMyTurn=false; serverLetter=""; resetUsedWords()
        safeSet(turnParagraph,"🎮 Giliran: ❌ Pertandingan selesai")
        safeSet(opponentParagraph,"👤 Lawan: ⏳ Menunggu...")
        safeSet(startLetterParagraph,"🔤 Huruf Awal: —")
        updateStatsParagraph()
    elseif cmd=="StartTurn" then
        isMyTurn=true; safeSet(turnParagraph,"🎮 Giliran: ✅ GILIRAN KAMU!")
        updateStatsParagraph()
        if autoEnabled and serverLetter~="" then task.spawn(startUltraAI) end
    elseif cmd=="EndTurn" then
        isMyTurn=false; safeSet(turnParagraph,"🎮 Giliran: ⏳ Giliran lawan...")
        updateStatsParagraph()
    elseif cmd=="UpdateServerLetter" then
        serverLetter=tostring(value or "")
        safeSet(startLetterParagraph,"🔤 Huruf Awal: "..(serverLetter~="" and string.upper(serverLetter) or "—"))
        if config.bombMode or config.playMode=="kompetitif" then
            task.spawn(function()
                local bWord,bTier,bScore=findBombWord(serverLetter,config.bombTier)
                updateBombUI(bWord,bTier,bScore)
            end)
        end
        if autoEnabled and matchActive and isMyTurn then task.spawn(startUltraAI) end
    end
end

MatchUI.OnClientEvent:Connect(onMatchUI)
BillboardUpdate.OnClientEvent:Connect(function(word)
    if matchActive and not isMyTurn then
        local w=tostring(word or "")
        safeSet(opponentParagraph,"👤 Lawan: ✍ Mengetik: "..(w~="" and w or "..."))
    end
end)
UsedWordWarn.OnClientEvent:Connect(function(word)
    if word then
        addUsedWord(word); updateStatsParagraph()
        if autoEnabled and matchActive and isMyTurn then
            task.wait(math.random(200,400)/1000); task.spawn(startUltraAI)
        end
    end
end)

print("NAKA AUTO KATA v5.0 — LOADED  |  Mode: "..string.upper(config.playMode))
