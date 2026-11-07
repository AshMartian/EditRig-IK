--!strict
-- Read a saved IK chain snapshot and create an explicitly owned chain.
local ChainDefinition={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
function ChainDefinition.new(definition,options,createChain)
 assert(typeof(definition)=='Instance' and definition:IsA('Folder') and definition:GetAttribute('SchemaVersion')==1,'unsupported chain definition')
 assert(definition.Parent and definition.Parent:IsA('Folder') and definition.Parent.Parent and definition.Parent.Parent:IsA('Model'),'chain definition must belong to a model')
 assert(type(options)=='table' and options.exclusive==true and type(createChain)=='function','explicit ownership and chain factory required')
 local model=definition.Parent.Parent
 local endpointRef=definition:FindFirstChild('Endpoint')
 local list=definition:FindFirstChild('Joints')
 assert(endpointRef and endpointRef:IsA('ObjectValue') and endpointRef.Value and endpointRef.Value.ClassName=='Attachment' and endpointRef.Value:IsDescendantOf(model),'endpoint reference is invalid')
 assert(list and list:IsA('Folder'),'joint references missing')
 local refs=list:GetChildren()
 assert(#refs>0 and #refs<=128,'invalid joint count')
 for _,ref in ipairs(refs) do assert(ref:IsA('ObjectValue') and finite(ref:GetAttribute('Order')),'invalid joint reference') end
 table.sort(refs,function(a,b) return a:GetAttribute('Order')<b:GetAttribute('Order') end)
 local joints,limits={},{}
 local axes={X={1,0,0},Y={0,1,0},Z={0,0,1}}
 for i,ref in ipairs(refs) do
  assert(ref:GetAttribute('Order')==i and ref.Value and ref.Value:IsDescendantOf(model),'invalid joint order or reference')
  local kind,axis=ref:GetAttribute('Kind'),ref:GetAttribute('Axis')
  local lower,upper,swing=ref:GetAttribute('LowerDegrees'),ref:GetAttribute('UpperDegrees'),ref:GetAttribute('SwingDegrees')
  assert((kind=='Hinge' or kind=='Ball') and axes[axis],'invalid joint limit kind or axis')
  assert(finite(lower) and finite(upper) and lower>=-180 and upper<=180 and lower<=upper,'invalid angular limits')
  assert(finite(swing) and swing>=0 and swing<=180,'invalid swing angle')
  table.insert(joints,ref.Value)
  table.insert(limits,{kind=kind,axis=axes[axis],lower=math.rad(lower),upper=math.rad(upper),swing=math.rad(swing)})
 end
 local last=joints[#joints]; local endpoint=endpointRef.Value
 assert(endpoint.Parent==(if last:IsA('Motor6D') then last.Part1 else last),'endpoint parent does not match chain')
 local iterations,tolerance=definition:GetAttribute('Iterations'),definition:GetAttribute('Tolerance')
 local maxStepDegrees=definition:GetAttribute('MaxStepDegrees')
 if maxStepDegrees==nil then maxStepDegrees=180 end -- schema 1 definitions created before this option
 assert(finite(iterations) and iterations%1==0 and iterations>=1 and iterations<=1000,'invalid iterations')
 assert(finite(tolerance) and tolerance>=0,'invalid tolerance')
 assert(finite(maxStepDegrees) and maxStepDegrees>0 and maxStepDegrees<=180,'invalid maximum correction angle')
 local endpointParent,endpointPosition=endpoint.Parent,endpoint.Position
 local chain=createChain(joints,endpointPosition,{exclusive=true,limits=limits})
 local api={}
 function api:solve(target,overrides)
  assert(endpointRef.Value==endpoint and endpoint.Parent==endpointParent and (endpoint.Position-endpointPosition).Magnitude<1e-6,'endpoint changed; recreate the chain')
  assert(overrides==nil or type(overrides)=='table','solver overrides must be a table')
  local settings={iterations=iterations,tolerance=tolerance,maxStep=math.rad(maxStepDegrees)}
  if overrides then
   for key,value in pairs(overrides) do
    assert(key=='iterations' or key=='tolerance' or key=='maxStep','unknown solver option: '..tostring(key))
    settings[key]=value
   end
  end
  return chain:solve(target,settings)
 end
 function api:destroy() return chain:destroy() end
 return api
end
return ChainDefinition
