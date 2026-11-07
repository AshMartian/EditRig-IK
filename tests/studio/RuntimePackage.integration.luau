-- RuntimeSource and RuntimeComponents are supplied by the source-level test harness.
local storage=Instance.new('Folder')
local bundle=Instance.new('ModuleScript'); bundle.Name='RuntimeBundle'; bundle.Source=RuntimeSource
for name,source in pairs(RuntimeComponents) do
 local child=Instance.new('ModuleScript'); child.Name=name; child.Source=source; child.Parent=bundle
end
local copy=RuntimeInstaller.prepare(storage,bundle); copy.Parent=storage
local runtime=require(copy)
local identity={0,0,0,1}
local solved=runtime.solve({root={0,0,0},joints={{rest=identity,rotation=identity,offset={1,0,0}}}},{0,1,0},{iterations=5,tolerance=.001})
assert(solved.converged and solved.error<.001,'installed cloned runtime must be requireable and solve')
assert(type(runtime.createFootstepChain)=='function' and type(runtime.createActor)=='function','installed API must include actor and footstep factories')
assert(type(runtime.InputBindings.new)=='function','installed runtime must include InputAction bindings')
assert(type(runtime.createTargetStepper)=='function','installed runtime must include target stepper')
assert(not pcall(function() RuntimeInstaller.prepare(storage,bundle) end),'second installation must not overwrite')
storage:Destroy(); bundle:Destroy()
return 'Cloned runtime package loads and solves in Studio'
