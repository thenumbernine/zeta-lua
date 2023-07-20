local function main(gl)
	local modio = require 'base.script.singleton.modio'
	local glapp = modio:require 'script.singleton.glapp'
	glapp.gl = gl
	return glapp:run()
end
return main
