--// ======================================================
--// SAZARAX ULTIMATE UI LIBRARY - COMPLETE EDITION
--// Optimized + Animated + Professional
--// ======================================================

local UILib = {}
UILib.__index = UILib

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer

--// =========================
--// THEME SYSTEM
--// =========================

UILib.Themes = {
    Dark = {
        Background = Color3.fromRGB(18,18,22),
        Secondary = Color3.fromRGB(28,28,35),
        Accent = Color3.fromRGB(120,90,255),
        Text = Color3.fromRGB(255,255,255)
    },
    Purple = {
        Background = Color3.fromRGB(25,20,40),
        Secondary = Color3.fromRGB(35,30,55),
        Accent = Color3.fromRGB(170,0,255),
        Text = Color3.fromRGB(255,255,255)
    },
    Red = {
        Background = Color3.fromRGB(35,15,15),
        Secondary = Color3.fromRGB(45,20,20),
        Accent = Color3.fromRGB(255,60,60),
        Text = Color3.fromRGB(255,255,255)
    }
}

--// =========================
--// CONFIG SYSTEM
--// =========================

function UILib:SaveConfig(name,data)
    if writefile then
        writefile(name..".json", HttpService:JSONEncode(data))
    end
end

function UILib:LoadConfig(name)
    if isfile and isfile(name..".json") then
        return HttpService:JSONDecode(readfile(name..".json"))
    end
end

--// =========================
--// NOTIFICATION SYSTEM
--// =========================

function UILib:Notify(text)
    local Gui = Instance.new("ScreenGui", CoreGui)
    local Frame = Instance.new("Frame", Gui)
    Frame.Size = UDim2.fromOffset(300,60)
    Frame.Position = UDim2.new(1,-320,1,-100)
    Frame.BackgroundColor3 = Color3.fromRGB(25,25,30)
    Frame.BackgroundTransparency = 1
    Instance.new("UICorner",Frame)

    local Label = Instance.new("TextLabel",Frame)
    Label.Size = UDim2.new(1,-20,1,0)
    Label.Position = UDim2.new(0,10,0,0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.new(1,1,1)
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 14

    TweenService:Create(Frame,TweenInfo.new(0.3),{
        BackgroundTransparency = 0
    }):Play()

    task.wait(3)

    TweenService:Create(Frame,TweenInfo.new(0.3),{
        BackgroundTransparency = 1
    }):Play()

    task.wait(0.3)
    Gui:Destroy()
end

--// =========================
--// KEY SYSTEM
--// =========================

function UILib:CreateKeySystem(correctKey)

    local Gui = Instance.new("ScreenGui", CoreGui)

    local Frame = Instance.new("Frame",Gui)
    Frame.Size = UDim2.fromOffset(420,220)
    Frame.Position = UDim2.fromScale(0.5,0.5)
    Frame.AnchorPoint = Vector2.new(0.5,0.5)
    Frame.BackgroundColor3 = Color3.fromRGB(20,20,25)
    Frame.BackgroundTransparency = 1
    Instance.new("UICorner",Frame)

    TweenService:Create(Frame,TweenInfo.new(0.4),{
        BackgroundTransparency = 0
    }):Play()

    local Title = Instance.new("TextLabel",Frame)
    Title.Size = UDim2.new(1,0,0,50)
    Title.BackgroundTransparency = 1
    Title.Text = "Key System"
    Title.TextColor3 = Color3.new(1,1,1)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 22

    local Box = Instance.new("TextBox",Frame)
    Box.Size = UDim2.new(0.8,0,0,40)
    Box.Position = UDim2.new(0.1,0,0.4,0)
    Box.PlaceholderText = "Enter Key..."
    Box.BackgroundColor3 = Color3.fromRGB(35,35,45)
    Box.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner",Box)

    local Submit = Instance.new("TextButton",Frame)
    Submit.Size = UDim2.new(0.8,0,0,40)
    Submit.Position = UDim2.new(0.1,0,0.65,0)
    Submit.Text = "Unlock"
    Submit.BackgroundColor3 = Color3.fromRGB(120,90,255)
    Submit.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner",Submit)

    local unlocked = false

    Submit.MouseButton1Click:Connect(function()
        if Box.Text == correctKey then
            unlocked = true
            TweenService:Create(Frame,TweenInfo.new(0.3),{
                BackgroundTransparency = 1
            }):Play()
            task.wait(0.3)
            Gui:Destroy()
        end
    end)

    repeat task.wait() until unlocked
end

--// =========================
--// CREATE WINDOW
--// =========================

function UILib:CreateWindow(settings)

    local Theme = self.Themes[settings.Theme] or self.Themes.Dark

    local ScreenGui = Instance.new("ScreenGui",CoreGui)
    ScreenGui.Name = "SazaraxUI"

    local Main = Instance.new("Frame",ScreenGui)
    Main.Size = UDim2.fromOffset(650,450)
    Main.Position = UDim2.fromScale(0.5,0.5)
    Main.AnchorPoint = Vector2.new(0.5,0.5)
    Main.BackgroundColor3 = Theme.Background
    Main.BackgroundTransparency = 1
    Instance.new("UICorner",Main)

    TweenService:Create(Main,TweenInfo.new(0.4),{
        BackgroundTransparency = 0
    }):Play()

    -- Drag
    local dragging, dragInput, dragStart, startPos

    Main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
        end
    end)

    Main.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    -- Tabs Holder
    local TabButtons = Instance.new("Frame",Main)
    TabButtons.Size = UDim2.new(0,150,1,0)
    TabButtons.BackgroundColor3 = Theme.Secondary
    Instance.new("UICorner",TabButtons)

    local Content = Instance.new("Frame",Main)
    Content.Size = UDim2.new(1,-160,1,-10)
    Content.Position = UDim2.new(0,160,0,5)
    Content.BackgroundTransparency = 1

    local Window = {}
    local Tabs = {}

    function Window:AddTab(name)
        local Button = Instance.new("TextButton",TabButtons)
        Button.Size = UDim2.new(1,0,0,45)
        Button.Text = name
        Button.BackgroundTransparency = 1
        Button.TextColor3 = Theme.Text
        Button.Font = Enum.Font.Gotham
        Button.TextSize = 14

        local TabFrame = Instance.new("Frame",Content)
        TabFrame.Size = UDim2.new(1,0,1,0)
        TabFrame.Visible = false
        TabFrame.BackgroundTransparency = 1

        local Layout = Instance.new("UIListLayout",TabFrame)
        Layout.Padding = UDim.new(0,8)

        Button.MouseButton1Click:Connect(function()
            for _,v in pairs(Content:GetChildren()) do
                if v:IsA("Frame") then v.Visible = false end
            end
            TabFrame.Visible = true
        end)

        Tabs[name] = TabFrame
        return TabFrame
    end

    return Window
end

return UILib
