--[[
    NovaUI - LOGIC FILE
    Host this file (e.g. GitHub raw) and load it from Usage.lua with loadstring.

    API:
        Library:CreateWindow({Title, Size, ToggleKey, OnClose})
            Window:CreateTab(name)
                Tab:CreateSection(name)
                Tab:CreateLabel(text)
                Tab:CreateButton({Name, Callback})
                Tab:CreateToggle({Name, Default, Callback})
                Tab:CreateSlider({Name, Range, Increment, Default, Callback})
                Tab:CreateDropdown({Name, Options, Default, Callback})
                Tab:CreateTextbox({Name, Placeholder, Callback})
                Tab:CreateKeybind({Name, Default, Callback})
            Window:Notify({Title, Content, Duration})
            Window:Destroy()
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local Library = {}

local Theme = {
    Background = Color3.fromRGB(22, 22, 28),
    Topbar = Color3.fromRGB(30, 30, 38),
    Sidebar = Color3.fromRGB(27, 27, 34),
    Element = Color3.fromRGB(38, 38, 48),
    ElementHover = Color3.fromRGB(52, 52, 66),
    Accent = Color3.fromRGB(110, 120, 255),
    Text = Color3.fromRGB(235, 235, 245),
    SubText = Color3.fromRGB(150, 150, 168),
    Close = Color3.fromRGB(255, 95, 95),
    Minimize = Color3.fromRGB(255, 200, 70),
}

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------

local function create(className, props, children)
    local inst = Instance.new(className)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    return inst
end

local function tween(obj, props, time)
    local t = TweenService:Create(obj, TweenInfo.new(time or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function corner(radius)
    return create("UICorner", {CornerRadius = UDim.new(0, radius or 6)})
end

local function safeCall(callback, ...)
    if type(callback) == "function" then
        local ok, err = pcall(callback, ...)
        if not ok then
            warn("[NovaUI] " .. tostring(err))
        end
    end
end

local function getGuiParent()
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then
            return hui
        end
    end
    local ok = pcall(function() return CoreGui.Name end)
    if ok then
        return CoreGui
    end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function newLabel(parent, text, props)
    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = parent,
    })
    for k, v in pairs(props or {}) do
        label[k] = v
    end
    return label
end

local function newElement(parent, height)
    return create("Frame", {
        Size = UDim2.new(1, 0, 0, height or 36),
        BackgroundColor3 = Theme.Element,
        BorderSizePixel = 0,
        Parent = parent,
    }, {corner(6)})
end

local function hover(button, target)
    target = target or button
    button.MouseEnter:Connect(function()
        tween(target, {BackgroundColor3 = Theme.ElementHover}, 0.15)
    end)
    button.MouseLeave:Connect(function()
        tween(target, {BackgroundColor3 = Theme.Element}, 0.15)
    end)
end

---------------------------------------------------------------------
-- Window
---------------------------------------------------------------------

function Library:CreateWindow(config)
    config = config or {}
    local Window = {Connections = {}, Tabs = {}, Minimized = false, ActiveTab = nil}

    local size = config.Size or UDim2.fromOffset(540, 370)
    local width, height = size.X.Offset, size.Y.Offset
    local toggleKey = config.ToggleKey or Enum.KeyCode.RightShift

    local function connect(signal, fn)
        local c = signal:Connect(fn)
        table.insert(Window.Connections, c)
        return c
    end

    local gui = create("ScreenGui", {
        Name = config.Name or "NovaUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 100,
    })
    if syn and syn.protect_gui then
        pcall(syn.protect_gui, gui)
    end
    gui.Parent = getGuiParent()

    local main = create("Frame", {
        Name = "Main",
        Size = size,
        Position = UDim2.new(0.5, -width / 2, 0.5, -height / 2),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = gui,
    }, {
        corner(10),
        create("UIStroke", {Color = Theme.ElementHover, Thickness = 1}),
    })

    -- Topbar -----------------------------------------------------------
    local topbar = create("Frame", {
        Name = "Topbar",
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = Theme.Topbar,
        BorderSizePixel = 0,
        Parent = main,
    }, {corner(10)})

    create("Frame", { -- squares off the bottom corners of the topbar
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 1, -10),
        BackgroundColor3 = Theme.Topbar,
        BorderSizePixel = 0,
        Parent = topbar,
    })

    newLabel(topbar, config.Title or "Nova UI", {
        Size = UDim2.new(1, -90, 1, 0),
        Position = UDim2.new(0, 14, 0, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
    })

    local function topButton(text, color, xOffset)
        local btn = create("TextButton", {
            Size = UDim2.fromOffset(24, 24),
            Position = UDim2.new(1, xOffset, 0.5, -12),
            BackgroundColor3 = Theme.Element,
            Text = text,
            TextColor3 = Theme.Text,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            AutoButtonColor = false,
            Parent = topbar,
        }, {corner(6)})
        btn.MouseEnter:Connect(function()
            tween(btn, {BackgroundColor3 = color}, 0.15)
        end)
        btn.MouseLeave:Connect(function()
            tween(btn, {BackgroundColor3 = Theme.Element}, 0.15)
        end)
        return btn
    end

    local closeBtn = topButton("X", Theme.Close, -32)
    local minimizeBtn = topButton("-", Theme.Minimize, -62)

    -- Dragging ---------------------------------------------------------
    do
        local dragging, dragStart, startPos
        connect(topbar.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = main.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        connect(UserInputService.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                main.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
    end

    -- Body -------------------------------------------------------------
    local body = create("Frame", {
        Name = "Body",
        Size = UDim2.new(1, 0, 1, -38),
        Position = UDim2.new(0, 0, 0, 38),
        BackgroundTransparency = 1,
        Parent = main,
    })

    local sidebar = create("ScrollingFrame", {
        Size = UDim2.new(0, 130, 1, -16),
        Position = UDim2.new(0, 8, 0, 8),
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = body,
    }, {
        corner(8),
        create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}),
        create("UIPadding", {
            PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
            PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
        }),
    })

    local pages = create("Frame", {
        Size = UDim2.new(1, -154, 1, -16),
        Position = UDim2.new(0, 146, 0, 8),
        BackgroundTransparency = 1,
        Parent = body,
    })

    -- Minimize / Close -------------------------------------------------
    connect(minimizeBtn.MouseButton1Click, function()
        Window.Minimized = not Window.Minimized
        if Window.Minimized then
            local t = tween(main, {Size = UDim2.fromOffset(width, 38)}, 0.25)
            t.Completed:Connect(function()
                if Window.Minimized then
                    body.Visible = false
                end
            end)
        else
            body.Visible = true
            tween(main, {Size = size}, 0.25)
        end
    end)

    function Window:Destroy()
        for _, c in ipairs(Window.Connections) do
            c:Disconnect()
        end
        Window.Connections = {}
        local t = tween(main, {Size = UDim2.fromOffset(width, 0)}, 0.2)
        t.Completed:Connect(function()
            gui:Destroy()
        end)
        safeCall(config.OnClose)
    end

    connect(closeBtn.MouseButton1Click, function()
        Window:Destroy()
    end)

    connect(UserInputService.InputBegan, function(input, processed)
        if not processed and input.KeyCode == toggleKey then
            main.Visible = not main.Visible
        end
    end)

    -- Notifications ----------------------------------------------------
    local notifyHolder = create("Frame", {
        Size = UDim2.new(0, 260, 1, -20),
        Position = UDim2.new(1, -270, 0, 0),
        BackgroundTransparency = 1,
        Parent = gui,
    }, {
        create("UIListLayout", {
            Padding = UDim.new(0, 8),
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })

    function Window:Notify(o)
        o = o or {}
        local wrapper = create("Frame", {
            Size = UDim2.new(1, 0, 0, 62),
            BackgroundTransparency = 1,
            Parent = notifyHolder,
        })
        local card = create("Frame", {
            Size = UDim2.fromScale(1, 1),
            Position = UDim2.new(1.2, 0, 0, 0),
            BackgroundColor3 = Theme.Topbar,
            BorderSizePixel = 0,
            Parent = wrapper,
        }, {
            corner(8),
            create("UIStroke", {Color = Theme.Accent, Thickness = 1}),
        })
        newLabel(card, o.Title or "Notification", {
            Size = UDim2.new(1, -20, 0, 20),
            Position = UDim2.new(0, 10, 0, 6),
            Font = Enum.Font.GothamBold,
        })
        newLabel(card, o.Content or "", {
            Size = UDim2.new(1, -20, 0, 30),
            Position = UDim2.new(0, 10, 0, 26),
            TextColor3 = Theme.SubText,
            TextSize = 12,
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
        })
        tween(card, {Position = UDim2.new(0, 0, 0, 0)}, 0.3)
        task.delay(o.Duration or 4, function()
            local t = tween(card, {Position = UDim2.new(1.2, 0, 0, 0)}, 0.3)
            t.Completed:Connect(function()
                wrapper:Destroy()
            end)
        end)
    end

    -----------------------------------------------------------------
    -- Tabs
    -----------------------------------------------------------------

    function Window:CreateTab(name)
        local Tab = {}

        local tabBtn = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 1,
            Text = name or "Tab",
            TextColor3 = Theme.SubText,
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            AutoButtonColor = false,
            Parent = sidebar,
        }, {corner(6)})

        local page = create("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
            Parent = pages,
        }, {
            create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}),
            create("UIPadding", {
                PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2),
                PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 8),
            }),
        })

        local function select()
            for _, t in ipairs(Window.Tabs) do
                t.Page.Visible = false
                tween(t.Button, {BackgroundTransparency = 1, TextColor3 = Theme.SubText}, 0.15)
            end
            page.Visible = true
            tween(tabBtn, {BackgroundTransparency = 0.8, TextColor3 = Theme.Text}, 0.15)
            Window.ActiveTab = Tab
        end

        Tab.Page, Tab.Button = page, tabBtn
        table.insert(Window.Tabs, Tab)
        connect(tabBtn.MouseButton1Click, select)
        if #Window.Tabs == 1 then
            select()
        end

        -- Section ------------------------------------------------------
        function Tab:CreateSection(text)
            newLabel(page, string.upper(text or "Section"), {
                Size = UDim2.new(1, 0, 0, 22),
                TextColor3 = Theme.Accent,
                Font = Enum.Font.GothamBold,
                TextSize = 11,
            })
        end

        -- Label --------------------------------------------------------
        function Tab:CreateLabel(text)
            local frame = newElement(page, 30)
            local label = newLabel(frame, text or "Label", {
                Size = UDim2.new(1, -24, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
                TextColor3 = Theme.SubText,
            })
            local obj = {}
            function obj:Set(t)
                label.Text = t
            end
            return obj
        end

        -- Button -------------------------------------------------------
        function Tab:CreateButton(o)
            o = o or {}
            local btn = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 36),
                BackgroundColor3 = Theme.Element,
                Text = "",
                AutoButtonColor = false,
                BorderSizePixel = 0,
                Parent = page,
            }, {corner(6)})
            newLabel(btn, o.Name or "Button", {
                Size = UDim2.new(1, -24, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
            })
            hover(btn)
            connect(btn.MouseButton1Click, function()
                safeCall(o.Callback)
            end)
        end

        -- Toggle -------------------------------------------------------
        function Tab:CreateToggle(o)
            o = o or {}
            local state = o.Default == true
            local frame = newElement(page, 36)
            newLabel(frame, o.Name or "Toggle", {
                Size = UDim2.new(1, -70, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
            })
            local track = create("TextButton", {
                Size = UDim2.fromOffset(38, 20),
                Position = UDim2.new(1, -50, 0.5, -10),
                BackgroundColor3 = Theme.ElementHover,
                Text = "",
                AutoButtonColor = false,
                Parent = frame,
            }, {corner(10)})
            local knob = create("Frame", {
                Size = UDim2.fromOffset(14, 14),
                Position = UDim2.new(0, 3, 0.5, -7),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0,
                Parent = track,
            }, {corner(7)})

            local function render()
                tween(track, {BackgroundColor3 = state and Theme.Accent or Theme.ElementHover})
                tween(knob, {Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)})
            end

            local obj = {}
            function obj:Set(v, silent)
                state = v and true or false
                render()
                if not silent then
                    safeCall(o.Callback, state)
                end
            end
            function obj:Get()
                return state
            end

            connect(track.MouseButton1Click, function()
                obj:Set(not state)
            end)
            render()
            if state then
                safeCall(o.Callback, state)
            end
            return obj
        end

        -- Slider -------------------------------------------------------
        function Tab:CreateSlider(o)
            o = o or {}
            local min = (o.Range and o.Range[1]) or 0
            local max = (o.Range and o.Range[2]) or 100
            local inc = o.Increment or 1
            local value = o.Default or min

            local frame = newElement(page, 50)
            newLabel(frame, o.Name or "Slider", {
                Size = UDim2.new(1, -80, 0, 24),
                Position = UDim2.new(0, 12, 0, 4),
            })
            local valueLabel = newLabel(frame, "", {
                Size = UDim2.new(0, 60, 0, 24),
                Position = UDim2.new(1, -72, 0, 4),
                TextXAlignment = Enum.TextXAlignment.Right,
                TextColor3 = Theme.SubText,
            })
            local bar = create("Frame", {
                Size = UDim2.new(1, -24, 0, 6),
                Position = UDim2.new(0, 12, 0, 34),
                BackgroundColor3 = Theme.ElementHover,
                BorderSizePixel = 0,
                Parent = frame,
            }, {corner(3)})
            local fill = create("Frame", {
                Size = UDim2.fromScale(0, 1),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                Parent = bar,
            }, {corner(3)})

            local obj = {}
            function obj:Set(v, silent)
                v = math.clamp(v, min, max)
                v = math.floor(v / inc + 0.5) * inc
                v = math.clamp(v, min, max)
                value = v
                fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
                valueLabel.Text = tostring(math.floor(v * 1000 + 0.5) / 1000)
                if not silent then
                    safeCall(o.Callback, v)
                end
            end
            function obj:Get()
                return value
            end

            local dragging = false
            local function update(input)
                local alpha = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                obj:Set(min + (max - min) * alpha)
            end
            connect(bar.InputBegan, function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    update(input)
                end
            end)
            connect(UserInputService.InputEnded, function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)
            connect(UserInputService.InputChanged, function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    update(input)
                end
            end)

            obj:Set(value, true)
            return obj
        end

        -- Dropdown -----------------------------------------------------
        function Tab:CreateDropdown(o)
            o = o or {}
            local options = o.Options or {}
            local selected = o.Default or options[1]
            local open = false
            local itemHeight = 26

            local holder = create("Frame", {
                Size = UDim2.new(1, 0, 0, 36),
                BackgroundColor3 = Theme.Element,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Parent = page,
            }, {corner(6)})
            local header = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 36),
                BackgroundTransparency = 1,
                Text = "",
                Parent = holder,
            })
            newLabel(header, o.Name or "Dropdown", {
                Size = UDim2.new(0.5, 0, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
            })
            local valueLabel = newLabel(header, tostring(selected or "None"), {
                Size = UDim2.new(0.5, -32, 1, 0),
                Position = UDim2.new(0.5, 0, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Right,
                TextColor3 = Theme.SubText,
            })
            local arrow = newLabel(header, "v", {
                Size = UDim2.new(0, 20, 1, 0),
                Position = UDim2.new(1, -24, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Center,
                TextColor3 = Theme.SubText,
            })
            local list = create("Frame", {
                Size = UDim2.new(1, 0, 0, #options * itemHeight),
                Position = UDim2.new(0, 0, 0, 36),
                BackgroundTransparency = 1,
                Parent = holder,
            }, {create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder})})

            local obj = {}
            function obj:Set(v, silent)
                selected = v
                valueLabel.Text = tostring(v)
                if not silent then
                    safeCall(o.Callback, v)
                end
            end
            function obj:Get()
                return selected
            end

            for _, option in ipairs(options) do
                local item = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, itemHeight),
                    BackgroundColor3 = Theme.Element,
                    BorderSizePixel = 0,
                    Text = tostring(option),
                    TextColor3 = Theme.SubText,
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    AutoButtonColor = false,
                    Parent = list,
                })
                hover(item)
                connect(item.MouseButton1Click, function()
                    obj:Set(option)
                    open = false
                    arrow.Text = "v"
                    tween(holder, {Size = UDim2.new(1, 0, 0, 36)}, 0.2)
                end)
            end

            connect(header.MouseButton1Click, function()
                open = not open
                arrow.Text = open and "^" or "v"
                tween(holder, {Size = UDim2.new(1, 0, 0, open and (36 + #options * itemHeight) or 36)}, 0.2)
            end)
            return obj
        end

        -- Textbox ------------------------------------------------------
        function Tab:CreateTextbox(o)
            o = o or {}
            local frame = newElement(page, 36)
            newLabel(frame, o.Name or "Textbox", {
                Size = UDim2.new(0.5, -12, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
            })
            local box = create("TextBox", {
                Size = UDim2.new(0.5, -20, 0, 24),
                Position = UDim2.new(0.5, 8, 0.5, -12),
                BackgroundColor3 = Theme.ElementHover,
                BorderSizePixel = 0,
                Text = "",
                PlaceholderText = o.Placeholder or "Type here...",
                PlaceholderColor3 = Theme.SubText,
                TextColor3 = Theme.Text,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                ClearTextOnFocus = false,
                Parent = frame,
            }, {corner(5)})
            connect(box.FocusLost, function()
                safeCall(o.Callback, box.Text)
            end)
            local obj = {}
            function obj:Set(t)
                box.Text = t
            end
            function obj:Get()
                return box.Text
            end
            return obj
        end

        -- Keybind ------------------------------------------------------
        function Tab:CreateKeybind(o)
            o = o or {}
            local key = o.Default or Enum.KeyCode.F
            local listening = false

            local frame = newElement(page, 36)
            newLabel(frame, o.Name or "Keybind", {
                Size = UDim2.new(1, -100, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
            })
            local btn = create("TextButton", {
                Size = UDim2.fromOffset(70, 24),
                Position = UDim2.new(1, -82, 0.5, -12),
                BackgroundColor3 = Theme.ElementHover,
                BorderSizePixel = 0,
                Text = key.Name,
                TextColor3 = Theme.Text,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                AutoButtonColor = false,
                Parent = frame,
            }, {corner(5)})

            connect(btn.MouseButton1Click, function()
                listening = true
                btn.Text = "..."
            end)
            connect(UserInputService.InputBegan, function(input, processed)
                if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                    key = input.KeyCode
                    btn.Text = key.Name
                    listening = false
                elseif not listening and not processed and input.KeyCode == key then
                    safeCall(o.Callback, key)
                end
            end)

            local obj = {}
            function obj:Get()
                return key
            end
            return obj
        end

        return Tab
    end

    return Window
end

return Library
