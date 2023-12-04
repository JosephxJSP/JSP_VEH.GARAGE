ESX = nil
script_name = GetCurrentResourceName()
Call = {}
Call.EventBack = {}
local ownerPlate = {}

TriggerEvent(Config["EventRoute"]["getSharedObject"], function(obj) ESX = obj end)

debug = function(msg)
    -- print("^7[^3"..script_name.."^7] ^1Debug: ^4"..msg.."^7")
end

newEvnet = function(name, headler)
	return RegisterNetEvent(name), AddEventHandler(name, headler)
end

Call.Register = function(n,cb)
    Call.EventBack[n] = cb
end

Call.Return = function(_n,_id,src,cb,...)
    if not Call.EventBack[_n] then
        return
    end
    Call.EventBack[_n](src,cb,...)
end

newEvnet(script_name..":sv:Returndata",function(n, id, ...)
    local src = source
    Call.Return(n, id, src, function(...)
        TriggerClientEvent(script_name..":cl:Returndata", src, id, ...)
    end, ...)
end)

MySQL.ready(function ()
    local data = Config["DatabaseLoadAllVehicles"]()
    for _,v in ipairs(data) do
        ownerPlate[v.plate] = v.owner
    end
    debug(string.format("Load Owner data count: ^2%d", #data))
    if GetResourceState("JSP_VEH.INVENTORY") ~= "missing" then
        debug("Found ^7[^3JSP_VEH.INVENTORY^7] ^4!!")
    end
end)

local configData = { GARAGES = {}, POUNDS = {}, REMOVES = {} }
Citizen.CreateThread(function()
    local folderPath = GetResourcePath(script_name).."/config/position/"

    for _, v in pairs({ "GARAGES", "POUNDS", "REMOVES" }) do
        local command = string.format([[dir "%s%s" /b]], folderPath,v)
        for dir in io.popen(command):lines() do
            table.insert(configData[v], dir)
        end
    end
end)
newEvnet(script_name..":sv:getConfigData", function()
    local src = source
    TriggerClientEvent(script_name..":cl:getConfigData", src, configData)
end)

Call.Register(script_name..":sv:getAllVeh", function(source, cb)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local p = promise.new()
    
    p:resolve(Config["DatabaseGetOwnedVehicles"](xPlayer.identifier))
    cb(Citizen.Await(p))
end)

Call.Register(script_name..":sv:checkMoney", function(source, cb, data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if xPlayer.getAccount(data.type).money >= data.amount then
        xPlayer.removeAccountMoney(data.type, data.amount)
        cb(true)
    else
        cb(false)
    end
end)

newEvnet(script_name..":sv:updateVehicleTarget", function(plate, target)
    Config["DatabaseUpdateVehicleTarget"](plate, target)
end)

newEvnet(script_name..":sv:updateVehicleHealth", function(plate, properties)
    Config["DatabaseUpdateVehicleHealth"](plate, properties)
end)

getSourceFromIdentifier = function(identifier)
    local src = nil
    local xPlayers = ESX.GetPlayers()
    for k, user in pairs(xPlayers) do
        if GetPlayerIdentifiers(user)[1] == identifier then
            src = user
        end
    end
    return src
end

exports("AddVehicle", function(plate)
    --# Function นี้ใช้สำหรับเพิ่มยานพาหนะเข้าการาจ (ควรใช้หลังจากเพิ่มข้อมูลยานพาหนะเข้า Database แล้ว)
    --@ plate: string คือทะเบียนของยานพาหนะ
    local vehicle = Config["DatabaseGetOwnedVehicle"](plate)
    local owner = vehicle.owner
    local owner_src = getSourceFromIdentifier(owner)
    ownerPlate[plate] = owner
    TriggerClientEvent(script_name..":cl:AddVehicle", owner_src, vehicle)

    pcall(function()
        exports.nc_inventory:AddItem(owner_src, {
            name = plate,
            type = 'vehicle_key'
        })
    end)
    -- pcall(function()
    --     exports["JSP_VEH.INVENTORY"]:updateOwner(plate, owner)
    -- end)
end)

exports("RemoveVehicle", function(plate)
    --# Function นี้ใช้สำหรับลบยานพาหนะออกจากการาจ (ควรใช้หลังจากลบข้อมูลยานพาหนะออกจาก Database แล้ว)
    --@ plate: string คือทะเบียนของยานพาหนะ
    local owner = ownerPlate[plate]
    local owner_src = getSourceFromIdentifier(owner)
    ownerPlate[plate] = nil
    TriggerClientEvent(script_name..":cl:RemoveVehicle", owner_src, plate)
end)

exports("ReloadVehicleOwner", function(plate)
    --# Function นี้ใช้สำหรับโหลดเจ้าของยานะาหนะใหม่ (ควรใช้หลังจากอัพเดทข้อมูลยานพาหนะใน Database แล้ว)
    --@ plate: string คือทะเบียนของยานพาหนะ
    local vehicle = Config["DatabaseGetOwnedVehicle"](plate)
    local before_owner = ownerPlate[plate]
    local before_owner_src = getSourceFromIdentifier(before_owner)
    local after_owner = vehicle.owner
    local after_owner_src = getSourceFromIdentifier(after_owner)
    TriggerClientEvent(script_name..":cl:RemoveVehicle", before_owner_src, plate)
    Wait(100)
    TriggerClientEvent(script_name..":cl:AddVehicle", after_owner_src, vehicle)
    ownerPlate[plate] = after_owner
end)

exports("SpawnVehicle", function(playerId, plate, coords, heading, enterVehicle)
    --# Function นี้ใช้สำหรับสร้างยานพาหนะ
    --@ playerId: number คือเลข ID ของผู้เล่น (ผู้สร้าง)
    --@ plate: string คือทะเบียนของยานพาหนะ
    --@ coords: vector3 คือตำแหน่งของยานพาหนะ
    --@ heading: number คือ Heading ของยานพาหนะ
    --@ enterVehicle: boolean คือ ให้ผู้เล่นเข้าไปอยู่ในยานพาหนะอัตโนมัติ
end)

exports("StoreVehicle", function(plate, target)
    --# Function นี้ใช้สำหรับเก็บยานพาหนะ (ยานพาหนะที่อยู้ในเมืองจะถูกลบ)
    --@ plate: string คือทะเบียนของยานพาหนะ
    --@ target: string คือชื่อชนิดของการาจ
    Config["DatabaseUpdateVehicleTarget"](plate, target)
end)

exports("SetVehicleStored", function(plate, target)
    --# Function นี้ใช้สำหรับตั้งค่าการเก็บยานพาหนะ (เป็นการเปลี่ยนแปลงตั้งค่าเท่านั้น)
    --@ plate: string คือทะเบียนของยานพาหนะ
    --@ target: string คือชื่อชนิดของการาจ (หากไม่ใส่จะถือว่าเป็นการนำออกจากการาจ)
    --DeleEntity()
    Config["DatabaseUpdateVehicleTarget"](plate, target)
end)

exports("UpdateProperties", function(plate, properties, updateToDatabase)
    --# Function นี้ใช้สำหรับเปลี่ยนแปลงคุณสมบัติของยานพาหนะ
    --@ plate: string คือทะเบียนของยานพาหนะ
    --@ properties: table|string คือข้อมูลคุณสมบัติของยานพาหนะ
    --@ updateToDatabase: boolean คือให้เปลี่ยนแปลงข้อมูลใน Database ด้วยไหม
    if not ownerPlate[plate] then
        return
    end

    local owner = ownerPlate[plate]
    local owner_src = getSourceFromIdentifier(owner)
    TriggerClientEvent(script_name..":cl:UpdateProperties", owner_src, plate, properties)
    if updateToDatabase then
        Config["DatabaseUpdateVehicleProperties"](plate, properties)
    end
end)

exports("SyncVehicle", function(vehicle)
    --# Function นี้ใช้สำหรับ Sync ค่ายานพาหนะเข้าระบบ (เพื่อให้ไม่เกิดการมียานพาหนะซ้ำกันเมือง)
    --@ vehicle: number คือเลข Entity ของยานพาหนะ
end)
