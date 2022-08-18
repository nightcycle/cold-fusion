
--!strict
local StateAbstract = require(script.Parent.StateAbstract)
type StateAbstract<T> = StateAbstract.StateAbstract<T>

local State = require(script.Parent.State)
local TweenAbstract = require(script.Parent.TweenAbstract)

type TweenAbstract<T> = TweenAbstract.TweenAbstract<T>
type State<T> = State.State<T>

local Tween = {}
Tween.__index = Tween
Tween.__type = "Tween"
setmetatable(Tween, State)

Tween.new = function<T>(
	goal: StateAbstract<T>, 
	duration: (number | StateAbstract<number>?), 
	easingStyle: (Enum.EasingStyle | StateAbstract<Enum.EasingStyle>)?, 
	easingDirection: (Enum.EasingDirection | StateAbstract<Enum.EasingDirection>)?
): State<T>
	-- print("Start val", goal:Get())
	local self = TweenAbstract.new(goal, duration, easingStyle, easingDirection)
	setmetatable(self, Tween)
	
	local output: any = self

	return output
end

return Tween