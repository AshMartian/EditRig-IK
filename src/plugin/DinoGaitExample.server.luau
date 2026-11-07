-- Disabled by default. This experimental script is explicitly started by its owner.
local rig=script.Parent
local old=rig:FindFirstChild('Script')
assert(not old or not old:IsA('Script') or old.Disabled,'Disable the original Dino gait script before enabling this example')
local IK=require(game:GetService('ReplicatedStorage'):WaitForChild('EditRigIKRuntime'))
local SmoothGait=require(script:WaitForChild('DinoSmoothGait'))
local gait=SmoothGait.new(rig,IK,{distance=2,forward=2,height=1,duration=.3})
local connection
local function stop()
 if connection then connection:Disconnect(); connection=nil end
 gait:destroy()
end
connection=game:GetService('RunService').Heartbeat:Connect(function(dt)
 local ok,err=pcall(gait.step,gait,dt)
 if not ok then stop(); warn('EditRigIK smooth gait stopped: '..tostring(err)) end
end)
script.Destroying:Connect(stop)
script:GetPropertyChangedSignal('Disabled'):Connect(function() if script.Disabled then stop() end end)
