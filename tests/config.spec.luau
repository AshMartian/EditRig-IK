local Config = require('../src/shared/Config')
local config = Config.validate({kind='Hinge', axis='Y', lower=-45, upper=90, swing=70})
assert(config.lower == -45 and config.upper == 90)
assert(not pcall(function() Config.validate({kind='Hinge', axis='Y', lower=30, upper=-30, swing=70}) end))
assert(not pcall(function() Config.validate({kind='Ball', axis='X', lower=-30, upper=30, swing=181}) end))
assert(not pcall(function() Config.validate({kind='Hinge', axis='banana', lower=-30, upper=30, swing=70}) end))
assert(not pcall(function() Config.validate({kind='Hinge', axis='X', lower=0/0, upper=30, swing=70}) end))
local defaults=Config.validateDrive({},'Jaw')
assert(defaults.control=='Jaw' and defaults.impulse=='JawImpulse' and defaults.frequency==4)
assert(not pcall(function() Config.validateDrive({frequency=0},'Jaw') end))
assert(not pcall(function() Config.validateDrive({impulse=string.rep('x',129)},'Jaw') end))
local hinge={kind='Hinge',axis='X',lower=-170,upper=-130,swing=90,weight=1,circular={start=190,width=40}}
local round=Config.validate(hinge)
assert(round.circular and round.circular.start==-170 and round.circular.width==40, 'circular sweep must survive configuration validation')
for _, bad in ipairs({{start=0,width=-1},{start=0,width=361},{start=math.huge,width=10},{start=0,width=0/0}}) do
 local input=table.clone(hinge); input.circular=bad
 assert(not pcall(Config.validate,input), 'invalid circular sweep rejected')
end
local inconsistent=table.clone(hinge); inconsistent.upper=0
assert(not pcall(Config.validate,inconsistent), 'displayed endpoints cannot disagree with sweep')
local ball=table.clone(hinge); ball.kind='Ball'
assert(not pcall(Config.validate,ball), 'circular sweep only supports hinges')
print('configuration tests passed')
