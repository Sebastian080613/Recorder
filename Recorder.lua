local players = game:GetService("Players")
local player = players.LocalPlayer
local player_gui = player:WaitForChild("PlayerGui")
local user_input_service = game:GetService("UserInputService")
local replicated_storage = game:GetService("ReplicatedStorage")
local http_service = game:GetService("HttpService")

local file_name = "Strat.txt"
_G.record_strat = false

-- [[ NEW VARIABLES FOR SETTINGS & SKIPS ]]
_G.Settings = {
    SkipMode = "Single", -- "Single" (s) or "Range" (r)
    RecordAbilities = true
}

local skip_list = {}        -- For "s" format
local range_start = nil     -- For "r" format
local last_skipped_wave = nil
local range_time = ":00"

local spawned_towers = {}
local tower_count = 0

-- [[ UI INITIALIZATION ]]
local screen_gui = Instance.new("ScreenGui")
screen_gui.Name = "strat_recorder_ui"
screen_gui.ResetOnSpawn = false
screen_gui.Parent = player_gui

local main_frame = Instance.new("Frame", screen_gui)
main_frame.Name = "main_frame"
main_frame.Size = UDim2.new(0, 300, 0, 400)
main_frame.Position = UDim2.new(0.35, 0, 0.3, 0)
main_frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
main_frame.Active = true
main_frame.Draggable = true
Instance.new("UICorner", main_frame).CornerRadius = UDim.new(0, 8)

-- Settings Menu (Hidden by default)
local settings_frame = Instance.new("Frame", main_frame)
settings_frame.Size = UDim2.new(1, 0, 0.7, 0)
settings_frame.Position = UDim2.new(0, 0, 0.1, 0)
settings_frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
settings_frame.Visible = false
settings_frame.ZIndex = 5
Instance.new("UICorner", settings_frame)

local settings_toggle = Instance.new("TextButton", main_frame)
settings_toggle.Size = UDim2.new(0, 30, 0, 30)
settings_toggle.Position = UDim2.new(1, -70, 0, 5)
settings_toggle.Text = "⚙️"
settings_toggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
Instance.new("UICorner", settings_toggle)

settings_toggle.MouseButton1Click:Connect(function() settings_frame.Visible = not settings_frame.Visible end)

-- Settings Toggles
local function add_setting(name, prop, y)
    local btn = Instance.new("TextButton", settings_frame)
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.Position = UDim2.new(0.05, 0, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Text = name .. ": " .. tostring(_G.Settings[prop])
    btn.ZIndex = 6
    Instance.new("UICorner", btn)

    btn.MouseButton1Click:Connect(function()
        if prop == "SkipMode" then
            _G.Settings[prop] = (_G.Settings[prop] == "Single") and "Range" or "Single"
        else
            _G.Settings[prop] = not _G.Settings[prop]
        end
        btn.Text = name .. ": " .. tostring(_G.Settings[prop])
    end)
end

add_setting("Skip Style (s/r)", "SkipMode", 50)
add_setting("Abilities", "RecordAbilities", 95)

-- [[ HELPER FUNCTIONS ]]
local function add_log(msg)
    local log_item = Instance.new("TextLabel", log_box)
    log_item.Size = UDim2.new(1, -10, 0, 18)
    log_item.BackgroundTransparency = 1
    log_item.TextColor3 = Color3.fromRGB(200, 200, 200)
    log_item.Text = "> " .. msg
    log_item.Font = Enum.Font.Code
    log_item.TextSize = 10
    log_item.TextXAlignment = Enum.TextXAlignment.Left
end

local function format_time()
    local state = replicated_storage:FindFirstChild("State")
    if not state then return ":00" end
    local total = math.max(0, state.MaxTimer.Value - state.Timer.Value)
    local m, s = math.floor(total/60), total%60
    return (m > 0) and string.format("%d:%02d", m, s) or string.format(":%02d", s)
end

-- [[ HOOKING SKIP LOGIC ]]
local old_namecall
old_namecall = hookmetamethod(game, "__namecall", function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    
    if _G.record_strat and self.Name == "Vote" and method == "FireServer" and args[1] == "Skip" then
        local state = replicated_storage:FindFirstChild("State")
        local wave = state.Wave.Value
        
        if _G.Settings.SkipMode == "Single" then
            if not table.find(skip_list, wave) then table.insert(skip_list, wave) end
            add_log("Logged Wave " .. wave .. " (Single)")
        else
            if not range_start then 
                range_start = wave 
                range_time = format_time()
            end
            last_skipped_wave = wave
            add_log("Range Streak: " .. range_start .. " -> " .. (wave + 1))
        end
    end
    return old_namecall(self, ...)
end)

-- [[ RANGE TERMINATOR ]]
task.spawn(function()
    while task.wait(2) do
        local state = replicated_storage:FindFirstChild("State")
        if _G.record_strat and _G.Settings.SkipMode == "Range" and range_start and last_skipped_wave then
            if state.Wave.Value > last_skipped_wave then
                local res = string.format('TDS:VoteSkip("r, %d, %d, %s")', range_start, last_skipped_wave + 1, range_time)
                if appendfile then appendfile(file_name, res .. "\n") end
                add_log("Saved Range: " .. res)
                range_start, last_skipped_wave = nil, nil
            end
        end
    end
end)

-- [[ BUTTON ACTIONS ]]
stop_btn.MouseButton1Click:Connect(function()
    if _G.Settings.SkipMode == "Single" and #skip_list > 0 then
        table.sort(skip_list)
        local res = string.format('TDS:VoteSkip("s, %s, %s")', table.concat(skip_list, ", "), format_time())
        if appendfile then appendfile(file_name, res .. "\n") end
    end
    
    _G.record_strat = false
    skip_list = {}
    range_start = nil
    add_log("--- Recording Saved ---")
end)

-- (Keep your original Title, Log Box, Close Btn, and Resize logic here...)
