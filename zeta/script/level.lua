local class = require 'ext.class'
local Level = require 'base.script.level'

local ZetaLevel = class(Level)

-- only spawn the player ... and whatever's close to him
-- then, as the player moves, spawn things just out of his screen
function ZetaLevel:initialSpawn()
end

-- use zeta's sandbox
-- TODO have zeta overload sandbox, put a default version in base, then have base level use base sandbox and get rid of this
function ZetaLevel:runInitFile(initFile)
	local sandbox = require 'zeta.script.sandbox'
	sandbox(file[initFile])
end

return ZetaLevel
