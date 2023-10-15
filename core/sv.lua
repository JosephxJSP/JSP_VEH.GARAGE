ESX = nil
script_name = GetCurrentResourceName()

TriggerEvent(Config["getSharedObject"], function(obj) ESX = obj end)


RegisterServerEvent(script_name.."sv:Template")
AddEventHandler(script_name.."sv:Template", function()

end)