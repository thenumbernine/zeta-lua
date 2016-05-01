local Audio = require 'audio.audio'

-- make sure base.script.singleton.game requires this file so audio:init happens before the game inits
local audio = Audio()

return audio