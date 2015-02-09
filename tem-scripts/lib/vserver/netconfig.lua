#!/usr/bin/lua
local M={} -- our module
local SB={} -- sandboxed functions
local config={} -- config array
config.vrrpmac="00:00:5e:00:01:00" -- no need to change
config.macprefix="02:00:00:00:00:00" -- fake local admin mac
config.network={}
function SB.shost(arg)
  for k = 1 do
    local hostname=arg.name
    config.network[hostname]=config.network[hostname] or {}
    local iface
    if arg.iface then
      iface=arg.iface
    else
      iface="eth0"
    end
    local ip
    if not arg.sameip then
      local ipnet,iphost=arg.ip:match("^(%d+.%d+.%d+).(%d+)")
      ip=ipnet .."."..tonumber(iphost)+k-1 .. (arg.ip:match("(/%d+)") or "/24")
    else
      ip=arg.ip
    end
    local mac=arg.mac
    if not mac then
      local mac1,mac2,mac3=ip:match("^%d+.(%d+).(%d+).(%d+)")
      mac=string.format("%02x:%02x:%02x",mac1,mac2,mac3)
    end
    if #mac < #config.macprefix then
      mac=config.macprefix:sub(1,-(#mac+1))..mac
    end
    local gw=arg.gw
    if not gw and not arg.nogw then
	gw=ip:match("^(%d+.%d+.%d+)") ..".1"
    end
    config.network[hostname][iface]={
      vid=arg.vid,
      mac=mac,
      ip=ip,
      noup=arg.noup,
      gw=gw
    }
  end
end

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
      local ipnet,iphost=arg.ip:match("^(%d+.%d+.%d+).(%d+)")
      ip=ipnet .."."..tonumber(iphost)+k-1 .. (arg.ip:match("(/%d+)") or "/24")
    else
      ip=arg.ip
    end
    local ip6
    if arg.ip6 then
      if not arg.sameip6 and arg.ip6 ~= "radvd" then
        local ipnet,iphost=arg.ip6:match("^([0-9a-fA-F:]+:)([0-9a-fA-F]+)")
        local ipmask=arg.ip6:match("(/%d+)$") or "/64"
        ip6=ipnet ..string.format("%x",tonumber(iphost,16)+k-1) ..ipmask
      else
        ip6=arg.ip6
      end
    end
    local ip6gw
    if arg.ip6gw then
      ip6gw=arg.ip6gw
    end
    local mac=arg.mac
    if not mac then
      local mac1,mac2,mac3=ip:match("^%d+.(%d+).(%d+).(%d+)")
      mac=string.format("%02x:%02x:%02x",mac1,mac2,mac3)
    end
    if #mac < #config.macprefix then
      mac=config.macprefix:sub(1,-(#mac+1))..mac
    end
    local gw=arg.gw
    if not gw and not arg.nogw then
	gw=ip:match("^(%d+.%d+.%d+)") ..".1"
    end
    config.network[hostname][iface]={
      vid=arg.vid,
      mac=mac,
      ip=ip,
      noup=arg.noup,
      gw=gw,
      ip6=ip6,
      ip6gw=ip6gw,
      unreachable=arg.unreachable
    }
  end
end

function SB.fwlan(arg)
  local nogw
  local ip6gw
  if arg.gw then
    nogw=nil
  else
    nogw=true
  end
  if arg.ip6 then
    ip6gw=arg.ip6gw or "none"
  end
  SB.host{
    name="fw",
    vid=arg.vid,ip=arg.ip,iface="vlan"..arg.vid,
    nogw=nogw,gw=arg.gw,ip6=arg.ip6,ip6gw=arg.ip6gw,
    unreachable=arg.unreachable
  }
  local mac=arg.mac or "10"
  if #mac < #config.vrrpmac then
    mac=config.vrrpmac:sub(1,-(#mac+1))..mac
  end
  local ip=arg.vrrpip or (arg.ip:match("^(%d+.%d+.%d+.)")).."1"..(arg.ip:match("(/%d+)") or "/24")
  local ip6
  if arg.ip6 then
    local ipnet,iphost=arg.ip6:match("^([0-9a-fA-F:]+:)([0-9a-fA-F]+)")
    local ipmask=arg.ip6:match("(/%d+)$") or "/64"
    ip6=arg.vrrpip6 or ipnet.."1" ..ipmask
  end
  SB.host{name="fw",
    vid=arg.vid,
    sameip=true,
    sameip6=true,
    iface="vlan"..arg.vid.."-gw",
    mac=mac,
    ip=ip,
    ip6=ip6,
    ip6gw="none",
    noup=true,
    nogw=true
  }
end
function M.configload()
  local myenv={
    shost=SB.shost,
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
