-- Run only in a place with Workspace.Dino Auto. The clone stays unparented;
-- no live rig instances, animation controllers, or scripts are modified.
local source=workspace:FindFirstChild('Dino Auto')
assert(source and source.Archivable,'Dino Auto cannot be cloned')
local rig=source:Clone()
local ok,result=pcall(function()
 local results={}
 for _,side in ipairs({'Left','Right'}) do
  local legs=rig:FindFirstChild('Legs')
  local p1=legs:FindFirstChild(side..' Leg 1')
  local p2=legs:FindFirstChild(side..' Leg 2')
  local p3=legs:FindFirstChild(side..' Leg 3')
  local j1=p1:FindFirstChild(side..' Leg 2')
  local j2=p2:FindFirstChild(side..' Leg 3')
  local j3=p3:FindFirstChild(side..' Foot')
  local endpoint=Vector3.zero
  local chain=ChainAdapter.new({j1,j2,j3},endpoint,{exclusive=true},Solver.new(Limits))
  local function fk()
   return j1.Part0.CFrame*j1.C0*j1.Transform*j1.C1:Inverse()*j2.C0*j2.Transform*j2.C1:Inverse()*j3.C0*j3.Transform*j3.C1:Inverse()*CFrame.new(endpoint)
  end
  local target=fk().Position+Vector3.new(.2,.15,-.1)
  local solved=chain:solve(target,{iterations=80,tolerance=.001})
  local discrepancy=(solved.endpointWorld-fk().Position).Magnitude
  assert(solved.converged and discrepancy<.001,side..' leg geometry check failed')
  table.insert(results,side..' error='..solved.error..' FK discrepancy='..discrepancy)
  assert(#chain:destroy()==0)
 end
 return table.concat(results,'\n')
end)
rig:Destroy()
assert(ok,result)
return result
