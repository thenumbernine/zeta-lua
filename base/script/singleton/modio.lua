--[[
this is special.  it's not to be overridden, so I put the class in this file rather than singleton/class/
--]]
local ModIO = class()

-- find somewhere before anyone else requires this file
-- ... probably init.lua ...
-- and insert in the current mod
ModIO.search = table{'base'}

function ModIO:find(fn)
	for _,dir in ipairs(self.search) do
		local fullfn = dir .. '/' .. fn
		if os.fileexists(fullfn) then return fullfn end
	end
end

-- this assumes package.path contains "?.lua"
function ModIO:require(includename)
	--print("require'ing "..includename)
	for _,dir in ipairs(self.search) do
		local filename = dir..'/'.. includename:gsub('%.', '/') .. '.lua'
		--print('checking '..filename..'...')
		if os.fileexists(filename) then
			--print('...found!')
			return require(dir..'.'..includename)
		end
	end
end

return ModIO()
