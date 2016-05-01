#!/usr/local/bin/luajit

require 'lfs'
require 'ext'

local Image = require 'image'

local fs = table()
if #arg == 0 then
	for f in lfs.dir('.') do
		if f:sub(-4) == '.png' then
			fs:insert(f)
		end
	end
else
	for i=1,#arg do
		assert(io.fileexists(arg[i]))
		fs[i] = arg[i]
	end
end

local results = table()

function compare(fa,fb)
	print('comparing',fa,fb)
	local a = Image(fa)
	local b = Image(fb)

	local ax, ay, ach = a:size()
	local bx, by, bch = b:size()

	if ach ~= bch then
		return math.huge, "images have different channels: "..ach.." vs "..bch
	end
	
	if ax ~= bx or ay ~= by then
		return math.huge, "images have different sizes: "..ax.."x"..ay.." vs "..bx.."x"..by
		-- TODO don't quit just yet.  instead (for both pathways) trim transparent borders, *then* compare
	end	
	
	local pixelsdiffer = 0
	for y=0,ay-1 do
		for x=0,ax-1 do
			local ap = {a(x,y)}
			local bp = {b(x,y)}
			assert(#ap == #bp)
			for i=1,#ap do
				if ap[i] ~= bp[i] then
					pixelsdiffer = pixelsdiffer + 1
					break
				end
			end
		end
	end	
	return pixelsdiffer
end

for i=1,#fs-1 do
	for j=i+1,#fs do
		-- TODO parse output, then (1) report channel differ and size differ up front, (2) read pixels differ and sort results accordingly
		local differ, msg = compare(fs[i], fs[j])
		results:insert{differ=differ, msg=msg, fa=fs[i], fb=fs[j]}
	end
end

results:sort(function(a,b)
	return a.differ > b.differ
end)

if #results > 0 then
	print()
	print()
	print()
	print("results:")
	for _,m in ipairs(results) do
		print(unpack{m.differ, m.fa, m.fb, m.msg})	-- unpack trims the nil at the end.
	end
end
