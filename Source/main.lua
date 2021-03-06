import 'CoreLibs/graphics.lua'
--import "CoreLibs/qrcode"
import 'CoreLibs/ui'
import 'shaker.lua'

-- defining some global variables

minX = 0
maxX = 400
minY = 0
maxY = 240

pointerX = maxX / 2
pointerY = maxY / 2
pointerR = 3

MODE_HORIZONTAL = 0
MODE_VERTICAL = 1
MODE_ARC = 2
mode = MODE_HORIZONTAL

showingCrankIndicator = false
firstUpdate = true

-- local variables and functions

local gfx = playdate.graphics

gfx.clear( gfx.kColorWhite )
gfx.setColor( gfx.kColorBlack )

inverted = false
local menu = playdate.getSystemMenu()
local menuItem, error = menu:addMenuItem("Clear", function()
	gfx.clear()
end)
local menuItem, error = menu:addMenuItem("Invert", function()
	doInvert()
end)

function doInvert()
	inverted = not inverted
	playdate.display.setInverted(inverted)
end

playdate.startAccelerometer()
local shaker = Shaker.new(function()
	gfx.clear()
end, {})
shaker:setEnabled(true)

local qrImage = gfx.image.new("Images/github.qr.png")
local generatingQR = false
--local qrCallback = function(image, errorMessage)
--	if errorMessage == nil then
--		playdate.simulator.writeToFile(image, "~/Developer/github.qr.png")
--		qrImage = image
--		generatingQR = false
--	end
--end
--gfx.generateQRCode("https://github.com/mgrider/crank-a-sketch", 100, qrCallback)

-- saving/loading functions

function saveImage()
	if showingCrankIndicator then
		return
	end
	local image = gfx.getDisplayImage()
	playdate.datastore.writeImage(image, "images/lastImage")
end

function loadImage()
	if playdate.file.exists("images/lastImage") then
		gfx.clear( gfx.kColorWhite )
		local savedImage = playdate.datastore.readImage("images/lastImage")
		if savedImage then
			savedImage:draw(0,0)
		end
	else
		-- here we are probably in a first-run scenario
		gfx.clear( gfx.kColorWhite )
	end
end

function save()
	saveImage()
	playdate.datastore.write({pointerX, pointerY})
end

function load()
	loadImage()
	local table = playdate.datastore.read()
	if table then
		pointerX = table[1]
		pointerY = table[2]
	end
end


-- update function

function playdate.update()

	if generatingQR then
		playdate.timer.updateTimers()
	end

	-- show the crank indicator if it's docked
	local crankDocked = playdate.isCrankDocked()
	if crankDocked and showingCrankIndicator then
		playdate.ui.crankIndicator:update()
		playdate.timer.updateTimers()
		return
	elseif crankDocked and not showingCrankIndicator then
		saveImage()
		playdate.ui.crankIndicator:start()
		showingCrankIndicator = true
		return
	elseif not crankDocked and showingCrankIndicator then
		if firstUpdate then
			-- this definitely sucks if the user has a saved image,
			-- but it's better than before, when the screen would just be
			-- black in this case. (completely broken.)
			gfx.clear( gfx.kColorWhite )
		else
			loadImage()
		end
		showingCrankIndicator = false
		return
	end
	firstUpdate = false

	-- test for shake gesture
	shaker:update()

	-- save some previous state
	local prevX = pointerX
	local prevY = pointerY
	local prevMode = mode

	-- let B invert
	if playdate.buttonJustPressed( playdate.kButtonB ) then
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
end


-- sdk callbacks

function playdate.gameWillTerminate()
	save()
end

function playdate.gameWillPause()
	local img = gfx.getDisplayImage()

	gfx.lockFocus(img)
	local bgRect = playdate.geometry.rect.new(20, 20, 160, 200)
	local textRect = playdate.geometry.rect.new(30, 30, 140, 180)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRoundRect(bgRect, 10)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRoundRect(bgRect, 10)
	local text = " Crank-A-Sketch \n\n by Martin Grider"
	gfx.drawTextInRect(text, textRect, 0, "...", kTextAlignment.center)

	if qrImage ~= nil and not generatingQR then
		qrImage:drawCentered(20+80, 20+130)
	end

	gfx.unlockFocus()
	playdate.setMenuImage(img, 0)
end

load()
