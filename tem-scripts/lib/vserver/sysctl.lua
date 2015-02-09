local M={}
--local posix=require"posix"
local function makepath(key)
        local path="/proc/sys"
	-- For now require key to use /
	return path .. key
--[[
        local dirname=posix.dirname(key)
        for dn in string.gmatch(dirname,"(/?[^/.]+)") do
                path=path and path..dn or dn
                local ps=posix.stat(path)
                if ps == nil then
                        posix.mkdir(path)
--                elseif ps.type == "link" then
--                        posix.unlink(path)
--                        posix.mkdir(path)
                end
        end
        ps=posix.stat(key)
        if ps and ps.type == "link" then
                posix.unlink(key)
        end
-- ]]
end
function M.set(key,value)
	local file=assert(io.open(makepath(key),"w"))
	if type(value) ~= "string" then
		value=tostring(value)
	end
	file:write(value.."\n")
	file:close()
end
function M.(key,value)
	local file=assert(io.open(makepath(key),"r"))
	n=file:read("*a")
	file:close()
	return n
end
return M
