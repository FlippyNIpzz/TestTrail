local count = 0
local function check(name, callback)
    local ok, err = pcall(callback)
    assert(ok, name .. ": " .. tostring(err))
    count += 1
end
local function tick() clock += 1 end
local function state(p)
    tick(); local ok, result = Service.GetState(p or admin); assert(ok, tostring(result)); return result
end
local function prepare(kind, id, value, p)
    local s = state(p); tick()
    local ok, result = Service.Prepare(p or admin, kind, id, value, s.Revision)
    assert(ok, tostring(result)); return result
end
local function commit(pending, p)
    tick(); return Service.Commit(p or admin, pending.Token, pending.RequestId)
end
Service.Initialize(context)
check("authorization and owner policy", function()
    assert(Service.IsAdmin(admin) and Service.IsAdmin(other) and Service.IsAdmin(creator))
    assert(not Service.IsAdmin(outsider)); Config.AllowExperienceOwner=false; assert(not Service.IsAdmin(creator)); Config.AllowExperienceOwner=true
end)
check("unauthorized direct calls cannot mutate or inspect", function()
    for _, action in {function() return Service.GetState(outsider) end, function() return Service.Prepare(outsider,"Toggle","generation",false,1) end, function() return Service.Commit(outsider,"forged",1) end} do
        local ok, code=action(); assert(not ok and code=="Forbidden")
    end
    assert(enabled and calls==0)
end)
check("allowlisted projection", function()
    local s=state(); assert(s.AdminUserIds==nil and s.Models[1].Options[1].Level==nil and s.Models[1].Options[1].Path==nil)
    assert(s.Features[1].Enabled and s.Models[1].Current=="base.level_1")
end)
check("prepare requires confirmation without changing state", function()
    local pending=prepare("Toggle","generation",false); assert(enabled and calls==0 and pending.Token and pending.Description)
end)
local first
check("confirmed toggle and duplicate replay", function()
    first=prepare("Toggle","generation",false); assert(commit(first)); assert(not enabled and calls==1)
    assert(commit(first)); assert(calls==1)
end)
check("reused request ID with different token rejected", function()
    tick(); local ok,code=Service.Commit(admin,"different",first.RequestId); assert(not ok and code=="RequestIdConflict" and calls==1)
end)
check("another admin observes and changes state", function()
    assert(not state(other).Features[1].Enabled)
    local pending=prepare("Toggle","generation",true,other); assert(commit(pending,other)); assert(state().Features[1].Enabled)
end)
check("stale confirmation rejected after other admin change", function()
    local old=prepare("Model","plot","base.level_2")
    assert(commit(prepare("Toggle","generation",false,other),other))
    local ok,code=commit(old); assert(not ok and code=="StaleState" and style=="base.level_1")
end)
check("model option allowlist enforced", function()
    local s=state(); tick(); local ok,code=Service.Prepare(admin,"Model","plot","rbxassetid://123",s.Revision)
    assert(not ok and code=="UnapprovedModel" and style=="base.level_1")
end)
check("confirmed model replacement", function()
    assert(commit(prepare("Model","plot","base.level_2"))); assert(style=="base.level_2")
    assert(state(other).Models[1].Current==style)
end)
check("ordinary ownership changes invalidate confirmation", function()
    local pending=prepare("Model","plot","base.level_1"); owner=8
    local ok,code=commit(pending); assert(not ok and code=="StaleState" and style=="base.level_2"); owner=7
end)
check("adapter failure preserves model", function()
    failModel=true; local ok,code=commit(prepare("Model","plot","base.level_1")); failModel=false
    assert(not ok and code=="ModelPreparationFailed" and style=="base.level_2")
end)
check("expiry rejects mutation", function()
    local pending=prepare("Model","plot","base.level_1"); clock+=31
    local ok,code=commit(pending); assert(not ok and code=="ConfirmationExpired" and style=="base.level_2")
end)
check("forged confirmation rejected", function()
    local s=state(); tick(); local ok,code=Service.Commit(admin,"forged",s.NextRequestId); assert(not ok and code=="InvalidConfirmation")
end)
check("malformed requests are harmless", function()
    for _,values in {{"Unknown","generation",true},{"Toggle",{},true},{"Toggle","generation",1},{"Model","unknown","x"},{"Toggle","generation",true}} do
        local s=state(); tick(); local rev=if values[1]=="Toggle" and values[3]==true and values[2]=="generation" then 0/0 else s.Revision
        assert(not Service.Prepare(admin,values[1],values[2],values[3],rev))
    end
    assert(not Service.Commit(admin,{},1)); assert(not Service.Commit(admin,"x",0/0)); assert(not Service.Commit(admin,"x",math.huge))
end)
check("rate limits and stale sequences", function()
    state(); local ok,code=Service.GetState(admin); assert(not ok and code=="RateLimited")
    tick(); local _,pending=Service.Prepare(admin,"Model","plot","base.level_1",state().Revision)
    local limited,why=Service.Prepare(admin,"Model","plot","base.level_1",1); assert(not limited and why=="RateLimited")
    tick(); local stale,reason=Service.Commit(admin,"x",1); assert(not stale and reason=="StaleRequest")
end)
check("vacant target rejected", function()
    owner=0; local s=state(); tick(); local ok,code=Service.Prepare(admin,"Model","plot","base.level_1",s.Revision); assert(not ok and code=="TargetUnavailable"); owner=7
end)
check("unavailable features are not silently enabled", function()
    Service.Destroy(); Service.Initialize({GameConfig={Features={}}}); local s=state(); assert(not s.Features[1].Supported and not s.Models[1].Available)
    tick(); local ok,code=Service.Prepare(admin,"Toggle","generation",true,s.Revision); assert(not ok and code=="Unsupported")
end)
check("cleanup removes session request state", function()
    Service.Forget(admin); assert(state().NextRequestId==1); Service.Destroy()
end)
return tostring(count) .. " admin policy tests passed"
