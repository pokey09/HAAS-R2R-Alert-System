local function debugPrint(message)
    if Config.Debug then
        print(message)
    end
end

-- Utility function to get the name of the vehicle model
local function getVehicleName(vehicle)
    local model = GetEntityModel(vehicle)
    return GetDisplayNameFromVehicleModel(model)
end

-- Check if the vehicle is in the monitored list
local function isVehicleInConfig(vehicle)
    local model = GetEntityModel(vehicle)
    for _, modelName in ipairs(Config.MonitoredVehicles) do
        if model == GetHashKey(modelName) then
            return true
        end
    end
    return false
end

-- Determine if the heading is similar
local function isHeadingSimilar(playerHeading, targetHeading, threshold)
    local delta = math.abs((playerHeading - targetHeading) % 360)
    delta = delta > 180 and 360 - delta or delta -- Ensure shortest angle difference
    debugPrint(string.format("Heading delta: %.2f", delta))
    return delta <= threshold
end

-- Determine if the heading is opposite
local function isHeadingOpposite(playerHeading, targetHeading, threshold)
    local delta = math.abs((playerHeading - targetHeading) % 360)
    delta = delta > 180 and 360 - delta or delta -- Ensure shortest angle difference
    debugPrint(string.format("Heading delta for opposite: %.2f", delta))
    return math.abs(delta - 180) <= threshold
end

-- Determine if a vehicle is approaching the player
local function isVehicleApproaching(playerCoords, playerVelocity, targetCoords, targetVelocity)
    local relativePosition = targetCoords - playerCoords
    local relativeVelocity = targetVelocity - playerVelocity
    local dotProduct = relativePosition.x * relativeVelocity.x + relativePosition.y * relativeVelocity.y + relativePosition.z * relativeVelocity.z
    return dotProduct < 0
end

-- Get the relative direction of a vehicle
local function getRelativeDirection(playerCoords, playerHeading, targetCoords)
    -- Calculate the relative position vector from player to target vehicle
    local relativeX = targetCoords.x - playerCoords.x
    local relativeY = targetCoords.y - playerCoords.y

    -- Rotate the relative position into the player's local coordinate space
    local headingRadians = math.rad(-playerHeading) -- Negative for clockwise rotation
    local localX = relativeX * math.cos(headingRadians) - relativeY * math.sin(headingRadians)
    local localY = relativeX * math.sin(headingRadians) + relativeY * math.cos(headingRadians)

    -- Determine direction based on local X and Y coordinates
    if localY > 0 then -- In front of the player
        if localX > 0 then
            return "right"
        else
            return "left"
        end
    else -- Behind the player
        return "back"
    end
end

Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        if IsPedInAnyVehicle(playerPed, false) then
            local playerVehicle = GetVehiclePedIsIn(playerPed, false)
            local playerHeading = GetEntityHeading(playerVehicle)
            local playerCoords = GetEntityCoords(playerVehicle)
            local playerVelocity = GetEntityVelocity(playerVehicle)

            for _, vehicle in ipairs(GetGamePool('CVehicle')) do
                if vehicle ~= playerVehicle and isVehicleInConfig(vehicle) then

                    if IsVehicleSirenOn(vehicle) and IsVehicleSirenOn(playerVehicle) then
                        local targetCoords = GetEntityCoords(vehicle)
                        local targetVelocity = GetEntityVelocity(vehicle)
                        local targetHeading = GetEntityHeading(vehicle)
                        local distance = #(playerCoords - targetCoords)

                        debugPrint(string.format(
                            "Detected vehicle '%s' at coords (x=%.2f, y=%.2f, z=%.2f), heading=%.2f",
                            getVehicleName(vehicle), targetCoords.x, targetCoords.y, targetCoords.z, targetHeading
                        ))
                        debugPrint(string.format(
                            "Player vehicle at coords (x=%.2f, y=%.2f, z=%.2f), heading=%.2f",
                            playerCoords.x, playerCoords.y, playerCoords.z, playerHeading
                        ))
                        debugPrint(string.format("Distance to vehicle: %.2f", distance))

                        if distance < Config.DetectionDistance
                            and not (isHeadingSimilar(playerHeading, targetHeading, Config.HeadingThreshold)
                            or isHeadingOpposite(playerHeading, targetHeading, Config.HeadingThreshold))
                            and isVehicleApproaching(playerCoords, playerVelocity, targetCoords, targetVelocity) then
                            local direction = getRelativeDirection(playerCoords, playerHeading, targetCoords)
                            if direction == "back" then
                                debugPrint("Vehicle is behind the player. No flasher.")
                            elseif direction == "left" or direction == "right" then
                                debugPrint(string.format(
                                    "Flasher triggered for vehicle '%s' approaching from the %s",
                                    getVehicleName(vehicle), direction
                                ))
                                SendNUIMessage({
                                    action = "showFlasher",
                                    direction = direction
                                })
                            end
                        else
                            debugPrint(string.format("Vehicle '%s' is heading in a similar or opposite direction.", getVehicleName(vehicle)))
                            SendNUIMessage({ action = "hideFlasher" })
                        end
                    else
                        debugPrint("Siren is OFF for detected vehicle.")
                        SendNUIMessage({ action = "hideFlasher" })
                    end
                end
            end
        end

        Wait(500)
    end
end)

RegisterNUICallback("hideFlasher", function()
    debugPrint("NUI Callback: Hiding flasher.")
    SendNUIMessage({ action = "hideFlasher" })
end)
