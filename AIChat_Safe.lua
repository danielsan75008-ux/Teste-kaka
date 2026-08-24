--[[
    AIChat - Safe/Analysis Edition
    Baseado no prompt enviado pelo usuário e no catálogo Icons.lua.

    Importante:
    - Não executa código recebido da IA ou do RScripts.
    - Permite copiar código quando setclipboard estiver disponível.
    - A integração RScripts usa somente endpoints documentados.
    - Nenhuma IA, modelo ou API key é configurada por padrão.
    - A persistência usa apenas APIs reais quando disponíveis.

    Ícones usados do Icons.lua:
    bot, settings/cog, search, copy, x, chevron-down, minimize-2,
    maximize-2, refresh-cw, code, alert-circle.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local THEME = {
    Accent = Color3.fromRGB(255, 132, 0),
    Background = Color3.fromRGB(16, 16, 18),
    Surface = Color3.fromRGB(23, 23, 26),
    Surface2 = Color3.fromRGB(29, 29, 33),
    Text = Color3.fromRGB(245, 245, 245),
    Muted = Color3.fromRGB(165, 165, 170),
    Border = Color3.fromRGB(70, 48, 30),
}

local ICONS = {
    bot = "rbxassetid://80451686744860",
    cog = "rbxassetid://116544501716299",
    search = "rbxassetid://97780235974933",
    copy = "rbxassetid://78979572434545",
    x = "rbxassetid://76821953846248",
    ["chevron-down"] = "rbxassetid://134243273101015",
    code = "rbxassetid://107380207681249",
    alert = "rbxassetid://83898160590116",
    refresh = "rbxassetid://78082218499697",
}

local RSCRIPTS_BASE = "https://api.rscripts.net"

local State = {
    Profiles = {},
    ActiveProfile = nil,
    Models = {},
    Favorites = {},
    CustomModels = {},
    SystemPrompt = "",
    RScriptsKey = "",
    Theme = {
        Accent = THEME.Accent,
        Transparency = 0.08,
        Scale = 1,
        FontSize = 14,
        Corner = 6,
        Animations = true,
    },
    Chat = {},
    CurrentTab = "Chat",
    Minimized = false,
    LastSize = UDim2.fromOffset(520, 420),
    Http = nil,
}

-- -------------------------------------------------------------------------
-- HTTP
-- -------------------------------------------------------------------------

local function getRequestFunction()
    local candidates = {
        (syn and syn.request),
        (http and http.request),
        (fluxus and fluxus.request),
        request,
        http_request,
    }

    for _, fn in ipairs(candidates) do
        if type(fn) == "function" then
            return fn
        end
    end
    return nil
end

State.Http = getRequestFunction()

local function requestAsync(options)
    if not State.Http then
        return false, "HTTP não disponível neste ambiente."
    end

    local ok, result = pcall(State.Http, options)
    if not ok then
        return false, tostring(result)
    end

    if type(result) ~= "table" then
        return false, "Resposta HTTP inválida."
    end

    local status = tonumber(result.StatusCode or result.Status or 0)
    local body = result.Body or result.body or ""

    if status < 200 or status >= 300 then
        return false, ("HTTP %d"):format(status), status, body
    end

    return true, body, status
end

local function jsonDecode(body)
    local ok, value = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not ok then
        return nil, "JSON inválido."
    end
    return value
end

local function jsonEncode(value)
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(value)
    end)
    if not ok then
        return nil
    end
    return encoded
end

-- -------------------------------------------------------------------------
-- Storage: somente APIs existentes no ambiente
-- -------------------------------------------------------------------------

local function storageAvailable()
    return type(isfile) == "function"
        and type(readfile) == "function"
        and type(writefile) == "function"
end

local CONFIG_FILE = "AIChat/config.json"

local function saveConfig()
    if not storageAvailable() then
        return false, "Persistência não disponível neste ambiente."
    end

    if type(makefolder) == "function" then
        pcall(makefolder, "AIChat")
    end

    local payload = {
        Profiles = State.Profiles,
        Models = State.Models,
        Favorites = State.Favorites,
        CustomModels = State.CustomModels,
        SystemPrompt = State.SystemPrompt,
        RScriptsKey = State.RScriptsKey,
        Theme = State.Theme,
        ActiveProfile = State.ActiveProfile,
    }

    local encoded = jsonEncode(payload)
    if not encoded then
        return false, "Não foi possível serializar a configuração."
    end

    local ok, err = pcall(writefile, CONFIG_FILE, encoded)
    if not ok then
        return false, tostring(err)
    end

    return true
end

local function loadConfig()
    if not storageAvailable() then
        return false
    end
    if not isfile(CONFIG_FILE) then
        return false
    end

    local ok, body = pcall(readfile, CONFIG_FILE)
    if not ok then
        return false
    end

    local data = jsonDecode(body)
    if type(data) ~= "table" then
        return false
    end

    for _, key in ipairs({
        "Profiles", "Models", "Favorites", "CustomModels",
        "SystemPrompt", "RScriptsKey", "Theme", "ActiveProfile"
    }) do
        if data[key] ~= nil then
            State[key] = data[key]
        end
    end

    return true
end

loadConfig()

-- -------------------------------------------------------------------------
-- GUI helpers
-- -------------------------------------------------------------------------

local Gui = Instance.new("ScreenGui")
Gui.Name = "AIChat"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Name = "AIChat"
Main.Size = State.LastSize
Main.Position = UDim2.new(0.5, -260, 0.5, -210)
Main.BackgroundColor3 = THEME.Background
Main.BackgroundTransparency = State.Theme.Transparency
Main.BorderSizePixel = 0
Main.Parent = Gui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, State.Theme.Corner)
MainCorner.Parent = Main

local Stroke = Instance.new("UIStroke")
Stroke.Color = State.Theme.Accent
Stroke.Thickness = 1
Stroke.Transparency = 0.15
Stroke.Parent = Main

local function label(parent, text, size, pos, fontSize, color)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or THEME.Text
    l.TextSize = fontSize or State.Theme.FontSize
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Size = size
    l.Position = pos
    l.Parent = parent
    return l
end

local function button(parent, text, size, pos, callback)
    local b = Instance.new("TextButton")
    b.AutoButtonColor = false
    b.BackgroundColor3 = THEME.Surface2
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = THEME.Text
    b.TextSize = State.Theme.FontSize
    b.Font = Enum.Font.GothamMedium
    b.Size = size
    b.Position = pos
    b.Parent = parent

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = b

    local s = Instance.new("UIStroke")
    s.Color = THEME.Border
    s.Thickness = 1
    s.Parent = b

    b.MouseEnter:Connect(function()
        b.BackgroundColor3 = THEME.Accent
    end)

    b.MouseLeave:Connect(function()
        b.BackgroundColor3 = THEME.Surface2
    end)

    b.Activated:Connect(callback)
    return b
end

local function textBox(parent, placeholder, size, pos, multiline)
    local t = Instance.new("TextBox")
    t.BackgroundColor3 = THEME.Surface
    t.BorderSizePixel = 0
    t.TextColor3 = THEME.Text
    t.PlaceholderColor3 = THEME.Muted
    t.PlaceholderText = placeholder
    t.Text = ""
    t.TextSize = State.Theme.FontSize
    t.Font = Enum.Font.Gotham
    t.ClearTextOnFocus = false
    t.MultiLine = multiline == true
    t.TextWrapped = multiline == true
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
    t.Size = size
    t.Position = pos
    t.Parent = parent

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = t

    local s = Instance.new("UIStroke")
    s.Color = THEME.Border
    s.Thickness = 1
    s.Parent = t

    return t
end

local function iconButton(parent, icon, size, pos, callback)
    local b = button(parent, "", size, pos, callback)
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.Image = ICONS[icon] or ""
    img.Size = UDim2.fromOffset(16, 16)
    img.Position = UDim2.new(0.5, -8, 0.5, -8)
    img.Parent = b
    return b
end

-- -------------------------------------------------------------------------
-- TopBar / tabs
-- -------------------------------------------------------------------------

local TopBar = Instance.new("Frame")
TopBar.BackgroundTransparency = 1
TopBar.Size = UDim2.new(1, -16, 0, 36)
TopBar.Position = UDim2.fromOffset(8, 6)
TopBar.Parent = Main

local Title = label(TopBar, "AIChat", UDim2.new(1, -100, 1, 0), UDim2.fromOffset(8, 0), 16)
Title.Font = Enum.Font.GothamBold

local MinButton = iconButton(TopBar, "chevron-down", UDim2.fromOffset(28, 28), UDim2.new(1, -62, 0, 2), function() end)
local CloseButton = iconButton(TopBar, "x", UDim2.fromOffset(28, 28), UDim2.new(1, -30, 0, 2), function()
    Gui:Destroy()
end)

local TabBar = Instance.new("Frame")
TabBar.BackgroundTransparency = 1
TabBar.Size = UDim2.new(1, -16, 0, 34)
TabBar.Position = UDim2.fromOffset(8, 44)
TabBar.Parent = Main

local Content = Instance.new("Frame")
Content.BackgroundTransparency = 1
Content.Size = UDim2.new(1, -16, 1, -86)
Content.Position = UDim2.fromOffset(8, 80)
Content.Parent = Main

local Pages = {}

local function createPage(name)
    local p = Instance.new("Frame")
    p.Name = name
    p.BackgroundTransparency = 1
    p.Size = UDim2.fromScale(1, 1)
    p.Visible = false
    p.Parent = Content
    Pages[name] = p
    return p
end

local function switchTab(name)
    State.CurrentTab = name
    for n, page in pairs(Pages) do
        page.Visible = n == name
    end
end

for i, name in ipairs({"Chat", "RScripts", "Configurações"}) do
    local b = button(TabBar, name, UDim2.new(1/3, -5, 1, 0), UDim2.new((i-1)/3, (i-1)*5, 0, 0), function()
        switchTab(name)
    end)
    if name == "Chat" then
        b.BackgroundColor3 = THEME.Accent
    end
end

-- -------------------------------------------------------------------------
-- CHAT
-- -------------------------------------------------------------------------

local ChatPage = createPage("Chat")

local ProfileLabel = label(ChatPage, "IA", UDim2.fromOffset(35, 28), UDim2.fromOffset(4, 0), 13, THEME.Muted)
local ProfileBox = button(ChatPage, "Nenhum perfil", UDim2.new(1, -48, 0, 28), UDim2.fromOffset(44, 0), function() end)

local History = Instance.new("ScrollingFrame")
History.BackgroundColor3 = THEME.Surface
History.BorderSizePixel = 0
History.Size = UDim2.new(1, 0, 1, -100)
History.Position = UDim2.fromOffset(0, 36)
History.ScrollBarThickness = 4
History.AutomaticCanvasSize = Enum.AutomaticSize.Y
History.CanvasSize = UDim2.new()
History.Parent = ChatPage

local HistoryLayout = Instance.new("UIListLayout")
HistoryLayout.Padding = UDim.new(0, 6)
HistoryLayout.Parent = History

local Input = textBox(ChatPage, "Digite uma mensagem...", UDim2.new(1, -112, 0, 58), UDim2.new(0, 0, 1, -58), true)
local Send = button(ChatPage, "Enviar", UDim2.fromOffset(100, 58), UDim2.new(1, -100, 1, -58), function() end)

local Status = label(ChatPage, "Status: pronto", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 1), 11, THEME.Muted)
Status.TextTransparency = 1

local function addMessage(role, text)
    table.insert(State.Chat, {role = role, content = text})

    local card = Instance.new("Frame")
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Size = UDim2.new(1, -12, 0, 0)
    card.BackgroundColor3 = role == "user" and THEME.Surface2 or THEME.Background
    card.BorderSizePixel = 0
    card.Parent = History

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.Parent = card

    local who = role == "user" and "Você" or "IA"
    label(card, who, UDim2.new(1, 0, 0, 18), UDim2.new(), 12, THEME.Accent)

    local body = label(card, text, UDim2.new(1, 0, 0, 0), UDim2.fromOffset(0, 20), 13)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.TextWrapped = true
end

local function getActiveProfile()
    if not State.ActiveProfile then
        return nil
    end
    return State.Profiles[State.ActiveProfile]
end

local function aiError(message)
    Status.Text = "Status: " .. message
    Status.TextTransparency = 0
    addMessage("assistant", message)
end

local function sendToAI(userText)
    local profile = getActiveProfile()

    if not profile then
        aiError("Configure a IA que você vai usar nas configurações.")
        return
    end

    if type(profile.API_URL) ~= "string" or profile.API_URL == "" then
        aiError("API URL inválida.")
        return
    end

    if type(profile.API_KEY) ~= "string" or profile.API_KEY == "" then
        aiError("API Key inválida.")
        return
    end

    if type(profile.MODEL) ~= "string" or profile.MODEL == "" then
        aiError("Selecione um modelo nas configurações.")
        return
    end

    local messages = {}
    if State.SystemPrompt ~= "" then
        table.insert(messages, {
            role = "system",
            content = State.SystemPrompt,
        })
    end

    for _, item in ipairs(State.Chat) do
        if item.role == "user" or item.role == "assistant" then
            table.insert(messages, {
                role = item.role,
                content = item.content,
            })
        end
    end

    table.insert(messages, {
        role = "user",
        content = userText,
    })

    local payload = jsonEncode({
        model = profile.MODEL,
        messages = messages,
    })

    if not payload then
        aiError("Não foi possível preparar a requisição.")
        return
    end

    Send.Active = false
    Send.Text = "Enviando..."
    Status.Text = "Status: enviando"
    Status.TextTransparency = 0

    task.spawn(function()
        local ok, body, code = requestAsync({
            Url = profile.API_URL,
            Method = "POST",
            Headers = {
                ["Authorization"] = "Bearer " .. profile.API_KEY,
                ["Content-Type"] = "application/json",
            },
            Body = payload,
        })

        if not ok then
            local message = "Erro de conexão."
            if code == 401 then message = "API Key inválida."
            elseif code == 403 then message = "Acesso negado."
            elseif code == 404 then message = "API URL ou modelo não encontrado."
            elseif code == 429 then message = "Limite de requisições atingido."
            elseif code == 503 then message = "HTTP indisponível no serviço."
            elseif body and body ~= "" then message = body end
            aiError(message)
        else
            local data = jsonDecode(body)
            local content = data
                and data.choices
                and data.choices[1]
                and data.choices[1].message
                and data.choices[1].message.content

            if type(content) ~= "string" or content == "" then
                aiError("Resposta sem choices/message/content.")
            else
                addMessage("assistant", content)
                Status.Text = "Status: pronto"
            end
        end

        Send.Active = true
        Send.Text = "Enviar"
    end)
end

Send.Activated:Connect(function()
    local text = Input.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        return
    end

    Input.Text = ""
    addMessage("user", text)
    sendToAI(text)
end)

-- -------------------------------------------------------------------------
-- RSCRIPTS
-- -------------------------------------------------------------------------

local ScriptsPage = createPage("RScripts")

local SearchInput = textBox(ScriptsPage, "Pesquisar scripts...", UDim2.new(1, -100, 0, 32), UDim2.fromOffset(0, 0))
local SearchButton = button(ScriptsPage, "Pesquisar", UDim2.fromOffset(92, 32), UDim2.new(1, -92, 0, 0), function() end)

local CurrentGame = button(ScriptsPage, "Jogo atual", UDim2.fromOffset(100, 30), UDim2.fromOffset(0, 38), function() end)
local Easier = button(ScriptsPage, "Mais fáceis", UDim2.fromOffset(105, 30), UDim2.fromOffset(108, 38), function() end)

local PlaceLabel = label(
    ScriptsPage,
    "PlaceId: " .. tostring(game.PlaceId),
    UDim2.new(1, -220, 0, 30),
    UDim2.fromOffset(220, 38),
    12,
    THEME.Muted
)

local Results = Instance.new("ScrollingFrame")
Results.BackgroundColor3 = THEME.Surface
Results.BorderSizePixel = 0
Results.Size = UDim2.new(1, 0, 1, -104)
Results.Position = UDim2.fromOffset(0, 72)
Results.ScrollBarThickness = 4
Results.AutomaticCanvasSize = Enum.AutomaticSize.Y
Results.CanvasSize = UDim2.new()
Results.Parent = ScriptsPage

local ResultsLayout = Instance.new("UIListLayout")
ResultsLayout.Padding = UDim.new(0, 6)
ResultsLayout.Parent = Results

local function clearResults()
    for _, child in ipairs(Results:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

local function setClipboard(text)
    if type(setclipboard) == "function" then
        local ok = pcall(setclipboard, text)
        return ok
    end
    return false
end

local function rscriptsRequest(path)
    if State.RScriptsKey == "" then
        return false, "Configure a RScripts API Key nas configurações."
    end

    local ok, body, code = requestAsync({
        Url = RSCRIPTS_BASE .. path,
        Method = "GET",
        Headers = {
            ["Authorization"] = "Bearer " .. State.RScriptsKey,
        },
    })

    if not ok then
        if code == 401 then
            return false, "RScripts API Key inválida."
        elseif code == 429 then
            return false, "Limite de requisições do RScripts atingido."
        end
        return false, body or "Falha ao consultar o RScripts."
    end

    local data = jsonDecode(body)
    if not data or data.success == false then
        return false, (data and data.error and data.error.message) or "Resposta inválida do RScripts."
    end

    return true, data
end

local function createScriptCard(item)
    local card = Instance.new("Frame")
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Size = UDim2.new(1, -10, 0, 0)
    card.BackgroundColor3 = THEME.Surface2
    card.BorderSizePixel = 0
    card.Parent = Results

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = card

    label(card, tostring(item.title or "Sem título"), UDim2.new(1, -10, 0, 22), UDim2.fromOffset(0, 0), 14, THEME.Text)

    local meta = ("Slug: %s | Likes: %s | Views: %s"):format(
        tostring(item.slug or "?"),
        tostring(item.likes or 0),
        tostring(item.views or 0)
    )
    label(card, meta, UDim2.new(1, -10, 0, 18), UDim2.fromOffset(0, 23), 11, THEME.Muted)

    local risk = item.risk
    local riskText = risk and ("Risco: %s (%s)"):format(tostring(risk.score or "?"), tostring(risk.level or "Unknown")) or "Risco: Unknown"
    label(card, riskText, UDim2.new(1, -10, 0, 18), UDim2.fromOffset(0, 42), 11, THEME.Muted)

    local desc = label(card, tostring(item.description or ""), UDim2.new(1, -10, 0, 0), UDim2.fromOffset(0, 62), 12, THEME.Text)
    desc.AutomaticSize = Enum.AutomaticSize.Y
    desc.TextWrapped = true

    local y = 88
    local copy = button(card, "Copiar", UDim2.fromOffset(82, 28), UDim2.fromOffset(0, y), function()
        if not item.slug then return end
        task.spawn(function()
            local ok, data = rscriptsRequest("/v1/scripts/" .. HttpService:UrlEncode(item.slug))
            if not ok then
                Status.Text = "Status: " .. tostring(data)
                Status.TextTransparency = 0
                return
            end

            local source = data.data and data.data.script
            if type(source) ~= "string" or source == "" then
                Status.Text = "Status: código não disponível."
                Status.TextTransparency = 0
                return
            end

            if not setClipboard(source) then
                Status.Text = "Status: setclipboard não está disponível neste ambiente."
            else
                Status.Text = "Status: código copiado."
            end
            Status.TextTransparency = 0
        end)
    end)

    local analyze = button(card, "Enviar à IA", UDim2.fromOffset(100, 28), UDim2.fromOffset(88, y), function()
        if not getActiveProfile() then
            aiError("Configure a IA que você vai usar nas configurações.")
            switchTab("Chat")
            return
        end

        task.spawn(function()
            local ok, data = rscriptsRequest("/v1/scripts/" .. HttpService:UrlEncode(item.slug or ""))
            if not ok then
                Status.Text = "Status: " .. tostring(data)
                Status.TextTransparency = 0
                return
            end

            local source = data.data and data.data.script
            if type(source) ~= "string" then
                aiError("O script não possui código disponível para análise.")
                switchTab("Chat")
                return
            end

            local prompt = "Analise este script do RScripts. Explique o que ele faz, identifique riscos e descreva as partes importantes. Não execute nada automaticamente:\n\n" .. source
            switchTab("Chat")
            Input.Text = prompt
        end)
    end)

    local safeNote = label(
        card,
        "Nenhum código é executado automaticamente.",
        UDim2.new(1, -10, 0, 18),
        UDim2.fromOffset(194, y + 5),
        10,
        THEME.Muted
    )

    return card
end

local function queryScripts(path)
    clearResults()
    local ok, data = rscriptsRequest(path)
    if not ok then
        local err = label(Results, tostring(data), UDim2.new(1, -12, 0, 50), UDim2.fromOffset(6, 6), 12, THEME.Muted)
        err.TextWrapped = true
        return
    end

    local list = data.data
    if type(list) ~= "table" then
        list = data.data and data.data.scripts or {}
    end

    if #list == 0 then
        label(Results, "Nenhum resultado.", UDim2.new(1, -12, 0, 40), UDim2.fromOffset(6, 6), 12, THEME.Muted)
        return
    end

    for _, item in ipairs(list) do
        createScriptCard(item)
    end
end

SearchButton.Activated:Connect(function()
    local q = SearchInput.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if q == "" then return end
    queryScripts("/v1/search?q=" .. HttpService:UrlEncode(q) .. "&index=scripts&limit=20")
end)

CurrentGame.Activated:Connect(function()
    PlaceLabel.Text = "PlaceId: " .. tostring(game.PlaceId)
    queryScripts("/v1/scripts?placeId=" .. tostring(game.PlaceId) .. "&limit=20")
end)

Easier.Activated:Connect(function()
    PlaceLabel.Text = "PlaceId: " .. tostring(game.PlaceId)
    queryScripts("/v1/scripts?placeId=" .. tostring(game.PlaceId) .. "&noKeySystem=true&freeOnly=true&sort=most-likes&limit=20")
end)

label(ScriptsPage, "Powered by Rscripts.net", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 1, -22), 10, THEME.Muted)

-- -------------------------------------------------------------------------
-- SETTINGS
-- -------------------------------------------------------------------------

local SettingsPage = createPage("Configurações")

local SettingsScroll = Instance.new("ScrollingFrame")
SettingsScroll.BackgroundTransparency = 1
SettingsScroll.Size = UDim2.fromScale(1, 1)
SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, 760)
SettingsScroll.ScrollBarThickness = 4
SettingsScroll.Parent = SettingsPage

local function settingLabel(text, y)
    return label(SettingsScroll, text, UDim2.new(1, -16, 0, 22), UDim2.fromOffset(6, y), 12, THEME.Muted)
end

settingLabel("Perfis de IA", 8)
local ProfileName = textBox(SettingsScroll, "Nome do perfil", UDim2.new(1, -120, 0, 30), UDim2.fromOffset(6, 34))
local AddProfile = button(SettingsScroll, "Criar", UDim2.fromOffset(96, 30), UDim2.new(1, -102, 0, 34), function() end)

local Provider = textBox(SettingsScroll, "Provedor (ex.: OpenAI, Gemini, DeepSeek...)", UDim2.new(1, -12, 0, 30), UDim2.fromOffset(6, 70))
local APIURL = textBox(SettingsScroll, "API URL", UDim2.new(1, -12, 0, 30), UDim2.fromOffset(6, 106))
local APIKey = textBox(SettingsScroll, "API Key", UDim2.new(1, -12, 0, 30), UDim2.fromOffset(6, 142))
APIKey.TextEditable = true

local Model = textBox(SettingsScroll, "Model ID — nenhum modelo é selecionado por padrão", UDim2.new(1, -12, 0, 30), UDim2.fromOffset(6, 178))
local SaveProfile = button(SettingsScroll, "Salvar perfil", UDim2.fromOffset(120, 30), UDim2.fromOffset(6, 214), function() end)
local DeleteProfile = button(SettingsScroll, "Excluir perfil", UDim2.fromOffset(120, 30), UDim2.fromOffset(132, 214), function() end)

settingLabel("Catálogo de modelos", 254)
local ModelSearch = textBox(SettingsScroll, "Pesquisar modelo...", UDim2.new(1, -120, 0, 30), UDim2.fromOffset(6, 280))
local RefreshModels = button(SettingsScroll, "Atualizar", UDim2.fromOffset(100, 30), UDim2.new(1, -106, 0, 280), function() end)

local AddCustomModel = button(SettingsScroll, "+ Modelo personalizado", UDim2.new(1, -12, 0, 30), UDim2.fromOffset(6, 316), function() end)

settingLabel("System Prompt", 354)
local SystemPrompt = textBox(SettingsScroll, "System Prompt (opcional)", UDim2.new(1, -12, 0, 90), UDim2.fromOffset(6, 380), true)

settingLabel("RScripts", 478)
local RSKey = textBox(SettingsScroll, "RScripts API Key", UDim2.new(1, -12, 0, 30), UDim2.fromOffset(6, 504))
local SaveSettings = button(SettingsScroll, "Salvar configurações", UDim2.fromOffset(160, 30), UDim2.fromOffset(6, 540), function() end)

local Warning = label(
    SettingsScroll,
    "API Keys colocadas em um script local podem ser extraídas pelo ambiente de execução. Não compartilhe suas chaves.",
    UDim2.new(1, -12, 0, 52),
    UDim2.fromOffset(6, 580),
    11,
    THEME.Muted
)
Warning.TextWrapped = true

local SessionInfo = label(
    SettingsScroll,
    storageAvailable() and "Persistência: disponível" or "Persistência: não disponível; configurações ficam apenas nesta sessão.",
    UDim2.new(1, -12, 0, 22),
    UDim2.fromOffset(6, 640),
    11,
    THEME.Muted
)

local function refreshProfileBox()
    if State.ActiveProfile and State.Profiles[State.ActiveProfile] then
        ProfileBox.Text = State.Profiles[State.ActiveProfile].Name or State.ActiveProfile
    else
        ProfileBox.Text = "Nenhum perfil"
    end
end

local function saveProfileFromFields()
    local name = ProfileName.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        return
    end

    State.Profiles[name] = {
        Name = name,
        Provider = Provider.Text,
        API_URL = APIURL.Text,
        API_KEY = APIKey.Text,
        MODEL = Model.Text,
    }

    State.ActiveProfile = name
    saveConfig()
    refreshProfileBox()
end

AddProfile.Activated:Connect(function()
    saveProfileFromFields()
end)

SaveProfile.Activated:Connect(function()
    saveProfileFromFields()
end)

DeleteProfile.Activated:Connect(function()
    local name = ProfileName.Text
    if State.Profiles[name] then
        State.Profiles[name] = nil
        if State.ActiveProfile == name then
            State.ActiveProfile = nil
        end
        saveConfig()
        refreshProfileBox()
    end
end)

SaveSettings.Activated:Connect(function()
    State.SystemPrompt = SystemPrompt.Text
    State.RScriptsKey = RSKey.Text
    saveConfig()
    SessionInfo.Text = storageAvailable()
        and "Persistência: configuração salva."
        or "Persistência não disponível; configuração mantida apenas nesta sessão."
end)

RefreshModels.Activated:Connect(function()
    -- Não existe um endpoint universal para todos os provedores.
    -- O perfil/API URL continua sendo a fonte de verdade.
    SessionInfo.Text = "Catálogo: use o endpoint oficial de modelos do provedor quando ele existir."
end)

SystemPrompt.Text = State.SystemPrompt or ""
RSKey.Text = State.RScriptsKey or ""
refreshProfileBox()

-- -------------------------------------------------------------------------
-- Dropdown simples de perfil no Chat
-- -------------------------------------------------------------------------

local ProfileDropdown = nil

ProfileBox.Activated:Connect(function()
    if ProfileDropdown then
        ProfileDropdown:Destroy()
        ProfileDropdown = nil
        return
    end

    ProfileDropdown = Instance.new("Frame")
    ProfileDropdown.BackgroundColor3 = THEME.Surface2
    ProfileDropdown.BorderSizePixel = 0
    ProfileDropdown.Size = UDim2.fromOffset(240, math.min(180, math.max(40, #State.Profiles * 34)))
    ProfileDropdown.Position = UDim2.fromOffset(44, 30)
    ProfileDropdown.ZIndex = 50
    ProfileDropdown.Parent = ProfileBox.Parent

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 2)
    layout.Parent = ProfileDropdown

    for name, profile in pairs(State.Profiles) do
        local b = button(ProfileDropdown, profile.Name or name, UDim2.new(1, 0, 0, 30), UDim2.new(), function()
            State.ActiveProfile = name
            refreshProfileBox()
            ProfileDropdown:Destroy()
            ProfileDropdown = nil
            saveConfig()
        end)
        b.ZIndex = 51
    end
end)

-- -------------------------------------------------------------------------
-- Drag
-- -------------------------------------------------------------------------

local dragging = false
local dragStart
local startPos

TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local delta = input.Position - dragStart
    Main.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end)

-- -------------------------------------------------------------------------
-- Resize
-- -------------------------------------------------------------------------

local ResizeHandle = Instance.new("TextButton")
ResizeHandle.BackgroundTransparency = 1
ResizeHandle.Text = ""
ResizeHandle.Size = UDim2.fromOffset(18, 18)
ResizeHandle.AnchorPoint = Vector2.new(1, 1)
ResizeHandle.Position = UDim2.fromScale(1, 1)
ResizeHandle.Parent = Main

local resizing = false
local resizeStart
local resizeSize

ResizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        resizeStart = input.Position
        resizeSize = Main.AbsoluteSize
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                resizing = false
                State.LastSize = Main.Size
                saveConfig()
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not resizing then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local delta = input.Position - resizeStart
    local width = math.max(360, resizeSize.X + delta.X)
    local height = math.max(300, resizeSize.Y + delta.Y)
    Main.Size = UDim2.fromOffset(width, height)
end)

-- -------------------------------------------------------------------------
-- Minimize
-- -------------------------------------------------------------------------

local minimizedSize = UDim2.fromOffset(520, 48)

MinButton.Activated:Connect(function()
    if not State.Minimized then
        State.LastSize = Main.Size
        State.Minimized = true

        for _, child in ipairs(Main:GetChildren()) do
            if child ~= TopBar and child ~= MainCorner and child ~= Stroke and child ~= ResizeHandle then
                if child:IsA("GuiObject") then
                    child.Visible = false
                end
            end
        end

        Main.Size = minimizedSize
        MinButton:FindFirstChildOfClass("ImageLabel").Image = ICONS["chevron-down"]
    else
        State.Minimized = false
        Main.Size = State.LastSize

        for _, child in ipairs(Main:GetChildren()) do
            if child ~= TopBar and child ~= MainCorner and child ~= Stroke and child ~= ResizeHandle then
                if child:IsA("GuiObject") then
                    child.Visible = true
                end
            end
        end

        switchTab(State.CurrentTab)
    end
end)

-- -------------------------------------------------------------------------
-- Inicialização
-- -------------------------------------------------------------------------

switchTab("Chat")

-- Nenhuma requisição de rede é feita na inicialização.
-- Nenhum perfil, modelo ou IA é selecionado automaticamente.
