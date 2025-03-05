local ExampleWidget = {}
local widget = ExampleWidget

widget.metadata = {
	name = "Example Widget",
	game = "com.pencilpals.illuremination"
}

widget.image = playdate.graphics.image.new(200, 200)

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

function widget:update()
	
end



function widget:main(path)
	playdate.graphics.pushContext(widget.image)
		-- Draw widget content
		playdate.graphics.clear(playdate.graphics.kColorClear)
		
		playdate.graphics.setColor(playdate.graphics.kColorBlack)
		playdate.graphics.setColor(playdate.graphics.kColorWhite)

		playdate.graphics.fillRoundRect(0, 0, 200, 200, configVars.cornerradius)

		playdate.graphics.setColor(playdate.graphics.kColorBlack)
		playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeCopy)

		playdate.graphics.drawText("Example Widget", 10, 90)
	playdate.graphics.popContext()

	self.lastDrawnImage = widget.image:copy()
	return widget.image
end

return widget