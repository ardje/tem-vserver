#!/usr/bin/lua
local M={} -- our module
local SB={} -- sandboxed functions
local config={} -- config array
config.vrrpmac="00:00:5e:00:01:00" -- no need to change
config.macprefix="02:00:00:00:00:00" -- fake local admin mac
config.network={}
function SB.host(arg)
  for k = 1,2 do
    local hostname=arg.name..k
    config.network[hostname]=config.network[hostname] or {}
    local iface
    if arg.iface then
      iface=arg.iface
    else
      iface="eth0"
    end
    local ip
    if not arg.sameip then
      local ipnet=arg.ip:match("^(%d+.%d+.%d+)")
      local iphost=tonumber(arg.ip:match(".(%d+)$"))
      ip=ipnet .."."..iphost+k-1
    else
      ip=arg.ip
    end
    local mac=arg.mac
    if not mac then
      local mac1,mac2,mac3=ip:match("^%d+.(%d+).(%d+).(%d+)$")
      mac=string.format("%02x:%02x:%02x",mac1,mac2,mac3)
    end
    if #mac < #config.macprefix then
      mac=config.macprefix:sub(1,-(#mac+1))..":"..mac
    end
    config.network[hostname][iface]={
      vid=arg.vid,
      mac=mac,
      ip=ip,
      noup=arg.noup
    }
  end
end

function M.fwlan(arg)
  SB.host{name="fw",vid=arg.vid,ip=arg.ip,iface="vlan"..arg.vid}
  local mac=arg.mac or "10"
  if #mac < #config.vrrpmac then
    mac=config.vrrpmac:sub(1,-(#mac+1))..":"..mac
  end
  local ip=arg.vrrpip or (arg.ip:match("^(%d+.%d+.%d+.)")).."1"
  SB.host{name="fw",
    vid=arg.vid,
    sameip=true,
    iface="vlan"..arg.vid.."-gw",
    mac=mac,
    ip=ip,
    noup=true
  }
end
function M.configload()
  local myenv={
    host=SB.host,
    fwlan=SB.fwlan,
    config=config
  }
  local loader=assert( loadfile("interfaces","bt",myenv) or
    loadfile("/etc/vserver-network/interfaces","bt",myenv))
  loader()
  return config
end

return M