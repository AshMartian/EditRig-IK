local storage=Instance.new('Folder'); storage.Name='TestStorage'
local bundle=Instance.new('ModuleScript'); bundle.Name='RuntimeBundle'
local child=Instance.new('ModuleScript'); child.Name='Solver'; child.Parent=bundle
local prepared=RuntimeInstaller.prepare(storage,bundle)
assert(prepared.Parent==nil and prepared.Name=='EditRigIKRuntime' and prepared:FindFirstChild('Solver'),'installer must create a detached runtime copy')
assert(not storage:FindFirstChild('EditRigIKRuntime'),'preparing must not mutate storage')
prepared.Parent=storage
local old=storage:FindFirstChild('EditRigIKRuntime')
assert(not pcall(function() RuntimeInstaller.prepare(storage,bundle) end),'existing runtime must never be overwritten')
assert(storage:FindFirstChild('EditRigIKRuntime')==old and old:FindFirstChild('Solver'),'existing runtime must remain intact')
storage:Destroy(); bundle:Destroy()
return 'Runtime installer preserves existing modules'
