local Azimuth -- server includes
local CrewboardTweaksConfig -- client/server
local crewboardTweaks_isVisible -- client
local crewboardTweaks_crewWorkforceUI, crewboardTweaks_freeCrewSpaceLabel, crewboardTweaks_hireReqCrewBtn, crewboardTweaks_transportLabel -- client UI
local crewboardTweaks_initialize, crewboardTweaks_onShowWindow, crewboardTweaks_onCloseWindow, crewboardTweaks_sync -- client extended functions


if onClient() then


include("azimuthlib-uiproportionalsplitter")

-- PREDEFINED --
crewboardTweaks_initialize = CrewBoard.initialize
function CrewBoard.initialize(...)
    crewboardTweaks_initialize(...)

    CrewboardTweaksConfig = {}
    invokeServerFunction("crewboardTweaks_sendSettings")
end

function CrewBoard.initUI() -- overridden
    local res = getResolution()
    local size = vec2(890, 510)
    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5));
    menu:registerWindow(window, "Hire Crew"%_t);

    window.caption = "Hire Crew"%_t
    window.showCloseButton = 1
    window.moveable = 1

    local hsplit = UIHorizontalProportionalSplitter(Rect(vec2(0, 10), size), 10, 10, {0.8, 30, 60, 0.2})

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
            self.bar.visible = false
            self.pic.visible = false
            self.slider.visible = false
            self.box.visible = false
            self.label.visible = false
            self.button.visible = false
        end

        local show = function (self)
            self.bar.visible = true
            self.pic.visible = true
            self.slider.visible = true
            self.box.visible = true
            self.label.visible = true
            self.button.visible = true
        end

        uiGroups[#uiGroups+1] = {pic=pic, bar=bar, slider=slider, box=box, label=label, button=button, show=show, hide=hide}
    end

    -- free crew space and 'Hire Required Crew'
    local vsplit = UIVerticalProportionalSplitter(hsplit[2], 10, 0, {0.5, 150})
    crewboardTweaks_freeCrewSpaceLabel = window:createLabel(Rect(vsplit[1].lower + vec2(0, 6), vsplit[1].upper), "", 15)
    crewboardTweaks_hireReqCrewBtn = window:createButton(vsplit[2], "Hire"%_t, "crewboardTweaks_onHireRequiredBtn")
    crewboardTweaks_hireReqCrewBtn.maxTextSize = 15

    -- ship workforce
    crewboardTweaks_crewWorkforceUI = {}
    local wfsplit = UIVerticalMultiSplitter(Rect(hsplit[3].lower, hsplit[3].upper - vec2(0, 10)), 10, 0, 5)
    for i = 1, 12 do
        local prof = CrewProfession(i)
        local wfPartition = wfsplit:partition(i - math.floor(i / 7) * 6 - 1)
        local wfYOffset = math.floor(i / 7) * 30
        local wfIcon = window:createPicture(Rect(wfPartition.lower + vec2(0, wfYOffset), wfPartition.lower + vec2(20, 20 + wfYOffset)), prof.icon)
        wfIcon.isIcon = 1
        wfIcon.tooltip = prof:name()
        crewboardTweaks_crewWorkforceUI[i] = {
          icon = wfIcon,
          label = window:createLabel(Rect(wfPartition.lower + vec2(30, 2 + wfYOffset), wfPartition.upper + vec2(0, wfYOffset)), "0/0", 12)
        }
    end

    window:createLine(hsplit[3].bottomLeft, hsplit[3].bottomRight)

    local hsplit2 = UIHorizontalSplitter(hsplit[4], 10, 0, 0.4)
    local vmsplit = UIVerticalMultiSplitter(hsplit2.bottom, 10, 0, 2)

    requestTransportButton = window:createButton(vmsplit:partition(2), "Request Transport"%_t, "onRequestTransportButtonPressed")

    local text = "You can request a crew transport ship here containing a complete crew for your current ship.\nOnly possible if your ship needs at least 300 more crew members."%_t
    if CrewboardTweaksConfig.TransportShipMinMissingCrew then
        text = text:gsub(300, CrewboardTweaksConfig.TransportShipMinMissingCrew)
    end
    crewboardTweaks_transportLabel = window:createLabel(hsplit2.top, text, 12)
    crewboardTweaks_transportLabel.font = FontType.Normal
    crewboardTweaks_transportLabel.wordBreak = true

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

crewboardTweaks_refreshUI = CrewBoard.refreshUI
function CrewBoard.refreshUI(...)
    crewboardTweaks_refreshUI(...)

    if not uiInitialized then return end
    local player = Player()
    local ship = player.craft
    if ship.maxCrewSize == nil or ship.crewSize == nil then return end

    local active = true
    local tooltip
    if not CheckFactionInteraction(player.index, 60000) then
        active = false
        tooltip = "Your relations with that faction aren't good enough."%_t
    elseif ship.minCrew.size - ship.crewSize < (CrewboardTweaksConfig.TransportShipMinMissingCrew or 300) then
        local amount = math.max(0, ship.minCrew.size - ship.crewSize)
        active = false
        local text = "We don't require more than 300 additional crew members. Additionally required crew members: ${amount}"%_t
        if CrewboardTweaksConfig.TransportShipMinMissingCrew then
            text = text:gsub(300, CrewboardTweaksConfig.TransportShipMinMissingCrew)
        end
        tooltip = text % {amount = amount}
    elseif transportData then
        active = false
        tooltip = "There's already a transport on the way."%_t
    end
    requestTransportButton.active = active
    requestTransportButton.tooltip = tooltip
end

-- CALLBACKS --
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
    local ship, freeSpace, buyableCrew, workforce, minWorkforce = CrewBoard.crewboardTweaks_collectData()
    if not ship then return end

    crewboardTweaks_freeCrewSpaceLabel.caption = "Hire required crew (free space ${num})"%_t % { num = freeSpace }
    for i = 1, 12 do
        local prof = CrewProfession(i)
        local wf = workforce[i] or 0
        local minWf = minWorkforce[i] or 0
        local wfUIPair = crewboardTweaks_crewWorkforceUI[i]
        wfUIPair.label.caption = wf.."/"..minWf
        if wf < minWf then
            wfUIPair.label.color = ColorInt(0xffff2626)
            wfUIPair.label.tooltip = nil
        else
            local mult = 1.0
            if i == CrewProfessionType.Engine or i == CrewProfessionType.Repair then
                mult = 1.3
            end
            if minWf * mult + 2 < wf then -- too much crew
                wfUIPair.label.color = ColorInt(0xff00b1d1)
                wfUIPair.label.tooltip = "You have too much crew of this type"%_t
            else
                wfUIPair.label.color = ColorInt(0xffe0e0e0)
                wfUIPair.label.tooltip = nil
            end
        end
    end
    local hireBtnTooltip = {}
    local price = 0
    local stationFaction = Faction()
    local buyer = Player()
    if ship.factionIndex == buyer.allianceIndex then
        buyer = buyer.alliance
    end
    for k, v in pairs(buyableCrew) do
        hireBtnTooltip[#hireBtnTooltip+1] = CrewProfession(k):name(v.amount)
        price = price + CrewBoard.getPriceAndTax(CrewProfession(k), v.amount, stationFaction, buyer)
    end
    if price > 0 then
        crewboardTweaks_hireReqCrewBtn.tooltip = table.concat(hireBtnTooltip, "\n").."\n".."Cost"%_t..": ".."¢${price}"%_t % {price = createMonetaryString(price)}
        crewboardTweaks_hireReqCrewBtn.active = true
    else
        crewboardTweaks_hireReqCrewBtn.tooltip = nil
        crewboardTweaks_hireReqCrewBtn.active = false
    end
end

function CrewBoard.crewboardTweaks_onHireRequiredBtn()
    invokeServerFunction("crewboardTweaks_hireRequiredBtn")
end

-- CALLABLE --
function CrewBoard.crewboardTweaks_receiveSettings(serverConfig)
    CrewboardTweaksConfig = serverConfig

    if not uiInitialized then return end

    local text = "You can request a crew transport ship here containing a complete crew for your current ship.\nOnly possible if your ship needs at least 300 more crew members."%_t
    text:gsub(300, CrewboardTweaksConfig.TransportShipMinMissingCrew)
    crewboardTweaks_transportLabel.caption = text
    CrewBoard.refreshUI()
end


else -- onServer


Azimuth = include("azimuthlib-basic")

local crewboardTweaks_configOptions = {
  _version = { default = "1.0", comment = "Config version. Don't touch." },
  TransportShipMinMissingCrew = { default = 300, min = 0, format = "floor", comment = "Minimal missing crew that is required to call a transport ship." }
}
local crewboardTweaks_isModified
CrewboardTweaksConfig, crewboardTweaks_isModified = Azimuth.loadConfig("CrewboardTweaks", crewboardTweaks_configOptions)
if crewboardTweaks_isModified then
    Azimuth.saveConfig("CrewboardTweaks", CrewboardTweaksConfig, crewboardTweaks_configOptions)
end

-- PREDEFINED --
-- Vanilla Fix: It's possible to call a transport ship even if you're missing < 300 people
crewboardTweaks_onRequestTransportButtonPressed = CrewBoard.onRequestTransportButtonPressed
function CrewBoard.onRequestTransportButtonPressed(...)
    local buyer, ship = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources)
    if not buyer then return end
    if ship.minCrew.size - ship.crewSize < CrewboardTweaksConfig.TransportShipMinMissingCrew then return end

    crewboardTweaks_onRequestTransportButtonPressed(...)
end

-- CALLABLE --
function CrewBoard.crewboardTweaks_sendSettings()
    invokeClientFunction(Player(callingPlayer), "crewboardTweaks_receiveSettings", { TransportShipMinMissingCrew = CrewboardTweaksConfig.TransportShipMinMissingCrew })
end
callable(CrewBoard, "crewboardTweaks_sendSettings")

function CrewBoard.crewboardTweaks_hireRequiredBtn()
    local player = Player(callingPlayer)
    local ship, _, buyableCrew = CrewBoard.crewboardTweaks_collectData(callingPlayer)
    if not ship then return end

    for k, v in pairs(buyableCrew) do
        CrewBoard.hireCrew(v.row, v.amount)
    end
end
callable(CrewBoard, "crewboardTweaks_hireRequiredBtn")


end


function CrewBoard.crewboardTweaks_collectData(playerIndex)
    local player = Player(playerIndex)
    local ship = player and player.craft or nil
    if not ship or not ship:hasComponent(ComponentType.Crew) then return end
    local freeSpace = ship.maxCrewSize - ship.crewSize

    local availableProfs = {}
    for i, pair in pairs(availableCrew) do
        availableProfs[pair.profession] = { number = pair.number, row = i }
    end

    local workforce = {}
    for k, v in pairs(ship.crew:getWorkforce()) do
        workforce[k.value] = v
    end
    local minWorkforce = {}
    for k, v in pairs(ship.minCrew:getWorkforce()) do
        minWorkforce[k.value] = v
    end

    -- calculate full crew
    local unemployed = ship.crew.unemployed
    local buyableCrew = {}
    for k, v in pairs(minWorkforce) do
        local wf = workforce[k] or 0
        if wf < v then
            -- professionals
            local available = availableProfs[k] or { number = 0 }
            if available.number > 0 and CrewBoard.canHireCrew(ship, available.row) then
                local amount = math.min(available.number, math.ceil((v - wf) / 1.5))
                buyableCrew[k] = { amount = amount, row = available.row }
                wf = wf + amount * 1.5
            end
            -- untrained
            if wf < v and CrewProfession(k).assignable then
                available = availableProfs[CrewProfessionType.None] or { number = 0 }
                if available.number > 0 then
                    local amount = math.min(available.number, math.ceil(v - wf))
                    if unemployed > 0 then -- take unemployed ship crew into account
                        local minValue = math.min(amount, unemployed)
                        unemployed = unemployed - minValue
                        amount = amount - minValue
                    end
                    local untrained = buyableCrew[CrewProfessionType.None]
                    if not untrained then
                        buyableCrew[CrewProfessionType.None] = { amount = amount, row = available.row }
                    else
                        untrained.amount = untrained.amount + amount
                    end
                    available.number = available.number - amount
                end
            end
        end
    end

    return ship, freeSpace, buyableCrew, workforce, minWorkforce
end