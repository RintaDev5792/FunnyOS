local ExampleWidget2 = {}
local widget = ExampleWidget2

widget.metadata = {
    name = "Example Widget 2",
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

function widget:main(path)
    
    playdate.graphics.pushContext(widget.image)
        -- Clear the widget
        playdate.graphics.clear(playdate.graphics.kColorClear)
        
        -- Draw background with styling
        playdate.graphics.setColor(playdate.graphics.kColorWhite)
        
        playdate.graphics.fillRoundRect(0, 0, 200, 200, configVars.cornerradius)
        
        -- Reset draw settings for content
        playdate.graphics.setColor(playdate.graphics.kColorBlack)
        playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeCopy)
        
        -- Draw content (now on top of background)
        playdate.graphics.drawText("Example Widget 2", 10, 90)

    playdate.graphics.popContext()
    
    -- Cache this image for when widget is inactive
    self.lastDrawnImage = widget.image
    
    return widget.image
end

return widget
