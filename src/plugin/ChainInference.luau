--!strict
-- Read-only selected-joint inference. An endpoint is an existing Attachment;
-- callers can present errors and request explicit choices instead of guessing.
local ChainInference={}
local function failure(reason,message) return {ok=false,reason=reason,message=message} end
local function belongs(value,model)
 return typeof(value)=='Instance' and value:IsDescendantOf(model)
end
local function jointKind(value)
 if typeof(value)~='Instance' then return nil end
 if value:IsA('Motor6D') then return 'Motor6D' end
 if value:IsA('Bone') then return 'Bone' end
 return nil
end

function ChainInference.infer(model,selected,options)
 options=options or {}
 if typeof(model)~='Instance' or not model:IsA('Model') then return failure('invalid_model','Select a model.') end
 local kind=jointKind(selected)
 if not kind or not belongs(selected,model) then return failure('invalid_selection','Select a Motor6D or Bone in the model.') end
 local explicitRoot,explicitEndpoint=options.root,options.endpoint
 if explicitRoot and (not belongs(explicitRoot,model) or jointKind(explicitRoot)~=kind) then
  return failure('invalid_root','The explicit root must be a joint of the same type in the model.')
 end
 if explicitEndpoint and (not belongs(explicitEndpoint,model) or explicitEndpoint.ClassName~='Attachment') then
  return failure('invalid_endpoint','The explicit endpoint must be an Attachment in the model.')
 end
 local before,after,invalid={},{},{}
 local function add(map,key,value)
  local list=map[key] or {}; map[key]=list; table.insert(list,value)
 end
 if kind=='Motor6D' then
  for _,j in ipairs(model:GetDescendants()) do
   if j:IsA('Motor6D') and j.Enabled then
    local a,b=j.Part0,j.Part1
    if a and b and belongs(a,model) and belongs(b,model) then add(after,a,j); add(before,b,j)
    else
     if a and belongs(a,model) then invalid[a]=true end
     if b and belongs(b,model) then invalid[b]=true end
    end
   end
  end
  if not selected.Enabled or not selected.Part0 or not selected.Part1 or not belongs(selected.Part0,model) or not belongs(selected.Part1,model) then
   return failure('invalid_joint','Selected Motor6D is disabled or has missing or external parts.')
  end
  if explicitRoot and (not explicitRoot.Enabled or not explicitRoot.Part0 or not explicitRoot.Part1 or not belongs(explicitRoot.Part0,model) or not belongs(explicitRoot.Part1,model)) then
   return failure('invalid_root','The explicit root is disabled or has missing or external parts.')
  end
 else
  for _,j in ipairs(model:GetDescendants()) do
   if j:IsA('Bone') and j.Parent and j.Parent:IsA('Bone') then add(after,j.Parent,j); add(before,j,j.Parent) end
  end
 end
 local function start(j) return if kind=='Motor6D' then j.Part0 else j end
 local function finish(j) return if kind=='Motor6D' then j.Part1 else j end
 local function nextNode(j,forward)
  if kind=='Motor6D' then return if forward then j.Part1 else j.Part0 end
  return j
 end
 local selectedStart,selectedEnd=start(selected),finish(selected)
 local terminal=if explicitEndpoint then explicitEndpoint.Parent else nil
 if terminal and ((kind=='Motor6D' and not terminal:IsA('BasePart')) or (kind=='Bone' and not terminal:IsA('Bone'))) then
  return failure('invalid_endpoint','The endpoint must be attached directly to the terminal part or Bone.')
 end
 -- Find a unique directed path in one direction, optionally stopping at a
 -- requested node. Do not discard malformed incident motors or cycles.
 local function walk(origin,target,forward)
  local paths={}; local cyclic=false; local malformed=false; local explored=0; local tooLong=false
  local function visit(node,path,seen)
   explored+=1
   if explored>10000 or #path>128 then tooLong=true; return end
   if invalid[node] then malformed=true end
   if target and node==target then table.insert(paths,table.clone(path)); return end
   local edges=(if forward then after else before)[node] or {}
   if not target and #edges==0 then table.insert(paths,table.clone(path)); return end
   for _,edge in ipairs(edges) do
    local nextPart=nextNode(edge,forward)
    if seen[nextPart] then cyclic=true
    else
     seen[nextPart]=true; table.insert(path,edge)
     visit(nextPart,path,seen)
     table.remove(path); seen[nextPart]=nil
    end
   end
  end
  visit(origin,{}, {[origin]=true})
  if tooLong then return nil,'too_complex' end
  if malformed then return nil,'incomplete' end
  if cyclic then return nil,'cycle' end
  if #paths==0 then return nil,'disconnected' end
  if #paths>1 then return nil,'ambiguous' end
  return paths[1],nil
 end
 local rootTarget=if explicitRoot then finish(explicitRoot) else nil
 local backwards,err=walk(selectedStart,rootTarget,false)
 -- A selected Motor6D starts after its own root joint; matching that joint
 -- explicitly is already satisfied without traversing back to its Part1.
 if explicitRoot==selected then backwards={}; err=nil end
 if err then return failure(err,'Cannot determine a unique root path: '..err..'.') end
 local forwards,forwardErr=walk(selectedEnd,terminal,true)
 if forwardErr then return failure(forwardErr,'Cannot determine a unique endpoint path: '..forwardErr..'.') end
 local joints={}
 for i=#backwards,1,-1 do table.insert(joints,backwards[i]) end
 if explicitRoot and explicitRoot~=selected and kind=='Motor6D' then table.insert(joints,1,explicitRoot) end
 if kind=='Bone' and explicitRoot and explicitRoot~=selected and (#joints==0 or joints[1]~=explicitRoot) then table.insert(joints,1,explicitRoot) end
 table.insert(joints,selected)
 for _,j in ipairs(forwards) do table.insert(joints,j) end
 -- Cross-direction repeats reveal loops that stop-at-target searches can miss.
 local seen={}
 for _,j in ipairs(joints) do if seen[j] then return failure('cycle','The chain contains a cycle.') end; seen[j]=true end
 if kind=='Motor6D' then
  local parts={[joints[1].Part0]=true}
  for _,j in ipairs(joints) do
   if parts[j.Part1] then return failure('cycle','The chain contains a cycle.') end
   parts[j.Part1]=true
  end
 end
 if #joints>128 then return failure('too_complex','The chain exceeds the 128-joint limit.') end
 local last=joints[#joints]
 local endpoint=explicitEndpoint
 if not endpoint then
  local candidates={}
  for _,child in ipairs(finish(last):GetChildren()) do if child.ClassName=='Attachment' then table.insert(candidates,child) end end
  if #candidates==0 then return failure('missing_endpoint','The terminal joint has no Attachment endpoint.') end
  if #candidates>1 then return failure('ambiguous_endpoint','The terminal joint has multiple Attachment endpoints.') end
  endpoint=candidates[1]
 end
 return {ok=true,model=model,joints=joints,root=joints[1],endJoint=last,endpoint=endpoint,
  rootSource=if explicitRoot then 'explicit' else 'inferred',endpointSource=if explicitEndpoint then 'explicit' else 'inferred'}
end
return ChainInference
