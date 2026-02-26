-- =========================================================
-- ULTRA SMART AUTO KATA v6.0 — NAKA
-- Full Custom ScreenGui — Cyber Dark Military Theme
-- =========================================================

if game:IsLoaded() == false then
    game.Loaded:Wait()
end

-- =========================
-- SERVICES
-- =========================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local LocalPlayer       = Players.LocalPlayer
local PlayerGui         = LocalPlayer:WaitForChild("PlayerGui")

-- =========================
-- LOAD WORDLIST
-- =========================
local kataModule = {}

local function downloadWordlist()
    local ok, response = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/danzzy1we/roblox-script-dump/refs/heads/main/WordListDump/Dump_IndonesianWords.lua")
    end)
    if not ok or not response then return false end
    local content = string.match(response, "return%s*(.+)")
    if not content then return false end
    content = string.gsub(content, "^%s*{", "")
    content = string.gsub(content, "}%s*$", "")
    for word in string.gmatch(content, '"([^"]+)"') do
        local w = string.lower(word)
        if #w > 1 then table.insert(kataModule, w) end
    end
    return true
end

local wordOk = downloadWordlist()
if not wordOk or #kataModule == 0 then warn("Wordlist gagal dimuat!") return end
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
local matchActive   = false
local isMyTurn      = false
local serverLetter  = ""
local usedWords     = {}
local usedWordsList = {}
local autoEnabled   = false
local autoRunning   = false

local stats = {
    totalWords   = 0,
    longestWord  = "",
    sessionStart = os.time(),
    bombsFired   = 0,
}

local config = {
    minDelay     = 500,
    maxDelay     = 750,
    aggression   = 20,
    minLength    = 3,
    maxLength    = 12,
    filterEnding = {},
    preferRare   = false,
    bombMode     = false,
    bombTier     = "auto",
}

-- =========================
-- HUMAN PROFILE
-- =========================
local humanProfile = {
    baseSpeed      = math.random(350, 550),
    mistakeChance  = math.random(6, 13) / 100,
    hesitateChance = math.random(8, 18) / 100,
    isBurstyTyper  = math.random(1, 2) == 1,
    fatigueRate    = math.random(1, 4),
    doubleTypoRate = math.random(2, 6) / 100,
    wordCount      = 0,
}

-- =========================
-- KEYBOARD NEIGHBORS
-- =========================
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
    if nb and #nb > 0 then return nb[math.random(1,#nb)] end
    return string.sub("abcdefghijklmnopqrstuvwxyz", math.random(1,26), math.random(1,26))
end

local function waitMs(ms)
    if ms < 8 then ms = 8 end
    task.wait(ms / 1000)
end

local function charDelay(charIndex, wordLength)
    local base = humanProfile.baseSpeed + (humanProfile.wordCount * humanProfile.fatigueRate)
    if humanProfile.isBurstyTyper then
        local p = charIndex / wordLength
        if p < 0.35 then base = base * 0.85
        elseif p > 0.75 then base = base * 1.4 end
    end
    if charIndex == 1 then base = base + math.random(1000, 3000) end
    base = base * (1 + math.random(-15,15)/100)
    if math.random(1,10) == 1 then base = base + math.random(200,600) end
    if base < 150 then base = 150 end
    return math.floor(base)
end

local function humanTypeWord(selectedWord, serverPrefix)
    humanProfile.wordCount = humanProfile.wordCount + 1
    local currentDisplay = serverPrefix
    local remain = string.sub(selectedWord, #serverPrefix + 1)
    local chars = {}
    for i = 1, #remain do table.insert(chars, string.sub(remain,i,i)) end
    local i = 1
    while i <= #chars do
        if not matchActive or not isMyTurn then return false end
        local correctChar = chars[i]
        local rolled = math.random()
        if math.random() < humanProfile.hesitateChance then
            waitMs(math.random(400, 900))
            if math.random(1,4) == 1 and #currentDisplay > #serverPrefix then
                currentDisplay = string.sub(currentDisplay, 1, #currentDisplay-1)
                TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay)
                waitMs(math.random(100,300))
                currentDisplay = currentDisplay .. string.sub(selectedWord, #currentDisplay+1, #currentDisplay+1)
                TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay)
                waitMs(charDelay(i, #chars)); i = i+1; continue
            end
        end
        if rolled < humanProfile.doubleTypoRate and i <= #chars-1 then
            local w1 = getNearbyChar(correctChar)
            local w2 = getNearbyChar(chars[i+1] or correctChar)
            currentDisplay = currentDisplay..w1; TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(charDelay(i,#chars)*0.6)
            currentDisplay = currentDisplay..w2; TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(math.random(80,200))
            currentDisplay = string.sub(currentDisplay,1,#currentDisplay-1); TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(math.random(60,150))
            currentDisplay = string.sub(currentDisplay,1,#currentDisplay-1); TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(math.random(80,220))
            currentDisplay = currentDisplay..correctChar; TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(charDelay(i,#chars)); i=i+1
        elseif rolled < (humanProfile.doubleTypoRate + humanProfile.mistakeChance) then
            local wrongChar = getNearbyChar(correctChar)
            currentDisplay = currentDisplay..wrongChar; TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(math.random(50,300))
            if math.random(1,5) <= 2 and i < #chars then
                currentDisplay = currentDisplay..(chars[i+1] or correctChar); TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(math.random(60,180))
                currentDisplay = string.sub(currentDisplay,1,#currentDisplay-1); TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(math.random(50,130))
            end
            currentDisplay = string.sub(currentDisplay,1,#currentDisplay-1); TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(math.random(80,250))
            currentDisplay = currentDisplay..correctChar; TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(charDelay(i,#chars)); i=i+1
        else
            currentDisplay = currentDisplay..correctChar; TypeSound:FireServer(); BillboardUpdate:FireServer(currentDisplay); waitMs(charDelay(i,#chars)); i=i+1
        end
    end
    waitMs(math.random(400,1000))
    return true
end

-- =========================
-- KATA BOM SYSTEM
-- =========================
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
    local lc = string.sub(word,-1)
    local count = letterCountCache[lc] or 9999
    local score = 0
    if count < 50 then score=score+100 elseif count < 150 then score=score+60 elseif count < 400 then score=score+30 elseif count < 800 then score=score+10 end
    local len = #word
    if len >= 12 then score=score+30 elseif len >= 9 then score=score+15 elseif len >= 7 then score=score+5 end
    return score
end

local function getBombTier(score)
    if score >= 120 then return "mega" elseif score >= 60 then return "kuat" elseif score >= 20 then return "biasa" end
    return nil
end

local function findBombWord(prefix, tierTarget)
    local candidates = {}
    local lp = string.lower(prefix)
    local allowed = {}
    if tierTarget == "mega" then for _,e in ipairs(BOM_TIERS.mega) do allowed[e]=true end
    elseif tierTarget == "kuat" then for _,e in ipairs(BOM_TIERS.kuat) do allowed[e]=true end; for _,e in ipairs(BOM_TIERS.mega) do allowed[e]=true end
    elseif tierTarget == "biasa" then for _,e in ipairs(BOM_TIERS.biasa) do allowed[e]=true end; for _,e in ipairs(BOM_TIERS.kuat) do allowed[e]=true end; for _,e in ipairs(BOM_TIERS.mega) do allowed[e]=true end
    else for _,e in ipairs(BOM_TIERS.biasa) do allowed[e]=true end; for _,e in ipairs(BOM_TIERS.kuat) do allowed[e]=true end; for _,e in ipairs(BOM_TIERS.mega) do allowed[e]=true end
    end
    for _, word in ipairs(kataModule) do
        if string.sub(word,1,#lp)==lp and not usedWords[word] and #word>=config.minLength and #word<=config.maxLength then
            local lc = string.sub(word,-1)
            if allowed[lc] then
                local bs = getBombScore(word)
                if bs > 0 then table.insert(candidates, {word=word, score=bs}) end
            end
        end
    end
    table.sort(candidates, function(a,b) return a.score > b.score end)
    if #candidates > 0 then return candidates[1].word, getBombTier(candidates[1].score), candidates[1].score end
    return nil, nil, 0
end

-- =========================
-- SCORING + WORD MANAGEMENT
-- =========================
local HARD_ENDINGS = {["x"]=10,["q"]=10,["f"]=8,["v"]=8,["z"]=9,["y"]=6,["w"]=5,["j"]=7,["k"]=4,["h"]=3}

local function scoreWord(word)
    local s = #word * 2
    if #word >= 9 then s=s+15 end
    if #word >= 12 then s=s+20 end
    local lc = string.sub(word,-1)
    if HARD_ENDINGS[lc] then s=s+HARD_ENDINGS[lc] end
    return s
end

local function addUsedWord(word)
    if not word then return end
    local w = string.lower(tostring(word))
    if not usedWords[w] then
        usedWords[w]=true; table.insert(usedWordsList,w)
        stats.totalWords=(stats.totalWords or 0)+1
        if #w > #(stats.longestWord or "") then stats.longestWord=w end
    end
end

local function resetUsedWords()
    usedWords={}; usedWordsList={}
end

local function getSmartWords(prefix)
    local results,lp,filterSet,hasFilter={},string.lower(prefix),{},false
    for _,v in ipairs(config.filterEnding) do
        local lv=string.lower(tostring(v))
        if lv~="semua" and lv~="" then filterSet[lv]=true; hasFilter=true end
    end
    for _,word in ipairs(kataModule) do
        if string.sub(word,1,#lp)==lp and not usedWords[word] and #word>=config.minLength and #word<=config.maxLength then
            local pass=true
            if hasFilter and not filterSet[string.sub(word,-1)] then pass=false end
            if pass then table.insert(results,word) end
        end
    end
    table.sort(results,function(a,b) return scoreWord(a)>scoreWord(b) end)
    return results
end

-- =========================================================
-- ██╗   ██╗██╗
-- ██║   ██║██║
-- ██║   ██║██║
-- ██║   ██║██║
-- ╚██████╔╝██║
-- CUSTOM SCREENGUI
-- =========================================================

-- =========================
-- COLOR PALETTE
-- =========================
local C = {
    bg       = Color3.fromRGB(8,  11, 15),
    bg2      = Color3.fromRGB(13, 17, 23),
    bg3      = Color3.fromRGB(17, 24, 32),
    panel    = Color3.fromRGB(10, 15, 20),
    border   = Color3.fromRGB(26, 37, 53),
    border2  = Color3.fromRGB(36, 48, 64),
    red      = Color3.fromRGB(255, 41,  68),
    red2     = Color3.fromRGB(255, 96, 112),
    gold     = Color3.fromRGB(255,208, 70),
    gold2    = Color3.fromRGB(255,184,  0),
    cyan     = Color3.fromRGB(0,  229, 255),
    cyan2    = Color3.fromRGB(0,  184, 212),
    green    = Color3.fromRGB(0,  255, 136),
    green2   = Color3.fromRGB(0,  204, 102),
    text     = Color3.fromRGB(200,216,232),
    text2    = Color3.fromRGB(122,154,184),
    text3    = Color3.fromRGB(58,  80,104),
    white    = Color3.fromRGB(255,255,255),
    black    = Color3.fromRGB(0,  0,   0),
    trans    = Color3.fromRGB(0,  0,   0),
}

local FONT_MONO  = Enum.Font.Code
local FONT_BOLD  = Enum.Font.GothamBold
local FONT_MED   = Enum.Font.Gotham
local FONT_LIGHT = Enum.Font.GothamLight

-- =========================
-- UI HELPERS
-- =========================
local function New(class, props, children)
    local inst = Instance.new(class)
    for k,v in pairs(props or {}) do inst[k]=v end
    for _,child in ipairs(children or {}) do child.Parent=inst end
    return inst
end

local function Tween(inst, props, t, style, dir)
    local info = TweenInfo.new(t or 0.25, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
    TweenService:Create(inst, info, props):Play()
end

local function Corner(r, parent)
    local c = Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 4); c.Parent=parent; return c
end

local function Stroke(thickness, color, parent)
    local s = Instance.new("UIStroke"); s.Thickness=thickness or 1; s.Color=color or C.border; s.Parent=parent; return s
end

local function Padding(all, parent)
    local p = Instance.new("UIPadding")
    if type(all)=="number" then
        p.PaddingTop=UDim.new(0,all); p.PaddingBottom=UDim.new(0,all)
        p.PaddingLeft=UDim.new(0,all); p.PaddingRight=UDim.new(0,all)
    else
        p.PaddingTop=UDim.new(0,all.top or 0); p.PaddingBottom=UDim.new(0,all.bottom or 0)
        p.PaddingLeft=UDim.new(0,all.left or 0); p.PaddingRight=UDim.new(0,all.right or 0)
    end
    p.Parent=parent; return p
end

local function ListLayout(dir, pad, parent)
    local l=Instance.new("UIListLayout")
    l.FillDirection=dir or Enum.FillDirection.Vertical
    l.SortOrder=Enum.SortOrder.LayoutOrder
    l.Padding=UDim.new(0,pad or 0)
    l.Parent=parent; return l
end

local function GridLayout(cellSize, cellPad, parent)
    local g=Instance.new("UIGridLayout")
    g.CellSize=cellSize or UDim2.new(0.5,-4,0,60)
    g.CellPaddingWall=UDim2.new(0,4,0,4)
    g.SortOrder=Enum.SortOrder.LayoutOrder
    g.Parent=parent; return g
end

-- Gradient background frame
local function GradBG(c1, c2, rot, parent)
    local g=Instance.new("UIGradient")
    g.Color=ColorSequence.new(c1,c2)
    g.Rotation=rot or 135
    g.Parent=parent
    return g
end

-- Make a label
local function Label(text, size, color, font, parent, props)
    local l=Instance.new("TextLabel")
    l.Text=text; l.TextSize=size or 13; l.TextColor3=color or C.text
    l.Font=font or FONT_MED; l.BackgroundTransparency=1
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.Size=UDim2.new(1,0,0,size and size+6 or 20)
    l.TextScaled=false
    for k,v in pairs(props or {}) do l[k]=v end
    if parent then l.Parent=parent end
    return l
end

-- Make a button
local function Button(text, bg, textColor, parent, callback)
    local btn=New("TextButton",{
        Text=text, TextSize=12, Font=FONT_BOLD,
        TextColor3=textColor or C.white,
        BackgroundColor3=bg or C.bg3,
        Size=UDim2.new(1,0,0,34),
        AutoButtonColor=false,
    })
    Corner(4, btn); Stroke(1, C.border2, btn)
    if parent then btn.Parent=parent end
    btn.MouseEnter:Connect(function()
        Tween(btn, {BackgroundColor3=Color3.fromRGB(
            math.min(255, bg and bg.R*255+20 or 40),
            math.min(255, bg and bg.G*255+20 or 40),
            math.min(255, bg and bg.B*255+20 or 40)
        )})
    end)
    btn.MouseLeave:Connect(function() Tween(btn, {BackgroundColor3=bg or C.bg3}) end)
    if callback then btn.MouseButton1Click:Connect(callback) end
    return btn
end

-- Section header
local function SectionHeader(text, icon, parent)
    local f=New("Frame",{BackgroundColor3=C.bg2,Size=UDim2.new(1,0,0,28)})
    Corner(0,f); Stroke(1,C.border,f)
    New("UIGradient",{Color=ColorSequence.new{
        ColorSequenceKeypoint.new(0,Color3.fromRGB(255,41,68)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(20,30,40))
    },Rotation=0,Parent=f})
    local lb=New("TextLabel",{
        Text=(icon or "◈").."  "..text,
        TextSize=10, Font=FONT_BOLD,
        TextColor3=C.red, BackgroundTransparency=1,
        Size=UDim2.new(1,-16,1,0),
        Position=UDim2.new(0,12,0,0),
        TextXAlignment=Enum.TextXAlignment.Left,
        LetterSpacing=3,
    })
    lb.Parent=f
    if parent then f.Parent=parent end
    return f
end

-- Status pill
local function StatusPill(labelText, value, accentColor, parent)
    local f=New("Frame",{BackgroundColor3=C.bg3,Size=UDim2.new(1,0,0,38)})
    Corner(4,f); Stroke(1,C.border,f)
    -- left accent bar
    New("Frame",{
        BackgroundColor3=accentColor or C.cyan,
        Size=UDim2.new(0,2,1,0),
        Position=UDim2.new(0,0,0,0),
        BorderSizePixel=0,
    }).Parent=f
    local lbl=New("TextLabel",{
        Text=labelText, TextSize=10, Font=FONT_BOLD,
        TextColor3=C.text3, BackgroundTransparency=1,
        Size=UDim2.new(0.5,0,0,14),
        Position=UDim2.new(0,12,0,4),
        TextXAlignment=Enum.TextXAlignment.Left,
        LetterSpacing=2,
    }); lbl.Parent=f
    local val=New("TextLabel",{
        Text=value, TextSize=14, Font=FONT_BOLD,
        TextColor3=accentColor or C.cyan,
        BackgroundTransparency=1,
        Size=UDim2.new(1,-12,0,16),
        Position=UDim2.new(0,12,0,18),
        TextXAlignment=Enum.TextXAlignment.Left,
    }); val.Parent=f
    if parent then f.Parent=parent end
    return f, val
end

-- Stat box
local function StatBox(label, value, color, parent)
    local f=New("Frame",{BackgroundColor3=C.bg3,Size=UDim2.new(0.5,-4,0,62)})
    Corner(4,f); Stroke(1,C.border,f)
    local lb=New("TextLabel",{
        Text=label, TextSize=9, Font=FONT_BOLD,
        TextColor3=C.text3, BackgroundTransparency=1,
        Size=UDim2.new(1,-8,0,14),
        Position=UDim2.new(0,8,0,8),
        TextXAlignment=Enum.TextXAlignment.Left,
        LetterSpacing=2,
    }); lb.Parent=f
    local vl=New("TextLabel",{
        Text=value, TextSize=20, Font=FONT_BOLD,
        TextColor3=color or C.gold,
        BackgroundTransparency=1,
        Size=UDim2.new(1,-8,0,26),
        Position=UDim2.new(0,8,0,26),
        TextXAlignment=Enum.TextXAlignment.Left,
    }); vl.Parent=f
    if parent then f.Parent=parent end
    return f, vl
end

-- Toggle component
local function Toggle(labelText, default, onChange, parent)
    local enabled=default or false
    local f=New("Frame",{BackgroundColor3=C.bg3,Size=UDim2.new(1,0,0,42)})
    Corner(4,f); Stroke(1,C.border,f)
    Padding({left=12,right=12,top=0,bottom=0},f)
    local lb=New("TextLabel",{
        Text=labelText, TextSize=13, Font=FONT_MED,
        TextColor3=C.text, BackgroundTransparency=1,
        Size=UDim2.new(1,-60,1,0),
        TextXAlignment=Enum.TextXAlignment.Left,
    }); lb.Parent=f
    -- track
    local track=New("Frame",{
        BackgroundColor3=enabled and C.green or C.border2,
        Size=UDim2.new(0,44,0,22),
        Position=UDim2.new(1,-44,0.5,-11),
        ClipsDescendants=true,
    }); Corner(11,track); track.Parent=f
    -- knob
    local knob=New("Frame",{
        BackgroundColor3=enabled and C.white or C.text3,
        Size=UDim2.new(0,16,0,16),
        Position=UDim2.new(0,enabled and 24 or 3,0.5,-8),
    }); Corner(8,knob); knob.Parent=track

    local btn=New("TextButton",{
        Text="", BackgroundTransparency=1,
        Size=UDim2.new(1,0,1,0),
    }); btn.Parent=f

    btn.MouseButton1Click:Connect(function()
        enabled=not enabled
        Tween(track,{BackgroundColor3=enabled and C.green or C.border2})
        Tween(knob,{Position=UDim2.new(0,enabled and 24 or 3,0.5,-8),BackgroundColor3=enabled and C.white or C.text3})
        if onChange then onChange(enabled) end
    end)
    if parent then f.Parent=parent end
    return f, function() return enabled end, function(v)
        enabled=v
        Tween(track,{BackgroundColor3=enabled and C.green or C.border2})
        Tween(knob,{Position=UDim2.new(0,enabled and 24 or 3,0.5,-8),BackgroundColor3=enabled and C.white or C.text3})
    end
end

-- Slider component
local function Slider(labelText, min, max, default, onChange, parent)
    local val=default or min
    local f=New("Frame",{BackgroundColor3=C.bg3,Size=UDim2.new(1,0,0,56)})
    Corner(4,f); Stroke(1,C.border,f)
    Padding({left=12,right=12,top=6,bottom=6},f)
    local header=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,18)}); header.Parent=f
    New("TextLabel",{Text=labelText,TextSize=11,Font=FONT_MED,TextColor3=C.text3,BackgroundTransparency=1,Size=UDim2.new(0.8,0,1,0),TextXAlignment=Enum.TextXAlignment.Left,LetterSpacing=1}).Parent=header
    local valLb=New("TextLabel",{Text=tostring(val),TextSize=13,Font=FONT_BOLD,TextColor3=C.gold,BackgroundTransparency=1,Size=UDim2.new(0.2,0,1,0),Position=UDim2.new(0.8,0,0,0),TextXAlignment=Enum.TextXAlignment.Right}); valLb.Parent=header
    -- track
    local track=New("Frame",{BackgroundColor3=C.border,Size=UDim2.new(1,0,0,4),Position=UDim2.new(0,0,0,30)}); Corner(2,track); track.Parent=f
    local fill=New("Frame",{BackgroundColor3=C.gold,Size=UDim2.new((val-min)/(max-min),0,1,0)}); Corner(2,fill)
    GradBG(C.red,C.gold,0,fill)
    fill.Parent=track
    local knob=New("Frame",{BackgroundColor3=C.white,Size=UDim2.new(0,12,0,12),Position=UDim2.new((val-min)/(max-min),0-6,0.5,-6)});Corner(6,knob); knob.Parent=track
    local dragging=false
    knob.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
            local abs=track.AbsolutePosition.X; local width=track.AbsoluteSize.X
            local pct=math.clamp((i.Position.X-abs)/width,0,1)
            val=math.floor(min+(max-min)*pct)
            valLb.Text=tostring(val)
            Tween(fill,{Size=UDim2.new(pct,0,1,0)},0.05)
            Tween(knob,{Position=UDim2.new(pct,-6,0.5,-6)},0.05)
            if onChange then onChange(val) end
        end
    end)
    if parent then f.Parent=parent end
    return f
end

-- Bomb tier button
local function BombTierBtn(icon, name, desc, endings, color, parent)
    local f=New("TextButton",{
        Text="", BackgroundColor3=C.bg3,
        Size=UDim2.new(1,0,0,60),
        AutoButtonColor=false,
    }); Corner(4,f); Stroke(1,C.border,f)
    New("TextLabel",{Text=icon,TextSize=22,Font=FONT_BOLD,TextColor3=C.white,BackgroundTransparency=1,Size=UDim2.new(0,40,1,0),Position=UDim2.new(0,8,0,0)}).Parent=f
    New("TextLabel",{Text=name,TextSize=14,Font=FONT_BOLD,TextColor3=color,BackgroundTransparency=1,Size=UDim2.new(1,-100,0,20),Position=UDim2.new(0,52,0,10)}).Parent=f
    New("TextLabel",{Text=desc,TextSize=10,Font=FONT_LIGHT,TextColor3=C.text3,BackgroundTransparency=1,Size=UDim2.new(1,-100,0,14),Position=UDim2.new(0,52,0,30)}).Parent=f
    local eb=New("Frame",{BackgroundColor3=C.bg2,Size=UDim2.new(0,60,0,22),Position=UDim2.new(1,-68,0.5,-11)}); Corner(3,eb); Stroke(1,color,eb)
    New("TextLabel",{Text=endings,TextSize=9,Font=FONT_BOLD,TextColor3=color,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),TextXAlignment=Enum.TextXAlignment.Center}).Parent=eb
    eb.Parent=f
    f.MouseEnter:Connect(function() Tween(f,{BackgroundColor3=C.bg2}); Tween(f:FindFirstChildOfClass("UIStroke"),{Color=color}) end)
    f.MouseLeave:Connect(function() Tween(f,{BackgroundColor3=C.bg3}); Tween(f:FindFirstChildOfClass("UIStroke"),{Color=C.border}) end)
    if parent then f.Parent=parent end
    return f
end

-- Toast notification
local toastContainer
local function showToast(title, body, color)
    if not toastContainer then return end
    local accent = color or C.green
    local toast=New("Frame",{
        BackgroundColor3=C.panel,
        Size=UDim2.new(0,260,0,56),
        Position=UDim2.new(1,10,0,0),
        ClipsDescendants=true,
    }); Corner(4,toast); Stroke(1,accent,toast)
    New("Frame",{BackgroundColor3=accent,Size=UDim2.new(0,2,1,0)}).Parent=toast
    New("TextLabel",{Text=title,TextSize=13,Font=FONT_BOLD,TextColor3=accent,BackgroundTransparency=1,Size=UDim2.new(1,-20,0,18),Position=UDim2.new(0,12,0,8),TextXAlignment=Enum.TextXAlignment.Left}).Parent=toast
    New("TextLabel",{Text=body,TextSize=11,Font=FONT_LIGHT,TextColor3=C.text2,BackgroundTransparency=1,Size=UDim2.new(1,-20,0,16),Position=UDim2.new(0,12,0,28),TextXAlignment=Enum.TextXAlignment.Left}).Parent=toast
    toast.Parent=toastContainer
    Tween(toast,{Position=UDim2.new(1,-270,0,0)},0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
    task.delay(3.5,function()
        Tween(toast,{Position=UDim2.new(1,10,0,0)},0.3)
        task.delay(0.35,function() toast:Destroy() end)
    end)
    -- stack existing toasts
    local offset=0
    for _,child in ipairs(toastContainer:GetChildren()) do
        if child:IsA("Frame") and child~=toast then
            offset=offset+60
            Tween(child,{Position=UDim2.new(1,-270,0,offset)},0.2)
        end
    end
end

-- Scrollable content frame
local function ScrollFrame(size, parent)
    local sf=New("ScrollingFrame",{
        BackgroundTransparency=1,
        Size=size or UDim2.new(1,0,1,0),
        ScrollBarThickness=2,
        ScrollBarImageColor3=C.border2,
        CanvasSize=UDim2.new(0,0,0,0),
        AutomaticCanvasSize=Enum.AutomaticSize.Y,
        BorderSizePixel=0,
    })
    if parent then sf.Parent=parent end
    return sf
end

-- =========================
-- BUILD MAIN WINDOW
-- =========================
-- Remove old GUI if exists
if PlayerGui:FindFirstChild("NAKA_GUI") then
    PlayerGui:FindFirstChild("NAKA_GUI"):Destroy()
end

local ScreenGui=New("ScreenGui",{
    Name="NAKA_GUI",
    ResetOnSpawn=false,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
    Parent=PlayerGui,
})

-- Toast container (top right)
toastContainer=New("Frame",{
    BackgroundTransparency=1,
    Size=UDim2.new(0,270,1,0),
    Position=UDim2.new(1,-280,0,20),
    ClipsDescendants=false,
})
toastContainer.Parent=ScreenGui
ListLayout(Enum.FillDirection.Vertical,6,toastContainer)

-- Main window frame
local MainFrame=New("Frame",{
    Name="MainFrame",
    BackgroundColor3=C.bg,
    Size=UDim2.new(0,340,0,560),
    Position=UDim2.new(0,20,0.5,-280),
    ClipsDescendants=true,
})
Corner(8,MainFrame); Stroke(1,C.border,MainFrame)
MainFrame.Parent=ScreenGui

-- Subtle grid background via ImageLabel (simulated with frames)
New("Frame",{
    BackgroundColor3=C.black,
    BackgroundTransparency=0.95,
    Size=UDim2.new(1,0,1,0),
    ZIndex=0,
}).Parent=MainFrame

-- Top accent line
local topLine=New("Frame",{
    BackgroundColor3=C.red,
    Size=UDim2.new(1,0,0,2),
    Position=UDim2.new(0,0,0,0),
})
GradBG(C.red,C.gold,0,topLine)
topLine.Parent=MainFrame

-- ── HEADER ──────────────────────────────────
local Header=New("Frame",{
    BackgroundColor3=C.bg2,
    Size=UDim2.new(1,0,0,56),
    Position=UDim2.new(0,0,0,2),
})
Header.Parent=MainFrame

-- header gradient
New("UIGradient",{
    Color=ColorSequence.new{
        ColorSequenceKeypoint.new(0,Color3.fromRGB(30,10,15)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(10,15,20)),
    },
    Rotation=135,
    Parent=Header,
})

-- Title
New("TextLabel",{
    Text="NAKA",
    TextSize=28, Font=FONT_BOLD,
    TextColor3=C.white,
    BackgroundTransparency=1,
    Size=UDim2.new(0,100,0,32),
    Position=UDim2.new(0,16,0,6),
    TextXAlignment=Enum.TextXAlignment.Left,
}).Parent=Header

-- Red N in NAKA
New("TextLabel",{
    Text="N",
    TextSize=28, Font=FONT_BOLD,
    TextColor3=C.red,
    BackgroundTransparency=1,
    Size=UDim2.new(0,20,0,32),
    Position=UDim2.new(0,16,0,6),
    TextXAlignment=Enum.TextXAlignment.Left,
}).Parent=Header

New("TextLabel",{
    Text="AUTO KATA SYSTEM  ·  V6.0",
    TextSize=9, Font=FONT_BOLD,
    TextColor3=C.text3,
    BackgroundTransparency=1,
    Size=UDim2.new(1,-20,0,14),
    Position=UDim2.new(0,16,0,38),
    TextXAlignment=Enum.TextXAlignment.Left,
    LetterSpacing=3,
}).Parent=Header

-- Online badge
local badge=New("Frame",{
    BackgroundColor3=Color3.fromRGB(0,30,15),
    Size=UDim2.new(0,72,0,20),
    Position=UDim2.new(1,-84,0,10),
}); Corner(3,badge); Stroke(1,C.green,badge)
New("TextLabel",{Text="● ONLINE",TextSize=9,Font=FONT_BOLD,TextColor3=C.green,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),TextXAlignment=Enum.TextXAlignment.Center}).Parent=badge
badge.Parent=Header

-- Minimize/Close buttons
local closeBtn=New("TextButton",{
    Text="✕",TextSize=12,Font=FONT_BOLD,TextColor3=C.text2,
    BackgroundColor3=C.bg3,Size=UDim2.new(0,24,0,20),
    Position=UDim2.new(1,-84,0,32),AutoButtonColor=false,
}); Corner(3,closeBtn); closeBtn.Parent=Header
closeBtn.MouseButton1Click:Connect(function()
    Tween(MainFrame,{Position=UDim2.new(-0.5,0,0.5,-280)},0.4,Enum.EasingStyle.Back)
end)

-- Drag support
local dragging,dragStart,startPos=false,nil,nil
Header.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true; dragStart=i.Position
        startPos=MainFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
        local delta=i.Position-dragStart
        MainFrame.Position=UDim2.new(
            startPos.X.Scale,startPos.X.Offset+delta.X,
            startPos.Y.Scale,startPos.Y.Offset+delta.Y
        )
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
end)

-- ── TAB BAR ─────────────────────────────────
local TabBar=New("Frame",{
    BackgroundColor3=C.bg2,
    Size=UDim2.new(1,0,0,36),
    Position=UDim2.new(0,0,0,58),
}); Stroke(1,C.border,TabBar); TabBar.Parent=MainFrame
ListLayout(Enum.FillDirection.Horizontal,0,TabBar)
Padding(4,TabBar)

local tabButtons={}
local tabContents={}
local activeTab=nil

local function switchTab(name)
    for n,btn in pairs(tabButtons) do
        local isActive=(n==name)
        Tween(btn,{
            BackgroundColor3=isActive and Color3.fromRGB(40,10,15) or C.bg2,
            TextColor3=isActive and C.red or C.text3,
        })
    end
    for n,content in pairs(tabContents) do
        content.Visible=(n==name)
    end
    activeTab=name
end

local function addTab(name, icon)
    local btn=New("TextButton",{
        Text=icon.." "..name, TextSize=10, Font=FONT_BOLD,
        TextColor3=C.text3,
        BackgroundColor3=C.bg2,
        Size=UDim2.new(0.25,0,1,0),
        AutoButtonColor=false,
        LetterSpacing=1,
    })
    tabButtons[name]=btn; btn.Parent=TabBar
    btn.MouseButton1Click:Connect(function() switchTab(name) end)

    -- content area
    local content=New("Frame",{
        BackgroundTransparency=1,
        Size=UDim2.new(1,0,1,0),
        Visible=false,
    })
    tabContents[name]=content
    return content
end

-- ── CONTENT AREA ────────────────────────────
local ContentArea=New("Frame",{
    BackgroundTransparency=1,
    Size=UDim2.new(1,0,1,-96),
    Position=UDim2.new(0,0,0,96),
    ClipsDescendants=true,
})
ContentArea.Parent=MainFrame

-- ==============================================
-- TAB: BATTLE
-- ==============================================
local battleContent=addTab("BATTLE","⚔")
battleContent.Parent=ContentArea

local battleScroll=ScrollFrame(UDim2.new(1,0,1,0),battleContent)
local bList=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
ListLayout(Enum.FillDirection.Vertical,6,bList)
Padding({left=8,right=8,top=8,bottom=8},bList)
bList.Parent=battleScroll

-- Status section
local statusPanel=New("Frame",{BackgroundColor3=C.panel,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
Corner(6,statusPanel); Stroke(1,C.border,statusPanel)
SectionHeader("STATUS LIVE","●",statusPanel)
local statusList=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
ListLayout(Enum.FillDirection.Vertical,4,statusList)
Padding({left=8,right=8,top=8,bottom=8},statusList)
statusList.Parent=statusPanel
statusPanel.Parent=bList

local _,turnVal    = StatusPill("GILIRAN","⏳ Menunggu...",C.green,statusList)
local _,letterVal  = StatusPill("HURUF AKTIF","—",C.cyan,statusList)
local _,oppVal     = StatusPill("STATUS LAWAN","⏳ Menunggu...",C.gold,statusList)

-- Big letter display
local bigLetterPanel=New("Frame",{BackgroundColor3=C.panel,Size=UDim2.new(1,0,0,80)})
Corner(6,bigLetterPanel); Stroke(1,C.border,bigLetterPanel)
local bigLetterLb=New("TextLabel",{
    Text="?", TextSize=48, Font=FONT_BOLD,
    TextColor3=C.cyan, BackgroundTransparency=1,
    Size=UDim2.new(1,0,1,0),
    TextXAlignment=Enum.TextXAlignment.Center,
}); bigLetterLb.Parent=bigLetterPanel
New("TextLabel",{Text="HURUF AWALAN",TextSize=8,Font=FONT_BOLD,TextColor3=C.text3,BackgroundTransparency=1,Size=UDim2.new(1,0,0,12),Position=UDim2.new(0,0,1,-14),TextXAlignment=Enum.TextXAlignment.Center,LetterSpacing=3}).Parent=bigLetterPanel
bigLetterPanel.Parent=bList

-- Auto kata section
local autoPanel=New("Frame",{BackgroundColor3=C.panel,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
Corner(6,autoPanel); Stroke(1,C.border,autoPanel)
SectionHeader("AUTO KATA","⚡",autoPanel)
local autoList=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
ListLayout(Enum.FillDirection.Vertical,4,autoList)
Padding({left=8,right=8,top=8,bottom=8},autoList)
autoList.Parent=autoPanel
autoPanel.Parent=bList

local autoToggleFrame,getAutoEnabled,setAutoEnabled=Toggle("⚡  Aktifkan Auto Kata",false,function(v)
    autoEnabled=v
    showToast(v and "⚡ Auto Kata ON" or "⚡ Auto Kata OFF", v and "AI + Human Typing aktif!" or "AI dinonaktifkan", v and C.green or C.red)
    if v and matchActive and isMyTurn and serverLetter~="" then task.spawn(startUltraAI) end
end,autoList)

Toggle("🃏  Mode Kata Langka",false,function(v) config.preferRare=v end,autoList)
Toggle("💣  Aktifkan Kata Bom",false,function(v)
    config.bombMode=v
    showToast(v and "💣 Kata Bom ON" or "💣 Kata Bom OFF", v and "AI prioritaskan kata mematikan!" or "Mode normal", v and C.red or C.text3)
end,autoList)

-- Filter section
local filterPanel=New("Frame",{BackgroundColor3=C.panel,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
Corner(6,filterPanel); Stroke(1,C.border,filterPanel)
SectionHeader("FILTER AKHIRAN","🔡",filterPanel)
local filterList=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
ListLayout(Enum.FillDirection.Vertical,4,filterList)
Padding({left=8,right=8,top=8,bottom=8},filterList)
filterList.Parent=filterPanel
filterPanel.Parent=bList

local filterStatusLb=New("TextLabel",{
    Text="◦  Filter  :  semua kata", TextSize=11, Font=FONT_MONO,
    TextColor3=C.text2, BackgroundTransparency=1,
    Size=UDim2.new(1,0,0,18), TextXAlignment=Enum.TextXAlignment.Left,
}); filterStatusLb.Parent=filterList

local trapBtn=Button("💀  TRAP MODE — x · q · z · f · v",Color3.fromRGB(30,8,12),C.red,filterList,function()
    config.filterEnding={"x","q","z","f","v"}
    filterStatusLb.Text="💀  TRAP: x · q · z · f · v"
    filterStatusLb.TextColor3=C.red
    showToast("💀 TRAP MODE","Lawan akan kesulitan!",C.red)
end)
Stroke(1,C.red,trapBtn)

Button("↺  Reset Filter",C.bg3,C.text2,filterList,function()
    config.filterEnding={}
    filterStatusLb.Text="◦  Filter  :  semua kata"
    filterStatusLb.TextColor3=C.text2
end)

-- Stats section
local statsPanel=New("Frame",{BackgroundColor3=C.panel,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
Corner(6,statsPanel); Stroke(1,C.border,statsPanel)
SectionHeader("STATISTIK","📊",statsPanel)
local statsPad=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
Padding({left=8,right=8,top=8,bottom=8},statsPad)
statsPad.Parent=statsPanel
statsPanel.Parent=bList

local statsGrid=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,132)})
GridLayout(UDim2.new(0.5,-4,0,62),UDim2.new(0,4,0,4),statsGrid)
statsGrid.Parent=statsPad

local _,statTotal  = StatBox("KATA DIKIRIM","0",C.gold,statsGrid)
local _,statBomb   = StatBox("BOM FIRED","0",C.red,statsGrid)
local _,statLong   = StatBox("TERPANJANG","—",C.cyan,statsGrid)
local _,statDur    = StatBox("DURASI","0m 0s",C.text2,statsGrid)

-- Word history
local historyLb=New("TextLabel",{
    Text="Riwayat  :  (belum ada)", TextSize=10, Font=FONT_MONO,
    TextColor3=C.text3, BackgroundTransparency=1,
    Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextWrapped=true,
}); historyLb.Parent=statsPad

Button("↺  Reset Statistik",C.bg3,C.text3,statsPad,function()
    stats={totalWords=0,longestWord="",sessionStart=os.time(),bombsFired=0}
    usedWords={}; usedWordsList={}; humanProfile.wordCount=0
    statTotal.Text="0"; statBomb.Text="0"; statLong.Text="—"; statDur.Text="0m 0s"
    historyLb.Text="Riwayat  :  (belum ada)"
    showToast("↺ Reset","Statistik direset",C.gold)
end)

-- ==============================================
-- TAB: BOMB
-- ==============================================
local bombContent=addTab("BOMB","💣")
bombContent.Parent=ContentArea

local bombScroll=ScrollFrame(UDim2.new(1,0,1,0),bombContent)
local bombList=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
ListLayout(Enum.FillDirection.Vertical,6,bombList)
Padding({left=8,right=8,top=8,bottom=8},bombList)
bombList.Parent=bombScroll

-- Tier selector
local tierPanel=New("Frame",{BackgroundColor3=C.panel,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
Corner(6,tierPanel); Stroke(1,C.border,tierPanel)
SectionHeader("PILIH TIER BOM","🎯",tierPanel)
local tierList=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
ListLayout(Enum.FillDirection.Vertical,6,tierList)
Padding({left=8,right=8,top=8,bottom=8},tierList)
tierList.Parent=tierPanel
tierPanel.Parent=bombList

local tierBtns={}
local function selectTier(tier)
    config.bombTier=tier
    for t,btn in pairs(tierBtns) do
        local colors={biasa=C.gold,kuat=C.red,mega=C.cyan,auto=C.green}
        Tween(btn:FindFirstChildOfClass("UIStroke"),{Color=t==tier and (colors[t] or C.green) or C.border})
        Tween(btn,{BackgroundColor3=t==tier and C.bg2 or C.bg3})
    end
    showToast("🎯 Tier: "..string.upper(tier),"Kata bom diset ke "..tier,config.bombTier=="mega" and C.cyan or config.bombTier=="kuat" and C.red or C.gold)
end

tierBtns.auto  = BombTierBtn("⚡","AUTO","AI pilih tier terbaik","otomatis",C.green,tierList)
tierBtns.biasa = BombTierBtn("💣","BOM BIASA","Susah tapi masih bisa dibalas","f·v·w·y",C.gold,tierList)
tierBtns.kuat  = BombTierBtn("💣💣","BOM KUAT","Sangat sedikit yang bisa balas","x·q·z",C.red,tierList)
tierBtns.mega  = BombTierBtn("💣💣💣","MEGA BOM","Hampir mustahil dibalas!","ULTRA",C.cyan,tierList)

for tier,btn in pairs(tierBtns) do
    btn.MouseButton1Click:Connect(function() selectTier(tier) end)
end
selectTier("auto")

-- Bomb status
local bombStatusPanel=New("Frame",{BackgroundColor3=C.panel,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
Corner(6,bombStatusPanel); Stroke(1,C.border,bombStatusPanel)
SectionHeader("STATUS BOM REALTIME","◈",bombStatusPanel)
local bombStatusPad=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
Padding({left=8,right=8,top=8,bottom=8},bombStatusPad)
bombStatusPad.Parent=bombStatusPanel
bombStatusPanel.Parent=bombList

local bombReadyFrame=New("Frame",{BackgroundColor3=Color3.fromRGB(0,15,20),Size=UDim2.new(1,0,0,52)})
Corner(4,bombReadyFrame); Stroke(1,C.cyan,bombReadyFrame)
local bombWordLb=New("TextLabel",{Text="—",TextSize=18,Font=FONT_BOLD,TextColor3=C.cyan,BackgroundTransparency=1,Size=UDim2.new(1,-16,0,24),Position=UDim2.new(0,12,0,6),TextXAlignment=Enum.TextXAlignment.Left}); bombWordLb.Parent=bombReadyFrame
local bombInfoLb=New("TextLabel",{Text="Mulai pertandingan untuk preview bom",TextSize=9,Font=FONT_MONO,TextColor3=C.text3,BackgroundTransparency=1,Size=UDim2.new(1,-16,0,14),Position=UDim2.new(0,12,0,32),TextXAlignment=Enum.TextXAlignment.Left}); bombInfoLb.Parent=bombReadyFrame
bombReadyFrame.Parent=bombStatusPad

local bombStockLb=New("TextLabel",{Text="Stok  :  menghitung...",TextSize=10,Font=FONT_MONO,TextColor3=C.text3,BackgroundTransparency=1,Size=UDim2.new(1,0,0,18),TextXAlignment=Enum.TextXAlignment.Left}); bombStockLb.Parent=bombStatusPad

Button("🔍  Preview Kata Bom",C.bg3,C.cyan,bombStatusPad,function()
    if serverLetter=="" then showToast("⚠️","Masuk pertandingan dulu!",C.gold); return end
    local bw,bt,bs=findBombWord(serverLetter,config.bombTier)
    if bw then
        local icons={mega="💣💣💣",kuat="💣💣",biasa="💣"}
        bombWordLb.Text=(icons[bt] or "💣").."  "..string.upper(bw)
        bombInfoLb.Text="TIER: "..string.upper(bt or "?").."  ·  SKOR: "..tostring(bs)
        showToast("💣 Bom Ditemukan!",string.upper(bw).." | Skor: "..bs,C.cyan)
    else
        bombWordLb.Text="—"; bombInfoLb.Text="Tidak ada kata bom untuk huruf ini"
        showToast("😔 Tidak ada bom","Untuk huruf '"..string.upper(serverLetter).."'",C.text3)
    end
end)

local megaBtn=Button("💣💣💣  PAKSA MEGA BOM",Color3.fromRGB(25,5,10),C.red,bombStatusPad,function()
    if not matchActive or not isMyTurn then showToast("⚠️","Bukan giliran kamu!",C.gold); return end
    local ob,ot=config.bombMode,config.bombTier
    config.bombMode=true; config.bombTier="mega"
    task.spawn(startUltraAI)
    task.delay(2,function() config.bombMode=ob; config.bombTier=ot end)
end)
Stroke(1,C.red,megaBtn)

-- ==============================================
-- TAB: CONFIG
-- ==============================================
local configContent=addTab("CONFIG","⚙")
configContent.Parent=ContentArea

local configScroll=ScrollFrame(UDim2.new(1,0,1,0),configContent)
local cfgList=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
ListLayout(Enum.FillDirection.Vertical,6,cfgList)
Padding({left=8,right=8,top=8,bottom=8},cfgList)
cfgList.Parent=configScroll

-- AI params
local aiPanel=New("Frame",{BackgroundColor3=C.panel,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
Corner(6,aiPanel); Stroke(1,C.border,aiPanel)
SectionHeader("PARAMETER AI","⚡",aiPanel)
local aiList=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
ListLayout(Enum.FillDirection.Vertical,4,aiList)
Padding({left=8,right=8,top=8,bottom=8},aiList)
aiList.Parent=aiPanel; aiPanel.Parent=cfgList

Slider("AGRESIVITAS",0,100,20,function(v) config.aggression=v end,aiList)
Slider("PANJANG KATA MIN",2,6,3,function(v) config.minLength=v end,aiList)
Slider("PANJANG KATA MAX",5,20,12,function(v) config.maxLength=v end,aiList)

-- Human typing profile
local htPanel=New("Frame",{BackgroundColor3=C.panel,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
Corner(6,htPanel); Stroke(1,C.border,htPanel)
SectionHeader("HUMAN TYPING PROFILE","🎭",htPanel)
local htList=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
ListLayout(Enum.FillDirection.Vertical,2,htList)
Padding({left=8,right=8,top=8,bottom=8},htList)
htList.Parent=htPanel; htPanel.Parent=cfgList

local function profileRow(key, val)
    local f=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,22)})
    New("TextLabel",{Text=key,TextSize=10,Font=FONT_BOLD,TextColor3=C.text3,BackgroundTransparency=1,Size=UDim2.new(0.55,0,1,0),TextXAlignment=Enum.TextXAlignment.Left,LetterSpacing=1}).Parent=f
    local vl=New("TextLabel",{Text=val,TextSize=11,Font=FONT_BOLD,TextColor3=C.gold,BackgroundTransparency=1,Size=UDim2.new(0.45,0,1,0),Position=UDim2.new(0.55,0,0,0),TextXAlignment=Enum.TextXAlignment.Right}); vl.Parent=f
    f.Parent=htList
    return vl
end

local pSpeed    = profileRow("BASE SPEED",    humanProfile.baseSpeed.."ms")
local pTypo     = profileRow("TYPO CHANCE",   string.format("%.0f%%",humanProfile.mistakeChance*100))
local pHesitate = profileRow("HESITATE",      string.format("%.0f%%",humanProfile.hesitateChance*100))
local pStyle    = profileRow("STYLE",         humanProfile.isBurstyTyper and "BURST" or "KONSISTEN")
local pFatigue  = profileRow("FATIGUE",       "+"..humanProfile.fatigueRate.."ms/kata")

Button("🔄  Generate Profil Baru",Color3.fromRGB(15,15,5),C.gold,htList,function()
    humanProfile.baseSpeed      = math.random(350,550)
    humanProfile.mistakeChance  = math.random(6,13)/100
    humanProfile.hesitateChance = math.random(8,18)/100
    humanProfile.isBurstyTyper  = math.random(1,2)==1
    humanProfile.fatigueRate    = math.random(1,4)
    humanProfile.doubleTypoRate = math.random(2,6)/100
    humanProfile.wordCount      = 0
    pSpeed.Text    = humanProfile.baseSpeed.."ms"
    pTypo.Text     = string.format("%.0f%%",humanProfile.mistakeChance*100)
    pHesitate.Text = string.format("%.0f%%",humanProfile.hesitateChance*100)
    pStyle.Text    = humanProfile.isBurstyTyper and "BURST" or "KONSISTEN"
    pFatigue.Text  = "+"..humanProfile.fatigueRate.."ms/kata"
    showToast("🎭 Profil Baru!",string.format("Spd:%dms Typo:%.0f%%",humanProfile.baseSpeed,humanProfile.mistakeChance*100),C.gold)
end)

-- Delay
local delayPanel=New("Frame",{BackgroundColor3=C.panel,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
Corner(6,delayPanel); Stroke(1,C.border,delayPanel)
SectionHeader("DELAY FALLBACK","⏱",delayPanel)
local delayList=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
ListLayout(Enum.FillDirection.Vertical,4,delayList)
Padding({left=8,right=8,top=8,bottom=8},delayList)
delayList.Parent=delayPanel; delayPanel.Parent=cfgList

Slider("DELAY MIN (ms)",50,600,500,function(v) config.minDelay=v end,delayList)
Slider("DELAY MAX (ms)",100,1200,750,function(v) config.maxDelay=v end,delayList)

local safePanel=New("Frame",{BackgroundColor3=C.panel,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
Corner(6,safePanel); Stroke(1,C.border,safePanel)
SectionHeader("PANDUAN KEAMANAN","🛡",safePanel)
local safePad=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
ListLayout(Enum.FillDirection.Vertical,4,safePad)
Padding({left=8,right=8,top=8,bottom=8},safePad)
safePad.Parent=safePanel; safePanel.Parent=cfgList

local function safeRow(dot,dotColor,txt)
    local f=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,20)})
    New("TextLabel",{Text=dot,TextSize=12,Font=FONT_BOLD,TextColor3=dotColor,BackgroundTransparency=1,Size=UDim2.new(0,20,1,0)}).Parent=f
    New("TextLabel",{Text=txt,TextSize=11,Font=FONT_MED,TextColor3=C.text2,BackgroundTransparency=1,Size=UDim2.new(1,-24,1,0),Position=UDim2.new(0,24,0,0),TextXAlignment=Enum.TextXAlignment.Left}).Parent=f
    f.Parent=safePad
end
safeRow("●",C.green,"AMAN  →  Human Typing ON")
safeRow("●",C.gold, "SEDANG  →  Delay 400ms+")
safeRow("●",C.red,  "BERISIKO  →  Delay < 200ms")

-- ==============================================
-- TAB: INFO
-- ==============================================
local infoContent=addTab("INFO","◈")
infoContent.Parent=ContentArea

local infoScroll=ScrollFrame(UDim2.new(1,0,1,0),infoContent)
local infoList=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
ListLayout(Enum.FillDirection.Vertical,6,infoList)
Padding({left=8,right=8,top=8,bottom=8},infoList)
infoList.Parent=infoScroll

-- About card
local aboutPanel=New("Frame",{BackgroundColor3=C.panel,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
Corner(6,aboutPanel); Stroke(1,C.border,aboutPanel)
SectionHeader("TENTANG","◈",aboutPanel)
local aboutPad=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
Padding({left=8,right=8,top=12,bottom=12},aboutPad)
aboutPad.Parent=aboutPanel; aboutPanel.Parent=infoList

-- Big stat strip
local stripFrame=New("Frame",{BackgroundColor3=C.bg3,Size=UDim2.new(1,0,0,54)}); Corner(4,stripFrame)
ListLayout(Enum.FillDirection.Horizontal,0,stripFrame)
local function strip(val,label,color)
    local f=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(0.33,0,1,0)})
    New("TextLabel",{Text=val,TextSize=20,Font=FONT_BOLD,TextColor3=color,BackgroundTransparency=1,Size=UDim2.new(1,0,0,28),Position=UDim2.new(0,0,0,4),TextXAlignment=Enum.TextXAlignment.Center}).Parent=f
    New("TextLabel",{Text=label,TextSize=8,Font=FONT_BOLD,TextColor3=C.text3,BackgroundTransparency=1,Size=UDim2.new(1,0,0,14),Position=UDim2.new(0,0,0,34),TextXAlignment=Enum.TextXAlignment.Center,LetterSpacing=2}).Parent=f
    f.Parent=stripFrame
end
strip("80K+","KATA",C.gold); strip("3","TIER BOM",C.cyan); strip("v6","VERSI",C.green)
stripFrame.Parent=aboutPad

local function infoRow(icon, text)
    local f=New("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,20)})
    New("TextLabel",{Text=icon,TextSize=13,Font=FONT_BOLD,TextColor3=C.red,BackgroundTransparency=1,Size=UDim2.new(0,28,1,0)}).Parent=f
    New("TextLabel",{Text=text,TextSize=11,Font=FONT_MED,TextColor3=C.text2,BackgroundTransparency=1,Size=UDim2.new(1,-32,1,0),Position=UDim2.new(0,32,0,0),TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true}).Parent=f
    f.Parent=aboutPad
end

infoRow("01","Buka tab BATTLE → Aktifkan Auto Kata")
infoRow("02","Aktifkan Kata Bom di tab BATTLE")
infoRow("03","Pilih tier bom di tab BOMB")
infoRow("04","Generate profil baru tiap sesi")
infoRow("05","Masuk pertandingan — AI bekerja sendiri!")

-- ==============================================
-- SWITCH TO FIRST TAB
-- ==============================================
switchTab("BATTLE")

-- ==============================================
-- AUTO ENGINE
-- ==============================================
local function startUltraAI()
    if autoRunning or not autoEnabled or not matchActive or not isMyTurn or serverLetter=="" then return end
    autoRunning=true
    task.wait(math.random(config.minDelay,config.maxDelay)/1000)
    local selectedWord,isBomb,bombTierUsed,bombScoreVal=nil,false,nil,0
    if config.bombMode then
        local bw,bt,bs=findBombWord(serverLetter,config.bombTier)
        if bw then selectedWord=bw; isBomb=true; bombTierUsed=bt; bombScoreVal=bs
            bombWordLb.Text=(bt=="mega" and "💣💣💣" or bt=="kuat" and "💣💣" or "💣").."  "..string.upper(bw)
            bombInfoLb.Text="TIER: "..string.upper(bt or "?").."  ·  SKOR: "..tostring(bs)
        end
    end
    if not selectedWord then
        local words=getSmartWords(serverLetter)
        if #words==0 then
            if #config.filterEnding>0 then
                local old=config.filterEnding; config.filterEnding={}
                words=getSmartWords(serverLetter); config.filterEnding=old
            end
            if #words==0 then autoRunning=false; return end
        end
        if config.aggression>=100 then selectedWord=words[1]
        else
            local topN=math.max(1,math.floor(#words*(1-config.aggression/100)))
            if topN>#words then topN=#words end
            selectedWord=words[math.random(1,topN)]
        end
    end
    local success=humanTypeWord(selectedWord,serverLetter)
    if not success then autoRunning=false; return end
    SubmitWord:FireServer(selectedWord)
    addUsedWord(selectedWord)
    -- update UI
    historyLb.Text="Riwayat: "..table.concat(usedWordsList,", ",math.max(1,#usedWordsList-5))
    statTotal.Text=tostring(stats.totalWords)
    statLong.Text=stats.longestWord~="" and string.upper(stats.longestWord) or "—"
    if isBomb then
        stats.bombsFired=(stats.bombsFired or 0)+1
        statBomb.Text=tostring(stats.bombsFired)
        local icon=bombTierUsed=="mega" and "💣💣💣" or bombTierUsed=="kuat" and "💣💣" or "💣"
        showToast(icon.." BOM DILUNCURKAN!",string.upper(selectedWord).." | Skor: "..bombScoreVal,C.red)
    end
    task.wait(math.random(100,300)/1000)
    BillboardEnd:FireServer()
    autoRunning=false
end

-- watcher
task.spawn(function()
    while true do
        task.wait(0.3)
        if autoEnabled and matchActive and isMyTurn and serverLetter~="" and not autoRunning then
            task.spawn(startUltraAI)
        end
    end
end)

-- stats timer
task.spawn(function()
    while true do
        task.wait(5)
        local elapsed=os.time()-(stats.sessionStart or os.time())
        statDur.Text=math.floor(elapsed/60).."m "..(elapsed%60).."s"
    end
end)

-- big letter pulse animation
task.spawn(function()
    local t=0
    while true do
        task.wait(0.05)
        t=t+0.05
        local alpha=0.5+0.5*math.sin(t*2)
        bigLetterLb.TextColor3=C.cyan:Lerp(Color3.fromRGB(0,180,220),alpha)
    end
end)

-- ==============================================
-- REMOTE HANDLERS
-- ==============================================
local function onMatchUI(cmd, value)
    if cmd=="ShowMatchUI" then
        matchActive=true; isMyTurn=false
        resetUsedWords(); humanProfile.wordCount=0
        turnVal.Text="⏳ Menunggu giliran..."; turnVal.TextColor3=C.gold
        oppVal.Text="👀 Pertandingan dimulai!"; oppVal.TextColor3=C.gold
        showToast("🎮 Match Dimulai","Menunggu giliran...",C.gold)

    elseif cmd=="HideMatchUI" then
        matchActive=false; isMyTurn=false; serverLetter=""
        turnVal.Text="❌ Selesai"; turnVal.TextColor3=C.text3
        letterVal.Text="—"; letterVal.TextColor3=C.text3
        bigLetterLb.Text="?"; bigLetterLb.TextColor3=C.cyan
        showToast("🏁 Match Selesai","GG!",C.text2)

    elseif cmd=="StartTurn" then
        isMyTurn=true
        turnVal.Text="✅ GILIRAN KAMU!"; turnVal.TextColor3=C.green
        showToast("⚔️ Giliran Kamu!","AI sedang memilih kata...",C.green)
        if autoEnabled and serverLetter~="" then task.spawn(startUltraAI) end

    elseif cmd=="EndTurn" then
        isMyTurn=false
        turnVal.Text="⏳ Giliran lawan..."; turnVal.TextColor3=C.gold

    elseif cmd=="UpdateServerLetter" then
        serverLetter=tostring(value or "")
        local d=serverLetter~="" and string.upper(serverLetter) or "—"
        letterVal.Text=d; letterVal.TextColor3=C.cyan
        bigLetterLb.Text=d
        if config.bombMode then
            task.spawn(function()
                local bw,bt,bs=findBombWord(serverLetter,config.bombTier)
                if bw then
                    bombWordLb.Text=(bt=="mega" and "💣💣💣" or bt=="kuat" and "💣💣" or "💣").."  "..string.upper(bw)
                    bombInfoLb.Text="TIER: "..string.upper(bt or "?").."  ·  SKOR: "..tostring(bs)
                end
            end)
        end
        if autoEnabled and matchActive and isMyTurn then task.spawn(startUltraAI) end
    end
end

local function onBillboard(word)
    if matchActive and not isMyTurn then
        local d=tostring(word or "")
        oppVal.Text="✍ "..( d~="" and d or "..."); oppVal.TextColor3=C.gold
    end
end

local function onUsedWarn(word)
    if word then
        addUsedWord(word)
        if autoEnabled and matchActive and isMyTurn then
            task.wait(math.random(200,400)/1000)
            task.spawn(startUltraAI)
        end
    end
end

MatchUI.OnClientEvent:Connect(onMatchUI)
BillboardUpdate.OnClientEvent:Connect(onBillboard)
UsedWordWarn.OnClientEvent:Connect(onUsedWarn)

-- Bomb stock counter (delayed)
task.delay(4,function()
    local total=0
    for _,word in ipairs(kataModule) do
        if getBombScore(word)>=20 then total=total+1 end
    end
    bombStockLb.Text="Stok Kata Bom  :  ~"..tostring(total).." kata"
end)

-- Welcome toast
task.delay(0.5,function()
    showToast("⚔ NAKA v6.0 LOADED","Human Typing + Kata Bom aktif!",C.green)
end)
task.delay(2,function()
    showToast("📚 "..#kataModule.." kata dimuat","Siap untuk pertandingan!",C.cyan)
end)

print("NAKA AUTO KATA v6.0 — Custom GUI LOADED")
