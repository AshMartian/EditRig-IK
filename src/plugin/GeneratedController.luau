--!strict
-- Editable per-actor entry point. No updates start automatically.
local Controller={}
local actor=nil
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
function Controller.stop()
 if not actor then return {} end
 local old=actor
 actor=nil
 return old:destroy()
end
return Controller
