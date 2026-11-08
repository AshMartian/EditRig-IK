--!strict
-- Pure visibility policy. The caller validates and resolves Studio instances.
local OverlaySelection={}
function OverlaySelection.showLimit(classification)
 return classification=='saved' or classification=='draft'
end
function OverlaySelection.new()
 local lastSelection=nil
 local wasOpen=false
 local overlayHidden,axesHidden=false,false
 local state={}
 function state:hideOverlay() overlayHidden=true end
 function state:showOverlay() overlayHidden=false end
 function state:hideAxes() axesHidden=true end
 function state:showAxes() axesHidden=false end
 function state:update(open,edit,selection,rig,joint)
  if selection~=lastSelection or (open and not wasOpen) then overlayHidden=false; axesHidden=false end
  lastSelection=selection; wasOpen=open
  if not open or not edit then return nil,nil end
  return if overlayHidden then nil else rig, if axesHidden then nil else joint
 end
 return state
end
return OverlaySelection
