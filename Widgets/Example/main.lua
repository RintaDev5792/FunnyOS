local ExampleWidget = {}
local widget = ExampleWidget

local counter = 0

-- path is filled out when loaded by system
widget.metadata = {
	name = "Example Widget",
	game = "com.panic.settings",
	path = nil
}

widget.image = nil

-- Input handlers
function widget:AButtonDown()
	openApp(self.metadata.game)
end

function widget:upButtonDown()
	
end

function widget:downButtonDown()
	
end

function widget:leftButtonDown()
	
end

function widget:rightButtonDown()
	
end

-- call this to get UPDATED widget image
function widget:loadWidgetImage()
	widget.image = playdate.graphics.image.new(200, 200)
	playdate.graphics.pushContext(widget.image)
		-- Draw widget content
		playdate.graphics.clear(playdate.graphics.kColorClear)

		playdate.graphics.setColor(playdate.graphics.kColorWhite)
		playdate.graphics.fillRoundRect(0, 0, 200, 200, configVars.cornerradius)

		playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeCopy)
		playdate.graphics.drawTextAligned(tostring(counter), 100, 91, kTextAlignment.center)
	playdate.graphics.popContext()

	return widget.image
end

-- call this to get RECENT widget image
function widget:getWidgetImage()
	if widget.image and not forceReload then
		return widget.image
	else
		return widget:loadWidgetImage()	
	end
end

function widget:update(isActive)
	if isActive then
		counter+=1
		widget:loadWidgetImage()
	end
end

return widget