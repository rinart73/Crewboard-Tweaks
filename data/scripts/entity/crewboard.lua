local Azimuth, CrewboardTweaksConfig, crewboardTweaks_isVisible -- client
local crewboardTweaks_crewWorkforceUI -- client UI
local crewboardTweaks_onShowWindow, crewboardTweaks_sync -- client extended functions
local crewboardTweaks_hireCrew -- server extended functions


if onClient() then


include("azimuthlib-uiproportionalsplitter")
Azimuth = include("azimuthlib-basic")

local crewboardTweaks_configOptions = {
  _version = {default = "1.0", comment = "Config version. Don't touch."},
  EnableCrewWorkforcePreview = {default = true, comment = "Show current and minimal crew workforce in crewboard window."}
}
local crewboardTweaks_isModified
CrewboardTweaksConfig, crewboardTweaks_isModified = Azimuth.loadConfig("CrewboardTweaks", crewboardTweaks_configOptions)
if crewboardTweaks_isModified then
    Azimuth.saveConfig("CrewboardTweaks", CrewboardTweaksConfig, crewboardTweaks_configOptions)
end

if CrewboardTweaksConfig.EnableCrewWorkforcePreview then

crewboardTweaks_crewWorkforceUI = {}

function CrewBoard.initUI() -- overridden
    local res = getResolution()
    local size = vec2(890, 470)
    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5));
    menu:registerWindow(window, "Hire Crew"%_t);

    window.caption = "Hire Crew"%_t
    window.showCloseButton = 1
    window.moveable = 1

    local hsplit = UIHorizontalProportionalSplitter(Rect(vec2(0, 10), size), 10, 10, {0.8, 60, 0.2})

    local hmsplit = UIHorizontalMultiSplitter(Rect(hsplit[1].lower - vec2(0, 10), hsplit[1].upper - vec2(0, 10)), 10, 10, 6)

    local padding = 15
    local iconSize = 30
    local barSize = 120
    local sliderSize = 350
    local amountBoxSize = 60
    local priceSize = 80
    local buttonSize = 150

    local iconX = 15
    local barX = iconX + iconSize + padding
    local sliderX = barX + barSize + padding
    local amountBoxX = sliderX + sliderSize + padding
    local priceX = amountBoxX + amountBoxSize + padding
    local buttonX = priceX + priceSize + padding

    for i = 0, 6 do
        local rect = hmsplit:partition(i)

        local pic = window:createPicture(Rect(iconX, rect.lower.y, iconX + iconSize, rect.upper.y), "")
        local bar = window:createNumbersBar(Rect(barX, rect.lower.y, barX + barSize, rect.upper.y))
        local slider = window:createSlider(Rect(sliderX, rect.lower.y, sliderX + sliderSize, rect.upper.y), 0, 15, 15, "", "onSliderChanged")
        slider.showMaxValue = true
        local box = window:createTextBox(Rect(amountBoxX, rect.lower.y, amountBoxX + amountBoxSize, rect.upper.y), "onAmountEntered")
        box.allowedCharacters = "0123456789"
        box.text = slider.value
        local label = window:createLabel(Rect(priceX, rect.lower.y, priceX + priceSize, rect.upper.y), "", 16)
        label:setRightAligned()
        label.fontSize = 12
        local button = window:createButton(Rect(buttonX, rect.lower.y, buttonX + buttonSize, rect.upper.y), "Hire"%_t, "onHireButtonPressed")

        local hide = function (self)
            self.bar:hide()
            self.pic:hide()
            self.slider:hide()
            self.box:hide()
            self.label:hide()
            self.button:hide()
        end

        local show = function (self)
            self.bar:show()
            self.pic:show()
            self.slider:show()
            self.box:show()
            self.label:show()
            self.button:show()
        end

        uiGroups[#uiGroups+1] = {pic=pic, bar=bar, slider=slider, box=box, label=label, button=button, show=show, hide=hide}
    end

    -- ship workforce
    local wfsplit = UIVerticalMultiSplitter(Rect(hsplit[2].lower, hsplit[2].upper - vec2(0, 10)), 10, 0, 5)
    local wfpartition, wficon, wfyoffset
    for i = 1, 12 do
        wfpartition = wfsplit:partition(i - math.floor(i / 7) * 6 - 1)
        wfyoffset = math.floor(i / 7) * 30
        wficon = window:createPicture(Rect(wfpartition.lower + vec2(0, wfyoffset), wfpartition.lower + vec2(20, 20 + wfyoffset)), CrewProfession(i).icon)
        wficon.isIcon = 1
        crewboardTweaks_crewWorkforceUI[i] = {
          icon = wficon,
          label = window:createLabel(Rect(wfpartition.lower + vec2(30, 2 + wfyoffset), wfpartition.upper + vec2(0, wfyoffset)), "0/0", 12)
        }
    end
    
    window:createLine(hsplit[2].bottomLeft, hsplit[2].bottomRight)

    local hsplit2 = UIHorizontalSplitter(hsplit[3], 10, 0, 0.4)
    local vmsplit = UIVerticalMultiSplitter(hsplit2.bottom, 10, 0, 2)

    requestTransportButton = window:createButton(vmsplit:partition(2), "Request Transport"%_t, "onRequestTransportButtonPressed")

    local label = window:createLabel(hsplit2.top, "You can request a crew transport ship here containing a complete crew for your current ship.\nOnly possible if your ship needs at least 300 more crewmembers."%_t, 12)
    label.font = FontType.Normal
    label.wordBreak = true

    transportPriceLabel = window:createLabel(vmsplit:partition(1), "", 14)
    transportPriceLabel.centered = true
    transportPriceLabel.position = transportPriceLabel.position + vec2(0, 10)

    transportETALabel = window:createLabel(vmsplit:partition(0), "", 14)
    transportETALabel.centered = true
    transportETALabel.position = transportETALabel.position + vec2(0, 10)

    CrewBoard.sync()

    uiInitialized = true
end

crewboardTweaks_onShowWindow = CrewBoard.onShowWindow
function CrewBoard.onShowWindow(...)
    crewboardTweaks_onShowWindow(...)

    crewboardTweaks_isVisible = true

    local ship = getPlayerCraft()
    ship:registerCallback("onCrewChanged", "crewboardTweaks_onCrewChanged")
end

crewboardTweaks_onCloseWindow = CrewBoard.onCloseWindow
function CrewBoard.onCloseWindow(...)
    if crewboardTweaks_onCloseWindow then crewboardTweaks_onCloseWindow(...) end

    crewboardTweaks_isVisible = false
end

crewboardTweaks_sync = CrewBoard.sync
function CrewBoard.sync(available, transport, lineToReset)
    -- update crew workforce labels
    if available and crewboardTweaks_isVisible then
        CrewBoard.crewboardTweaks_updateInfo()
    end

    crewboardTweaks_sync(available, transport, lineToReset)
end

function CrewBoard.crewboardTweaks_onCrewChanged(index)
    if crewboardTweaks_isVisible then
        local entity = Sector():getEntity(index)
        if entity then
            local ship = getPlayerCraft()
            if entity.index == ship.index then
                CrewBoard.crewboardTweaks_updateInfo()
            end
        end
    end
end

function CrewBoard.crewboardTweaks_updateInfo()
    local ship = getPlayerCraft()
    if ship and ship:hasComponent(ComponentType.Crew) then
        local workforce = {}
        local minWorkforce = {}
        for k, v in pairs(ship.crew:getWorkforce()) do
            workforce[k.value] = v
        end
        for k,v in pairs(ship.minCrew:getWorkforce()) do
            minWorkforce[k.value] = v
        end
        minWorkforce[CrewProfessionType.Sergeant] = math.max(0, math.ceil((ship.crew.engineers + ship.crew.gunners + ship.crew.miners + ship.crew.mechanics + ship.crew.pilots + ship.crew.security + ship.crew.attackers - 9) / 10))
        minWorkforce[CrewProfessionType.Lieutenant] = math.max(0, math.ceil((minWorkforce[CrewProfessionType.Sergeant] - 3) / 4))
        minWorkforce[CrewProfessionType.Commander] = math.max(0, math.ceil((minWorkforce[CrewProfessionType.Lieutenant] - 2) / 3))
        minWorkforce[CrewProfessionType.General] = math.max(0, math.ceil((minWorkforce[CrewProfessionType.Commander] - 2) / 3))
        local wf, minWf, wfUIPair
        for i = 1, 12 do
            wf = workforce[i] or 0
            minWf = minWorkforce[i] or 0
            wfUIPair = crewboardTweaks_crewWorkforceUI[i]
            wfUIPair.icon.tooltip = CrewProfession(i):name()
            wfUIPair.label.caption = wf .. "/" .. minWf
            wfUIPair.label.color = wf < minWf and ColorInt(0xffff2626) or ColorInt(0xffe0e0e0)
        end
    end
end

end


else -- onServer


crewboardTweaks_hireCrew = CrewBoard.hireCrew
function CrewBoard.hireCrew(i, num)
    if anynils(i, num) then return end
    -- Fixing the exploit - server doesn't check if station has enough crew members
    local pair = availableCrew[i]
    if not pair then return end
    num = math.min(tonumber(num) or 0, pair.number)
    if num <= 0 then return end

    crewboardTweaks_hireCrew(i, num)
end


end