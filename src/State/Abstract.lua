local runService = game:GetService("RunService")

local src = script.Parent.Parent
local packages = src.Parent
local maidConstructor = require(packages:WaitForChild("maid"))
local signalConstructor = require(packages:WaitForChild("signal"))
local animation = src:WaitForChild("Animation")


local remotes = game.ReplicatedStorage:FindFirstChild("ColdFusionRemotes")
local isEdit = false
local success, msg = pcall(function()
	isEdit = runService:IsEdit()
end)
if not remotes then
	if runService:IsClient() and not isEdit then
		remotes = game.ReplicatedStorage:WaitForChild("ColdFusionRemotes")
	else
		remotes = Instance.new("Folder", game.ReplicatedStorage)
		remotes.Name = "ColdFusionRemotes"
	end
end

local Abstract = {}
Abstract.__index = Abstract
local WEAK_KEYS_METATABLE = {__mode = "k"}

--[[
	@startuml
	!theme crt-amber
	class State {
		+ type: string,
		+ kind: string,
		+ dependentSet: weakTable,
		- _Maid: Maid,
		- _signal: Event,
		- _value: any | nil,
		- _valueTypes: [string] | nil,
		- _connections: weakTable,
		- _destroyed: boolean,
		- _cleanUp: boolean, --whether it  cleans up old value when changing it
		- _event = Event | nil,
		- _rate = number,
		- _player = Player | nil,
		- _id = string,
		- _lastFire = number,
		+ getRemoteEvent(remoteName: string): RemoteEvent
		+ Destroy()
		+ Get(asDependency: boolean | nil)
		+ Set(): any | nil
		+ Connect(): self, Event
		- _SetValue(val: any | nil)
		+ CleanUp(): self
		- _Ping()
		- _Fire()
		+ Transmit(remoteName: string, id: string | nil, player: Player, rate: number | nil): self
		+ Receive(remoteName: string, id: string | nil, player: Player): self
		+ Tween(tweenDuration: number | nil, easingStyle: EnumItem | nil, easingDirection: EnumItem | nil): TweenState
		+ Spring(speed: number, damping: number): SpringState
		+ Update(...): self
		+ Type(typeName1, typeName2 | nil, typeName3 | nil, ...): self
		+ new(kind: typeName, value: any): State
	}
	@enduml
]]--

function Abstract.getRemoteEvent(remoteName)
	if runService:IsClient() then
		return remotes:WaitForChild(remoteName)
	else
		if remotes:FindFirstChild(remoteName) then
			return remotes:FindFirstChild(remoteName)
		else
			local newRemote = Instance.new("RemoteEvent", remotes)
			newRemote.Name = remoteName
			return newRemote
		end
	end
end

function Abstract:Destroy()
	if self._destroyed == true then return end
	self._destroyed = true
	if self._cleanUp == false then
		if self._value ~= nil and (type(self._value) == "table" or typeof(self._value) == "Instance") then
			if self._value.Destroy then
				self._value:Destroy()
			end
		end
	end
	if self._Maid then
		self._Maid:Destroy()
	end
	for k, v in pairs(self) do
		self[k] = nil
	end
	setmetatable(self, nil)
end

function Abstract:Get(...) end
function Abstract:get(...) return self:Get(...) end
function Abstract:Set(...) end
function Abstract:set(...) return self:set(...) end

function Abstract:Connect(func)
	-- local newSignal = signalConstructor.new()
	-- self._Maid:GiveTask(newSignal)

	table.insert(self._connections, func)
	return self
end

function Abstract:_SetValue(val)
	if self._valueTypes and not self._valueTypes[typeof(val)] then
		error(self.kind..self.type.." cannot be set to "..tostring(typeof(val)))
	end
	local oldVal = self._value
	-- self:_SetValue(val)
	self._value = val
	for i, connection in ipairs(self._connections) do
		-- if connection then
		connection(val, oldVal)
		-- end
	end
	if self._cleanUp then
		local oldType = typeof(oldVal)
		if (oldType == "table" and oldType.Destroy) or oldType == "Instance" then
			oldType:Destroy()
		end
	end
end

function Abstract:CleanUp()
	self._cleanUp = true
	return self
end

function Abstract:_Ping()
	local event = self.getRemoteEvent(self._transmitName..tostring(self._transmitId or ""))
	if runService:IsClient() then
		event:FireServer()
	else
		event:FireClient(self._player)
	end
end


function Abstract:IsDeep()
	self._isDeep = true
	return self
end

function Abstract:_Fire()
	if self._event then
		local t = tick()
		if t - self._lastFire < 1/self._rate then
			return
		end
		self._lastFire = t
		local value = self._state:get()
		if runService:IsServer() then
			if self._player then
				self._event:FireClient(self._player, self._id, value)
			else
				self._event:FireAllClients(self._id, value)
			end
		else
			self._event:FireServer(self._id, value)
		end
	end
end

function Abstract:Transmit(remoteName: string, id: string | nil, player: Player, rate: number | nil)
	self._event = self.getRemoteEvent(remoteName)
	self._rate = rate
	self._id = id
	self._player = player

	if runService:IsClient() then
		self._Maid:GiveTask(self._event.OnClientEvent:Connect(function(newVal)
			self:_Fire()
		end))
	else
		self._Maid:GiveTask(self._event.OnServerEvent:Connect(function(plr, newVal)
			if self._player == nil or self._player == plr then
				self:_Fire()
			end
		end))
	end
	self:Connect(function(newVal, oldVal)
		self:_Fire()
	end)
	return self
end

function Abstract:Receive(remoteName: string, id: string | nil, player: Player)
	self._event = self.getRemoteEvent(remoteName)
	self._id = id
	self._player = player
	if runService:IsClient() then
		self._Maid:GiveTask(self._event.OnClientEvent:Connect(function(stateId, newVal)
			if self._id == stateId then
				self:Set(newVal)
			end
		end))
	else
		self._Maid:GiveTask(self._event.OnServerEvent:Connect(function(plr, stateId, newVal)
			if player == nil or player == plr and self._id == stateId then
				self:Set(newVal)
			end
		end))
	end
	self:_Ping()
	return self
end

function Abstract:Tween(duration, easingStyle, easingDirection)
	local tween = require(animation:WaitForChild("Tween"))
	local tweenParams = TweenInfo.new(duration or 0.3, easingStyle or Enum.EasingStyle.Quad, easingDirection or Enum.EasingDirection.InOut)
	local tweenState = tween(self, tweenParams)
	tweenState._Maid:GiveTask(self)
	return tweenState
end

function Abstract:Spring(speed, damping)
	local spring = require(animation:WaitForChild("Spring"))
	local springState = spring(self, speed, damping)
	springState._Maid:GiveTask(self)
	return springState
end

function Abstract:Update(...): boolean
	self:_Fire()
	return false
end

function Abstract:Type(...)
	self._valueTypes = self._valueTypes or {}
	for i, typeName in ipairs({...}) do
		self._valueTypes = typeName
	end
	return self
end

function Abstract:update(...) return self:Update(...) end

function Abstract.new(kind: string, initalValue: any)
	local self = setmetatable({
		type = "State",
		kind = kind,
		dependentSet = setmetatable({}, WEAK_KEYS_METATABLE),
		_Maid = maidConstructor.new(),
		_signal = signalConstructor.new(),
		_value = initalValue,
		_valueTypes = nil,
		_connections = {},
		_destroyed = false,
		_cleanUp = false, --whether it  cleans up old value when changing it
		_event = nil,
		_rate = 30,
		_player = nil,
		_id = "None",
		_lastFire = 0,
		_isDeep = false,
	}, Abstract)
	self._Maid:GiveTask(self._signal)
	return self
end

return Abstract