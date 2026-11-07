--!strict
-- Prepare an unparented copy; caller performs the undoable insertion.
local RuntimeInstaller={}
function RuntimeInstaller.prepare(storage,bundle)
 assert(typeof(storage)=='Instance','runtime destination required')
 assert(typeof(bundle)=='Instance' and bundle:IsA('ModuleScript') and bundle.Archivable,'runtime bundle unavailable')
 assert(not storage:FindFirstChild('EditRigIKRuntime'),'EditRigIKRuntime already exists; rename it before installing another')
 local copy=bundle:Clone()
 assert(copy,'could not clone runtime bundle')
 copy.Name='EditRigIKRuntime'
 copy:SetAttribute('EditRigIK_RuntimeSchemaVersion',1)
 return copy
end
return RuntimeInstaller
