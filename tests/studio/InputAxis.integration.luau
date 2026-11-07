local model=Instance.new('Model'); local motor=Instance.new('Motor6D'); motor.Parent=model
local folder=Instance.new('Folder'); folder.Parent=model; folder:SetAttribute('EditRigIK_ActorSchemaVersion',1)
local ref=Instance.new('ObjectValue'); ref.Name='Jaw'; ref.Value=motor; ref.Parent=folder
ref:SetAttribute('Kind','Hinge'); ref:SetAttribute('Axis','Z'); ref:SetAttribute('LowerDegrees',-90); ref:SetAttribute('UpperDegrees',90)
ref:SetAttribute('Control','Jaw'); ref:SetAttribute('Frequency',4)
local actor=ActorRig.new(folder,{Actor=Actor,JointDrive=JointDrive,JointAdapter=JointAdapter})
local context=Instance.new('InputContext')
local function action()
 local a=Instance.new('InputAction'); a.Type=Enum.InputActionType.Bool; a.Parent=context
 local b=Instance.new('InputBinding'); b.Type=Enum.InputBindingType.Scriptable; b.Parent=a
 return a,b
end
local negative,n=action(); local positive,p=action()
local bindings=InputBindings.new(actor)
assert(not pcall(function() bindings:bindAxis(negative,negative,'Jaw',.5) end),'axis needs distinct actions')
local handle=bindings:bindAxis(negative,positive,'Jaw',.5)
assert(not pcall(function() bindings:bindHold(positive,'Jaw',1) end),'axis must claim the control')
local function expect(angle)
 task.wait(); actor:step(.01)
 assert(motor.Transform:FuzzyEq(CFrame.Angles(0,0,math.rad(angle)),1e-5),'axis produced an unexpected joint pose')
end
n:Fire(true); expect(-45)
p:Fire(true); expect(0)
n:Fire(false); expect(45)
p:Fire(false); expect(0)
n:Fire(true); expect(-45)
handle:destroy(); expect(0)
local second=bindings:bindAxis(negative,positive,'Jaw',.5); expect(-45)
positive.Type=Enum.InputActionType.Direction1D; expect(0)
assert(not pcall(function() bindings:bindAxis(negative,positive,'Jaw',.5) end),'changed action type must be rejected')
second:destroy(); bindings:destroy(); actor:destroy(); context:Destroy(); model:Destroy()
local ballModel=Instance.new('Model'); local ballPart=Instance.new('Part'); ballPart.Parent=ballModel
local bone=Instance.new('Bone'); bone.Parent=ballPart
local ballFolder=Instance.new('Folder'); ballFolder.Parent=ballModel; ballFolder:SetAttribute('EditRigIK_ActorSchemaVersion',1)
local ballRef=Instance.new('ObjectValue'); ballRef.Name='Neck'; ballRef.Value=bone; ballRef.Parent=ballFolder
ballRef:SetAttribute('Kind','Ball'); ballRef:SetAttribute('Axis','X'); ballRef:SetAttribute('LowerDegrees',-90); ballRef:SetAttribute('UpperDegrees',90)
ballRef:SetAttribute('SwingDegrees',90); ballRef:SetAttribute('Control','Neck'); ballRef:SetAttribute('Frequency',4)
local ballActor=ActorRig.new(ballFolder,{Actor=Actor,JointDrive=JointDrive,JointAdapter=JointAdapter,BallDrive={new=function(o) return BallDrive.new(o,Limits) end}})
local ballContext=Instance.new('InputContext')
local left=Instance.new('InputAction'); left.Type=Enum.InputActionType.Bool; left.Parent=ballContext
local right=Instance.new('InputAction'); right.Type=Enum.InputActionType.Bool; right.Parent=ballContext
local leftInput=Instance.new('InputBinding'); leftInput.Type=Enum.InputBindingType.Scriptable; leftInput.Parent=left
local ballInputs=InputBindings.new(ballActor); ballInputs:bindAxis(left,right,'Neck',{.3,0,0})
leftInput:Fire(true); task.wait(); ballActor:step(.01)
assert(bone.Transform:FuzzyEq(CFrame.Angles(-.3,0,0),1e-5),'axis must support signed Bone vector controls')
right:Destroy(); task.wait(); ballActor:step(.01)
assert(bone.Transform:FuzzyEq(CFrame.identity,1e-5),'destroying either action must release the axis')
ballInputs:destroy(); ballActor:destroy(); ballContext:Destroy(); ballModel:Destroy()
return 'Paired actions drive an axis and safely reset it'
