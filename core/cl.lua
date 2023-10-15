ESX = nil
script_name = GetCurrentResourceName()

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent(Config["getSharedObject"], function(obj) ESX = obj end)
		Citizen.Wait(0)
	end	
end)

RegisterNetEvent(script_name.."cl:Template")
AddEventHandler(script_name.."cl:Template", function()
	
end)
