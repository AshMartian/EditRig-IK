--!strict
-- Keep another Studio tool in control until the user explicitly resumes or
-- closes and reopens our panel. Selection changes alone never steal it back.
local ViewportInputPolicy={}
function ViewportInputPolicy.new()
    local suppressed=false
    local policy={}
    function policy:update(open, edit, eligible)
        if not open then suppressed=false end
        return open and edit and eligible and not suppressed
    end
    function policy:toolTakenOver() suppressed=true end
    function policy:resume() suppressed=false end
    return policy
end
return ViewportInputPolicy
