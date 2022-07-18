--!strict

local RunService = game:GetService("RunService")
local package = script.Parent.Parent
local packages = package.Parent

local Maid = require(packages.Maid)
local State = require(script.Parent)
export type State = State.State

local Property = {}
Property.__index = Property
Property.__type = "Property"

function Property.new(instOrState: Instance | State, propertyName: string, rate: number)

	local self = State.new()
	self.Instance.Name = Property.__type
	setmetatable(self, Property)

	local maid = self._Maid
	local function connectProperty(inst: Instance)
		if not inst then return end
		local instMaid = Maid.new()
		maid["_prop"..propertyName] = instMaid
		instMaid:GiveTask(inst.Destroying:Connect(function()
			instMaid:Destroy()
		end))

		if rate then
			local dur = 1/rate
			local lastUpdate = 0

			local function step()
				if tick() - lastUpdate < dur then return end
				lastUpdate = tick()
				if self:_Set(inst[propertyName]) then
					self:_UpdateDependants()
				end
			end

			if RunService:IsClient() then
				instMaid["_prop"..propertyName] = RunService.RenderStepped:Connect(step)
			else
				instMaid["_prop"..propertyName] = RunService.Heartbeat:Connect(step)
			end
			
		else
			instMaid["_prop"..propertyName] = inst:GetPropertyChangedSignal(propertyName):Connect(function()
				if self:_Set(inst[propertyName]) then
					self:_UpdateDependants()
				end
			end)
			if self:_Set(inst[propertyName]) then
				self:_UpdateDependants()
			end
		end
	end
	if typeof(instOrState) == "Instance" then
		connectProperty(instOrState)
	elseif typeof(instOrState) == "table" then
		local tabl: table = instOrState
		if tabl.IsA and tabl:IsA("State") then
			local state:State = tabl
			state:Connect(function(cur)
				connectProperty(cur)
			end)
			connectProperty(state:Get())
		else
			error("Bad inst state")
		end
	else
		error("Bad inst")
	end
	return self
end
setmetatable(Property, State)

return Property.new