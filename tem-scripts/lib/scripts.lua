local M={}
local posix=require("posix")
-- Lokale scripts gaan dus voor package scripts!
local basedirs={"/usr/lib/tem-vserver/scripts","/root/vserver/scripts"}
local MO={}
local metaO={ __index=MO}

function M.list() 
	local l={}
	for _,bd in ipairs(basedirs) do
		if posix.stat(bd) ~= nil then
			for f in posix.files(bd) do
				local fn=bd .. "/" .. f
				local ps = posix.stat(fn)
				if ps ~= nil and ps.type == "regular" and f:match("^%w")
				then
					local O={}
					O.name=f
					O.basedir=bd
					O.canonical=fn
					setmetatable(O,metaO)
					l[f]=O
				end
			end
		end
	end
	return l	
end


function MO:getphases(f)
	if self.phases == nil
	then
		local p={}
		for l in io.lines(self.canonical) do
			local m=l:match("^%s+([a-z-]+)%)")
			if m ~= nil then
				p[#p+1]=m
			end
		end
		self.phases=p
	end
	return self.phases
end
function MO:populate(dir)
	local ps = posix.stat(dir)
	if ps == nil then
		posix.mkdir(dir)
	end
	for _,v in ipairs(self:getphases()) do
		d=dir .."/"..v..".d"
		if posix.stat(d) == nil then
			posix.mkdir(d)
		end
		posix.link(self.canonical,d .."/".. self.name,"soft")
		-- print(self.canonical,d)
	end
end

return M
