import 'CoreLibs/graphics.lua'
import 'CoreLibs/ui'
import 'shaker.lua'

local gfx = playdate.graphics

gfx.setBackgroundColor( gfx.kColorWhite )
gfx.setColor( gfx.kColorBlack )

inverted = false
local menu = playdate.getSystemMenu()
local menuItem, error = menu:addMenuItem("Clear", function()
	gfx.clear()
end)
local menuItem, error = menu:addMenuItem("Invert", function()
	doInvert()
end)

playdate.startAccelerometer()
local shaker = Shaker.new(function()
	gfx.clear()
end, {})
shaker:setEnabled(true)

function saveImage()
	local image = gfx.getDisplayImage()
	playdate.datastore.writeImage(image, "lastImage")
end

function loadImage()
	local savedImage = playdate.datastore.readImage("lastImage")
	if savedImage then
		savedImage:draw(0,0)
	end
end

loadImage()

minX = 0
maxX = 400
minY = 0
maxY = 240

pointerX = maxX / 2
pointerY = maxY / 2
pointerR = 3
velX = 2
velY = 2

MODE_HORIZONTAL = 0
MODE_VERTICAL = 1
MODE_ARC = 2
mode = MODE_HORIZONTAL

showingCrankIndicator = false

function playdate.update()

	-- show the crank indicator if it's docked
	local crankDocked = playdate.isCrankDocked()
	if crankDocked and showingCrankIndicator then
		playdate.timer.updateTimers()
		playdate.ui.crankIndicator:update()
		return
	elseif crankDocked and not showingCrankIndicator then
		saveImage()
		playdate.ui.crankIndicator:start()
		showingCrankIndicator = true
		return
	elseif not crankDocked and showingCrankIndicator then
		loadImage()
		showingCrankIndicator = false
	end

	-- test for shake gesture
	shaker:update()

	-- save some previous state
	local prevX = pointerX
	local prevY = pointerY
	local prevMode = mode

	-- let B invert
	if playdate.buttonIsPressed( playdate.kButtonB ) then
		doInvert()
	end

	-- pointer draw size
	if playdate.buttonIsPressed( playdate.kButtonUp ) then
		pointerR += 1
	elseif playdate.buttonIsPressed( playdate.kButtonDown ) then
		pointerR -= 1
		if pointerR < 1 then pointerR = 1 end
	end

	-- pointer mode
	if playdate.buttonJustPressed( playdate.kButtonLeft ) or
	   playdate.buttonJustPressed( playdate.kButtonA ) or
	   playdate.buttonJustPressed( playdate.kButtonRight ) then
		if mode == MODE_HORIZONTAL then
			mode = MODE_VERTICAL
		elseif mode == MODE_VERTICAL then
			mode = MODE_HORIZONTAL
		end
	end
--		mode = MODE_HORIZONTAL
--	elseif playdate.buttonIsPressed( playdate.kButtonRight ) then
--		mode = MODE_VERTICAL
--	end

	local change = playdate.getCrankChange()

	if change ~= 0 then
		if mode == MODE_HORIZONTAL then
			pointerX += change
		elseif mode == MODE_VERTICAL then
			pointerY += change
		elseif mode == MODE_ARC then
			--angle += change
			--angle = normalizeAngle(angle)
			--print(change, angle)
			--x,y = degreesToCoords(angle)
		end

	end

	if ( pointerX > maxX ) then
		pointerX = maxX
	elseif ( pointerX < minX ) then
		pointerX = minX
	end

	if ( pointerY > maxY ) then
		pointerY = maxY
	elseif ( pointerY < minY ) then
		pointerY = minY
	end

	-- Drawing
--	gfx.clear( gfx.kColorWhite )
	gfx.setColor( gfx.kColorBlack )

	-- overdraw previous direction indicator
	gfx.setLineWidth(1)
	if prevMode == MODE_HORIZONTAL then
		gfx.drawLine(prevX-1, prevY, prevX+1, prevY)
	elseif prevMode == MODE_VERTICAL then
		gfx.drawLine(prevX, prevY-1, prevX, prevY+1)
	end

	-- draw actual line
	gfx.setLineWidth(pointerR)
	gfx.drawLine(prevX, prevY, pointerX, pointerY)

	-- draw a circle at the end of the line for a nice rounded end
	gfx.fillCircleAtPoint( pointerX, pointerY, pointerR/2 )

	-- draw direction indicator
	gfx.setColor( gfx.kColorWhite )
	gfx.setLineWidth(1)
	if mode == MODE_HORIZONTAL then
		gfx.drawLine(pointerX-1, pointerY, pointerX+1, pointerY)
	elseif mode == MODE_VERTICAL then
		gfx.drawLine(pointerX, pointerY-1, pointerX, pointerY+1)
	end

	-- draw a single white pixel at cursor point
--	gfx.setColor( gfx.kColorWhite )
--	gfx.fillCircleAtPoint( pointerX, pointerY, 1)
--	gfx.setColor( gfx.kColorBlack )
end

function playdate.gameWillTerminate()
	saveImage()
end

function doInvert()
	if inverted then inverted = false
	elseif not inverted then inverted = true
	end
	playdate.display.setInverted(inverted)
end
