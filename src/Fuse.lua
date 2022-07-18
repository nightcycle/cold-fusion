--!strict
local package = script.Parent
local packages = package.Parent

local Interface = require(script.Parent.Interface)
local Maid = require(packages.Maid)

type Maid = {
	DoCleaning: <T>() -> nil,
	Destroy: <T>() -> nil,
}

local Fuse = {}

function Fuse:Destroy()
	self._Maid:Destroy()
	local interface = rawget(self, "_Interface") or {}
	for k, v in pairs(interface) do
		interface[k] = nil
	end
	for k, v in pairs(self) do
		self[k] = nil
	end
end

function Fuse.wrap(fuse, func)
	local meta = {}
	function meta:__call(...)
		local result = func(...)
		if typeof(result) == "function" then
			return fuse.wrap(fuse, result)
		else
			if result and result.Destroy then
				local maid = rawget(fuse, "_Maid")
				maid:GiveTask(result)
			end
			return result
		end
	end
	local wrapper = {}
	setmetatable(wrapper, meta)
	return wrapper
end

function new(maid: Maid?)
	local interface = Interface()
	interface.fuse = Fuse.new
	maid = maid or Maid.new()
	local self = setmetatable({
		_Maid = maid,
		_Interface = interface,
	}, Fuse)

	maid:GiveTask(self)

	return self
end

function Fuse:__index(k)
	if Fuse[k] then
		return Fuse[k]
	else
		if k == "Children" then
			return rawget(self, "_Interface")[k]
		elseif k == "fuse" then
			return self.wrap(self, new)
		else
			return self.wrap(self, rawget(self, "_Interface")[k])
		end
	end
end


return new