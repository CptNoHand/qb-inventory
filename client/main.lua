-- Variables

local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local inInventory = false
local currentWeapon = nil
local CurrentWeaponData = {}
local currentOtherInventory = nil
local Drops = {}
local CurrentDrop = nil
local DropsNear = {}
local CurrentVehicle = nil
local CurrentGlovebox = nil
local CurrentStash = nil
local isCrafting = false
local isHotbar = false
local itemInfos = {}
local showBlur = true
local WeaponAttachments = {}

RegisterNUICallback('showBlur', function()
    Wait(50)
    TriggerEvent("qb-inventory:client:showBlur")
end) 

RegisterNetEvent("qb-inventory:client:showBlur", function()
    Wait(50)
    showBlur = not showBlur
end)

-- Functions

local function GetClosestVending()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local object = nil
    for _, machine in pairs(Config.VendingObjects) do
        local ClosestObject = GetClosestObjectOfType(pos.x, pos.y, pos.z, 0.75, GetHashKey(machine), 0, 0, 0)
        if ClosestObject ~= 0 then
            if object == nil then
                object = ClosestObject
            end
        end
    end
    return object
end

local function OpenVending()
    local ShopItems = {}
    ShopItems.label = "Vending Machine"
    ShopItems.items = Config.VendingItem
    ShopItems.slots = #Config.VendingItem
    TriggerServerEvent("inventory:server:OpenInventory", "shop", "Vendingshop_"..math.random(1, 99), ShopItems)
end

local function DrawText3Ds(x, y, z, text)
	SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x,y,z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

local function FormatWeaponAttachments(itemdata)
    local attachments = {}
    itemdata.name = itemdata.name:upper()
    if itemdata.info.attachments ~= nil and next(itemdata.info.attachments) ~= nil then
        for _, v in pairs(itemdata.info.attachments) do
            if WeaponAttachments[itemdata.name] ~= nil then
                for key, value in pairs(WeaponAttachments[itemdata.name]) do
                    if value.component == v.component then
                        local item = value.item
                        attachments[#attachments+1] = {
                            attachment = key,
                            label = QBCore.Shared.Items[item].label
                            --label = value.label
                        }
                    end
                end
            end
        end
    end
    return attachments
end

local function IsBackEngine(vehModel)
    if BackEngineVehicles[vehModel] then return true end
    return false
end

local function OpenTrunk()
    local vehicle = QBCore.Functions.GetClosestVehicle()
    while (not HasAnimDictLoaded("amb@prop_human_bum_bin@idle_b")) do
        RequestAnimDict("amb@prop_human_bum_bin@idle_b")
        Wait(100)
    end
    TaskPlayAnim(PlayerPedId(), "amb@prop_human_bum_bin@idle_b", "idle_d", 4.0, 4.0, -1, 50, 0, false, false, false)
    if (IsBackEngine(GetEntityModel(vehicle))) then
        SetVehicleDoorOpen(vehicle, 4, false, false)
    else
        SetVehicleDoorOpen(vehicle, 5, false, false)
    end
end

local function CloseTrunk()
    local vehicle = QBCore.Functions.GetClosestVehicle()
    while (not HasAnimDictLoaded("amb@prop_human_bum_bin@idle_b")) do
        RequestAnimDict("amb@prop_human_bum_bin@idle_b")
        Wait(100)
    end
    TaskPlayAnim(PlayerPedId(), "amb@prop_human_bum_bin@idle_b", "exit", 4.0, 4.0, -1, 50, 0, false, false, false)
    if (IsBackEngine(GetEntityModel(vehicle))) then
        SetVehicleDoorShut(vehicle, 4, false)
    else
        SetVehicleDoorShut(vehicle, 5, false)
    end
end

local function closeInventory()
    SendNUIMessage({
        action = "close",
    })
end

local function ToggleHotbar(toggle)
    local HotbarItems = {
        [1] = PlayerData.items[1],
        [2] = PlayerData.items[2],
        [3] = PlayerData.items[3],
        [4] = PlayerData.items[4],
        [5] = PlayerData.items[5],
        [41] = PlayerData.items[41],
    }

    if toggle then
        SendNUIMessage({
            action = "toggleHotbar",
            open = true,
            items = HotbarItems
        })
    else
        SendNUIMessage({
            action = "toggleHotbar",
            open = false,
        })
    end
end

local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(0)
    end
end

local function openAnim()
    LoadAnimDict('pickup_object')
    TaskPlayAnim(PlayerPedId(),'pickup_object', 'putdown_low', 5.0, 1.5, 1.0, 48, 0.0, 0, 0, 0)
    Wait(500)
    ClearPedTasks(PlayerPedId())
end

local function ItemsToItemInfo()
	itemInfos = {
		[1] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 3x, " ..QBCore.Shared.Items["plastic"]["label"] .. ": 4x."},
		[2] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 8x, " ..QBCore.Shared.Items["plastic"]["label"] .. ": 6x."},
		[3] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 5x, " ..QBCore.Shared.Items["plastic"]["label"] .. ": 4x, "..QBCore.Shared.Items["aluminum"]["label"] .. ": 6x."},
		[4] = {costs = QBCore.Shared.Items["electronickit"]["label"] .. ": 2x, " ..QBCore.Shared.Items["plastic"]["label"] .. ": 4x, "..QBCore.Shared.Items["steel"]["label"] .. ": 5x."},
		[5] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 4x, " ..QBCore.Shared.Items["plastic"]["label"] .. ": 3x, "..QBCore.Shared.Items["aluminum"]["label"] .. ": 4x, "..QBCore.Shared.Items["iron"]["label"] .. ": 5x, "..QBCore.Shared.Items["electronickit"]["label"] .. ": 1x."},
		[6] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 4x, " ..QBCore.Shared.Items["steel"]["label"] .. ": 4x, "..QBCore.Shared.Items["aluminum"]["label"] .. ": 4x."},
		[7] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 4x, " ..QBCore.Shared.Items["steel"]["label"] .. ": 5x, "..QBCore.Shared.Items["plastic"]["label"] .. ": 7x."},
		[8] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 5x, " ..QBCore.Shared.Items["steel"]["label"] .. ": 5x, "..QBCore.Shared.Items["copper"]["label"] .. ": 5x."},
		[9] = {costs = QBCore.Shared.Items["iron"]["label"] .. ": 6x, " ..QBCore.Shared.Items["glass"]["label"] .. ": 6x."},
		[10] = {costs = QBCore.Shared.Items["aluminum"]["label"] .. ": 6x, " ..QBCore.Shared.Items["glass"]["label"] .. ": 6x."},
		[11] = {costs = QBCore.Shared.Items["iron"]["label"] .. ": 5x, " ..QBCore.Shared.Items["steel"]["label"] .. ": 5x, "..QBCore.Shared.Items["plastic"]["label"] .. ": 6x, "..QBCore.Shared.Items["aluminum"]["label"] .. ": 5x."},
		[12] = {costs = QBCore.Shared.Items["iron"]["label"] .. ": 5x, " ..QBCore.Shared.Items["steel"]["label"] .. ": 6x, "..QBCore.Shared.Items["screwdriverset"]["label"] .. ": 3x, "..QBCore.Shared.Items["advancedlockpick"]["label"] .. ": 5x."},
        [13] = {costs = QBCore.Shared.Items["iron"]["label"] .. ": 1x, " ..QBCore.Shared.Items["steel"]["label"] .. ": 1x, "..QBCore.Shared.Items["screwdriverset"]["label"] .. ": 1x, "..QBCore.Shared.Items["thermite"]["label"] .. ": 1x."},
	}

	local items = {}
	for _, item in pairs(Config.CraftingItems) do
		local itemInfo = QBCore.Shared.Items[item.name:lower()]
		items[item.slot] = {
			name = itemInfo["name"],
			amount = tonumber(item.amount),
			info = itemInfos[item.slot],
			label = itemInfo["label"],
			description = itemInfo["description"] or "",
			weight = itemInfo["weight"],
			type = itemInfo["type"],
			unique = itemInfo["unique"],
			useable = itemInfo["useable"],
			image = itemInfo["image"],
			slot = item.slot,
			costs = item.costs,
			threshold = item.threshold,
			points = item.points,
		}
	end
	Config.CraftingItems = items
end

local function SetupAttachmentItemsInfo()
	itemInfos = {
		[1] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 2x, " .. QBCore.Shared.Items["steel"]["label"] .. ": 5x, " .. QBCore.Shared.Items["rubber"]["label"] .. ": 2x"},
		[2] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 1x, " .. QBCore.Shared.Items["steel"]["label"] .. ": 2x, " .. QBCore.Shared.Items["rubber"]["label"] .. ": 8x"},
		[3] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 3x, " .. QBCore.Shared.Items["steel"]["label"] .. ": 7x, " .. QBCore.Shared.Items["rubber"]["label"] .. ": 2x"},
		[4] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 3x, " .. QBCore.Shared.Items["steel"]["label"] .. ": 6x, " .. QBCore.Shared.Items["rubber"]["label"] .. ": 2x"},
		[5] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 5x, " .. QBCore.Shared.Items["steel"]["label"] .. ": 8x, " .. QBCore.Shared.Items["rubber"]["label"] .. ": 6x"},
		[6] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 4x, " .. QBCore.Shared.Items["steel"]["label"] .. ": 5x, " .. QBCore.Shared.Items["rubber"]["label"] .. ": 2x"},
		[7] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 6x, " .. QBCore.Shared.Items["steel"]["label"] .. ": 8x, " .. QBCore.Shared.Items["rubber"]["label"] .. ": 2x, " .. QBCore.Shared.Items["smg_extendedclip"]["label"] .. ": 1x"},
		[8] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 5x, " .. QBCore.Shared.Items["steel"]["label"] .. ": 9x, " .. QBCore.Shared.Items["rubber"]["label"] .. ": 4x, " .. QBCore.Shared.Items["smg_extendedclip"]["label"] .. ": 2x"},
	}

	local items = {}
	for _, item in pairs(Config.AttachmentCrafting["items"]) do
		local itemInfo = QBCore.Shared.Items[item.name:lower()]
		items[item.slot] = {
			name = itemInfo["name"],
			amount = tonumber(item.amount),
			info = itemInfos[item.slot],
			label = itemInfo["label"],
			description = itemInfo["description"] or "",
			weight = itemInfo["weight"],
			unique = itemInfo["unique"],
			useable = itemInfo["useable"],
			image = itemInfo["image"],
			slot = item.slot,
			costs = item.costs,
			threshold = item.threshold,
			points = item.points,
		}
	end
	Config.AttachmentCrafting["items"] = items
end

local function GetThresholdItems()
	ItemsToItemInfo()
	local items = {}
	for k, _ in pairs(Config.CraftingItems) do
		if PlayerData.metadata["craftingrep"] >= Config.CraftingItems[k].threshold then
			items[k] = Config.CraftingItems[k]
		end
	end
	return items
end

local function GetAttachmentThresholdItems()
	SetupAttachmentItemsInfo()
	local items = {}
	for k, _ in pairs(Config.AttachmentCrafting["items"]) do
		if PlayerData.metadata["attachmentcraftingrep"] >= Config.AttachmentCrafting["items"][k].threshold then
			items[k] = Config.AttachmentCrafting["items"][k]
		end
	end
	return items
end

-- Events

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    LocalPlayer.state:set("inv_busy", false, true)
    PlayerData = QBCore.Functions.GetPlayerData()
    QBCore.Functions.TriggerCallback("inventory:server:GetCurrentDrops", function(theDrops)
		Drops = theDrops
	end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    LocalPlayer.state:set("inv_busy", true, true)
    PlayerData = {}
    RemoveAllNearbyDrops()
end)

RegisterNetEvent('QBCore:Client:UpdateObject', function()
	QBCore = exports['qb-core']:GetCoreObject()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

RegisterNetEvent('inventory:client:CheckOpenState', function(type, id, label)
    local name = QBCore.Shared.SplitStr(label, "-")[2]
    if type == "stash" then
        if name ~= CurrentStash or CurrentStash == nil then
            TriggerServerEvent('inventory:server:SetIsOpenState', false, type, id)
        end
    elseif type == "trunk" then
        if name ~= CurrentVehicle or CurrentVehicle == nil then
            TriggerServerEvent('inventory:server:SetIsOpenState', false, type, id)
        end
    elseif type == "glovebox" then
        if name ~= CurrentGlovebox or CurrentGlovebox == nil then
            TriggerServerEvent('inventory:server:SetIsOpenState', false, type, id)
        end
    elseif type == "drop" then
        if name ~= CurrentDrop or CurrentDrop == nil then
            TriggerServerEvent('inventory:server:SetIsOpenState', false, type, id)
        end
    end
end)

RegisterNetEvent('weapons:client:SetCurrentWeapon', function(data, _)
    CurrentWeaponData = data or {}
end)

RegisterNetEvent('inventory:client:ItemBox', function(itemData, type)
    SendNUIMessage({
        action = "itemBox",
        item = itemData,
        type = type
    })
end)

RegisterNetEvent('inventory:client:requiredItems', function(items, bool)
    local itemTable = {}
    if bool then
        for k, _ in pairs(items) do
            itemTable[#itemTable+1] = {
                item = items[k].name,
                label = QBCore.Shared.Items[items[k].name]["label"],
                image = items[k].image,
            }
        end
    end

    SendNUIMessage({
        action = "requiredItem",
        items = itemTable,
        toggle = bool
    })
end)

RegisterNetEvent('inventory:server:RobPlayer', function(TargetId)
    SendNUIMessage({
        action = "RobMoney",
        TargetId = TargetId,
    })
end)

RegisterNetEvent('inventory:client:OpenInventory', function(PlayerAmmo, inventory, other)
    if not IsEntityDead(PlayerPedId()) then
        Wait(500)
        ToggleHotbar(false)
        if showBlur == true then
            TriggerScreenblurFadeIn(1000)
        end
        SetNuiFocus(true, true)
        if other then
            currentOtherInventory = other.name
        end
        SendNUIMessage({
            action = "open",
            inventory = inventory,
            slots = MaxInventorySlots,
            other = other,
            maxweight = QBCore.Config.Player.MaxWeight,
            Ammo = PlayerAmmo,
            maxammo = Config.MaximumAmmoValues,
        })
        inInventory = true
    end
end)

RegisterNetEvent('inventory:client:UpdatePlayerInventory', function(isError)
    SendNUIMessage({
        action = "update",
        inventory = PlayerData.items,
        maxweight = QBCore.Config.Player.MaxWeight,
        slots = MaxInventorySlots,
        error = isError,
    })
end)

RegisterNetEvent('inventory:client:CraftItems', function(itemName, itemCosts, amount, toSlot, points)
    local ped = PlayerPedId()
    SendNUIMessage({
        action = "close",
    })
    isCrafting = true
    QBCore.Functions.Progressbar("repair_vehicle", "Crafting..", (math.random(2000, 5000) * amount), false, true, {
		disableMovement = true,
		disableCarMovement = true,
		disableMouse = false,
		disableCombat = true,
	}, {
		animDict = "mini@repair",
		anim = "fixing_a_player",
		flags = 16,
	}, {}, {}, function() -- Done
		StopAnimTask(ped, "mini@repair", "fixing_a_player", 1.0)
        TriggerServerEvent("inventory:server:CraftItems", itemName, itemCosts, amount, toSlot, points)
        TriggerEvent('inventory:client:ItemBox', QBCore.Shared.Items[itemName], 'add')
        isCrafting = false
	end, function() -- Cancel
		StopAnimTask(ped, "mini@repair", "fixing_a_player", 1.0)
        QBCore.Functions.Notify("Failed", "error")
        isCrafting = false
	end)
end)

RegisterNetEvent('inventory:client:CraftAttachment', function(itemName, itemCosts, amount, toSlot, points)
    local ped = PlayerPedId()
    SendNUIMessage({
        action = "close",
    })
    isCrafting = true
    QBCore.Functions.Progressbar("repair_vehicle", "Crafting..", (math.random(2000, 5000) * amount), false, true, {
		disableMovement = true,
		disableCarMovement = true,
		disableMouse = false,
		disableCombat = true,
	}, {
		animDict = "mini@repair",
		anim = "fixing_a_player",
		flags = 16,
	}, {}, {}, function() -- Done
		StopAnimTask(ped, "mini@repair", "fixing_a_player", 1.0)
        TriggerServerEvent("inventory:server:CraftAttachment", itemName, itemCosts, amount, toSlot, points)
        TriggerEvent('inventory:client:ItemBox', QBCore.Shared.Items[itemName], 'add')
        isCrafting = false
	end, function() -- Cancel
		StopAnimTask(ped, "mini@repair", "fixing_a_player", 1.0)
        QBCore.Functions.Notify("Failed", "error")
        isCrafting = false
	end)
end)

RegisterNetEvent('inventory:client:PickupSnowballs', function()
    local ped = PlayerPedId()
    LoadAnimDict('anim@mp_snowball')
    TaskPlayAnim(ped, 'anim@mp_snowball', 'pickup_snowball', 3.0, 3.0, -1, 0, 1, 0, 0, 0)
    QBCore.Functions.Progressbar("pickupsnowball", "Collecting snowballs..", 1500, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        ClearPedTasks(ped)
        TriggerServerEvent('QBCore:Server:AddItem', "snowball", 1)
        TriggerEvent('inventory:client:ItemBox', QBCore.Shared.Items["snowball"], "add")
    end, function() -- Cancel
        ClearPedTasks(ped)
        QBCore.Functions.Notify("Canceled", "error")
    end)
end)

RegisterNetEvent('inventory:client:UseSnowball', function(amount)
    local ped = PlayerPedId()
    GiveWeaponToPed(ped, `weapon_snowball`, amount, false, false)
    SetPedAmmo(ped, `weapon_snowball`, amount)
    SetCurrentPedWeapon(ped, `weapon_snowball`, true)
end)

RegisterNetEvent('inventory:client:UseWeapon', function(weaponData, shootbool)
    local ped = PlayerPedId()
    local weaponName = tostring(weaponData.name)
    if currentWeapon == weaponName then
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        Wait(1500)
        RemoveAllPedWeapons(ped, true)
        TriggerEvent('weapons:client:SetCurrentWeapon', nil, shootbool)
        currentWeapon = nil
    elseif weaponName == "weapon_stickybomb" or weaponName == "weapon_pipebomb" or weaponName == "weapon_smokegrenade" or weaponName == "weapon_flare" or weaponName == "weapon_proxmine" or weaponName == "weapon_ball"  or weaponName == "weapon_molotov" or weaponName == "weapon_grenade" or weaponName == "weapon_bzgas" then
        GiveWeaponToPed(ped, GetHashKey(weaponName), 1, false, false)
        SetPedAmmo(ped, GetHashKey(weaponName), 1)
        SetCurrentPedWeapon(ped, GetHashKey(weaponName), true)
        TriggerEvent('weapons:client:SetCurrentWeapon', weaponData, shootbool)
        currentWeapon = weaponName
    elseif weaponName == "weapon_snowball" then
        GiveWeaponToPed(ped, GetHashKey(weaponName), 10, false, false)
        SetPedAmmo(ped, GetHashKey(weaponName), 10)
        SetCurrentPedWeapon(ped, GetHashKey(weaponName), true)
        TriggerServerEvent('QBCore:Server:RemoveItem', weaponName, 1)
        TriggerEvent('weapons:client:SetCurrentWeapon', weaponData, shootbool)
        currentWeapon = weaponName
    else
        TriggerEvent('weapons:client:SetCurrentWeapon', weaponData, shootbool)
        QBCore.Functions.TriggerCallback("weapon:server:GetWeaponAmmo", function(result, name)
            local ammo = tonumber(result)
            if weaponName == "weapon_petrolcan" or weaponName == "weapon_fireextinguisher" then
                ammo = 4000
            end
	    if name ~= weaponName then
                ammo = 0
            end
            GiveWeaponToPed(ped, GetHashKey(weaponName), 0, false, false)
            SetPedAmmo(ped, GetHashKey(weaponName), ammo)
            SetCurrentPedWeapon(ped, GetHashKey(weaponName), true)
            if weaponData.info.attachments ~= nil then
                for _, attachment in pairs(weaponData.info.attachments) do
                    GiveWeaponComponentToPed(ped, GetHashKey(weaponName), GetHashKey(attachment.component))
                end
            end
            currentWeapon = weaponName
        end, CurrentWeaponData)
    end
end)

RegisterNetEvent('inventory:client:CheckWeapon', function(weaponName)
    local ped = PlayerPedId()
    if currentWeapon == weaponName then
        TriggerEvent('weapons:ResetHolster')
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        RemoveAllPedWeapons(ped, true)
        currentWeapon = nil
    end
end)

-- This needs to be changed to do a raycast so items arent placed in walls
RegisterNetEvent('inventory:client:AddDropItem', function(dropId, player, coords)
    local forward = GetEntityForwardVector(GetPlayerPed(GetPlayerFromServerId(player)))
	local x, y, z = table.unpack(coords + forward * 0.5)
    Drops[dropId] = {
        id = dropId,
        coords = {
            x = x,
            y = y,
            z = z - 0.3,
        },
    }
end)

function RemoveAllNearbyDrops()
    for k in pairs(DropsNear) do
        RemoveNearbyDrop(k)
    end
end

function RemoveNearbyDrop(index)
    if DropsNear[index] then
        local dropItem = DropsNear[index].object
        if DoesEntityExist(dropItem) then
            DeleteEntity(dropItem)
        end

        DropsNear[index] = nil
        if Drops[index] then
            Drops[index].object = nil
            Drops[index].isDropShowing = nil
        end
    end
end

RegisterNetEvent('inventory:client:RemoveDropItem', function(dropId)
    Drops[dropId] = nil
    if Config.UseItemDrop then
        RemoveNearbyDrop(dropId)
    else
        DropsNear[dropId] = nil
    end
end)

RegisterNetEvent('inventory:client:DropItemAnim', function()
    local ped = PlayerPedId()
    SendNUIMessage({
        action = "close",
    })
    RequestAnimDict("pickup_object")
    while not HasAnimDictLoaded("pickup_object") do
        Wait(7)
    end
    TaskPlayAnim(ped, "pickup_object" ,"pickup_low" ,8.0, -8.0, -1, 1, 0, false, false, false )
    Wait(2000)
    ClearPedTasks(ped)
end)

RegisterNetEvent('inventory:client:SetCurrentStash', function(stash)
    CurrentStash = stash
end)

-- Commands

RegisterCommand('closeinv', function()
    closeInventory()
end, false)

RegisterCommand('inventory', function()
    if not isCrafting and not inInventory then
        if not PlayerData.metadata["isdead"] and not PlayerData.metadata["inlaststand"] and not PlayerData.metadata["ishandcuffed"] and not IsPauseMenuActive() then
            local ped = PlayerPedId()
            local curVeh = nil
            local VendingMachine = nil
            if not Config.UseTarget then VendingMachine = GetClosestVending() end

            if IsPedInAnyVehicle(ped) then -- Is Player In Vehicle
                local vehicle = GetVehiclePedIsIn(ped, false)
                CurrentGlovebox = QBCore.Functions.GetPlate(vehicle)
                curVeh = vehicle
                CurrentVehicle = nil
            else
                local vehicle = QBCore.Functions.GetClosestVehicle()
                if vehicle ~= 0 and vehicle ~= nil then
                    local pos = GetEntityCoords(ped)
                    local dimensionMin, dimensionMax = GetModelDimensions(GetEntityModel(vehicle))
		    local trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, (dimensionMin.y), 0.0)
                    if (IsBackEngine(GetEntityModel(vehicle))) then
                        trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, (dimensionMax.y), 0.0)
                    end
                    if #(pos - trunkpos) < 1.5 and not IsPedInAnyVehicle(ped) then
                        if GetVehicleDoorLockStatus(vehicle) < 2 then
                            CurrentVehicle = QBCore.Functions.GetPlate(vehicle)
                            curVeh = vehicle
                            CurrentGlovebox = nil
                        else
                            QBCore.Functions.Notify("Vehicle Locked", "error")
                            return
                        end
                    else
                        CurrentVehicle = nil
                    end
                else
                    CurrentVehicle = nil
                end
            end

            -- Trunk
            if CurrentVehicle ~= nil then
                local maxweight = 0
                local slots = 0
                -- GRAB WEIGHT AND SLOTS FROM SHARED LUA
                local modelName = GetDisplayNameFromVehicleModel(GetEntityModel(curVeh)):lower()

                if maxweight == 0 and QBCore.Shared.Vehicles[modelName] ~= nil then
                    maxweight = QBCore.Shared.Vehicles[modelName]['trunkspace']
                    slots = QBCore.Shared.Vehicles[modelName]['trunkslots']
                end
                
                if maxweight == 0 then
                    maxweight = 30000
                end
                if slots == 0 then
                    slots = 15
                end
                local other = {
                    maxweight = maxweight,
                    slots = slots,
                }
                TriggerServerEvent("inventory:server:OpenInventory", "trunk", CurrentVehicle, other)
                OpenTrunk()
            elseif CurrentGlovebox then
                TriggerServerEvent("inventory:server:OpenInventory", "glovebox", CurrentGlovebox)
            elseif CurrentDrop ~= 0 then
                TriggerServerEvent("inventory:server:OpenInventory", "drop", CurrentDrop)
            elseif VendingMachine then
                local ShopItems = {}
                ShopItems.label = "Vending Machine"
                ShopItems.items = Config.VendingItem
                ShopItems.slots = #Config.VendingItem
                TriggerServerEvent("inventory:server:OpenInventory", "shop", "Vendingshop_"..math.random(1, 99), ShopItems)
            else
                openAnim()
                TriggerServerEvent("inventory:server:OpenInventory")
            end
        end
    end
end)

RegisterKeyMapping('inventory', 'Open Inventory', 'keyboard', 'TAB')

RegisterCommand('hotbar', function()
    isHotbar = not isHotbar
    if not PlayerData.metadata["isdead"] and not PlayerData.metadata["inlaststand"] and not PlayerData.metadata["ishandcuffed"] and not IsPauseMenuActive() then
        ToggleHotbar(isHotbar)
    end
end)

RegisterKeyMapping('hotbar', 'Toggles keybind slots', 'keyboard', 'z')

for i = 1, 6 do
    RegisterCommand('slot' .. i,function()
        if not PlayerData.metadata["isdead"] and not PlayerData.metadata["inlaststand"] and not PlayerData.metadata["ishandcuffed"] and not IsPauseMenuActive() then
            if i == 6 then
                i = MaxInventorySlots
            end
            TriggerServerEvent("inventory:server:UseItemSlot", i)
        end
    end)
    RegisterKeyMapping('slot' .. i, 'Uses the item in slot ' .. i, 'keyboard', i)
end

RegisterNetEvent('qb-inventory:client:giveAnim', function()
    LoadAnimDict('mp_common')
	TaskPlayAnim(PlayerPedId(), 'mp_common', 'givetake1_b', 8.0, 1.0, -1, 16, 0, 0, 0, 0)
end)

RegisterNetEvent('inventory:client:craftTarget',function()
    local crafting = {}
    crafting.label = "Crafting"
    crafting.items = GetThresholdItems()
    TriggerServerEvent("inventory:server:OpenInventory", "crafting", math.random(1, 99), crafting)
end)

-- NUI

RegisterNUICallback('RobMoney', function(data, cb)
    TriggerServerEvent("police:server:RobPlayer", data.TargetId)
    cb('ok')
end)

RegisterNUICallback('Notify', function(data, cb)
    QBCore.Functions.Notify(data.message, data.type)
    cb('ok')
end)

RegisterNUICallback('GetWeaponData', function(cData, cb)
    local data = {
        WeaponData = QBCore.Shared.Items[cData.weapon],
        AttachmentData = FormatWeaponAttachments(cData.ItemData)
    }
    cb(data)
end)

RegisterNUICallback('RemoveAttachment', function(data, cb)
    local ped = PlayerPedId()
    local WeaponData = QBCore.Shared.Items[data.WeaponData.name]
    local Attachment = WeaponAttachments[WeaponData.name:upper()][data.AttachmentData.attachment]
    QBCore.Functions.TriggerCallback('weapons:server:RemoveAttachment', function(NewAttachments)
        if NewAttachments ~= false then
            local Attachies = {}
            RemoveWeaponComponentFromPed(ped, GetHashKey(data.WeaponData.name), GetHashKey(Attachment.component))
            for _, v in pairs(NewAttachments) do
                for _, pew in pairs(WeaponAttachments[WeaponData.name:upper()]) do
                    if v.component == pew.component then
                        local item = pew.item
                        Attachies[#Attachies+1] = {
                            attachment = pew.item,
                            label = QBCore.Shared.Items[item].label,
                        }
                    end
                end
            end
            local DJATA = {
                Attachments = Attachies,
                WeaponData = WeaponData,
            }
            cb(DJATA)
        else
            RemoveWeaponComponentFromPed(ped, GetHashKey(data.WeaponData.name), GetHashKey(Attachment.component))
            cb({})
        end
    end, data.AttachmentData, data.WeaponData)
end)

RegisterNUICallback('getCombineItem', function(data, cb)
    cb(QBCore.Shared.Items[data.item])
end)

RegisterNUICallback("CloseInventory", function(_, cb)
    if currentOtherInventory == "none-inv" then
        CurrentDrop = nil
        CurrentVehicle = nil
        CurrentGlovebox = nil
        CurrentStash = nil
        SetNuiFocus(false, false)
        inInventory = false
        TriggerScreenblurFadeOut(1000)
        ClearPedTasks(PlayerPedId())
        return
    end
    if CurrentVehicle ~= nil then
        CloseTrunk()
        TriggerServerEvent("inventory:server:SaveInventory", "trunk", CurrentVehicle)
        CurrentVehicle = nil
    elseif CurrentGlovebox ~= nil then
        TriggerServerEvent("inventory:server:SaveInventory", "glovebox", CurrentGlovebox)
        CurrentGlovebox = nil
    elseif CurrentStash ~= nil then
        TriggerServerEvent("inventory:server:SaveInventory", "stash", CurrentStash)
        CurrentStash = nil
    else
        TriggerServerEvent("inventory:server:SaveInventory", "drop", CurrentDrop)
        CurrentDrop = nil
    end
    Wait(50)
    TriggerScreenblurFadeOut(1000)
    SetNuiFocus(false, false)
    inInventory = false
    cb('ok')
end)

RegisterNUICallback("UseItem", function(data, cb)
    TriggerServerEvent("inventory:server:UseItem", data.inventory, data.item)
    cb('ok')
end)

RegisterNUICallback("combineItem", function(data, cb)
    Wait(150)
    TriggerServerEvent('inventory:server:combineItem', data.reward, data.fromItem, data.toItem)
    cb('ok')
end)

RegisterNUICallback('combineWithAnim', function(data, cb)
    local ped = PlayerPedId()
    local combineData = data.combineData
    local aDict = combineData.anim.dict
    local aLib = combineData.anim.lib
    local animText = combineData.anim.text
    local animTimeout = combineData.anim.timeOut
    QBCore.Functions.Progressbar("combine_anim", animText, animTimeout, false, true, {
        disableMovement = false,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = aDict,
        anim = aLib,
        flags = 16,
    }, {}, {}, function() -- Done
        StopAnimTask(ped, aDict, aLib, 1.0)
        TriggerServerEvent('inventory:server:combineItem', combineData.reward, data.requiredItem, data.usedItem)
    end, function() -- Cancel
        StopAnimTask(ped, aDict, aLib, 1.0)
        QBCore.Functions.Notify("Failed!", "error")
    end)
    cb('ok')
end)

RegisterNUICallback("SetInventoryData", function(data, cb)
    TriggerServerEvent("inventory:server:SetInventoryData", data.fromInventory, data.toInventory, data.fromSlot, data.toSlot, data.fromAmount, data.toAmount)
    cb('ok')
end)

RegisterNUICallback("PlayDropSound", function(_, cb)
    PlaySound(-1, "CLICK_BACK", "WEB_NAVIGATION_SOUNDS_PHONE", 0, 0, 1)
    cb('ok')
end)

RegisterNUICallback("PlayDropFail", function(_, cb)
    PlaySound(-1, "Place_Prop_Fail", "DLC_Dmod_Prop_Editor_Sounds", 0, 0, 1)
    cb('ok')
end)

RegisterNUICallback("GiveItem", function(data, cb)
    local player, distance = QBCore.Functions.GetClosestPlayer(GetEntityCoords(PlayerPedId()))
    if player ~= -1 and distance < 3 then
        if (data.inventory == 'player') then
            local playerId = GetPlayerServerId(player)
            SetCurrentPedWeapon(PlayerPedId(),'WEAPON_UNARMED',true)
            TriggerServerEvent("inventory:server:GiveItem", playerId, data.item.name, data.amount, data.item.slot)
        else
            QBCore.Functions.Notify("You do not own this item!", "error")
        end
    else
        QBCore.Functions.Notify("No one nearby!", "error")
    end
    cb('ok')
end)

-- Threads

CreateThread(function()
    while true do
        local sleep = 100
        if DropsNear ~= nil then
			local ped = PlayerPedId()
			local closestDrop = nil
			local closestDistance = nil
            for k, v in pairs(DropsNear) do

                if DropsNear[k] ~= nil then
                    if Config.UseItemDrop then
                        if not v.isDropShowing then
                            CreateItemDrop(k)
                        end
                    else
                        sleep = 0
                        DrawMarker(20, v.coords.x, v.coords.y, v.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.15, 120, 10, 20, 155, false, false, false, 1, false, false, false)
                    end

					local coords = (v.object ~= nil and GetEntityCoords(v.object)) or vector3(v.coords.x, v.coords.y, v.coords.z)
					local distance = #(GetEntityCoords(ped) - coords)
					if distance < 2 and (not closestDistance or distance < closestDistance) then
						closestDrop = k
						closestDistance = distance
					end
                end
            end


			if not closestDrop then
				CurrentDrop = 0
			else
				CurrentDrop = closestDrop
			end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        if Drops ~= nil and next(Drops) ~= nil then
            local pos = GetEntityCoords(PlayerPedId(), true)
            for k, v in pairs(Drops) do
                if Drops[k] ~= nil then
                    local dist = #(pos - vector3(v.coords.x, v.coords.y, v.coords.z))
                    if dist < Config.MaxDropViewDistance then
                        DropsNear[k] = v
                    else
                        if Config.UseItemDrop and DropsNear[k] then
                            RemoveNearbyDrop(k)
                        else
                            DropsNear[k] = nil
                        end
                    end
                end
            end
        else
            DropsNear = {}
        end
        Wait(500)
    end
end)

CreateThread(function()
    if Config.UseTarget then
        exports['qb-target']:AddTargetModel(Config.VendingObjects, {
            options = {
                {
                    icon = "fa-solid fa-cash-register",
                    label = "Vending Machine",
                    action = function()
                        OpenVending()
                    end
                },
            },
            distance = 2.5
        })
    end
end)

CreateThread(function()
    if Config.UseTarget then
        exports['qb-target']:AddTargetModel(Config.CraftingObject, {
            options = {
                {
                    event = "inventory:client:craftTarget",
                    icon = "fas fa-tools",
                    label = "Craft",
                },
            },
            distance = 2.5,
        })
    else
        while true do
            local sleep = 1000
            if LocalPlayer.state['isLoggedIn'] then
                local pos = GetEntityCoords(PlayerPedId())
                local craftObject = GetClosestObjectOfType(pos, 2.0, Config.CraftingObject, false, false, false)
                if craftObject ~= 0 then
                    local objectPos = GetEntityCoords(craftObject)
                    if #(pos - objectPos) < 1.5 then
                        sleep = 0
                        DrawText3Ds(objectPos.x, objectPos.y, objectPos.z + 1.0, "~g~E~w~ - Craft")
                        if IsControlJustReleased(0, 38) then
                            local crafting = {}
                            crafting.label = "Crafting"
                            crafting.items = GetThresholdItems()
                            TriggerServerEvent("inventory:server:OpenInventory", "crafting", math.random(1, 99), crafting)
                            sleep = 100
                        end
                    end
                end
            end
            Wait(sleep)
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if LocalPlayer.state['isLoggedIn'] then
            local pos = GetEntityCoords(PlayerPedId())
            local distance = #(pos - Config.AttachmentCraftingLocation)
            if distance < 10 then
                if distance < 1.5 then
                    sleep = 0
                    DrawText3Ds(Config.AttachmentCraftingLocation.x, Config.AttachmentCraftingLocation.y, Config.AttachmentCraftingLocation.z, "~g~E~w~ - Craft")
                    if IsControlJustPressed(0, 38) then
                        local crafting = {}
                        crafting.label = "Attachment Crafting"
                        crafting.items = GetAttachmentThresholdItems()
                        TriggerServerEvent("inventory:server:OpenInventory", "attachment_crafting", math.random(1, 99), crafting)
                        sleep = 100
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- Drop Stuff

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then
        if Config.UseItemDrop then RemoveAllNearbyDrops() end
    end
end)

function CreateItemDrop(index)
    local dropItem = CreateObject(Config.ItemDropObject, DropsNear[index].coords.x, DropsNear[index].coords.y, DropsNear[index].coords.z, false, false, false)
    DropsNear[index].object = dropItem
    DropsNear[index].isDropShowing = true
    PlaceObjectOnGroundProperly(dropItem)
    FreezeEntityPosition(dropItem, true)
    -- SetEntityCollision(dropItem, false, false)
	if Config.UseTarget then
		exports['qb-target']:AddTargetEntity(dropItem, {
			options = {
				{
					icon = 'fas fa-backpack',
					label = 'Open Bag',
					action = function()
						TriggerServerEvent("inventory:server:OpenInventory", "drop", index)
					end,
				}
			},
			distance = 2.5,
		})
	end
end
