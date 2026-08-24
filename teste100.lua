--[[
    AIChat
    Configuração simplificada:

    [TextBox] Nome do player
    [SelectBox] Empresa da IA
    [SelectBox] Modelo da IA
    [TextBox] API Key

    URL e configurações técnicas são automáticas.
    Nenhum script encontrado no RScripts é executado automaticamente.
]]

-- =========================================================
-- SERVIÇOS
-- =========================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- =========================================================
-- TEMA
-- =========================================================

local Theme = {
    Background = Color3.fromRGB(15, 15, 18),
    Surface = Color3.fromRGB(22, 22, 26),
    Surface2 = Color3.fromRGB(29, 29, 34),
    Text = Color3.fromRGB(245, 245, 245),
    Muted = Color3.fromRGB(160, 160, 168),
    Accent = Color3.fromRGB(255, 132, 0),
    Border = Color3.fromRGB(75, 50, 30),
}

-- =========================================================
-- EMPRESAS / MODELOS
-- =========================================================
-- Você NÃO precisa colocar URL nem modelo manualmente.
-- O usuário escolhe a empresa e depois o modelo.

local AI_PROVIDERS = {

    ["OpenAI"] = {
        url = "https://api.openai.com/v1/chat/completions",

        models = {
            "gpt-5.6",
            "gpt-5.6-mini",
            "gpt-5.5",
            "gpt-5.4",
            "gpt-4o",
            "gpt-4o-mini",
        },
    },

    ["DeepSeek"] = {
        url = "https://api.deepseek.com/chat/completions",

        models = {
            "deepseek-chat",
            "deepseek-reasoner",
        },
    },

    ["Google Gemini"] = {
        url = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",

        models = {
            "gemini-2.5-pro",
            "gemini-2.5-flash",
            "gemini-2.0-flash",
        },
    },

    ["OpenRouter"] = {
        url = "https://openrouter.ai/api/v1/chat/completions",

        models = {
            "openai/gpt-5.6",
            "openai/gpt-5.6-mini",
            "anthropic/claude-sonnet-4",
            "google/gemini-2.5-pro",
            "deepseek/deepseek-chat",
        },
    },
}

local SelectedProvider = nil
local SelectedModel = nil
local PlayerName = ""
local APIKey = ""

-- =========================================================
-- HTTP
-- =========================================================

local function GetRequestFunction()

    local candidates = {
        request,
        http_request,

        syn and syn.request,
        http and http.request,
        fluxus and fluxus.request,
        krnl and krnl.request,
    }

    for _, fn in ipairs(candidates) do
        if type(fn) == "function" then
            return fn
        end
    end

    return nil
end

local Request = GetRequestFunction()

local function HTTPRequest(options)

    if not Request then
        return false, nil, nil,
            "Este executor não disponibiliza uma função HTTP compatível."
    end

    local success, response = pcall(function()
        return Request(options)
    end)

    if not success then
        return false, nil, nil, tostring(response)
    end

    if type(response) ~= "table" then
        return false, nil, nil, "Resposta HTTP inválida."
    end

    local status = tonumber(
        response.StatusCode
        or response.Status
        or response.status
        or 0
    )

    local body =
        response.Body
        or response.body
        or ""

    if status == 0 and body ~= "" then
        status = 200
    end

    if status < 200 or status >= 300 then
        return false, body, status,
            "HTTP " .. tostring(status)
    end

    return true, body, status, nil
end

-- =========================================================
-- JSON
-- =========================================================

local function Encode(data)

    local success, result = pcall(function()
        return HttpService:JSONEncode(data)
    end)

    if success then
        return result
    end

    return nil
end

local function Decode(data)

    local success, result = pcall(function()
        return HttpService:JSONDecode(data)
    end)

    if success then
        return result
    end

    return nil
end

-- =========================================================
-- GUI
-- =========================================================

local Gui = Instance.new("ScreenGui")
Gui.Name = "AIChat"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(560, 470)
Main.Position = UDim2.new(0.5, -280, 0.5, -235)
Main.BackgroundColor3 = Theme.Background
Main.BorderSizePixel = 0
Main.Parent = Gui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Theme.Accent
MainStroke.Thickness = 1
MainStroke.Parent = Main

-- =========================================================
-- FUNÇÕES VISUAIS
-- =========================================================

local function Label(parent, text, size, position, textSize)

    local object = Instance.new("TextLabel")

    object.BackgroundTransparency = 1
    object.Size = size
    object.Position = position

    object.Text = text
    object.TextColor3 = Theme.Text
    object.TextSize = textSize or 13
    object.Font = Enum.Font.Gotham

    object.TextXAlignment = Enum.TextXAlignment.Left
    object.TextYAlignment = Enum.TextYAlignment.Center

    object.Parent = parent

    return object
end

local function Button(parent, text, size, position)

    local object = Instance.new("TextButton")

    object.AutoButtonColor = false
    object.BackgroundColor3 = Theme.Surface2
    object.BorderSizePixel = 0

    object.Size = size
    object.Position = position

    object.Text = text
    object.TextColor3 = Theme.Text
    object.TextSize = 13
    object.Font = Enum.Font.GothamMedium

    object.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = object

    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Border
    stroke.Thickness = 1
    stroke.Parent = object

    object.MouseEnter:Connect(function()
        object.BackgroundColor3 = Theme.Accent
    end)

    object.MouseLeave:Connect(function()
        object.BackgroundColor3 = Theme.Surface2
    end)

    return object
end

local function TextBox(parent, placeholder, size, position)

    local object = Instance.new("TextBox")

    object.BackgroundColor3 = Theme.Surface
    object.BorderSizePixel = 0

    object.Size = size
    object.Position = position

    object.Text = ""
    object.PlaceholderText = placeholder

    object.TextColor3 = Theme.Text
    object.PlaceholderColor3 = Theme.Muted

    object.TextSize = 13
    object.Font = Enum.Font.Gotham

    object.ClearTextOnFocus = false

    object.TextXAlignment = Enum.TextXAlignment.Left
    object.TextYAlignment = Enum.TextYAlignment.Center

    object.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = object

    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Border
    stroke.Thickness = 1
    stroke.Parent = object

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.Parent = object

    return object
end

-- =========================================================
-- TOP BAR
-- =========================================================

local TopBar = Instance.new("Frame")
TopBar.BackgroundTransparency = 1
TopBar.Size = UDim2.new(1, -16, 0, 40)
TopBar.Position = UDim2.fromOffset(8, 5)
TopBar.Parent = Main

local Title = Label(
    TopBar,
    "AIChat",
    UDim2.new(1, -80, 1, 0),
    UDim2.fromOffset(8, 0),
    17
)

Title.Font = Enum.Font.GothamBold

local Close = Button(
    TopBar,
    "×",
    UDim2.fromOffset(32, 30),
    UDim2.new(1, -32, 0, 4)
)

Close.Activated:Connect(function()
    Gui:Destroy()
end)

-- =========================================================
-- ABAS
-- =========================================================

local Tabs = Instance.new("Frame")
Tabs.BackgroundTransparency = 1
Tabs.Size = UDim2.new(1, -16, 0, 36)
Tabs.Position = UDim2.fromOffset(8, 48)
Tabs.Parent = Main

local ChatTab = Button(
    Tabs,
    "Chat",
    UDim2.new(1 / 3, -5, 1, 0),
    UDim2.fromOffset(0, 0)
)

local ScriptTab = Button(
    Tabs,
    "RScripts",
    UDim2.new(1 / 3, -5, 1, 0),
    UDim2.new(1 / 3, 2, 0, 0)
)

local ConfigTab = Button(
    Tabs,
    "Configuração",
    UDim2.new(1 / 3, -5, 1, 0),
    UDim2.new(2 / 3, 4, 0, 0)
)

ChatTab.BackgroundColor3 = Theme.Accent

-- =========================================================
-- PÁGINAS
-- =========================================================

local Pages = {}

local function Page(name)

    local page = Instance.new("Frame")

    page.Name = name
    page.BackgroundTransparency = 1
    page.Size = UDim2.new(1, -16, 1, -92)
    page.Position = UDim2.fromOffset(8, 88)
    page.Visible = false

    page.Parent = Main

    Pages[name] = page

    return page
end

local ChatPage = Page("Chat")
local ScriptPage = Page("RScripts")
local ConfigPage = Page("Configuração")

local function ShowPage(name)

    for pageName, page in pairs(Pages) do
        page.Visible = pageName == name
    end

    ChatTab.BackgroundColor3 =
        name == "Chat"
        and Theme.Accent
        or Theme.Surface2

    ScriptTab.BackgroundColor3 =
        name == "RScripts"
        and Theme.Accent
        or Theme.Surface2

    ConfigTab.BackgroundColor3 =
        name == "Configuração"
        and Theme.Accent
        or Theme.Surface2
end

ChatTab.Activated:Connect(function()
    ShowPage("Chat")
end)

ScriptTab.Activated:Connect(function()
    ShowPage("RScripts")
end)

ConfigTab.Activated:Connect(function()
    ShowPage("Configuração")
end)

-- =========================================================
-- CONFIGURAÇÃO
-- =========================================================

Label(
    ConfigPage,
    "Configuração da IA",
    UDim2.new(1, 0, 0, 25),
    UDim2.fromOffset(5, 0),
    16
).Font = Enum.Font.GothamBold

Label(
    ConfigPage,
    "Você só precisa informar seu nome e sua API Key.",
    UDim2.new(1, 0, 0, 22),
    UDim2.fromOffset(5, 27),
    11
).TextColor3 = Theme.Muted

-- ---------------------------------------------------------
-- NOME DO PLAYER
-- ---------------------------------------------------------

Label(
    ConfigPage,
    "Nome do player",
    UDim2.new(1, 0, 0, 20),
    UDim2.fromOffset(5, 58),
    11
).TextColor3 = Theme.Muted

local PlayerNameBox = TextBox(
    ConfigPage,
    "Ex.: CoiledTom",
    UDim2.new(1, -10, 0, 34),
    UDim2.fromOffset(5, 80)
)

-- ---------------------------------------------------------
-- EMPRESA
-- ---------------------------------------------------------

Label(
    ConfigPage,
    "Empresa da IA",
    UDim2.new(1, 0, 0, 20),
    UDim2.fromOffset(5, 122),
    11
).TextColor3 = Theme.Muted

local ProviderBox = Button(
    ConfigPage,
    "▼  Selecione a empresa",
    UDim2.new(1, -10, 0, 36),
    UDim2.fromOffset(5, 144)
)

-- ---------------------------------------------------------
-- MODELO
-- ---------------------------------------------------------

Label(
    ConfigPage,
    "Modelo",
    UDim2.new(1, 0, 0, 20),
    UDim2.fromOffset(5, 188),
    11
).TextColor3 = Theme.Muted

local ModelBox = Button(
    ConfigPage,
    "▼  Primeiro selecione a empresa",
    UDim2.new(1, -10, 0, 36),
    UDim2.fromOffset(5, 210)
)

-- ---------------------------------------------------------
-- API KEY
-- ---------------------------------------------------------

Label(
    ConfigPage,
    "API Key",
    UDim2.new(1, 0, 0, 20),
    UDim2.fromOffset(5, 254),
    11
).TextColor3 = Theme.Muted

local APIKeyBox = TextBox(
    ConfigPage,
    "Cole sua API Key aqui",
    UDim2.new(1, -10, 0, 34),
    UDim2.fromOffset(5, 276)
)

-- ---------------------------------------------------------
-- STATUS
-- ---------------------------------------------------------

local ConfigStatus = Label(
    ConfigPage,
    "",
    UDim2.new(1, -10, 0, 38),
    UDim2.fromOffset(5, 318),
    11
)

ConfigStatus.TextWrapped = true
ConfigStatus.TextColor3 = Theme.Muted

-- =========================================================
-- SELECTBOX
-- =========================================================

local ActiveDropdown = nil

local function CloseDropdown()

    if ActiveDropdown then
        ActiveDropdown:Destroy()
        ActiveDropdown = nil
    end

end

local function CreateSelectBox(options, anchor, callback)

    CloseDropdown()

    local dropdown = Instance.new("Frame")

    dropdown.BackgroundColor3 = Theme.Surface2
    dropdown.BorderSizePixel = 0

    dropdown.Size = UDim2.new(
        anchor.Size.X.Scale,
        anchor.Size.X.Offset,
        0,
        math.min(#options * 34 + 8, 210)
    )

    dropdown.Position = UDim2.new(
        anchor.Position.X.Scale,
        anchor.Position.X.Offset,
        anchor.Position.Y.Scale,
        anchor.Position.Y.Offset + anchor.Size.Y.Offset + 4
    )

    dropdown.ZIndex = 100
    dropdown.Parent = ConfigPage

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = dropdown

    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Accent
    stroke.Parent = dropdown

    local scroll = Instance.new("ScrollingFrame")

    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0

    scroll.Size = UDim2.new(1, -4, 1, -4)
    scroll.Position = UDim2.fromOffset(2, 2)

    scroll.CanvasSize = UDim2.fromOffset(
        0,
        #options * 34
    )

    scroll.ScrollBarThickness = 4
    scroll.ZIndex = 101
    scroll.Parent = dropdown

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 2)
    layout.Parent = scroll

    for _, option in ipairs(options) do

        local item = Instance.new("TextButton")

        item.BackgroundColor3 = Theme.Surface
        item.BorderSizePixel = 0

        item.Size = UDim2.new(1, -4, 0, 32)

        item.Text = "  " .. tostring(option)
        item.TextColor3 = Theme.Text
        item.TextSize = 12
        item.Font = Enum.Font.GothamMedium

        item.TextXAlignment = Enum.TextXAlignment.Left

        item.AutoButtonColor = false
        item.ZIndex = 102

        item.Parent = scroll

        local itemCorner = Instance.new("UICorner")
        itemCorner.CornerRadius = UDim.new(0, 5)
        itemCorner.Parent = item

        item.MouseEnter:Connect(function()
            item.BackgroundColor3 = Theme.Accent
        end)

        item.MouseLeave:Connect(function()
            item.BackgroundColor3 = Theme.Surface
        end)

        item.Activated:Connect(function()

            callback(option)

            CloseDropdown()

        end)

    end

    ActiveDropdown = dropdown

end

-- =========================================================
-- SELECTBOX EMPRESA
-- =========================================================

ProviderBox.Activated:Connect(function()

    local providers = {}

    for providerName in pairs(AI_PROVIDERS) do
        table.insert(providers, providerName)
    end

    table.sort(providers)

    CreateSelectBox(
        providers,
        ProviderBox,
        function(provider)

            SelectedProvider = provider
            SelectedModel = nil

            ProviderBox.Text =
                "✓  " .. provider

            ModelBox.Text =
                "▼  Selecione o modelo"

            ConfigStatus.Text =
                "Agora escolha o modelo da " .. provider .. "."

        end
    )

end)

-- =========================================================
-- SELECTBOX MODELO
-- =========================================================

ModelBox.Activated:Connect(function()

    if not SelectedProvider then

        ConfigStatus.Text =
            "Primeiro escolha a empresa da IA."

        return
    end

    local models =
        AI_PROVIDERS[SelectedProvider].models

    CreateSelectBox(
        models,
        ModelBox,
        function(model)

            SelectedModel = model

            ModelBox.Text =
                "✓  " .. model

            ConfigStatus.Text =
                "Modelo selecionado: " .. model

        end
    )

end)

-- =========================================================
-- SALVAR CONFIGURAÇÃO
-- =========================================================

local SaveButton = Button(
    ConfigPage,
    "Salvar configuração",
    UDim2.fromOffset(180, 36),
    UDim2.fromOffset(5, 365)
)

SaveButton.Activated:Connect(function()

    PlayerName =
        PlayerNameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")

    APIKey =
        APIKeyBox.Text:gsub("^%s+", ""):gsub("%s+$", "")

    if PlayerName == "" then

        ConfigStatus.Text =
            "Digite o nome do player."

        return
    end

    if not SelectedProvider then

        ConfigStatus.Text =
            "Selecione a empresa da IA."

        return
    end

    if not SelectedModel then

        ConfigStatus.Text =
            "Selecione o modelo da IA."

        return
    end

    if APIKey == "" then

        ConfigStatus.Text =
            "Cole sua API Key."

        return
    end

    ConfigStatus.Text =
        "Configuração salva!"

end)

-- =========================================================
-- CHAT
-- =========================================================

local ChatHeader = Label(
    ChatPage,
    "Conversa",
    UDim2.new(1, 0, 0, 25),
    UDim2.fromOffset(4, 0),
    15
)

ChatHeader.Font = Enum.Font.GothamBold

local ActiveAI = Label(
    ChatPage,
    "Nenhuma IA configurada",
    UDim2.new(1, 0, 0, 20),
    UDim2.fromOffset(4, 26),
    11
)

ActiveAI.TextColor3 = Theme.Muted

local Messages = Instance.new("ScrollingFrame")

Messages.BackgroundColor3 = Theme.Surface
Messages.BorderSizePixel = 0

Messages.Size = UDim2.new(1, 0, 1, -130)
Messages.Position = UDim2.fromOffset(0, 52)

Messages.ScrollBarThickness = 4
Messages.AutomaticCanvasSize = Enum.AutomaticSize.Y
Messages.CanvasSize = UDim2.new()

Messages.Parent = ChatPage

local MessageLayout = Instance.new("UIListLayout")
MessageLayout.Padding = UDim.new(0, 8)
MessageLayout.Parent = Messages

local MessagePadding = Instance.new("UIPadding")
MessagePadding.PaddingTop = UDim.new(0, 8)
MessagePadding.PaddingBottom = UDim.new(0, 8)
MessagePadding.PaddingLeft = UDim.new(0, 8)
MessagePadding.PaddingRight = UDim.new(0, 8)
MessagePadding.Parent = Messages

local Input = TextBox(
    ChatPage,
    "Digite sua mensagem...",
    UDim2.new(1, -105, 0, 60),
    UDim2.new(0, 0, 1, -60)
)

local SendButton = Button(
    ChatPage,
    "Enviar",
    UDim2.fromOffset(95, 60),
    UDim2.new(1, -95, 1, -60)
)

local function AddMessage(author, text)

    local frame = Instance.new("Frame")

    frame.BackgroundColor3 =
        author == "Você"
        and Theme.Surface2
        or Theme.Background

    frame.BorderSizePixel = 0

    frame.Size = UDim2.new(1, -2, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y

    frame.Parent = Messages

    local padding = Instance.new("UIPadding")

    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 9)
    padding.PaddingRight = UDim.new(0, 9)

    padding.Parent = frame

    local name = Label(
        frame,
        author,
        UDim2.new(1, 0, 0, 18),
        UDim2.fromOffset(0, 0),
        11
    )

    name.TextColor3 = Theme.Accent

    local message = Label(
        frame,
        text,
        UDim2.new(1, 0, 0, 0),
        UDim2.fromOffset(0, 21),
        13
    )

    message.AutomaticSize = Enum.AutomaticSize.Y
    message.TextWrapped = true
    message.TextYAlignment = Enum.TextYAlignment.Top

end

-- =========================================================
-- ENVIO PARA IA
-- =========================================================

local function SendToAI(message)

    if not SelectedProvider then

        AddMessage(
            "Sistema",
            "Selecione a empresa da IA nas configurações."
        )

        return
    end

    if not SelectedModel then

        AddMessage(
            "Sistema",
            "Selecione o modelo da IA nas configurações."
        )

        return
    end

    if APIKey == "" then

        AddMessage(
            "Sistema",
            "Configure sua API Key."
        )

        return
    end

    local provider =
        AI_PROVIDERS[SelectedProvider]

    local messages = {

        {
            role = "system",

            content =
                "O nome do player é "
                .. PlayerName
                .. ". "
                .. "Chame o player por esse nome. "
                .. "Seja útil e responda em português."
        },

        {
            role = "user",
            content = message
        }
    }

    local body = Encode({

        model = SelectedModel,

        messages = messages

    })

    if not body then

        AddMessage(
            "Sistema",
            "Erro ao preparar a requisição."
        )

        return
    end

    SendButton.Text = "..."

    task.spawn(function()

        local success, response, status, errorMessage =
            HTTPRequest({

                Url = provider.url,

                Method = "POST",

                Headers = {

                    ["Content-Type"] =
                        "application/json",

                    ["Authorization"] =
                        "Bearer " .. APIKey,

                },

                Body = body

            })

        if not success then

            AddMessage(
                "Sistema",
                "Erro HTTP: "
                .. tostring(errorMessage)
            )

            SendButton.Text = "Enviar"

            return
        end

        local data = Decode(response)

        if not data then

            AddMessage(
                "Sistema",
                "A IA retornou uma resposta inválida."
            )

            SendButton.Text = "Enviar"

            return
        end

        local answer

        if data.choices
            and data.choices[1]
            and data.choices[1].message then

            answer =
                data.choices[1].message.content

        end

        if type(answer) ~= "string"
            or answer == "" then

            AddMessage(
                "Sistema",
                "Não foi possível encontrar a resposta da IA."
            )

            SendButton.Text = "Enviar"

            return
        end

        AddMessage(
            SelectedProvider,
            answer
        )

        SendButton.Text = "Enviar"

    end)

end

SendButton.Activated:Connect(function()

    local message =
        Input.Text:gsub("^%s+", ""):gsub("%s+$", "")

    if message == "" then
        return
    end

    Input.Text = ""

    AddMessage(
        "Você",
        message
    )

    SendToAI(message)

end)

-- =========================================================
-- RSCRIPTS
-- =========================================================

local ScriptTitle = Label(
    ScriptPage,
    "RScripts",
    UDim2.new(1, 0, 0, 25),
    UDim2.fromOffset(4, 0),
    15
)

ScriptTitle.Font = Enum.Font.GothamBold

local SearchBox = TextBox(
    ScriptPage,
    "Pesquisar scripts...",
    UDim2.new(1, -105, 0, 36),
    UDim2.fromOffset(0, 34)
)

local SearchButton = Button(
    ScriptPage,
    "Buscar",
    UDim2.fromOffset(95, 36),
    UDim2.new(1, -95, 0, 34)
)

local Results = Instance.new("ScrollingFrame")

Results.BackgroundColor3 = Theme.Surface
Results.BorderSizePixel = 0

Results.Size = UDim2.new(1, 0, 1, -82)
Results.Position = UDim2.fromOffset(0, 76)

Results.ScrollBarThickness = 4
Results.AutomaticCanvasSize = Enum.AutomaticSize.Y
Results.CanvasSize = UDim2.new()

Results.Parent = ScriptPage

local ResultLayout = Instance.new("UIListLayout")
ResultLayout.Padding = UDim.new(0, 7)
ResultLayout.Parent = Results

local function ClearResults()

    for _, child in ipairs(Results:GetChildren()) do

        if child:IsA("Frame")
            or child:IsA("TextLabel") then

            child:Destroy()

        end

    end

end

local RSCRIPTS_URL =
    "https://api.rscripts.net"

local RScriptsKey = ""

local function RScriptsRequest(endpoint)

    if RScriptsKey == "" then

        return false,
            nil,
            "Configure a API Key do RScripts."
    end

    if not Request then

        return false,
            nil,
            "HTTP indisponível neste executor. O executor precisa fornecer request, http_request ou syn.request."
    end

    local success, body, status, errorMessage =
        HTTPRequest({

            Url = RSCRIPTS_URL .. endpoint,

            Method = "GET",

            Headers = {

                ["Authorization"] =
                    "Bearer " .. RScriptsKey,

                ["X-Api-Key"] =
                    RScriptsKey,

                ["Accept"] =
                    "application/json"

            }

        })

    if not success then

        if status == 401 then

            return false,
                nil,
                "API Key do RScripts inválida."

        elseif status == 403 then

            return false,
                nil,
                "Acesso negado pelo RScripts."

        elseif status == 429 then

            return false,
                nil,
                "Limite de requisições atingido."

        end

        return false,
            nil,
            errorMessage
            or "Erro HTTP."

    end

    local data = Decode(body)

    if not data then

        return false,
            nil,
            "Resposta inválida do RScripts."

    end

    return true, data, nil

end

local function AddScriptResult(script)

    local card = Instance.new("Frame")

    card.BackgroundColor3 = Theme.Surface2
    card.BorderSizePixel = 0

    card.Size = UDim2.new(1, -8, 0, 120)

    card.Parent = Results

    local padding = Instance.new("UIPadding")

    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)

    padding.Parent = card

    local title = Label(
        card,
        tostring(script.title or "Sem título"),
        UDim2.new(1, 0, 0, 20),
        UDim2.fromOffset(0, 0),
        13
    )

    title.Font = Enum.Font.GothamBold

    local description = Label(
        card,
        tostring(script.description or "Sem descrição."),
        UDim2.new(1, 0, 0, 36),
        UDim2.fromOffset(0, 24),
        11
    )

    description.TextWrapped = true
    description.TextYAlignment = Enum.TextYAlignment.Top
    description.TextColor3 = Theme.Muted

    local CopyButton = Button(
        card,
        "Copiar",
        UDim2.fromOffset(82, 28),
        UDim2.fromOffset(0, 75)
    )

    CopyButton.Activated:Connect(function()

        if type(setclipboard) ~= "function" then

            CopyButton.Text =
                "Clipboard indisponível"

            task.delay(2, function()

                if CopyButton then
                    CopyButton.Text = "Copiar"
                end

            end)

            return
        end

        local slug = script.slug

        if not slug then
            return
        end

        task.spawn(function()

            local ok, data, err =
                RScriptsRequest(
                    "/v1/scripts/"
                    .. HttpService:UrlEncode(slug)
                )

            if not ok then

                CopyButton.Text = "Erro"

                return
            end

            local source =
                data.data
                and data.data.script

            if type(source) ~= "string" then

                CopyButton.Text =
                    "Sem código"

                return
            end

            pcall(
                setclipboard,
                source
            )

            CopyButton.Text =
                "Copiado!"

            task.delay(2, function()

                if CopyButton then
                    CopyButton.Text = "Copiar"
                end

            end)

        end)

    end)

end

local function SearchScripts()

    ClearResults()

    local query =
        SearchBox.Text:gsub("^%s+", "")
        :gsub("%s+$", "")

    if query == "" then

        return
    end

    SearchButton.Text = "..."

    task.spawn(function()

        local endpoint =
            "/v1/search?q="
            .. HttpService:UrlEncode(query)
            .. "&index=scripts&limit=20"

        local success, data, errorMessage =
            RScriptsRequest(endpoint)

        if not success then

            local errorLabel = Label(
                Results,
                tostring(errorMessage),
                UDim2.new(1, -10, 0, 60),
                UDim2.fromOffset(5, 5),
                12
            )

            errorLabel.TextWrapped = true
            errorLabel.TextColor3 = Theme.Muted

            SearchButton.Text = "Buscar"

            return
        end

        local scripts = {}

        if data.data
            and type(data.data.scripts) == "table" then

            scripts =
                data.data.scripts

        elseif type(data.data) == "table" then

            scripts =
                data.data

        end

        if #scripts == 0 then

            local none = Label(
                Results,
                "Nenhum script encontrado.",
                UDim2.new(1, -10, 0, 40),
                UDim2.fromOffset(5, 5),
                12
            )

            none.TextColor3 = Theme.Muted

        else

            for _, script in ipairs(scripts) do

                AddScriptResult(script)

            end

        end

        SearchButton.Text = "Buscar"

    end)

end

SearchButton.Activated:Connect(
    SearchScripts
)

SearchBox.FocusLost:Connect(function(enterPressed)

    if enterPressed then
        SearchScripts()
    end

end)

-- =========================================================
-- RSCRIPTS CONFIG
-- =========================================================

local RScriptsConfigLabel = Label(
    ConfigPage,
    "RScripts API Key",
    UDim2.new(1, 0, 0, 20),
    UDim2.fromOffset(5, 410),
    11
)

RScriptsConfigLabel.TextColor3 =
    Theme.Muted

local RScriptsKeyBox = TextBox(
    ConfigPage,
    "API Key do RScripts",
    UDim2.new(1, -10, 0, 34),
    UDim2.fromOffset(5, 432)
)

local SaveRScripts = Button(
    ConfigPage,
    "Salvar RScripts",
    UDim2.fromOffset(150, 34),
    UDim2.fromOffset(5, 474)
)

SaveRScripts.Activated:Connect(function()

    RScriptsKey =
        RScriptsKeyBox.Text
        :gsub("^%s+", "")
        :gsub("%s+$", "")

    if RScriptsKey == "" then

        ConfigStatus.Text =
            "Informe a API Key do RScripts."

        return
    end

    ConfigStatus.Text =
        "API Key do RScripts salva."

end)

-- =========================================================
-- ARRASTAR JANELA
-- =========================================================

local dragging = false
local dragStart
local startPosition

TopBar.InputBegan:Connect(function(input)

    if input.UserInputType ==
        Enum.UserInputType.MouseButton1
        or input.UserInputType ==
        Enum.UserInputType.Touch then

        dragging = true

        dragStart = input.Position
        startPosition = Main.Position

    end

end)

UserInputService.InputChanged:Connect(function(input)

    if not dragging then
        return
    end

    if input.UserInputType ~=
        Enum.UserInputType.MouseMovement
        and input.UserInputType ~=
        Enum.UserInputType.Touch then

        return
    end

    local delta =
        input.Position - dragStart

    Main.Position =
        UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,

            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )

end)

UserInputService.InputEnded:Connect(function(input)

    if input.UserInputType ==
        Enum.UserInputType.MouseButton1
        or input.UserInputType ==
        Enum.UserInputType.Touch then

        dragging = false

    end

end)

-- =========================================================
-- INICIALIZAÇÃO
-- =========================================================

ShowPage("Chat")

AddMessage(
    "Sistema",
    "AIChat iniciado. Configure a empresa, modelo e API Key na aba Configuração."
)