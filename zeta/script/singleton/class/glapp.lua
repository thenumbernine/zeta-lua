local class = require 'ext.class'
local file = require 'ext.file'
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
		os.execute('mkdir zeta/maps/'..levelcfg.path)
		local Level = require 'base.script.level'
		require 'image'(
			Level.mapTileSize[1] * levelcfg.blocksWide,
			Level.mapTileSize[2] * levelcfg.blocksHigh,
			3,
			'unsigned char'):save('zeta/maps/'..levelcfg.path..'/tile.png')
		
		file('zeta/maps/'..levelcfg.path..'/init.lua'):write(file'zeta/maps/gen/init.lua':read())
		--file('zeta/maps/'..levelcfg.path..'/init.lua'):write(file'zeta/maps/gen/gen2.lua':read())
		file('zeta/maps/'..levelcfg.path..'/texpack.png'):write(file'zeta/maps/gen/texpack.png':read())
	end

	return levelcfg
end

return ZetaApp
