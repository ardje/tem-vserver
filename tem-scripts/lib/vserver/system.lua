local M={}
local posix = require("posix")
local vsd=require("vserver.debug")
-- 5.1 vs 5.2
local unpack=unpack or table.unpack

function M.system(args)
	local pid=assert(posix.fork())
	if pid == 0 then
		vsd:debug(1,"run:",table.concat(args," "),"\n")
		-- Use unpack due to "old" lua-posix
		assert(posix.execp(unpack(args)))
	end
	return posix.wait(pid)
end

function M.read(args)
	local r,w=posix.pipe()
	local pid=assert(posix.fork())
	if pid == 0 then
		vsd:debug(1,table.concat(args," "),"\n")
		posix.dup2(w,2)
		-- Use unpack due to "old" lua-posix
		assert(posix.execp(unpack(args)))
	end
	local n={}
	for l in r:lines() do
		vsd:debug(4,"Reading :",l,"\n")
		n[#n+1]=l
	end
	posix.wait(pid)
	return n
end


return M
