local class = require 'ext.class'
local path = require 'ext.path'
local App = require 'base.script.singleton.class.glapp'
local ZetaApp = class(App)

ZetaApp.title = 'Zeta'

function ZetaApp:loadLevelConfig(save)
	local levelcfg = ZetaApp.super.loadLevelConfig(self, save)

-- zeta-specific
	if not levelcfg.path then
		local seed = os.time()
		print('generating seed '..seed)
		levelcfg.path = 'gen'..seed
		path('zeta/maps/'..levelcfg.path):mkdir()
		local Level = require 'base.script.level'
		require 'image'(
			Level.mapTileSize[1] * levelcfg.blocksWide,
			Level.mapTileSize[2] * levelcfg.blocksHigh,
			3,
			'unsigned char'):save('zeta/maps/'..levelcfg.path..'/tile.png')
		
		path('zeta/maps/'..levelcfg.path..'/init.lua'):write(path'zeta/maps/gen/init.lua':read())
		--path('zeta/maps/'..levelcfg.path..'/init.lua'):write(path'zeta/maps/gen/gen2.lua':read())
		path('zeta/maps/'..levelcfg.path..'/texpack.png'):write(path'zeta/maps/gen/texpack.png':read())
	end

	return levelcfg
end

return ZetaApp
