local M={}
local posix=require"posix"
local debug=require"vserver.debug"

function M.exec(...)
        local cmd
        for k,v in pairs{...} do
                cmd=(cmd and cmd .. " " or "" )..v
        end
        debug:debug(4,"# ",cmd,"\n")
        local file=assert(io.popen(cmd))
        if file then
                local result=file:read("*a")
                debug:debug(4,result)
                return(file:close())
        else
                return nil
        end
end
function M.nsmounted(ns)
	debug:debug(5,"check if ",ns," mounted\n")
        local ismounted=nil
        for l in io.lines("/proc/mounts") do
		debug:debug(5,"mount:",l,"\n")
                if l:match("/run/netns/([^ ]+) ") == ns then
                        ismounted=true
                        break
                end
        end
        return ismounted
end
function M.mountns(ns)
        assert(M.exec("vspace -e "..ns.." --net mount -o bind /proc/self/ns/net /run/netns/"..ns))
end
function M.ifsetns(netns,oldname,newname)
	if not M.nsmounted(netns) then
		M.mountns(netns)
	end
	M.ip("link set dev",oldname,"netns",netns)
	M.ipns(netns,"ip link set dev",oldname,"name",newname)
end
function M.ipns(ns,...)
        if not M.nsmounted(ns) then
                M.mountns(ns)
        end
        return M.ip("netns exec",ns,...)
end
function M.ip(...)
	return M.exec("ip",...)
end
function M.sysctl(vserver,base,key,value)
	local svalue=value
	if type(svalue) ~= "string" then
		svalue=tostring(svalue)
	end
	local cmd="sysctl -w "..(base and base.."/" or "")..key.."="..svalue
	return M.ipns(vserver,cmd)
end
function M.intfexists(intf)
        return M.ip("link show dev",intf)
end
function M.createvlan(parent,intf,id)
        M.ip("link add link",parent,"name",intf,"type vlan id",id)
        M.ip("link set arp off dev",intf)
        M.ip("link set up dev",intf)
end
function M.createmvlan(parent,intf,mac)
        M.ip("link add link",parent,"name",intf,"type macvlan mode bridge")
        M.ip("link set dev",intf,"address",mac)
end
function M.moveandrename(ns,intf,newintf)
end
function M.parsearg(arg,options)
        local i=1
        local unparsed={}
        while i<=#arg do
                local n
                local carg=arg[i]
                if options[carg] ~= nil then
                        n=options[carg](arg,i)
                else
                        unparsed[#unparsed+1]=carg
                        n=0
                end     
                i=i+1+n
        end
end
return M
