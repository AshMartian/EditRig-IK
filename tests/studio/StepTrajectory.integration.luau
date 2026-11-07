local model=Instance.new('Model')
local base=Instance.new('Part'); base.Parent=model
local middle=Instance.new('Part'); middle.Parent=model
local tip=Instance.new('Part'); tip.Parent=model
local m1=Instance.new('Motor6D'); m1.Part0=base; m1.Part1=middle; m1.Parent=base
local m2=Instance.new('Motor6D'); m2.Part0=middle; m2.Part1=tip; m2.C0=CFrame.new(1,0,0); m2.Parent=middle
local b1=Instance.new('Bone'); b1.Parent=base
local b2=Instance.new('Bone'); b2.CFrame=CFrame.new(1,0,0); b2.Parent=b1
for _,joints in ipairs({{m1,m2},{b1,b2}}) do
 local chain=ChainAdapter.new(joints,Vector3.xAxis,{exclusive=true},Solver.new(Limits))
 local step=StepTrajectory.new({start={1,1,0},target={1.1,.9,0},up={0,1,0},height=.1,duration=1})
 for i=0,10 do
  local point,done=step:sample(i/10)
  local target=Vector3.new(point[1],point[2],point[3])
  local result=chain:solve(target,{iterations=100,tolerance=.001})
  assert(result.converged and (result.endpointWorld-target).Magnitude<.002,'trajectory target must be solvable by fixture chain')
  assert(done==(i==10))
 end
 local actor=Actor.new({behaviors={{name='step',type='footstep',options={start={1,1,0},up={0,1,0},height=.1,duration=1,impulse='Step'}}}}, {footstep=function(options) return FootstepBehavior.new(options,StepTrajectory) end})
 actor:impulse('Step',{1.1,.9,0})
 for _=1,10 do
  local output=actor:step({},.1)[1].value
  local pos=output.position
  assert(chain:solve(Vector3.new(pos[1],pos[2],pos[3]),{iterations=100,tolerance=.001}).converged,'actor-driven footstep must solve')
 end
 actor:destroy()
 assert(#chain:destroy()==0)
end
model:Destroy()
return 'Trajectory targets drive Motor6D and Bone fixture chains'
