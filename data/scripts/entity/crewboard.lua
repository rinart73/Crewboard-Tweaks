local workforceUI = workforceUI or {} -- bringing 1.1.2 stuff to earlier versions

local Azimuth -- server includes
local CrewboardTweaksConfig -- client/server
local crewboardTweaks_freeCrewSpaceLabel, crewboardTweaks_hireReqCrewBtn, crewboardTweaks_transportLabel -- UI
local crewboardTweaks_initialize -- client/server extended functions
local crewboardTweaks_onRequestTransportButtonPressed -- server extended functions
local crewboardTweaks_onShowWindow, crewboardTweaks_refreshUI -- client extended functions


if onClient() then


include("azimuthlib-uiproportionalsplitter")

-- PREDEFINED --

crewboardTweaks_initialize = CrewBoard.initialize
function CrewBoard.initialize(...)
    crewboardTweaks_initialize(...)

    CrewboardTweaksConfig = { TransportShipMinMissingCrew = 300 } -- default config
    invokeServerFunction("crewboardTweaks_sendSettings")
end

function CrewBoard.initUI() -- overriden
    local res = getResolution()
    local size = vec2(890, 500)
    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5));
    menu:registerWindow(window, "Hire Crew"%_t);

    window.caption = "Hire Crew"%_t
    window.showCloseButton = 1
    window.moveable = 1

    local hsplit = UIHorizontalSplitter(Rect(vec2(0, 10), size), 10, 10, 0.8)
    local lister = UIVerticalLister(hsplit.top, 10, 10)

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

    for i = 0, 5 do
        local rect = lister:nextRect(30)

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

        table.insert(uiGroups, {pic=pic, bar=bar, slider=slider, box=box, label=label, button=button, show=show, hide=hide})
    end

    -- current workforce
    lister:nextRect(1)
    local rect = lister:nextRect(30)
    local vsplit = UIVerticalProportionalSplitter(rect, 10, 0, {0.5, 270})
    crewboardTweaks_freeCrewSpaceLabel = window:createLabel(vsplit[1], "Current Crew"%_t, 14)
    crewboardTweaks_freeCrewSpaceLabel:setBottomLeftAligned()
    rect = vsplit[2]
    crewboardTweaks_hireReqCrewBtn = window:createButton(Rect(rect.lower, rect.upper + vec2(10, 0)), "Hire required crew"%_t, "crewboardTweaks_onHireRequiredBtn")
    crewboardTweaks_hireReqCrewBtn.maxTextSize = 16

    for row = 0, 1 do
        local workforceSplit = UIVerticalMultiSplitter(lister:nextRect(25), 10, 0, 6)

        for i = 0, 6 do
            local professionIndex = i
            if row == 1 then
                if i == 6 then break end

                professionIndex = i + 7
            end

            local profession = CrewProfession(professionIndex)
            local split = UIVerticalSplitter(workforceSplit:partition(i), 10, 0, 0.5)
            split:setLeftQuadratic()

            local picture = window:createPicture(split.left, profession.icon)
            picture.isIcon = true
            local label = window:createLabel(split.right, "", 14)
            label:setLeftAligned()

            workforceUI[professionIndex] = {picture = picture, label = label}
        end
    end

    window:createLine(hsplit.top.bottomLeft, hsplit.top.bottomRight)

    -- crew transport
    local hsplit2 = UIHorizontalSplitter(hsplit.bottom, 10, 0, 0.4)
    local vmsplit = UIVerticalMultiSplitter(hsplit2.bottom, 10, 0, 2)

    requestTransportButton = window:createButton(vmsplit:partition(2), "Request Transport"%_t, "onRequestTransportButtonPressed")

    local text = "You can request a crew transport ship here containing a complete crew for your current ship.\nOnly possible if your ship needs at least 300 more crew members."%_t
    text = text:gsub(300, CrewboardTweaksConfig.TransportShipMinMissingCrew)
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

if GameVersion() < Version(1, 1, 2) then
--
crewboardTweaks_onShowWindow = CrewBoard.onShowWindow
function CrewBoard.onShowWindow(...)
    crewboardTweaks_onShowWindow(...)

    local craft = Player().craft
    if craft then
        craft:registerCallback("onCrewChanged", "onCrewChanged")
    end
end

crewboardTweaks_onCloseWindow = CrewBoard.onCloseWindow
function CrewBoard.onCloseWindow(...)
    if crewboardTweaks_onCloseWindow then crewboardTweaks_onCloseWindow(...) end

    local craft = Player().craft
    if craft then
        craft:unregisterCallback("onCrewChanged", "onCrewChanged")
    end
end
--
end

-- FUNCTIONS --

crewboardTweaks_refreshUI = CrewBoard.refreshUI
function CrewBoard.refreshUI(...)
    crewboardTweaks_refreshUI(...)

    if not uiInitialized then return end
    local ship, buyableCrew = CrewBoard.crewboardTweaks_collectData()
    if not ship then return end

    crewboardTweaks_freeCrewSpaceLabel.caption = "Current Crew"%_t .. " (free space ${num})"%_t % { num = ship.maxCrewSize - ship.crewSize }

    if GameVersion() < Version(1, 1, 2) then -- bringing 1.1.2 stuff to earlier versions
        -- current workforce
        local currentWorkforce = {}
        for profession, amount in pairs(ship.crew:getWorkforce()) do
            currentWorkforce[profession.value] = amount
        end

        local minCrew = ship.minCrew
        local minWorkforce = {}
        for profession, amount in pairs(minCrew:getWorkforce()) do
            minWorkforce[profession.value] = amount
        end

        for professionIndex, data in pairs(workforceUI) do
            local required = minWorkforce[professionIndex] or 0
            local available = currentWorkforce[professionIndex] or 0
            if required == 0 then
                data.label.caption = available
            else
                data.label.caption = "${workforce}/${required}"%_t % {workforce = available, required = required}
            end

            if required > available then
                data.label.color = ColorRGB(1, 1, 0)
            else
                data.label.color = ColorRGB(1, 1, 1)
            end

            data.picture.tooltip = CrewProfession(professionIndex):name(available)
        end
    end

    -- hire required crew
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

    -- crew transport
    local active = true
    local tooltip
    if not CheckFactionInteraction(Player().index, 60000) then
        active = false
        tooltip = "Your relations with that faction aren't good enough."%_t
    elseif ship.minCrew.size - ship.crewSize < CrewboardTweaksConfig.TransportShipMinMissingCrew then
        local amount = math.max(0, ship.minCrew.size - ship.crewSize)
        active = false
        local text = "We don't require more than 300 additional crew members. Additionally required crew members: ${amount}"%_t
        text = text:gsub(300, CrewboardTweaksConfig.TransportShipMinMissingCrew)
        tooltip = text % {amount = amount}
    elseif transportData then
        active = false
        tooltip = "There's already a transport on the way."%_t
    end
    requestTransportButton.active = active
    requestTransportButton.tooltip = tooltip
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

-- CALLBACKS --

if GameVersion() < Version(1, 1, 2) then
--
function CrewBoard.onCrewChanged()
    CrewBoard.refreshUI()
end
--
end

function CrewBoard.crewboardTweaks_onHireRequiredBtn()
    invokeServerFunction("crewboardTweaks_hireRequiredBtn")
end


else -- onServer


Azimuth = include("azimuthlib-basic")

-- PREDEFINED --

crewboardTweaks_initialize = CrewBoard.initialize
function CrewBoard.initialize(...)
    crewboardTweaks_initialize(...)

    local crewboardTweaks_configOptions = {
      _version = { default = "1.0", comment = "Config version. Don't touch." },
      TransportShipMinMissingCrew = { default = 300, min = 0, format = "floor", comment = "Minimal missing crew that is required to call a transport ship." }
    }
    local crewboardTweaks_isModified
    CrewboardTweaksConfig, crewboardTweaks_isModified = Azimuth.loadConfig("CrewboardTweaks", crewboardTweaks_configOptions)
    if crewboardTweaks_isModified then
        Azimuth.saveConfig("CrewboardTweaks", CrewboardTweaksConfig, crewboardTweaks_configOptions)
    end
end

-- CALLABLE --

-- Vanilla Fix: It was possible to call a transport ship even if you were missing < 300 people
crewboardTweaks_onRequestTransportButtonPressed = CrewBoard.onRequestTransportButtonPressed
function CrewBoard.onRequestTransportButtonPressed(...)
    local buyer, ship = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources)
    if not buyer then return end
    if ship.minCrew.size - ship.crewSize < CrewboardTweaksConfig.TransportShipMinMissingCrew then return end

    crewboardTweaks_onRequestTransportButtonPressed(...)
end

function CrewBoard.crewboardTweaks_sendSettings()
    invokeClientFunction(Player(callingPlayer), "crewboardTweaks_receiveSettings", { TransportShipMinMissingCrew = CrewboardTweaksConfig.TransportShipMinMissingCrew })
end
callable(CrewBoard, "crewboardTweaks_sendSettings")

function CrewBoard.crewboardTweaks_hireRequiredBtn()
    local player = Player(callingPlayer)
    local ship, buyableCrew = CrewBoard.crewboardTweaks_collectData(callingPlayer)
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

    return ship, buyableCrew
end