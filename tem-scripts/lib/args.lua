local M={}
function M.parseargs(arg,options,stuff)
	local params={}
	local n=1
	local cb={}
	function cb:nextarg()
		n=n+1
		return arg[n]
	end
	while n <= #arg do
		if arg[n]:match("^--") then
			local optname="_"..arg[n]:match("^--(%w+)")		
			if options[optname] then
				local r,e=options[optname](stuff,cb)
				if r == nil then
					return r,e
				end
			else
				return nil,"Unknown option "..optname
			end
			n=n+1
		else
			params[#params+1]=arg[n]
			n=n+1
		end
	end
	return params
end
return M
