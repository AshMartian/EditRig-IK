assert(HingeLimitHandles and HingeDragMath and Config and AxisGizmo,'hinge handle dependencies required')
local gui=Instance.new('Folder')
local mouseMove=Instance.new('BindableEvent'); local mouseUp=Instance.new('BindableEvent')
local mouse={Move=mouseMove.Event,Button1Up=mouseUp.Event,UnitRay=Ray.new(Vector3.new(0,0,10),Vector3.new(0,0,-1))}
local parent=Instance.new('Part'); parent.CFrame=CFrame.new(5,4,3)*CFrame.Angles(.3,.4,.2)
local motor=Instance.new('Motor6D'); motor.Part0=parent; motor.C0=CFrame.Angles(.2,.5,-.3)
local original=motor.C0
local changes={}; local focus={}
local h=HingeLimitHandles.new(gui,mouse,Config,HingeDragMath,AxisGizmo.restFrame,function(bound,value) table.insert(changes,{bound,value}) end,function(bound) table.insert(focus,bound) end)
local config={kind='Hinge',axis='Z',lower=-45,upper=45,swing=30}
assert(h:set(motor,config),'rotated Motor6D rest frame supported')
local frame=parent.CFrame*motor.C0
local lower=gui:FindFirstChild('EditRigIKLowerHandle'); local upper=gui:FindFirstChild('EditRigIKUpperHandle')
assert(lower and upper and lower.ClassName~=upper.ClassName,'distinct endpoint handle shapes')
local radius=lower.Radius; h:select('lower'); assert(lower.Radius>radius,'numeric focus visibly enlarges the corresponding handle')
h:select(nil); assert(lower.Radius==radius,'clearing field focus restores normal marker size')
local expected=frame:PointToWorldSpace(Vector3.new(math.cos(math.rad(-45)),math.sin(math.rad(-45)),0))
assert(((parent.CFrame*lower.CFrame).Position-expected).Magnitude<1e-5,'lower marker uses joint rest frame')
local function rayAt(angle)
 local p=frame:PointToWorldSpace(Vector3.new(math.cos(math.rad(angle)),math.sin(math.rad(angle)),0))
 return Ray.new(p+frame.LookVector*10,-frame.LookVector)
end
assert(h:begin('lower',rayAt(-45)))
h:move(rayAt(0)); assert(#changes==1 and changes[1][1]=='lower' and math.abs(changes[1][2])<1e-4,'drag updates lower draft in joint frame')
assert(focus[1]=='lower' and motor.C0==original and motor:GetAttribute('EditRigIK_LowerDegrees')==nil,'drag focuses field and does not mutate source')
local synced={kind='Hinge',axis='Z',lower=0,upper=45,swing=30}
assert(h:sync(motor,synced),'matching numeric field update syncs')
h:move(rayAt(20)); assert(#changes==2 and math.abs(changes[2][2]-20)<1e-4,'matching field sync must preserve the drag')
synced.lower=10; assert(h:sync(motor,synced)); h:move(rayAt(30)); assert(#changes==2,'competing external numeric edit cancels drag')
assert(h:set(motor,config)); assert(h:begin('lower',rayAt(-45)))
h:move(rayAt(-20)); h:cancel(true)
assert(math.abs(changes[#changes][2]+45)<1e-4 and changes[#changes][1]=='lower','Escape-style cancel restores the original draft')
local count=#changes; h:cancel(true); assert(#changes==count,'second cancel has no effect')
assert(h:begin('lower',rayAt(-45))); h:move(rayAt(-15)); count=#changes; h:cancel(); assert(#changes==count,'normal cancellation retains draft')
assert(h:set(motor,{kind='Hinge',axis='Z',lower=-180,upper=180,swing=30}))
assert(((parent.CFrame*lower.CFrame).Position-(parent.CFrame*upper.CFrame).Position).Magnitude>.25,'coincident angular bounds have independently clickable radial positions')
assert(h:set(motor,config)); assert(h:begin('lower',rayAt(-45)))
parent.CFrame=parent.CFrame*CFrame.new(1,0,0); count=#changes
assert(not h:move(rayAt(-20)) and #changes==count,'frame movement interrupts drag without emitting a draft')
parent.CFrame=frame*motor.C0:Inverse()
local bone=Instance.new('Bone'); bone.CFrame=CFrame.Angles(.3,.2,.1); bone.Parent=parent
assert(h:set(bone,config),'Bone rest frame supported')
local boneframe=parent.CFrame*bone.CFrame
assert(((parent.CFrame*lower.CFrame).Position-boneframe:PointToWorldSpace(Vector3.new(math.cos(math.rad(-45)),math.sin(math.rad(-45)),0))).Magnitude<1e-5,'Bone local frame used')
assert(h:begin('lower',Ray.new(boneframe:PointToWorldSpace(Vector3.new(1,0,10)),boneframe:VectorToWorldSpace(Vector3.new(0,0,-1)))))
bone.Parent=nil; count=#changes; h:move(Ray.new(Vector3.new(0,0,10),Vector3.new(0,0,-1))); assert(#changes==count,'missing joint frame cancels without draft callback')
h:destroy(); h:destroy(); assert(#gui:GetChildren()==0,'destroy removes handle adornments')
mouseMove:Destroy(); mouseUp:Destroy(); parent:Destroy(); gui:Destroy()
return 'Hinge limit handles passed'
