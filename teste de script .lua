--==============================================================
-- 🤖 ROBLOX AI ASSISTANT
-- OpenRouter Free
-- Mobile Friendly
--==============================================================
--
-- CONFIGURE SOMENTE:
--
-- API_KEY = "SUA_CHAVE_DO_OPENROUTER"
--
-- Endpoint:
-- https://openrouter.ai/api/v1/chat/completions
--
-- Modelo:
-- openrouter/free
--
--==============================================================

--// Services
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

--==============================================================
-- CONFIG
--==============================================================

local CONFIG = {
    API_URL = "https://openrouter.ai/api/v1/chat/completions",

    API_KEY = "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",

    MODEL = "openrouter/free",

    MAX_HISTORY = 30,

    SYSTEM_PROMPT = [[
Você é um assistente especializado em Roblox e Luau.

Ajude o usuário a criar, corrigir e explicar scripts Roblox.

Quando o usuário pedir código:
- forneça código Luau completo quando possível;
- use blocos ```lua;
- explique brevemente o que o código faz;
- não omita partes importantes;
- priorize compatibilidade com celular quando relevante.
]]
}

--==============================================================
-- STATE
--==============================================================

local ConversationHistory = {
    {
        role = "system",
        content = CONFIG.SYSTEM_PROMPT
    }
}

local Busy = false

--==============================================================
-- GUI ROOT
--==============================================================

local ScreenGui = Instance.new("ScreenGui")

ScreenGui.Name = "OpenRouterAIAssistant"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

--==============================================================
-- HELPERS
--==============================================================

local function New(class, properties)
    local obj = Instance.new(class)

    for property, value in pairs(properties or {}) do
        pcall(function()
            obj[property] = value
        end)
    end

    return obj
end

local function AddCorner(parent, radius)
    local corner = New("UICorner", {
        CornerRadius = UDim.new(0, radius)
    })

    corner.Parent = parent

    return corner
end

local function AddStroke(parent, color, thickness)
    local stroke = New("UIStroke", {
        Color = color,
        Thickness = thickness or 1
    })

    stroke.Parent = parent

    return stroke
end

local function AddPadding(parent, amount)
    local padding = New("UIPadding", {
        PaddingTop = UDim.new(0, amount),
        PaddingBottom = UDim.new(0, amount),
        PaddingLeft = UDim.new(0, amount),
        PaddingRight = UDim.new(0, amount)
    })

    padding.Parent = parent

    return padding
end

--==============================================================
-- COLORS
--==============================================================

local COLORS = {
    Background = Color3.fromRGB(13, 13, 15),
    Panel = Color3.fromRGB(20, 20, 23),
    Panel2 = Color3.fromRGB(27, 27, 31),

    User = Color3.fromRGB(32, 32, 37),
    AI = Color3.fromRGB(23, 26, 30),

    Code = Color3.fromRGB(9, 9, 11),

    Text = Color3.fromRGB(240, 240, 240),
    Muted = Color3.fromRGB(145, 145, 150),

    Accent = Color3.fromRGB(255, 115, 30),
    AccentDark = Color3.fromRGB(190, 70, 15),

    Error = Color3.fromRGB(210, 65, 65)
}

--==============================================================
-- MAIN
--==============================================================

local Main = New("Frame", {
    Name = "Main",

    Size = UDim2.new(0, 390, 0, 520),

    Position = UDim2.new(
        0.5,
        -195,
        0.5,
        -260
    ),

    BackgroundColor3 = COLORS.Background,

    BorderSizePixel = 0,

    Active = true
})

Main.Parent = ScreenGui

AddCorner(Main, 14)
AddStroke(Main, Color3.fromRGB(55, 55, 60), 1)

--==============================================================
-- TOP BAR
--==============================================================

local TopBar = New("Frame", {
    Size = UDim2.new(1, 0, 0, 50),

    BackgroundColor3 = COLORS.Panel,

    BorderSizePixel = 0
})

TopBar.Parent = Main

AddCorner(TopBar, 14)

local Title = New("TextLabel", {
    Size = UDim2.new(1, -100, 1, 0),

    Position = UDim2.new(0, 15, 0, 0),

    BackgroundTransparency = 1,

    Text = "🤖  AI Assistant",

    TextColor3 = COLORS.Text,

    TextSize = 16,

    Font = Enum.Font.GothamBold,

    TextXAlignment = Enum.TextXAlignment.Left
})

Title.Parent = TopBar

local Status = New("TextLabel", {
    Size = UDim2.new(1, -100, 0, 15),

    Position = UDim2.new(0, 16, 1, -17),

    BackgroundTransparency = 1,

    Text = "OpenRouter • Free",

    TextColor3 = COLORS.Muted,

    TextSize = 9,

    Font = Enum.Font.Gotham,

    TextXAlignment = Enum.TextXAlignment.Left
})

Status.Parent = TopBar

local MinimizeButton = New("TextButton", {
    Size = UDim2.new(0, 34, 0, 30),

    Position = UDim2.new(1, -75, 0.5, -15),

    BackgroundColor3 = COLORS.Panel2,

    Text = "−",

    TextColor3 = COLORS.Text,

    TextSize = 20,

    Font = Enum.Font.GothamBold,

    AutoButtonColor = false
})

MinimizeButton.Parent = TopBar

AddCorner(MinimizeButton, 8)

local CloseButton = New("TextButton", {
    Size = UDim2.new(0, 34, 0, 30),

    Position = UDim2.new(1, -38, 0.5, -15),

    BackgroundColor3 = COLORS.Panel2,

    Text = "×",

    TextColor3 = COLORS.Text,

    TextSize = 18,

    Font = Enum.Font.GothamBold,

    AutoButtonColor = false
})

CloseButton.Parent = TopBar

AddCorner(CloseButton, 8)

--==============================================================
-- CHAT
--==============================================================

local Chat = New("ScrollingFrame", {
    Name = "Chat",

    Size = UDim2.new(1, -16, 1, -128),

    Position = UDim2.new(0, 8, 0, 57),

    BackgroundTransparency = 1,

    BorderSizePixel = 0,

    ScrollBarThickness = 4,

    ScrollBarImageColor3 = COLORS.Accent,

    AutomaticCanvasSize = Enum.AutomaticSize.Y,

    CanvasSize = UDim2.new(0, 0, 0, 0),

    ScrollingDirection = Enum.ScrollingDirection.Y
})

Chat.Parent = Main

local ChatLayout = New("UIListLayout", {
    Padding = UDim.new(0, 8),

    SortOrder = Enum.SortOrder.LayoutOrder
})

ChatLayout.Parent = Chat

AddPadding(Chat, 5)

--==============================================================
-- INPUT
--==============================================================

local InputFrame = New("Frame", {
    Size = UDim2.new(1, -16, 0, 60),

    Position = UDim2.new(0, 8, 1, -68),

    BackgroundColor3 = COLORS.Panel,

    BorderSizePixel = 0
})

InputFrame.Parent = Main

AddCorner(InputFrame, 10)

local InputBox = New("TextBox", {
    Size = UDim2.new(1, -60, 1, -10),

    Position = UDim2.new(0, 8, 0, 5),

    BackgroundColor3 = COLORS.Panel2,

    BorderSizePixel = 0,

    Text = "",

    PlaceholderText = "Digite sua mensagem...",

    PlaceholderColor3 = COLORS.Muted,

    TextColor3 = COLORS.Text,

    TextSize = 14,

    Font = Enum.Font.Gotham,

    ClearTextOnFocus = false,

    MultiLine = true,

    TextWrapped = true,

    TextXAlignment = Enum.TextXAlignment.Left,

    TextYAlignment = Enum.TextYAlignment.Center
})

InputBox.Parent = InputFrame

AddCorner(InputBox, 8)
AddPadding(InputBox, 8)

local SendButton = New("TextButton", {
    Size = UDim2.new(0, 44, 0, 44),

    Position = UDim2.new(1, -51, 0.5, -22),

    BackgroundColor3 = COLORS.Accent,

    Text = "➤",

    TextColor3 = Color3.new(1, 1, 1),

    TextSize = 18,

    Font = Enum.Font.GothamBold,

    AutoButtonColor = false
})

SendButton.Parent = InputFrame

AddCorner(SendButton, 9)

--==============================================================
-- FLOATING BUTTON
--==============================================================

local FloatingButton = New("TextButton", {
    Size = UDim2.new(0, 58, 0, 58),

    Position = UDim2.new(0, 20, 0.5, -29),

    BackgroundColor3 = COLORS.Background,

    BorderSizePixel = 0,

    Text = "🤖",

    TextSize = 26,

    Visible = false,

    AutoButtonColor = false
})

FloatingButton.Parent = ScreenGui

AddCorner(FloatingButton, 18)
AddStroke(FloatingButton, COLORS.Accent, 2)

--==============================================================
-- DRAG
--==============================================================

local function MakeDraggable(object, handle)

    local dragging = false
    local dragStart
    local startPosition

    handle.InputBegan:Connect(function(input)

        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true

            dragStart = input.Position
            startPosition = object.Position

        end

    end)

    handle.InputEnded:Connect(function(input)

        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

            dragging = false

        end

    end)

    UserInputService.InputChanged:Connect(function(input)

        if not dragging then
            return
        end

        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart

        object.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,

            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )

    end)
end

MakeDraggable(Main, TopBar)
MakeDraggable(FloatingButton, FloatingButton)

--==============================================================
-- AUTO SCROLL
--==============================================================

local function ScrollToBottom()

    task.defer(function()

        task.wait()

        Chat.CanvasPosition = Vector2.new(
            0,
            math.max(
                0,
                Chat.AbsoluteCanvasSize.Y - Chat.AbsoluteSize.Y
            )
        )

    end)
end

--==============================================================
-- ADD MESSAGE
--==============================================================

local function AddMessage(role, text)

    local IsUser = role == "user"

    local Container = New("Frame", {
        Size = UDim2.new(1, -10, 0, 0),

        BackgroundColor3 =
            IsUser and COLORS.User or COLORS.AI,

        BorderSizePixel = 0,

        AutomaticSize = Enum.AutomaticSize.Y
    })

    Container.Parent = Chat

    AddCorner(Container, 9)
    AddPadding(Container, 9)

    local Header = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),

        BackgroundTransparency = 1,

        Text = IsUser and "👤  Você" or "🤖  IA",

        TextColor3 =
            IsUser and COLORS.Text or COLORS.Accent,

        TextSize = 12,

        Font = Enum.Font.GothamBold,

        TextXAlignment = Enum.TextXAlignment.Left
    })

    Header.Parent = Container

    local Body = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),

        Position = UDim2.new(0, 0, 0, 23),

        BackgroundTransparency = 1,

        Text = text,

        TextColor3 = COLORS.Text,

        TextSize = 13,

        Font = Enum.Font.Gotham,

        TextWrapped = true,

        TextXAlignment = Enum.TextXAlignment.Left,

        TextYAlignment = Enum.TextYAlignment.Top,

        AutomaticSize = Enum.AutomaticSize.Y
    })

    Body.Parent = Container

    ScrollToBottom()

    return Container
end

--==============================================================
-- CODE BLOCK
--==============================================================

local function AddCodeBlock(code)

    local Container = New("Frame", {
        Size = UDim2.new(1, -10, 0, 0),

        BackgroundColor3 = COLORS.Code,

        BorderSizePixel = 0,

        AutomaticSize = Enum.AutomaticSize.Y
    })

    Container.Parent = Chat

    AddCorner(Container, 9)
    AddPadding(Container, 8)

    local CodeBox = New("TextBox", {
        Size = UDim2.new(1, 0, 0, 0),

        BackgroundTransparency = 1,

        Text = code,

        TextColor3 = Color3.fromRGB(230, 230, 230),

        TextSize = 12,

        Font = Enum.Font.Code,

        TextWrapped = false,

        TextXAlignment = Enum.TextXAlignment.Left,

        TextYAlignment = Enum.TextYAlignment.Top,

        MultiLine = true,

        ClearTextOnFocus = false,

        TextEditable = false,

        AutomaticSize = Enum.AutomaticSize.Y
    })

    CodeBox.Parent = Container

    local ButtonFrame = New("Frame", {
        Size = UDim2.new(1, 0, 0, 36),

        BackgroundTransparency = 1
    })

    ButtonFrame.Parent = Container

    local CopyButton = New("TextButton", {
        Size = UDim2.new(0.5, -4, 1, 0),

        BackgroundColor3 = COLORS.Panel2,

        Text = "📋 Copiar",

        TextColor3 = COLORS.Text,

        TextSize = 12,

        Font = Enum.Font.GothamBold,

        AutoButtonColor = false
    })

    CopyButton.Parent = ButtonFrame

    AddCorner(CopyButton, 7)

    local ExecuteButton = New("TextButton", {
        Size = UDim2.new(0.5, -4, 1, 0),

        Position = UDim2.new(0.5, 4, 0, 0),

        BackgroundColor3 = COLORS.Accent,

        Text = "▶ Executar",

        TextColor3 = Color3.new(1, 1, 1),

        TextSize = 12,

        Font = Enum.Font.GothamBold,

        AutoButtonColor = false
    })

    ExecuteButton.Parent = ButtonFrame

    AddCorner(ExecuteButton, 7)

    -- COPY

    CopyButton.MouseButton1Click:Connect(function()

        local clipboard =
            setclipboard
            or toclipboard

        if clipboard then

            local success = pcall(function()
                clipboard(code)
            end)

            if success then

                CopyButton.Text = "✓ Copiado"

                task.delay(1.5, function()

                    if CopyButton.Parent then
                        CopyButton.Text = "📋 Copiar"
                    end

                end)

            end

        else

            CopyButton.Text = "⚠️ Indisponível"

            task.delay(1.5, function()

                if CopyButton.Parent then
                    CopyButton.Text = "📋 Copiar"
                end

            end)

        end

    end)

    -- EXECUTE

    ExecuteButton.MouseButton1Click:Connect(function()

        local compiler = loadstring

        if not compiler then

            ExecuteButton.Text = "⚠️ Indisponível"

            task.delay(1.5, function()

                if ExecuteButton.Parent then
                    ExecuteButton.Text = "▶ Executar"
                end

            end)

            return
        end

        local success, func = pcall(
            compiler,
            code
        )

        if not success or not func then

            ExecuteButton.Text = "⚠️ Erro"

            warn(
                "[AI Assistant] Compile error:",
                func
            )

            return
        end

        local ran, errorMessage = pcall(func)

        if ran then

            ExecuteButton.Text = "✓ Executado"

        else

            ExecuteButton.Text = "⚠️ Erro"

            warn(
                "[AI Assistant] Runtime error:",
                errorMessage
            )

        end

        task.delay(1.5, function()

            if ExecuteButton.Parent then
                ExecuteButton.Text = "▶ Executar"
            end

        end)

    end)

    ScrollToBottom()

    return Container
end

--==============================================================
-- PARSE RESPONSE
--==============================================================

local function DisplayAIResponse(response)

    local found = false

    local cursor = 1

    while true do

        local startPos, endPos, code =
            response:find(
                "```[%w_%-]*\n(.-)```",
                cursor
            )

        if not startPos then

            local remaining = response:sub(cursor)

            if remaining:gsub("%s+", "") ~= "" then
                AddMessage("assistant", remaining)
            end

            break
        end

        found = true

        local textBefore =
            response:sub(cursor, startPos - 1)

        if textBefore:gsub("%s+", "") ~= "" then
            AddMessage("assistant", textBefore)
        end

        AddCodeBlock(code)

        cursor = endPos + 1
    end

    if not found
    and response:gsub("%s+", "") ~= "" then

        AddMessage("assistant", response)

    end
end

--==============================================================
-- HTTP REQUEST
--==============================================================

local function RequestAI()

    if CONFIG.API_KEY == ""
    or CONFIG.API_KEY == "SUA_CHAVE_AQUI" then

        return false,
            "Configure sua API_KEY do OpenRouter."
    end

    local requestFunction =
        request
        or http_request

    if not requestFunction then

        return false,
            "Este ambiente não possui uma função HTTP compatível."
    end

    local Payload = {
        model = CONFIG.MODEL,

        messages = ConversationHistory,

        temperature = 0.7,

        max_tokens = 3000
    }

    local success, response = pcall(function()

        return requestFunction({

            Url = CONFIG.API_URL,

            Method = "POST",

            Headers = {
                ["Content-Type"] =
                    "application/json",

                ["Authorization"] =
                    "Bearer " .. CONFIG.API_KEY,

                ["HTTP-Referer"] =
                    "https://openrouter.ai/",

                ["X-Title"] =
                    "Roblox AI Assistant"
            },

            Body =
                HttpService:JSONEncode(Payload)
        })

    end)

    if not success then

        return false,
            tostring(response)

    end

    if not response then

        return false,
            "A API não retornou resposta."
    end

    if response.StatusCode
    and (
        response.StatusCode < 200
        or response.StatusCode >= 300
    ) then

        local body = response.Body or ""

        return false,
            "HTTP "
            .. tostring(response.StatusCode)
            .. "\n"
            .. body
    end

    local decodeSuccess, Data =
        pcall(function()

            return HttpService:JSONDecode(
                response.Body
            )

        end)

    if not decodeSuccess then

        return false,
            "A resposta recebida não é um JSON válido."
    end

    -- OpenRouter Chat Completions
    local Answer =
        Data
        and Data.choices
        and Data.choices[1]
        and Data.choices[1].message
        and Data.choices[1].message.content

    if not Answer then

        if Data.error then

            local message =
                Data.error.message
                or Data.error.code
                or "Erro desconhecido."

            return false,
                tostring(message)

        end

        return false,
            "A API respondeu, mas não encontramos o texto da IA."
    end

    return true, Answer
end

--==============================================================
-- LOADING
--==============================================================

local function AddLoading()

    return AddMessage(
        "assistant",
        "⏳ Pensando..."
    )
end

--==============================================================
-- SEND
--==============================================================

local function SendMessage()

    if Busy then
        return
    end

    local Message = InputBox.Text

    if not Message
    or Message:gsub("%s+", "") == "" then

        return
    end

    InputBox.Text = ""

    AddMessage(
        "user",
        Message
    )

    table.insert(
        ConversationHistory,
        {
            role = "user",
            content = Message
        }
    )

    -- Mantém system + últimas mensagens
    while #ConversationHistory > CONFIG.MAX_HISTORY + 1 do

        table.remove(
            ConversationHistory,
            2
        )

    end

    Busy = true

    SendButton.Text = "..."

    local Loading = AddLoading()

    task.spawn(function()

        local success, result =
            RequestAI()

        if Loading then
            Loading:Destroy()
        end

        if success then

            table.insert(
                ConversationHistory,
                {
                    role = "assistant",
                    content = result
                }
            )

            while #ConversationHistory > CONFIG.MAX_HISTORY + 1 do

                table.remove(
                    ConversationHistory,
                    2
                )

            end

            DisplayAIResponse(result)

        else

            AddMessage(
                "assistant",
                "❌ Erro\n\n"
                .. tostring(result)
            )

        end

        Busy = false

        SendButton.Text = "➤"

    end)
end

--==============================================================
-- CLEAR CHAT
--==============================================================

local function ClearChat()

    ConversationHistory = {
        {
            role = "system",
            content = CONFIG.SYSTEM_PROMPT
        }
    }

    for _, child in ipairs(Chat:GetChildren()) do

        if not child:IsA("UIListLayout")
        and not child:IsA("UIPadding") then

            child:Destroy()

        end

    end

    AddMessage(
        "assistant",
        "🧹 Histórico apagado.\nPode começar uma nova conversa."
    )
end

--==============================================================
-- MINIMIZE
--==============================================================

MinimizeButton.MouseButton1Click:Connect(function()

    Main.Visible = false

    FloatingButton.Visible = true

end)

FloatingButton.MouseButton1Click:Connect(function()

    FloatingButton.Visible = false

    Main.Visible = true

end)

--==============================================================
-- CLOSE
--==============================================================

CloseButton.MouseButton1Click:Connect(function()

    ScreenGui.Enabled = false

end)

--==============================================================
-- SEND EVENTS
--==============================================================

SendButton.MouseButton1Click:Connect(
    SendMessage
)

InputBox.FocusLost:Connect(function(enterPressed)

    if enterPressed then
        SendMessage()
    end

end)

--==============================================================
-- DOUBLE CLICK TITLE = CLEAR
--==============================================================

local LastClick = 0

Title.InputBegan:Connect(function(input)

    if input.UserInputType ~= Enum.UserInputType.MouseButton1
    and input.UserInputType ~= Enum.UserInputType.Touch then

        return
    end

    local now = tick()

    if now - LastClick < 0.35 then
        ClearChat()
    end

    LastClick = now

end)

--==============================================================
-- WELCOME
--==============================================================

AddMessage(
    "assistant",
    "Olá! 🤖\n\n"
    .. "Sou seu AI Assistant para Roblox.\n\n"
    .. "Pode pedir scripts, correções, explicações ou ideias. "
    .. "Quando eu enviar código, ele aparecerá em um bloco separado "
    .. "com os botões 📋 Copiar e ▶ Executar."
)

print("====================================")
print("🤖 AI Assistant carregado")
print("Provider: OpenRouter")
print("Model: " .. CONFIG.MODEL)
print("====================================")