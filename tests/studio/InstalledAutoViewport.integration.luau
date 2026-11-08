-- Run manually in Studio Edit with the installed plugin panel open and idle.
-- This exercises selection-driven UI and restores the prior selection and
-- draft. It does not simulate a physical drag or prove mouse-event capture.
local run=game:GetService('RunService')
local selection=game:GetService('Selection')
local input=game:GetService('UserInputService')
local gui=game:GetService('PluginGuiService').PluginGui:FindFirstChild('EditRigPanel')
assert(run:IsEdit() and gui and gui:FindFirstChild('JointsPage'),'open the installed EditRig IK panel in Edit mode')
assert(not input:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and not input:GetFocusedTextBox(),'finish the current pointer or text edit first')
assert(not workspace:FindFirstChild('EditRigIKAutoModeFixture'),'remove the previous fixture first')
local old=selection:Get()
local draft={}
for _,field in ipairs(gui.JointsPage:GetDescendants()) do
 if field:IsA('TextBox') and field.Name:sub(-5)=='Input' then draft[field.Name]=field.Text end
end
local model=Instance.new('Model'); model.Name='EditRigIKAutoModeFixture'
local ok,result=xpcall(function()
 local base=Instance.new('Part'); base.Anchored=true; base.Position=Vector3.new(0,-5000,0); base.Parent=model
 local child=Instance.new('Part'); child.Anchored=true; child.Position=Vector3.new(0,-4998,0); child.Parent=model
 local joint=Instance.new('Motor6D'); joint.Part0=base; joint.Part1=child; joint.Parent=base
 model.Parent=workspace
 local initial=base.CFrame
 selection:Set({model}); task.wait(.3)
 assert(gui.JointsPage.EditHingeLimits3D.Text=='Pause 3D joint editing','model selection must arm viewport editing')
 selection:Set({joint}); task.wait(.3)
 local handles=game:GetService('CoreGui'):FindFirstChild('EditRigIKHingeHandles')
 assert(handles and handles:FindFirstChild('EditRigIKLowerHandle') and handles:FindFirstChild('EditRigIKUpperHandle'),'joint selection must display both hinge controls')
 assert(handles:FindFirstChild('EditRigIKLowerLabel') and handles:FindFirstChild('EditRigIKUpperLabel'),'joint selection must display bound labels')
 assert(joint:GetAttribute('EditRigIK_SchemaVersion')==nil,'automatic examples must not save metadata')
 assert(base.CFrame==initial,'selection must not move the fixture')
 return 'Automatic model and hinge controls appeared without writing or moving the rig'
end,debug.traceback)
selection:Set(old); task.wait(.3)
if gui.Parent and #selection:Get()==#old then
 local now=selection:Get(); local same=true
 for i,item in ipairs(old) do if now[i]~=item then same=false end end
 if same then
  for name,value in pairs(draft) do
   local field=gui.JointsPage:FindFirstChild(name,true)
   if field then field.Text=value end
  end
 end
end
model:Destroy()
assert(ok,result)
return result
