ESX = nil
script_name = GetCurrentResourceName()
server_ip = GetCurrentServerEndpoint()
Call = {}
Call.list = {}
Call.Id = 0
local isLoadedData = false
local isFirstTime = true
local configData = {
	GARAGES = {},
	POUNDS = {},
	REMOVES = {},
}
local ListObject = {
	OBJECT = {},
	PED = {}
}
local allVehData = {}
local currentZone = {}
local playerJob = "unemployed"

debug = function(msg)
    print("^7[^3"..script_name.."^7] ^1Debug: ^4"..msg)
end

newEvnet = function(name, headler)
	return RegisterNetEvent(name), AddEventHandler(name, headler)
end

CreateThread(function()
	while ESX == nil do
		TriggerEvent(Config["EventRoute"]["getSharedObject"], function(obj) ESX = obj end)
		Wait(0)
	end	
	Wait(2000)
	SendNUIMessage({
		action = "init",
		data = { locale=Config["Locale"].UI, interface=Config["Interface"]},
	})
	playerJob = ESX.GetPlayerData().job.name
end)

CreateThread(function()
	while not isLoadedData do
		TriggerServerEvent(script_name..":sv:getConfigData")
		Wait(5000)
		if isFirstTime then loadAllVehicle() Wait(500) end
	end	
end)

Call.Trigger = function(n,cb,...)
	Call.list[Call.Id] = cb
	TriggerServerEvent(script_name..":sv:Returndata", n , Call.Id, ...)
	Call.Id = ( Call.Id < 65535 ) and ( Call.Id + 1 ) or 0
end

newEvnet(script_name..":cl:Returndata",function(Id, ...)
	Call.list[Id](...)
	Call.list[Id] = nil
end)

newEvnet(script_name..":cl:getConfigData", function(data)
	loadConfigFile(data)
	isLoadedData = true
end)

newEvnet(Config["EventRoute"]["onPlayerDeath"], function()
	closeMenu()
end)

newEvnet(Config["EventRoute"]["setJob"], function(job)
	playerJob = job.name
end)

loadConfigFile = function(allFilename)
	local configFile = allFilename

	CreateThread(function()
		for k, v in pairs(configFile) do
			for _, j in ipairs(v) do
				local data = LoadResourceFile(script_name, string.format("config/position/%s/%s", k, j))
				local chunk, err = load(data, "example3.lua", "t")
				if chunk then
					local tableResult = chunk()
					configData[k][string.match(j, "^(.*)%.lua$")] = tableResult
				end
				Wait(500)
			end
		end
		createOption()
	end)
end

createOption = function()
	print(true)
	CreateThread(function()
		for k, v in pairs(configData) do
			for _, j in pairs(v) do
				-- Blip
				if j.others.blip ~= nil and j.others.blip.enable then
					if j.spawner then
						for __, d in pairs(j.spawner.from) do
							blips = AddBlipForCoord(d.coords)
							SetBlipDisplay(blips, 4)
							SetBlipSprite(blips, j.others.blip.sprite)
							SetBlipScale(blips, j.others.blip.size)
							SetBlipColour(blips, j.others.blip.color)
							SetBlipAsShortRange(blips, true)
							AddTextEntry("BLIP_GARAGE", j.others.blip.name)
							BeginTextCommandSetBlipName("BLIP_GARAGE")
							EndTextCommandSetBlipName(blips)
						end
					else
						for __, d in pairs(j.remover) do
							blips = AddBlipForCoord(d.coords)
							SetBlipDisplay(blips, 4)
							SetBlipSprite(blips, j.others.blip.sprite)
							SetBlipScale(blips, j.others.blip.size)
							SetBlipColour(blips, j.others.blip.color)
							SetBlipAsShortRange(blips, true)
							AddTextEntry("BLIP_GARAGE", j.others.blip.name)
							BeginTextCommandSetBlipName("BLIP_GARAGE")
							EndTextCommandSetBlipName(blips)
						end
					end
				end

				-- Object
				if j.others.object ~= nil and j.others.object.enable then
					if j.spawner then
						for __, d in pairs(j.spawner.from) do
							coords = vector3(d.coords.x , d.coords.y, d.coords.z + j.others.object.z_offset)
							if not ListObject["OBJECT"][coords] then
								ESX.Game.SpawnLocalObject(j.others.object.model, coords, function(obj)
									SetEntityHeading(obj, j.others.object.heading)
									SetEntityVelocity(obj, 0.0, 0.0, -2.0)
									Wait(100)
									if j.others.object.place_on_ground then
										PlaceObjectOnGroundProperly(obj)
									end
									SetEntityCollision(obj, j.others.object.collision, j.others.object.collision)
									FreezeEntityPosition(obj, true)
									-- table.insert(ListObject["OBJECT"], obj)
									ListObject["OBJECT"][coords] = obj
									print(d.coords.x , d.coords.y, d.coords.z)
								end)
							end
						end
					end
				end

				-- Ped
				if j.others.ped ~= nil and j.others.ped.enable then
					if j.spawner then
						for __, d in pairs(j.spawner.from) do
							RequestModel(j.others.ped.model)
							while (not HasModelLoaded(j.others.ped.model)) do
								Citizen.Wait(1)
							end
							local ped = CreatePed(4, j.others.ped.model, d.coords.x , d.coords.y, d.coords.z + j.others.ped.z_offset, j.others.ped.heading, false, true)
							FreezeEntityPosition(ped, true)
							SetEntityInvincible(ped, true)
							SetBlockingOfNonTemporaryEvents(ped, true)
							SetEntityCollision(ped, j.others.ped.collision, j.others.ped.collision)
							if j.others.ped.animation.enable then
								RequestAnimDict(j.others.ped.animation.dict)
								while (not HasAnimDictLoaded(j.others.ped.animation.dict)) do
									Citizen.Wait(1)
								end
								Wait(100)
								TaskPlayAnim(ped, j.others.ped.animation.dict, j.others.ped.animation.name, 8.0, 0.0, -1, 1, 1, 0, 0, 0, 0)
							end
							table.insert(ListObject["PED"], ped)
						end
					end
				end
			end
		end
		debug("createBlip!")
	end)
end

-- Draw Markers
CreateThread(function()
	while true do
		Wait(0)
		local playerPed = PlayerPedId()
		local coords = GetEntityCoords(playerPed)
		local canSleep = true
		local allowJob = true
		
		for k,v in pairs(configData) do
			for _, j in pairs(v) do
				
				if tableCount(j.allow_jobs) > 0 then
					if j.allow_jobs[playerJob] then
						allowJob = true
					else
						allowJob = false
					end
				else
					allowJob = true
				end

				if j.spawner then
					for __, d in pairs(j.spawner.from) do
						if j.others.marker.enable then
							if (GetDistanceBetweenCoords(coords, d.coords, true) < j.others.marker.distance) then
								canSleep = false
								if IsPedInAnyVehicle(PlayerPedId(), true) == false and allowJob then
									if not (GetDistanceBetweenCoords(coords, d.coords, true) < d.radius) then
										if j.others.marker.useAddon then
											if not HasStreamedTextureDictLoaded(j.others.marker.addon.idle.ytd) then
												RequestStreamedTextureDict(j.others.marker.addon.idle.ytd, true)
												while not HasStreamedTextureDictLoaded(j.others.marker.addon.idle.ytd) do
													Wait(1)
												end
											else
												DrawMarker(9, d.coords.x, d.coords.y, d.coords.z + j.others.marker.z_offset, 0.0, 0.0, 0.0, 90.0, 0.0, 0.0, j.others.marker.size, j.others.marker.size, j.others.marker.size, 255, 255, 255, 255, false, false, 2, true, j.others.marker.addon.idle.ytd, j.others.marker.addon.idle.img, false)
											end
										else
											DrawMarker(j.others.marker.game.sprite, d.coords.x, d.coords.y, d.coords.z + j.others.marker.z_offset, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, j.others.marker.size, 2.0, j.others.marker.height, j.others.marker.game.color.idle.r, j.others.marker.game.color.idle.g, j.others.marker.game.color.idle.b, j.others.marker.game.color.idle.a, false, true, 2, j.others.marker.turn, false, false, false)
										end
									else
										if j.others.marker.useAddon then
											if not HasStreamedTextureDictLoaded(j.others.marker.addon.active.ytd) then
												RequestStreamedTextureDict(j.others.marker.addon.active.ytd, true)
												while not HasStreamedTextureDictLoaded(j.others.marker.addon.active.ytd) do
													Wait(1)
												end
											else
												DrawMarker(9, d.coords.x, d.coords.y, d.coords.z + j.others.marker.z_offset, 0.0, 0.0, 0.0, 90.0, 0.0, 0.0, j.others.marker.size, j.others.marker.size, j.others.marker.size, 255, 255, 255, 255, false, false, 2, true, j.others.marker.addon.active.ytd, j.others.marker.addon.active.img, false)
											end
										else
											DrawMarker(j.others.marker.game.sprite, d.coords.x, d.coords.y, d.coords.z + j.others.marker.z_offset, 0.0, 0.0, 0.0, 0, 0.0, 0.0, j.others.marker.size, 2.0, j.others.marker.height, j.others.marker.game.color.active.r, j.others.marker.game.color.active.g, j.others.marker.game.color.active.b, j.others.marker.game.color.active.a, false, true, 2, j.others.marker.turn, false, false, false)
										end
										if IsControlJustPressed(0, Config["Keys"].action) and not IsPedDeadOrDying(PlayerPedId()) then
											openMenu(k, j)
										end
									end
								end
							end
						end
					end
				elseif j.remover then
					for __, d in pairs(j.remover) do
						if j.others.marker.enable then
							if (GetDistanceBetweenCoords(coords, d.coords, true) < j.others.marker.distance) then
								canSleep = false
								if GetPedInVehicleSeat(GetVehiclePedIsIn(PlayerPedId()), -1) == PlayerPedId() and allowJob then
									if not (GetDistanceBetweenCoords(coords, d.coords, true) < d.radius) then
										DrawMarker(j.others.marker.sprite, d.coords.x, d.coords.y, d.coords.z + j.others.marker.z_offset, 0.0, 0.0, 0.0, 0, 0.0, 0.0, j.others.marker.size, j.others.marker.size, j.others.marker.height, j.others.marker.color.idle.r, j.others.marker.color.idle.g, j.others.marker.color.idle.b, j.others.marker.color.idle.a, false, false, 2, j.others.marker.turn, false, false, false)
									else
										DrawMarker(j.others.marker.sprite, d.coords.x, d.coords.y, d.coords.z + j.others.marker.z_offset, 0.0, 0.0, 0.0, 0, 0.0, 0.0, j.others.marker.size, j.others.marker.size, j.others.marker.height, j.others.marker.color.idle.r, j.others.marker.color.active.g, j.others.marker.color.active.b, j.others.marker.color.active.a, false, false, 2, j.others.marker.turn, false, false, false)
										if j.auto_mode and not IsPedDeadOrDying(PlayerPedId()) then
											storedVehicle(j)
										else
											if IsControlJustPressed(0, Config["Keys"].action) and not IsPedDeadOrDying(PlayerPedId()) then
												storedVehicle(j)
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end

		if canSleep then
            Wait(500)
        end
	end
end)

NuiFocus = function(status)
	SetNuiFocus(status, status)
end

loadAllVehicle = function()
	CreateThread(function()
		Call.Trigger(script_name..":sv:getAllVeh", function(cb)
			allVehData = cb
			for k,v in pairs(allVehData) do
				allVehData[k].model = GetDisplayNameFromVehicleModel((json.decode(v.vehicle)).model)
				allVehData[k].name = GetResourceKvpString(script_name..":("..server_ip.."):name-"..v.plate) or GetDisplayNameFromVehicleModel((json.decode(v.vehicle)).model)
				allVehData[k].favorite = toBoolean(GetResourceKvpString(script_name..":("..server_ip.."):favorite-"..v.plate)) or false
			end
			isFirstTime = false
		end)
	end)
end

toBoolean = function(str)
    local bool = false
    if str == "true" then
        bool = true
    end
    return bool
end

tableCount = function(table)
	local count = 0
	for _,v in pairs(table) do
		count = count + 1
	end
	return count
end

storedVehicle = function(index)
	local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
	local plate = Utils.Trim(GetVehicleNumberPlateText(vehicle))

	if getVehicle(plate) then
		TriggerServerEvent(script_name..":sv:updateVehicleHealth", plate, Utils.ClientGetVehicleProperties(vehicle))
		getVehicle(plate).target = index.target

		local currentVehicleProperties = Utils.ClientGetVehicleProperties(vehicle)
		local updateVehicleProperties = json.decode(getVehicle(plate).vehicle)
		updateVehicleProperties.tankHealth = currentVehicleProperties.tankHealth
		updateVehicleProperties.engineHealth = currentVehicleProperties.engineHealth
		updateVehicleProperties.windowsBroken = currentVehicleProperties.windowsBroken
		updateVehicleProperties.fuelLevel = currentVehicleProperties.fuelLevel
		updateVehicleProperties.dirtLevel = currentVehicleProperties.dirtLevel
		updateVehicleProperties.bodyHealth = currentVehicleProperties.bodyHealth
		getVehicle(plate).vehicle = json.encode(updateVehicleProperties)
		
		TriggerServerEvent(script_name..":sv:updateVehicleTarget", plate, index.target)

		DeleteEntity(vehicle)
	else
		Config.ClientNotification("error", Config["Locale"].Notify.not_owner)
		Wait(5000)
	end
end

openMenu = function(type, data)
	currentZone = data
	if isFirstTime then loadAllVehicle() Wait(500) end
	NuiFocus(true)
	SendNUIMessage({
		action = "openMenu",
		type = type,
		data = {
			title = data.title,
			options = data.options,
			vehicle = allVehData,
			target = data.target or Config["BlockPund"],
		}
	})
end

closeMenu = function()
	NuiFocus(false)
	SendNUIMessage({ action = "closeMenu" })
end

RegisterNUICallback("closeMenu", function()
	closeMenu()
end)

RegisterNUICallback("setFavorite", function(data)
	local name = script_name..":("..server_ip.."):favorite-"..data.plate
	SetResourceKvp(name, tostring(data.status))
	getVehicle(data.plate).favorite = toBoolean(GetResourceKvpString(name)) or false
end)

RegisterNUICallback("onClickButton", function(data)
	local xplate = data.plate
	local xtype = data.type
	local xmodel = json.decode(getVehicle(xplate).vehicle).model
	if currentZone.options[xtype].price.amount > 0 then
		Call.Trigger(script_name..":sv:checkMoney", function(hasMoney)
			if not hasMoney then
				Config.ClientNotification("error", Config["Locale"].Notify.no_money)
			else
				if xtype == "inside" or xtype == "trunk" then
					openVehicleInventory(xtype, xplate, xmodel)
				elseif xtype == "spawn" then
					spawnedVehicle(xplate)
				end
				closeMenu()
			end
		end, currentZone.options[xtype].price)
	else
		if xtype == "inside" or xtype == "trunk" then
			openVehicleInventory(xtype, xplate, xmodel)
		elseif xtype == "spawn" then
			spawnedVehicle(xplate)
		end
		closeMenu()
	end
end)

RegisterNUICallback("getVehicleWeight", function(data, cb)
	local model, inside, trunk
	if GetResourceState("JSP_VEH.INVENTORY") ~= "missing" then
		local vehicle = getVehicle(data.plate)
		model = json.decode(vehicle.vehicle).model
		inside = exports["JSP_VEH.INVENTORY"]:getVehicleData("inside", data.plate, model)
		trunk = exports["JSP_VEH.INVENTORY"]:getVehicleData("trunk", data.plate, model)
	else

	end
	cb({ inside={current=inside.weight, max=inside.max_weight}, trunk={current=trunk.weight, max=trunk.max_weight} })
end)

RegisterNUICallback("changeVehicleName", function(data)
	local plate = data.plate
	local name = data.name
	local kvp_name = script_name..":("..server_ip.."):name-"..plate

	if name == "" or name == nil then
		DeleteResourceKvp(kvp_name)
	else
		SetResourceKvp(kvp_name, name)
	end

	getVehicle(plate).name = GetResourceKvpString(kvp_name) or GetDisplayNameFromVehicleModel((json.decode(v.vehicle)).model)
end)

openVehicleInventory = function(type, plate, model)
	--@ type: ประเภทการเปิด (inside / trunk)
	--@ plate: ทะเบียนรถ
	if GetResourceState("JSP_VEH.INVENTORY") ~= "missing" then
		TriggerEvent("JSP_VEH.INVENTORY:cl:OpenVehInventory", type, plate, model)
	else

	end
end

spawnedVehicle = function(plate)
	CreateThread(function()
		local spawnPoint = {}
		local playerCoords = GetEntityCoords(PlayerPedId())
		for k,v in pairs(currentZone.spawner.to) do
			spawnPoint[k] = {
				index = k,
				distance = GetDistanceBetweenCoords(playerCoords, v.coords, true)
			}
		end
		local function compareByB(a, b)
			return a.distance < b.distance
		end
		table.sort(spawnPoint, compareByB)

		local __spv = function(plate)
			local data = getVehicle(plate)
			for i, entry in ipairs(spawnPoint) do
				if not IsAnyVehicleNearPoint(currentZone.spawner.to[entry.index].coords, 4.0) then
					Utils.SpawnVehicle((json.decode(data.vehicle)).model, currentZone.spawner.to[entry.index].coords, currentZone.spawner.to[entry.index].heading, function(vehicle)
						Utils.ClientSetVehicleProperties(vehicle, json.decode(data.vehicle))
						TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
						-- Set Vehicle Targer CL/SV
						data.target = nil
						TriggerServerEvent(script_name..":sv:updateVehicleTarget", data.plate, nil)
					end)
					break
				end
			end
		end

		if currentZone.target == nil or currentZone.target[getVehicle(plate).target] then
			__spv(plate)
		else
			Config.ClientNotification("error", Config["Locale"].Notify.not_is_garage)
		end
	end)
end

getVehicle = function(plate)
	local vehicle = false
	for k,v in pairs(allVehData) do
		if v.plate == plate then
			vehicle = allVehData[k]
			break
		end
	end
	return vehicle
end

newEvnet(script_name..":cl:AddVehicle", function(vehicle)
	table.insert(allVehData, {
		vehicle = vehicle.vehicle,
		owner = vehicle.owner,
		type = vehicle.type,
		target = vehicle.target,
		plate = json.decode(vehicle.vehicle).plate,
		model = GetDisplayNameFromVehicleModel((json.decode(vehicle.vehicle)).model),
		name = GetResourceKvpString(script_name..":("..server_ip.."):name-"..json.decode(vehicle.vehicle).plate) or GetDisplayNameFromVehicleModel((json.decode(vehicle.vehicle)).model),
		favorite = toBoolean(GetResourceKvpString(script_name..":("..server_ip.."):favorite-"..json.decode(vehicle.vehicle).plate)) or false
	})
end)

newEvnet(script_name..":cl:RemoveVehicle", function(plate)
	local vehicle = getVehicle(plate)
	vehicle = nil
end)

newEvnet(script_name..":cl:UpdateProperties", function(plate, properties)
	local vehicle = getVehicle(plate)
	vehicle.vehicle = json.encode(properties)
	-- print(plate)
	-- print(vehicle)
	-- print(vehicle.vehicle)
	-- print(json.encode(properties))
end)

AddEventHandler("onResourceStop", function(resource)
	if resource == GetCurrentResourceName() then
		for k, v in pairs(ListObject["OBJECT"]) do
			ESX.Game.DeleteObject(v)
			DeleteEntity(v)
		end

		for k, v in pairs(ListObject["PED"]) do
			DeletePed(v)
		end
	end
end)
