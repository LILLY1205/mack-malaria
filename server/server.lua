local RSGCore = exports['rsg-core']:GetCoreObject()

RSGCore.Functions.CreateUseableItem("malaria_medicine", function(source)
    TriggerClientEvent('mack-malaria:client:usemedicine', source)
end)

RegisterServerEvent('mack-malaria:medicineUsed')
AddEventHandler('mack-malaria:medicineUsed', function()
    local Player = RSGCore.Functions.GetPlayer(source)
    if Player then
        Player.Functions.RemoveItem('malaria_medicine', 1)
        TriggerClientEvent("rsg-inventory:client:ItemBox", source, RSGCore.Shared.Items["malaria_medicine"], "remove")
    end
end)

RegisterServerEvent('mack-malaria:giveback')
AddEventHandler('mack-malaria:giveback', function()
    local Player = RSGCore.Functions.GetPlayer(source)
    if Player then
        Player.Functions.AddItem('malaria_medicine', 1)
        TriggerClientEvent("rsg-inventory:client:ItemBox", source, RSGCore.Shared.Items["malaria_medicine"], "add")
    end
end)

RSGCore.Functions.CreateUseableItem("oldbox", function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if Player then
        Player.Functions.RemoveItem('oldbox', 1)
        TriggerClientEvent("rsg-inventory:client:ItemBox", source, RSGCore.Shared.Items["oldbox"], "remove")
        TriggerClientEvent('mack-malaria:useOldbox', source)
    end
end)

RegisterNetEvent('mack-malaria:server:removeitem', function(item, amount)
    local source = source
    local Player = RSGCore.Functions.GetPlayer(source)
    
    if Player then
        Player.Functions.RemoveItem(item, amount)
        TriggerClientEvent("rsg-inventory:client:ItemBox", source, RSGCore.Shared.Items[item], "remove")
    end
end)

RegisterServerEvent('mack-malaria:spreadPlayer')
AddEventHandler('mack-malaria:spreadPlayer', function(targetPlayer)
    local source = source
    local sourcePlayer = RSGCore.Functions.GetPlayer(source)
    local targetPlayerObj = RSGCore.Functions.GetPlayer(targetPlayer)
    
    if not sourcePlayer or not targetPlayerObj then return end
    
    -- Double-check distance on server side to prevent cheating
    local sourceCoords = GetEntityCoords(GetPlayerPed(source))
    local targetCoords = GetEntityCoords(GetPlayerPed(targetPlayer))
    local distance = #(sourceCoords - targetCoords)
    
    if distance <= Config.SpreadDistance then
        if targetPlayerObj.PlayerData.job.type ~= "leo" and 
           targetPlayerObj.PlayerData.job.name ~= "medic" then
            TriggerClientEvent('mack-malaria:spread', targetPlayer)
            if Config.Debug then
                print(string.format('Malaria spread from %s to %s at distance %0.2f', 
                    source, targetPlayer, distance))
            end
        end
    else
        if Config.Debug then
            print(string.format('Spread attempt failed - distance %0.2f exceeds limit %0.2f', 
                distance, Config.SpreadDistance))
        end
    end
end)

