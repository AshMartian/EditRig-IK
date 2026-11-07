--!strict
-- Prepare an inert, editable InputContext from an actor definition.
local InputProfileBuilder={}
function InputProfileBuilder.validateKey(value)
 assert(value==nil or type(value)=='string','key must be a KeyCode name')
 local name=if value then string.match(value,'^%s*(.-)%s*$') else ''
 if name=='' then return '' end
 local ok,key=pcall(function() return Enum.KeyCode[name] end)
 assert(ok and key and key~=Enum.KeyCode.None,'unknown or unsupported KeyCode: '..name)
 return key.Name
end
function InputProfileBuilder.create(definition)
 assert(typeof(definition)=='Instance' and definition:IsA('Folder') and definition.Name=='EditRigIKActor' and definition:GetAttribute('EditRigIK_ActorSchemaVersion')==1 and definition.Parent and definition.Parent:IsA('Model'),'select a supported actor definition')
 local groups,keys={},{}
 local function add(route,control,keyName)
  if keyName=='' then return end
  assert(type(control)=='string' and #control>0 and #control<=128,'actor control or impulse name is invalid')
  local id=route..'\0'..control
  assert(not keys[keyName] or keys[keyName]==id,'one key cannot drive different actions: '..keyName)
  keys[keyName]=id
  local group=groups[id]
  if not group then group={route=route,control=control,keys={}}; groups[id]=group end
  group.keys[keyName]=true
 end
 for _,ref in ipairs(definition:GetChildren()) do
  local joint=if ref:IsA('ObjectValue') then ref.Value else nil
  assert(joint and (joint:IsA('Motor6D') or joint:IsA('Bone')) and joint:IsDescendantOf(definition.Parent),'invalid actor joint reference')
  add('Hold',ref:GetAttribute('Control'),InputProfileBuilder.validateKey(joint:GetAttribute('EditRigIK_HoldKey')))
  add('Impulse',ref:GetAttribute('Impulse'),InputProfileBuilder.validateKey(joint:GetAttribute('EditRigIK_ImpulseKey')))
 end
 local ordered={}
 for id in pairs(groups) do table.insert(ordered,id) end
 table.sort(ordered); assert(#ordered>0,'no keys assigned to actor joints')
 local context=Instance.new('InputContext'); context.Name='EditRigIKInputTemplate'; context.Enabled=false; context.Sink=false
 for index,id in ipairs(ordered) do
  local group=groups[id]
  local action=Instance.new('InputAction'); action.Name=string.format('%s%03d',group.route,index); action.Type=Enum.InputActionType.Bool
  action:SetAttribute('Route',group.route); action:SetAttribute('Control',group.control); action:SetAttribute('Value',1)
  local names={}; for name in pairs(group.keys) do table.insert(names,name) end; table.sort(names)
  for _,name in ipairs(names) do
   local binding=Instance.new('InputBinding'); binding.Name=name; binding.Type=Enum.InputBindingType.Automatic; binding.KeyCode=Enum.KeyCode[name]; binding.Parent=action
  end
  action.Parent=context
 end
 return context
end
return InputProfileBuilder
