local function main()
	local modio = require 'base.script.singleton.modio'
	local glapp = modio:require 'script.singleton.glapp'
	return glapp:run()
end
return main
