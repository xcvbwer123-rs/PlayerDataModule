--// Variables
local module = {}

local Methods = {
    GetResults = true;
    HasError = true;
    IsNull = true;
}

local concat = table.concat

--// Types
export type Operation = {
    Completed: boolean;
    GetResults: () -> ...any;
    HasError: () -> string | false;
    IsNull: () -> boolean;
    OnComplete: ((self: Operation) -> ())?;
}

--// Functions
function module:__index(Key: any)
    if typeof(Key) == "string" and rawget(Methods, Key) and self ~= module then
        return rawget(module, Key)
    end
end

local function MakeError(Message)
    return concat({Message, "\n", debug.traceback(3)})
end

local function Run(Function, Operation, ...)
    local Results = {pcall(Function, ...)}

    if not Results[1] then
        Operation._Error = MakeError(Results[2])
    else
        table.remove(Results, 1)
        Operation._Results = Results
    end

    Operation.Completed = true

    if Operation.OnComplete then
        task.spawn(Operation.OnComplete, Operation)
    end
end

function module:GetResults()
    if self._Error then
        return error(self._Error, 2)
    end

    return table.unpack(self._Results)
end

function module:HasError()
    if self._Error then
        return self._Error
    end

    return false
end

function module:IsNull()
    if self._Error then
        return error(self._Error, 2)
    end

    return #self._Results == 0
end

function module.Run(Function: (...any) -> ...any, Async: boolean?, ...)
    local Operation = setmetatable({Completed = false}, module)

    if Async then
        task.spawn(Run, Function, Operation, ...)
    else
        Run(Function, Operation, ...)
    end

    return Operation
end

return table.freeze(module) :: {Run: (Function: (...any) -> ...any, Async: boolean?, ...any) -> Operation}