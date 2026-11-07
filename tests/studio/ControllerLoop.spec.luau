local model=Instance.new('Model'); local definition=Instance.new('Folder'); definition.Name='EditRigIKActor'; definition.Parent=model
local runtime=Instance.new('ModuleScript'); runtime.Name='EditRigIKRuntime'
local tick=Instance.new('BindableEvent')
local count,stopped=0,0; local fail=false
local fakeActor={step=function(_,dt) assert(dt==.1); count+=1; if fail then error('conflicting writer') end end,destroy=function() stopped+=1; return {} end}
local fakeRuntime={createActor=function(arg,options) assert(arg==definition and options.exclusive); return fakeActor end}
local fakeStorage={FindFirstChild=function(_,name) if name=='EditRigIKRuntime' then return runtime end end}
local fakeGame={GetService=function(_,name) if name=='ReplicatedStorage' then return fakeStorage elseif name=='RunService' then return {PreSimulation=tick.Event} end error('unexpected service') end}
local controller=GeneratedControllerFactory({Parent=model},fakeGame,function(obj) assert(obj==runtime); return fakeRuntime end)
local problem=nil
assert(controller.run({exclusive=true},function(message) problem=message end)==fakeActor,'run returns actor')
assert(not pcall(function() controller.run({exclusive=true}) end),'duplicate update loop must be rejected')
tick:Fire(.1); task.wait(); assert(count==1,'signal should step actor')
controller.stop(); tick:Fire(.1); task.wait(); assert(count==1 and stopped==1,'stop disconnects before destroying actor')
controller.run({exclusive=true},function(message) problem=message end)
fail=true; tick:Fire(.1); task.wait()
assert(count==2 and stopped==2 and problem and string.find(problem,'conflicting writer',1,true),'failed update must notify and clean up')
tick:Fire(.1); task.wait(); assert(count==2,'failed loop must be disconnected')
assert(not pcall(controller.get),'failed loop must release actor')
tick:Destroy(); runtime:Destroy(); model:Destroy()
return 'Generated controller starts, stops, and cleans up a failed update loop'
