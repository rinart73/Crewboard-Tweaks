local crewboardTweaks_onTransferCrew -- server, extended function


if onServer() then


-- Fix vanilla exploit that allows to steal other people crew from a crew transport
crewboardTweaks_onTransferCrew = CrewTransport.onTransferCrew
function CrewTransport.onTransferCrew(...)
    local player = Player(callingPlayer)
    if not player or not data or not data.reserved or player.craftIndex.string ~= data.reserved then return end

    crewboardTweaks_onTransferCrew(...)
end


end