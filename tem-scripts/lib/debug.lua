local M={}
M._debug_level=1
if M._fixed_package_path == nil then
	package.path="/etc/scripts-vserver/lib/?.lua;"..package.path
end
M._fixed_package_path=1
function M:verbose(level)
	if type(level) ~= "number" then
		print("level ",level," is not a number")
		return(1)
	end
	return level <= self._debug_level
end
function M:setverbose(level)
	self._debug_level=level
end
function M:debug(level,...)
	if self:verbose(level) then
		io.write(...)
	end
end
return M
