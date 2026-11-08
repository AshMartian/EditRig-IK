--!strict
-- Pure scheduling policy for an incremental preview solve. A job is an opaque
-- identity token; consumers must publish results only when complete accepts it.
local PosePreviewQueue={}

function PosePreviewQueue.new(maxIterations)
 local budget=if maxIterations==nil then 40 else maxIterations
 assert(type(budget)=='number' and budget%1==0 and budget>=1 and budget<=40,'preview iteration budget must be an integer from 1 to 40')
 local current=nil
 local inFlight=nil
 local api={}

 function api:request(target,orientation)
  current={target=target,orientation=orientation,iteration=1,previous=nil}
  inFlight=nil
 end

 function api:next()
  if not current or inFlight then return nil end
  local job={target=current.target,orientation=current.orientation,iteration=current.iteration,previous=current.previous}
  inFlight=job
  return job
 end

 function api:complete(job,result)
  if not current or not inFlight or job~=inFlight then return false,'stale' end
  inFlight=nil
  if type(result)~='table' or type(result.converged)~='boolean' then
   current=nil
   return false,'failed'
  end
  if result.converged then
   current=nil
   return true,'converged'
  end
  if current.iteration>=budget then
   current=nil
   return true,'exhausted'
  end
  current.iteration+=1
  current.previous=result
  return true,'pending'
 end

 function api:cancel()
  current=nil
  inFlight=nil
 end
 return api
end

return PosePreviewQueue
