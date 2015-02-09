#!/usr/bin/lua
package.path="./tem-scripts/lib/?.lua;"..package.path ..";/usr/share/lua/5.2/?.lua;/usr/share/lua/5.2/?/init.lua;./?.lua"
-- package.cpath=package.cpath ..";/usr/lib/arm-linux-gnueabihf/lua/5.2/?.so"
local debug=require"vserver.debug"
debug:setverbose(4)
local nc=require"vserver.netconfig"
local config=nc.configload()
local M={}
function M.dumphash(arg,prefix,visited)
        if visited == nil
        then
                visited={arg}
        end
        prefix = prefix or ""
        for k,v in pairs(arg)
        do
                if  type(v) == "table" and visited[v]==nil
                then
                        visited[v]=1
                        print(prefix .. k, v, getmetatable(v))
                        M.dumphash(v,prefix .. k .. ".",visited)
                else
                        print(prefix .. k, v)
                end
        end
end


M.dumphash(config)

