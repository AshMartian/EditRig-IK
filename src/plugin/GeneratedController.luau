--!strict
-- Editable per-actor entry point. No updates start automatically.
local Controller={}
local actor=nil
local connection=nil
local handlingError=false
local function getRuntime()
 local runtime=game:GetService('ReplicatedStorage'):FindFirstChild('EditRigIKRuntime')
 assert(runtime and runtime:IsA('ModuleScript'), 'Install EditRigIKRuntime in ReplicatedStorage first')
 return require(runtime)
end
function Controller.openChain(name, options)
 assert(type(name)=='string' and name~='', 'chain name is required')
 local folder=script.Parent:FindFirstChild('EditRigIKChains')
 local definition=folder and folder:FindFirstChild(name)
 assert(definition and definition:IsA('Folder'), 'named IK chain definition is missing')
 return getRuntime().createConfiguredIKChain(definition,options)
end
function Controller.openFootstep(name, options)
 assert(type(name)=='string' and name~='', 'chain name is required')
 local folder=script.Parent:FindFirstChild('EditRigIKChains')
 local definition=folder and folder:FindFirstChild(name)
 assert(definition and definition:IsA('Folder'), 'named IK chain definition is missing')
 return getRuntime().createFootstepChain(definition,options)
end
function Controller.start(options)
 if actor then return actor end
 local definition=script.Parent:FindFirstChild('EditRigIKActor')
 assert(definition, 'EditRigIKActor definition is missing')
 actor=getRuntime().createActor(definition,options)
 return actor
end
function Controller.get()
 assert(actor, 'Start the actor before using its controls')
 return actor
end
-- Explicit opt-in; no update connection exists until run() is called.
function Controller.run(options,onError)
 assert(not connection and not handlingError,'actor update loop is running or handling an error')
 assert(onError==nil or type(onError)=='function','onError must be a function')
 local signal=game:GetService('RunService').PreSimulation
 local existed=actor~=nil
 local current=Controller.start(options)
 local ownConnection
 local ok,result=pcall(function()
  return signal:Connect(function(dt)
   if connection~=ownConnection then return end
   local stepped,message=pcall(current.step,current,dt)
   if stepped then return end
   ownConnection:Disconnect(); connection=nil
   handlingError=true
   if onError then
    local notified,notifyError=pcall(onError,tostring(message))
    if not notified then warn('EditRigIK error handler failed: '..tostring(notifyError)) end
   else warn('EditRigIK actor update failed: '..tostring(message)) end
   if actor==current then
    local stopped,stopError=pcall(Controller.stop)
    if not stopped then warn('EditRigIK actor cleanup failed: '..tostring(stopError)) end
    if stopped and #stopError>0 then warn('EditRigIK actor cleanup left externally changed joints: '..table.concat(stopError,', ')) end
   end
   handlingError=false
  end)
 end)
 if not ok then
  if not existed then pcall(Controller.stop) end
  error(result)
 end
 ownConnection=result; connection=result
 return current
end
function Controller.stop()
 if connection then connection:Disconnect(); connection=nil end
 if not actor then return {} end
 local old=actor
 actor=nil
 return old:destroy()
end
return Controller
