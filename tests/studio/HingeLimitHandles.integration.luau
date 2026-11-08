assert(HingeLimitHandles and HingeDragMath and Config and AxisGizmo,'hinge handle dependencies required')
local gui=Instance.new('Folder')
local mouseMove=Instance.new('BindableEvent'); local mouseUp=Instance.new('BindableEvent')
local mouse={Move=mouseMove.Event,Button1Up=mouseUp.Event,UnitRay=Ray.new(Vector3.new(0,0,10),Vector3.new(0,0,-1))}
local parent=Instance.new('Part'); parent.CFrame=CFrame.new(5,4,3)*CFrame.Angles(.3,.4,.2)
local motor=Instance.new('Motor6D'); motor.Part0=parent; motor.C0=CFrame.Angles(.2,.5,-.3)
local original=motor.C0
local changes={}; local focus={}
local h=HingeLimitHandles.new(gui,mouse,Config,HingeDragMath,AxisGizmo.restFrame,function(bound,value,circular,restore) table.insert(changes,{bound,value,circular,restore}) end,function(bound) table.insert(focus,bound) end)
local config={kind='Hinge',axis='Z',lower=-45,upper=45,swing=30}
assert(h:set(motor,config),'rotated Motor6D rest frame supported')
local frame=parent.CFrame*motor.C0
local lower=gui:FindFirstChild('EditRigIKLowerHandle'); local upper=gui:FindFirstChild('EditRigIKUpperHandle')
assert(lower and upper and lower.ClassName~=upper.ClassName,'distinct endpoint handle shapes')
local lowerGui=gui:FindFirstChild('EditRigIKLowerLabel'); local upperGui=gui:FindFirstChild('EditRigIKUpperLabel')
assert(lowerGui and upperGui and lowerGui:IsA('BillboardGui') and upperGui:IsA('BillboardGui'),'screen-facing bound labels exist')
assert(lowerGui.Label.Text=='Lower Z -45.0°' and upperGui.Label.Text=='Upper Z 45.0°','labels identify the local axis and bounds')
assert(lower.Color3==Color3.fromRGB(80,145,255) and upper.Color3==lower.Color3,'Z handles match the blue local Z axis')
for _,pair in ipairs({{'X',Color3.fromRGB(255,75,75)},{'Y',Color3.fromRGB(75,255,100)}}) do
 local changed={kind='Hinge',axis=pair[1],lower=-45,upper=45,swing=30}
 assert(h:sync(motor,changed),'valid axis edit is reflected immediately')
 assert(lower.Color3==pair[2] and upper.Color3==pair[2],'both handles follow the chosen local axis color')
 assert(lowerGui.Label.Text:find('Lower '..pair[1],1,true) and upperGui.Label.Text:find('Upper '..pair[1],1,true),'both labels identify the chosen local axis')
end
assert(h:sync(motor,config),'restore the original Z axis')
assert(lowerGui.Adornee==parent and (parent.CFrame:PointToWorldSpace(lowerGui.StudsOffsetWorldSpace)-(parent.CFrame*lower.CFrame).Position).Magnitude<1e-5,'label offset compensates for the adornee rotation used by the BillboardGui renderer')
assert((parent.CFrame:PointToWorldSpace(upperGui.StudsOffsetWorldSpace)-(parent.CFrame*upper.CFrame).Position).Magnitude<1e-5,'upper label uses the same rotated-adornee correction')
local radius=lower.Radius; h:select('lower'); assert(lower.Radius>radius,'numeric focus visibly enlarges the corresponding handle')
h:select(nil); assert(lower.Radius==radius,'clearing field focus restores normal marker size')
local expected=frame:PointToWorldSpace(Vector3.new(math.cos(math.rad(-45)),math.sin(math.rad(-45)),0))
assert(((parent.CFrame*lower.CFrame).Position-expected).Magnitude<1e-5,'lower marker uses joint rest frame')
local function rayAt(angle)
 local p=frame:PointToWorldSpace(Vector3.new(math.cos(math.rad(angle)),math.sin(math.rad(angle)),0))
 return Ray.new(p+frame.LookVector*10,-frame.LookVector)
end
assert(h:begin('lower',rayAt(-45)))
h:move(rayAt(0)); assert(lowerGui.Label.Text=='Lower Z 0.0°','label updates while dragging'); assert(#changes==1 and changes[1][1]=='lower' and math.abs(changes[1][2])<1e-4,'drag updates lower draft in joint frame')
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
-- Legacy hinges promote atomically only when an endpoint crosses the seam.
assert(h:set(motor,{kind='Hinge',axis='Z',lower=-90,upper=170,swing=30}))
assert(h:begin('upper',rayAt(170))); assert(h:move(rayAt(-170)))
local crossing=changes[#changes]
assert(crossing[3] and math.abs(crossing[3].start+90)<1e-4 and math.abs(crossing[3].width-280)<1e-4,'crossing promotes to a circular interval')
assert(math.abs(crossing[2]+170)<1e-4,'dragged endpoint crosses seam without jumping or clamping')
h:cancel(true)
local restored=changes[#changes]
assert(not restored[3] and restored[4] and restored[4].lower==-90 and restored[4].upper==170,'cancel restores both legacy bounds and demotes')
assert(h:set(motor,{kind='Hinge',axis='Z',lower=150,upper=-150,swing=30,circular={start=150,width=60}}))
assert(h:begin('upper',rayAt(-150))); assert(h:move(rayAt(-140)))
assert(math.abs(changes[#changes][3].width-70)<1e-4,'existing circular interval remains circular')
h:cancel(true); assert(math.abs(changes[#changes][3].width-60)<1e-4,'cancel restores original circular interval')
assert(changes[#changes][4] and changes[#changes][4].lower==150 and changes[#changes][4].upper==-150,'circular cancel also returns original displayed endpoints')
assert(h:set(motor,config)); assert(h:begin('lower',rayAt(-45)))
parent.CFrame=parent.CFrame*CFrame.new(1,0,0); count=#changes
assert(not h:move(rayAt(-20)) and #changes==count,'frame movement interrupts drag without emitting a draft')
parent.CFrame=frame*motor.C0:Inverse()
local bone=Instance.new('Bone'); bone.CFrame=CFrame.Angles(.3,.2,.1); bone.Parent=parent
assert(h:set(bone,config),'Bone rest frame supported')
local boneframe=parent.CFrame*bone.CFrame
assert((parent.CFrame:PointToWorldSpace(lowerGui.StudsOffsetWorldSpace)-(parent.CFrame*lower.CFrame).Position).Magnitude<1e-5,'Bone labels also compensate for rotated ancestor parts')
assert(((parent.CFrame*lower.CFrame).Position-boneframe:PointToWorldSpace(Vector3.new(math.cos(math.rad(-45)),math.sin(math.rad(-45)),0))).Magnitude<1e-5,'Bone local frame used')
assert(h:begin('lower',Ray.new(boneframe:PointToWorldSpace(Vector3.new(1,0,10)),boneframe:VectorToWorldSpace(Vector3.new(0,0,-1)))))
bone.Parent=nil; count=#changes; h:move(Ray.new(Vector3.new(0,0,10),Vector3.new(0,0,-1))); assert(#changes==count,'missing joint frame cancels without draft callback')
h:destroy(); h:destroy(); assert(#gui:GetChildren()==0,'destroy removes handle adornments')
mouseMove:Destroy(); mouseUp:Destroy(); parent:Destroy(); gui:Destroy()
return 'Hinge limit handles passed'
