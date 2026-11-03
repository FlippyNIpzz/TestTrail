--!strict

-- Two-phase startup with reverse-order cleanup on failure.
local Lifecycle = {}
function Lifecycle.Run(modules: { any }, context: any): () -> ()
    local prepared: { any } = {}
    local function destroy()
        for index = #prepared, 1, -1 do
            local ok, reason = pcall(prepared[index].Destroy)
            if not ok then warn(reason) end
        end
        table.clear(prepared)
    end
    local ok, reason = xpcall(function()
        for _, feature in modules do
            table.insert(prepared, feature)
            feature.Initialize(context)
        end
        for _, feature in prepared do feature.Start() end
    end, debug.traceback)
    if not ok then destroy(); error(reason) end
    return destroy
end
return Lifecycle
