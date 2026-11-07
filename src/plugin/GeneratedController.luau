--!strict
-- Editable per-actor entry point. No updates start automatically.
local Controller={}
local actor=nil
function Controller.start(options)
 if actor then return actor end
 local definition=script.Parent:FindFirstChild('EditRigIKActor')
 assert(definition, 'EditRigIKActor definition is missing')
 local runtime=game:GetService('ReplicatedStorage'):FindFirstChild('EditRigIKRuntime')
 assert(runtime and runtime:IsA('ModuleScript'), 'Install EditRigIKRuntime in ReplicatedStorage first')
 actor=require(runtime).createActor(definition,options)
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
