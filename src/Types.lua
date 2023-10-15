local DataStoreService = game:GetService("DataStoreService")
--// Extra Types
local DefaultData = require(script.Parent:WaitForChild("DefaultData"))
local Caller = require(script.Parent:WaitForChild("Caller"))

type DefaultData = typeof(DefaultData)
export type Operation = Caller.Operation

--// Main Types
type DataReturnSignal = {
    Connect: (self: DataReturnSignal, Function: (DataStore: DataStore) -> ...any) -> RBXScriptConnection;
    Once: (self: DataReturnSignal, Function: (DataStore: DataStore) -> ...any) -> RBXScriptConnection;
    Wait: (self: DataReturnSignal) -> DataStore;
}

type ChangedSignal = {
    Connect: (self: ChangedSignal, Function: (Property: string, NewValue: any, OldValue: any) -> ...any) -> RBXScriptConnection;
    Once: (self: ChangedSignal, Function: (Property: string, NewValue: any, OldValue: any) -> ...any) -> RBXScriptConnection;
    Wait: (self: ChangedSignal) -> (string, any, any);
}

export type DataStore = DefaultData & {
    -- Methods
    Save: (self: DataStore, Async: boolean?) -> Operation;
    Clear: (self: DataStore) -> ();
    Destroy: (self: DataStore) -> ();
    BindToClose: (self: DataStore, Function: (...any) -> ...any) -> ();

    -- Variables
    IsLoaded: boolean;
    Player: Player;

    -- Events
    AutosaveBegan: DataReturnSignal;
    AutosaveEnded: DataReturnSignal;
    Changed: ChangedSignal;
}

export type MainModule = {
    ConnectedToRoblox: boolean;

    GetData: (self: MainModule, Player: Player) -> DataStore;
    SaveAll: (self: MainModule, Async: boolean?) -> {[Player]: Operation};
    RetryToConnect: (self: MainModule) -> boolean;
}

return nil