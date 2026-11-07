local model=Instance.new('Model')
local definition=Instance.new('Folder'); definition.Name='EditRigIKActor'; definition.Parent=model
local chains=Instance.new('Folder'); chains.Name='EditRigIKChains'; chains.Parent=model
local leg=Instance.new('Folder'); leg.Name='Leg'; leg.Parent=chains
local runtime=Instance.new('ModuleScript'); runtime.Name='EditRigIKRuntime'
local started,stopped=0,0
local fakeActor={destroy=function() stopped+=1; return {} end}
local fakeRuntime={createActor=function(arg,options) assert(arg==definition and options and options.exclusive==true); started+=1; return fakeActor end,createConfiguredIKChain=function(arg,options) assert(arg==leg and options.exclusive==true); return 'chain' end,createFootstepChain=function(arg,options) assert(arg==leg and options.exclusive==true); return 'footstep' end}
local fakeStorage={FindFirstChild=function(_,name) if name=='EditRigIKRuntime' then return runtime end end}
local fakeGame={GetService=function(_,name) assert(name=='ReplicatedStorage'); return fakeStorage end}
local controller=GeneratedControllerFactory({Parent=model},fakeGame,function(obj) assert(obj==runtime); return fakeRuntime end)
assert(controller.start({exclusive=true})==fakeActor and controller.start({exclusive=true})==fakeActor and started==1)
assert(controller.get()==fakeActor)
assert(controller.openChain('Leg',{exclusive=true})=='chain')
assert(controller.openFootstep('Leg',{exclusive=true})=='footstep')
assert(#controller.stop()==0 and stopped==1)
assert(not pcall(controller.get),'get should reject an actor that has not started')
model:Destroy(); runtime:Destroy()
return 'Generated controller lifecycle passed'
