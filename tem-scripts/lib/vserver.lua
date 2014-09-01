local M={}
local posix=require("posix")
local basedir="/etc/vservers"
local MO={}
local metaO={ __index=MO}
local ts=require("vserver.system")
local vsd=require("vserver.debug")

function M:vserver(name)
	self._list=self._list or {}
	local O=self._list[name]
	if O == nil then
		O={ _name = name }
		setmetatable(O,metaO)
		self._list[name]=O
		return O
	end
	return O
end
function M.list() 
	local l={}
	l = M._list or {}
	
	for f in posix.files(basedir) do
		local ps = posix.stat(basedir .. "/" .. f)
		if l[f] == nil then
			if ps ~= nil and ps.type == "directory" and f:match("^%w")
			then
				l[f]=M:vserver(f)
			end
		end
	end
	M._list=l
	return l	
end


function M.oldversion()
	if M._oldversion then
		return M._oldversion == 1
	end
	M._oldversion=0
	local functionsfile="/usr/lib/util-vserver/vserver.functions"
	local ps = posix.stat(functionsfile)
	if ps and ps.type == "regular" then
		for l in io.lines(functionsfile) do
			-- Test op oude patch: vserver.functions bevat dan:
			-- IP_LINK)            "${VSPACE_SHARED_CMD[@]}" $_IP link  set   "$@";;
			if l:match([[IP_LINK%)%s+"%${VSPACE_SHARED_CMD%[@%]}"%s+%$_IP%s+link%s+set%s+"%$@";;]]) then
				M._oldversion=1
				return M._oldversion == 1
			end
		end
	end
	return nil
end

function MO:canonical(f)
	local c=basedir .."/"..self._name
	if f then
		c=c.."/"..f
	end
	return c
end
local function readfromdir( dir)
	local r={}
	for fn in posix.files(dir) do
		if fn:match("^%w") then
			local cf=dir .."/"..fn
			local ps= posix.stat(cf)
			if ps.type == "directory" then
				r[fn] = readfromdir(cf)
			elseif ps.type == "regular" then
				local n="";
				for v in io.lines(cf) do
					n=v
				end
				r[fn]=n
			end
			
		end
	end
	return r
end
function MO:_settings()
	self.settings=self.settings or {}
	self.settingstype=self.settingstype or {}
	self.settingsdirty=self.settingsdirty or {}
end
function MO:getDirectory(f)
	self:_settings()
	local dir=self:canonical(f)
	local ps
	local ss
	ps=posix.stat(dir)
	if ps and ps.type == "directory" then
		ss=readfromdir(dir)
		self.settingstype[f]="directory"
	end 	
	self.settings[f]=ss
	return ss
end
function MO:getsetting(f,type)
	self:_settings()
	local fn = self:canonical(f)
	if self.settings[f] == nil
	then
		local ps = posix.stat(fn)
		if ps ~= nil
		then
			local t={}
			if type == nil or type == "array" then
				type="array"
				for l in io.lines(fn) do
					t[#t+1]=l
				end
				if #t == 0 then
					self.settings[f]=""
				elseif #t == 1 then
					self.settings[f]=t[1]
				else
					self.settings[f]=t
				end
			elseif type == "directory" then
				self:getDirectory(f)
			elseif type == "hash" then
				t=self.settings[f] or t
				for l in io.lines(fn) do
					t[l]=l
				end
				self.settings[f]=t
			end
			self.settingstype[f]=type
		end
	end
	return self.settings[f]
end
function MO:getsimple(f)
	return self:getsetting(f,"array")
end
function MO:set(f,type,t)
	self:_settings()
	self.settings[f]=t
	self.settingstype[f]=type
	self.settingsdirty[f]=true
end
local function createkeypath(key)
	local path=""
	local dirname=posix.dirname(key)
	for dn in string.gmatch(dirname,"/([^/]+)") do
		path=path.."/"..dn
		vsd:debug(4,"creating path:",path,"\n")
		local ps=posix.stat(path)
		if ps == nil then
			posix.mkdir(path)
			vsd:debug(4,"creating path:",path," mkdir\n")
		elseif ps.type == "link" then
			posix.unlink(path)
			posix.mkdir(path)
			vsd:debug(4,"creating path:",path," unlink+mkdir\n")
		end
	end
	ps=posix.stat(key)
	if ps and ps.type == "link" then
		posix.unlink(key)
	end
	vsd:debug(3,"prepared ",dirname,"\n")
end
local function commitdirectory(settings,path)
	for k,v in pairs(settings) do
		local fn=path.."/"..k
		createkeypath(fn)
		if type(v) == "table" then
			commitdirectory(v,fn)
		else
			local fh=assert(io.open(fn,"wb"))
			if type(v) == "table"
			then
				for _,v in ipairs(v) do
					fh:write(v,"\n")		
				end
			else
				fh:write(v,"\n")		
			end
			fh:close()
		end
	end
end
function MO:commit(f)
	self:_settings()
	local st = self.settingstype[f]
	local ss = self.settings[f]
	if st and ss then
		vsd:debug(2,"Committing ",f,"\n")
		if st=="array" then
			local fn=self:canonical(f)
			createkeypath(fn)
			local fh=assert(io.open(fn,"wb"))
			if type(ss) == "string"
			then
				fh:write(ss,"\n")		
			else
				for _,v in ipairs(ss) do
					fh:write(v,"\n")		
				end
			end
			fh:close()
		elseif st == "hash" then
			local fn=self:canonical(f)
			createkeypath(fn)
			local fh=assert(io.open(fn,"wb"))
			for k,_ in pairs(ss) do
					fh:write(k,"\n")		
			end
			fh:close()
		elseif st== "directory" then
			commitdirectory(self.settings[f],self:canonical(f))
			-- go ahead :-)
		end
	else
		io.write("Trying to commit an unknown setting ",f,"\n")
	end
	self.settingsdirty[f]=nil
end
function MO:commitall(forced)
	self:_settings()
	if forced then
		for k,_ in pairs(self.settingstype) do
			self:commit(k)
		end
	else
		for k,_ in pairs(self.settingsdirty) do
			self:commit(k)
		end
	end
end
local function removesymlinks(dir)
	local ps
	for f in posix.files(dir) do
		if f:match("^%w") then
			fn=dir .."/"..f
			ps=posix.stat(fn)
			if ps.type == "directory" then
				removesymlinks(fn)
			elseif ps.type == "link" then
				posix.unlink(fn)
				-- print("removing: ",fn)
			else
				io.write("WARNING: ",fn," is not a symlink or a directory. Ignoring!\n")
			end
		end
	end
	--print("removing: ",dir)
	posix.rmdir(dir)
end
function MO:name()
	return self._name
end
function MO:emptyScripts()
	local bd=self:canonical("scripts")
	local ps
	ps=posix.stat(bd)
	if ps == nil then
		posix.mkdir(bd)
	elseif ps.type == "link" then
		posix.unlink(bd)
		posix.mkdir(bd)
	else -- assume directory
		removesymlinks(bd)	
		posix.mkdir(bd)
	end
end
function MO:chrtExec(cmd)
	local realcmd={ "chroot", self:canonical("vdir") }
	for _,v in ipairs(cmd) do
		realcmd[#realcmd+1]=v
	end
	return ts.system(realcmd)
end

--
-- Fixups van vservers
--
function MO:fix_namespace_cleanup_skip()
	local new_ncs = "/run/netns/"..self:name()
	local ncs=self:getsimple("namespace-cleanup-skip")
	if ncs 	~= new_ncs then
		self:set("namespace-cleanup-skip","array",{ new_ncs })
		self:commit("namespace-cleanup-skip")
		vsd:debug(1,"fixed-namespace-cleanup;")
	end
end
function MO:has_interfaces()
	local interfaces=self:getDirectory("interfaces")
	if interfaces and #interfaces > 0 then
		return 1				
	end
	return nil
end
function MO:check_interfaces()
	local interfaces=self:getDirectory("interfaces")
	if interfaces then
		for _,v in pairs(interfaces) do
			if v.parentdev ~= nil then
				vsd:debug(1, "hasparentdev;")
				return 1				
			end
		end
	end
	return nil
end
function MO:deploy_scripts(scripts)
	local spaces_net=self:getsimple("spaces/net")
	local ts=self:getsetting("tem_scripts","hash") or {}
	local has_parentdev=self:check_interfaces()
	if spaces_net == nil then
		-- templates or old style
		-- nothing to do really
	elseif spaces_net == "" then
		-- Old style, fix use old scripts
		ts.generic_old_namespace=1
		if has_parentdev then
			-- Old style doesn't really mix with "new" style
			ts.generic_holder=1
			vsd:debug(0,"Gateway parameter will not be parsed in old style\n")
		else
			ts.vlan_holder=1
		end
		self:fix_namespace_cleanup_skip()
	elseif spaces_net == self:name() then
		-- New style
		ts.generic_network_namespace=1
		if self:has_interfaces() then
			if has_parentdev then
				ts.generic_holder=1
			else
				ts.vlan_holder=1
			end
		end
		self:fix_namespace_cleanup_skip()
	else
		-- generic namespaced vserver
		ts.generic_network_namespace=1
	end
	if M.oldversion() then
		ts.unpatch_enableInterfaces=1
	end
	self:emptyScripts()
	local tslist={}
	for k,_ in pairs(ts) do
		scripts[k]:populate(self:canonical("scripts"))
		tslist[#tslist+1]=k
	end
	vsd:debug(1,"scripts:",table.concat(tslist,", "),";")
end
function MO:fix_dependency()
	local spaces_net=self:getsimple("spaces/net")
	local depends=self:getsetting("apps/init/depends","hash") or {}
	if spaces_net and spaces_net ~= "" and spaces_net ~= self:name() then
		if depends[spaces_net] == nil then
			depends[spaces_net]=spaces_net
			self:set("apps/init/depends","hash",depends)
			self:commit("apps/init/depends")
			vsd:debug(1,"fixed-dependencies;")
		end
	end
end


return M
