--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local ServerStorage = game:GetService("ServerStorage")

if not RunService:IsServer() then return end

--// Variables
local Types = require(script:WaitForChild("Types"))
local Caller = require(script:WaitForChild("Caller"))
local Settings = require(script:WaitForChild("Settings"))
local DefaultData = require(script:WaitForChild("DefaultData"))

local concat = table.concat
local _print = print
local _warn = warn
local void = (function()end)()

local IsStudio = RunService:IsStudio()
local ModuleLoaded = not Settings.AutoRetryOnConnectFail

local module = {}
local Connections = {}
local Stores = setmetatable({}, {__mode = "k"}) :: {[Player]: Types.DataStore}
local CloseFunctions = setmetatable({}, {__index = function(self, Key) rawset(self, Key, {}) return rawget(self, Key) end}) :: {[Player]: {(...any) -> ...any}}

local Store = DataStoreService:GetDataStore(concat({Settings.StoreName, "_v", Settings.StoreVersion}))
local GetAsync = Store.GetAsync
local SetAsync = Store.SetAsync

local Exceptions = {
    CALLED_META_METHOD = "You've called meta method.";
    TRY_TO_CHANGE_LOCKED_PROPERTIES = "The %s property is locked.";
    TRY_TO_CALL_METHOD_ON_MAINMOUDLE = "You've called DataStore method on MainModule.";
}

local Methods = {
    Save = true;
    Clear = true;
    Destroy = true;
    BindToClose = true;
}

local NotChangables = {
    AutosaveBegan = true;
    AutosaveEnded = true;
    Changed = true
}

local ReadOnlys = {
    IsLoaded = true;
    Player = true;
}

local RealPropertiesMeta = {}

--// Functions
-- Util functions
local function print(...)
    if Settings.Debug then
        return _print(...)
    end
end

local function warn(...)
    if Settings.Debug then
        return _warn(...)
    end
end

local function dprint(...)
    if Settings.Debug and Settings.DetailedDebug then
        return _print(...)
    end
end

local function dwarn(...)
    if Settings.Debug and Settings.DetailedDebug then
        return _warn(...)
    end
end

local function assert(Check, Message, Level)
    if not Check then
        return error(Message, Level or 3)
    end
end

function RealPropertiesMeta:__index(Key: any)
    if rawget(DefaultData, Key) ~= nil then
        local Property = rawget(DefaultData, Key)
        rawset(self, Key, typeof(Property) ~= "table" and Property or table.clone(Property))
        return rawget(self, Key)
    end
end

local function CanConnectToRoblox()
    local Operation = Caller.Run(SetAsync, false, Store, "__Server", os.time())
    local Error = Operation:HasError()

    if Error then
        return false
    else
        return true
    end
end

local function RunAutosave(DataStore: Types.DataStore)
    if not Settings.Autosave then return end

    local Player = DataStore.Player

    while wait(Settings.AutosaveDelay) and Player and Player:IsDescendantOf(Players) and Settings.Autosave do
        -- 여기서 wait을 쓰는 이유는 자동저장은 굳이 정확히 시간 계산을 할 필요가 없기 때문!
        print(`Autosaving {Player.Name}'s data.`)
        DataStore.__coreProps._AutoStart:Fire(DataStore)
        DataStore:Save()
        DataStore.__coreProps._AutoEnd:Fire(DataStore)
        print(`{Player.Name}'s data.saved.`)
    end
end

local function OnPlayerAdded(Player: Player)
    local DataStore: Types.DataStore
    local IsLoaded = false

    repeat task.wait() until ModuleLoaded

    if not module.ConnectedToRoblox then
        return Player:Kick(Settings.ConnectFailKickMessage)
    end

    if RunService:IsStudio() and Settings.LoadDefaultDataInStudio then
        DataStore = {}
        IsLoaded = true
    else
        local Operation = Caller.Run(GetAsync, false, Store, `User_{Player.UserId}`)
        
        if Operation:HasError() then
            if Settings.RetryOnFail then
                local RetryCount = 0

                repeat
                    task.wait(Settings.RetryDelay)

                    RetryCount += 1
                    Operation = Caller.Run(GetAsync, false, Store, `User_{Player.UserId}`)

                    if not Operation:HasError() then
                        break
                    end
                until RetryCount >= Settings.RetryCount
            end

            if Operation:HasError() then
                if Settings.KickPlayerOnFail then
                    _warn(Operation:HasError())
                    Player:Kick(Settings.KickMessage)
                else
                    warn(`Failed to load {Player.Name}'s data. Set data as default data.`)
                    DataStore = {}
                end
            end
        end

        if not DataStore then
            if Operation:IsNull() then
                DataStore = {}
                print(`Creating new data cell : {Player.Name}`)
            else
                DataStore = HttpService:JSONDecode(Operation:GetResults())
                print(`Load data cell : {Player.Name}`)
            end

            IsLoaded = true
        end
    end

    -- Signal 모듈 쓰는게 더 좋은데 귀찮은 :>
    local AutoStart = Instance.new("BindableEvent")
    local AutoEnd = Instance.new("BindableEvent")
    local Changed = Instance.new("BindableEvent")
    
    local DataStore = {
        __realProps = setmetatable(DataStore, RealPropertiesMeta);
        __coreProps = {
            IsLoaded = IsLoaded;
            Player = Player;
            AutosaveBegan = AutoStart.Event;
            AutosaveEnded = AutoEnd.Event;
            Changed = Changed.Event;
            
            _AutoStart = AutoStart;
            _AutoEnd = AutoEnd;
            _Changed = Changed;
            _Key = `User_{Player.UserId}`;
        };
    }

    local AutosaveThread = task.spawn(RunAutosave, DataStore)
    DataStore.__coreProps._AutosaveThread = AutosaveThread

    Stores[Player] = setmetatable(DataStore, module)

    return Stores[Player]
end

local function OnPlayerRemoving(Player: Player)
    local PlayerStore = Stores[Player]

    if PlayerStore then
        Stores[Player] = void

        if PlayerStore.IsLoaded then
            if IsStudio and not Settings.SaveInStudio then
                print(`Save cancelled : {Player.Name}`)
            else
                PlayerStore:Save()
                print(`Successfully saved : {Player.Name}`)
            end
        end
        
        PlayerStore:Destroy()
    end
    
    if CloseFunctions[Player] then
        CloseFunctions[Player] = void
    end
end

local function RunCloseFunctions(Player: Player)
    local Store = module:GetData(Player)

    for _, Function in ipairs(CloseFunctions[Player]) do
        Function(Store)
    end
end

local function BindToClose()
    local Operations = {}

    for Player, _ in pairs(CloseFunctions) do
        table.insert(Operations, Caller.Run(RunCloseFunctions, true, Player))
    end

    local Completed = false
    repeat
        Completed = true

        for _, Operation in ipairs(Operations) do
            if not Operation.Completed then
                Completed = false
                break
            end
        end

        task.wait()
    until Completed
    
    for _, Connection in ipairs(Connections) do
        Connection:Disconnect()
    end

    table.clear(Connections)

    for _, Player in ipairs(Players:GetPlayers()) do
        OnPlayerRemoving(Player)
    end
end

-- DataStore functions
function module:__index(Key: any)
    assert(self ~= module, Exceptions.CALLED_META_METHOD)

    if rawget(Methods, Key) then
        return rawget(module, Key)
    elseif rawget(self.__coreProps, Key) and (Key:sub(1, 1) == "_" and getfenv(2).script == script or true) then
        return rawget(self.__coreProps, Key)
    else
        return self.__realProps[Key] -- 일부로 메타테이블 걸어놨으니까 그냥 호출시키는거인
    end
end

function module:__newindex(Key: any, Value: any)
    assert(self ~= module, Exceptions.CALLED_META_METHOD)
    assert(not (rawget(NotChangables, Key) or rawget(Methods, Key)), Exceptions.TRY_TO_CHANGE_LOCKED_PROPERTIES:format(Key))

    if (rawget(ReadOnlys, Key) and getfenv(2).script == script) then
        return rawset(self.__coreProps, Key, Value)
    elseif rawget(DefaultData, Key) ~= nil then
        rawget(self.__coreProps, "_Changed"):Fire(Key, Value, self.__realProps[Key]) -- 혹시 nil인 상태에서 설정하면 rawget할때 nil 딸려오니 메타테이블 걸리게 rawget안씀
        return rawset(self.__realProps, Key, Value)
    end
end

function module:Save(Async: boolean?)
    assert(self ~= module, Exceptions.TRY_TO_CALL_METHOD_ON_MAINMOUDLE)

    local Operation = Caller.Run(SetAsync, Async, Store, self._Key, HttpService:JSONEncode(self.__realProps))
    return Operation
end

function module:Clear()
    assert(self ~= module, Exceptions.TRY_TO_CALL_METHOD_ON_MAINMOUDLE)

    table.clear(self.__realProps)
end

function module:Destroy()
    assert(self ~= module, Exceptions.TRY_TO_CALL_METHOD_ON_MAINMOUDLE)

    table.clear(self.__realProps)
    setmetatable(self.__realProps, nil)
    
    for Key, Value in pairs(self.__coreProps) do
        if typeof(Value) == "Instance" and Key ~= "Player" then
            Value:Destroy()
        elseif typeof(Value) == "table" then
            table.clear(Value)
        elseif typeof(Value) == "thread" and coroutine.status(Value) ~= "dead" then
            task.cancel(Value)
        end

        rawset(self.__coreProps, Key, void)
    end

    table.clear(self)
    setmetatable(self, nil)
end

function module:BindToClose(Function: (...any) -> ...any)
    assert(self ~= module, Exceptions.TRY_TO_CALL_METHOD_ON_MAINMOUDLE)

    local Player = self.Player

    if Player and Player:IsDescendantOf(Players) then
        table.insert(CloseFunctions[Player], Function)
    else
        warn("Player not found in the game.")
        self:Destroy()
    end
end

-- MainModule functions
function module:GetData(Player: Player)
    if Player and Player:IsDescendantOf(Players) then
        if not Stores[Player] then
            print(`Waiting until {Player.Name}'s store to load.`)
            repeat
                task.wait()
            until Stores[Player]
        end

        return Stores[Player]
    end
end

function module:SaveAll(Async: boolean?)
    local Operations = {}

    for _, Store in pairs(Stores) do
        print(`Now saving {Store.Player.Name}'s store.`)
        table.insert(Operations, Store:Save(Async))
    end

    return Operations
end

function module:RetryToConnect()
    module.ConnectedToRoblox = CanConnectToRoblox()

    if not module.ConnectedToRoblox then
        warn("Failed to connect roblox data store api.")
    end

    return module.ConnectedToRoblox
end

--// Initialize
module:RetryToConnect()

if not ModuleLoaded and not module.ConnectedToRoblox then
    local Retry = 0

    repeat
        task.wait(Settings.ReconnectDelay)
        Retry += 1

        print(concat({"Retry to connect api (", Retry, " trial)."}))

        module:RetryToConnect()
    until Retry >= Settings.ReconnectCount or module.ConnectedToRoblox
end

ModuleLoaded = true

table.insert(Connections, Players.PlayerAdded:Connect(OnPlayerAdded))
table.insert(Connections, Players.PlayerRemoving:Connect(OnPlayerRemoving))

-- 미리 들어와있는 플레이어들도 있을수 있으니 하는 작업 (완전 종종 그럼)
for _, Player in ipairs(Players:GetPlayers()) do
    task.spawn(OnPlayerAdded, Player)
end

if not IsStudio then
    game:BindToClose(BindToClose)
end

return module :: Types.MainModule