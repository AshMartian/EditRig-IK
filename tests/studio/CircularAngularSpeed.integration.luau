-- Source fixture: isolated instances are never parented into the open place.
local model=Instance.new('Model')
local part=Instance.new('Part'); part.Parent=model
local other=Instance.new('Part'); other.Parent=model
local motor=Instance.new('Motor6D'); motor.Part0=part; motor.Part1=other; motor.Parent=part
local bone=Instance.new('Bone'); bone.Parent=part
local function rotation(degrees) return CFrame.Angles(0,0,math.rad(degrees)) end
local function point(degrees) local a=math.rad(degrees); return Vector3.new(math.cos(a),math.sin(a),0) end
local function angle(cf) return math.deg(math.atan2(cf.RightVector.Y,cf.RightVector.X)) end
local ok,err=pcall(function()
 local solver=Solver.new(Limits,CircularHinge.v1)
 local bounds={kind='Hinge',axis={0,0,1},circular={version=1,start=math.rad(-150),width=math.rad(300)}}
 for _,joint in ipairs({motor,bone}) do
  joint.Transform=rotation(-140)
  local chain=ChainAdapter.new({joint},Vector3.xAxis,{exclusive=true,limits={bounds}},solver)
  local result=chain:solve(point(140),{iterations=20,tolerance=1e-6,maxAngularSpeed=math.rad(45),dt=1})
  assert(math.abs(angle(joint.Transform)-(-95))<1e-3,'capped '..joint.ClassName..' must take the permitted arc, not the shorter forbidden gap: '..angle(joint.Transform))
  assert(result.motionLimited and math.abs(angle(CFrame.new(0,0,0,unpack(result.rotations[1])))-(-95))<1e-3,'diagnostics must report the applied capped pose')
  chain:destroy()
  -- The same cap may cross the numeric ±180° seam inside an allowed arc.
  joint.Transform=rotation(170)
  local seam={kind='Hinge',axis={0,0,1},circular={version=1,start=math.rad(150),width=math.rad(60)}}
  chain=ChainAdapter.new({joint},Vector3.xAxis,{exclusive=true,limits={seam}},solver)
  chain:solve(point(-160),{iterations=20,tolerance=1e-6,maxAngularSpeed=math.rad(10),dt=1})
  assert(joint.Transform:FuzzyEq(rotation(180),1e-5),'capped rotation must cross the seam inside the allowed arc')
  chain:destroy()
  joint.Transform=rotation(-140)
  chain=ChainAdapter.new({joint},Vector3.xAxis,{exclusive=true,baseMode='animated',limits={bounds}},solver)
  local opts={iterations=20,tolerance=1e-6,maxAngularSpeed=math.rad(45),dt=1}
  chain:solve(point(140),opts)
  joint.Transform=rotation(30) -- the animation has supplied a fresh base
  chain:solve(point(140),opts)
  assert(math.abs(angle(joint.Transform)-(-50))<1e-3,'animated base must cap from the previous applied IK pose')
  chain:destroy()
  joint.Transform=rotation(-170)
  chain=ChainAdapter.new({joint},Vector3.xAxis,{exclusive=true,limits={bounds}},solver)
  local before=joint.Transform
  assert(not pcall(function() chain:solve(point(140),{iterations=20,tolerance=1e-6,maxAngularSpeed=1,dt=.2}) end),'capped solve must reject initial pose outside the allowed arc')
  assert(joint.Transform:FuzzyEq(before,1e-6),'rejected initial pose must remain unchanged')
  chain:destroy()
  joint.Transform=CFrame.Angles(.4,0,0)*rotation(-140)
  chain=ChainAdapter.new({joint},Vector3.xAxis,{exclusive=true,limits={bounds}},solver)
  before=joint.Transform
  assert(not pcall(function() chain:solve(point(140),{iterations=20,tolerance=1e-6,maxAngularSpeed=1,dt=.2}) end),'capped solve must reject off-axis starting swing')
  assert(joint.Transform:FuzzyEq(before,1e-6),'rejected off-axis pose must remain unchanged')
  chain:destroy()
 end
end)
model:Destroy()
assert(ok,err)
return 'circular angular speed limits preserve permitted arcs for Motor6D and Bone'
