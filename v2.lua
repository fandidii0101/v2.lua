--[[
	FanKunHUB (Auto Steal + Egg Filter)
	Engine Auto Steal diambil dari FanKunHub (tanpa fitur lain).
	UI, FPS/ms, Avatar, dan Live HUD progress dari versi sebelumnya.

	Toggle UI : RightShift  (atau tombol bulat di sisi kiri layar)
	Config    : FanKunHUB/config.json (jika executor mendukung writefile)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local localPlayer = Players.LocalPlayer

local v, tbl, register

local function fn()
	return Workspace:FindFirstChild("World") or Workspace:FindFirstChild("__OBJECTS")
end

local genv = getgenv and getgenv() or _G

-- matikan instance lama kalau script dieksekusi dua kali
if type(genv.__FanKunHUBHubShutdown) == "function" then
	pcall(genv.__FanKunHUBHubShutdown)
end

local fanKunHubHubSession = {}
genv.__FanKunHUBHubSession = fanKunHubHubSession

local function fn2()
	return genv.__FanKunHUBHubSession == fanKunHubHubSession
end

-- FPS rata-rata (dipakai engine untuk menyesuaikan settle time)
local n = 60

RunService.Heartbeat:Connect(function(deltaTime)
	if deltaTime and deltaTime > 0 then
		n = n * 0.9 + 1 / deltaTime * 0.1
	end
end)

local function fn3()
	return n
end

-- ping jaringan (dipakai engine untuk menambah waktu hold saat ping tinggi)
genv.__FanKunHUBNetPing = function()
	local ping = 0

	pcall(function()
		ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
	end)

	return tonumber(ping) or 0
end

-- config minimal: hanya key yang dipakai Auto Steal + Egg Filter
local fanKunHubConfig = {
	AutoSteal = false,
	HelpFriend = false,
	LowSpeedBoost = true,
	StealMode = "Instant",
	FlyAerial = false,
	FlyZigzag = false,
	StealHoldSeconds = 5,
	Language = "Indonesia",
	StealAreas = {"None"},
	StealRarities = {"None"},
	StealNamesFilter = {"None"},
	StealMinValue = 0,
	StealMutations = {"None"},
	StealMinWeight = 0,
	StealPriority = "Rarity",
	AutoIndex = false,
	AntiAfkTreadmill = false,
	AntiAfkJump = false,
	GodMode = true,
	AntiGuardKnockback = true,
	TweenSpeedMultiplier = 60,
	RunDropCount = 3,
	TaskOrder = {"auto_steal", "star", "mech_boss", "butterfly", "auto_place", "use_scrambled", "auto_sell", "treadmill"},
	TaskOrderPicked = {},
	TaskNumbers = {},
}


----------------------------------------------------------------------
-- ENGINE AUTO STEAL (dari FanKunHub)
local EggState = require(game:GetService("ReplicatedStorage").Client.EggState)
EggState.GetAreaEggSnapshot = EggState.ReadFieldEggs
EggState.GetAreaEggRecord = EggState.ReadFieldEgg
EggState.RequestAreaEggSnapshot = EggState.SyncFieldEggs
EggState.RequestCarryAreaEgg = EggState.CarryFieldEgg
EggState.RequestDropHeldAreaEgg = EggState.DropFieldEgg
EggState.AreaEggCarryStateChanged = EggState.CarryChanged
EggState.AreaEggClaimed = EggState.FieldClaimed
EggState.AreaEggUpdated = EggState.FieldShifted
EggState.AreaEggRemoved = EggState.FieldGone
EggState.GetOwnerRuntimeRecords = EggState.ReadOwnerEggs
EggState.RequestEquipTool = EggState.WearEggTool
EggState.RequestPlaceEgg = EggState.PlantEgg
EggState.RequestHatchEgg = EggState.BeginHatch
EggState.RequestCompleteHatchEgg = EggState.FinishHatch
EggState.RequestRuntimeSnapshot = EggState.SyncOwnedEggs
EggState.RuntimeOwnerUpdated = EggState.OwnerRefreshed
EggState.RuntimeOwnerCleared = EggState.OwnerCleared
local PlotState = require(game:GetService("ReplicatedStorage").Client.PlotState)
PlotState.GetMySlot = PlotState.ResolveLocalSlot
PlotState.GetPlotsFolder = PlotState.ResolveFolder
PlotState.IsWorldPositionWithinLocalPlotBounds = PlotState.ContainsLocalPoint
PlotState.GetPlotData = PlotState.ResolvePlot
local AreaEggResetWall = require(game:GetService("ReplicatedStorage").Client.AreaEggResetWall)
AreaEggResetWall.IsClosed = AreaEggResetWall.IsSealed

fanKunHubConfig.applyStealValueInput = function(arg, arg2)
	local str3 = string.lower(tostring(arg2 or "")):gsub("[%s,]", "")
	if str3 == "" then
		arg.StealMinValue = 0
		return true
	end
	local v5, v6 = string.match(str3, "^([%d]+%.?[%d]*)([kmb]?)$")
	local num = tonumber(v5)
	if not num then
		return false
	end
	arg.StealMinValue = num * (if v6 == "k" then 1000 else if v6 == "m" then 1000000 else if v6 == "b" then 1000000000 else 1)
	return true
end

fanKunHubConfig.getAreaEggValue = function(arg, arg2)
	if not arg._assetGenerationUtil then
		arg._assetGenerationUtil = require(game:GetService("ReplicatedStorage").Shared.Util.AssetEarnings)
	end

	return arg._assetGenerationUtil.MutationOnlyRatePerSecond({Category = arg2.AssetCategory, Scale = arg2.AssetScale or 1, Mutations = arg2.Mutations or {}, BaseMutation = arg2.BaseMutation, EyeColor = arg2.AssetEyeColor, ColorSeed = arg2.AssetColorSeed, ColorIndex = arg2.AssetColorIndex, Gender = arg2.Gender, Personality = arg2.Personality or "Normal", HasBeenFirstPlaced = arg2.HasBeenFirstPlaced == true})
end


local AreaEggCycle, AreaEggResetWall2

pcall(function()
	AreaEggCycle = require(ReplicatedStorage.Shared.Util.AreaEggCycle)
	AreaEggResetWall2 = require(ReplicatedStorage.Client.AreaEggResetWall)
end)

local function fn31()
	if AreaEggCycle and type(AreaEggCycle.IsNightPhase) == "function" then
		local ok, result = pcall(AreaEggCycle.IsNightPhase, workspace:GetServerTimeNow())
		if ok and result == true then
			return true
		end
	end

	if AreaEggResetWall2 then
		if type(AreaEggResetWall2.IsSealed) == "function" then
			local ok, result = pcall(AreaEggResetWall2.IsSealed)
			if ok and result == true then
				return true
			end
		end

		if type(AreaEggResetWall2.IsClosed) == "function" then
			local ok, result = pcall(AreaEggResetWall2.IsClosed)
			if ok and result == true then
				return true
			end
		end
	end

	return false
end

local fanKunHubTaskLadder = {}

do
	fanKunHubTaskLadder.DEFAULT = {"auto_steal", "star", "mech_boss", "butterfly", "auto_place", "use_scrambled", "auto_sell", "treadmill"}
	fanKunHubTaskLadder.TITLES = {auto_steal = "Auto Steal", star = "Shooting Star", mech_boss = "Mech Boss", butterfly = "Butterfly Bloom", auto_place = "Auto Place", use_scrambled = "Use Scrambled", auto_sell = "Auto Sell", treadmill = "Treadmill"}
	fanKunHubTaskLadder.PINNED = {treadmill = true}
	local tbl5 = {}

	fanKunHubTaskLadder.register = function(arg, arg2)
		tbl5[arg] = arg2
	end

	fanKunHubTaskLadder.sanitize = function(arg)
		local tbl6 = {}
		local tbl7 = {}

		local function fn32(arg2)
			local str3 = tostring(arg2)

			if fanKunHubTaskLadder.TITLES[str3] and (not tbl7[str3] and not fanKunHubTaskLadder.PINNED[str3]) then
				tbl7[str3] = true
				tbl6[#tbl6 + 1] = str3
			end
		end

		for i, v5 in ipairs(type(arg) == "table" and arg or {}) do
			fn32(v5)
		end

		for i, v5 in ipairs(fanKunHubTaskLadder.DEFAULT) do
			fn32(v5)
		end

		for i, v5 in ipairs(fanKunHubTaskLadder.DEFAULT) do
			if fanKunHubTaskLadder.PINNED[v5] and not tbl7[v5] then
				tbl7[v5] = true
				tbl6[#tbl6 + 1] = v5
			end
		end

		return tbl6
	end

	local v5, v6

	fanKunHubTaskLadder.order = function()
		local taskOrder = fanKunHubConfig and fanKunHubConfig.TaskOrder

		if taskOrder ~= v6 or not v5 then
			v6 = taskOrder
			v5 = fanKunHubTaskLadder.sanitize(taskOrder)
		end

		return v5
	end

	fanKunHubTaskLadder.rank = function(arg)
		for i, v7 in ipairs(fanKunHubTaskLadder.order()) do
			if v7 == arg then
				return i
			end
		end

		return 1 / 0
	end

	local function fn32(arg, arg2)
		local result = tbl5[arg]
		local v7 = result and result[arg2]
		if type(v7) ~= "function" then
			return nil
		end
		arg2, result = pcall(v7)
		if arg2 then
			return result
		end
		return nil
	end

	fanKunHubTaskLadder.wants = function(arg)
		return fn32(arg, "wants") == true
	end

	fanKunHubTaskLadder.active = function(arg)
		return fn32(arg, "active") == true
	end

	fanKunHubTaskLadder.enabled = function(arg)
		return fn32(arg, "enabled") == true
	end

	fanKunHubTaskLadder.bossFighting = function()
		if localPlayer:GetAttribute("InScrambleArena") == true then
			return true
		end

		local fanKunHubScrambleBoss = genv.__FanKunHUBScrambleBoss
		return fanKunHubScrambleBoss ~= nil and not fanKunHubScrambleBoss.destroyed and fanKunHubScrambleBoss.enabled == true and fanKunHubScrambleBoss:_inArena() == true
	end

	fanKunHubTaskLadder.stealCarrying = function()
		local fanKunHubEggRuntime = genv.__FanKunHUBEggRuntime

		if fanKunHubEggRuntime then
			if fanKunHubEggRuntime.destroyed then
				return false
			end
		else
			return false
		end

		if fanKunHubEggRuntime._instantReturnToken ~= nil then
			return true
		elseif fanKunHubEggRuntime._forestDropInProgress ~= nil then
			return true
		end

		local carry = fanKunHubEggRuntime.carry
		return carry ~= nil and carry.active == true and carry.uid ~= nil and carry.uid ~= fanKunHubEggRuntime.primerUid
	end

	local tbl6 = {}

	local function fn33(arg)
		if arg ~= "mech_boss" and fanKunHubTaskLadder.bossFighting() then
			return "mech_boss"
		end

		if arg ~= "auto_steal" and fanKunHubTaskLadder.stealCarrying() then
			return "auto_steal"
		end

		for i, v7 in ipairs(fanKunHubTaskLadder.order()) do
			if v7 == arg then
				return nil
			end

			if fanKunHubTaskLadder.wants(v7) then
				return v7
			end
		end

		return nil
	end

	fanKunHubTaskLadder.blocker = function(arg)
		local now = os.clock()
		local v7 = tbl6[arg]
		if v7 and now - v7.at < 0.1 then
			return v7.value
		end
		local v8 = fn33(arg)

		if v7 then
			v7.at = now
			v7.value = v8
		else
			tbl6[arg] = {at = now, value = v8}
		end

		return v8
	end

	fanKunHubTaskLadder.holder = function(arg)
		for i, v7 in ipairs(fanKunHubTaskLadder.order()) do
			if v7 ~= arg and (not fanKunHubTaskLadder.PINNED[v7] and fanKunHubTaskLadder.active(v7)) then
				return v7
			end
		end

		return nil
	end

	fanKunHubTaskLadder.yieldLabel = function(arg)
		local v7 = fanKunHubTaskLadder.blocker(arg)
		return v7 and "Yielding to " .. fanKunHubTaskLadder.TITLES[v7] or nil
	end

	fanKunHubTaskLadder.current = function()
		if fanKunHubTaskLadder.bossFighting() then
			return "mech_boss"
		end

		if fanKunHubTaskLadder.stealCarrying() then
			return "auto_steal"
		end

		for i, v7 in ipairs(fanKunHubTaskLadder.order()) do
			if fanKunHubTaskLadder.active(v7) then
				return v7
			end
		end

		return nil
	end

	fanKunHubTaskLadder.describe = function(arg)
		if not fanKunHubTaskLadder.enabled(arg) then
			return "Off", "off"
		end
		local v7 = fn32(arg, "status")
		local flag2 = type(v7) == "string" and v7 ~= "" and v7 or nil

		if fanKunHubTaskLadder.active(arg) then
			return flag2 or "Running", "run"
		elseif fanKunHubTaskLadder.current() == arg then
			return flag2 or "Running", "run"
		end

		local v8 = fanKunHubTaskLadder.blocker(arg)
		if v8 and fanKunHubTaskLadder.wants(arg) then
			return "Yielding to " .. fanKunHubTaskLadder.TITLES[v8], "wait"
		end
		return flag2 or "Idle", "off"
	end
end

genv.__FanKunHUBTaskLadder = fanKunHubTaskLadder

do
	if type(genv.__FanKunHUBStealDeclutterCleanup) == "function" then
		pcall(genv.__FanKunHUBStealDeclutterCleanup)
	end

	local tbl7 = {{name = "ProximityPrompts", restore = true}, {name = "AreaGui", restore = false}}
	local flag2 = false
	local tbl8 = {}

	local function fn39(arg)
		return arg and (arg:IsA("ScreenGui") or arg:IsA("LayerCollector"))
	end

	local function fn40(arg)
		if not arg:IsA("LayerCollector") then
			return
		end

		pcall(function()
			arg.Enabled = false
		end)

		table.insert(tbl8, arg:GetPropertyChangedSignal("Enabled"):Connect(function()
			if flag2 and arg.Enabled then
				pcall(function()
					arg.Enabled = false
				end)
			end
		end))
	end

	local function fn41(arg)
		if not fn39(arg) then
			return
		end

		pcall(function()
			arg.Enabled = false
		end)

		table.insert(tbl8, arg:GetPropertyChangedSignal("Enabled"):Connect(function()
			if flag2 and arg.Enabled then
				pcall(function()
					arg.Enabled = false
				end)
			end
		end))

		for i, child in ipairs(arg:GetChildren()) do
			fn40(child)
		end

		table.insert(tbl8, arg.ChildAdded:Connect(function(child)
			if flag2 then
				fn40(child)
			end
		end))
	end

	local function fn42(arg)
		local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
		if not playerGui then
			return
		end

		for i, v5 in ipairs(tbl7) do
			local v6 = playerGui:FindFirstChild(v5.name)

			if v6 then
				arg(v6, v5)
			end
		end
	end

	local function fn43()
		local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
		if not playerGui then
			return
		end

		fn42(function(arg)
			fn41(arg)
		end)

		table.insert(tbl8, playerGui.ChildAdded:Connect(function(child)
			if not flag2 then
				return
			end

			for i, v5 in ipairs(tbl7) do
				if child.Name == v5.name then
					fn41(child)
					break
				end
			end
		end))
	end

	local function fn44()
		for i, v5 in ipairs(tbl8) do
			pcall(function()
				v5:Disconnect()
			end)
		end

		table.clear(tbl8)

		fn42(function(arg, arg2)
			pcall(function()
				arg.Enabled = arg2.restore
			end)

			if arg2.restore then
				for i, child in ipairs(arg:GetChildren()) do
					if child:IsA("LayerCollector") then
						pcall(function()
							child.Enabled = true
						end)
					end
				end
			end
		end)
	end

	genv.__FanKunHUBSetStealDeclutter = function(arg)
		local flag3 = arg == true
		if flag3 == flag2 then
			return
		end
		flag2 = flag3

		if flag3 then
			fn43()
		else
			fn44()
		end
	end

	genv.__FanKunHUBStealDeclutterCleanup = function()
		flag2 = false
		fn44()
	end
end

local v5 = (function()
	local index = {}
	index.__index = index
	local tbl11 = {auto_place = true, auto_fuse = true, equip_best = true}
	local tbl12 = {auto_steal = 100, auto_hatch = 80, auto_place = 70, auto_fuse = 50, equip_best = 40, rewards = 20}

	local function fn60(arg)
		local tbl13 = {}

		for k, v5 in pairs(arg) do
			tbl13[k] = v5
		end

		return tbl13
	end

	index.new = function()
		local obj = setmetatable({}, index)
		obj.destroyed = false
		obj.active = nil
		obj.background = nil
		obj.reservations = {}
		obj.listeners = {}
		obj.backgroundListeners = {}
		obj.serial = 0
		return obj
	end

	index._snapshot = function(arg)
		local active = arg.active
		return {busy = active ~= nil, operation = active and active.owner or nil, priority = active and active.priority or 0, reservedCount = active and #active.uids or 0, reservations = fn60(arg.reservations)}
	end

	index._emit = function(arg)
		local v5 = arg:_snapshot()

		for k in pairs(arg.listeners) do
			local ok, result = pcall(k, v5)

			if not ok then
				warn("[StealAnEgg] Coordinator listener failed:", result)
			end
		end
	end

	index._emitBackground = function(arg)
		local background = arg.background
		local tbl13 = {busy = background ~= nil, operation = background and background.owner or nil}

		for k in pairs(arg.backgroundListeners) do
			local ok, result = pcall(k, tbl13)

			if not ok then
				warn("[StealAnEgg] Background coordinator listener failed:", result)
			end
		end
	end

	index.subscribe = function(arg, arg2)
		arg.listeners[arg2] = true
		pcall(arg2, arg:_snapshot())

		return function()
			arg.listeners[arg2] = nil
		end
	end

	index.subscribeBackground = function(arg, arg2)
		arg.backgroundListeners[arg2] = true
		local v5 = pcall
		local tbl13 = {busy = arg.background ~= nil}
		tbl13.operation = arg.background and arg.background.owner or nil
		v5(arg2, tbl13)

		return function()
			arg.backgroundListeners[arg2] = nil
		end
	end

	index.getSnapshot = function(arg)
		return arg:_snapshot()
	end

	index.isBackgroundBusy = function(arg)
		return arg.background ~= nil
	end

	index.isReserved = function(arg, arg2, arg3)
		local v5 = arg.reservations[arg2]
		return v5 ~= nil and v5 ~= arg3
	end

	index.tryAcquire = function(arg, arg2, arg3, arg4)
		if arg.destroyed then
			return nil, "Coordinator destroyed"
		end

		if type(arg2) ~= "string" then
			return nil, "Invalid operation owner"
		elseif arg2 == "" then
			return nil, "Invalid operation owner"
		end

		if arg.active then
			return nil, "Busy: " .. arg.active.owner
		end

		if arg.background and tbl11[arg2] then
			return nil, "Busy: background " .. arg.background.owner
		end
		local tbl13 = {}
		local tbl14 = {}

		for i, v5 in ipairs(type(arg3) == "table" and arg3 or {}) do
			if type(v5) == "string" and (v5 ~= "" and not tbl14[v5]) then
				if arg:isReserved(v5, arg2) then
					return nil, "UID reserved by " .. tostring(arg.reservations[v5])
				end
				tbl14[v5] = true
				table.insert(tbl13, v5)
			end
		end

		arg.serial = arg.serial + 1
		local active = {id = arg.serial, lane = "foreground", owner = arg2, priority = tonumber(arg4) or tbl12[arg2] or 0, uids = tbl13, released = false}
		arg.active = active

		for i, v5 in ipairs(tbl13) do
			arg.reservations[v5] = arg2
		end

		arg:_emit()
		return active
	end

	index.tryAcquireBackground = function(arg, arg2, arg3)
		if arg.destroyed then
			return nil, "Coordinator destroyed"
		end

		if type(arg2) ~= "string" then
			return nil, "Invalid operation owner"
		elseif arg2 == "" then
			return nil, "Invalid operation owner"
		end

		if arg.background then
			return nil, "Background busy: " .. arg.background.owner
		end

		if arg.active and tbl11[arg.active.owner] then
			return nil, "Foreground tool busy: " .. arg.active.owner
		end
		local tbl13 = {}
		local tbl14 = {}

		for i, v5 in ipairs(type(arg3) == "table" and arg3 or {}) do
			if type(v5) == "string" and (v5 ~= "" and not tbl14[v5]) then
				if arg:isReserved(v5, arg2) then
					return nil, "UID reserved by " .. tostring(arg.reservations[v5])
				end
				tbl14[v5] = true
				table.insert(tbl13, v5)
			end
		end

		arg.serial = arg.serial + 1
		local background = {id = arg.serial, lane = "background", owner = arg2, priority = 0, uids = tbl13, released = false}
		arg.background = background

		for i, v5 in ipairs(tbl13) do
			arg.reservations[v5] = arg2
		end

		arg:_emitBackground()
		return background
	end

	index.release = function(arg, arg2)
		if type(arg2) ~= "table" then
			return false
		elseif arg2.released then
			return false
		end

		arg2.released = true

		for i, v5 in ipairs(arg2.uids or {}) do
			if arg.reservations[v5] == arg2.owner then
				arg.reservations[v5] = nil
			end
		end

		local flag5 = arg.active == arg2

		if flag5 then
			arg.active = nil
		elseif arg.background == arg2 then
			arg.background = nil
			arg:_emitBackground()
		end

		if flag5 then
			arg:_emit()
		end

		return true
	end

	index.destroy = function(arg)
		if arg.destroyed then
			return
		end
		arg.destroyed = true

		if arg.active then
			arg:release(arg.active)
		end

		if arg.background then
			arg:release(arg.background)
		end

		table.clear(arg.reservations)
		table.clear(arg.listeners)
		table.clear(arg.backgroundListeners)
	end

	return index
end)()

local v6 = (function()
	local ReplicatedStorage2 = game:GetService("ReplicatedStorage")
	local Areas = require(ReplicatedStorage2.Data.Areas)
	local Assets = require(ReplicatedStorage2.Data.Assets)
	local Guards = require(ReplicatedStorage2.Data.Guards)
	local Mutations = require(ReplicatedStorage2.Shared.Modules.Mutations)
	local tbl11 = {}
	local tbl12 = {Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Cosmic = 7, Secret = 8, Eternal = 9, Divine = 10}

	tbl11.rarityRank = function(arg)
		return tbl12[arg] or 0
	end

	local function fn60(arg)
		local tbl13 = {}
		local tbl14 = {}

		for i, v6 in ipairs(arg) do
			if type(v6) == "string" and (v6 ~= "" and not tbl13[v6]) then
				tbl13[v6] = true
				table.insert(tbl14, v6)
			end
		end

		table.sort(tbl14)
		return tbl14
	end

	tbl11.getRarities = function()
		local tbl13 = {}

		for k in pairs(Assets.ByRarity) do
			table.insert(tbl13, k)
		end

		table.sort(tbl13, function(arg, arg2)
			local n8 = tbl12[arg] or 99
			local n9 = tbl12[arg2] or 99
			if n8 ~= n9 then
				return n8 < n9
			end
			return tostring(arg) < tostring(arg2)
		end)

		return tbl13
	end

	tbl11.getNames = function()
		local tbl13 = {}

		for k, v6 in pairs(Assets.Directory) do
			table.insert(tbl13, v6.DisplayName or v6._id)
		end

		return fn60(tbl13)
	end

	tbl11.getAreas = function()
		local tbl13 = {}

		for k, v6 in pairs(Areas.Directory) do
			if type(k) == "string" and (type(v6) == "table" and type(v6.DropTable) == "table") then
				table.insert(tbl13, k)
			end
		end

		table.sort(tbl13, function(arg, arg2)
			local v6 = Guards.Directory[arg]
			local v7 = Guards.Directory[arg2]
			local walkSpeed = v6 and v6.WalkSpeed or 1 / 0
			local walkSpeed2 = v7 and v7.WalkSpeed or 1 / 0
			if walkSpeed ~= walkSpeed2 then
				return walkSpeed < walkSpeed2
			end
			return arg < arg2
		end)

		return tbl13
	end

	tbl11.getMutations = function()
		local tbl13 = {}
		local v6 = Mutations.Ids()

		for k in pairs(type(v6) == "table" and v6 or {}) do
			if type(k) == "string" and k ~= Mutations.NO_MUTATION then
				local ok, result = pcall(Mutations.LabelOf, k)
				table.insert(tbl13, ok and type(result) == "string" and result ~= "" and result or k)
			end
		end

		return fn60(tbl13)
	end

	tbl11.resolveMutationId = function(arg)
		if type(arg) ~= "string" then
			return nil
		end

		if Mutations.IdSet[arg] then
			return arg
		end

		for k in pairs(Mutations.Ids()) do
			if k ~= Mutations.NO_MUTATION and Mutations.LabelOf(k) == arg then
				return k
			end
		end

		return nil
	end

	tbl11.resolve = function(arg)
		local v6 = arg and Assets.Directory[arg.AssetCategory]
		local rarity = v6 and v6.Rarity
		local displayName = rarity and (rarity.DisplayName or rarity._id) or "Unknown"
		return {name = v6 and (v6.DisplayName or v6._id) or arg and arg.AssetCategory or "Unknown", category = arg and arg.AssetCategory or "Unknown", rarity = displayName, rarityRank = tbl12[displayName] or 0, rarityColor = rarity and rarity.Color or nil, icon = v6 and type(v6.Icon) == "string" and v6.Icon or nil}
	end

	return tbl11
end)()

local function fn60(arg)
	if not arg then
		return nil
	end

	for i, descendant in ipairs(arg:GetDescendants()) do
		if descendant:IsA("ModuleScript") and (descendant.Name == "Limits" and (descendant.Parent and (descendant.Parent:FindFirstChild("Surface") and descendant.Parent:FindFirstChild("Runtime")))) then
			return descendant
		end
	end

	return nil
end

local v7 = fn60(localPlayer:FindFirstChildOfClass("PlayerScripts")) or fn60(game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts"))

local v8 = (function()
	local Players2 = game:GetService("Players")
	local ReplicatedStorage2 = game:GetService("ReplicatedStorage")
	local RunService2 = game:GetService("RunService")
	local localPlayer2 = Players2.LocalPlayer
	local EggState2 = require(ReplicatedStorage2.Client.EggState)
	local Remotes = require(ReplicatedStorage2.Shared.Remotes)
	local eggWorld = Remotes.EggWorld
	local AreaEggs = require(ReplicatedStorage2.Shared.Types.AreaEggs)
	local AreaEggSlotIdentity = require(ReplicatedStorage2.Shared.Util.AreaEggSlotIdentity)
	local AreaEggResetWall3 = require(ReplicatedStorage2.Client.AreaEggResetWall)
	local SpeedPowerProjection = require(ReplicatedStorage2.Client.SpeedPowerProjection)
	local TreadmillUtil = require(ReplicatedStorage2.Shared.Util.TreadmillUtil)
	local EggRecords = require(ReplicatedStorage2.Shared.Util.EggRecords)
	local AssetEarnings = require(ReplicatedStorage2.Shared.Util.AssetEarnings)
	local Save = require(ReplicatedStorage2.Shared.Save)
	local PlotState2 = require(ReplicatedStorage2.Client.PlotState)
	local n8 = 10
	local n9 = 20
	local n10 = 100
	local n11 = 60
	local n12 = 0.05
	local n13 = 200
	local n14 = 1000
	local n15 = 600
	local speed = 3000

	local function fn61()
		return genv.__FanKunHUBAdminBoost == true and speed or n14
	end

	local str3 = "__FanKunHUBStealAnEggMovementSpoof"
	local n16 = 436
	local str4 = "__FanKunHUBStealAnEggIntegritySpoof"
	local tbl11 = {Divine = true, Eternal = true}
	local str5 = "ClientCharacter: GetDebugSnapshot"
	local tbl12 = {"LastObservedSample", "LastSample", "LastGoodSample", "LastGameplayTrustedSample", "LastValidatedSample", "LastValidatedGroundedSample", "LastConfirmedGroundSample", "CandidateGroundedSample"}
	local n17 = 0.15
	local n18 = 8
	local n19 = 1
	local name2 = "__FanKunHUBHoverPad"
	local str6 = "FanKunHUBRuntimeOwner"
	local vector2 = Vector3.new(538, 71, -365)
	local n20 = 612
	local tbl13 = {-364.3, -367.21, -371.12, -375.65}
	CFrame.new(599.8, 113.5, -325)
	Vector3.new(599.8, 70, -325)
	local n21 = 3
	local n22 = 0.85
	local n23 = 2
	local n24 = 3000
	local cframe = CFrame.new(554.071, 70.276, -395.573, 0, 0, 1, 0, 1, 0, -1, 0, 0)
	local n25 = 14
	local n26 = 0.7
	local n27 = 3
	local n28 = 6
	local n29 = 0.45
	local n30 = 30
	local n31 = 18
	local n32 = 0.35
	local n33 = 2
	local n34 = 0.1
	local name3 = "__FanKunHUBTreadmillDecoy"
	local tbl14 = {Script = true, LocalScript = true, BillboardGui = true, Sound = true}
	local n35 = 0.25
	local n36 = 5
	local n37 = 2
	local n38 = 45
	local n39 = 10
	local n40 = 0.03
	local n41 = 0.65
	local n42 = 0.35
	local n43 = 0.08
	local n44 = 1.35
	local n45 = 0.15
	local n46 = 24
	local n47 = 2
	local n48 = 0.5
	local n49 = 0.45
	local n50 = 0.4
	local str7 = "PlayerTrap"
	local str8 = "Trap"
	local index = {}
	index.__index = index
	local Stats = game:GetService("Stats")

	local function fn62(arg, firstAreaSlotKey)
		local humanoidRootPart = localPlayer2.Character and localPlayer2.Character:FindFirstChild("HumanoidRootPart")

		if humanoidRootPart then
			pcall(function()
				humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			end)
		end

		local n51 = 0

		pcall(function()
			n51 = Stats.Network.ServerStats.Ping:GetValue()
		end)

		task.wait(math.max(0.3, n51 * 2.5 / 1000))
		local tbl15 = {Uid = arg}

		if firstAreaSlotKey ~= nil then
			tbl15.FirstAreaSlotKey = firstAreaSlotKey
		end

		firstAreaSlotKey, arg = eggWorld.AskFieldEggCarry:InvokeServer(tbl15)
		return firstAreaSlotKey == true, typeof(arg) == "string" and arg or nil
	end

	local function fn63(arg, arg2, arg3)
		local connection6 = arg:Connect(arg2)
		table.insert(arg3, connection6)
		return connection6
	end

	local function fn64(arg)
		for i, v8 in ipairs(arg) do
			pcall(v8.Disconnect, v8)
		end

		table.clear(arg)
	end

	local function fn65(arg, arg2)
		for i, v8 in ipairs(arg or {}) do
			if v8 == arg2 then
				return true
			end
		end

		return false
	end

	local fn66

	local function fn67(arg)
		local humanoidRootPart = arg and arg:FindFirstChild("HumanoidRootPart")

		if humanoidRootPart then
			humanoidRootPart:SetAttribute("KillPartIgnore", true)
		end
	end

	local function fn68(arg)
		if arg._healthPinner then
			pcall(arg._healthPinner.Disconnect, arg._healthPinner)
			arg._healthPinner = nil
		end

		if arg._healthChangedConnection then
			pcall(arg._healthChangedConnection.Disconnect, arg._healthChangedConnection)
			arg._healthChangedConnection = nil
		end
	end

	local function fn69(arg, arg2)
		fn68(arg)
		local humanoid = arg2 and arg2:FindFirstChildOfClass("Humanoid")
		local humanoidRootPart = arg2 and arg2:FindFirstChild("HumanoidRootPart")
		if not humanoid then
			return false
		end
		local health = math.max(humanoid.MaxHealth, 100)
		local flag5 = false
		local n51 = 0

		local function fn70()
			if flag5 then
				return
			elseif arg.destroyed then
				return
			elseif localPlayer2.Character ~= arg2 then
				return
			elseif not humanoid.Parent then
				return
			end

			local now = os.clock()
			if now - n51 < 0.1 and (humanoid.Health > 0 and humanoid:GetState() ~= Enum.HumanoidStateType.Dead) then
				return
			end
			n51, flag5 = now, true

			pcall(function()
				humanoid.BreakJointsOnDeath = false
				humanoid.RequiresNeck = false
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
				humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

				if humanoid.Health <= 0 then
					humanoid.Health = health
				end

				if humanoid:GetState() == Enum.HumanoidStateType.Dead then
					humanoid:ChangeState(Enum.HumanoidStateType.Running)
				end

				if humanoidRootPart and (humanoidRootPart.Parent == arg2 and humanoidRootPart.Anchored) then
					humanoidRootPart.Anchored = false
				end
			end)

			flag5 = false
		end

		fn70()

		arg._healthChangedConnection = humanoid.HealthChanged:Connect(function(health2)
			if health2 <= 0 then
				fn70()
			elseif health2 < health then
				fn70()
			end
		end)

		arg._healthPinner = RunService2.Heartbeat:Connect(fn70)
		return true
	end

	local function fn70(arg)
		local humanoid = arg and arg:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		pcall(function()
			if humanoid.Health <= 0 then
				humanoid.Health = math.max(humanoid.MaxHealth, 1)
			end

			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
			humanoid.BreakJointsOnDeath = true
			humanoid.RequiresNeck = true
		end)
	end

	local function fn71()
		return getgenv and getgenv() or _G
	end

	local function fn72()
		if type(getconnections) ~= "function" then
			return false
		elseif type(debug) ~= "table" then
			return false
		elseif type(debug.info) ~= "function" then
			return false
		elseif type(debug.getupvalue) ~= "function" then
			return false
		end

		local ok, result = pcall(getconnections, localPlayer2.Idled)

		if ok then
			if type(result) ~= "table" then
				return false
			end
		else
			return false
		end

		local str9 = ".PlayerScripts.Game.AntiAFK"

		for i, v8 in ipairs(result) do
			local function_ = v8.Function

			if type(function_) == "function" and type(v8.Disable) == "function" then
				local ok2, result2 = pcall(debug.info, function_, "s")
				local ok3, result3 = pcall(debug.getupvalue, function_, 1)
				if ok2 and (type(result2) == "string" and (result2:sub(-27) == str9 and (ok3 and type(result3) == "number"))) then
					return (pcall(v8.Disable, v8))
				end
			end
		end

		return false
	end

	local function fn73()
		local v8 = fn71()
		local tbl15 = v8[str3]

		if type(tbl15) ~= "table" or tbl15.Version ~= n16 then
			if type(tbl15) == "table" then
				tbl15.Enabled = false
			end

			tbl15 = {Version = n16, Installed = false, Enabled = false, Mode = "StateBaseline", Humanoid = nil, RootPart = nil, WalkSpeed = n15}
			v8[str3] = tbl15
		end

		return tbl15
	end

	local function fn74(arg, arg2)
		local v8 = fn73()
		if not v8 then
			return false
		end
		local humanoid = arg and arg:FindFirstChildOfClass("Humanoid")
		local humanoidRootPart = arg and arg:FindFirstChild("HumanoidRootPart")
		v8.Humanoid = humanoid
		v8.RootPart = humanoidRootPart
		v8.WalkSpeed = math.clamp(tonumber(arg2) or n15, n13, n14 * n44)
		v8.Enabled = false
		return humanoid ~= nil and humanoidRootPart ~= nil
	end

	local function fn75()
		local v8 = fn71()[str3]

		if type(v8) == "table" then
			v8.Enabled = false
			v8.Humanoid = nil
			v8.RootPart = nil
		end
	end

	local function fn76(arg, arg2, arg3)
		local v8

		if type(getcallbackvalue) == "function" and type(debug) == "table" and type(debug.getupvalue) == "function" then
			local signal2 = ReplicatedStorage2:FindFirstChild("Packages") and ReplicatedStorage2.Packages:FindFirstChild("Signal")

			if signal2 then
				local ok, result = pcall(require, signal2)

				if ok and type(result) == "table" and type(result.Invoked) == "function" then
					local ok2, result2 = pcall(result.Invoked, str5)

					if ok2 and result2 then
						local ok3, result3 = pcall(getcallbackvalue, result2, "OnInvoke")

						if ok3 and type(result3) == "function" then
							local ok4, result4 = pcall(debug.getinfo, result3)

							if ok4 then
								local function fn77(arg4, arg5, arg6)
									if v8 then
										return
									elseif type(arg4) ~= "table" then
										return
									elseif arg5 > 3 then
										return
									elseif arg6[arg4] then
										return
									end

									arg6[arg4] = true
									if rawget(arg4, "Player") == arg and (rawget(arg4, "Character") == arg.Character and (rawget(arg4, "Humanoid") == arg2 and (rawget(arg4, "RootPart") == arg3 and (type(rawget(arg4, "SampleHistory")) == "table" and type(rawget(arg4, "Evidence")) == "table")))) then
										v8 = arg4
										return
									end
									local n51 = 0

									for k, v9 in pairs(arg4) do
										n51 += 1
										if n51 > 128 then
											break
										end

										if type(v9) == "table" then
											fn77(v9, arg5 + 1, arg6)
										end
									end
								end

								for i = 1, result4.nups or 0, 1 do
									local ok5, result5 = pcall(debug.getupvalue, result3, i)

									if ok5 and type(result5) == "table" then
										fn77(result5, 0, {})
										if v8 then
											break
										end
									end
								end
							end
						end
					end
				end
			end
		end

		if not v8 and type(getgc) == "function" then
			local ok, result = pcall(getgc, true)

			if ok and type(result) == "table" then
				for i, v9 in ipairs(result) do
					if type(v9) == "table" and rawget(v9, "Player") == arg and rawget(v9, "Character") == arg.Character and rawget(v9, "Humanoid") == arg2 and rawget(v9, "RootPart") == arg3 and type(rawget(v9, "SampleHistory")) == "table" and type(rawget(v9, "Evidence")) == "table" then
						v8 = v9
						break
					end
				end
			end
		end

		return v8
	end

	local tbl15 = {busy = false, nextAt = 0, misses = 0, found = nil}

	local function fn77(arg, arg2, arg3)
		local found = tbl15.found
		if type(found) == "table" and (rawget(found, "Player") == arg and (rawget(found, "Character") == arg.Character and (rawget(found, "Humanoid") == arg2 and rawget(found, "RootPart") == arg3))) then
			return found
		end

		if tbl15.busy then
			return nil
		elseif os.clock() < tbl15.nextAt then
			return nil
		end

		tbl15.busy = true

		task.spawn(function()
			task.wait()
			local ok, result = pcall(fn76, arg, arg2, arg3)
			local v8 = ok and result or nil
			tbl15.found = v8
			tbl15.misses = v8 and 0 or tbl15.misses + 1
			tbl15.nextAt = os.clock() + (v8 and 0.2 or (tbl15.misses >= 5 and 10 or 1))
			tbl15.busy = false
		end)

		return nil
	end

	local function fn78(arg, arg2, arg3)
		if type(arg) ~= "table" then
			return false
		end
		local value = rawget(arg, "RootPart")
		local cFrame = value and value.Parent and value.CFrame or nil
		local position = cFrame and cFrame.Position or nil
		local vector3 = typeof(arg3) == "Vector3" and arg3 or Vector3.new(0, 0, 0)

		local function fn79(arg4)
			if type(arg4) == "table" then
				rawset(arg4, "WalkSpeed", arg2)

				if cFrame then
					rawset(arg4, "CFrame", cFrame)
					rawset(arg4, "Position", position)
					rawset(arg4, "LinearVelocity", vector3)
					rawset(arg4, "AngularVelocity", (Vector3.new(0, 0, 0)))
				end
			end
		end

		for i, v8 in ipairs(tbl12) do
			fn79(rawget(arg, v8))
		end

		for k, v8 in pairs(rawget(arg, "SampleHistory") or {}) do
			fn79(v8)
		end

		for k, v8 in pairs(rawget(arg, "SafeGroundCheckpoints") or {}) do
			fn79(v8)
		end

		local value2 = rawget(arg, "Evidence")

		if type(value2) == "table" then
			value2.Speed = 0
			value2.Teleport = 0
			value2.Flight = 0
		end

		local value3 = rawget(arg, "ImpulseContext")

		if type(value3) == "table" then
			local maxHorizontalSpeed = math.max(tonumber(value3.MaxHorizontalSpeed) or 0, arg2)
			local n51 = math.max((tonumber(value3.ExpiresAt) or 0) - (tonumber(value3.StartedAt) or 0), n45)
			value3.MaxHorizontalSpeed = maxHorizontalSpeed

			if position then
				value3.OriginPosition = position
			end

			value3.MaxHorizontalDistance = math.max(tonumber(value3.MaxHorizontalDistance) or 0, maxHorizontalSpeed * n51 + n46 * 2)
			fn79(value3.PreMovementSafeSample)
		end

		if rawget(arg, "CorrectionContext") == nil then
			rawset(arg, "FirstSuspiciousAt", nil)

			if rawget(arg, "ThreatLevel") == "Observing" then
				rawset(arg, "ThreatLevel", "Trusted")
			end
		end

		return true
	end

	local function fn79()
		local v8 = fn71()
		local tbl16 = v8[str4]

		if type(tbl16) ~= "table" then
			tbl16 = {}
			v8[str4] = tbl16
		end

		return tbl16
	end

	local function fn80(arg, arg2, arg3)
		return type(arg) == "table" and rawget(arg, "Player") == localPlayer2 and rawget(arg, "Character") == localPlayer2.Character and rawget(arg, "Humanoid") == arg2 and rawget(arg, "RootPart") == arg3
	end

	local function fn81(arg, arg2, arg3)
		return fn80(arg, arg2, arg3)
	end

	local function fn82(humanoid, rootPart, arg)
		local v8 = fn79()
		local state = v8.State

		if fn80(state, humanoid, rootPart) then
		else
			local now = os.clock()
			if now < (v8.NextSearchAt or 0) then
				return false
			end
			v8.NextSearchAt = now + 0.2
			state = fn77(localPlayer2, humanoid, rootPart)
		end

		if not state then
			return false
		end

		if not fn81(state, humanoid, rootPart) then
			v8.Enabled = false
			v8.Humanoid = humanoid
			v8.RootPart = rootPart
			v8.State = state
			return false
		end

		v8.NextSearchAt = 0
		v8.Enabled = true
		v8.Humanoid = humanoid
		v8.RootPart = rootPart
		v8.State = state
		v8.WalkSpeed = math.clamp(arg * n44, n13, n14 * n44)
		v8.TravelVelocity = Vector3.new(0, 0, 0)
		fn78(state, v8.WalkSpeed, v8.TravelVelocity)
		return true
	end

	local function fn83(arg, arg2, arg3, travelVelocity)
		local v8 = fn71()[str4]

		if type(v8) ~= "table" then
			return false
		elseif v8.Enabled then
			if v8.Humanoid ~= arg then
				return false
			elseif v8.RootPart ~= arg2 then
				return false
			elseif not fn81(v8.State, arg, arg2) then
				return false
			end
		else
			return false
		end

		v8.WalkSpeed = math.clamp(arg3 * n44, n13, n14 * n44)

		if typeof(travelVelocity) == "Vector3" then
			v8.TravelVelocity = travelVelocity
		elseif typeof(v8.TravelVelocity) ~= "Vector3" then
			v8.TravelVelocity = Vector3.new(0, 0, 0)
		end

		return fn78(v8.State, v8.WalkSpeed, v8.TravelVelocity)
	end

	local function fn84(arg)
		local v8 = fn71()[str4]
		if type(v8) ~= "table" then
			return
		end

		if arg == nil or v8.Humanoid == arg then
			v8.Enabled = false
			v8.Humanoid = nil
			v8.RootPart = nil
			v8.State = nil
			v8.TravelVelocity = nil
			v8.NextSearchAt = 0
		end
	end

	local function fn85(arg, arg2)
		if #arg2 == 0 then
			return true
		end

		for i, v8 in ipairs(arg.Mutations or {}) do
			if fn65(arg2, v8) then
				return true
			end
		end

		return arg.BaseMutation ~= nil and fn65(arg2, arg.BaseMutation)
	end

	local function fn86()
		local v8 = TreadmillUtil.SpeedPowerToWalkSpeed(SpeedPowerProjection.ReadProjected())
		local character = localPlayer2.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local walkSpeed = humanoid and humanoid.WalkSpeed or v8
		return math.clamp(math.min(v8, walkSpeed), n13, n14)
	end

	index.new = function(catalog, limitsModule, coordinator)
		local obj = setmetatable({}, index)
		obj.catalog = catalog
		obj.limitsModule = limitsModule
		obj.coordinator = coordinator
		obj.operationToken = nil
		obj.connections = {}
		obj.listeners = {}
		obj.records = {}
		obj.enabled = false
		obj.userStealEnabled = false
		obj.skippedEggs = {}
		obj.riftWants = {}
		obj.riftOnly = false
		obj.indexObjectiveEnabled = false
		obj.wispObjective = nil
		obj.manualObjectiveEnabled = false
		obj.manualQueue = {}
		obj.manualOrder = {}
		obj.indexCache = {at = 0, set = {}}
		obj.running = false
		obj.safeStarting = false
		obj.movementRetryPending = false
		obj.destroyed = false
		obj.resetBlocked = AreaEggResetWall3.IsSealed()
		obj.gateOpenAt = obj.resetBlocked and 1 / 0 or os.clock()
		obj.activeTween = nil
		obj.activeTarget = nil
		obj.claimPresentationNode = nil
		obj.claimPresentationOriginal = nil
		obj.claimPresentationSuppression = nil
		obj.carry = {active = false, uid = nil, generation = 0}
		obj.carryWorker = nil
		obj.tweenRecoveryUid = nil
		obj.planGeneration = 0
		obj.treadmillDecoy = nil
		obj.treadmillDecoyCamera = nil
		obj.treadmillDecoyCameraConnection = nil
		obj.treadmillDecoyCharacterConnection = nil
		obj.treadmillPopupConnection = nil
		obj.treadmillDecoyRealTransparency = nil
		obj.hoverPadOwnerId = string.format("%s:%0.6f", tostring(obj), os.clock())
		obj.instantPhase = nil
		obj.primerUid = nil
		obj.primerUids = {}
		obj.targetUid = nil
		obj.hitTimer = nil
		obj.guardHitBoostInstalled = false
		obj.stats = {status = obj.resetBlocked and "Reset wall closed" or "Ready", available = 0, matching = 0, lastTarget = "None", lastResult = "Idle"}
		obj.config = {stealMode = "Instant", flyAerial = false, flyZigzag = false, speed = n15, antiTrap = true, heaviestFirst = false, highestValueFirst = false, minWeightKg = 0, espEnabled = false, espRarity = true, espName = true, espKg = true, espMutation = true, espValue = true, espPlaced = false, espIcon = true, espMinRank = 0, espMinValue = 0, minValuePerSec = 0, rarityEnabled = false, rarities = {}, nameEnabled = false, names = {}, areaEnabled = false, areas = {}, mutationEnabled = false, mutations = {}}
		obj.gameAntiAfkDisabled = fn72()

		if localPlayer2.Character then
			fn67(localPlayer2.Character)
			local humanoid = localPlayer2.Character:FindFirstChildOfClass("Humanoid")

			if humanoid then
				pcall(function()
					humanoid.BreakJointsOnDeath = false
					humanoid.RequiresNeck = false
					humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
					humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
					humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
				end)
			end

			fn69(obj, localPlayer2.Character)
		end

		catalog, limitsModule = pcall(function()
			return require(ReplicatedStorage2.Shared.Util.EggRecords)
		end)

		obj.weightUtil = catalog and type(limitsModule.WeightKgForScale) == "function" and limitsModule or nil

		local function fn87(arg)
			if not arg then
				return
			end

			fn63(arg.DescendantAdded, function(arg2)
				if obj.config.antiTrap then
					obj:_purgeTrap(arg2)
				end
			end, obj.connections)
		end

		fn87(workspace:FindFirstChild("Transient"))
		fn87(workspace:FindFirstChild("__DEBRIS"))

		if obj.config.antiTrap then
			obj:_purgeTraps()
		end

		fn63(workspace.ChildAdded, function(arg)
			if arg.Name == "Transient" or arg.Name == "__DEBRIS" then
				fn87(arg)

				if obj.config.antiTrap then
					obj:_purgeTraps()
				end
			end
		end, obj.connections)

		obj:_replaceSnapshot(EggState2.ReadFieldEggs())

		fn63(EggState2.FieldRefreshed, function(arg)
			obj:_replaceSnapshot(arg)
		end, obj.connections)

		fn63(EggState2.FieldShifted, function(arg)
			obj.records[arg.Uid] = arg
			obj:_refreshCounts()

			if obj.enabled and not obj.destroyed and not obj.running and not obj.carry.active and (arg.State == AreaEggs.States.Slot or arg.State == AreaEggs.States.Dropped) and not obj._shiftWakePending then
				obj._shiftWakePending = true

				task.delay(0.25, function()
					obj._shiftWakePending = nil

					if not obj.destroyed and (obj.enabled and not obj.running) then
						obj:_schedule()
					end
				end)
			end
		end, obj.connections)

		fn63(EggState2.FieldGone, function(arg)
			obj.records[arg] = nil

			if obj.activeTarget and obj.activeTarget.Uid == arg then
				if obj.carry.active and obj.carry.uid == arg then
					obj:_refreshCounts()
					return
				end
				obj.carryAttemptToken = nil
				obj:_clearArrivalHold(arg)

				if obj.activeTween and obj.activeTween.Cancel then
					pcall(obj.activeTween.Cancel, obj.activeTween)
				end

				local activeTarget = obj.activeTarget

				task.delay(n41, function()
					if obj.destroyed then
						return
					elseif not obj.enabled then
						return
					end

					if obj.carry.active and obj.carry.uid == arg then
						return
					end

					if obj.activeTarget == activeTarget and activeTarget.Uid == arg then
						obj:_finish("Target removed \226\128\148 continuing")
					end
				end)
			end

			obj:_refreshCounts()
		end, obj.connections)

		fn63(EggState2.ResetCountdown, function()
			obj:_closeGate("Egg reset countdown")
		end, obj.connections)

		fn63(EggState2.ResetFade, function()
			obj:_closeGate("Egg reset teleport")
		end, obj.connections)

		fn63(AreaEggResetWall3.Changed, function(arg)
			if arg then
				obj:_closeGate("Reset wall closed")
			else
				obj.resetBlocked = false
				obj.gateOpenAt = os.clock()
				obj.safeStarting = false
				obj.running = false
				obj:_setStatus(obj.enabled and "Searching" or "Ready")
				obj:_schedule()
			end
		end, obj.connections)

		fn63(localPlayer2.CharacterRemoving, function()
			obj._recalling = nil
			obj:_cleanupInstantSteal()
			obj:_hideTreadmillDecoy()
			obj._forestDropInProgress = nil
			obj._instantReturnToken = nil
			obj.carry.generation += 1
			obj:_invalidateCarryWorker()
			obj.carry.active = false
			obj.carry.uid = nil
			obj.safeStarting = false
			obj.planGeneration = obj.planGeneration + 1
			obj:_cancelTween("Character resetting")
			obj:_stopMovementProtection()
		end, obj.connections)

		fn63(RunService2.Heartbeat, function()
			if obj.destroyed then
				return
			end
			local character = localPlayer2.Character
			local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
			if not humanoidRootPart then
				return
			end
			local assemblyLinearVelocity = humanoidRootPart.AssemblyLinearVelocity
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local walkSpeed = humanoid and humanoid.WalkSpeed or 0
			local vector3 = Vector3.new(assemblyLinearVelocity.X, 0, assemblyLinearVelocity.Z)

			if vector3.Magnitude > math.max(400, walkSpeed * 1.5) or math.abs(assemblyLinearVelocity.Y) > 400 then
				local n51 = math.max(100, walkSpeed)
				local v8 = if vector3.Magnitude > n51 then vector3.Unit * n51 else vector3
				humanoidRootPart.AssemblyLinearVelocity = Vector3.new(v8.X, math.clamp(assemblyLinearVelocity.Y, -100, 100), v8.Z)
			end
		end, obj.connections)

		fn63(localPlayer2.CharacterAdded, function(arg)
			obj:_hideTreadmillDecoy()
			fn67(arg)
			local humanoid = arg:FindFirstChildOfClass("Humanoid")

			if humanoid then
				pcall(function()
					humanoid.BreakJointsOnDeath = false
					humanoid.RequiresNeck = false
					humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
					humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
					humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
				end)
			end

			fn69(obj, arg)

			task.delay(0.25, function()
				if not obj.destroyed and obj.enabled then
					obj:_startMovementProtection()
				end
			end)

			task.delay(1, function()
				if not obj.destroyed and (obj.enabled and obj:_wallOpen()) then
					obj:_schedule()
				end
			end)
		end, obj.connections)

		obj:_installClaimPresentationFilter()

		fn63(EggState2.CarryChanged, function(arg)
			if arg.IsCarrying then
				if obj.running and (obj.activeTarget and arg.Uid == obj.activeTarget.Uid) then
					if obj.carry.active and obj.carry.uid == arg.Uid then
						return
					end

					if obj.instantPhase == "priming" and arg.Uid == obj.primerUid then
						obj.carry.active = true
						obj.carry.uid = arg.Uid
						obj:_clearArrivalHold(arg.Uid)
						obj:_enterBaitWait()
						return
					end

					obj.carry.generation += 1
					obj:_invalidateCarryWorker()
					obj:_clearArrivalHold(arg.Uid)
					obj.claimPresentationSuppression = {assetCategory = obj.activeTarget.AssetCategory, expiresAt = os.clock() + 8}
					obj.carry.active = true
					obj.carry.uid = arg.Uid
					obj.carryStartTime = os.clock()
					obj.carryStartPos = obj.activeTarget and obj.activeTarget.BottomCFrame and obj.activeTarget.BottomCFrame.Position or localPlayer2.Character and localPlayer2.Character:FindFirstChild("HumanoidRootPart") and localPlayer2.Character.HumanoidRootPart.Position

					if obj.tweenRecoveryUid == arg.Uid then
						obj.tweenRecoveryUid = nil
					end

					if obj.carryTimeouts then
						obj.carryTimeouts[arg.Uid] = nil
					end

					obj.stats.lastResult = "Carry confirmed"
					obj:_notify()
					obj.carryAttemptToken = nil

					if obj.activeTween and obj.activeTween.Cancel then
						pcall(obj.activeTween.Cancel, obj.activeTween)
					end

					task.defer(function()
						if not obj.destroyed and (obj.enabled and (obj.carry.uid == arg.Uid and obj:_hasConfirmedCarry(arg.Uid))) then
							if genv.__FanKunHUBGodMode then
								genv.__FanKunHUBGodMode:stopDefend()
							end

							obj:_returnToSafe()
						end
					end)
				end

				return
			end

			if obj.carry.uid ~= nil and (arg.Uid ~= nil and arg.Uid ~= obj.carry.uid) then
				return
			end
			local uid = arg.Uid or obj.carry.uid or obj.activeTarget and obj.activeTarget.Uid
			local active = obj.carry.active
			obj.carry.generation += 1
			local generation = obj.carry.generation
			obj:_invalidateCarryWorker()

			if obj.activeTween and obj.activeTween.Cancel then
				pcall(obj.activeTween.Cancel, obj.activeTween)
			end

			obj.carry.active = false
			obj.carry.uid = nil

			if genv.__FanKunHUBGodMode then
				genv.__FanKunHUBGodMode:startDefend(uid)
			end

			if obj._captureHoldUid ~= nil and uid == obj._captureHoldUid then
				return
			elseif obj._adminBusyUid ~= nil then
				if uid == obj._adminBusyUid then
					return
				end
			end

			if obj.instantPhase == "priming" then
				if arg.Uid == obj.primerUid then
					obj:_startPrimerTargetHunt()
					return
				elseif uid == obj.primerUid then
					obj:_startPrimerTargetHunt()
					return
				end
			end

			if obj._forestDropInProgress ~= nil and uid == obj._forestDropInProgress then
				return
			end

			if not active then
				return
			end

			if obj.running then
				if not obj.activeTarget then
					return
				end
			else
				return
			end

			local humanoidRootPart = localPlayer2.Character and localPlayer2.Character:FindFirstChild("HumanoidRootPart")

			if humanoidRootPart and obj:_isInSafeArea(humanoidRootPart) then
				obj:_reportStolen()
				obj:_finish("Safe return complete")
				return
			end

			task.delay(n40, function()
				if obj.destroyed then
					return
				elseif obj.enabled then
					if obj.carry.active then
						return
					elseif obj.carry.generation ~= generation then
						return
					end
				else
					return
				end

				local humanoidRootPart2 = localPlayer2.Character and localPlayer2.Character:FindFirstChild("HumanoidRootPart")

				if humanoidRootPart2 and obj:_isInSafeArea(humanoidRootPart2) then
					obj:_reportStolen()
					obj:_finish("Safe return complete")
					return
				end

				obj:_reStealDroppedEgg(uid)
			end)
		end, obj.connections)

		fn63(localPlayer2:GetAttributeChangedSignal("RagdollEndTime"), function()
			local attribute = localPlayer2:GetAttribute("RagdollEndTime") or 0

			if obj.instantPhase == "priming" and attribute > workspace:GetServerTimeNow() then
				obj:_startPrimerTargetHunt()
			end
		end, obj.connections)

		fn63(RunService2.Heartbeat, function()
			if obj.destroyed then
				return
			end
			local now = os.clock()
			if now - (obj._espLastTick or 0) < 0.4 then
				return
			end
			obj._espLastTick = now

			local ok, result = pcall(function()
				obj:_updateEsp()
			end)

			if not ok and now - (obj._espErrLast or 0) > 5 then
				obj._espErrLast = now
				warn("[SAE][esp] update error: " .. tostring(result))
			end
		end, obj.connections)

		local status = obj.stats.status
		obj.stats.status = status
		return obj
	end

	index._installClaimPresentationFilter = function(arg)
		return false
	end

	index._restoreClaimPresentationFilter = function(arg)
		local claimPresentationNode = arg.claimPresentationNode
		local claimPresentationOriginal = arg.claimPresentationOriginal

		if type(claimPresentationNode) == "table" and (type(claimPresentationOriginal) == "function" and rawget(claimPresentationNode, "_fn") == arg.claimPresentationWrapper) then
			claimPresentationNode._fn = claimPresentationOriginal
		end

		arg.claimPresentationNode = nil
		arg.claimPresentationOriginal = nil
		arg.claimPresentationWrapper = nil
		arg.claimPresentationSuppression = nil
	end

	index._setStatus = function(arg, status)
		if arg.stats.status == status then
			return
		end

		if type(status) == "string" and string.find(status, "not currently trusted", 1, true) then
			arg._untrustedSeen = true
		end

		arg.stats.status = status
		arg:_notify()
	end

	index._notify = function(arg)
		local v8 = arg:getSnapshot()

		for k in pairs(arg.listeners) do
			local ok, result = pcall(k, v8)

			if not ok then
				warn("[StealAnEgg] UI listener failed:", result)
			end
		end
	end

	index.onChanged = function(arg, arg2)
		arg.listeners[arg2] = true
		local ok, result = pcall(arg2, arg:getSnapshot())

		if not ok then
			warn("[StealAnEgg] UI listener failed:", result)
		end

		return function()
			arg.listeners[arg2] = nil
		end
	end

	index.getSnapshot = function(arg)
		return {status = arg.stats.status, available = arg.stats.available, matching = arg.stats.matching, lastTarget = arg.stats.lastTarget, lastResult = arg.stats.lastResult, wallClosed = arg.resetBlocked or AreaEggResetWall3.IsSealed() or os.clock() < arg.gateOpenAt, enabled = arg.enabled, running = arg.running}
	end

	index._replaceSnapshot = function(arg, arg2)
		table.clear(arg.records)

		for k, v8 in pairs(arg2 and (arg2.Records or arg2) or {}) do
			if type(v8) == "table" and type(v8.Uid) == "string" then
				arg.records[v8.Uid] = v8
			elseif type(k) == "string" then
				if type(v8) == "table" then
					arg.records[k] = v8
				end
			end
		end

		arg:_refreshCounts()
		arg:_schedule()
	end

	index._indexWants = function(arg)
		local now = os.clock()
		local indexCache = arg.indexCache
		if indexCache and now - (indexCache.at or 0) < 2 then
			return indexCache.set
		end
		local tbl16 = {}

		pcall(function()
			local areasDirectory = arg.areasDirectory

			if areasDirectory then
			else
				areasDirectory = require(ReplicatedStorage2.Data.Areas).Directory
				arg.areasDirectory = areasDirectory
			end

			local uid = (Save.Peek or Save.Get)()

			if areasDirectory then
				if not uid then
					return
				end
			else
				return
			end

			local index2 = uid.Index or {}
			local tbl17 = {}

			for k, v8 in pairs(uid.EggInventory or {}) do
				local assetCategory = type(v8) == "table" and (v8.AssetCategory or v8.Category)

				if assetCategory then
					tbl17[tostring(assetCategory)] = true
				end
			end

			uid = arg.carry and arg.carry.uid

			if uid then
				local v8 = arg.records[uid]

				if v8 and v8.AssetCategory then
					tbl17[tostring(v8.AssetCategory)] = true
				end
			end

			for k, v8 in pairs(areasDirectory) do
				if type(v8) == "table" and type(v8.DropTable) == "table" then
					for i, v9 in ipairs(v8.DropTable) do
						uid = v9[1]

						if uid then
							local str9 = tostring(uid)

							if not index2[str9] and not tbl17[str9] then
								tbl16[str9] = true
							end
						end
					end
				end
			end
		end)

		arg.indexCache = {at = now, set = tbl16}
		return tbl16
	end

	index._isIndexObjective = function(arg, arg2)
		if not arg.indexObjectiveEnabled then
			return false
		end

		if type(arg2) ~= "table" then
			return false
		end
		local assetCategory = arg2.AssetCategory

		if assetCategory then
			if assetCategory == "" then
				return false
			end
		else
			return false
		end

		return arg:_indexWants()[tostring(assetCategory)] == true
	end

	index.setIndexObjective = function(arg, arg2)
		local indexObjectiveEnabled = arg2 == true
		if arg.indexObjectiveEnabled == indexObjectiveEnabled then
			return
		end
		arg.indexObjectiveEnabled = indexObjectiveEnabled
		arg.indexCache = {at = 0, set = {}}
		arg:_reconcileRunningState()
	end

	index._isWispObjective = function(arg, arg2)
		local wispObjective = arg.wispObjective

		if type(wispObjective) ~= "table" then
			return false
		elseif type(arg2) ~= "table" then
			return false
		end

		if wispObjective.area and arg2.AreaId ~= wispObjective.area then
			return false
		end

		if wispObjective.rarity then
			local v8 = arg.catalog.resolve(arg2)

			if v8 then
				if v8.rarity ~= wispObjective.rarity then
					return false
				end
			else
				return false
			end
		end

		return true
	end

	index.setWispObjective = function(arg, arg2)
		local wispObjectiveKey = type(arg2) == "table" and (arg2.area or "") .. "|" .. (arg2.rarity or "") or nil
		if arg.wispObjectiveKey == wispObjectiveKey then
			return
		end
		arg.wispObjectiveKey = wispObjectiveKey
		arg.wispObjective = wispObjectiveKey and arg2 or nil
		arg:_reconcileRunningState()
	end

	index.indexMissingCount = function(arg)
		local n51 = 0

		for k in pairs(arg:_indexWants()) do
			n51 += 1
		end

		return n51
	end

	index._matchesNormalFilter = function(arg, arg2)
		local minWeightKg = arg.catalog.resolve(arg2)
		local config = arg.config

		if config.rarityEnabled then
			if #config.rarities == 0 then
				return false
			elseif not fn65(config.rarities, minWeightKg.rarity) then
				return false
			end
		end

		if config.nameEnabled then
			if #config.names == 0 then
				return false
			elseif not fn65(config.names, minWeightKg.name) then
				if not fn65(config.names, minWeightKg.category) then
					return false
				end
			end
		end

		if config.areaEnabled then
			if #config.areas == 0 then
				return false
			elseif not fn65(config.areas, arg2.AreaId) then
				return false
			end
		end

		if config.mutationEnabled and not fn85(arg2, config.mutations) then
			return false
		end
		minWeightKg = config.minWeightKg

		if minWeightKg and minWeightKg > 0 then
			local v8 = arg:_resolveWeightKg(arg2)

			if v8 then
				if v8 < config.minWeightKg then
					return false
				end
			else
				return false
			end
		end

		local minValuePerSec = config.minValuePerSec

		if minValuePerSec and minValuePerSec > 0 then
			local v8 = fn66(arg2)

			if v8 then
				if v8 < config.minValuePerSec then
					return false
				end
			else
				return false
			end
		end

		return true
	end

	index._matches = function(arg, arg2)
		if arg2.State ~= AreaEggs.States.Slot and arg2.State ~= AreaEggs.States.Dropped then
			return false
		end

		if arg:_isManualKeep(arg2.Uid) then
			return true
		end

		if arg.riftWants[arg2.AssetCategory] then
			return true
		end

		if arg.indexObjectiveEnabled and arg:_isIndexObjective(arg2) then
			return true
		end

		if arg.wispObjective and arg:_isWispObjective(arg2) then
			return true
		end

		if arg.userStealEnabled and (not arg.riftOnly and arg:_matchesNormalFilter(arg2)) then
			return true
		end
		return false
	end

	index.setScrambleWants = function(arg, arg2, arg3)
		local riftWants = {}

		for i, v8 in ipairs(type(arg2) == "table" and arg2 or {}) do
			if type(v8) == "string" and v8 ~= "" then
				riftWants[v8] = true
			end
		end

		local riftOnly = arg3 == true
		arg3 = riftOnly ~= arg.riftOnly

		for k in pairs(riftWants) do
			arg3 = if arg.riftWants[k] then arg3 else true
		end

		for k in pairs(arg.riftWants) do
			arg3 = if riftWants[k] then arg3 else true
		end

		if not arg3 then
			return
		end
		arg.riftWants = riftWants
		arg.riftOnly = riftOnly
		arg:_reconcileRunningState()
	end

	index._refreshCounts = function(arg)
		local available = 0
		local matching = 0

		for k, record in pairs(arg.records) do
			if record.State == AreaEggs.States.Slot then
				available, matching = available + 1, if arg:_matches(record) then matching + 1 else matching
			end
		end

		arg.stats.available = available
		arg.stats.matching = matching
		arg:_notify()
	end

	index.hasPriorityRareEgg = function(arg)
		local humanoidRootPart, v8, v9, v10 = localPlayer2.Character and localPlayer2.Character:FindFirstChild("HumanoidRootPart")

		for k, v11 in pairs(arg.records or {}) do
			if (v11.State == AreaEggs.States.Slot or v11.State == AreaEggs.States.Dropped) and v11.BottomCFrame then
				if arg:isSkippedEgg(v11.Uid) then
				else
					if arg:_matchesNormalFilter(v11) then
						local v12 = arg.catalog.resolve(v11)

						if tbl11[v12.rarity] then
							local magnitude = humanoidRootPart and (v11.BottomCFrame.Position - humanoidRootPart.Position).Magnitude or 0
							local rarityRank = v12.rarityRank or 0

							if v8 then
								if rarityRank > v9 then
									v8 = v11
									v9 = rarityRank
									v10 = magnitude
								else
									if rarityRank == v9 and magnitude < v10 then
										v8 = v11
										v9 = rarityRank
										v10 = magnitude
									end
								end
							else
								v8 = v11
								v9 = rarityRank
								v10 = magnitude
							end
						end
					end
				end
			end
		end

		return v8 ~= nil, v8
	end

	local str9 = "Event_CaptureTheEggUid"
	local n51 = 110

	index.isSkippedEgg = function(arg, arg2)
		if arg2 ~= nil and (arg2 == workspace:GetAttribute(str9) and not arg.captureObjectiveEnabled) then
			return true
		end
		local v8 = arg2 and arg.skippedEggs[arg2]
		if not v8 then
			return false
		end

		if os.clock() < v8 then
			return true
		end
		arg.skippedEggs[arg2] = nil
		return false
	end

	index._isCaptureEgg = function(arg, arg2)
		return arg2 ~= nil and arg2 == workspace:GetAttribute(str9)
	end

	index.setCaptureObjective = function(arg, arg2)
		local flag5 = arg2 == true
		if arg.captureObjectiveEnabled == flag5 then
			return
		end

		if flag5 then
			arg._modeBeforeCapture = {arg.config.stealMode, arg.config.flyAerial, arg.config.flyZigzag}
			arg:setStealMode("Instant", false, false)
			arg.captureObjectiveEnabled = true
		else
			arg.captureObjectiveEnabled = false
			local modeBeforeCapture = arg._modeBeforeCapture
			arg._modeBeforeCapture = nil

			if modeBeforeCapture then
				arg:setStealMode(modeBeforeCapture[1], modeBeforeCapture[2], modeBeforeCapture[3])
			end
		end

		arg:_reconcileRunningState()
	end

	index._captureHold = function(arg, captureHoldUid)
		if arg._captureHoldUid == captureHoldUid then
			return
		end
		arg._captureHoldUid = captureHoldUid

		local function fn87()
			local v8 = EggState2.ReadFieldEgg(captureHoldUid)
			return v8 ~= nil and v8.State == AreaEggs.States.Carried and v8.CarrierUserId == localPlayer2.UserId
		end

		local function fn88()
			local destroyed = arg.destroyed
			return (if destroyed then not destroyed else arg.enabled) and arg.captureObjectiveEnabled and fn87()
		end

		task.spawn(function()
			arg:_clearArrivalHold(captureHoldUid)
			arg:_hideTreadmillDecoy()

			pcall(function()
				arg:_stopHoverPad()
			end)

			arg.stats.lastResult = "Holding capture egg"
			arg:_setStatus("Holding capture egg")
			local character = localPlayer2.Character
			local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
			local cFrame = humanoidRootPart and CFrame.new(humanoidRootPart.Position.X, n51, humanoidRootPart.Position.Z) * humanoidRootPart.CFrame.Rotation

			if cFrame then
				arg:_glideRoot(cFrame, function()
					return not fn88()
				end)
			end

			while fn88() do
				local character2 = localPlayer2.Character
				local humanoidRootPart2 = character2 and character2:FindFirstChild("HumanoidRootPart")
				local humanoid = character2 and character2:FindFirstChildOfClass("Humanoid")

				if humanoidRootPart2 and humanoid and cFrame then
					pcall(function()
						humanoidRootPart2.CFrame = cFrame
						humanoidRootPart2.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
						humanoidRootPart2.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
					end)

					arg:_syncHoverPad(cFrame.Position)
					local n52 = math.clamp(arg.config.speed or n15, n13, fn61())

					pcall(function()
						fn74(character2, n52 * n44)
						fn83(humanoid, humanoidRootPart2, n52, (Vector3.new(0, 0, 0)))
					end)
				end

				task.wait(0.1)
			end

			pcall(function()
				arg:_stopHoverPad()
			end)

			if arg._captureHoldUid == captureHoldUid then
				arg._captureHoldUid = nil
			end

			if arg.destroyed then
				return
			elseif not arg.enabled then
				return
			end

			arg:_finish(arg.captureObjectiveEnabled and "Capture egg lost \226\128\148 re-grabbing" or "Capture stopped")
		end)
	end

	index._chooseTarget = function(arg)
		local humanoidRootPart = localPlayer2.Character and localPlayer2.Character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then
			return nil
		end

		if arg.captureObjectiveEnabled then
			local attribute = workspace:GetAttribute(str9)
			local v8 = attribute and (EggState2.ReadFieldEgg(attribute) or arg.records[attribute])

			if type(v8) == "table" and v8.BottomCFrame then
				if v8.State == AreaEggs.States.Slot then
					return v8
				elseif v8.State == AreaEggs.States.Dropped then
					return v8
				end
			end
		end

		if arg.manualObjectiveEnabled then
			local v8 = arg:_takeManualTarget()
			if v8 then
				return v8
			end
		end

		if arg.userStealEnabled and not arg.riftOnly then
			local v8, v9 = arg:hasPriorityRareEgg()
			if v8 and v9 then
				return v9
			end
		end

		local v8, v9, v10, v11, v12, v13

		for k, record in pairs(arg.records) do
			if (record.State == AreaEggs.States.Slot or record.State == AreaEggs.States.Dropped) and record.BottomCFrame then
				if arg:isSkippedEgg(record.Uid) then
				else
					local magnitude = (record.BottomCFrame.Position - humanoidRootPart.Position).Magnitude

					if arg.riftWants[record.AssetCategory] then
						if v8 then
							if magnitude < v9 then
								v8 = record
								v9 = magnitude
							end
						else
							v8 = record
							v9 = magnitude
						end
					else
						if arg.wispObjective and arg:_isWispObjective(record) then
							if v10 then
								if magnitude < v11 then
									v10 = record
									v11 = magnitude
								end
							else
								v10 = record
								v11 = magnitude
							end
						else
							if arg.indexObjectiveEnabled and arg:_isIndexObjective(record) then
								if v12 then
									if magnitude < v13 then
										v12 = record
										v13 = magnitude
									end
								else
									v12 = record
									v13 = magnitude
								end
							end
						end
					end
				end
			end
		end

		if v8 or v10 or v12 then
			return v8 or v10 or v12
		end

		if arg.userStealEnabled and not arg.riftOnly then
			local v14, v15, v16

			for k, record in pairs(arg.records) do
				if record.State == AreaEggs.States.Slot or record.State == AreaEggs.States.Dropped then
					local v17 = arg:isSkippedEgg(record.Uid)

					if if v17 then not v17 else arg:_matchesNormalFilter(record) then
						local magnitude = (record.BottomCFrame.Position - humanoidRootPart.Position).Magnitude
						local v18 = arg.catalog.resolve(record)
						local v19 = if arg.config.highestValueFirst then fn66(record) or -1 / 0 else if arg.config.heaviestFirst then arg:_resolveWeightKg(record) or -1 / 0 else v18.rarityRank or 0

						if v14 then
							if v19 > v15 then
								v14 = record
								v15 = v19
								v16 = magnitude
							else
								if v19 == v15 and magnitude < v16 then
									v14 = record
									v15 = v19
									v16 = magnitude
								end
							end
						else
							v14 = record
							v15 = v19
							v16 = magnitude
						end
					end
				end
			end

			if v14 then
				return v14
			end
		end

		return nil
	end

	index._takeManualTarget = function(arg)
		local tbl16 = {}
		local manualOrder = {}

		for i, v8 in ipairs(arg.manualOrder) do
			local v9 = arg.records[v8]

			if v9 then
				if v9.State == AreaEggs.States.Slot then
					manualOrder[#manualOrder + 1] = v8
					tbl16[v8] = true
				elseif v9.State == AreaEggs.States.Dropped then
					manualOrder[#manualOrder + 1] = v8
					tbl16[v8] = true
				end
			end
		end

		arg.manualOrder = manualOrder

		for k in pairs(arg.manualQueue) do
			if not tbl16[k] then
				arg.manualQueue[k] = nil
			end
		end

		if #manualOrder == 0 then
			if arg.manualObjectiveEnabled then
				arg.manualObjectiveEnabled = false

				task.defer(function()
					if not arg.destroyed then
						arg:_reconcileRunningState()
					end
				end)
			end

			return nil
		end

		return arg.records[manualOrder[1]]
	end

	index.queueManual = function(arg, arg2)
		if type(arg2) ~= "table" then
			return 0
		end

		for i, v8 in ipairs(arg2) do
			if v8 ~= nil then
				arg.manualKeep = arg.manualKeep or {}
				arg.manualKeep[v8] = os.clock() + 180
			end

			if v8 ~= nil and not arg.manualQueue[v8] then
				arg.manualQueue[v8] = true
				arg.manualOrder[#arg.manualOrder + 1] = v8
			end
		end

		local n52 = #arg.manualOrder

		if n52 > 0 then
			arg.manualObjectiveEnabled = true
		end

		arg:_reconcileRunningState()
		return n52
	end

	index.clearManual = function(arg)
		arg.manualKeep = {}
		arg.manualQueue = {}
		arg.manualOrder = {}
		arg.manualObjectiveEnabled = false
		arg:_reconcileRunningState()
	end

	index._isManualKeep = function(arg, uid)
		local keep = arg.manualKeep
		local expires = keep and uid ~= nil and keep[uid]

		if not expires then
			return false
		end

		if os.clock() > expires then
			keep[uid] = nil
			return false
		end

		return true
	end

	index.stealNow = function(arg, uid)
		if uid == nil then
			return
		end

		arg.manualQueue = {[uid] = true}
		arg.manualOrder = {uid}
		arg.manualKeep = {[uid] = os.clock() + 180}
		arg.manualObjectiveEnabled = true

		local active = arg.activeTarget
		if arg.running and not arg.carry.active and active and active.Uid ~= uid then
			arg.planGeneration = arg.planGeneration + 1
			arg:_cancelTween("Switching target")
			arg:_releaseOperation()
			arg.running = false
			arg.safeStarting = false
			arg.activeTarget = nil
		end

		arg:_reconcileRunningState()
	end

	index.manualPending = function(arg)
		return #arg.manualOrder
	end

	index.setTreadmillManager = function(arg, treadmillManager)
		arg.treadmillManager = treadmillManager
	end

	index.getStealMode = function(arg)
		return arg.config.stealMode == "Fly" and "Fly" or "Instant"
	end

	index.setStealMode = function(arg, arg2, arg3, arg4)
		local stealMode = arg2 == "Fly" and "Fly" or "Instant"
		local flyAerial = stealMode == "Fly" and arg3 == true
		local flyZigzag = stealMode == "Fly" and arg4 == true and not flyAerial

		if arg.config.stealMode ~= stealMode or arg.config.flyAerial ~= flyAerial or arg.config.flyZigzag ~= flyZigzag then
			arg.config.stealMode = stealMode
			arg.config.flyAerial = flyAerial
			arg.config.flyZigzag = flyZigzag

			if arg.enabled then
				arg:_installGuardHitDistanceBoost()
				arg:_finish("Mode changed")
			end
		end

		return stealMode
	end

	local resolveHitDistance
	local n52 = 25

	index._installGuardHitDistanceBoost = function(arg)
		if arg.guardHitBoostInstalled then
			return
		end

		local function fn87()
			local GuardChasePolicy = require(ReplicatedStorage2.Shared.Modules.GuardAreas.GuardChasePolicy)

			if GuardChasePolicy and type(GuardChasePolicy.ResolveHitDistance) == "function" then
				resolveHitDistance = resolveHitDistance or GuardChasePolicy.ResolveHitDistance
				local v8 = arg

				GuardChasePolicy.ResolveHitDistance = function(arg2)
					if v8.enabled and v8.instantPhase == "priming" then
						return n52
					end

					if v8.enabled then
						return -1 / 0
					elseif v8._recalling then
						return -1 / 0
					end

					return resolveHitDistance and resolveHitDistance(arg2) or (arg2 or 10)
				end

				arg.guardHitBoostInstalled = true
			end
		end

		pcall(fn87)
	end

	index._removeGuardHitDistanceBoost = function(arg)
		if not arg.guardHitBoostInstalled then
			return
		end

		pcall(function()
			local GuardChasePolicy = require(ReplicatedStorage2.Shared.Modules.GuardAreas.GuardChasePolicy)

			if GuardChasePolicy and resolveHitDistance then
				GuardChasePolicy.ResolveHitDistance = resolveHitDistance
				arg.guardHitBoostInstalled = false
			end
		end)
	end

	index._setInstantAnchored = function(arg, anchored)
		pcall(function()
			local humanoidRootPart = localPlayer2.Character and localPlayer2.Character:FindFirstChild("HumanoidRootPart")

			if humanoidRootPart and humanoidRootPart.Anchored ~= anchored then
				humanoidRootPart.Anchored = anchored
			end
		end)
	end

	index._kbCancelTimer = function(arg)
		if arg.hitTimer then
			pcall(task.cancel, arg.hitTimer)
			arg.hitTimer = nil
		end
	end

	index._isPrimerEgg = function(arg, arg2)
		if arg2 == nil then
			return false
		end

		if arg2 == arg.primerUid then
			return true
		end
		local primerUids = arg.primerUids and arg.primerUids[arg2]
		if primerUids and primerUids > os.clock() then
			return true
		end

		if primerUids then
			arg.primerUids[arg2] = nil
		end

		return false
	end

	index._cleanupInstantSteal = function(arg)
		arg.instantPhase = nil
		arg.primerUid = nil
		arg.targetUid = nil
		arg._flyDeparting = false
		arg:_stopGuardStick()
		arg:_kbCancelTimer()
		arg:_setInstantAnchored(false)
		arg:_hideTreadmillDecoy()
	end

	index._choosePrimerEgg = function(arg, arg2)
		local guard = fn()
		local areas = guard and guard:FindFirstChild("Areas")
		local guardAreas = areas and areas:FindFirstChild("GuardAreas")
		local forest = guardAreas and guardAreas:FindFirstChild("Forest")
		guard = forest and forest:FindFirstChild("Guard")
		areas = guard and guard:FindFirstChild("HumanoidRootPart")
		local position, v8, v9 = areas and areas.Position

		for k, record in pairs(arg.records) do
			if record.State == AreaEggs.States.Slot and (record.AreaId == "Forest" and record.Uid ~= arg2) then
				if arg:_isCaptureEgg(record.Uid) then
				else
					local magnitude = position and (record.BottomCFrame.Position - position).Magnitude or (localPlayer2.Character and localPlayer2.Character:FindFirstChild("HumanoidRootPart") and (record.BottomCFrame.Position - localPlayer2.Character.HumanoidRootPart.Position).Magnitude or 1 / 0)
					local rarityRank = arg.catalog.resolve(record).rarityRank or 0
					local n53 = -magnitude - rarityRank * 100

					if v8 then
						if n53 > v9 then
							v8 = record
							v9 = n53
						end
					else
						v8 = record
						v9 = n53
					end
				end
			end
		end

		return v8
	end

	local n53 = 2.5
	local n54 = 0.05
	local n55 = 1.5
	local n56 = 18
	local n57 = 0.35

	index._stopGuardStick = function(arg)
		if arg.guardStickConnection then
			pcall(arg.guardStickConnection.Disconnect, arg.guardStickConnection)
			arg.guardStickConnection = nil
		end
	end

	index._startGuardStick = function(arg)
		arg:_stopGuardStick()

		local function fn87()
			local v8 = fn()
			local areas = v8 and v8:FindFirstChild("Areas")
			local guardAreas = areas and areas:FindFirstChild("GuardAreas")
			local forest = guardAreas and guardAreas:FindFirstChild("Forest")
			local guard = forest and forest:FindFirstChild("Guard")
			return guard and guard:FindFirstChild("HumanoidRootPart")
		end

		arg.guardStickConnection = RunService2.PreSimulation:Connect(function()
			if arg.destroyed then
				arg:_stopGuardStick()
				return
			elseif arg.enabled then
				if arg.instantPhase ~= "priming" then
					arg:_stopGuardStick()
					return
				end
			else
				arg:_stopGuardStick()
				return
			end

			local n58 = fn87()
			local character = localPlayer2.Character
			local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")

			if n58 then
				if not humanoidRootPart then
					return
				end
			else
				return
			end

			local position = n58.Position
			local n59 = n58.CFrame.LookVector * n53
			n58 = Vector3.new(position.X + n59.X, humanoidRootPart.Position.Y, position.Z + n59.Z) - humanoidRootPart.Position
			local v8 = if n58.Magnitude > 40 then n58.Unit * 40 else n58
			local n60 = humanoidRootPart.Position + v8
			humanoidRootPart.CFrame = CFrame.lookAt(n60, Vector3.new(position.X, n60.Y, position.Z))
			humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			arg:_syncHoverPad(n60)
		end)
	end

	index._forestGuardModel = function(arg)
		local v8 = fn()
		local areas = v8 and v8:FindFirstChild("Areas")
		local guardAreas = areas and areas:FindFirstChild("GuardAreas")
		local forest = guardAreas and guardAreas:FindFirstChild("Forest")
		return forest and forest:FindFirstChild("Guard")
	end

	index._triggerGuardHit = function(arg)
		local v8 = arg:_forestGuardModel()
		local humanoidRootPart = v8 and v8:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then
			return
		end
		local character = localPlayer2.Character
		local humanoidRootPart2 = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart2 then
			return
		end
		local position = humanoidRootPart.Position
		local n58 = humanoidRootPart.CFrame.LookVector * n53
		local vector3 = Vector3.new(position.X + n58.X, humanoidRootPart2.Position.Y, position.Z + n58.Z)
		arg.guardStrikeAnchor = vector3
		humanoidRootPart2.CFrame = CFrame.lookAt(vector3, Vector3.new(position.X, vector3.Y, position.Z))
		humanoidRootPart2.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		local collider = v8:FindFirstChild("Collider") or humanoidRootPart

		if collider and firetouchinterest then
			pcall(function()
				firetouchinterest(humanoidRootPart2, collider, 0)
				firetouchinterest(humanoidRootPart2, collider, 1)
			end)
		end

		pcall(function()
			local forestStrike = Remotes.GuardPatrol and Remotes.GuardPatrol.ForestStrike

			if forestStrike then
				forestStrike:FireServer({EggUid = arg.primerUid, GuardCFrame = humanoidRootPart.CFrame})
			end
		end)
	end

	index._stopGuardStrike = function(arg)
		arg.guardStrikeGeneration = (arg.guardStrikeGeneration or 0) + 1
	end

	index._knockbackLanded = function(arg)
		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if humanoidRootPart then
			if not humanoid then
				return false
			end
		else
			return false
		end

		if humanoid.PlatformStand then
			return true
		elseif humanoid.Sit then
			return true
		end

		local state = humanoid:GetState()

		if state == Enum.HumanoidStateType.Ragdoll then
			return true
		elseif state == Enum.HumanoidStateType.FallingDown then
			return true
		elseif state == Enum.HumanoidStateType.PlatformStanding then
			return true
		end

		return humanoidRootPart.AssemblyLinearVelocity.Magnitude > n56
	end

	index._settleAfterKnockback = function(arg)
		local guardStrikeAnchor = arg.guardStrikeAnchor
		local n58 = os.clock() + n57

		while os.clock() < n58 and not arg.destroyed do
			local character = localPlayer2.Character
			local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
			if not humanoidRootPart then
				return
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")

			if humanoid then
				pcall(function()
					humanoid.PlatformStand = false
					humanoid.Sit = false
					humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
				end)
			end

			if guardStrikeAnchor then
				humanoidRootPart.CFrame = CFrame.new(guardStrikeAnchor)
			end

			humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			arg:_syncHoverPad(guardStrikeAnchor or humanoidRootPart.Position)
			RunService2.Heartbeat:Wait()
		end
	end

	index._startGuardStrike = function(arg)
		arg:_stopGuardStrike()
		local guardStrikeGeneration = arg.guardStrikeGeneration

		task.spawn(function()
			local n58 = os.clock() + n55

			while true do
				local destroyed = arg.destroyed
				if not ((if destroyed then not destroyed else arg.enabled) and arg.instantPhase == "priming" and arg.guardStrikeGeneration == guardStrikeGeneration and os.clock() < n58) then
					break
				end
				arg:_triggerGuardHit()
				local n59 = os.clock() + n54
				local flag5 = false

				while os.clock() < n59 do
					if arg:_knockbackLanded() then
						flag5 = true
						break
					end
					RunService2.Heartbeat:Wait()
				end

				if flag5 then
					break
				end
			end

			if arg.guardStrikeGeneration == guardStrikeGeneration then
				arg:_stopGuardStick()
				arg:_settleAfterKnockback()
			end
		end)
	end

	index._enterBaitWait = function(arg)
		arg:_setInstantAnchored(false)
		arg:_setStatus("Preparing steal")
		arg:_startGuardStick()
		arg:_startGuardStrike()
		if arg.hitTimer then
			return
		end

		arg.hitTimer = task.delay(n55 + 0.3, function()
			arg.hitTimer = nil

			if arg.destroyed then
				return
			elseif not arg.enabled then
				return
			end

			if arg.instantPhase ~= "priming" then
				return
			end
			arg:_stopGuardStick()
			arg:_stopGuardStrike()

			if arg.carry.active and arg:_isPrimerEgg(arg.carry.uid) then
				pcall(EggState2.DropFieldEgg, "PlayerRequest")
			end

			arg:_finish("Steal timed out \226\128\148 retrying")
		end)
	end

	local function fn87(arg, arg2)
		local str10 = tostring(arg or ""):lower()
		local n58 = 8
		local n59 = 3.5

		if str10:find("enchanted") then
			n58 = 18
			n59 = 12
		else
			if str10:find("light") then
				local n60 = 16
				local n61 = 10
				n58 = n60
				n59 = n61
			else
				if str10:find("dark") then
					local n60 = 16
					local n61 = 10
					n58 = n60
					n59 = n61
				else
					if str10:find("titan") then
						local n60 = 10
						local n61 = 8
						n58 = n60
						n59 = n61
					else
						if str10:find("cosmic") then
							local n60 = 10
							local n61 = 8
							n58 = n60
							n59 = n61
						else
							if str10:find("cherry") then
								local n60 = 10
								local n61 = 8
								n58 = n60
								n59 = n61
							end
						end
					end
				end
			end
		end

		return math.max(n59, n58 * ((11 - math.clamp(arg2, 1, 10)) / 6))
	end

	index._resolveSettleSeconds = function(arg, arg2)
		local n58 = math.clamp(tonumber(fanKunHubConfig.StealHoldSeconds) or 5, 1, 10)
		local flag5 = arg.settleBonus and type(arg2) == "table" and arg.settleBonus[arg2.Uid]
		local seconds = flag5 and flag5.untilAt > os.clock() and flag5.seconds or 0
		local v8 = fn3()
		seconds = if v8 > 0 then if v8 < 12 then seconds + 2 else seconds else seconds
		local v9 = if genv.__FanKunHUBNetPing() > 300 then seconds + 1 else seconds
		return fn87(type(arg2) == "table" and arg2.AreaId, n58) + v9
	end

	index._startPrimerTargetHunt = function(arg)
		if arg.instantPhase ~= "priming" then
			return
		end
		arg:_stopGuardStick()
		arg:_stopGuardStrike()

		pcall(function()
			local character = localPlayer2.Character
			local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")

			if humanoid then
				humanoid.PlatformStand = false
				humanoid.Sit = false
			end

			if humanoidRootPart then
				if arg.guardStrikeAnchor then
					humanoidRootPart.CFrame = CFrame.new(arg.guardStrikeAnchor)
				end

				humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			end
		end)

		arg:_kbCancelTimer()
		arg:_setInstantAnchored(false)
		arg.instantPhase = "hunting"
		arg:_clearArrivalHold()
		arg.carry.generation += 1
		arg:_invalidateCarryWorker()
		arg.carry.active = false
		arg.carry.uid = nil
		local targetUid = arg.targetUid
		arg.targetUid = nil
		if not targetUid then
			arg:_finish("No target egg")
			return
		end
		local v8 = EggState2.ReadFieldEgg(targetUid) or arg.records[targetUid]
		if not v8 or v8.State ~= AreaEggs.States.Slot and v8.State ~= AreaEggs.States.Dropped then
			arg:_finish("Target egg no longer available")
			return
		end
		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if humanoidRootPart then
			if not humanoid then
				arg:_finish("Character unavailable")
				return
			end
		else
			arg:_finish("Character unavailable")
			return
		end

		arg.activeTarget = v8
		local v9 = arg:_resolveEggDestination(v8, humanoidRootPart, humanoid)
		if not v9 then
			arg:_finish("Target destination unavailable")
			return
		end

		if arg.config.stealMode == "Fly" then
			local uid = v8.Uid

			local function fn88()
				return arg.destroyed or not arg.enabled or arg.instantPhase ~= "hunting" or not arg.activeTarget or arg.activeTarget.Uid ~= uid
			end

			if arg.config.flyAerial then
				arg:_setStatus("Heading to target egg")
				arg:_startFlyGrounding()
				local v10 = arg:_flyWalkTo(v9, fn88, 8, 110)
				arg:_stopFlyGrounding()

				if not v10 then
					if not fn88() then
						arg:_finish("Could not reach the egg \226\128\148 retrying")
					end

					return
				end
			elseif arg.config.flyZigzag then
				arg:_setStatus("Heading to target egg")

				if not arg:_walkToZigzag(v9, fn88) then
					if not fn88() then
						arg:_finish("Zig-zag walk to target failed")
					end

					return
				end
			else
				arg:_setStatus("Heading to target egg")

				if not arg:_walkTo(v9, fn88) then
					if not fn88() then
						arg:_finish("Walk to target failed")
					end

					return
				end
			end

			if fn88() then
				return
			end
			arg:_glideRoot(v9, fn88, arg:_legitWalkSpeed())
			if fn88() then
				return
			end
			arg:_setArrivalHold(v9, uid)
			arg:_setStatus("Securing target egg")
			arg:_requestCarry(v8, true)
			return
		end

		if arg.config.stealMode == "Instant" then
			local uid = v8.Uid

			local function fn88()
				return arg.destroyed or not arg.enabled or arg.instantPhase ~= "hunting" or not arg.activeTarget or arg.activeTarget.Uid ~= uid
			end

			local n58 = v9 + Vector3.new(0, n25, 0)
			arg:_setStatus("Heading to target egg")

			if not arg:_glideRoot(n58, fn88) then
				if not fn88() then
					arg:_finish("Could not reach the egg \226\128\148 retrying")
				end

				return
			end

			task.spawn(arg._hoverSettleCarry, arg, v8, v9, n58, fn88)
			return
		end

		arg:_setStatus("Heading to target egg")

		arg:_tweenRoot(v9, function()
			if arg.instantPhase == "hunting" and (arg.activeTarget and arg.activeTarget.Uid == v8.Uid) then
				arg:_requestCarry(v8, false)
			end
		end, nil, {holdAfterArrival = true, holdUid = v8.Uid, flightProfile = true, carryTarget = v8})
	end

	index._hoverSettleCarry = function(arg, arg2, arg3, cFrame, arg4)
		arg:_startHoverPad()
		local v8 = arg:_resolveSettleSeconds(arg2)
		local n58 = os.clock() + v8

		while os.clock() < n58 do
			if arg4() then
				return
			end
			arg:_setStatus(string.format("Securing target egg (%.1fs)", math.max(0, n58 - os.clock())))
			local character = localPlayer2.Character
			local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")

			if humanoidRootPart and humanoid then
				pcall(function()
					humanoidRootPart.CFrame = cFrame
					humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
				end)

				arg:_syncHoverPad(cFrame.Position)
				local n59 = math.clamp(arg.config.speed or n15, n13, fn61())

				pcall(function()
					fn74(character, n59 * n44)
					fn83(humanoid, humanoidRootPart, n59, (Vector3.new(0, 0, 0)))
				end)
			end

			task.wait(0.1)
		end

		if arg4() then
			return
		end
		arg:_glideRoot(arg3, arg4)
		if arg4() then
			return
		end
		arg:_setArrivalHold(arg3, arg2.Uid)
		arg:_setStatus("Securing target egg")
		arg:_requestCarry(arg2, true)
	end

	index._wallOpen = function(arg)
		if arg.resetBlocked then
			return false
		elseif AreaEggResetWall3.IsSealed() then
			return false
		elseif os.clock() < arg.gateOpenAt then
			return false
		end

		local v8 = fn()
		local areas = v8 and v8:FindFirstChild("Areas")
		local wallStartCollision = areas and areas:FindFirstChild("WallStartCollision")
		if wallStartCollision and (wallStartCollision:IsA("BasePart") and wallStartCollision.CanCollide) then
			return false
		end
		return true
	end

	index._closeGate = function(arg, arg2)
		arg.resetBlocked = true
		arg.gateOpenAt = 1 / 0
		arg.safeStarting = false

		if arg.activeTween then
			if not arg.activeTween.sharedTravel then
				arg:_cancelTween(arg2)
			end
		else
			arg:_cancelTween(arg2)
		end

		arg:_setStatus(arg2)
	end

	index._releaseOperation = function(arg)
		local operationToken = arg.operationToken
		arg.operationToken = nil

		if operationToken and arg.coordinator then
			arg.coordinator:release(operationToken)
		end
	end

	index._acquireOperation = function(arg)
		if arg.operationToken then
			return true
		elseif not arg.coordinator then
			return true
		end

		local autoSteal, v8 = arg.coordinator:tryAcquire("auto_steal", {})
		if not autoSteal then
			return false, v8
		end
		arg.operationToken = autoSteal
		return true
	end

	index._cancelTween = function(arg, lastResult, arg2)
		arg:_cleanupInstantSteal()
		arg.carryAttemptToken = nil
		arg:_clearArrivalHold()
		arg.safeStarting = false

		if arg.activeTween then
			pcall(arg.activeTween.Cancel, arg.activeTween)
			arg.activeTween = nil
		end

		if not arg.activeTween and not arg.arrivalHold then
			arg:_stopHoverPad()
		end

		if arg.running then
			arg.running = false
			arg.activeTarget = nil
			arg.stats.lastResult = lastResult
			arg:_notify()
		end

		if not arg2 then
			arg:_releaseOperation()
		end
	end

	index._groundYAt = function(arg, arg2, arg3, arg4)
		local character = arg4 or localPlayer2.Character
		local vector3 = Vector3.new(arg2, (character and character:FindFirstChild("HumanoidRootPart") and character.HumanoidRootPart.Position.Y or vector2.Y) + 60, arg3)
		local filterDescendantsInstances = {}

		if character then
			table.insert(filterDescendantsInstances, character)
		end

		if arg.hoverPad then
			table.insert(filterDescendantsInstances, arg.hoverPad)
		end

		if arg.treadmillDecoy then
			table.insert(filterDescendantsInstances, arg.treadmillDecoy)
		end

		for i, child in ipairs(workspace:GetChildren()) do
			if child.Name == name2 then
				table.insert(filterDescendantsInstances, child)
			elseif child.Name == name3 then
				table.insert(filterDescendantsInstances, child)
			end
		end

		for i = 1, 10, 1 do
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude
			raycastParams.FilterDescendantsInstances = filterDescendantsInstances
			raycastParams.IgnoreWater = true
			local hit = workspace:Raycast(vector3, Vector3.new(0, -300, 0), raycastParams)
			if not hit then
				return nil
			end

			if hit.Instance.CanCollide then
				return hit.Position.Y
			end
			table.insert(filterDescendantsInstances, hit.Instance)
		end

		return nil
	end

	index._resolveSafeCFrame = function(arg, arg2)
		if not arg2 then
			return nil
		end
		local x = vector2.X
		local z = vector2.Z
		local y = vector2.Y
		local v8 = arg:_groundYAt(x, z, arg2.Parent)
		local v9 = if v8 then v8 + 3.2 else y
		return CFrame.new(x, v9, z) * arg2.CFrame.Rotation
	end

	index._groundSnap = function(arg)
		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoidRootPart or not humanoid then
			return false
		end
		local position = humanoidRootPart.Position
		local v8 = arg:_groundYAt(position.X, position.Z, character)
		if not v8 then
			return false
		end
		local n58 = v8 + arg:_feetOffset(humanoidRootPart, humanoid)

		if position.Y < n58 - 0.25 or position.Y > n58 + 8 then
			pcall(function()
				arg:_syncHoverPad(Vector3.new(position.X, n58, position.Z))
				humanoidRootPart.CFrame = CFrame.new(position.X, n58, position.Z) * humanoidRootPart.CFrame.Rotation
				humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			end)

			return true
		end

		return false
	end

	local function fn88(arg)
		if typeof(arg) == "Instance" and arg:IsA("Trail") then
			pcall(arg.Destroy, arg)
		end
	end

	local function fn89(arg)
		if typeof(arg) == "Instance" then
			if arg.Name == "SpeedGainPopup" then
				pcall(arg.Destroy, arg)
			elseif arg.Name == "PlusOne" then
				pcall(arg.Destroy, arg)
			end
		end
	end

	local SAFE_MARKER_NAME = "__FanKunHUBSafeMarker"

	index._showSafeMarker = function(arg)
		if arg.safeMarker and arg.safeMarker.Parent then
			return
		end
		for _, child in ipairs(workspace:GetChildren()) do
			if child.Name == SAFE_MARKER_NAME then
				pcall(child.Destroy, child)
			end
		end
		local part = Instance.new("Part")
		part.Name = SAFE_MARKER_NAME
		part.Shape = Enum.PartType.Cylinder
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(94, 160, 255)
		part.Transparency = 0.35
		part.Size = Vector3.new(0.25, 7, 7)
		-- cylinder berdiri rebah: putar agar menjadi cincin datar di lantai zona aman
		local groundY = arg:_groundYAt(vector2.X, vector2.Z) or (vector2.Y - 3)
		part.CFrame = CFrame.new(vector2.X, groundY + 0.15, vector2.Z) * CFrame.Angles(0, 0, math.rad(90))
		part.Parent = workspace
		arg.safeMarker = part

		local beacon = Instance.new("Attachment")
		beacon.Parent = part
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(14, 14)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
		billboard.AlwaysOnTop = true
		billboard.Adornee = part
		billboard.Parent = part
		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromScale(1, 1)
		dot.BackgroundColor3 = Color3.fromRGB(94, 160, 255)
		dot.BorderSizePixel = 0
		dot.Parent = billboard
		Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
		local dotStroke = Instance.new("UIStroke", dot)
		dotStroke.Color = Color3.new(1, 1, 1)
		dotStroke.Thickness = 2
	end

	index._hideSafeMarker = function(arg)
		if arg.safeMarker then
			pcall(arg.safeMarker.Destroy, arg.safeMarker)
			arg.safeMarker = nil
		end
		for _, child in ipairs(workspace:GetChildren()) do
			if child.Name == SAFE_MARKER_NAME then
				pcall(child.Destroy, child)
			end
		end
	end

	-- Mengembalikan tampilan & kontrol karakter asli ke normal (fix visual aneh setelah steal)
	index._restoreCharacterVisual = function(arg)
		local character = localPlayer2.Character
		if not character then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		for _, descendant in ipairs(character:GetDescendants()) do
			if descendant:IsA("BasePart") then
				pcall(function()
					descendant.LocalTransparencyModifier = 0
				end)
			end
		end
		local animate = character:FindFirstChild("Animate")
		if animate then
			pcall(function()
				animate.Disabled = false
			end)
		end
		if humanoid then
			pcall(function()
				humanoid.AutoRotate = true
				humanoid.PlatformStand = false
				humanoid.Sit = false
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
				if humanoid:GetState() ~= Enum.HumanoidStateType.Running then
					humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
				end
			end)
		end
		if root then
			pcall(function()
				if root.Anchored then
					root.Anchored = false
				end
				root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			end)
		end
		local camera = workspace.CurrentCamera
		if camera and humanoid then
			pcall(function()
				camera.CameraSubject = humanoid
				if camera.CameraType ~= Enum.CameraType.Custom then
					camera.CameraType = Enum.CameraType.Custom
				end
			end)
		end
	end

	index._showTreadmillDecoy = function(arg)
		if arg.treadmillDecoy and arg.treadmillDecoy.Parent then
			return true
		end
		arg:_hideTreadmillDecoy()
		local character = localPlayer2.Character
		if not character then
			return false
		end
		local archivable = character.Archivable
		character.Archivable = true
		local ok, treadmillDecoy = pcall(character.Clone, character)
		character.Archivable = archivable

		if ok then
			if not treadmillDecoy then
				return false
			elseif typeof(treadmillDecoy) ~= "Instance" then
				return false
			end
		else
			return false
		end

		treadmillDecoy.Name = name3

		for i, descendant in ipairs(treadmillDecoy:GetDescendants()) do
			if tbl14[descendant.ClassName] then
				pcall(descendant.Destroy, descendant)
			elseif descendant:IsA("Trail") then
				pcall(descendant.Destroy, descendant)
			elseif descendant:IsA("BasePart") then
				descendant.LocalTransparencyModifier = 0
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
			end
		end

		local humanoidRootPart = treadmillDecoy:FindFirstChild("HumanoidRootPart")
		local humanoid = treadmillDecoy:FindFirstChildOfClass("Humanoid")

		if humanoidRootPart then
			if not humanoid then
				treadmillDecoy:Destroy()
				return false
			end
		else
			treadmillDecoy:Destroy()
			return false
		end

		pcall(function()
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end)

		treadmillDecoy.Parent = workspace
		treadmillDecoy:PivotTo(CFrame.new(vector2))
		arg.treadmillDecoy = treadmillDecoy
		pcall(arg._showSafeMarker, arg)
		local playerGui = localPlayer2:FindFirstChildOfClass("PlayerGui")

		if playerGui then
			for i, descendant in ipairs(playerGui:GetDescendants()) do
				if descendant.Name == "SpeedGainPopup" then
					fn89(descendant)
				elseif descendant.Name == "PlusOne" then
					fn89(descendant)
				end
			end

			arg.treadmillPopupConnection = playerGui.DescendantAdded:Connect(function(descendant)
				if arg.treadmillDecoy == treadmillDecoy then
					fn89(descendant)
				end
			end)
		end

		local treadmillDecoyRealTransparency = setmetatable({}, {__mode = "k"})

		local function fn90(arg2)
			if arg2 then
				if arg2:IsA("BasePart") then
					if not arg2:IsDescendantOf(character) then
						return
					end
				else
					return
				end
			else
				return
			end

			if treadmillDecoyRealTransparency[arg2] == nil then
				treadmillDecoyRealTransparency[arg2] = 0
			end

			arg2.LocalTransparencyModifier = 1
		end

		for i, descendant in ipairs(character:GetDescendants()) do
			fn90(descendant)
			fn88(descendant)
		end

		arg.treadmillDecoyRealTransparency = treadmillDecoyRealTransparency

		arg.treadmillDecoyCharacterConnection = character.DescendantAdded:Connect(function(descendant)
			if arg.treadmillDecoy == treadmillDecoy then
				pcall(fn90, descendant)
				fn88(descendant)
			end
		end)

		local currentCamera = workspace.CurrentCamera

		if currentCamera then
			arg.treadmillDecoyCamera = currentCamera.CameraSubject
			currentCamera.CameraSubject = humanoid
		end

		arg.treadmillDecoyCameraConnection = RunService2.RenderStepped:Connect(function()
			if arg.treadmillDecoy ~= treadmillDecoy then
				return
			elseif treadmillDecoy.Parent then
				if not humanoid.Parent then
					return
				end
			else
				return
			end

			for k in pairs(treadmillDecoyRealTransparency) do
				if k.Parent and k.LocalTransparencyModifier ~= 1 then
					k.LocalTransparencyModifier = 1
				end
			end

			local currentCamera2 = workspace.CurrentCamera

			if currentCamera2 and currentCamera2.CameraSubject ~= humanoid then
				currentCamera2.CameraSubject = humanoid
			end
		end)

		return true
	end

	index._hideTreadmillDecoy = function(arg, arg2)
		if arg._recalling and not arg2 then
			return
		end

		if arg.treadmillDecoyCameraConnection then
			pcall(arg.treadmillDecoyCameraConnection.Disconnect, arg.treadmillDecoyCameraConnection)
			arg.treadmillDecoyCameraConnection = nil
		end

		if arg.treadmillDecoyCharacterConnection then
			pcall(arg.treadmillDecoyCharacterConnection.Disconnect, arg.treadmillDecoyCharacterConnection)
			arg.treadmillDecoyCharacterConnection = nil
		end

		if arg.treadmillPopupConnection then
			pcall(arg.treadmillPopupConnection.Disconnect, arg.treadmillPopupConnection)
			arg.treadmillPopupConnection = nil
		end

		for k, v8 in pairs(arg.treadmillDecoyRealTransparency or {}) do
			if typeof(k) == "Instance" and k.Parent then
				pcall(function()
					k.LocalTransparencyModifier = v8
				end)
			end
		end

		arg.treadmillDecoyRealTransparency = nil
		local character = localPlayer2.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local currentCamera = workspace.CurrentCamera

		if currentCamera then
			pcall(function()
				currentCamera.CameraSubject = humanoid or arg.treadmillDecoyCamera
			end)
		end

		arg.treadmillDecoyCamera = nil

		if arg.treadmillDecoy then
			pcall(arg.treadmillDecoy.Destroy, arg.treadmillDecoy)
		end

		arg.treadmillDecoy = nil
		pcall(arg._hideSafeMarker, arg)
		pcall(arg._restoreCharacterVisual, arg)

		-- sapu ulang beberapa kali: skrip kamera/animasi game bisa menimpa nilai setelah decoy hilang
		task.spawn(function()
			for _, waitTime in ipairs({0.05, 0.25, 0.6}) do
				task.wait(waitTime)
				if arg.treadmillDecoy == nil and not arg.destroyed then
					pcall(arg._restoreCharacterVisual, arg)
				end
			end
		end)
	end

	index._restoreTreadmillVisualAtSafe = function(arg)
		if not arg.treadmillDecoy then
			arg:_hideTreadmillDecoy()
			return true
		end
		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local v8 = arg:_resolveSafeCFrame(humanoidRootPart)

		if humanoidRootPart then
			if humanoid then
				if not v8 then
					arg:_hideTreadmillDecoy()
					return false
				end
			else
				arg:_hideTreadmillDecoy()
				return false
			end
		else
			arg:_hideTreadmillDecoy()
			return false
		end

		local n58, v9 = os.clock() + n33
		local n59 = 0

		while true do
			local destroyed = arg.destroyed
			if not (if destroyed then not destroyed else os.clock() < n58) then
				break
			end
			local now = os.clock()

			if arg:_isInSafeArea(humanoidRootPart) then
				v9 = v9 or now
				if now - v9 >= n32 then
					arg:_hideTreadmillDecoy()
					return true
				end
			else
				v9 = nil

				if now >= n59 then
					n59 = now + n34
					arg:_teleportRoot(humanoidRootPart, humanoid, v8)
				end
			end

			task.wait(0.03)
		end

		arg:_hideTreadmillDecoy()
		return false
	end

	index._prepareTreadmillLaunch = function(arg, arg2, arg3)
		local treadmillManager = arg.treadmillManager

		if treadmillManager then
			if type(treadmillManager.pulseForCarry) ~= "function" then
				return false, "Preparation unavailable"
			end
		else
			return false, "Preparation unavailable"
		end

		local uid = arg2 and arg2.Uid

		local function fn90()
			return uid and (EggState2.ReadFieldEgg(uid) or arg.records[uid]) or nil
		end

		local function fn91()
			local v8 = fn90()
			return arg.destroyed or not arg.enabled or arg.planGeneration ~= arg3 or not arg:_wallOpen() or type(v8) ~= "table" or not arg:_matches(v8)
		end

		local function fn92(arg4)
			local character = localPlayer2.Character
			return arg:_teleportRoot(character and character:FindFirstChild("HumanoidRootPart"), character and character:FindFirstChildOfClass("Humanoid"), arg4)
		end

		arg:_setStatus("Preparing carry")
		if not arg:_showTreadmillDecoy() then
			return false, "Safe-zone visual unavailable"
		end
		local v8, v9 = treadmillManager:pulseForCarry(fn92, fn91)
		if not v8 then
			arg:_restoreTreadmillVisualAtSafe()
			return false, v9
		end
		arg:_setStatus("Positioning at safe area")
		if not arg:_restoreTreadmillVisualAtSafe() then
			return false, "Safe teleport failed"
		end

		if fn91() then
			return false, "Target changed before travel"
		end
		return true, (fn90())
	end

	index._resolveEggDestination = function(arg, arg2, arg3, arg4)
		if type(arg2) ~= "table" then
			return nil
		elseif typeof(arg2.BottomCFrame) ~= "CFrame" then
			return nil
		end

		local character = localPlayer2.Character
		arg3, arg4 = arg3 or character and character:FindFirstChild("HumanoidRootPart"), arg4 or character and character:FindFirstChildOfClass("Humanoid")

		if arg3 then
			if not arg4 then
				return nil
			end
		else
			return nil
		end

		local n58 = arg:_feetOffset(arg3, arg4) + n17
		return CFrame.new(arg2.BottomCFrame.Position + Vector3.new(0, n58, 0))
	end

	local n58 = 110
	local n59 = 30
	local n60 = 900
	local n61 = 120
	local n62 = 18
	local n63 = -426
	local n64 = -308

	local function fn90()
		local ok, result = pcall(function()
			local v8 = fn()
			return v8 and v8:FindFirstChild("Areas") and v8.Areas:FindFirstChild("EggCarryBounds")
		end)

		if ok and result then
			local gameplay1 = result:FindFirstChild("Gameplay1")

			if gameplay1 and gameplay1:IsA("BasePart") then
				local n65 = gameplay1.Size.Z * 0.5 - n62
				if n65 > 5 then
					return gameplay1.Position.Z - n65, gameplay1.Position.Z + n65
				end
			end
		end

		return n63, n64
	end

	index._resolveRouteCruiseY = function(arg, arg2, arg3)
		if arg.config.stealMode ~= "Fly" then
			return nil
		end

		if arg2 then
			if typeof(arg3) ~= "CFrame" then
				return nil
			end
		else
			return nil
		end

		if arg3.Position.Y >= n58 - 6 then
			return nil
		end
		return n58
	end

	index._resolveElevatedDestination = function(arg, arg2, arg3)
		if arg2 then
			if typeof(arg3) ~= "CFrame" then
				return nil
			end
		else
			return nil
		end

		return arg3
	end

	index._teleportRoot = function(arg, arg2, arg3, cFrame)
		if not arg2 or not arg3 then
			return false
		elseif typeof(cFrame) ~= "CFrame" then
			return false
		end

		if not pcall(function()
			arg2.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			arg2.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			arg2.CFrame = cFrame
			arg2.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			arg2.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end) then
			return false
		end

		local n65 = math.clamp(arg.config.speed or n15, n13, fn61())
		fn74(localPlayer2.Character, n65 * n44)

		if not fn83(arg3, arg2, n65, (Vector3.new(0, 0, 0))) then
			fn82(arg3, arg2, n65)
			fn83(arg3, arg2, n65, (Vector3.new(0, 0, 0)))
		end

		return true
	end

	index._legitWalkSpeed = function(arg)
		local walkSpeed

		pcall(function()
			local humanoid = localPlayer2.Character and localPlayer2.Character:FindFirstChildOfClass("Humanoid")
			walkSpeed = humanoid and humanoid.WalkSpeed
		end)

		if type(walkSpeed) == "number" and (walkSpeed >= 1 and walkSpeed <= 400) then
			arg._legitWsCache = walkSpeed
		end

		return arg._legitWsCache or type(walkSpeed) == "number" and math.clamp(walkSpeed, 1, 400) or 16
	end

	index._activeGlideSpeed = function(arg)
		if arg.config.stealMode == "Fly" and arg._flyDeparting then
			return arg:_legitWalkSpeed()
		end
		return n24
	end

	index._glideRoot = function(arg, cFrame, arg2, arg3)
		if typeof(cFrame) ~= "CFrame" then
			return false
		end
		local v8 = arg3 or arg:_activeGlideSpeed()
		local character = localPlayer2.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart or not humanoid then
			return false
		end
		pcall(fn67, character)

		pcall(function()
			humanoid.AutoRotate = false
		end)

		arg:_startHoverPad()
		local position = cFrame.Position

		local function fn91(arg4, arg5, arg6)
			local n65 = math.clamp(arg.config.speed or n15, n13, fn61())

			pcall(function()
				fn74(arg4, n65 * n44)
				fn83(arg5, arg6, n65, (Vector3.new(0, 0, 0)))
			end)
		end

		local n65 = os.clock() + math.clamp((position - humanoidRootPart.Position).Magnitude / math.max(v8, 1) * 1.6 + 6, 15, 120)

		while os.clock() < n65 do
			if arg2 and arg2() then
				return false
			end

			if arg.destroyed then
				return false
			elseif not arg.enabled then
				if not arg._externalDeliver then
					return false
				end
			end

			local character2 = localPlayer2.Character
			humanoidRootPart = character2 and character2:FindFirstChild("HumanoidRootPart")
			humanoid = character2 and character2:FindFirstChildOfClass("Humanoid")
			if not humanoidRootPart or not humanoid then
				return false
			end
			local position2 = humanoidRootPart.Position
			local n66 = position - position2
			local magnitude = n66.Magnitude

			if magnitude <= 1 then
				pcall(function()
					humanoidRootPart.CFrame = cFrame
					humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
				end)

				arg:_syncHoverPad(position)
				fn91(character2, humanoid, humanoidRootPart)
				return true
			end

			local result = RunService2.Heartbeat:Wait()
			local n67 = math.max(math.min(result, n45), 0.004166666666666667)
			local n68 = math.min(v8 * n67, magnitude)
			local n69 = position2 + n66.Unit * n68

			if n67 >= 0.03333333333333333 then
				local v9 = arg:_groundYAt(n69.X, n69.Z, character2)

				if v9 then
					local n70 = v9 + arg:_feetOffset(humanoidRootPart, humanoid)

					if n69.Y < n70 then
						n69 = Vector3.new(n69.X, n70, n69.Z)
					end
				end
			end

			pcall(function()
				humanoidRootPart.CFrame = CFrame.new(n69, n69 + n66.Unit)
				humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			end)

			arg:_syncHoverPad(n69)
			fn91(character2, humanoid, humanoidRootPart)
		end

		return false
	end

	index.HOP = {studs = 500, gap = 0.15, height = 40, safeWait = 0.8}
	index.RELAY_LAND_OK = 200
	index.RELAY_ROUNDS = 3
	index.EGG_FREE_SLOTS = 5

	index._relaySettle = function(arg)
		if not arg._relaySettle_s then
			local n65 = 0.05

			pcall(function()
				n65 = localPlayer2:GetNetworkPing() or 0.05
			end)

			arg._relaySettle_s = math.clamp(0.5 + n65 * 4, index.HOP.safeWait, 2)
			arg._relayGood = 0
		end

		return arg._relaySettle_s
	end

	index._noteRelayLanding = function(arg, arg2)
		local v8 = arg:_relaySettle()

		if arg2 > index.RELAY_LAND_OK then
			arg._relaySettle_s = math.min(v8 + 0.2, 2)
			arg._relayGood = 0
		else
			arg._relayGood = (arg._relayGood or 0) + 1

			if arg._relayGood >= 5 then
				arg._relayGood = 0
				arg._relaySettle_s = math.max(v8 - 0.05, index.HOP.safeWait)
			end
		end
	end

	index._hopRoot = function(arg, arg2, arg3)
		if typeof(arg2) ~= "CFrame" then
			return false
		end
		local hop = index.HOP
		local character = localPlayer2.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart or not humanoid then
			return false
		end
		pcall(fn67, character)

		pcall(function()
			humanoid.AutoRotate = false
		end)

		arg:_startHoverPad()
		local position = arg2.Position
		local n65 = position.Y + hop.height

		local function fn91()
			if arg3 and arg3() then
				return false
			end

			if arg.destroyed then
				return false
			elseif not arg.enabled then
				if not arg._externalDeliver then
					return false
				end
			end

			character = localPlayer2.Character
			humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
			humanoid = character and character:FindFirstChildOfClass("Humanoid")
			return humanoidRootPart ~= nil and humanoid ~= nil and humanoid.Health > 0
		end

		local function fn92(cFrame)
			pcall(function()
				humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
				humanoidRootPart.CFrame = cFrame
				humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			end)

			arg:_syncHoverPad(cFrame.Position)
			local n66 = math.clamp(arg.config.speed or n15, n13, fn61())

			pcall(function()
				fn74(character, n66 * n44)
				fn83(humanoid, humanoidRootPart, n66, (Vector3.new(0, 0, 0)))
			end)
		end

		local n66 = os.clock() + 20

		while os.clock() < n66 do
			if not fn91() then
				return false
			end
			local position2 = humanoidRootPart.Position
			local vector3 = Vector3.new(position.X - position2.X, 0, position.Z - position2.Z)
			if vector3.Magnitude <= hop.studs then
				fn92(arg2)
				return true
			end
			local n67 = Vector3.new(position2.X, n65, position2.Z) + vector3.Unit * hop.studs
			local cframe2 = CFrame.new(n67, n67 + vector3.Unit)
			fn92(cframe2)
			local n68 = os.clock() + hop.gap

			while os.clock() < n68 do
				RunService2.Heartbeat:Wait()
				if not fn91() then
					return false
				end
				fn92(cframe2)
			end
		end

		return false
	end

	local n65 = 420
	local n66 = 20
	local n67 = 0.5

	index._walkBrakeDecel = function(arg)
		if arg._brakeDecel then
			return arg._brakeDecel
		end
		local fanKunHubBrakeDecel = genv.__FanKunHUBBrakeDecel
		local humanoid = localPlayer2.Character and localPlayer2.Character:FindFirstChildOfClass("Humanoid")
		if type(fanKunHubBrakeDecel) == "table" and (humanoid and math.abs((fanKunHubBrakeDecel.ws or 0) - humanoid.WalkSpeed) < 15) then
			arg._brakeDecel = fanKunHubBrakeDecel.decel
			return fanKunHubBrakeDecel.decel
		end
		return n65
	end

	index._walkLeg = function(arg, arg2, arg3, arg4, arg5, arg6, arg7)
		local function fn91(arg8, arg9)
			if arg8 and arg9 then
				pcall(function()
					arg8:MoveTo(arg9.Position)
				end)
			end

			return false
		end

		local unit, v8, v9

		while os.clock() < arg6 do
			local character = localPlayer2.Character
			local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")

			if humanoidRootPart then
				if not humanoid then
					return false
				end
			else
				return false
			end

			if arg3 and arg3() then
				return (fn91(humanoid, humanoidRootPart))
			end

			if arg.destroyed then
				return (fn91(humanoid, humanoidRootPart))
			elseif not arg.enabled then
				if not arg._externalDeliver then
					return (fn91(humanoid, humanoidRootPart))
				end
			end

			local position = humanoidRootPart.Position
			local vector3 = Vector3.new(arg2.X - position.X, 0, arg2.Z - position.Z)
			local magnitude = vector3.Magnitude
			local assemblyLinearVelocity = humanoidRootPart.AssemblyLinearVelocity
			local magnitude2 = Vector3.new(assemblyLinearVelocity.X, 0, assemblyLinearVelocity.Z).Magnitude

			if arg5 then
				if magnitude <= arg4 and magnitude2 <= n66 then
					pcall(function()
						humanoid:MoveTo(position)
					end)

					return true
				end
			else
				unit = unit or (magnitude > 0.001 and vector3.Unit or Vector3.new(0, 0, 0))

				if magnitude <= arg4 then
					return true
				elseif vector3:Dot(unit) <= 0 then
					return true
				end
			end

			local vector4
			local n68 = magnitude > 0.001 and math.max(assemblyLinearVelocity.X * vector3.X + assemblyLinearVelocity.Z * vector3.Z, 0) / magnitude or magnitude2

			if arg5 and magnitude <= n68 * n68 / (2 * arg:_walkBrakeDecel()) + n68 * 0.06 then
				vector4 = position
				local now = os.clock()

				if v8 and (now > v9 and magnitude2 > n66) then
					local n69 = (v8 - magnitude2) / (now - v9)

					if n69 > 20 and n69 < 5000 then
						arg._brakeDecel = arg:_walkBrakeDecel() * 0.8 + n69 * 0.93 * 0.2
						genv.__FanKunHUBBrakeDecel = {ws = humanoid.WalkSpeed, decel = arg._brakeDecel}
					end
				end

				v8 = magnitude2
				v9 = now
			else
				v8 = nil
				local n69 = math.max(humanoid.WalkSpeed * n67, 12)

				if arg5 and magnitude <= n69 then
					vector4 = Vector3.new(arg2.X, position.Y, arg2.Z)
				else
					vector4 = position + vector3.Unit * n69
				end
			end

			pcall(function()
				humanoid:MoveTo(vector4)
			end)

			if arg7 then
				arg7()
			end

			RunService2.Heartbeat:Wait()
		end

		local character = localPlayer2.Character
		return (fn91(character and character:FindFirstChildOfClass("Humanoid"), character and character:FindFirstChild("HumanoidRootPart")))
	end

	index._walkTo = function(arg, arg2, arg3, arg4)
		if typeof(arg2) ~= "CFrame" then
			return false
		end
		local n68 = arg4 or 8
		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if humanoidRootPart then
			if not humanoid then
				return false
			end
		else
			return false
		end

		pcall(function()
			humanoid.AutoRotate = true
		end)

		local position = arg2.Position
		local walkSpeed = humanoid.WalkSpeed
		local v8 = if walkSpeed then if walkSpeed < 1 then 16 else walkSpeed else 16
		local magnitude = Vector3.new(position.X - humanoidRootPart.Position.X, 0, position.Z - humanoidRootPart.Position.Z).Magnitude
		return arg:_walkLeg(position, arg3, n68, true, os.clock() + math.clamp(magnitude / v8 * 2 + 8, 12, 90))
	end

	index._walkToZigzag = function(arg, arg2, arg3, arg4)
		if typeof(arg2) ~= "CFrame" then
			return false
		end
		local n68 = arg4 or 8
		local n69 = 60
		local n70 = 38
		local n71 = 10
		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if humanoidRootPart then
			if not humanoid then
				return false
			end
		else
			return false
		end

		pcall(function()
			humanoid.AutoRotate = true
		end)

		local position = arg2.Position
		local walkSpeed = humanoid.WalkSpeed
		local v8 = if walkSpeed then if walkSpeed < 1 then 16 else walkSpeed else 16
		local magnitude = Vector3.new(position.X - humanoidRootPart.Position.X, 0, position.Z - humanoidRootPart.Position.Z).Magnitude
		local n72 = math.max(45, v8 * v8 / (2 * arg:_walkBrakeDecel()) * 1.25)
		local n73, v9, v10 = os.clock() + math.clamp(magnitude / v8 * 3 + 10, 14, 120)

		local ok, result, result2 = pcall(function()
			return fn90()
		end)

		if ok and (type(result) == "number" and type(result2) == "number") then
			local n74 = math.min(result, result2)
			local n75 = math.max(result, result2)
			v9 = n74
			v10 = n75
		end

		result2 = math.random() < 0.5 and -1 or 1

		while os.clock() < n73 do
			if arg3 and arg3() then
				return false
			end

			if arg.destroyed then
				return false
			elseif not arg.enabled then
				return false
			end

			local character2 = localPlayer2.Character
			humanoidRootPart, humanoid = character2 and character2:FindFirstChild("HumanoidRootPart"), character2 and character2:FindFirstChildOfClass("Humanoid")

			if humanoidRootPart then
				if not humanoid then
					return false
				end
			else
				return false
			end

			local position2 = humanoidRootPart.Position
			local vector3 = Vector3.new(position.X - position2.X, 0, position.Z - position2.Z)
			local magnitude2 = vector3.Magnitude
			if magnitude2 <= n72 then
				return arg:_walkLeg(position, arg3, n68, true, n73)
			end
			local unit = vector3.Unit
			local vector4 = Vector3.new(-unit.Z, 0, unit.X)
			local n74 = math.max(magnitude2 - n72 * 0.5, 4)
			local n75 = math.min(n69 + math.random() * 40, n74)
			local n76 = result2 * math.min(n70, n75 * 0.4) * (0.6 + math.random() * 0.4)
			result2 = -result2
			local n77 = position2 + unit * n75 + vector4 * n76
			n75 = n77.Z
			local v11 = if v9 then if v10 then math.clamp(n75, v9 + 2, v10 - 2) else n75 else n75
			if not arg:_walkLeg(Vector3.new(n77.X, position2.Y, v11), arg3, n71, false, n73) then
				return false
			end
		end

		return false
	end

	index._flyWalkTo = function(arg, arg2, arg3, arg4, arg5)
		if typeof(arg2) ~= "CFrame" then
			return false
		end
		local n68 = arg4 or 8
		local hoverPadHeightOverride = tonumber(arg5) or 110
		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoidRootPart or not humanoid then
			return false
		end

		pcall(function()
			humanoid.AutoRotate = true
		end)

		local function fn91()
			pcall(function()
				local humanoid2 = localPlayer2.Character and localPlayer2.Character:FindFirstChildOfClass("Humanoid")
				local animator = humanoid2 and humanoid2:FindFirstChildWhichIsA("Animator")

				if animator then
					for i, v8 in ipairs(animator:GetPlayingAnimationTracks()) do
						v8:Stop(0)
					end
				end
			end)
		end

		local function fn92(disabled)
			local character2 = localPlayer2.Character
			local animate = character2 and character2:FindFirstChild("Animate")

			if animate then
				pcall(function()
					animate.Disabled = disabled
				end)
			end
		end

		fn92(true)
		fn91()
		local position = arg2.Position
		arg.hoverPadHeightOverride = hoverPadHeightOverride
		arg:_startHoverPad()

		pcall(function()
			humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position.X, hoverPadHeightOverride, humanoidRootPart.Position.Z) * humanoidRootPart.CFrame.Rotation
			humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end)

		arg:_syncHoverPad()
		local walkSpeed = humanoid.WalkSpeed
		local v8 = if walkSpeed then if walkSpeed < 1 then 16 else walkSpeed else 16
		local magnitude = Vector3.new(position.X - humanoidRootPart.Position.X, 0, position.Z - humanoidRootPart.Position.Z).Magnitude
		local v9 = arg:_walkLeg(position, arg3, n68, true, os.clock() + math.clamp(magnitude / v8 * 2 + 10, 12, 120), fn91)
		fn92(false)
		arg.hoverPadHeightOverride = nil
		if not v9 then
			return false
		end

		if arg3 and arg3() then
			return false
		end
		arg:_glideRoot(arg2, arg3, arg:_legitWalkSpeed())
		return not (arg3 and arg3())
	end

	index._isInSafeArea = function(arg, arg2)
		if not arg2 then
			return false
		end
		local n68 = arg2.Position - vector2
		return Vector2.new(n68.X, n68.Z).Magnitude <= n30 and math.abs(n68.Y) <= n31
	end

	index._isInField = function(arg, arg2)
		local v8 = fn()
		local areas = v8 and v8:FindFirstChild("Areas")
		local wallStartCollision = areas and areas:FindFirstChild("WallStartCollision")

		if wallStartCollision then
			if not wallStartCollision:IsA("BasePart") then
				return true
			end
		else
			return true
		end

		return arg2.Position.X >= wallStartCollision.Position.X + 3
	end

	index._needsSafeZoneHop = function(arg, arg2)
		if arg:_isInField(arg2) then
			return false, nil
		elseif arg:_isInSafeArea(arg2) then
			return false, nil
		end

		return true, arg:_resolveSafeCFrame(arg2)
	end

	index._invalidateCarryWorker = function(arg)
		arg.carryWorker = nil
	end

	index._claimCarryWorker = function(arg, arg2, arg3)
		local generation = arg.carry.generation
		local carryWorker = arg.carryWorker
		if carryWorker and carryWorker.generation == generation then
			return nil
		end
		local carryWorker2 = {kind = arg2, uid = arg3, generation = generation, token = {}}
		arg.carryWorker = carryWorker2
		return carryWorker2
	end

	index._isCarryWorkerCurrent = function(arg, arg2)
		return type(arg2) == "table" and arg.carryWorker == arg2 and arg.carry.generation == arg2.generation and not arg.destroyed and (arg.enabled or arg._externalDeliver)
	end

	index._releaseCarryWorker = function(arg, arg2)
		if arg.carryWorker == arg2 then
			arg.carryWorker = nil
		end
	end

	index.ownsCarryRecovery = function(arg, arg2)
		if arg.destroyed then
			return false
		elseif not arg.enabled then
			return false
		end

		if arg.carry.uid == arg2 then
			return true
		end
		return arg.running and arg.activeTarget ~= nil and (arg2 == nil or arg.activeTarget.Uid == arg2)
	end

	index.requestCarryRecovery = function(arg, arg2)
		if arg.destroyed then
			return false
		elseif arg.enabled then
			if type(arg2) ~= "string" then
				return false
			elseif arg2 == "" then
				return false
			end
		else
			return false
		end

		if arg:isSkippedEgg(arg2) then
			return true
		end

		if arg.tweenRecoveryUid == arg2 then
			arg:_scheduleMovementRetry()
			return true
		end

		if arg.carry.active and arg.carry.uid == arg2 then
			return true
		end
		local v8 = EggState2.ReadFieldEgg(arg2) or arg.records[arg2]

		if type(v8) ~= "table" then
			return false
		elseif v8.State ~= AreaEggs.States.Dropped then
			if v8.State ~= AreaEggs.States.Slot then
				return false
			end
		end

		local carryWorker = arg.carryWorker

		if carryWorker and carryWorker.kind == "re-steal" and carryWorker.uid == arg2 or arg.activeTween and arg.activeTarget and arg.activeTarget.Uid == arg2 then
			return true
		elseif arg.carryAttemptToken then
			if arg.activeTarget and arg.activeTarget.Uid == arg2 then
				return true
			end
		end

		arg.carry.generation += 1
		arg:_invalidateCarryWorker()
		arg.carryAttemptToken = nil
		arg.running = true
		arg.activeTarget = v8

		task.defer(function()
			if not arg.destroyed and (arg.enabled and not arg.carry.active) then
				arg:_reStealDroppedEgg(arg2)
			end
		end)

		return true
	end

	index._hasConfirmedCarry = function(arg, arg2)
		if not arg.carry.active then
			return false
		end

		if arg2 == nil then
			return true
		elseif arg.carry.uid == nil then
			return true
		end

		return arg.carry.uid == arg2
	end

	index._adoptCarryFromRecord = function(arg, uid)
		if arg.carry.active and arg.carry.uid == uid then
			return
		end

		if arg.carryTimeouts then
			arg.carryTimeouts[uid] = nil
		end

		if arg.instantPhase == "priming" and uid == arg.primerUid then
			arg.carry.active = true
			arg.carry.uid = uid
			return
		end

		arg.carry.generation += 1
		arg:_invalidateCarryWorker()
		arg:_clearArrivalHold(uid)
		local activeTarget = arg.activeTarget
		arg.claimPresentationSuppression = {assetCategory = activeTarget and activeTarget.AssetCategory, expiresAt = os.clock() + 8}
		arg.carry.active = true
		arg.carry.uid = uid
		arg.carryStartTime = os.clock()
		local humanoidRootPart = localPlayer2.Character and localPlayer2.Character:FindFirstChild("HumanoidRootPart")
		arg.carryStartPos = activeTarget and activeTarget.BottomCFrame and activeTarget.BottomCFrame.Position or humanoidRootPart and humanoidRootPart.Position

		if arg.tweenRecoveryUid == uid then
			arg.tweenRecoveryUid = nil
		end

		arg.stats.lastResult = "Carry confirmed"
		arg:_notify()
	end

	index._recordShowsCarried = function(arg, arg2)
		if type(arg2) ~= "string" then
			return false
		elseif arg2 == "" then
			return false
		end

		local v8 = EggState2.ReadFieldEgg(arg2) or arg.records[arg2]
		return type(v8) == "table" and v8.State == AreaEggs.States.Carried and v8.CarrierUserId == localPlayer2.UserId
	end

	index._recordShowsForeignCarry = function(arg, arg2)
		if type(arg2) ~= "string" then
			return false
		elseif arg2 == "" then
			return false
		end

		local v8 = EggState2.ReadFieldEgg(arg2) or arg.records[arg2]
		return type(v8) == "table" and v8.State == AreaEggs.States.Carried and v8.CarrierUserId ~= nil and v8.CarrierUserId ~= localPlayer2.UserId
	end

	index._resolveMovementSpeed = function(arg, arg2)
		if arg2.Parent then
			if arg2.Health <= 0 then
				return nil
			end
		else
			return nil
		end

		return math.clamp(arg.config.speed, n13, fn61())
	end

	index._isAreaSafe = function(arg, arg2)
		return true
	end

	index._feetOffset = function(arg, arg2, arg3)
		if arg3.RigType == Enum.HumanoidRigType.R15 then
			return arg2.Size.Y * 0.5 + math.max(arg3.HipHeight, 0.5)
		end
		return arg2.Size.Y * 0.5 + 2
	end

	index.setAntiTrap = function(arg, arg2)
		arg.config.antiTrap = arg2 == true

		if arg.config.antiTrap then
			arg:_purgeTraps()
		end
	end

	index._isForeignTrap = function(arg, arg2)
		if arg2.Name == str7 and arg2:IsA("BasePart") then
			local attribute = arg2:GetAttribute("Owner")
			return type(attribute) ~= "string" or attribute ~= localPlayer2.Name
		end
		return arg2:IsA("Model") and arg2.Name == str8 and arg2:FindFirstChild("Hitbox") ~= nil
	end

	index._purgeTrap = function(arg, arg2)
		if arg.config.antiTrap then
			if arg2 then
				if not arg2.Parent then
					return
				end
			else
				return
			end
		else
			return
		end

		if arg:_isForeignTrap(arg2) then
			pcall(arg2.Destroy, arg2)
		end
	end

	index._purgeTraps = function(arg)
		for i, v8 in ipairs({"Transient", "__DEBRIS"}) do
			local v9 = workspace:FindFirstChild(v8)

			if v9 then
				for i2, descendant in ipairs(v9:GetDescendants()) do
					arg:_purgeTrap(descendant)
				end
			end
		end
	end

	index._syncHoverPad = function(arg, arg2)
		local hoverPad = arg.hoverPad

		if hoverPad then
			if hoverPad.Parent then
				if hoverPad:GetAttribute(str6) ~= arg.hoverPadOwnerId then
					return false
				end
			else
				return false
			end
		else
			return false
		end

		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if humanoidRootPart then
			if not humanoid then
				return false
			end
		else
			return false
		end

		local position = typeof(arg2) == "Vector3" and arg2 or humanoidRootPart.Position
		local y = position.Y
		local v8 = if arg.hoverPadHeightOverride ~= nil then if typeof(arg2) ~= "Vector3" then arg.hoverPadHeightOverride else y else y
		local v9 = if arg.hoverPadHeightOverride ~= nil then math.max(n18, humanoid.WalkSpeed * 2 / 15) else n18

		if math.abs(hoverPad.Size.X - v9) > 0.5 then
			hoverPad.Size = Vector3.new(v9, n19, v9)
		end

		hoverPad.CFrame = CFrame.new(position.X, v8 - arg:_feetOffset(humanoidRootPart, humanoid) - n19 * 0.5 - 0.05, position.Z)
		return true
	end

	index._setArrivalHold = function(arg, arg2, arg3)
		if typeof(arg2) ~= "CFrame" then
			return
		end
		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")

		if character then
			if not humanoidRootPart then
				return
			end
		else
			return
		end

		arg.arrivalHold = {Character = character, RootPart = humanoidRootPart, CFrame = arg2, Uid = arg3}
	end

	index._clearArrivalHold = function(arg, arg2)
		local arrivalHold = arg.arrivalHold

		if arrivalHold then
			if arg2 == nil then
				arg.arrivalHold = nil
			elseif arrivalHold.Uid == nil then
				arg.arrivalHold = nil
			elseif arrivalHold.Uid == arg2 then
				arg.arrivalHold = nil
			end
		else
			arg.arrivalHold = nil
		end
	end

	index._enforceArrivalHold = function(arg)
		local arrivalHold = arg.arrivalHold

		if type(arrivalHold) ~= "table" then
			return false
		elseif typeof(arrivalHold.CFrame) ~= "CFrame" then
			return false
		end

		if localPlayer2.Character ~= arrivalHold.Character then
			arg.arrivalHold = nil
			return false
		elseif arrivalHold.RootPart then
			if not arrivalHold.RootPart.Parent then
				arg.arrivalHold = nil
				return false
			end
		else
			arg.arrivalHold = nil
			return false
		end

		arg:_startHoverPad()

		pcall(function()
			arrivalHold.RootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			arrivalHold.RootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			arg:_syncHoverPad(arrivalHold.CFrame.Position)
			arrivalHold.RootPart.CFrame = arrivalHold.CFrame
		end)

		arg:_syncHoverPad(arrivalHold.CFrame.Position)
		return true
	end

	index._purgeOrphanHoverPads = function(arg)
		for i, child in ipairs(workspace:GetChildren()) do
			if child.Name == name2 and child ~= arg.hoverPad then
				pcall(child.Destroy, child)
			end
		end
	end

	index._startHoverPad = function(arg)
		local hoverPad = arg.hoverPad

		if (if hoverPad then not hoverPad.Parent else not hoverPad) or hoverPad:GetAttribute(str6) ~= arg.hoverPadOwnerId then
			arg:_purgeOrphanHoverPads()

			if hoverPad and hoverPad.Parent then
				pcall(hoverPad.Destroy, hoverPad)
			end

			local part = Instance.new("Part")
			part.Name = name2
			part:SetAttribute(str6, arg.hoverPadOwnerId)
			part.Anchored = true
			part.CanCollide = true
			part.CanQuery = true
			part.CanTouch = false
			part.CastShadow = false
			part.Transparency = 1
			part.Material = Enum.Material.SmoothPlastic
			part.Size = Vector3.new(n18, n19, n18)
			arg.hoverPad = part
			part.Parent = workspace
		end

		arg:_syncHoverPad()

		if not arg.hoverPadConnection then
			arg.hoverPadConnection = RunService2.PreSimulation:Connect(function()
				if not arg:_syncHoverPad() then
					arg:_startHoverPad()
				end
			end)
		end

		if not arg.hoverPadPostConnection then
			arg.hoverPadPostConnection = RunService2.PostSimulation:Connect(function()
				if arg.activeTween then
					arg:_syncHoverPad()
				elseif arg.arrivalHold then
					arg:_syncHoverPad()
				end
			end)
		end
	end

	index._stopHoverPad = function(arg)
		arg.hoverPadHeightOverride = nil

		if arg.hoverPadConnection then
			pcall(arg.hoverPadConnection.Disconnect, arg.hoverPadConnection)
			arg.hoverPadConnection = nil
		end

		if arg.hoverPadPostConnection then
			pcall(arg.hoverPadPostConnection.Disconnect, arg.hoverPadPostConnection)
			arg.hoverPadPostConnection = nil
		end

		if arg.hoverPad then
			pcall(arg.hoverPad.Destroy, arg.hoverPad)
			arg.hoverPad = nil
		end

		arg:_purgeOrphanHoverPads()
	end

	index._startMovementProtection = function(arg)
		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if character then
			if humanoidRootPart then
				if not humanoid then
					return false
				end
			else
				return false
			end
		else
			return false
		end

		local n68 = math.clamp(arg.config.speed or n15, n13, fn61())
		arg.protectionCharacter = character
		arg.protectionHumanoid = humanoid
		arg.protectionRoot = humanoidRootPart
		fn74(character, n68 * n44)
		fn82(humanoid, humanoidRootPart, n68)

		if not arg.integritySpoofConnection then
			arg.integritySpoofConnection = RunService2.PreSimulation:Connect(function()
				local character2 = localPlayer2.Character
				local humanoidRootPart2 = character2 and character2:FindFirstChild("HumanoidRootPart")
				local humanoid2 = character2 and character2:FindFirstChildOfClass("Humanoid")

				if character2 then
					if humanoidRootPart2 then
						if not humanoid2 then
							return
						end
					else
						return
					end
				else
					return
				end

				local n69 = math.clamp(arg.config.speed or n15, n13, fn61())
				arg.protectionCharacter = character2
				arg.protectionHumanoid = humanoid2
				arg.protectionRoot = humanoidRootPart2
				fn74(character2, n69 * n44)

				if not fn83(humanoid2, humanoidRootPart2, n69) then
					fn82(humanoid2, humanoidRootPart2, n69)
				end

				arg:_enforceArrivalHold()
			end)
		end

		if not arg.arrivalHoldConnection then
			arg.arrivalHoldConnection = RunService2.Heartbeat:Connect(function()
				arg:_enforceArrivalHold()
			end)
		end

		return true
	end

	index._startFlyGrounding = function(arg)
		arg:_stopFlyGrounding()
		local v8 = fn79()

		arg._flyGroundConn = RunService2.PreSimulation:Connect(function()
			if arg.destroyed then
				return
			end
			local state = v8 and v8.State

			if type(state) ~= "table" then
				return
			elseif rawget(state, "CorrectionContext") ~= nil then
				return
			end

			rawset(state, "IsSupportedNow", true)
			rawset(state, "UnsupportedStartedAt", nil)

			if rawget(state, "MovementMode") ~= "Correcting" then
				rawset(state, "MovementMode", "Grounded")
			end

			local value = rawget(state, "Evidence")

			if type(value) == "table" then
				value.Flight = 0
				value.Teleport = 0
				value.Speed = 0
			end
		end)
	end

	index._stopFlyGrounding = function(arg)
		if arg._flyGroundConn then
			pcall(arg._flyGroundConn.Disconnect, arg._flyGroundConn)
			arg._flyGroundConn = nil
		end
	end

	index._stopMovementProtection = function(arg)
		arg:_stopFlyGrounding()

		if arg.integritySpoofConnection then
			pcall(arg.integritySpoofConnection.Disconnect, arg.integritySpoofConnection)
			arg.integritySpoofConnection = nil
		end

		if arg.arrivalHoldConnection then
			pcall(arg.arrivalHoldConnection.Disconnect, arg.arrivalHoldConnection)
			arg.arrivalHoldConnection = nil
		end

		arg:_clearArrivalHold()
		arg:_stopHoverPad()
		fn75()
		fn84(arg.protectionHumanoid)
		arg.protectionCharacter = nil
		arg.protectionHumanoid = nil
		arg.protectionRoot = nil
	end

	index.travelAndWait = function(arg, arg2, arg3)
		local tbl16 = arg3 or {}
		if arg.destroyed then
			return false
		end

		if arg.travelBusy and os.clock() < (arg.travelBusyUntil or 0) then
			return false
		end
		local flag5, ok = arg.activeTween and not arg.running

		if flag5 then
			local sharedTravel = arg.activeTween.sharedTravel
			ok = if sharedTravel then tbl16.preempt == true else not sharedTravel
		else
			ok = flag5
		end

		if ok then
			pcall(arg.activeTween.Cancel, arg.activeTween)
			flag5 = os.clock() + 0.5

			while arg.activeTween and os.clock() < flag5 do
				task.wait(0.05)
			end
		end

		if arg.activeTween then
			return false
		end
		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then
			return false
		end
		arg.travelBusy = true
		arg.travelBusyUntil = os.clock() + 45

		ok, flag5 = pcall(function()
			local flag6
			local now = os.clock()
			local magnitude = (arg2.Position - humanoidRootPart.Position).Magnitude
			local n68 = now + magnitude / math.max(tonumber(tbl16.speed) or arg.config.speed or n15, n13) + 6
			arg.travelBusyUntil = n68 + 2
			local speed2 = tbl16.speed

			local tbl17 = {silent = true, sharedTravel = true, abort = function()
				return arg.destroyed or tbl16.abort ~= nil and tbl16.abort()
			end}

			tbl17.onDone = function(arg4)
				flag6 = arg4 == true
			end

			arg:_tweenRoot(arg2, nil, speed2, tbl17)
			speed2 = now

			while true do
				if not (flag6 == nil) then
					break
				end
				local now2 = os.clock()
				local humanoidRootPart2 = localPlayer2.Character and localPlayer2.Character:FindFirstChild("HumanoidRootPart")
				local magnitude2 = humanoidRootPart2 and (arg2.Position - humanoidRootPart2.Position).Magnitude or 1 / 0

				if magnitude2 < magnitude - 0.5 then
					magnitude = magnitude2
					speed2 = now2
				end

				if arg.destroyed or tbl16.abort ~= nil and tbl16.abort() or now2 - speed2 >= 1.5 or now2 >= n68 then
					if arg.activeTween and arg.activeTween.Cancel then
						pcall(arg.activeTween.Cancel)
					end

					flag6 = false
					break
				end

				task.wait(0.05)
			end

			return flag6
		end)

		arg.travelBusy = false

		if not ok then
			if arg.activeTween and (arg.activeTween.sharedTravel and arg.activeTween.Cancel) then
				pcall(arg.activeTween.Cancel)
			end

			return false
		end

		return flag5 == true
	end

	index._tweenRoot = function(arg, arg2, arg3, arg4, arg5)
		arg:_clearArrivalHold()
		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local tbl16 = arg5 or {}

		if not humanoidRootPart or not humanoid then
			arg.safeStarting = false

			if tbl16.silent then
				if tbl16.onDone then
					pcall(tbl16.onDone, false)
				end

				return
			end

			arg:_finish("Character unavailable")
			return
		end

		local v8 = arg4 or arg:_resolveMovementSpeed(humanoid)

		if not v8 then
			arg.safeStarting = false

			if tbl16.silent then
				if tbl16.onDone then
					pcall(tbl16.onDone, false)
				end

				return
			end

			arg:_finish("Movement unavailable")
			return
		end

		local n68 = math.clamp(v8, n13, fn61())
		arg:_startMovementProtection()
		pcall(fn67, character)
		local currentCamera = workspace.CurrentCamera

		if currentCamera and currentCamera.CameraSubject ~= humanoid then
			pcall(function()
				currentCamera.CameraSubject = humanoid
			end)
		end

		local autoRotate = humanoid.AutoRotate
		humanoid.AutoRotate = false
		local flag5 = tbl16.flightProfile == true and arg:_resolveRouteCruiseY(humanoidRootPart, arg2) or nil
		local activeTween = {sharedTravel = tbl16.sharedTravel == true, routeCruiseY = flag5, travelPhase = flag5 and "takeoff" or nil, zigzag = arg.config.stealMode == "Zig-Zag", zigT = 0, zigLast = 0}
		arg.activeTween = activeTween
		arg:_startHoverPad()
		local flag6, connection6, now, v9 = false
		local n69 = 0

		local function fn91(arg6)
			if flag6 then
				return
			end
			flag6, now = true, nil

			if humanoid.Parent ~= nil then
				humanoid.AutoRotate = autoRotate
			end

			if arg6 and tbl16.holdAfterArrival then
				arg:_setArrivalHold(arg2, tbl16.holdUid)
			end

			if tbl16.onDone then
				pcall(tbl16.onDone, arg6 == true)
			end

			if connection6 then
				connection6:Disconnect()
				connection6 = nil
			end

			if arg.activeTween == activeTween then
				arg.activeTween = nil
			end

			if not arg.arrivalHold then
				arg:_stopHoverPad()
			end

			if not arg.enabled then
				arg:_stopMovementProtection()
			end

			pcall(function()
				if localPlayer2.Character == character and humanoidRootPart.Parent then
					humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				end
			end)

			if arg6 and (localPlayer2.Character == character and (humanoid.Parent ~= nil and arg3)) then
				arg3()
			end
		end

		activeTween.Cancel = function()
			fn91(false)
		end

		connection6 = RunService2.Heartbeat:Connect(function(deltaTime)
			if tbl16.abort and tbl16.abort() then
				fn91(false)
				return
			end

			if arg.destroyed then
				fn91(false)
				return
			elseif arg.activeTween ~= activeTween then
				fn91(false)
				return
			end

			if tbl16.carryTarget and os.clock() >= (activeTween.nextTargetCheck or 0) then
				activeTween.nextTargetCheck = os.clock() + 0.1
				local uid = tbl16.carryTarget.Uid
				local v10 = EggState2.ReadFieldEgg(uid)
				local state = v10 and v10.State

				if state ~= AreaEggs.States.Slot and (state ~= AreaEggs.States.Dropped and (state ~= "GuardCarried" and (not (v10 and v10.CarrierUserId == localPlayer2.UserId) and not arg:_hasConfirmedCarry(uid)))) then
					fn91(false)
					local fanKunHubPlayerSteal = genv.__FanKunHUBPlayerSteal
					arg:_finish(state == "Carried" and fanKunHubPlayerSteal ~= nil and fanKunHubPlayerSteal:intercept(uid) and "Target taken - chasing the carrier" or "Target taken by someone else")
					return
				end
			end

			pcall(function()
				local n70 = math.clamp(arg4 or arg.config.speed or n68, n13, fn61())
				fn74(character, n70 * n44)
				local v10 = fn71()[str4]
				local state = type(v10) == "table" and v10.State or nil

				if not fn81(state, humanoid, humanoidRootPart) then
					v9, now = nil, nil
					humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
					arg:_syncHoverPad(humanoidRootPart.Position)

					if fn80(state, humanoid, humanoidRootPart) then
						fn78(state, n70 * n44, (Vector3.new(0, 0, 0)))
					else
						fn82(humanoid, humanoidRootPart, n70)
					end

					return
				end

				local position = humanoidRootPart.Position
				local n71 = arg2.Position - position
				local magnitude = n71.Magnitude
				local vector3 = Vector3.new(n71.X, 0, n71.Z)
				local magnitude2 = vector3.Magnitude
				local position2 = arg2.Position

				if activeTween.routeCruiseY then
					if activeTween.travelPhase == "takeoff" then
						if position.Y >= activeTween.routeCruiseY - 0.5 then
							activeTween.travelPhase = "cruise"
						else
							position2 = Vector3.new(position.X, activeTween.routeCruiseY, position.Z)
						end
					end

					if activeTween.travelPhase == "cruise" then
						if magnitude2 <= 4 then
							activeTween.travelPhase = "descend"
						else
							position2 = Vector3.new(arg2.Position.X, activeTween.routeCruiseY, arg2.Position.Z)
						end
					end

					position2 = if activeTween.travelPhase == "descend" then arg2.Position else position2
				end

				local n72 = position2 - position
				local magnitude3 = n72.Magnitude
				local routeCruiseY = activeTween.routeCruiseY and magnitude2 or magnitude
				local carryTarget

				if v9 and routeCruiseY > v9 + n47 then
					n69 = os.clock() + n48
				end

				v9 = routeCruiseY
				routeCruiseY = os.clock() < n69 and math.max(n13, n70 * n49) or n70

				if tbl16.carryTarget and not activeTween.__earlyCarrySpam and magnitude <= 30 then
					activeTween.__earlyCarrySpam = true
					carryTarget = tbl16.carryTarget
					local uid = carryTarget.Uid
					local v11 = AreaEggSlotIdentity.LooksLikeFirstAreaUid(uid) and AreaEggSlotIdentity.SlotKey(carryTarget.AreaId, carryTarget.NestId) or nil

					task.spawn(function()
						while true do
							local destroyed = arg.destroyed
							if not ((if destroyed then not destroyed else arg.enabled) and arg.activeTween == activeTween and not arg:_hasConfirmedCarry(uid)) then
								break
							end
							pcall(fn62, uid, v11)
							task.wait(0.08)
						end
					end)
				end

				local n73 = math.max(math.min(deltaTime, n45), 0.004166666666666667)
				local n74 = routeCruiseY * n73
				local vector4 = Vector3.new(humanoidRootPart.CFrame.LookVector.X, 0, humanoidRootPart.CFrame.LookVector.Z)
				local unit = vector3.Magnitude > 0.001 and vector3.Unit or (vector4.Magnitude > 0.001 and vector4.Unit or Vector3.new(0, 0, -1))
				local routeCruiseY2 = activeTween.routeCruiseY

				if (if routeCruiseY2 then activeTween.travelPhase == "descend" else not routeCruiseY2) and magnitude <= math.max(n74, 0.05) then
					if magnitude > 0.5 then
						now = nil
					end

					arg:_syncHoverPad(arg2.Position)
					humanoidRootPart.CFrame = CFrame.lookAt(arg2.Position, arg2.Position + unit)
					humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					arg:_syncHoverPad(arg2.Position)
					fn83(humanoid, humanoidRootPart, n70, (Vector3.new(0, 0, 0)))
					now = now or os.clock()

					if os.clock() - now >= n50 then
						fn91(true)
					end

					return
				end

				now = nil

				if magnitude3 <= 0.001 then
					humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
					arg:_syncHoverPad(position)
					return
				end

				if arg.hoverPad then
					if not arg.hoverPad.Parent then
						arg:_startHoverPad()
					end
				else
					arg:_startHoverPad()
				end

				local n75 = math.min(n74, magnitude3)
				vector3, routeCruiseY2, routeCruiseY = position + n72.Unit * n75, n73 >= 0.03333333333333333

				if routeCruiseY2 then
					local routeCruiseY3 = activeTween.routeCruiseY
					routeCruiseY = if routeCruiseY3 then activeTween.travelPhase ~= "cruise" else not routeCruiseY3
				else
					routeCruiseY = routeCruiseY2
				end

				if routeCruiseY then
					local v11 = arg:_groundYAt(vector3.X, vector3.Z, character)

					if v11 then
						local n76 = v11 + arg:_feetOffset(humanoidRootPart, humanoid)
						vector3 = if vector3.Y < n76 then Vector3.new(vector3.X, n76, vector3.Z) else vector3
					end
				end

				magnitude, n74 = activeTween.zigzag

				if magnitude then
					local routeCruiseY3 = activeTween.routeCruiseY
					n74 = if routeCruiseY3 then activeTween.travelPhase == "cruise" else not routeCruiseY3
				else
					n74 = magnitude
				end

				if n74 then
					local vector5 = Vector3.new(n72.X, 0, n72.Z)

					if vector5.Magnitude > 1 then
						if magnitude2 > 12 then
							local unit2 = vector5.Unit
							local vector6 = Vector3.new(-unit2.Z, 0, unit2.X)
							magnitude3 = math.min(n59, magnitude2 * 0.3)
							local v11 = if magnitude2 < n61 then magnitude3 * (magnitude2 / n61) else magnitude3
							activeTween.zigT = (activeTween.zigT or 0) + n75
							local zigLast = v11 * math.sin(activeTween.zigT / n60 * 3.141592653589793 * 2)
							local n76 = zigLast - (activeTween.zigLast or 0)
							activeTween.zigLast = zigLast
							local n77 = vector3 + vector6 * n76

							if not activeTween.zigLaneMin then
								activeTween.zigLaneMin, activeTween.zigLaneMax = fn90()
							end

							local n78 = math.clamp(n77.Z, activeTween.zigLaneMin, activeTween.zigLaneMax)
							vector3 = if n78 ~= n77.Z then Vector3.new(n77.X, n77.Y, n78) else n77
						else
							activeTween.zigLast = 0
						end
					else
						activeTween.zigLast = 0
					end
				end

				local n76 = (vector3 - position) / n73
				arg:_syncHoverPad(vector3)
				humanoidRootPart.CFrame = CFrame.lookAt(vector3, vector3 + unit)
				humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				arg:_syncHoverPad(vector3)

				if not fn83(humanoid, humanoidRootPart, n70, n76) then
					fn82(humanoid, humanoidRootPart, n70)
					fn83(humanoid, humanoidRootPart, n70, n76)
				end
			end)
		end)
	end

	index._reStealDroppedEgg = function(arg, arg2)
		if type(arg2) ~= "string" then
			arg:_finish("Egg lost \226\128\148 retrying")
			return
		elseif arg2 == "" then
			arg:_finish("Egg lost \226\128\148 retrying")
			return
		end

		if arg:isSkippedEgg(arg2) then
			return
		end

		if arg.tweenRecoveryUid == arg2 then
			arg.running = false
			arg.activeTarget = nil
			arg:_releaseOperation()
			arg:_scheduleMovementRetry()
			return
		end

		local v8 = arg:_claimCarryWorker("re-steal", arg2)
		if not v8 then
			return
		end

		if genv.__FanKunHUBGodMode then
			genv.__FanKunHUBGodMode:startDefend(arg2)
		end

		local n68 = os.clock() + 5
		arg:_setStatus("Re-stealing dropped egg")
		local v9

		while arg:_isCarryWorkerCurrent(v8) and os.clock() < n68 do
			local v10 = EggState2.ReadFieldEgg(arg2) or arg.records[arg2]

			if v10 then
				if v10.State == AreaEggs.States.Dropped then
					v9 = v10
					break
				elseif v10.State == AreaEggs.States.Slot then
					v9 = v10
					break
				end
			end

			task.wait(0.03)
		end

		if not arg:_isCarryWorkerCurrent(v8) then
			return
		end

		if if v9 then not arg:_wallOpen() else not v9 then
			arg:_releaseCarryWorker(v8)
			arg:_finish("Egg lost \226\128\148 retrying")
			return
		end

		arg:_cancelTween("Re-stealing dropped egg", true)
		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		n68 = arg:_resolveEggDestination(v9, humanoidRootPart, humanoid)
		local v10 = n68 and arg:_resolveElevatedDestination(humanoidRootPart, n68) or nil

		if not v10 then
			arg:_releaseCarryWorker(v8)
			arg:_finish("Character unavailable")
			return
		end

		arg.running = true
		arg.activeTarget = v9
		arg:_setStatus("Bringing egg home")

		if arg:_regrabBurst(v8, v9.Uid, 3.5) then
			return
		elseif not arg:_isCarryWorkerCurrent(v8) then
			return
		end

		arg:_setStatus("Re-stealing egg")

		if not arg:_teleportRoot(humanoidRootPart, humanoid, v10) then
			arg:_releaseCarryWorker(v8)
			arg:_finish("Re-steal failed \226\128\148 retrying")
			return
		end

		arg:_setArrivalHold(v10, v9.Uid)
		arg:_setStatus("Re-stealing egg")

		if arg:_isCarryWorkerCurrent(v8) then
			arg:_requestCarry(v9, true)
		end
	end

	index._regrabBurst = function(arg, arg2, arg3, arg4)
		local function fn91()
			local v8 = EggState2.ReadFieldEgg(arg3)
			return v8 ~= nil and v8.State == AreaEggs.States.Carried and v8.CarrierUserId == localPlayer2.UserId
		end

		local RagdollJoints

		pcall(function()
			RagdollJoints = require(ReplicatedStorage2.Shared.Modules.RagdollJoints)
		end)

		local flag5 = false
		local flag6 = false
		local n68 = os.clock() + arg4

		while os.clock() < n68 and not arg.destroyed and (arg.enabled or arg._externalDeliver) do
			if fn91() then
				return true
			end

			if not arg:_isCarryWorkerCurrent(arg2) then
				return (fn91())
			end
			local v8 = EggState2.ReadFieldEgg(arg3)

			if v8 then
				if v8.State ~= AreaEggs.States.Dropped and v8.State ~= AreaEggs.States.Slot then
					return false
				end
			else
				return false
			end

			local character = localPlayer2.Character
			local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")

			if humanoidRootPart then
				if not humanoid then
					return false
				end
			else
				return false
			end

			pcall(function()
				if RagdollJoints and RagdollJoints.Release then
					RagdollJoints.Release(character)
				end

				humanoid.PlatformStand = false
				humanoid.Sit = false

				if humanoid:GetState() ~= Enum.HumanoidStateType.Running then
					humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
				end
			end)

			local v9 = arg:_resolveEggDestination(v8, humanoidRootPart, humanoid)

			if v9 then
				humanoidRootPart.CFrame = v9
				humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
				arg:_syncHoverPad(v9.Position)
			end

			if not flag5 then
				flag5 = true

				task.spawn(function()
					pcall(function()
						eggWorld.AskFieldEggCarry:InvokeServer({Uid = arg3})
					end)

					flag5 = false
				end)
			end

			if not flag6 then
				flag6 = true

				task.spawn(function()
					pcall(EggState2.CarryFieldEgg, arg3)
					flag6 = false
				end)
			end

			pcall(function()
				local areaEggSlotsClient = workspace:FindFirstChild("AreaEggSlotsClient")
				local v10 = areaEggSlotsClient and areaEggSlotsClient:FindFirstChild(tostring(arg3))
				local carryAreaEgg = v10 and (v10:FindFirstChild("CarryAreaEgg", true) or v10:FindFirstChildWhichIsA("ProximityPrompt", true))

				if carryAreaEgg and (carryAreaEgg.Enabled and type(fireproximityprompt) == "function") then
					carryAreaEgg.HoldDuration = 0
					carryAreaEgg.RequiresLineOfSight = false
					fireproximityprompt(carryAreaEgg, 0)
				end
			end)

			task.wait(0.06)
		end

		return (fn91())
	end

	index._recoverCarryConfirmationTimeout = function(arg, arg2, arg3)
		if arg.destroyed then
			return false
		elseif arg.enabled then
			if arg.carryAttemptToken ~= arg2 then
				return false
			elseif arg:_hasConfirmedCarry(arg3) then
				return false
			end
		else
			return false
		end

		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		arg2 = humanoidRootPart and arg:_resolveSafeCFrame(humanoidRootPart)
		local v8 = arg2 and arg:_resolveElevatedDestination(humanoidRootPart, arg2) or nil
		arg.carryTimeouts = arg.carryTimeouts or {}
		local n68 = (arg.carryTimeouts[arg3] or 0) + 1
		local flag5 = n68 >= n37

		if flag5 then
			arg.carryTimeouts[arg3] = nil
			arg.skippedEggs[arg3] = os.clock() + n38
			arg.tweenRecoveryUid = nil
		else
			arg.carryTimeouts[arg3] = n68
			local v9 = arg:_isPrimerEgg(arg3)
			arg.tweenRecoveryUid = (if v9 then not v9 else arg3) or nil
		end

		local lastCarryReject = arg.stats.lastCarryReject

		if type(lastCarryReject) == "string" and lastCarryReject:lower():find("inventory is full", 1, true) then
			arg.eggFullCount = arg:_eggCount() or 1 / 0
		end

		local v9 = arg.records[arg3] or EggState2.ReadFieldEgg(arg3)
		local flag6 = arg.config.stealMode == "Instant" and (arg3 == arg.primerUid or type(v9) == "table" and v9.AreaId == "Forest")
		arg.carry.generation += 1
		arg:_invalidateCarryWorker()
		arg.carryAttemptToken = nil
		arg:_clearArrivalHold(arg3)

		if arg.activeTween and arg.activeTween.Cancel then
			pcall(arg.activeTween.Cancel, arg.activeTween)
		end

		arg.activeTween = nil
		arg.running = true
		arg.activeTarget = nil
		arg.stats.lastResult = "Carry confirmation timeout"

		if humanoidRootPart and v8 then
			pcall(function()
				humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			end)

			arg:_setStatus("Carry timeout - returning to safe area")

			pcall(arg._glideRoot, arg, v8, function()
				return arg.destroyed or not arg.enabled
			end)

			if flag5 then
				arg:_setStatus(lastCarryReject and "Carry refused (" .. lastCarryReject .. ") \226\128\148 skipping egg" or "Carry timed out twice \226\128\148 skipping egg")
			else
				arg:_setStatus("Carry timeout \226\128\148 retrying")
			end
		else
			arg:_setStatus("Carry timeout \226\128\148 safe area unavailable")
		end

		arg.running = false
		arg:_releaseOperation()

		if flag6 then
			arg.running = true
		end

		task.delay(0.35, function()
			if flag6 then
				if not arg.destroyed and arg.enabled then
					arg:_setStatus("Retrying steal")

					pcall(arg._treadmillReset, arg, function()
						return arg.destroyed or not arg.enabled
					end)
				end

				arg.running = false
			end

			if not arg.destroyed and (arg.enabled and arg.carryAttemptToken == nil) then
				arg:_schedule()
			end
		end)

		return true
	end

	index._requestCarry = function(arg, arg2, arg3)
		if not arg:_wallOpen() then
			arg:_finish("Wall closed before carry")
			return
		end
		local uid, carryAttemptToken, n68 = arg2.Uid, {}
		arg.stats.lastCarryReject = nil
		local n69 = arg.instantPhase == "priming" and uid == arg.primerUid and n36 or math.max(n36, arg:_resolveSettleSeconds(arg2) + 3)
		arg.carryAttemptToken = carryAttemptToken
		arg.stats.lastResult = "Carry requested"
		arg:_setStatus("Securing egg")
		arg2 = localPlayer2.Character
		local humanoid = arg2 and arg2:FindFirstChildOfClass("Humanoid")

		if humanoid then
			pcall(humanoid.UnequipTools, humanoid)
		end

		if arg.coordinator then
			local n70 = os.clock() + 0.35

			while arg.coordinator:isBackgroundBusy() and not arg.destroyed and arg.enabled and arg.carryAttemptToken == carryAttemptToken and os.clock() < n70 do
				task.wait(0.02)
			end

			if humanoid and humanoid.Parent then
				pcall(humanoid.UnequipTools, humanoid)
			end
		end

		task.spawn(function()
			while true do
				local destroyed = arg.destroyed
				if not ((if destroyed then not destroyed else arg.enabled) and arg.running and arg.carryAttemptToken == carryAttemptToken and arg.activeTarget and arg.activeTarget.Uid == uid) then
					break
				end

				if not arg:_hasConfirmedCarry(uid) and arg:_recordShowsCarried(uid) then
					arg:_adoptCarryFromRecord(uid)
				end

				if arg:_hasConfirmedCarry(uid) then
					if arg:_recordShowsCarried(uid) then
						arg:_clearArrivalHold(uid)
						arg.carryAttemptToken = nil

						if arg.activeTween then
							pcall(arg.activeTween.Cancel, arg.activeTween)
							arg.activeTween = nil
						end

						if arg.instantPhase == "priming" and uid == arg.primerUid then
							arg.carry.active = true
							arg.carry.uid = uid
							arg.stats.lastResult = "Preparing steal"
							arg:_enterBaitWait()
							return
						end

						arg.carry.active = true
						arg.carry.uid = uid
						arg.stats.lastResult = "Carry confirmed"
						arg:_setStatus("Carry confirmed")

						task.defer(function()
							if not arg.destroyed and (arg.enabled and arg:_hasConfirmedCarry(uid)) then
								arg:_returnToSafe()
							end
						end)

						return
					end

					arg:_setStatus("Confirming carry record")
					task.wait(n35)
					continue
				end

				if n68 and os.clock() >= n68 then
					arg:_recoverCarryConfirmationTimeout(carryAttemptToken, uid)
					return
				end

				if not arg:_wallOpen() then
					arg:_finish("Wall closed before carry")
					return
				end
				local v8 = EggState2.ReadFieldEgg(uid) or arg.records[uid]
				if not v8 then
					arg:_finish("Target unavailable")
					return
				end

				if v8.State == AreaEggs.States.Carried then
					if v8.CarrierUserId == localPlayer2.UserId then
						arg:_setStatus("Confirming carry state")
						task.wait(n35)
						continue
					end

					arg:_finish("Egg carried by another player")
					return
				end

				if v8.State ~= AreaEggs.States.Slot and v8.State ~= AreaEggs.States.Dropped then
					arg:_finish("Target changed")
					return
				end
				local character = localPlayer2.Character
				local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
				if not humanoidRootPart then
					arg:_finish("Character unavailable")
					return
				end
				local humanoid2 = character and character:FindFirstChildOfClass("Humanoid")
				if not humanoid2 then
					arg:_finish("Character unavailable")
					return
				end
				local v9 = arg:_resolveEggDestination(v8, humanoidRootPart, humanoid2)
				local v10 = v9 and arg:_resolveElevatedDestination(humanoidRootPart, v9) or nil
				if not v10 then
					arg:_finish("Character unavailable")
					return
				end
				local position = v10.Position

				if (humanoidRootPart.Position - position).Magnitude > n39 then
					if arg3 then
						arg:_setStatus("Re-stealing egg")
						if not arg:_teleportRoot(humanoidRootPart, humanoid2, v10) then
							arg:_finish("Re-steal failed \226\128\148 retrying")
							return
						end
						arg:_setArrivalHold(v10, uid)
						arg:_setStatus("Re-stealing egg")
					else
						arg:_setStatus("Re-approaching egg")
						local flag5 = false

						arg:_tweenRoot(v9, function()
							flag5 = true

							if arg.carryAttemptToken == carryAttemptToken and not arg:_hasConfirmedCarry(uid) then
								arg:_setStatus("Securing egg")
							end
						end, nil, {holdAfterArrival = true, holdUid = uid, flightProfile = true})

						while true do
							local destroyed2 = arg.destroyed
							if not ((if destroyed2 then not destroyed2 else arg.enabled) and arg.carryAttemptToken == carryAttemptToken and not arg:_hasConfirmedCarry(uid) and not flag5) then
								break
							end
							task.wait(n35)
						end

						continue
					end
				end

				local v11 = AreaEggSlotIdentity.LooksLikeFirstAreaUid(v8.Uid) and AreaEggSlotIdentity.SlotKey(v8.AreaId, v8.NestId) or nil
				humanoidRootPart, character, position = pcall(fn62, v8.Uid, v11)
				local v12 = if humanoidRootPart then if character == true then nil else position else tostring(character)

				if v12 then
					arg.stats.lastCarryReject = v12

					if v12 ~= arg._lastCarryRejectLogged then
						arg._lastCarryRejectLogged = v12
						warn("[FanKunHUB] carry refused: " .. v12)
					end
				end

				n68 = n68 or os.clock() + n69
				arg.stats.lastResult = "Carry requested"
				arg:_setStatus(v12 and "Waiting for carry \194\183 " .. v12 or "Waiting for carry confirmation")
				task.wait(n35)
			end
		end)
	end

	index._burstHold = function(arg, cFrame, arg2)
		if typeof(cFrame) ~= "CFrame" then
			return false
		end
		local position = cFrame.Position

		local function fn91()
			local character = localPlayer2.Character
			return character and character:FindFirstChild("HumanoidRootPart")
		end

		local function fn92(arg3)
			arg3.CFrame = cFrame
			arg3.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			arg3.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end

		local n68 = os.clock() + n26

		while os.clock() < n68 do
			if arg2 and arg2() then
				return false
			end
			local v8 = fn91()

			if v8 then
				if not v8.Parent then
					return false
				end
			else
				return false
			end

			pcall(fn92, v8)
			RunService2.Heartbeat:Wait()
		end

		local n69, now = os.clock() + n27

		while os.clock() < n69 do
			if arg2 and arg2() then
				return false
			end
			n68 = fn91()

			if n68 then
				if not n68.Parent then
					return false
				end
			else
				return false
			end

			if (n68.Position - position).Magnitude > n28 then
				now = nil
			else
				if now then
					if os.clock() - now >= n29 then
						return true
					end
				else
					now = os.clock()
				end
			end

			pcall(fn92, n68)
			RunService2.Heartbeat:Wait()
		end

		local v8 = fn91()
		return v8 ~= nil and (v8.Position - position).Magnitude <= n28
	end

	local tbl16 = {["Titan Temple"] = true, ["Light Dark"] = true, ["Enchanted Forest"] = true, ["Cherry Blossom"] = true, Cosmic = true, Prehistoric = true, ["Abyss Ocean"] = true, Volcano = true, Snow = true, Jungle = true, Desert = true, Lake = true}
	local n68 = 200
	local n69 = 5000

	index._usesPortalBoost = function(arg, arg2)
		return fanKunHubConfig.LowSpeedBoost == true and arg.config.stealMode == "Instant" and type(arg2) == "table" and tbl16[arg2.AreaId] ~= nil and not (arg.portalBoostFailed and (arg.portalBoostFailed[arg2.Uid] or 0) > os.clock())
	end

	local function fn91(arg, arg2)
		local v8 = fn()
		local build = v8 and v8:FindFirstChild("Build")
		local v9 = build and build:FindFirstChild(arg)
		if not v9 then
			return nil
		end
		local basePart = arg2 and v9:FindFirstChild(arg2) or v9:FindFirstChildWhichIsA("BasePart", true)
		return basePart and basePart:IsA("BasePart") and basePart or nil
	end

	local function fn92()
		local attribute = localPlayer2:GetAttribute("RagdollEndTime")
		if type(attribute) ~= "number" then
			return 0
		end
		return math.max(attribute + 0.15 - workspace:GetServerTimeNow(), 0)
	end

	local function fn93(arg)
		local v8

		if type(arg) == "string" then
			local ok, result = pcall(function()
				return game:GetService("HttpService"):JSONDecode(arg)
			end)

			v8 = ok and result or nil
		else
			v8 = arg
		end

		if type(v8) ~= "table" then
			return nil
		end
		local arguments = v8.Arguments
		local vector3 = type(arguments) == "table" and type(arguments[3]) == "number" and Vector3.new(arguments[1], arguments[2], arguments[3]) or nil
		return v8.Action, vector3
	end

	index._watchRelocates = function(arg)
		if arg._relocateConn then
			return
		end
		local refresh = Remotes.RigSync and Remotes.RigSync.Refresh
		if not refresh then
			return
		end
		arg._relocateCount = 0

		arg._relocateConn = refresh.OnClientEvent:Connect(function(arg2)
			if fn93(arg2) == "Relocate" then
				arg._relocateCount = (arg._relocateCount or 0) + 1
				arg._relocateAt = os.clock()
			end
		end)
	end

	index._guardLagback = function(arg, arg2)
		local refresh = Remotes.RigSync and Remotes.RigSync.Refresh
		if not refresh then
			return
		end

		if not arg2 then
			for i, v8 in ipairs(arg._lagbackHooks or {}) do
				pcall(v8.forward.Disconnect, v8.forward)
				pcall(v8.connection.Enable, v8.connection)
			end

			arg._lagbackHooks = nil
			return
		end

		if arg._lagbackHooks then
			return
		elseif type(getconnections) ~= "function" then
			return
		end

		local lagbackHooks = {}
		arg._lagbackHooks = lagbackHooks
		local ok, result = pcall(getconnections, refresh.OnClientEvent)

		for i, v8 in ipairs(ok and type(result) == "table" and result or {}) do
			local function_ = v8.Function

			if type(function_) == "function" then
				i, arg = pcall(debug.info, function_, "s")

				if i and (tostring(arg):find("ContentCatalog", 1, true) and (type(v8.Disable) == "function" and pcall(v8.Disable, v8))) then
					local function fn94(arg3, ...)
						local v9, v10 = fn93(arg3)
						if v9 == "Relocate" and (v10 and v10.Y < n69) then
							return
						end
						function_(arg3, ...)
					end

					local connection6 = refresh.OnClientEvent:Connect(fn94)
					table.insert(lagbackHooks, {connection = v8, forward = connection6})
				end
			end
		end
	end

	index._crossPortal = function(arg, arg2, arg3, arg4)
		arg = localPlayer2.Character
		local humanoidRootPart = arg and arg:FindFirstChild("HumanoidRootPart")

		if not arg2 or not humanoidRootPart then
			return false
		elseif type(firetouchinterest) ~= "function" then
			return false
		end

		local position = humanoidRootPart.Position
		local n70 = os.clock() + (arg4 or 8)
		local n71 = n70 + 6
		local n72 = 0

		while os.clock() < n70 do
			if arg3 and arg3() then
				return false
			end
			local character = localPlayer2.Character
			humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
			if not humanoidRootPart then
				return false
			end

			if (humanoidRootPart.Position - position).Magnitude >= n68 then
				if position.Y > n69 ~= (humanoidRootPart.Position.Y > n69) then
					return true
				end
				position = humanoidRootPart.Position
			end

			local v8 = fn92()

			if v8 > 0 then
				n70 = math.min(math.max(n70, os.clock() + v8 + 1), n71)
			else
				if os.clock() - n72 >= 0.1 then
					n72 = os.clock()

					pcall(function()
						firetouchinterest(humanoidRootPart, arg2, 0)
						task.wait()
						firetouchinterest(humanoidRootPart, arg2, 1)
					end)
				end
			end

			task.wait(0.05)
		end

		return false
	end

	index._mutePortalFx = function(arg, arg2, arg3)
		local portalTransition = Remotes.FuseBiome and Remotes.FuseBiome.PortalTransition
		if not portalTransition then
			return
		end

		if arg2 then
			arg._portalFxMuteCount = (arg._portalFxMuteCount or 0) + 1

			if arg._portalFxMuted then
				return
			elseif type(getconnections) ~= "function" then
				return
			end

			arg._portalFxMuted = {}
			local ok, result = pcall(getconnections, portalTransition.OnClientEvent)

			for i, v8 in ipairs(ok and type(result) == "table" and result or {}) do
				local function_ = v8.Function

				if type(function_) == "function" then
					local ok2, result2 = pcall(debug.info, function_, "s")

					if ok2 and (tostring(result2):find("FuseBiomePortalController", 1, true) and (type(v8.Disable) == "function" and pcall(v8.Disable, v8))) then
						table.insert(arg._portalFxMuted, v8)
					end
				end
			end

			if #arg._portalFxMuted > 0 then
				arg._portalFxHandshake = portalTransition.OnClientEvent:Connect(function(arg4, arg5, arg6)
					if arg5 ~= nil and not arg6 then
						pcall(function()
							portalTransition:FireServer(arg5)
						end)
					end
				end)
			end

			arg:_filterPortalToasts(true)
		else
			arg._portalFxMuteCount = arg3 and 0 or math.max((arg._portalFxMuteCount or 0) - 1, 0)
			if arg._portalFxMuteCount > 0 then
				return
			end
			arg:_filterPortalToasts(false, arg3)

			for i, v8 in ipairs(arg._portalFxMuted or {}) do
				pcall(v8.Enable, v8)
			end

			arg._portalFxMuted = nil

			if arg._portalFxHandshake then
				pcall(arg._portalFxHandshake.Disconnect, arg._portalFxHandshake)
				arg._portalFxHandshake = nil
			end
		end
	end

	local tbl17 = {{"Toasts", "Line"}, {"Alerts", "Raise"}}

	index._filterPortalToasts = function(arg, arg2, arg3)
		if arg2 then
			arg._portalToastUntil = 1 / 0

			if arg._portalToastHooks then
				return
			elseif type(getconnections) ~= "function" then
				return
			end

			local portalToastHooks = {}
			arg._portalToastHooks = portalToastHooks

			for i, v8 in ipairs(tbl17) do
				local ok, result = pcall(function()
					return Remotes[v8[1]][v8[2]]
				end)

				local v9 = if ok then result else nil
				i, ok = false

				if v9 then
					i, ok = pcall(getconnections, v9.OnClientEvent)
				end

				for i2, v10 in ipairs(i and type(ok) == "table" and ok or {}) do
					local function_ = v10.Function

					if type(function_) == "function" and (type(v10.Disable) == "function" and pcall(v10.Disable, v10)) then
						local function fn94(arg4, ...)
							local body = type(arg4) == "table" and (arg4.Body or arg4.Text)
							if type(body) == "string" and (body:lower():find("portal", 1, true) and os.clock() < (arg._portalToastUntil or 0)) then
								return
							end
							function_(arg4, ...)
						end

						local connection6 = v9.OnClientEvent:Connect(fn94)
						table.insert(portalToastHooks, {connection = v10, forward = connection6})
					end
				end
			end

			return
		end

		local function fn94()
			local portalToastHooks = arg._portalToastHooks
			arg._portalToastHooks = nil

			for i, v8 in ipairs(portalToastHooks or {}) do
				pcall(v8.forward.Disconnect, v8.forward)
				pcall(v8.connection.Enable, v8.connection)
			end
		end

		if arg3 then
			fn94()
			return
		end
		local portalToastUntil = os.clock() + 2
		arg._portalToastUntil = portalToastUntil

		task.delay(2.1, function()
			if arg._portalToastUntil == portalToastUntil then
				local portalFxMuteCount = arg._portalFxMuteCount

				if portalFxMuteCount then
					if portalFxMuteCount == 0 then
						fn94()
					end
				else
					fn94()
				end
			end
		end)
	end

	index._portalBoostSteal = function(arg, arg2)
		arg:_mutePortalFx(true)
		arg._boostHopUid = arg2.Uid
		local ok, result = pcall(arg._portalBoostHop, arg, arg2)
		arg:_guardLagback(false)

		if arg._boostHopUid == arg2.Uid then
			arg._boostHopUid = nil
		end

		if arg._treeHopUid == arg2.Uid then
			arg._treeHopUid = nil
		end

		arg:_mutePortalFx(false)
		arg:_muteTreeFx(false)

		if not ok then
			warn("[FanKunHUB] steal error: " .. tostring(result))

			if not arg.destroyed and arg.enabled then
				arg:_finish("Steal error \226\128\148 retrying")
			end
		end
	end

	index._muteTreeFx = function(arg, arg2)
		if type(getconnections) ~= "function" then
			return
		end

		if arg2 then
			arg._treeFxToken = (arg._treeFxToken or 0) + 1
			if arg._treeFxMuted then
				return
			end
			arg._treeFxMuted = {}
			local transition = Remotes.EnchantedTree and Remotes.EnchantedTree.Transition

			for i, v8 in ipairs({{transition and transition.OnClientEvent, "EnchantedTreeController"}, {localPlayer2:GetAttributeChangedSignal("InEnchantedTree"), "EnchantedTreeController"}}) do
				i, transition = false

				if v8[1] then
					i, transition = pcall(getconnections, v8[1])
				end

				for i2, v9 in ipairs(i and type(transition) == "table" and transition or {}) do
					local function_ = v9.Function

					if type(function_) == "function" then
						local ok, result = pcall(debug.info, function_, "s")

						if ok and (tostring(result):find(v8[2], 1, true) and (type(v9.Disable) == "function" and pcall(v9.Disable, v9))) then
							table.insert(arg._treeFxMuted, v9)
						end
					end
				end
			end
		else
			if not arg._treeFxMuted then
				return
			end
			local treeFxToken = arg._treeFxToken

			task.spawn(function()
				local n70 = os.clock() + 12

				while os.clock() < n70 and (localPlayer2:GetAttribute("InEnchantedTree") == true or arg._treePromptAt and os.clock() - arg._treePromptAt < 2.5) do
					task.wait(0.1)
				end

				task.wait(1.5)
				if arg._treeFxToken ~= treeFxToken then
					return
				end

				for i, v8 in ipairs(arg._treeFxMuted or {}) do
					pcall(v8.Enable, v8)
				end

				arg._treeFxMuted = nil
			end)
		end
	end

	index._isStealPrompt = function(arg, arg2)
		if typeof(arg2) ~= "Instance" then
			return false
		end

		if arg2.Name == "EnchantedTreePrompt" then
			return true
		end
		local areaEggSlotsClient = workspace:FindFirstChild("AreaEggSlotsClient")
		if areaEggSlotsClient and arg2:IsDescendantOf(areaEggSlotsClient) then
			return true
		end

		if arg2:FindFirstAncestor("FuseBiomeLanePortals") then
			return true
		elseif arg2:FindFirstAncestor("FuseBiomeZone") then
			return true
		end

		return false
	end

	index._installPromptFilter = function(arg)
		if arg._promptFilter then
			return
		elseif type(getconnections) ~= "function" then
			return
		end

		local promptFilter = {muted = {}, forwarders = {}}
		arg._promptFilter = promptFilter

		local function fn94()
			local destroyed = arg.destroyed
			return if destroyed then not destroyed else arg.enabled or arg._externalDeliver or arg._recalling or arg._treeFxMuted ~= nil
		end

		for i, v8 in ipairs({ProximityPromptService.PromptShown, ProximityPromptService.PromptHidden}) do
			local ok, result = pcall(getconnections, v8)

			for i2, v9 in ipairs(ok and type(result) == "table" and result or {}) do
				local function_ = v9.Function

				if type(function_) == "function" then
					i, i2 = pcall(debug.info, function_, "s")

					if i and (tostring(i2):find("ProximityPromptScriptController", 1, true) and (type(v9.Disable) == "function" and pcall(v9.Disable, v9))) then
						table.insert(promptFilter.muted, v9)

						table.insert(promptFilter.forwarders, v8:Connect(function(arg2, ...)
							if fn94() and arg:_isStealPrompt(arg2) then
								return
							end
							function_(arg2, ...)
						end))
					end
				end
			end
		end

		pcall(function()
			local machines = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Machines")
			local fuseMachine = machines and machines:FindFirstChild("FuseMachine")
			local proximityPrompt = fuseMachine and fuseMachine:FindFirstChildWhichIsA("ProximityPrompt", true)
			if not proximityPrompt then
				return
			end
			local ok, result = pcall(getconnections, proximityPrompt.Triggered)

			for i, v8 in ipairs(ok and type(result) == "table" and result or {}) do
				local function_ = v8.Function

				if type(function_) == "function" and (type(v8.Disable) == "function" and pcall(v8.Disable, v8)) then
					table.insert(promptFilter.muted, v8)

					table.insert(promptFilter.forwarders, proximityPrompt.Triggered:Connect(function(...)
						if fn94() then
							return
						end
						function_(...)
					end))
				end
			end
		end)
	end

	index._removePromptFilter = function(arg)
		local promptFilter = arg._promptFilter
		if not promptFilter then
			return
		end
		arg._promptFilter = nil

		for i, forwarder in ipairs(promptFilter.forwarders) do
			pcall(forwarder.Disconnect, forwarder)
		end

		for i, v8 in ipairs(promptFilter.muted) do
			pcall(v8.Enable, v8)
		end
	end

	index._leaveTreeHidden = function(arg, arg2)
		local enchantedTreeInterior = fn()
		local build = enchantedTreeInterior and enchantedTreeInterior:FindFirstChild("Build")
		enchantedTreeInterior = build and build:FindFirstChild("EnchantedTreeInterior")
		local markers = enchantedTreeInterior and enchantedTreeInterior:FindFirstChild("Markers")
		local exitTrigger = markers and markers:FindFirstChild("ExitTrigger")
		local n70 = os.clock() + 2.5

		while localPlayer2:GetAttribute("InEnchantedTree") ~= true and arg._treePromptAt and os.clock() - arg._treePromptAt < 2.5 and os.clock() < n70 do
			task.wait(0.05)
		end

		local n71 = os.clock() + 10

		while localPlayer2:GetAttribute("InEnchantedTree") == true and os.clock() < n71 do
			if arg2 and arg2() then
				break
			end
			local character = localPlayer2.Character
			local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")

			if humanoidRootPart and exitTrigger then
				pcall(firetouchinterest, humanoidRootPart, exitTrigger, 0)
				task.wait()
				pcall(firetouchinterest, humanoidRootPart, exitTrigger, 1)
			end

			task.wait(0.2)
		end

		return localPlayer2:GetAttribute("InEnchantedTree") ~= true
	end

	index._usesTreeBoost = function(arg, arg2)
		return false
	end

	index._treeBoostHop = function(arg, arg2)
		local uid = arg2.Uid
		local v8 = fn()
		local build = v8 and v8:FindFirstChild("Build")
		local enchantedTreeInterior = build and build:FindFirstChild("EnchantedTreeInterior")
		local markers = enchantedTreeInterior and enchantedTreeInterior:FindFirstChild("Markers")
		local enterTrigger = markers and markers:FindFirstChild("EnterTrigger")
		local enchantedTreePrompt = enterTrigger and enterTrigger:FindFirstChild("EnchantedTreePrompt", true)
		local exitTrigger = markers and markers:FindFirstChild("ExitTrigger")

		local function fn94()
			return arg.destroyed or not arg.enabled or arg.instantPhase ~= "hunting" or not arg.activeTarget or arg.activeTarget.Uid ~= uid
		end

		local function fn95()
			local character = localPlayer2.Character
			return character and character:FindFirstChild("HumanoidRootPart"), character and character:FindFirstChildOfClass("Humanoid")
		end

		local function fn96()
			return localPlayer2:GetAttribute("InEnchantedTree") == true
		end

		local function fn97()
			local n70 = os.clock() + 8

			while fn96() and os.clock() < n70 do
				local v9 = fn95()

				if v9 and exitTrigger then
					pcall(firetouchinterest, v9, exitTrigger, 0)
					task.wait()
					pcall(firetouchinterest, v9, exitTrigger, 1)
				end

				task.wait(0.2)
			end

			return not fn96()
		end

		local function fn98(arg3)
			fn97()
			if fn94() then
				return
			end
			arg.treeBoostFailed = arg.treeBoostFailed or {}
			arg.treeBoostFailed[uid] = os.clock() + 60
			arg:_finish(arg3)
		end

		build, arg2 = fn95()

		if enchantedTreePrompt and exitTrigger then
			if build then
				if not arg2 then
					fn98("Steal unavailable \226\128\148 retrying")
					return
				end
			else
				fn98("Steal unavailable \226\128\148 retrying")
				return
			end
		else
			fn98("Steal unavailable \226\128\148 retrying")
			return
		end

		local parent = enchantedTreePrompt.Parent
		local worldPosition = parent and (parent:IsA("Attachment") and parent.WorldPosition or parent:IsA("BasePart") and parent.Position)
		if not worldPosition then
			fn98("Steal unavailable \226\128\148 retrying")
			return
		end
		parent = os.clock() + 4

		while fn92() > 0 and os.clock() < parent do
			if fn94() then
				return
			end
			task.wait(0.05)
		end

		arg:_clearArrivalHold(uid)
		arg:_stopHoverPad()
		arg:_setStatus("Heading to target egg")
		arg._treeHopUid = uid
		arg:_muteTreeFx(true)
		arg:_teleportRoot(build, arg2, CFrame.new(worldPosition + Vector3.new(0, 1, 4)))
		local n70 = (tonumber(enchantedTreePrompt.HoldDuration) or 0) + 0.05
		local n71 = os.clock() + 6

		while true do
			local v9 = fn96()
			if not (if v9 then not v9 else os.clock() < n71) then
				break
			end

			if fn94() then
				return
			end

			pcall(function()
				enchantedTreePrompt.Enabled = true
			end)

			arg._treePromptAt = os.clock()

			pcall(function()
				enchantedTreePrompt:InputHoldBegin()
				task.wait(n70)
				enchantedTreePrompt:InputHoldEnd()
			end)

			if type(fireproximityprompt) == "function" then
				pcall(fireproximityprompt, enchantedTreePrompt, n70)
			end

			task.wait(0.1)
		end

		if not fn96() then
			fn98("Could not reach the egg \226\128\148 retrying")
			return
		end
		arg:_setStatus("Securing target egg")
		task.wait(0.3)
		if not fn97() then
			fn98("Could not reach the egg \226\128\148 retrying")
			return
		end

		if fn94() then
			return
		end
		parent, arg2 = fn95()

		if parent then
			if not arg2 then
				fn98("Character unavailable")
				return
			end
		else
			fn98("Character unavailable")
			return
		end

		local v9 = EggState2.ReadFieldEgg(uid) or arg.records[uid]

		if v9 then
			if v9.State ~= AreaEggs.States.Slot and v9.State ~= AreaEggs.States.Dropped then
				arg:_finish("Target egg no longer available")
				return
			end
		else
			arg:_finish("Target egg no longer available")
			return
		end

		local v10 = arg:_resolveEggDestination(v9, parent, arg2)
		if not v10 then
			fn98("Target destination unavailable")
			return
		end
		arg:_walkTo(v10, fn94, 4)
		if fn94() then
			return
		end
		parent, arg2 = fn95()
		local flag5 = not parent

		if if parent then not arg2 else flag5 then
			fn98("Could not reach the egg \226\128\148 retrying")
			return
		elseif (parent.Position - v10.Position).Magnitude > 25 then
			fn98("Could not reach the egg \226\128\148 retrying")
			return
		end

		arg:_setArrivalHold(v10, uid)
		arg.boostedUid = uid
		arg.treeBoostedUid = uid

		task.spawn(function()
			pcall(function()
				eggWorld.AskFieldEggCarry:InvokeServer({Uid = uid})
			end)
		end)

		arg:_setStatus("Securing target egg")
		arg:_requestCarry(v9, true)
	end

	index._portalBoostHop = function(arg, arg2)
		local uid = arg2.Uid
		if arg:_usesTreeBoost(arg2) then
			return arg:_treeBoostHop(arg2)
		end
		local FuseBiomeLanePortals = fn91("FuseBiomeLanePortals")
		local FuseBiomeZone = fn91("FuseBiomeZone", "ExitPart")

		local function fn94()
			return arg.destroyed or not arg.enabled or arg.instantPhase ~= "hunting" or not arg.activeTarget or arg.activeTarget.Uid ~= uid
		end

		local function fn95()
			local character = localPlayer2.Character
			return character and character:FindFirstChild("HumanoidRootPart"), character and character:FindFirstChildOfClass("Humanoid")
		end

		local function fn96()
			local v8 = fn95()

			if v8 and v8.Position.Y > n69 then
				arg:_crossPortal(FuseBiomeZone, nil, 8)
			end
		end

		local function fn97(arg3)
			fn96()
			if fn94() then
				return
			end
			arg.portalBoostMisses = arg.portalBoostMisses or {}
			local n70 = (arg.portalBoostMisses[uid] or 0) + 1
			arg.portalBoostMisses[uid] = n70

			if n70 >= 2 then
				arg.portalBoostMisses[uid] = nil
				arg.portalBoostFailed = arg.portalBoostFailed or {}
				arg.portalBoostFailed[uid] = os.clock() + 60
			end

			arg:_finish(arg3)
		end

		local v8, v9 = fn95()

		if FuseBiomeLanePortals then
			if not FuseBiomeZone then
				fn97("Steal unavailable \226\128\148 retrying")
				return
			elseif v8 then
				if not v9 then
					fn97("Steal unavailable \226\128\148 retrying")
					return
				end
			else
				fn97("Steal unavailable \226\128\148 retrying")
				return
			end
		else
			fn97("Steal unavailable \226\128\148 retrying")
			return
		end

		local v10 = arg:_resolveEggDestination(arg2, v8, v9)
		if not v10 then
			fn97("Target destination unavailable")
			return
		end
		arg:_setStatus("Heading to target egg")
		arg:_guardLagback(true)
		RunService2.PreSimulation:Wait()
		v9.PlatformStand = true
		arg:_teleportRoot(v8, v9, v10)
		RunService2.PreSimulation:Wait()
		v9.PlatformStand = false
		local n70 = 0.1

		pcall(function()
			n70 = localPlayer2:GetNetworkPing() or 0.1
		end)

		task.wait(math.clamp(0.15 + n70 * 2.5, 0.3, 1))
		if fn94() then
			return
		end
		arg:_stopHoverPad()
		arg:_setStatus("Securing target egg")
		local v11 = arg:_crossPortal(FuseBiomeLanePortals, fn94, 6)
		arg:_guardLagback(false)
		if not v11 then
			fn97("Could not reach the egg \226\128\148 retrying")
			return
		end
		arg:_setStatus("Securing target egg")
		if not arg:_crossPortal(FuseBiomeZone, fn94, 8) then
			fn97("Could not reach the egg \226\128\148 retrying")
			return
		end

		if fn94() then
			return
		end
		v9, FuseBiomeLanePortals = fn95()

		if v9 then
			if not FuseBiomeLanePortals then
				fn97("Character unavailable")
				return
			end
		else
			fn97("Character unavailable")
			return
		end

		if (v9.Position - v10.Position).Magnitude > 25 then
			fn97("Could not reach the egg \226\128\148 retrying")
			return
		end
		local v12 = EggState2.ReadFieldEgg(uid) or arg.records[uid]

		if v12 then
			if v12.State ~= AreaEggs.States.Slot and v12.State ~= AreaEggs.States.Dropped then
				arg:_finish("Target egg no longer available")
				return
			end
		else
			arg:_finish("Target egg no longer available")
			return
		end

		local v13 = arg:_resolveEggDestination(v12, v9, FuseBiomeLanePortals) or v10
		arg:_teleportRoot(v9, FuseBiomeLanePortals, v13)
		arg:_setArrivalHold(v13, uid)
		arg.boostedUid = uid
		arg:_setStatus("Securing target egg")
		task.wait(0.35)
		if fn94() then
			return
		end

		task.spawn(function()
			pcall(function()
				eggWorld.AskFieldEggCarry:InvokeServer({Uid = uid})
			end)
		end)

		arg:_requestCarry(v12, true)
	end

	index._needsHiddenRecall = function(arg)
		if arg.destroyed then
			return false
		end
		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then
			return false
		end

		if humanoidRootPart.Position.Y > n69 then
			return true
		end

		if localPlayer2:GetAttribute("InEnchantedTree") == true then
			return true
		end

		if arg._treePromptAt and os.clock() - arg._treePromptAt < 2.5 then
			return true
		end

		if arg._treeHopUid ~= nil then
			return true
		end
		return arg.treadmillDecoy ~= nil and arg.treadmillDecoy.Parent ~= nil and not arg:_isInSafeArea(humanoidRootPart)
	end

	index._finishBoostedEgg = function(arg, arg2)
		local v8 = EggState2.ReadFieldEgg(arg2) or arg.records[arg2]

		if v8 then
			if v8.State ~= AreaEggs.States.Slot and v8.State ~= AreaEggs.States.Dropped then
				return false
			end
		else
			return false
		end

		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local flag5 = humanoidRootPart and humanoid and arg:_resolveEggDestination(v8, humanoidRootPart, humanoid)

		if flag5 then
			if (humanoidRootPart.Position - flag5.Position).Magnitude > 25 then
				return false
			end
		else
			return false
		end

		arg:_setArrivalHold(flag5, arg2)
		arg:_setStatus("Finishing target egg")

		local function fn94()
			local v9 = EggState2.ReadFieldEgg(arg2)
			return v9 ~= nil and v9.State == AreaEggs.States.Carried and v9.CarrierUserId == localPlayer2.UserId
		end

		local n70 = os.clock() + 3
		flag5 = false

		while (if flag5 then not flag5 else os.clock() < n70) and not arg.destroyed and not arg.enabled do
			task.spawn(function()
				pcall(function()
					eggWorld.AskFieldEggCarry:InvokeServer({Uid = arg2})
				end)
			end)

			local n71 = os.clock() + 0.25

			while os.clock() < n71 do
				if fn94() then
					flag5 = true
					break
				end
				task.wait(0.03)
			end
		end

		arg:_clearArrivalHold(arg2)

		if flag5 then
			if arg.destroyed then
				return false
			elseif arg.enabled then
				return false
			end
		else
			return false
		end

		arg.boostedUid = nil
		if not arg:deliverCarriedEgg(arg2, v8) then
			return false
		end
		local n71 = os.clock() + 30

		while arg._instantReturnToken ~= nil and os.clock() < n71 and not arg.destroyed do
			task.wait(0.1)
		end

		arg.boostedUid = nil
		local v9 = EggState2.ReadFieldEgg(arg2)
		local flag6 = v9 == nil or v9.State == AreaEggs.States.Claimed or fanKunHubConfig.HelpFriend and v9.State == AreaEggs.States.Dropped
		local character2 = localPlayer2.Character
		local humanoidRootPart2 = character2 and character2:FindFirstChild("HumanoidRootPart")
		return flag6 and humanoidRootPart2 ~= nil and arg:_isInSafeArea(humanoidRootPart2)
	end

	index._finishTreeEgg = function(arg, treeBoostedUid)
		local v8 = EggState2.ReadFieldEgg(treeBoostedUid) or arg.records[treeBoostedUid]

		if v8 then
			if v8.State ~= AreaEggs.States.Slot and v8.State ~= AreaEggs.States.Dropped then
				return false
			end
		else
			return false
		end

		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local v9 = humanoidRootPart and humanoid and arg:_resolveEggDestination(v8, humanoidRootPart, humanoid)

		if v9 then
			if (humanoidRootPart.Position - v9.Position).Magnitude > 400 then
				return false
			end
		else
			return false
		end

		arg:_setStatus("Finishing target egg")
		local externalDeliver = arg._externalDeliver
		arg._externalDeliver = true

		arg:_walkTo(v9, function()
			return arg.destroyed or arg.enabled
		end, 4)

		arg._externalDeliver = externalDeliver

		if arg.destroyed then
			return false
		elseif arg.enabled then
			return false
		end

		arg.treeBoostedUid = treeBoostedUid
		return arg:_finishBoostedEgg(treeBoostedUid)
	end

	index._recallHidden = function(arg)
		arg._recalling = true
		local boostHopUid = arg._boostHopUid
		local treeHopUid = arg._treeHopUid

		task.spawn(function()
			local function fn94()
				return arg.destroyed or arg.enabled
			end

			local ok, result = pcall(function()
				arg:_startMovementProtection()
				arg:_mutePortalFx(true)
				local flag5 = localPlayer2:GetAttribute("InEnchantedTree") == true or arg._treePromptAt ~= nil and os.clock() - arg._treePromptAt < 2.5

				if flag5 or treeHopUid then
					arg:_muteTreeFx(true)
					arg:_setStatus("Finishing target egg")
					local flag6 = arg:_leaveTreeHidden(fn94) and not fn94() and treeHopUid ~= nil and arg:_finishTreeEgg(treeHopUid)
					arg:_muteTreeFx(false)

					if flag6 then
						return
					elseif fn94() then
						return
					end
				end

				local character = localPlayer2.Character
				local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
				local flag6 = (if flag5 then not flag5 else humanoidRootPart ~= nil) and humanoidRootPart.Position.Y > n69

				if flag6 then
					arg:_setStatus("Returning to safe area")
					arg:_crossPortal(fn91("FuseBiomeZone", "ExitPart"), fn94, 8)
				end

				if fn94() then
					return
				end

				if flag6 and (boostHopUid and arg:_finishBoostedEgg(boostHopUid)) then
					return
				end
				local flag7 = false

				local function fn95()
					for i, v8 in ipairs(EggState2.ReadFieldEggs().Records or {}) do
						if v8.State == AreaEggs.States.Carried and v8.CarrierUserId == localPlayer2.UserId then
							flag7 = true
							break
						end
					end
				end

				pcall(fn95)

				if flag7 then
					pcall(EggState2.DropFieldEgg, "PlayerRequest")
					task.wait(0.3)
				end

				local character2 = localPlayer2.Character
				local humanoidRootPart2 = character2 and character2:FindFirstChild("HumanoidRootPart")

				if humanoidRootPart2 and (not arg:_isInSafeArea(humanoidRootPart2) and not fn94()) then
					arg:_setStatus("Returning to safe area")
					local v8 = arg:_resolveSafeCFrame(humanoidRootPart2)
					local externalDeliver = arg._externalDeliver
					arg._externalDeliver = true

					if v8 then
						arg:_glideRoot(v8, fn94)
					end

					arg._externalDeliver = externalDeliver

					if not fn94() then
						arg:_groundSnap()
					end
				end
			end)

			if not ok then
				warn("[FanKunHUB] hidden recall error: " .. tostring(result))
			end

			arg:_mutePortalFx(false)
			arg._recalling = nil

			if not arg.destroyed and not arg.enabled then
				arg:_hideTreadmillDecoy()
				arg:_removeGuardHitDistanceBoost()
				arg:_stopMovementProtection()
				fn68(arg)
				arg:_setStatus("Idle")
			end
		end)
	end

	index._treadmillReset = function(arg, arg2)
		arg._treadmillResetting = true
		local ok, result = pcall(arg._treadmillResetInner, arg, arg2)
		arg._treadmillResetting = false
		return ok and result
	end

	index._treadmillResetInner = function(arg, arg2)
		local function fn94()
			return arg2 ~= nil and arg2()
		end

		local treadmill = Remotes and Remotes.Treadmill
		if not treadmill or fn94() then
			return false
		end

		local function fn95()
			local ok, result = pcall(function()
				return treadmill.AskRenderSnapshot:InvokeServer()
			end)

			if ok then
				if type(result) ~= "table" then
					return nil
				end
			else
				return nil
			end

			return table.find(result, localPlayer2.UserId) ~= nil
		end

		local flag5 = (function()
			local ok, result = pcall(function()
				local flag5 = type(PlotState2.ResolveLocalSlot) == "function" and PlotState2.ResolveLocalSlot() or PlotState2.GetMySlot()
				local flag6 = type(PlotState2.ResolveFolder) == "function" and PlotState2.ResolveFolder() or PlotState2.GetPlotsFolder()
				local v8 = flag6 and flag5 and flag6:FindFirstChild(tostring(flag5))
				local treadmillBottom = v8 and v8:FindFirstChild("TreadmillBottom")

				if treadmillBottom then
					if not treadmillBottom:IsA("BasePart") then
						return nil
					end
				else
					return nil
				end

				local character = localPlayer2.Character
				local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")

				if humanoidRootPart then
					if not humanoid then
						return nil
					end
				else
					return nil
				end

				local n70 = humanoid.RigType == Enum.HumanoidRigType.R15 and humanoidRootPart.Size.Y * 0.5 + math.max(humanoid.HipHeight, 0.5) or humanoidRootPart.Size.Y * 0.5 + 2
				return treadmillBottom.CFrame * CFrame.new(0, treadmillBottom.Size.Y * 0.5 + n70 + 0.05, 0)
			end)

			return ok and result or nil
		end)()

		if flag5 then
			if fn94() then
				return false
			end
		else
			return false
		end

		arg:_glideRoot(flag5, function()
			return fn94()
		end)

		if fn94() then
			return false
		end
		arg = os.clock() + 0.7
		flag5 = false

		while true do
			local v8 = fn94()
			if not (if v8 then not v8 else os.clock() < arg) then
				break
			end

			pcall(function()
				treadmill.AskWearStill:InvokeServer()
			end)

			task.wait(0.08)
			if fn95() == true then
				flag5 = true
				break
			end
		end

		if flag5 then
			local n70 = os.clock() + 0.25

			while true do
				local v8 = fn94()
				if not (if v8 then not v8 else os.clock() < n70) then
					break
				end
				task.wait(0.05)
			end
		end

		local n70 = os.clock() + 0.7
		local flag6 = false

		while true do
			local v8 = fn94()
			if not (if v8 then not v8 else os.clock() < n70) then
				break
			end

			pcall(function()
				treadmill.AskDoff:InvokeServer()
			end)

			task.wait(0.08)
			if fn95() == false then
				flag6 = true
				break
			end
		end

		return flag5 and flag6
	end

	index._instantReturn = function(arg, forestDropInProgress)
		if arg._instantReturnToken ~= nil then
			return
		end
		local instantReturnToken = {}
		arg._instantReturnToken = instantReturnToken
		arg._flyDeparting = false

		if arg.config.stealMode == "Fly" then
			-- Mode Run: JANGAN tampilkan decoy di titik aman. Karakter asli dibiarkan terlihat
			-- selama return; kalau ada decoy sisa (mis. dari boost), hapus supaya karakter asli muncul lagi.
			if arg.treadmillDecoy then
				pcall(arg._hideTreadmillDecoy, arg, true)
			end
		end

		task.spawn(function()
			local function fn94()
				local destroyed = arg.destroyed
				return (if destroyed then not destroyed else arg.enabled or arg._externalDeliver) and arg._instantReturnToken == instantReturnToken
			end

			local function fn95()
				local character = localPlayer2.Character
				return character and character:FindFirstChild("HumanoidRootPart"), character and character:FindFirstChildOfClass("Humanoid")
			end

			local function fn96()
				return EggState2.ReadFieldEgg(forestDropInProgress)
			end

			local function fn97()
				local v8 = fn96()
				return v8 ~= nil and v8.State == AreaEggs.States.Carried and v8.CarrierUserId == localPlayer2.UserId
			end

			local function fn98()
				local v8 = fn96()
				if not v8 then
					return true
				end
				return v8.State == AreaEggs.States.Claimed
			end

			local function fn99()
				local v8 = fn95()
				return v8 and arg:_resolveSafeCFrame(v8) or nil
			end

			local function fn100(arg2)
				arg.settleBonus = arg.settleBonus or {}

				if arg2 then
					arg.settleBonus[forestDropInProgress] = nil
				elseif arg.config.stealMode == "Instant" then
					if arg.boostedUid ~= forestDropInProgress then
						local settleBonus = arg.settleBonus
						local tbl18 = {seconds = n23}
						tbl18.untilAt, settleBonus[forestDropInProgress] = os.clock() + 300, tbl18
					end
				end
			end

			local function fn101(arg2)
				if arg._instantReturnToken ~= instantReturnToken then
					return
				end
				fn100(arg2 == nil or arg2 == "Safe return complete")
				arg._instantReturnToken = nil
				arg._forestDropInProgress = nil
				local externalDeliver = arg._externalDeliver
				arg._externalDeliver = nil
				if arg.destroyed then
					return
				end

				if arg.enabled then
					arg:_reportStolen()
					arg:_finish(arg2 or "Safe return complete")
				elseif externalDeliver then
					arg:_reportStolen()
					arg.carry.active = false
					arg.carry.uid = nil
					arg.activeTarget = nil
					arg:_hideTreadmillDecoy()
				end
			end

			arg:_clearArrivalHold(forestDropInProgress)
			local treeRegrabMode = arg.treeBoostedUid == forestDropInProgress and (arg.treeRegrabMode or "walk") or "glide"

			local function fn102()
				local v8 = fn95()
				return v8 ~= nil and arg:_isInSafeArea(v8)
			end

			local function fn103(arg2, arg3, arg4)
				return arg:_walkTo(arg2, arg3, arg4 or 4)
			end

			local function fn104(arg2, arg3, arg4, arg5)
				local flag5 = treeRegrabMode == "walk" or arg5 == "egg" and (treeRegrabMode == "glideSafe" or treeRegrabMode == "skipSafe") or arg5 == "safe" and treeRegrabMode == "glideEgg"

				if flag5 and arg5 == "safe" then
					local function fn105()
						return arg3() or fn102()
					end

					return arg:_walkTo(arg2, fn105, arg4 or 4)
				end

				if flag5 then
					return arg:_walkTo(arg2, arg3, arg4 or 4)
				end
				return arg:_glideRoot(arg2, arg3)
			end

			local flag5 = arg.config.stealMode == "Fly" or arg.boostedUid == forestDropInProgress and not fanKunHubConfig.HelpFriend
			local n70 = arg.boostedUid == forestDropInProgress and not fanKunHubConfig.HelpFriend and 0.3 or flag5 and 0.15 or 0.4
			-- Run mode: jumlah siklus drop -> re-grab saat return dapat diatur dari UI.
			local runDropRounds = math.clamp(math.floor((tonumber(fanKunHubConfig.RunDropCount) or index.RELAY_ROUNDS) + 0.5), 0, 10)
			local n71 = flag5 and 0.45 or n22
			local v8 = fn97()

			if v8 then
			else
				arg:_setStatus("Confirming carry record")
				local n72 = os.clock() + 2.5

				while fn94() and os.clock() < n72 do
					v8 = fn97()
					if v8 then
						break
					end
					local v9 = fn96()
					if v9 and v9.State == AreaEggs.States.Claimed then
						break
					end
					RunService2.Heartbeat:Wait()
				end

				if not fn94() then
					return
				end
			end

			if v8 then
				arg._forestDropInProgress = forestDropInProgress

				if runDropRounds > 0 then
				for i = 1, runDropRounds, 1 do
					arg._forestDropInProgress = forestDropInProgress
					arg:_setStatus("Bringing egg home")

					arg:_hopRoot(cframe, function()
						local v9 = fn94()
						return if v9 then not fn97() else not v9
					end)

					if not fn94() then
						return
					end
					flag5 = false

					for i2 = 1, n21, 1 do
						if fn94() then
							if not fn97() then
								break
							end
						else
							break
						end

						arg:_setStatus("Bringing egg home")

						arg:_hopRoot(cframe, function()
							local v9 = fn94()
							return if v9 then not fn97() else not v9
						end)

						if not fn94() then
							return
						end

						if fn97() then
							task.wait(math.max(n70, arg:_relaySettle()))
							if not fn94() then
								return
							end

							if fn97() then
								pcall(EggState2.DropFieldEgg, "PlayerRequest")
							end

							local n72 = os.clock() + n71

							while fn94() and fn97() and os.clock() < n72 do
								RunService2.Heartbeat:Wait()
							end
						end

						local v9 = fn96()
						local v10 = flag5
						if v9 and v9.State == AreaEggs.States.Dropped then
							flag5 = true
							break
						end

						if not fn97() then
							flag5 = v10
							break
						end
					end

					if not fn94() then
						return
					end

					if not flag5 then
						if arg._instantReturnToken == instantReturnToken then
							arg._instantReturnToken = nil
						end

						arg._forestDropInProgress = nil
						fn100(false)
						arg:_finish("Drop failed \226\128\148 retrying")
						return
					end

					if fanKunHubConfig.HelpFriend then
						arg.skippedEggs[forestDropInProgress] = os.clock() + 1800
						arg._forestDropInProgress = nil
						arg.carry.active = false
						arg.carry.uid = nil
						arg.stats.lastResult = "Dropped for a friend"
						arg:_setStatus("Egg dropped for a friend, heading back")
						local v9 = fn99()

						if v9 then
							arg:_glideRoot(v9, function()
								return not fn94()
							end)
						end

						if not fn94() then
							return
						end
						local externalDeliver = arg._externalDeliver
						arg._instantReturnToken = nil
						arg._externalDeliver = nil

						if arg.enabled then
							arg:_finish("Dropped for a friend")
						elseif externalDeliver then
							arg.activeTarget = nil
							arg:_hideTreadmillDecoy()
						end

						return
					end

					local n72, position = os.clock() + 3

					while fn94() and os.clock() < n72 do
						local v9 = fn96()

						if v9 and v9.State == AreaEggs.States.Dropped then
							local bottomCFrame = v9.BottomCFrame or v9.BoundsCFrame
							position = bottomCFrame and bottomCFrame.Position
							if position then
								break
							end
						else
							if v9 and v9.State ~= AreaEggs.States.Carried then
								break
							end
						end

						task.wait(0.1)
					end

					if not fn94() then
						return
					end
					arg._forestDropInProgress = nil

					if position then
						arg:_noteRelayLanding((position - cframe.Position).Magnitude)
					end

					arg:_setStatus("Bringing egg home")
					local flag6 = treeRegrabMode ~= "skipSafe" and fn99()

					if flag6 then
						fn104(flag6, function()
							return not fn94()
						end, nil, "safe")
					end

					if not fn94() then
						return
					end
					local v9 = arg:_claimCarryWorker("instant-regrab", forestDropInProgress)
					local cframe2 = position and CFrame.new(position + Vector3.new(0, 3.2, 0)) or cframe

					local function fn105()
						fn104(cframe2, function()
							local v10 = fn94()
							return if v10 then fn97() else not v10
						end, 3, "egg")
					end

					n72 = false

					if v9 then
						arg:_setStatus("Bringing egg home")
						fn105()
						if not fn94() then
							return
						end
						n72 = arg:_regrabBurst(v9, forestDropInProgress, 0.5)
						if not fn94() then
							return
						end
						n72 = if fn97() then true else n72

						if n72 then
						else
							if fn97() then
							else
								if arg:_isCarryWorkerCurrent(v9) then
									arg:_setStatus("Bringing egg home")
									local v10 = fn99()

									if v10 then
										arg:_glideRoot(v10, function()
											return not fn94()
										end)
									end

									if not fn94() then
										return
									end
									arg:_setStatus("Bringing egg home")

									arg:_treadmillReset(function()
										return not fn94()
									end)

									if not fn94() then
										return
									end
									arg:_setStatus("Bringing egg home")
									v10 = fn99()

									if v10 then
										arg:_glideRoot(v10, function()
											return not fn94()
										end)
									end

									if not fn94() then
										return
									end

									if arg:_isCarryWorkerCurrent(v9) then
										arg:_setStatus("Bringing egg home")
										fn105()
										if not fn94() then
											return
										end
										local v11 = arg:_regrabBurst(v9, forestDropInProgress, 0.6)
										if not fn94() then
											return
										end
										n72 = v11
									end
								end
							end
						end
					end

					if not n72 and not fn97() then
						fn101(fn98() and "Safe return complete" or "Re-grab failed \226\128\148 retrying")
						return
					end

					if position ~= nil then
						if (position - cframe.Position).Magnitude > index.RELAY_LAND_OK then
							if fn97() then
								if i >= runDropRounds then
									break
								end
							else
								break
							end
						else
							break
						end
					else
						break
					end

					arg:_setStatus("Bringing egg home")
				end
				end
			end

			local n72 = 80

			local function fn105(arg2, arg3)
				local v9, v10 = fn95()
				if v9 and (v10 and (v9.Position - arg2.Position).Magnitude <= n72) then
					return arg:_teleportRoot(v9, v10, arg2)
				end
				return fn103(arg2, arg3)
			end

			if fn97() then
				arg:_setStatus("Bringing egg home")
				local v9 = fn99()

				if v9 then
					fn105(v9, function()
						local v10 = fn94()
						return if v10 then not fn97() else not v10
					end)
				end
			end

			arg:_setStatus("Waiting for deposit")
			local n73 = os.clock() + 8

			while fn94() and not fn98() and os.clock() < n73 do
				n70, fn99 = fn95()

				if n70 and (fn99 and not arg:_isInSafeArea(n70)) then
					local v9 = arg:_resolveSafeCFrame(n70)

					if v9 then
						fn105(v9, function()
							local v10 = fn94()
							return if v10 then fn98() else not v10
						end)
					end
				end

				task.wait(0.1)
			end

			fn101(fn98() and "Safe return complete" or "Bank not confirmed \226\128\148 retrying")
		end)
	end

	index.deliverCarriedEgg = function(arg, uid, activeTarget)
		if type(uid) ~= "string" then
			return false
		elseif uid == "" then
			return false
		elseif arg.destroyed then
			return false
		end

		if arg._instantReturnToken ~= nil then
			return false
		end
		arg._externalDeliver = true

		if type(activeTarget) == "table" then
			arg.activeTarget = activeTarget
		end

		arg.carry.active = true
		arg.carry.uid = uid
		arg.reportedUid = nil
		arg:_instantReturn(uid)

		if arg._instantReturnToken == nil then
			arg._externalDeliver = nil
			arg.carry.active = false
			arg.carry.uid = nil
			return false
		end

		task.spawn(function()
			local n70 = os.clock() + 30

			while arg._instantReturnToken ~= nil and os.clock() < n70 do
				task.wait(0.25)
			end

			if arg._externalDeliver then
				arg._externalDeliver = nil
				arg._instantReturnToken = nil
				arg.carry.active = false
				arg.carry.uid = nil
			end
		end)

		return true
	end

	index._adminSteal = function(arg, activeTarget)
		local uid = activeTarget.Uid
		arg._adminBusyUid = uid

		local function fn94()
			local v8 = EggState2.ReadFieldEgg(uid)
			return v8 ~= nil and v8.State == AreaEggs.States.Carried and v8.CarrierUserId == localPlayer2.UserId
		end

		local function fn95()
			local destroyed = arg.destroyed
			return (if destroyed then not destroyed else arg.enabled) and genv.__FanKunHUBAdminBoost == true and arg._adminBusyUid == uid
		end

		local ok, result = pcall(function()
			arg.instantPhase = nil
			arg.primerUid = nil
			arg.targetUid = nil
			arg.activeTarget = activeTarget
			arg.stats.lastResult = "Admin Abuse"
			arg:_setStatus("Heading to target egg")
			local n70 = os.clock() + 3
			local n71 = 0

			while fn95() and not fn94() do
				if os.clock() >= n70 then
					arg.skippedEggs[uid] = os.clock() + 10
					return arg:_finish("Carry refused \226\128\148 next egg")
				end
				local v8 = EggState2.ReadFieldEgg(uid)
				if if v8 then v8.State ~= AreaEggs.States.Slot and v8.State ~= AreaEggs.States.Dropped else not v8 then
					return arg:_finish("Target egg no longer available")
				end
				local character = localPlayer2.Character
				local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if if humanoidRootPart then not humanoid else not humanoidRootPart then
					return arg:_finish("Character unavailable")
				end
				local v9 = arg:_resolveEggDestination(v8, humanoidRootPart, humanoid)

				if v9 and (humanoidRootPart.Position - v9.Position).Magnitude > 4 then
					arg:_teleportRoot(humanoidRootPart, humanoid, v9)
				end

				if os.clock() >= n71 then
					n71 = os.clock() + 0.1
					arg:_setStatus("Securing egg")

					task.spawn(function()
						pcall(function()
							eggWorld.AskFieldEggCarry:InvokeServer({Uid = uid})
						end)
					end)
				end

				RunService2.Heartbeat:Wait()
			end

			if not fn95() then
				return
			end
			arg.carry.active = true
			arg.carry.uid = uid
			arg:_adminDeliver(uid)
		end)

		if arg._adminBusyUid == uid then
			arg._adminBusyUid = nil
		end

		if not ok then
			warn("[FanKunHUB] admin steal error: " .. tostring(result))

			if not arg.destroyed and arg.enabled then
				arg:_finish("Steal error \226\128\148 retrying")
			end
		end
	end

	index._adminDeliver = function(arg, adminDeliverUid)
		if arg._adminDeliverUid == adminDeliverUid then
			return
		end
		arg._adminDeliverUid = adminDeliverUid
		arg._adminBusyUid = adminDeliverUid

		local function fn94()
			return EggState2.ReadFieldEgg(adminDeliverUid)
		end

		local function fn95()
			local v8 = fn94()
			return v8 ~= nil and v8.State == AreaEggs.States.Carried and v8.CarrierUserId == localPlayer2.UserId
		end

		local function fn96()
			local v8 = fn94()
			return v8 == nil or v8.State == AreaEggs.States.Claimed
		end

		arg:_clearArrivalHold(adminDeliverUid)
		arg:_setStatus("Bringing egg home")
		local n70 = os.clock() + 4

		while true do
			local destroyed = arg.destroyed
			if not ((if destroyed then not destroyed else arg.enabled) and not fn96() and fn95() and os.clock() < n70) then
				break
			end
			local character = localPlayer2.Character
			local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local v8 = humanoidRootPart and arg:_resolveSafeCFrame(humanoidRootPart)

			if v8 and (humanoid and (humanoidRootPart.Position - v8.Position).Magnitude > 4) then
				arg:_teleportRoot(humanoidRootPart, humanoid, v8)
				arg:_setStatus("Waiting for deposit")
			end

			RunService2.Heartbeat:Wait()
		end

		arg._adminDeliverUid = nil

		if arg._adminBusyUid == adminDeliverUid then
			arg._adminBusyUid = nil
		end

		if arg.destroyed then
			return
		elseif not arg.enabled then
			return
		end

		if fn96() then
			arg:_reportStolen()
			arg:_finish("Safe return complete")
		else
			arg:_finish(fn95() and "Bank not confirmed \226\128\148 retrying" or "Egg lost \226\128\148 retrying")
		end
	end

	index._returnToSafe = function(arg)
		local uid

		if arg:_isPrimerEgg(arg.carry.uid) then
			local uid2 = arg.carry.uid
			arg.stats.lastResult = "Steal not banked \226\128\148 retrying"
			arg.carry.active = false
			arg.carry.uid = nil
			arg.carry.generation += 1
			arg:_invalidateCarryWorker()
			arg.skippedEggs[uid2] = os.clock() + 30
			pcall(EggState2.DropFieldEgg, "PlayerRequest")

			if arg.instantPhase == "priming" then
				arg:_startPrimerTargetHunt()
			else
				task.delay(0.5, function()
					if not arg.destroyed and (arg.enabled and not arg.running) then
						arg:_schedule()
					end
				end)
			end

			arg:_notify()
			return
		end

		if arg.captureObjectiveEnabled and arg:_isCaptureEgg(arg.carry.uid) then
			arg:_captureHold(arg.carry.uid)
			return
		end

		if genv.__FanKunHUBAdminBoost == true then
			uid = arg.carry.uid or arg.activeTarget and arg.activeTarget.Uid

			if uid and arg._adminBusyUid ~= uid then
				task.spawn(arg._adminDeliver, arg, uid)
			end

			return
		end

		if arg.config.stealMode == "Instant" or arg.config.stealMode == "Fly" then
			uid = arg.carry.uid or arg.activeTarget and arg.activeTarget.Uid
			if uid then
				arg:_instantReturn(uid)
				return
			end
			arg:_finish("Carry lost \226\128\148 retrying")
			return
		end

		local uid2 = arg.carry.uid
		local v8 = arg:_claimCarryWorker("return", uid2)
		if not v8 then
			return
		end
		arg:_clearArrivalHold(uid2)

		if not arg:_wallOpen() then
			arg:_releaseCarryWorker(v8)
			arg:_finish("Reset interrupted carry")
			return
		end

		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")

		if not humanoidRootPart then
			arg:_releaseCarryWorker(v8)
			arg:_finish("Character unavailable")
			return
		end

		local v9 = arg:_hasConfirmedCarry(uid2)

		if if v9 then arg:_recordShowsForeignCarry(uid2) else not v9 then
			arg:_releaseCarryWorker(v8)
			arg:_finish("Carry not confirmed \226\128\148 retrying")
			return
		end

		if arg:_isInSafeArea(humanoidRootPart) then
			arg:_finalizeReturn(v8)
			return
		end

		if fanKunHubConfig.HelpFriend then
			arg.handoffLane = (arg.handoffLane or 0) % #tbl13 + 1
			local n70 = CFrame.new(n20, vector2.Y, tbl13[arg.handoffLane]) * humanoidRootPart.CFrame.Rotation
			arg:_setStatus("Taking the egg to the friend drop")

			arg:_tweenRoot(n70, function()
				if arg:_isCarryWorkerCurrent(v8) then
					task.spawn(arg._handOffEgg, arg, v8, uid2, n70)
				end
			end, nil, {flightProfile = true})

			return
		end

		local v10 = arg:_resolveSafeCFrame(humanoidRootPart)

		if not v10 then
			arg:_releaseCarryWorker(v8)
			arg:_finish("Safe destination unavailable")
			return
		end

		arg:_setStatus("Returning to safe area")

		arg:_tweenRoot(v10, function()
			if arg:_isCarryWorkerCurrent(v8) then
				arg:_finalizeReturn(v8)
			end
		end, nil, {flightProfile = true})
	end

	index._handOffEgg = function(arg, arg2, arg3, cFrame)
		local function fn94()
			local humanoidRootPart = localPlayer2.Character and localPlayer2.Character:FindFirstChild("HumanoidRootPart")
			if not humanoidRootPart then
				return false
			end
			humanoidRootPart.CFrame = cFrame
			humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			return true
		end

		local function fn95()
			local v8 = EggState2.ReadFieldEgg(arg3)
			return v8 ~= nil and v8.State == AreaEggs.States.Carried and v8.CarrierUserId == localPlayer2.UserId
		end

		arg:_setStatus("Dropping the egg for a friend")
		local n70 = 0.1

		pcall(function()
			n70 = localPlayer2:GetNetworkPing() or 0.1
		end)

		local n71 = os.clock() + math.max(0.3, 0.2 + 2 * n70)

		while os.clock() < n71 do
			if not fn94() then
				break
			end
			RunService2.Heartbeat:Wait()
		end

		arg.skippedEggs[arg3] = os.clock() + 1800
		arg:_reportStolen()
		n71 = false

		for i = 1, 4, 1 do
			fn94()
			local v8 = n71
			if not fn95() then
				n71 = true
				break
			end
			pcall(EggState2.DropFieldEgg, "PlayerRequest")
			local n72 = os.clock() + 0.6
			n71 = v8

			repeat
				RunService2.Heartbeat:Wait()
				n71 = not fn95()
			until n71 or os.clock() >= n72

			if n71 then
				break
			end
		end

		if not n71 then
			arg.skippedEggs[arg3] = nil

			if arg:_isCarryWorkerCurrent(arg2) then
				arg:_releaseCarryWorker(arg2)
				arg:_finish("Friend drop failed \226\128\148 retrying")
			end

			return
		end

		local n72 = os.clock() + 1

		while arg.carry.active and os.clock() < n72 do
			RunService2.Heartbeat:Wait()
		end

		arg.carry.active = false
		arg.carry.uid = nil
		arg.stats.lastResult = "Dropped for a friend"
		local humanoidRootPart = localPlayer2.Character and localPlayer2.Character:FindFirstChild("HumanoidRootPart")
		local v8 = humanoidRootPart and arg:_resolveSafeCFrame(humanoidRootPart)
		if not v8 then
			arg:_finish("Dropped for a friend")
			return
		end
		arg:_setStatus("Egg dropped for a friend, heading back")

		arg:_tweenRoot(v8, nil, nil, {flightProfile = true, onDone = function()
			arg:_finish("Dropped for a friend")
		end})
	end

	index._reportStolen = function(arg)
		local activeTarget = arg.activeTarget

		if type(activeTarget) ~= "table" then
			return
		elseif not activeTarget.Uid then
			return
		end

		if arg.reportedUid == activeTarget.Uid then
			return
		end
		arg.reportedUid = activeTarget.Uid

		task.delay(1.5, function()
			if arg.destroyed then
				return
			end
			local v8

			pcall(function()
				v8 = EggState2.ReadFieldEgg(activeTarget.Uid)
			end)

			if type(v8) == "table" and (v8.State == AreaEggs.States.Slot or v8.State == AreaEggs.States.Dropped or v8.State == AreaEggs.States.Carried and v8.CarrierUserId ~= localPlayer2.UserId) then
				arg.reportedUid = nil
				arg.stats.deliveryFailed = (arg.stats.deliveryFailed or 0) + 1
				arg.stats.lastResult = "Delivery failed \226\128\148 retrying"
				arg:_notify()

				if arg.enabled and not arg.running then
					arg:_schedule()
				end

				return
			end

			arg.stats.delivered = (arg.stats.delivered or 0) + 1
			local fanKunHubWebhook = genv.__FanKunHUBWebhook
			if not fanKunHubWebhook then
				return
			end
			local ok, result = pcall(arg.catalog.resolve, activeTarget)
			pcall(fanKunHubWebhook.stolen, activeTarget, ok and result or nil, nil)
		end)
	end

	index._startWatchdog = function(arg)
		if arg.watchdogRunning then
			return
		end
		arg.watchdogRunning = true

		task.spawn(function()
			local v8 = nil
			local position = nil
			local now = nil
			local v9 = nil
			local v10 = nil
			local now2 = os.clock()

			while fn2() and not arg.destroyed and arg.userStealEnabled do
				task.wait(2)
				local humanoidRootPart = localPlayer2.Character and localPlayer2.Character:FindFirstChild("HumanoidRootPart")
				local str10 = tostring(arg.stats.status)

				if arg.enabled then
					if humanoidRootPart then
						if humanoidRootPart.Position.Y > n69 then
							if arg._boostHopUid == nil then
								if arg._recalling then
									arg._biomeStrandedSince = nil
								elseif arg._biomeStrandedSince and os.clock() - arg._biomeStrandedSince >= 2 then
									arg._biomeStrandedSince = nil
									arg.stats.watchdogResets = (arg.stats.watchdogResets or 0) + 1
									arg:_setStatus("Leaving the portal biome")
									arg:_mutePortalFx(true)
									pcall(arg._crossPortal, arg, fn91("FuseBiomeZone", "ExitPart"), nil, 8)
									arg:_mutePortalFx(false)

									if arg.running then
										arg:_finish("Left the portal biome")
									end
								else
									arg._biomeStrandedSince = arg._biomeStrandedSince or os.clock()
								end
							else
								arg._biomeStrandedSince = nil
							end
						else
							arg._biomeStrandedSince = nil
						end
					else
						arg._biomeStrandedSince = nil
					end
				else
					arg._biomeStrandedSince = nil
				end

				if arg.enabled and arg.running and not arg.carry.active and arg.carryAttemptToken == nil and arg._instantReturnToken == nil and not arg._captureHoldUid and humanoidRootPart and str10 == v8 and position and (humanoidRootPart.Position - position).Magnitude < 3 then
					if os.clock() - now > 12 then
						arg.stats.watchdogResets = (arg.stats.watchdogResets or 0) + 1

						pcall(function()
							arg:_invalidateCarryWorker()
						end)

						arg:_finish("Stuck - retrying")
						arg:_releaseOperation()
						v8 = nil
						position = nil
						now = nil
						v9 = nil
					end
				else
					v8 = str10
					position = humanoidRootPart and humanoidRootPart.Position
					now = os.clock()
				end

				if arg.enabled then
					str10, humanoidRootPart = nil

					if arg._captureHoldUid then
						local v11 = nil
						local v12 = nil
						v9 = v11
						v10 = v12
					else
						if arg.running then
							local v11 = nil
							local str11 = tostring(arg.activeTarget and arg.activeTarget.Uid) .. "|" .. tostring(arg.carry.active)

							if str11 ~= v9 then
								local now3 = os.clock()
								v9 = str11
								now2 = now3
							else
								if os.clock() - now2 > 60 then
									arg.stats.watchdogResets = (arg.stats.watchdogResets or 0) + 1
									local uid = arg.activeTarget and arg.activeTarget.Uid

									if uid and not arg.carry.active then
										arg.skippedEggs[uid] = os.clock() + n38

										if arg.tweenRecoveryUid == uid then
											arg.tweenRecoveryUid = nil
										end
									end

									pcall(function()
										arg:_invalidateCarryWorker()
									end)

									arg:_finish("Stuck \226\128\148 retrying")
									v9 = nil
								end
							end

							v10 = v11
						else
							local v11 = nil
							local ok, result = pcall(arg._chooseTarget, arg)

							if arg:_wallOpen() then
								if ok then
									if result ~= nil then
										local now3 = v10 or os.clock()

										if os.clock() - now3 > 6 then
											arg.stats.watchdogResets = (arg.stats.watchdogResets or 0) + 1
											arg:_releaseOperation()
											arg:_schedule()
											v10 = nil
										else
											v10 = now3
										end
									else
										v10 = nil
									end
								else
									v10 = nil
								end
							else
								v10 = nil
							end

							v9 = v11
						end
					end
				else
					local v11, v12
					v9 = v11
					v10 = v12
				end
			end

			arg.watchdogRunning = false
		end)
	end

	index._finalizeReturn = function(arg, arg2)
		if not arg:_isCarryWorkerCurrent(arg2) then
			return
		end

		if not arg.carry.active then
			arg:_releaseCarryWorker(arg2)
			arg:_reportStolen()
			arg:_finish("Safe return complete")
			return
		end

		arg:_setStatus("Validating safe arrival")
		local now = os.clock()
		local n70 = os.clock() + 6

		while arg:_isCarryWorkerCurrent(arg2) and arg.carry.active and os.clock() < n70 do
			local humanoidRootPart = localPlayer2.Character and localPlayer2.Character:FindFirstChild("HumanoidRootPart")

			if not humanoidRootPart then
				arg:_releaseCarryWorker(arg2)
				arg:_finish("Character unavailable")
				return
			end

			if not arg:_isInSafeArea(humanoidRootPart) then
				arg:_setStatus("Rollback detected \226\128\148 returning again")
				arg:_releaseCarryWorker(arg2)

				task.defer(function()
					if not arg.destroyed and (arg.enabled and arg.carry.active) then
						arg:_returnToSafe()
					end
				end)

				return
			end

			if os.clock() - now >= n42 then
				arg:_setStatus("Waiting for deposit")
			end

			task.wait(n43)
		end

		if not arg:_isCarryWorkerCurrent(arg2) then
			return
		end

		if not arg.carry.active then
			arg:_releaseCarryWorker(arg2)
			arg:_reportStolen()
			arg:_finish("Safe return complete")
			return
		end

		arg:_setStatus("Deposit pending \226\128\148 validating again")

		task.defer(function()
			if arg:_isCarryWorkerCurrent(arg2) and arg.carry.active then
				arg:_finalizeReturn(arg2)
			end
		end)
	end

	index._finish = function(arg, arg2)
		arg:_noteLowSpeedOutcome(arg2)
		arg:_hideTreadmillDecoy()
		pcall(arg._restoreCharacterVisual, arg)
		arg._forestDropInProgress = nil
		arg._instantReturnToken = nil
		arg.boostedUid = nil
		arg:_invalidateCarryWorker()
		arg.planGeneration = arg.planGeneration + 1
		arg:_cancelTween(arg2, arg.enabled)
		arg:_setStatus(arg.enabled and "Searching" or "Idle")

		if arg.enabled then
			task.delay(n12, function()
				if arg.destroyed then
					arg:_releaseOperation()
					return
				elseif not arg.enabled then
					arg:_releaseOperation()
					return
				end

				arg:_schedule()
			end)
		end
	end

	index._scheduleMovementRetry = function(arg)
		if arg.movementRetryPending then
			return
		elseif arg.destroyed then
			return
		elseif not arg.enabled then
			return
		end

		arg.movementRetryPending = true

		task.delay(0.2, function()
			arg.movementRetryPending = false

			if not arg.destroyed and arg.enabled then
				arg:_schedule()
			end
		end)
	end

	index._eggCount = function(arg)
		local ok, result = pcall(function()
			local n70 = 0

			for k in pairs(require(ReplicatedStorage2.Shared.Save).Peek().EggInventory or {}) do
				n70 += 1
			end

			return n70
		end)

		return ok and result or nil
	end

	index._eggInventoryFull = function(arg)
		local eggFullCount = arg.eggFullCount
		if not eggFullCount then
			return false
		end
		local v8 = arg:_eggCount()
		if not v8 then
			return true
		end

		if v8 > eggFullCount then
			arg.eggFullCount = nil
			arg._eggFullHold = false
			return false
		end

		if v8 >= eggFullCount then
			arg._eggFullHold = true
			local fanKunHubIsAutoSellEggBusy = genv.__FanKunHUBIsAutoSellEggBusy and genv.__FanKunHUBIsAutoSellEggBusy()
			arg._eggFullAt = arg._eggFullAt or os.clock()

			if not fanKunHubIsAutoSellEggBusy and os.clock() - arg._eggFullAt > 60 then
				arg.eggFullCount = nil
				arg._eggFullHold = false
				arg._eggFullAt = nil
				return false
			end

			return true
		end

		arg._eggFullAt = nil

		if arg._eggFullHold then
			if genv.__FanKunHUBIsAutoSellEggBusy and (genv.__FanKunHUBIsAutoSellEggBusy() and v8 > eggFullCount - index.EGG_FREE_SLOTS) then
				return true
			end
			arg._eggFullHold = false
			arg.eggFullNotified = nil
		end

		return false
	end

	index._schedule = function(arg)
		if not arg.running then
			arg.safeStarting = false
		end

		if arg.destroyed then
			return
		elseif arg.enabled then
			if arg.running then
				return
			end
		else
			return
		end

		if not arg.carry.active and arg:_eggInventoryFull() then
			arg:_releaseOperation()
			arg:_setStatus("Egg inventory full - place, hatch or sell eggs")

			if not arg.eggFullNotified then
				arg.eggFullNotified = true

				pcall(function()
					game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Auto Steal", Text = "Egg inventory full. Place, hatch or sell eggs and it continues by itself.", Duration = 6})
				end)
			end

			task.delay(3, function()
				if not arg.destroyed and (arg.enabled and not arg.running) then
					arg:_schedule()
				end
			end)

			return
		end

		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if if humanoidRootPart then not humanoid else not humanoidRootPart then
			arg:_releaseOperation()
			arg:_setStatus("Character unavailable")
			return
		end

		arg:_startMovementProtection()

		if arg.carry.active and arg.carry.uid ~= nil then
			if arg.instantPhase == "priming" and arg.carry.uid == arg.primerUid then
				return
			end

			if arg:_isPrimerEgg(arg.carry.uid) then
				arg:_setStatus("Dropping primer egg")
				arg.skippedEggs[arg.carry.uid] = os.clock() + 30
				pcall(EggState2.DropFieldEgg, "PlayerRequest")

				task.delay(0.5, function()
					if not arg.destroyed and arg.enabled then
						arg:_schedule()
					end
				end)

				return
			end

			local v8 = arg.records[arg.carry.uid] or EggState2.ReadFieldEgg(arg.carry.uid)
			local captureObjectiveEnabled = type(v8) == "table" and (arg.riftWants[v8.AssetCategory] or arg.captureObjectiveEnabled and arg:_isCaptureEgg(v8.Uid) or arg.indexObjectiveEnabled and arg:_isIndexObjective(v8) or arg.wispObjective and arg:_isWispObjective(v8) or arg.userStealEnabled and not arg.riftOnly and arg:_matchesNormalFilter(v8) or arg:_isManualKeep(v8.Uid))

			if type(v8) == "table" and not captureObjectiveEnabled then
				arg:_setStatus("Dropping unwanted egg")
				arg.skippedEggs[arg.carry.uid] = os.clock() + 30
				pcall(EggState2.DropFieldEgg, "PlayerRequest")

				task.delay(0.5, function()
					if not arg.destroyed and arg.enabled then
						arg:_schedule()
					end
				end)

				return
			end

			arg:_returnToSafe()
			return
		end

		if not arg:_wallOpen() then
			arg:_releaseOperation()
			arg:_setStatus("Waiting for reset wall")
			return
		end

		local fanKunHubPlayerSteal = genv.__FanKunHUBPlayerSteal
		local autoSteal = fanKunHubTaskLadder.blocker("auto_steal")
		local v8 = (if autoSteal then not autoSteal else fanKunHubTaskLadder.holder("auto_steal")) or nil

		if (autoSteal or v8 or fanKunHubPlayerSteal and fanKunHubPlayerSteal.running) and not (arg.manualObjectiveEnabled and #arg.manualOrder > 0) then
			arg:_releaseOperation()
			arg:_setStatus(autoSteal and "Yielding to " .. fanKunHubTaskLadder.TITLES[autoSteal] or v8 and "Waiting for " .. fanKunHubTaskLadder.TITLES[v8] .. " to hand over" or "Yielding to Steal Players")
			if arg._yieldRetryPending then
				return
			end
			arg._yieldRetryPending = true

			task.delay((autoSteal or v8) and 1 or 0.5, function()
				arg._yieldRetryPending = nil

				if not arg.destroyed and arg.enabled then
					arg:_schedule()
				end
			end)

			return
		end

		character = arg.tweenRecoveryUid
		local v9 = character and (EggState2.ReadFieldEgg(character) or arg.records[character]) or nil

		if character and (type(v9) ~= "table" or v9.State ~= AreaEggs.States.Slot and v9.State ~= AreaEggs.States.Dropped) then
			arg.tweenRecoveryUid = nil
			v9 = nil
			character = nil
		end

		local v10

		if v9 then
			v10 = v9
		else
			v10 = arg:_chooseTarget()
		end

		if not v10 then
			if arg.stats.matching == 0 then
				if arg.stats.available > 0 then
					local minWeightKg = arg.config.minWeightKg

					if minWeightKg then
						if minWeightKg > 0 then
							arg:_setStatus(string.format("No eggs \226\137\165 %dKg", arg.config.minWeightKg))
						else
							arg:_setStatus("No matching eggs")
						end
					else
						arg:_setStatus("No matching eggs")
					end
				else
					arg:_setStatus("No matching eggs")
				end
			else
				arg:_setStatus("No matching eggs")
			end

			arg:_releaseOperation()

			if not arg.activeTween and (arg:_isInField(humanoidRootPart) and not arg:_isInSafeArea(humanoidRootPart)) then
				local v11 = arg:_resolveSafeCFrame(humanoidRootPart)

				if v11 then
					arg:_tweenRoot(v11, nil, nil, {silent = true, flightProfile = true, abort = function()
						local enabled = arg.enabled
						return if enabled then arg.running else not enabled
					end})
				end
			end

			return
		end

		if arg.treadmillManager and arg.treadmillManager:isEngaged() then
			arg.treadmillManager:_cancelIdle(true)
		end

		local planGeneration = arg.planGeneration
		fanKunHubPlayerSteal, autoSteal = arg:_acquireOperation()

		if not fanKunHubPlayerSteal then
			arg:_setStatus("Waiting \194\183 " .. tostring(autoSteal or "another operation"))

			task.delay(0.5, function()
				if not arg.destroyed and (arg.enabled and arg.planGeneration == planGeneration) then
					arg:_schedule()
				end
			end)

			return
		end

		arg.safeStarting = true
		arg.running = true
		arg.activeTarget = v10
		local v11 = arg.catalog.resolve(v10)
		arg.stats.lastTarget = string.format("%s \194\183 %s \194\183 %s", v11.rarity, v11.name, v10.AreaId)

		if character then
			arg.safeStarting = false
			arg.stats.lastResult = "Recovering with tween"
			local v12 = arg:_resolveEggDestination(v10, humanoidRootPart, humanoid)

			if not v12 then
				arg.tweenRecoveryUid = nil
				arg:_finish("Recovery destination unavailable")
				return
			end

			arg:_setStatus("Returning to egg")

			arg:_tweenRoot(v12, function()
				if arg.tweenRecoveryUid == v10.Uid then
					arg:_requestCarry(v10, false)
				end
			end, nil, {holdAfterArrival = true, holdUid = v10.Uid, flightProfile = true, carryTarget = v10})

			return
		end

		if not arg:_leftTreadmill(humanoidRootPart) then
			arg.running = false
			arg.safeStarting = false
			arg.activeTarget = nil
			arg:_releaseOperation()
			arg:_setStatus("Preparing steal")

			task.delay(0.3, function()
				if not arg.destroyed and (arg.enabled and arg.planGeneration == planGeneration) then
					arg:_schedule()
				end
			end)

			return
		end

		if genv.__FanKunHUBAdminBoost == true and not (arg.captureObjectiveEnabled and arg:_isCaptureEgg(v10.Uid)) then
			arg.safeStarting = false
			task.spawn(arg._adminSteal, arg, v10)
			return
		end

		autoSteal = humanoidRootPart.Position - vector2
		local magnitude = Vector2.new(autoSteal.X, autoSteal.Z).Magnitude
		character = if arg:_usesPortalBoost(v10) then true else false

		if arg.config.stealMode == "Fly" then
			local bottomCFrame = v10.BottomCFrame or v10.BoundsCFrame

			if bottomCFrame then
				local n70 = bottomCFrame.Position - humanoidRootPart.Position
				character = if Vector2.new(n70.X, n70.Z).Magnitude < magnitude then true else character
			end
		end

		if not character and (magnitude > 3 and os.clock() - (arg.lastSafeRepositionAt or 0) > 5) then
			local v12 = arg:_resolveSafeCFrame(humanoidRootPart)

			if v12 then
				arg.safeStarting = true
				arg.running = true
				arg.lastSafeRepositionAt = os.clock()
				arg:_setStatus("Repositioning to safe area")

				arg:_tweenRoot(v12, function()
					arg:_groundSnap()
					arg.safeStarting = false
					arg.running = false

					task.delay(0.15, function()
						if not arg.destroyed and (arg.enabled and arg.planGeneration == planGeneration) then
							arg:_schedule()
						end
					end)
				end, nil, {flightProfile = true})

				return
			end
		end

		arg.safeStarting = false

		if arg:_usesPortalBoost(v10) then
			arg.instantPhase = "hunting"
			arg.primerUid = nil
			arg.targetUid = nil
			arg.activeTarget = v10
			arg._flyDeparting = false
			arg:_installGuardHitDistanceBoost()
			arg:_startMovementProtection()
			arg:_showTreadmillDecoy()
			arg.stats.lastResult = "Low Speed Boost"
			task.spawn(arg._portalBoostSteal, arg, v10)
			return
		end

		if arg.config.stealMode == "Fly" then
			arg.instantPhase = "priming"
			arg.primerUid = nil
			arg.targetUid = v10.Uid
			arg.activeTarget = v10
			arg._flyDeparting = false
			arg.lowFpsPrime = false
			arg:_installGuardHitDistanceBoost()
			arg:_startMovementProtection()
			arg.stats.lastResult = "High Speed departing"
			arg:_startPrimerTargetHunt()
			return
		end

		local v12 = arg:_choosePrimerEgg(v10.Uid)

		if not v12 then
			arg.running = false
			arg.activeTarget = nil
			arg:_releaseOperation()
			arg:_setStatus("Preparing steal")

			task.delay(0.25, function()
				if not arg.destroyed and (arg.enabled and arg.planGeneration == planGeneration) then
					arg:_schedule()
				end
			end)

			return
		end

		arg.instantPhase = "priming"
		arg.primerUid = v12.Uid
		arg.primerUids[v12.Uid] = os.clock() + 120
		arg.skippedEggs[v12.Uid] = os.clock() + 30
		arg.targetUid = v10.Uid
		arg.activeTarget = v12
		arg._flyDeparting = arg.config.stealMode == "Fly"

		if arg.config.stealMode == "Instant" then
			arg:_showTreadmillDecoy()
		end

		arg:_installGuardHitDistanceBoost()
		arg.stats.lastResult = arg.config.stealMode .. " priming"
		arg.lowFpsPrime = fn3() < 30
		local v13 = arg:_resolveEggDestination(v12, humanoidRootPart, humanoid)
		if not v13 then
			arg:_finish("Steal unavailable \226\128\148 retrying")
			return
		end

		if arg.lowFpsPrime then
			arg:_setStatus("Preparing steal")

			arg:_tweenRoot(v13, function()
				if arg.instantPhase == "priming" and arg.primerUid == v12.Uid then
					arg:_requestCarry(v12, false)
				end
			end, nil, {holdAfterArrival = true, holdUid = v12.Uid, flightProfile = true, carryTarget = v12})

			return
		end

		if arg.config.stealMode == "Fly" then
			arg:_setStatus("Preparing steal")

			local function fn94()
				return arg.destroyed or not arg.enabled or arg.instantPhase ~= "priming" or arg.primerUid ~= v12.Uid
			end

			if not arg:_glideRoot(v13, fn94) then
				if arg.instantPhase == "priming" and arg.primerUid == v12.Uid then
					arg:_finish("Steal unavailable \226\128\148 retrying")
				end

				return
			end

			arg:_setArrivalHold(v13, v12.Uid)
			arg:_requestCarry(v12, true)
			return
		end

		arg:_setStatus("Preparing steal")
		if not arg:_teleportRoot(humanoidRootPart, humanoid, v13) then
			arg:_finish("Steal unavailable \226\128\148 retrying")
			return
		end
		arg:_setArrivalHold(v13, v12.Uid)
		arg:_requestCarry(v12, true)
	end

	index._leftTreadmill = function(arg, arg2)
		local treadmillManager = arg.treadmillManager
		if not treadmillManager or treadmillManager.destroyed then
			return true
		end

		if not (treadmillManager.activeTreadmill ~= nil) and (not (treadmillManager.treadmillEquipPending == true) and not (treadmillManager.travelingToTreadmill == true)) then
			if arg2 ~= nil then
				if not arg2.Anchored then
					arg.treadmillLeaveAt = nil
					return true
				end
			else
				arg.treadmillLeaveAt = nil
				return true
			end
		end

		local now = os.clock()
		arg.treadmillLeaveAt = arg.treadmillLeaveAt or now
		treadmillManager.idleGeneration = treadmillManager.idleGeneration + 1

		if not arg.treadmillDoffBusy and now - (arg.treadmillDoffAt or 0) > 0.6 then
			arg.treadmillDoffBusy = true
			arg.treadmillDoffAt = now

			task.spawn(function()
				pcall(treadmillManager._requestUnequip, treadmillManager)
				pcall(treadmillManager._syncActiveTreadmillSnapshot, treadmillManager)
				arg.treadmillDoffBusy = false
			end)
		end

		if arg2 and arg2.Anchored and now - arg.treadmillLeaveAt > 1 then
			pcall(function()
				arg2.Anchored = false
			end)
		end

		if now - arg.treadmillLeaveAt > 8 then
			arg.treadmillLeaveAt = nil
			return true
		end
		return false
	end

	index._reconcileRunningState = function(arg)
		local enabled = arg.userStealEnabled == true or next(arg.riftWants) ~= nil or arg.indexObjectiveEnabled == true or arg.wispObjective ~= nil or arg.manualObjectiveEnabled == true or arg.captureObjectiveEnabled == true

		if arg.enabled == enabled then
			if arg.enabled then
				arg:_refreshCounts()
				arg:_schedule()
			end

			return
		end

		arg.enabled = enabled

		if arg.enabled then
			if localPlayer2.Character then
				fn67(localPlayer2.Character)
				fn69(arg, localPlayer2.Character)
			end

			arg:_installGuardHitDistanceBoost()
			arg:_startMovementProtection()
			pcall(arg._installPromptFilter, arg)
			arg:_setStatus("Searching")
			arg:_schedule()
		else
			if arg._instantReturnToken ~= nil and (arg.carry.uid ~= nil and not arg._externalDeliver) then
				arg._externalDeliver = true
				arg.planGeneration = arg.planGeneration + 1
				arg.running = false
				arg:_setStatus("Finishing target egg")

				task.spawn(function()
					local n70 = os.clock() + 45

					while arg._instantReturnToken ~= nil and os.clock() < n70 and not arg.destroyed do
						task.wait(0.2)
					end

					if arg.destroyed then
						return
					elseif arg.enabled then
						return
					end

					arg._externalDeliver = nil
					arg._instantReturnToken = nil
					arg.carry.active = false
					arg.carry.uid = nil
					arg.activeTarget = nil
					arg:_cleanupInstantSteal()
					arg:_removeGuardHitDistanceBoost()
					arg:_restoreTreadmillVisualAtSafe()
					arg:_stopMovementProtection()
					fn68(arg)
					arg:_setStatus("Idle")
				end)

				arg:_refreshCounts()
				return
			end

			local v8 = arg:_needsHiddenRecall()

			if v8 then
				arg._recalling = true
			end

			arg.planGeneration = arg.planGeneration + 1
			arg.carry.generation += 1
			arg:_cleanupInstantSteal()

			if not v8 then
				arg:_removeGuardHitDistanceBoost()
			end

			arg:_invalidateCarryWorker()
			arg._forestDropInProgress = nil
			arg._instantReturnToken = nil
			arg.carry.active = false
			arg.carry.uid = nil
			arg.tweenRecoveryUid = nil
			arg.claimPresentationSuppression = nil
			arg.safeStarting = false
			arg.movementRetryPending = false
			arg:_cancelTween("Disabled")
			arg:_releaseOperation()

			if v8 then
				arg:_recallHidden()
			else
				arg:_restoreTreadmillVisualAtSafe()
				arg:_stopMovementProtection()
				fn68(arg)
			end

			arg.activeTarget = nil
			arg.running = false
			arg:_setStatus("Idle")
		end

		arg:_refreshCounts()
	end

	index.setEnabled = function(arg, arg2)
		arg.userStealEnabled = arg2 == true
		arg:_reconcileRunningState()

		if arg.userStealEnabled then
			arg:_startWatchdog()
		end

		arg:_reconcileScramblePortal()
	end

	local str10 = "ScrambleArenaPortal"

	index._neutralizeScramblePortal = function(arg, arg2)
		if typeof(arg2) ~= "Instance" then
			return
		elseif arg2.Name ~= str10 then
			return
		end

		arg.scramblePortalOriginals = arg.scramblePortalOriginals or {}

		for i, descendant in ipairs(arg2:GetDescendants()) do
			if descendant:IsA("BasePart") then
				if arg.scramblePortalOriginals[descendant] == nil then
					local attribute = descendant:GetAttribute("FanKunHUBPortalOrig")

					if type(attribute) == "string" then
						arg.scramblePortalOriginals[descendant] = {CanCollide = attribute:sub(1, 1) == "1", CanTouch = attribute:sub(2, 2) == "1"}
					else
						arg.scramblePortalOriginals[descendant] = {CanCollide = descendant.CanCollide, CanTouch = descendant.CanTouch}
						pcall(descendant.SetAttribute, descendant, "FanKunHUBPortalOrig", (descendant.CanCollide and "1" or "0") .. (descendant.CanTouch and "1" or "0"))
					end
				end

				pcall(function()
					descendant.CanCollide = false
					descendant.CanTouch = false
				end)
			end
		end
	end

	index._startScramblePortalBypass = function(arg)
		local v8 = workspace:FindFirstChild(str10)

		if v8 then
			arg:_neutralizeScramblePortal(v8)
		end

		if not arg.scramblePortalConn then
			arg.scramblePortalConn = workspace.ChildAdded:Connect(function(child)
				if arg.destroyed then
					return
				elseif arg.userStealEnabled then
					if arg._scramblePortalHold then
						return
					end
				else
					return
				end

				if child.Name ~= str10 then
					return
				end

				for i, v9 in ipairs({0, 0.15, 0.4, 0.8}) do
					task.delay(v9, function()
						if not arg.destroyed and (arg.userStealEnabled and (not arg._scramblePortalHold and child.Parent)) then
							arg:_neutralizeScramblePortal(child)
						end
					end)
				end
			end)
		end
	end

	index._stopScramblePortalBypass = function(arg)
		if arg.scramblePortalConn then
			pcall(arg.scramblePortalConn.Disconnect, arg.scramblePortalConn)
			arg.scramblePortalConn = nil
		end

		if arg.scramblePortalOriginals then
			for k, scramblePortalOriginal in pairs(arg.scramblePortalOriginals) do
				if typeof(k) == "Instance" and k.Parent then
					pcall(function()
						k.CanCollide = scramblePortalOriginal.CanCollide
						k.CanTouch = scramblePortalOriginal.CanTouch
						k:SetAttribute("FanKunHUBPortalOrig", nil)
					end)
				end
			end

			arg.scramblePortalOriginals = nil
		end
	end

	index._setScramblePortalHold = function(arg, arg2)
		local scramblePortalHold = arg2 == true
		if arg._scramblePortalHold == scramblePortalHold then
			return
		end
		arg._scramblePortalHold = scramblePortalHold
		arg:_reconcileScramblePortal()
	end

	index._reconcileScramblePortal = function(arg)
		if arg.userStealEnabled then
			if arg._scramblePortalHold then
				arg:_stopScramblePortalBypass()
			else
				arg:_startScramblePortalBypass()
			end
		else
			arg:_stopScramblePortalBypass()
		end
	end

	index._resolveWeightKg = function(arg, arg2)
		local weightUtil = arg.weightUtil

		if weightUtil then
			if arg2 then
				if arg2.AssetScale then
					if not arg2.AssetCategory then
						return nil
					end
				else
					return nil
				end
			else
				return nil
			end
		else
			return nil
		end

		local ok, result = pcall(weightUtil.WeightKgForScale, arg2.AssetCategory, arg2.AssetScale)
		if ok and type(result) == "number" then
			return result
		end
		return nil
	end

	index.setHeaviestFirst = function(arg, arg2)
		arg.config.heaviestFirst = arg2 == true

		if arg.config.heaviestFirst then
			arg.config.highestValueFirst = false
		end

		arg:_schedule()
	end

	index.setHighestValueFirst = function(arg, arg2)
		arg.config.highestValueFirst = arg2 == true

		if arg.config.highestValueFirst then
			arg.config.heaviestFirst = false
		end

		arg:_schedule()
	end

	local name4 = "__FanKunHUBEggEsp"
	local name5 = "__FanKunHUBEggHighlight"
	local tbl18 = {rarity = true, name = true, kg = true, mutation = true, value = true, placed = true, icon = true}

	fn66 = function(arg)
		if type(arg) ~= "table" then
			return nil
		end
		local category = arg.Category or arg.AssetCategory
		local num = tonumber(arg.Scale or arg.AssetScale)

		if type(category) ~= "string" then
			return nil
		elseif num then
			if num <= 0 then
				return nil
			end
		else
			return nil
		end

		local tbl19 = {Category = category, Scale = num, Mutations = type(arg.Mutations) == "table" and table.clone(arg.Mutations) or {}, BaseMutation = type(arg.BaseMutation) == "string" and arg.BaseMutation or nil}
		category, arg = pcall(AssetEarnings.MutationOnlyRatePerSecond, tbl19)
		return category and type(arg) == "number" and arg or nil
	end

	local v8

	local function fn94(arg)
		if type(v8) ~= "table" then
			local ok, result = pcall(require, ReplicatedStorage2.Packages.FormatNumber.Simple)

			if ok and type(result.FormatCompact) == "function" then
				v8 = result
			end
		end

		if v8 then
			local ok, result = pcall(v8.FormatCompact, arg, ".#")
			if ok and type(result) == "string" then
				return result
			end
		end

		local n70 = math.abs(arg)

		if n70 >= 1000000000000 then
			return string.format("%.2fT", arg / 1000000000000)
		elseif n70 >= 1000000000 then
			return string.format("%.2fB", arg / 1000000000)
		elseif n70 >= 1000000 then
			return string.format("%.1fM", arg / 1000000)
		elseif n70 >= 1000 then
			return string.format("%.1fK", arg / 1000)
		end

		return string.format("%d", math.floor(arg + 0.5))
	end

	local n70 = 2
	local n71 = 3.2
	local n72 = 1.25
	local n73 = 597
	local tbl19 = {["Carry not confirmed \226\128\148 retrying"] = true, ["Carry refused \226\128\148 next egg"] = true, ["Carry lost \226\128\148 retrying"] = true, ["Drop failed \226\128\148 retrying"] = true, ["Egg lost \226\128\148 retrying"] = true, ["Re-steal failed \226\128\148 retrying"] = true, ["Steal timed out \226\128\148 retrying"] = true}
	local n74 = 8
	local n75 = 600
	local tbl20 = {}

	local function fn95()
		if next(tbl20) then
			return tbl20
		end
		local v9 = fn()
		local areas = v9 and v9:FindFirstChild("Areas")
		local guardAreas = areas and areas:FindFirstChild("GuardAreas")

		for i, v10 in ipairs(guardAreas and guardAreas:GetChildren() or {}) do
			local closestExitPoint = v10:FindFirstChild("ClosestExitPoint")

			if closestExitPoint and closestExitPoint:IsA("BasePart") then
				tbl20[v10.Name] = closestExitPoint.Position.X
			end
		end

		return tbl20
	end

	index.settleNeed = function(arg, arg2, arg3)
		local v9 = fn95()[arg2]
		return n70 + math.max(0, (v9 or n73) - n73) / (n71 * math.max(arg3, 16))
	end

	index.recommendLowSpeedLevel = function(arg, arg2)
		local v9 = arg2 or fn86()
		local tbl21 = {}

		if arg.config.areaEnabled and #arg.config.areas > 0 then
			tbl21 = arg.config.areas
		else
			for k in pairs(fn95()) do
				tbl21[#tbl21 + 1] = k
			end
		end

		local n76, v10 = 10
		arg2 = 10

		for i, v11 in ipairs(tbl21) do
			if fanKunHubConfig.LowSpeedBoost == true and tbl16[v11] ~= nil then
			else
				local v12 = arg:settleNeed(v11, v9)
				local n77 = 1

				for i2 = 10, 1, -1 do
					if fn87(v11, i2) >= v12 then
						n77 = i2
						break
					end
				end

				i = 1

				for i2 = 10, 1, -1 do
					if fn87(v11, i2) >= v12 * n72 then
						i = i2
						break
					end
				end

				if n77 < n76 then
					n76 = n77
					v10 = v11
				end

				arg2 = math.min(arg2, i)
			end
		end

		local lowSpeedFailCap = arg.lowSpeedFailCap

		if lowSpeedFailCap then
			n76 = math.min(n76, lowSpeedFailCap)
			arg2 = math.min(arg2, lowSpeedFailCap)
		end

		return math.min(arg2, n76), n76, v9, v10
	end

	index._noteLowSpeedOutcome = function(arg, arg2)
		local flag5 = arg._untrustedSeen == true
		arg._untrustedSeen = nil
		if arg.config.stealMode ~= "Instant" then
			return
		end

		if arg.boostedUid ~= nil then
			return
		elseif arg._boostHopUid ~= nil then
			return
		end

		local failed = tbl19[tostring(arg2)] == true or flag5
		if not failed and arg2 ~= "Safe return complete" then
			return
		end
		local n76 = math.clamp(tonumber(fanKunHubConfig.StealHoldSeconds) or 5, 1, 10)
		arg.lowSpeedOutcomes = arg.lowSpeedOutcomes or {}
		flag5 = arg.lowSpeedOutcomes[n76] or {}
		arg.lowSpeedOutcomes[n76] = flag5
		local n77 = #flag5 + 1
		local tbl21 = {}
		tbl21.at, tbl21.failed, flag5[n77] = os.clock(), failed, tbl21

		while #flag5 > n74 do
			table.remove(flag5, 1)
		end

		tbl21 = 0
		n77 = 0

		for i, v9 in ipairs(flag5) do
			if os.clock() - v9.at <= n75 then
				tbl21, n77 = tbl21 + 1, if v9.failed then n77 + 1 else n77
			end
		end

		if n76 > 1 and (n77 >= 3 and n77 / tbl21 >= 0.4) then
			local lowSpeedFailCap = n76 - 1
			local lowSpeedFailCap2 = arg.lowSpeedFailCap

			if if lowSpeedFailCap2 then lowSpeedFailCap < arg.lowSpeedFailCap else not lowSpeedFailCap2 then
				arg.lowSpeedFailCap = lowSpeedFailCap
				arg.lowSpeedAdvice = {from = n76, to = lowSpeedFailCap, fails = n77, total = tbl21, fresh = true}
			end
		end
	end

	index.lowSpeedStatus = function(arg)
		local v9

		pcall(function()
			v9 = SpeedPowerProjection.ReadProjected()
		end)

		local v10, v11, v12 = arg:recommendLowSpeedLevel()
		local n76 = math.clamp(tonumber(fanKunHubConfig.StealHoldSeconds) or 5, 1, 10)
		local lowSpeedAdvice = arg.lowSpeedAdvice
		local v13 = lowSpeedAdvice and (if n76 <= lowSpeedAdvice.to then nil else lowSpeedAdvice)
		return {speedText = type(v9) == "number" and fn94(v9) or "?", walkSpeed = math.floor((v12 or 0) + 0.5), safe = v10, fast = v11, level = n76, advice = v13}
	end

	-- daftar egg yang bisa dicuri sekarang (dipakai Steal Panel)
	index.listStealableEggs = function(arg)
		local list = {}
		local character = localPlayer2.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		for _, record in pairs(arg.records) do
			if (record.State == AreaEggs.States.Slot or record.State == AreaEggs.States.Dropped) and record.BottomCFrame then
				local info = arg.catalog.resolve(record)
				local mutations = {}

				if type(record.Mutations) == "table" then
					for _, mutation in pairs(record.Mutations) do
						mutations[#mutations + 1] = tostring(mutation)
					end
					table.sort(mutations)
				end

				local value = fn66(record)

				list[#list + 1] = {
					uid = record.Uid,
					name = tostring(info.name),
					icon = type(info.icon) == "string" and info.icon ~= "" and info.icon or nil,
					rarity = tostring(info.rarity),
					rarityRank = info.rarityRank or 0,
					color = typeof(info.rarityColor) == "Color3" and info.rarityColor or nil,
					area = record.AreaId ~= nil and tostring(record.AreaId) or nil,
					kg = arg:_resolveWeightKg(record),
					mutations = table.concat(mutations, ", "),
					value = value and fn94(value) or nil,
					distance = root and (record.BottomCFrame.Position - root.Position).Magnitude or nil,
					dropped = record.State == AreaEggs.States.Dropped,
				}
			end
		end

		return list
	end

	index.setEggEsp = function(arg, arg2)
		arg.config.espEnabled = arg2 == true

		if not arg.config.espEnabled then
			pcall(function()
				arg:_clearEsp()
			end)
		end
	end

	index.setEspMinRank = function(arg, arg2)
		arg.config.espMinRank = math.max(tonumber(arg2) or 0, 0)
	end

	index.setEspMinValue = function(arg, arg2)
		arg.config.espMinValue = math.max(tonumber(arg2) or 0, 0)
	end

	index._espPasses = function(arg, arg2, arg3)
		local config = arg.config
		local espMinRank = config.espMinRank
		if espMinRank and (espMinRank > 0 and (tonumber(arg2 and arg2.rarityRank) or 0) < config.espMinRank) then
			return false
		end
		local espMinValue = config.espMinValue
		if espMinValue and (espMinValue > 0 and (tonumber(arg3) or 0) < config.espMinValue) then
			return false
		end
		return true
	end

	index.setEspOption = function(arg, arg2, arg3)
		if tbl18[arg2] then
			arg.config["esp" .. arg2:sub(1, 1):upper() .. arg2:sub(2)] = arg3 == true
		end
	end

	index._clearEsp = function(arg)
		local areaEggSlotsClient = workspace:FindFirstChild("AreaEggSlotsClient")
		if not areaEggSlotsClient then
			return
		end

		for i, child in ipairs(areaEggSlotsClient:GetChildren()) do
			local v9 = child:FindFirstChild(name4)

			if v9 then
				v9:Destroy()
			end

			local v10 = child:FindFirstChild(name5)

			if v10 then
				v10:Destroy()
			end
		end
	end

	index._updateEsp = function(arg)
		local areaEggSlotsClient = workspace:FindFirstChild("AreaEggSlotsClient")
		if not areaEggSlotsClient then
			return
		end
		local config = arg.config

		for i, child in ipairs(areaEggSlotsClient:GetChildren()) do
			local v9 = arg.records[child.Name]
			local flag5 = config.espEnabled and v9 ~= nil and (v9.State == AreaEggs.States.Slot or v9.State == AreaEggs.States.Dropped)
			local v10 = flag5 and (if arg:_espPasses(arg.catalog.resolve(v9), fn66(v9)) then flag5 else false)
			local hitbox = v10 and (child:FindFirstChild("Hitbox") or child:FindFirstChildWhichIsA("BasePart", true))
			local billboardGui = child:FindFirstChild(name4)
			local highlight = child:FindFirstChild(name5)

			if if v10 then not hitbox else not v10 then
				if billboardGui then
					billboardGui:Destroy()
				end

				if highlight then
					highlight:Destroy()
				end
			else
				if billboardGui then
					if billboardGui:FindFirstChild("Icon") then
					else
						billboardGui:Destroy()
						billboardGui = nil
					end
				end

				if billboardGui then
				else
					billboardGui = Instance.new("BillboardGui")
					billboardGui.Name = name4
					billboardGui.AlwaysOnTop = true
					billboardGui.Size = UDim2.fromOffset(220, 72)
					billboardGui.StudsOffset = Vector3.new(0, 4.4, 0)
					billboardGui.MaxDistance = 1000
					billboardGui.Adornee = hitbox
					local imageLabel = Instance.new("ImageLabel")
					imageLabel.Name = "Icon"
					imageLabel.AnchorPoint = Vector2.new(0.5, 1)
					imageLabel.Position = UDim2.fromScale(0.5, 0.42)
					imageLabel.Size = UDim2.fromOffset(30, 30)
					imageLabel.BackgroundTransparency = 1
					imageLabel.ScaleType = Enum.ScaleType.Fit
					imageLabel.Visible = false
					imageLabel.Parent = billboardGui
					local textLabel = Instance.new("TextLabel")
					textLabel.Name = "Text"
					textLabel.AnchorPoint = Vector2.new(0.5, 0)
					textLabel.Position = UDim2.fromScale(0.5, 0.45)
					textLabel.Size = UDim2.new(1, 0, 0.55, 0)
					textLabel.BackgroundTransparency = 1
					textLabel.Font = Enum.Font.GothamBold
					textLabel.TextSize = 13
					textLabel.TextStrokeTransparency = 0.35
					textLabel.TextXAlignment = Enum.TextXAlignment.Center
					textLabel.TextYAlignment = Enum.TextYAlignment.Top
					textLabel.Parent = billboardGui
					billboardGui.Parent = child
				end

				billboardGui.Adornee = hitbox
				local tbl21 = arg.catalog.resolve(v9)
				local icon = billboardGui:FindFirstChild("Icon")
				local icon2 = config.espIcon and type(tbl21.icon) == "string" and tbl21.icon ~= "" and tbl21.icon or nil
				icon.Image = icon2 or ""
				icon.Visible = icon2 ~= nil
				local rarityColor = typeof(tbl21.rarityColor) == "Color3" and tbl21.rarityColor or Color3.fromRGB(255, 255, 255)
				local tbl22 = {}

				if config.espRarity then
					tbl22[#tbl22 + 1] = string.upper(tbl21.rarity or "?")
				end

				if config.espName then
					tbl22[#tbl22 + 1] = tostring(tbl21.name)
				end

				if config.espKg then
					tbl21 = arg:_resolveWeightKg(v9)

					if tbl21 then
						tbl22[#tbl22 + 1] = string.format("%d Kg", math.floor(tbl21))
					end
				end

				if config.espMutation and type(v9.Mutations) == "table" and next(v9.Mutations) then
					tbl21 = {}

					for k, mutation in pairs(v9.Mutations) do
						tbl21[#tbl21 + 1] = tostring(mutation)
					end

					if #tbl21 > 0 then
						table.sort(tbl21)
						tbl22[#tbl22 + 1] = table.concat(tbl21, ", ")
					end
				end

				if config.espValue then
					tbl21 = fn66(v9)

					if tbl21 then
						tbl22[#tbl22 + 1] = "$" .. fn94(tbl21) .. "/s"
					end
				end

				local text = billboardGui:FindFirstChild("Text")
				text.Text = table.concat(tbl22, " | ")
				text.TextColor3 = rarityColor

				if highlight then
					if highlight:IsA("Highlight") then
					else
						highlight:Destroy()
						highlight = nil
					end
				end

				if highlight then
				else
					highlight = Instance.new("Highlight")
					highlight.Name = name5
					highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					highlight.Parent = child
				end

				highlight.Adornee = child
				highlight.FillColor = rarityColor
				highlight.FillTransparency = 0.72
				highlight.OutlineColor = rarityColor
				highlight.OutlineTransparency = 0
			end
		end

		arg._placedEspAnchors = arg._placedEspAnchors or {}
		os.clock()

		if config.espPlaced then
			local v9 = (Save.Peek or Save.Get)()
			local eggInventory = type(v9) == "table" and v9.EggInventory or nil
			local centerPoint = PlotState2.ResolveLocalSlot()
			local fanKunHubPlacedEggAnchors = PlotState2.ResolveFolder()
			local v10 = fanKunHubPlacedEggAnchors and centerPoint and fanKunHubPlacedEggAnchors:FindFirstChild(tostring(centerPoint))
			centerPoint = v10 and v10:FindFirstChild("CenterPoint")
			local v11 = centerPoint and (if centerPoint:IsA("BasePart") then centerPoint else nil)
			local tbl21 = {}

			if type(eggInventory) == "table" and v11 then
				fanKunHubPlacedEggAnchors = workspace:FindFirstChild("FanKunHUBPlacedEggAnchors")

				if fanKunHubPlacedEggAnchors then
				else
					fanKunHubPlacedEggAnchors = Instance.new("Folder")
					fanKunHubPlacedEggAnchors.Name = "FanKunHUBPlacedEggAnchors"
					fanKunHubPlacedEggAnchors.Parent = workspace
				end

				for i, child in ipairs(fanKunHubPlacedEggAnchors:GetChildren()) do
					if child:IsA("Highlight") then
						child:Destroy()
					elseif child:IsA("BillboardGui") then
						child:Destroy()
					end
				end

				for k, v12 in pairs(eggInventory) do
					if type(k) == "string" and (type(v12) == "table" and type(v12.Placement) == "table") then
						tbl21[k] = true
						local localCFrame = v12.Placement.LocalCFrame

						if typeof(localCFrame) ~= "CFrame" then
							local ok, result = pcall(EggRecords.Decode, v12)
							local placement = ok and type(result) == "table" and result.Placement or nil
							localCFrame = type(placement) == "table" and placement.LocalCFrame or nil
						end

						if typeof(localCFrame) == "CFrame" then
							local ok, result = pcall(EggRecords.Decode, v12)
							local flag5 = ok and type(result) == "table" and result or v12
							result = tonumber(flag5.AssetScale) or 1
							local cFrame = v11.CFrame * localCFrame + Vector3.new(0, 3 + result * 2, 0)
							arg._placedEspAnchors[k] = arg._placedEspAnchors[k] or {}
							local v13 = arg._placedEspAnchors[k]

							if typeof(v13.anchor) ~= "Instance" then
								local part = Instance.new("Part")
								part.Name = "FanKunHUBPE_" .. k
								part.Size = Vector3.new(1.5, 1.5, 1.5)
								part.Transparency = 1
								part.Anchored = true
								part.CanCollide = false
								part.CanQuery = false
								part.CanTouch = false
								part.Parent = fanKunHubPlacedEggAnchors
								v13.anchor = part
							end

							v13.anchor.CFrame = cFrame
							local v14 = arg.catalog.resolve({AssetCategory = flag5.AssetCategory})
							local rarityColor = typeof(v14.rarityColor) == "Color3" and v14.rarityColor or Color3.fromRGB(255, 255, 255)
							local billboardGui = fn66({Category = flag5.AssetCategory, Mutations = type(flag5.Mutations) == "table" and flag5.Mutations or {}, Scale = result, BaseMutation = type(flag5.BaseMutation) == "string" and flag5.BaseMutation or nil})
							if not arg:_espPasses(v14, billboardGui) then
								tbl21[k] = nil
								continue
							end
							local tbl22 = {}

							if config.espRarity then
								tbl22[#tbl22 + 1] = string.upper(v14.rarity or "?")
							end

							if config.espName then
								tbl22[#tbl22 + 1] = tostring(v14.name)
							end

							if config.espKg then
								local ok2, result2 = pcall(EggRecords.WeightKgForScale, flag5.AssetCategory, result)

								if ok2 and type(result2) == "number" then
									tbl22[#tbl22 + 1] = string.format("%d Kg", math.floor(result2))
								end
							end

							if config.espValue and billboardGui then
								tbl22[#tbl22 + 1] = "$" .. fn94(billboardGui) .. "/s"
							end

							if type(v12.Placement.ReadyAt) == "number" then
								tbl22[#tbl22 + 1] = "READY"
							elseif type(flag5.Placement) == "table" then
								if flag5.Placement.ReadyAt ~= nil then
									tbl22[#tbl22 + 1] = "READY"
								end
							end

							billboardGui = v13.anchor:FindFirstChild(name4)

							if billboardGui then
							else
								billboardGui = Instance.new("BillboardGui")
								billboardGui.Name = name4
								billboardGui.AlwaysOnTop = true
								billboardGui.Size = UDim2.fromOffset(220, 72)
								billboardGui.StudsOffset = Vector3.new(0, 1.4, 0)
								billboardGui.MaxDistance = 1000
								local imageLabel = Instance.new("ImageLabel")
								imageLabel.Name = "Icon"
								imageLabel.AnchorPoint = Vector2.new(0.5, 1)
								imageLabel.Position = UDim2.fromScale(0.5, 0.42)
								imageLabel.Size = UDim2.fromOffset(34, 34)
								imageLabel.BackgroundTransparency = 1
								imageLabel.ScaleType = Enum.ScaleType.Fit
								imageLabel.Visible = false
								imageLabel.Parent = billboardGui
								local textLabel = Instance.new("TextLabel")
								textLabel.Name = "Text"
								textLabel.AnchorPoint = Vector2.new(0.5, 0)
								textLabel.Position = UDim2.fromScale(0.5, 0.45)
								textLabel.Size = UDim2.new(1, 0, 0.55, 0)
								textLabel.BackgroundTransparency = 1
								textLabel.Font = Enum.Font.GothamBold
								textLabel.TextSize = 13
								textLabel.TextStrokeTransparency = 0.35
								textLabel.TextXAlignment = Enum.TextXAlignment.Center
								textLabel.TextYAlignment = Enum.TextYAlignment.Top
								textLabel.Parent = billboardGui
								billboardGui.Parent = v13.anchor
							end

							local icon = billboardGui:FindFirstChild("Icon")

							if icon then
								local icon2 = config.espIcon and type(v14.icon) == "string" and v14.icon ~= "" and v14.icon or nil
								icon.Image = icon2 or ""
								icon.Visible = icon2 ~= nil
							end

							local text = billboardGui:FindFirstChild("Text")
							text.Text = table.concat(tbl22, " | ")
							text.TextColor3 = rarityColor
							local v15 = v13.anchor:FindFirstChild(name5)

							if v15 then
								v15:Destroy()
							end
						end
					end
				end
			end

			for k, placedEspAnchor in pairs(arg._placedEspAnchors) do
				if not tbl21[k] then
					if typeof(placedEspAnchor.anchor) == "Instance" then
						placedEspAnchor.anchor:Destroy()
					end

					if typeof(placedEspAnchor.highlight) == "Instance" then
						placedEspAnchor.highlight:Destroy()
					end

					arg._placedEspAnchors[k] = nil
				end
			end
		else
			for k, v9 in pairs(arg._placedEspAnchors or {}) do
				if typeof(v9.anchor) == "Instance" then
					v9.anchor:Destroy()
				end

				if typeof(v9.highlight) == "Instance" then
					v9.highlight:Destroy()
				end

				arg._placedEspAnchors[k] = nil
			end
		end
	end

	index.setMinWeightKg = function(arg, arg2)
		local n76 = tonumber(arg2) or 0
		arg.config.minWeightKg = math.max(n76, 0)
	end

	index.setMinValuePerSec = function(arg, arg2)
		local n76 = tonumber(arg2) or 0
		arg.config.minValuePerSec = math.max(n76, 0)
		arg:_refreshCounts()
		arg:_schedule()
	end

	index.setSpeed = function(arg, arg2)
		local n76 = math.clamp(math.floor((tonumber(arg2) or n11) + 0.5), n9, n10)
		arg.config.speed = n76 * n8

		if genv.__FanKunHUBAdminBoost == true then
			arg.config.speed = speed
		end

		if arg.enabled then
			arg:_startMovementProtection()
		elseif arg.activeTween then
			arg:_startMovementProtection()
		end

		return n76
	end

	index.getDefaultSpeed = function(arg)
		return n11
	end

	index.setFilterEnabled = function(arg, arg2, arg3)
		arg.config[arg2 .. "Enabled"] = arg3 == true
		arg:_refreshCounts()
		arg:_schedule()
	end

	index.setFilter = function(arg, arg2, arg3)
		local tbl21 = type(arg3) == "table" and table.clone(arg3) or {}

		if arg2 == "mutations" and type(arg.catalog.resolveMutationId) == "function" then
			local tbl22 = {}

			for i, v9 in ipairs(tbl21) do
				local v10 = arg.catalog.resolveMutationId(v9)

				if v10 then
					table.insert(tbl22, v10)
				end
			end

			tbl21 = tbl22
		end

		arg.config[arg2] = tbl21
		arg:_refreshCounts()
		arg:_schedule()
	end

	index.destroy = function(arg)
		if arg.destroyed then
			return
		end
		arg.destroyed = true
		arg.enabled = false
		arg:_mutePortalFx(false, true)
		pcall(arg._guardLagback, arg, false)
		pcall(arg._stopScramblePortalBypass, arg)
		pcall(arg._removePromptFilter, arg)

		if arg._relocateConn then
			pcall(arg._relocateConn.Disconnect, arg._relocateConn)
			arg._relocateConn = nil
		end

		arg._recalling = nil
		arg:_hideTreadmillDecoy()
		arg.planGeneration = arg.planGeneration + 1
		arg.carry.generation += 1
		arg:_invalidateCarryWorker()
		arg.carry.active = false
		arg.carry.uid = nil
		arg.tweenRecoveryUid = nil
		arg.safeStarting = false
		arg:_cancelTween("Destroyed")
		arg:_cleanupInstantSteal()
		arg:_removeGuardHitDistanceBoost()
		arg:_releaseOperation()
		arg:_stopMovementProtection()

		if arg._healthPinner then
			pcall(arg._healthPinner.Disconnect, arg._healthPinner)
			arg._healthPinner = nil
		end

		if arg._healthChangedConnection then
			pcall(arg._healthChangedConnection.Disconnect, arg._healthChangedConnection)
			arg._healthChangedConnection = nil
		end

		arg:_restoreClaimPresentationFilter()
		fn70(localPlayer2.Character)

		pcall(function()
			arg:_clearEsp()
		end)

		pcall(function()
			for k, v9 in pairs(arg._placedEspAnchors or {}) do
				if typeof(v9.anchor) == "Instance" then
					v9.anchor:Destroy()
				end
			end

			local fanKunHubPlacedEggAnchors = workspace:FindFirstChild("FanKunHUBPlacedEggAnchors")

			if fanKunHubPlacedEggAnchors then
				fanKunHubPlacedEggAnchors:Destroy()
			end
		end)

		fn64(arg.connections)
		table.clear(arg.listeners)
		table.clear(arg.records)
	end

	return index
end)()

local tbl11 = {k = 1000, m = 1000000, b = 1000000000, t = 1000000000000, q = 1000000000000000}

local function fn61(arg)
	local match, v9 = tostring(arg or ""):lower():gsub("%s+", ""):gsub("%$", ""):gsub("/s$", ""):match("^([%d%.]+)([kmbtq]?)$")
	local num = tonumber(match)
	if not num then
		return nil
	end
	return math.max(0, math.floor(num * (tbl11[v9] or 1) + 0.5))
end

local v9 = (function()
	local Players2 = game:GetService("Players")
	local RunService2 = game:GetService("RunService")
	local ReplicatedStorage2 = game:GetService("ReplicatedStorage")
	local localPlayer2 = Players2.LocalPlayer
	local Remotes = require(ReplicatedStorage2.Shared.Remotes)
	local EggState2 = require(ReplicatedStorage2.Client.EggState)
	local Ragdoll = require(ReplicatedStorage2.Shared.Modules.Ragdoll)
	local RagdollJoints = require(ReplicatedStorage2.Shared.Modules.RagdollJoints)
	local eggWorld = Remotes.EggWorld
	local n8 = 340
	local n9 = 240
	local n10 = 0.05
	local n11 = 5
	local index = {}
	index.__index = index

	local function fn62(arg)
		if arg then
			pcall(arg.Disconnect, arg)
		end
	end

	index.new = function(eggRuntime)
		local obj = setmetatable({}, index)
		obj.eggRuntime = eggRuntime
		obj.enabled = true
		obj.destroyed = false
		obj.connections = {}
		obj.originalRagdoll = {}
		obj.originalHumanoidStates = setmetatable({}, {__mode = "k"})
		obj.stats = {blockedHits = 0, blockedDrops = 0, recarriedEggs = 0}
		obj.lastHeldEggUid = nil
		obj.lastHeldSlotKey = nil
		obj._installed = false
		obj._stickyToken = 0
		obj._nextBodyRecoveryAt = 0
		obj._nextJointSweepAt = 0
		obj._forestStrikeOldFire = nil
		return obj
	end

	index._liveBody = function(arg)
		local character = localPlayer2.Character
		return character, character and character:FindFirstChildOfClass("Humanoid"), character and character:FindFirstChild("HumanoidRootPart")
	end

	index._recoverBody = function(arg, arg2)
		if arg.enabled then
			if arg.destroyed then
				return
			end
		else
			return
		end

		local v9, v10, v11 = arg:_liveBody()

		if v9 then
			if not v10 then
				return
			elseif v11 then
			else
				return
			end
		else
			return
		end

		local now = os.clock()
		if not arg2 and now < arg._nextBodyRecoveryAt then
			return
		end
		arg._nextBodyRecoveryAt = now + 0.03

		if not arg.originalHumanoidStates[v10] then
			local originalHumanoidStates = arg.originalHumanoidStates
			local tbl12 = {}
			tbl12.Physics = v10:GetStateEnabled(Enum.HumanoidStateType.Physics)
			tbl12.FallingDown = v10:GetStateEnabled(Enum.HumanoidStateType.FallingDown)
			tbl12.Ragdoll = v10:GetStateEnabled(Enum.HumanoidStateType.Ragdoll)
			originalHumanoidStates[v10] = tbl12
		end

		local state = v10:GetState()
		local flag5 = state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.FallingDown or state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.PlatformStanding or state == Enum.HumanoidStateType.Seated

		pcall(function()
			v10.BreakJointsOnDeath = false
			v10.RequiresNeck = false
			v10:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
			v10:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
			v10:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			v10:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			v10.PlatformStand = false
			v10.Sit = false
			local state2 = v10:GetState()

			if state2 == Enum.HumanoidStateType.Physics or state2 == Enum.HumanoidStateType.FallingDown or state2 == Enum.HumanoidStateType.Ragdoll or state2 == Enum.HumanoidStateType.PlatformStanding or state2 == Enum.HumanoidStateType.Seated then
				v10:ChangeState(Enum.HumanoidStateType.GettingUp)
				v10:ChangeState(Enum.HumanoidStateType.Running)
			end
		end)

		for i, descendant in ipairs(v9:GetDescendants()) do
			if descendant:IsA("Motor6D") then
				if not descendant.Enabled then
					descendant.Enabled = true
				end
			elseif descendant:IsA("BallSocketConstraint") or descendant:IsA("HingeConstraint") then
				if descendant.Name:find("Ragdoll", 1, true) then
					pcall(descendant.Destroy, descendant)
				elseif descendant:GetAttribute("RagdollConstraint") then
					pcall(descendant.Destroy, descendant)
				end
			end
		end

		local assemblyLinearVelocity = v11.AssemblyLinearVelocity

		if flag5 or Vector3.new(assemblyLinearVelocity.X, 0, assemblyLinearVelocity.Z).Magnitude > math.max(n8, (tonumber(v10.WalkSpeed) or 0) * 1.5) or math.abs(assemblyLinearVelocity.Y) > n9 then
			v11.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			v11.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			arg.stats.blockedHits = arg.stats.blockedHits + 1
		end
	end

	index._watchCharacter = function(arg, arg2)
		if not arg2 then
			return
		end

		local function fn63(descendant)
			if arg.enabled then
				if arg.destroyed then
					return
				end
			else
				return
			end

			if descendant:IsA("BallSocketConstraint") or descendant:IsA("HingeConstraint") then
				if descendant.Name:find("Ragdoll", 1, true) or descendant:GetAttribute("RagdollConstraint") then
					pcall(descendant.Destroy, descendant)
					arg:_recoverBody(true)
				end
			elseif descendant:IsA("Motor6D") then
				if not descendant.Enabled then
					descendant.Enabled = true
				end
			end
		end

		local connection6 = arg2.DescendantAdded:Connect(fn63)
		table.insert(arg.connections, connection6)
	end

	index._installRagdollHooks = function(arg)
		if arg._installed then
			return
		end
		arg._installed = true

		task.spawn(function()
			task.wait()
			local fanKunHubForestGate = genv.__FanKunHUBForestGate

			if type(fanKunHubForestGate) == "table" and (fanKunHubForestGate.comp and fanKunHubForestGate.orig) then
				pcall(rawset, fanKunHubForestGate.comp, "_attackHandler", fanKunHubForestGate.orig)
				genv.__FanKunHUBForestGate = nil
			end

			if type(getgc) ~= "function" then
				return
			end
			local ok, result = pcall(getgc, true)

			if ok then
				if type(result) ~= "table" then
					return
				end
			else
				return
			end

			for i, v9 in ipairs(result) do
				if i % 20000 == 0 then
					RunService2.Heartbeat:Wait()
				end

				if arg.destroyed then
					return
				end

				if type(v9) == "table" and rawget(v9, "_areaId") == "Forest" and type(rawget(v9, "_attackHandler")) == "function" then
					local value = rawget(v9, "_attackHandler")
					arg._forestGate = {comp = v9, orig = value}
					genv.__FanKunHUBForestGate = arg._forestGate

					rawset(v9, "_attackHandler", function(...)
						if arg.enabled and (not arg.destroyed and (not (arg.eggRuntime and arg.eggRuntime.instantPhase == "priming") and not (genv.__FanKunHUBPlayerSteal and genv.__FanKunHUBPlayerSteal.running))) then
							arg.stats.blockedHits = arg.stats.blockedHits + 1
							arg:_recoverBody(true)

							if genv.__FanKunHUBGodMode then
								genv.__FanKunHUBGodMode:startDefend()
							end

							return
						end

						return value(...)
					end)

					break
				end
			end
		end)

		for i, v9 in ipairs({"ApplyClientRagdoll", "Ragdoll", "TimedRagdoll", "TimedRagdollAsync"}) do
			if type(Ragdoll[v9]) == "function" then
				arg.originalRagdoll[v9] = Ragdoll[v9]

				Ragdoll[v9] = function(...)
					if arg.enabled and not arg.destroyed then
						arg.stats.blockedHits = arg.stats.blockedHits + 1
						arg:_recoverBody(true)
						return
					end

					return arg.originalRagdoll[v9](...)
				end
			end
		end

		if type(Ragdoll.IsRagdolled) == "function" then
			arg.originalRagdoll.IsRagdolled = Ragdoll.IsRagdolled

			function Ragdoll.IsRagdolled(arg2)
				if arg.enabled and arg2 == localPlayer2.Character then
					return false
				end
				return arg.originalRagdoll.IsRagdolled(arg2)
			end
		end
	end

	index._restoreLocalState = function(arg)
		for k, originalHumanoidState in pairs(arg.originalHumanoidStates) do
			if k.Parent then
				pcall(function()
					k:SetStateEnabled(Enum.HumanoidStateType.Physics, originalHumanoidState.Physics)
					k:SetStateEnabled(Enum.HumanoidStateType.FallingDown, originalHumanoidState.FallingDown)
					k:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, originalHumanoidState.Ragdoll)
				end)
			end
		end

		arg.originalHumanoidStates = setmetatable({}, {__mode = "k"})
		pcall(RagdollJoints.Release, localPlayer2.Character)
	end

	index._slotKey = function(arg, arg2)
		if type(arg2) ~= "table" then
			return nil
		elseif type(arg2.AreaId) ~= "string" then
			return nil
		elseif type(arg2.NestId) ~= "string" then
			return nil
		end

		return string.format("%s:%s", arg2.AreaId, arg2.NestId)
	end

	index._requestCarry = function(arg, arg2, firstAreaSlotKey)
		local tbl12 = {Uid = arg2}

		if firstAreaSlotKey ~= nil then
			tbl12.FirstAreaSlotKey = firstAreaSlotKey
		end

		return eggWorld.AskFieldEggCarry:InvokeServer(tbl12)
	end

	index._startSticky = function(arg, lastHeldEggUid, lastHeldSlotKey)
		if type(lastHeldEggUid) ~= "string" then
			return
		elseif lastHeldEggUid == "" then
			return
		end

		arg._stickyToken = arg._stickyToken + 1
		local stickyToken = arg._stickyToken
		arg.stats.recarriedEggs = arg.stats.recarriedEggs + 1

		task.spawn(function()
			local n12 = os.clock() + n11

			while true do
				local destroyed = arg.destroyed
				if not ((if destroyed then not destroyed else arg.enabled) and stickyToken == arg._stickyToken and os.clock() < n12) then
					break
				end
				local v9 = EggState2.ReadFieldEgg(lastHeldEggUid)

				if v9 and (v9.State == "Carried" and v9.CarrierUserId == localPlayer2.UserId) then
					arg.lastHeldEggUid = lastHeldEggUid
					arg.lastHeldSlotKey = lastHeldSlotKey or arg:_slotKey(v9)
					return
				end

				if v9 and (v9.State == "Dropped" or v9.State == "Slot") then
					if arg.eggRuntime and arg.eggRuntime:requestCarryRecovery(lastHeldEggUid) then
						return
					end
					local v10, v11, v12 = arg:_liveBody()

					if v12 and (v9.BottomCFrame and (v12.Position - v9.BottomCFrame.Position).Magnitude <= 10) then
						pcall(arg._requestCarry, arg, lastHeldEggUid, lastHeldSlotKey or arg:_slotKey(v9))
					end
				end

				task.wait(n10)
			end
		end)
	end

	index._bindSignals = function(arg)
		table.insert(arg.connections, EggState2.CarryChanged:Connect(function(arg2)
			if not arg.enabled then
				return
			end

			if arg2.IsCarrying and type(arg2.Uid) == "string" then
				arg._stickyToken = arg._stickyToken + 1
				arg.lastHeldEggUid = arg2.Uid
				arg.lastHeldSlotKey = arg:_slotKey((EggState2.ReadFieldEgg(arg2.Uid)))
				return
			end

			local fanKunHubPlayerSteal = genv.__FanKunHUBPlayerSteal
			if fanKunHubPlayerSteal and fanKunHubPlayerSteal.running then
				return
			end
			local uid = arg2.Uid or arg.lastHeldEggUid
			local lastHeldSlotKey = arg.lastHeldSlotKey
			if arg.eggRuntime and arg.eggRuntime:isSkippedEgg(uid) then
				return
			end

			if uid then
				arg.stats.blockedDrops = arg.stats.blockedDrops + 1
				arg:_startSticky(uid, lastHeldSlotKey)

				if genv.__FanKunHUBGodMode then
					genv.__FanKunHUBGodMode:startDefend(uid)
				end
			end
		end))

		table.insert(arg.connections, localPlayer2.CharacterAdded:Connect(function(character)
			arg:_watchCharacter(character)

			task.defer(function()
				arg:_recoverBody(true)
			end)
		end))

		if localPlayer2.Character then
			arg:_watchCharacter(localPlayer2.Character)
		end

		table.insert(arg.connections, RunService2.Stepped:Connect(function()
			arg:_recoverBody()
		end))
	end

	index.setEnabled = function(arg, arg2)
		local enabled = arg2 == true
		if arg.enabled == enabled then
			return
		end
		arg.enabled = enabled

		if arg.enabled then
			arg:_recoverBody()
		else
			arg._stickyToken = arg._stickyToken + 1
			arg:_restoreLocalState()
		end
	end

	index.install = function(fanKunHubAntiGuard)
		if fanKunHubAntiGuard.destroyed then
			return false
		end
		getgenv().__FanKunHUBAntiGuard = fanKunHubAntiGuard
		fanKunHubAntiGuard:_installRagdollHooks()
		fanKunHubAntiGuard:_bindSignals()
		fanKunHubAntiGuard:_recoverBody()
		return true
	end

	index.destroy = function(arg)
		if arg.destroyed then
			return
		end
		arg.enabled = false
		arg:_restoreLocalState()
		arg.destroyed = true
		arg._stickyToken = arg._stickyToken + 1

		for i, connection6 in ipairs(arg.connections) do
			fn62(connection6)
		end

		table.clear(arg.connections)

		for k, v9 in pairs(arg.originalRagdoll) do
			if type(v9) == "function" then
				Ragdoll[k] = v9
			end
		end

		if arg._forestGate then
			pcall(rawset, arg._forestGate.comp, "_attackHandler", arg._forestGate.orig)

			if genv.__FanKunHUBForestGate == arg._forestGate then
				genv.__FanKunHUBForestGate = nil
			end

			arg._forestGate = nil
		end

		arg.eggRuntime = nil

		if getgenv().__FanKunHUBAntiGuard == arg then
			getgenv().__FanKunHUBAntiGuard = nil
		end
	end

	index.getStats = function(arg)
		return arg.stats
	end

	return index
end)()

local v10 = (function()
	local Players2 = game:GetService("Players")
	game:GetService("RunService")
	local ReplicatedStorage2 = game:GetService("ReplicatedStorage")
	local localPlayer2 = Players2.LocalPlayer
	local index = {}
	index.__index = index

	index.new = function(eggRuntime)
		local obj = setmetatable({}, index)
		obj.eggRuntime = eggRuntime
		obj.enabled = true
		obj.active = false
		obj.activeDroppedUid = nil
		obj.swingSequence = 0
		obj.lastSwingAt = 0
		obj.defendThread = nil
		obj.connections = {}
		obj.targetRange = 35
		obj:_bindSignals()
		return obj
	end

	index._isBat = function(arg, arg2)
		if arg2 then
			if not arg2:IsA("Tool") then
				return false
			end
		else
			return false
		end

		local fanKunHubIsBatTool = genv.__FanKunHUBIsBatTool
		if fanKunHubIsBatTool and fanKunHubIsBatTool(arg2) then
			return true
		end

		if not fanKunHubIsBatTool then
			if arg2:GetAttribute("IsBat") == true then
				return true
			elseif arg2:GetAttribute("GearName") == "Bat" then
				return true
			end
		end

		local attribute = arg2:GetAttribute("ItemType")
		if attribute ~= nil and attribute ~= "Gear" then
			return false
		end
		return string.find(string.lower(arg2.Name), "slap", 1, true) ~= nil
	end

	index._findBat = function(arg)
		local character = localPlayer2.Character
		local backpack = localPlayer2:FindFirstChildOfClass("Backpack")

		if character then
			for i, child in ipairs(character:GetChildren()) do
				if arg:_isBat(child) then
					return child, true
				end
			end
		end

		if backpack then
			for i, child in ipairs(backpack:GetChildren()) do
				if arg:_isBat(child) then
					return child, false
				end
			end
		end

		pcall(function()
			local networking = ReplicatedStorage2:FindFirstChild("Packages") and ReplicatedStorage2.Packages:FindFirstChild("Networking")
			local rfCodexAskWearFieldBat = networking and networking:FindFirstChild("RF/Codex/AskWearFieldBat")

			if rfCodexAskWearFieldBat then
				rfCodexAskWearFieldBat:InvokeServer()
			end
		end)

		return nil, false
	end

	index._equipBat = function(arg)
		local character = localPlayer2.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if humanoid then
			if humanoid.Health <= 0 then
				return nil
			end
		else
			return nil
		end

		local v10, v11 = arg:_findBat()
		if not v10 then
			return nil
		end

		if v11 and v10.Parent == character then
			return v10
		end
		pcall(humanoid.EquipTool, humanoid, v10)
		local n8 = os.clock() + 0.35

		while os.clock() < n8 do
			if v10.Parent == character then
				return v10
			end
			task.wait(0.05)
		end

		return v10.Parent == character and v10 or nil
	end

	index._getNearbyEnemies = function(arg)
		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then
			return {}
		end
		local tbl12 = {}

		for i, player in ipairs(Players2:GetPlayers()) do
			if player ~= localPlayer2 and player.Character then
				local humanoidRootPart2 = player.Character:FindFirstChild("HumanoidRootPart")
				local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

				if humanoidRootPart2 and (humanoid and humanoid.Health > 0) then
					local magnitude = (humanoidRootPart2.Position - humanoidRootPart.Position).Magnitude

					if magnitude <= arg.targetRange then
						table.insert(tbl12, {player = player, root = humanoidRootPart2, humanoid = humanoid, distance = magnitude})
					end
				end
			end
		end

		table.sort(tbl12, function(arg2, arg3)
			return arg2.distance < arg3.distance
		end)

		return tbl12
	end

	index._swing = function(arg, arg2, arg3)
		if arg2 then
			if arg2.Parent ~= localPlayer2.Character then
				return false
			end
		else
			return false
		end

		local serverTimeNow = workspace:GetServerTimeNow()
		if serverTimeNow - arg.lastSwingAt < 0.22 then
			return false
		end
		arg.lastSwingAt = serverTimeNow
		pcall(arg2.Activate, arg2)
		local handle = arg2:FindFirstChild("Handle") or arg2:FindFirstChildWhichIsA("BasePart", true)

		if handle and arg3 and type(firetouchinterest) == "function" then
			pcall(function()
				firetouchinterest(handle, arg3, 0)
				task.wait(0.01)
				firetouchinterest(handle, arg3, 1)
			end)
		end

		pcall(function()
			local batSwing = require(ReplicatedStorage2.Shared.Remotes).BatSwing

			if batSwing and batSwing.Trigger then
				arg.swingSequence = arg.swingSequence + 1
				local str3 = string.format("%d:%d:%d", localPlayer2.UserId, arg.swingSequence, math.floor(serverTimeNow * 1000))
				batSwing.Trigger:FireServer(nil, str3)
			end
		end)

		return true
	end

	index.startDefend = function(arg, activeDroppedUid)
		if not arg.enabled then
			return
		end

		if arg.eggRuntime and arg.eggRuntime.instantPhase == "priming" then
			return
		end

		if activeDroppedUid and (arg.eggRuntime and arg.eggRuntime:isSkippedEgg(activeDroppedUid)) then
			return
		end
		local fanKunHubPlayerSteal = genv.__FanKunHUBPlayerSteal
		if fanKunHubPlayerSteal and fanKunHubPlayerSteal.running then
			return
		end
		arg.active = true
		arg.activeDroppedUid = activeDroppedUid or arg.activeDroppedUid
		if arg.defendThread then
			return
		end

		arg.defendThread = task.spawn(function()
			local flag5 = false

			while arg.active and arg.enabled do
				if arg.eggRuntime and (arg.eggRuntime.carry and arg.eggRuntime.carry.active) then
					break
				end
				local fanKunHubPlayerSteal2 = genv.__FanKunHUBPlayerSteal
				if fanKunHubPlayerSteal2 and fanKunHubPlayerSteal2.running then
					flag5 = true
					break
				end
				local v10 = arg:_getNearbyEnemies()

				if #v10 > 0 then
					local v11 = arg:_equipBat()

					if v11 then
						for i, v12 in ipairs(v10) do
							if v12.root and v12.root.Parent then
								arg:_swing(v11, v12.root)
							end
						end
					end
				end

				task.wait(0.1)
			end

			arg.active = false
			arg.defendThread = nil
			if flag5 then
				return
			end

			pcall(function()
				local character = localPlayer2.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")

				if humanoid then
					humanoid:UnequipTools()
				end
			end)
		end)
	end

	index.stopDefend = function(arg)
		arg.active = false
		arg.activeDroppedUid = nil
	end

	index.setEnabled = function(arg, arg2)
		arg.enabled = arg2 == true

		if not arg.enabled then
			arg:stopDefend()
		end
	end

	index._bindSignals = function(arg)
		pcall(function()
			local EggState2 = require(ReplicatedStorage2.Client.EggState)

			table.insert(arg.connections, EggState2.CarryChanged:Connect(function(arg2)
				if arg2.IsCarrying then
					arg:stopDefend()
				elseif arg.enabled then
					arg:startDefend(arg2.Uid)
				end
			end))
		end)

		pcall(function()
			local Remotes = require(ReplicatedStorage2.Shared.Remotes)
			local forestStrike = Remotes.GuardPatrol and Remotes.GuardPatrol.ForestStrike

			if forestStrike then
				table.insert(arg.connections, forestStrike.OnClientEvent:Connect(function()
					if arg.enabled then
						arg:startDefend()
					end
				end))
			end
		end)
	end

	index.destroy = function(arg)
		arg:stopDefend()

		for i, connection6 in ipairs(arg.connections) do
			pcall(connection6.Disconnect, connection6)
		end

		table.clear(arg.connections)
	end

	return index
end)()

local v11 = (function()
	local Players2 = game:GetService("Players")
	local ReplicatedStorage2 = game:GetService("ReplicatedStorage")
	local localPlayer2 = Players2.LocalPlayer
	local Remotes = require(ReplicatedStorage2.Shared.Remotes)
	local PlotState2 = require(ReplicatedStorage2.Client.PlotState)
	local Hud = require(ReplicatedStorage2.Client.Hud)
	local Save = require(ReplicatedStorage2.Shared.Save)
	local Treadmills = require(ReplicatedStorage2.Data.Treadmills)
	local n8 = 8

	local function fn62()
		local treadmill = fanKunHubTaskLadder.blocker("treadmill")
		if treadmill then
			return "Yielding to " .. fanKunHubTaskLadder.TITLES[treadmill]
		end
		local treadmill2 = fanKunHubTaskLadder.holder("treadmill")
		if treadmill2 then
			return "Waiting for " .. fanKunHubTaskLadder.TITLES[treadmill2]
		end
		return nil
	end

	local function fn63()
		return fn62() ~= nil
	end

	local function fn64()
		return fanKunHubTaskLadder.blocker("treadmill") == "auto_steal"
	end

	local function fn65()
		return fn62() or "Yielding"
	end

	local n9 = 1
	local n10 = 0.15
	local n11 = 0.75
	local n12 = 0.35
	local n13 = 0.1
	local n14 = 1.5
	local n15 = 0.03
	local n16 = 0.2
	local n17 = 0.25
	local n18 = 0.35
	local n19 = 2.5
	local n20 = 3
	local index = {}
	index.__index = index

	index.new = function(coordinator, travel)
		local obj = setmetatable({}, index)
		obj.coordinator = coordinator
		obj.travel = travel
		obj.destroyed = false
		obj.listeners = {}
		obj.resources = {}
		obj.config = {disableDuringAutomation = true, idleFarm = false, autoUpgrade = false}
		obj.stats = {mode = "Idle", boost = "Waiting"}
		obj.busy = coordinator and coordinator:getSnapshot().busy == true or false
		obj.idleGeneration = 0
		obj.lastEquipAt = 0
		obj.activeTreadmill = nil
		obj.travelingToTreadmill = false
		obj.treadmillEquipPending = false
		obj.unequipGuardRunning = false
		obj.backgroundYieldRunning = false
		obj.lastBackgroundYieldAt = 0
		obj.carryPulseRunning = false
		obj.treadmillStateRevision = 0
		obj:_listenActiveTreadmill()

		task.spawn(function()
			pcall(function()
				obj:_syncActiveTreadmillSnapshot()
			end)
		end)

		obj:_listenCoordinator()
		obj:_listenSpeedGain()
		return obj
	end

	index._snapshot = function(arg)
		return {mode = arg.stats.mode, boost = arg.stats.boost, disableDuringAutomation = arg.config.disableDuringAutomation, idleFarm = arg.config.idleFarm}
	end

	index._emit = function(arg)
		local v11 = arg:_snapshot()

		for i, listener in ipairs(arg.listeners) do
			pcall(listener, v11)
		end
	end

	index._setStatus = function(arg, mode, boost)
		if mode ~= nil then
			arg.stats.mode = mode
		end

		if boost ~= nil then
			arg.stats.boost = boost
		end

		arg:_emit()
	end

	index.subscribe = function(arg, arg2)
		table.insert(arg.listeners, arg2)
		pcall(arg2, arg:_snapshot())

		return function()
			local v11 = table.find(arg.listeners, arg2)

			if v11 then
				table.remove(arg.listeners, v11)
			end
		end
	end

	index._requestUnequip = function(arg)
		local ok, result, result2 = pcall(function()
			return Remotes.Treadmill.AskDoff:InvokeServer()
		end)

		if not ok then
			return false, tostring(result)
		end

		if result == false then
			return false, tostring(result2 or "Server rejected")
		end
		return true
	end

	index._shouldBlockTreadmill = function(arg)
		if arg.destroyed then
			return false
		elseif arg.carryPulseRunning then
			return false
		end

		if arg.busy and arg.config.disableDuringAutomation then
			return true
		end
		local fanKunHubEggRuntime = genv.__FanKunHUBEggRuntime
		if fanKunHubEggRuntime and fanKunHubEggRuntime._treadmillResetting then
			return false
		end
		local ok, result = pcall(fanKunHubTaskLadder.holder, "treadmill")
		return ok and result ~= nil
	end

	index._startUnequipGuard = function(arg)
		if arg.unequipGuardRunning then
			return
		elseif arg:_shouldBlockTreadmill() then
			if arg.activeTreadmill == nil then
				return
			end
		else
			return
		end

		arg.unequipGuardRunning = true

		task.spawn(function()
			local n21 = n10

			while arg:_shouldBlockTreadmill() and arg.activeTreadmill ~= nil do
				local v11, v12 = arg:_requestUnequip()
				arg:_setStatus("Automation active", v11 and "Blocked" or "Release retry: " .. tostring(v12))
				task.wait(n21)
				n21 = math.min(n21 * 2, n11)
			end

			arg.unequipGuardRunning = false

			if arg:_shouldBlockTreadmill() and arg.activeTreadmill ~= nil then
				arg:_startUnequipGuard()
			end
		end)
	end

	index._cancelIdle = function(arg, arg2)
		arg.idleGeneration = arg.idleGeneration + 1

		if arg2 then
			arg:_requestUnequip()
		end
	end

	index.setDisableDuringAutomation = function(arg, arg2)
		arg.config.disableDuringAutomation = true

		if arg.busy and arg.config.disableDuringAutomation then
			arg:_cancelIdle(true)
			arg:_startUnequipGuard()
			arg:_setStatus("Automation active", "Blocked")
		elseif not arg.busy then
			if arg.config.idleFarm then
				arg:_startIdle()
			end
		end
	end

	index.setIdleFarm = function(arg, arg2)
		arg.config.idleFarm = arg2 == true

		if not arg.config.idleFarm then
			arg:_cancelIdle(true)
			arg:_setStatus(arg.busy and "Automation active" or "Idle", "Disabled")
			return
		end

		if not arg.busy then
			arg:_startIdle()
		end

		if arg.idleWatchdog then
			return
		end

		arg.idleWatchdog = task.spawn(function()
			while true do
				local destroyed = arg.destroyed
				if not (if destroyed then not destroyed else arg.config.idleFarm) then
					break
				end
				task.wait(2)

				if arg.idleRunning == nil and (not arg.busy and (arg.config.idleFarm and not arg.destroyed)) then
					arg:_startIdle()
				end
			end

			arg.idleWatchdog = nil
		end)
	end

	index._readUpgradeState = function(arg)
		local ok, result, result2, result3 = pcall(function()
			local v11 = (Save.Peek or Save.Get)()
			if not v11 then
				return nil
			end
			local n21 = tonumber(v11.TreadmillUpgradeLevel) or 0
			return n21, v11.Money, Treadmills.GetByUpgradeLevel(n21 + 1)
		end)

		if ok then
			if result == nil then
				return nil
			end
		else
			return nil
		end

		return result, result2, result3
	end

	index._raiseTier = function(arg)
		local v11, v12, v13 = arg:_readUpgradeState()
		if not v13 then
			return false, "Max tier"
		end

		if (tonumber(v12) or 0) < (tonumber(v13.Price) or 0) then
			return false, "Not enough money"
		end

		local ok, result, result2 = pcall(function()
			return Remotes.Treadmill.AskTierRaise:InvokeServer(v13._id)
		end)

		if not ok then
			return false, tostring(result)
		end

		if result ~= true then
			return false, tostring(result2 or "Server rejected")
		end
		return true, v13.DisplayName or v13._id
	end

	index.setAutoUpgrade = function(arg, arg2)
		arg.config.autoUpgrade = arg2 == true

		if arg.config.autoUpgrade then
			if arg.autoUpgradeRunning then
				return
			end
		else
			return
		end

		arg.autoUpgradeRunning = true

		task.spawn(function()
			while true do
				local destroyed = arg.destroyed
				if not (if destroyed then not destroyed else arg.config.autoUpgrade) then
					break
				end
				local v11, v12 = arg:_raiseTier()

				if v11 then
					arg:_setStatus(arg.busy and "Automation active" or "Idle", "Upgraded to " .. tostring(v12))
					task.wait(1)
				elseif v12 == "Max tier" then
					arg:_setStatus(arg.busy and "Automation active" or "Idle", "Treadmill maxed")
					task.wait(30)
				else
					task.wait(5)
				end
			end

			arg.autoUpgradeRunning = false
		end)
	end

	index._resolveStandCFrame = function(arg)
		local v11 = PlotState2.ResolveLocalSlot()
		local v12 = PlotState2.ResolveFolder()
		local v13 = v12 and v11 and v12:FindFirstChild(tostring(v11))
		local treadmillBottom = v13 and v13:FindFirstChild("TreadmillBottom")

		if treadmillBottom then
			if not treadmillBottom:IsA("BasePart") then
				return nil
			end
		else
			return nil
		end

		local character = localPlayer2.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if humanoidRootPart then
			if not humanoid then
				return nil
			end
		else
			return nil
		end

		local v14 = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoidRootPart.Size.Y * 0.5 + math.max(humanoid.HipHeight, 0.5) else humanoidRootPart.Size.Y * 0.5 + 2
		return treadmillBottom.CFrame * CFrame.new(0, treadmillBottom.Size.Y * 0.5 + v14 + 0.05, 0)
	end

	index.isEngaged = function(arg)
		return arg.activeTreadmill ~= nil or arg.travelingToTreadmill or arg.treadmillEquipPending or arg.carryPulseRunning
	end

	index._isTreadmillHudActive = function(arg)
		local ok, result = pcall(function()
			local Game = Hud.Frame("Game")
			local Treadmill = Hud.Frame("Treadmill")
			return Game.Visible == false and Treadmill.Visible == true
		end)

		return ok and result == true
	end

	index._isGameHudRestored = function(arg)
		local ok, result = pcall(function()
			local Game = Hud.Frame("Game")
			local Treadmill = Hud.Frame("Treadmill")
			return Game.Visible == true and Treadmill.Visible == false
		end)

		return ok and result == true
	end

	index.pulseForCarry = function(arg, arg2, arg3)
		if arg.destroyed then
			return false, "Preparation unavailable"
		elseif arg.carryPulseRunning then
			return false, "Preparation unavailable"
		elseif type(arg2) ~= "function" then
			return false, "Preparation unavailable"
		end

		arg:_cancelIdle(false)
		arg.carryPulseRunning = true

		local function fn66()
			return arg.destroyed or arg3 ~= nil and arg3()
		end

		local function fn67(arg4)
			local n21, n22, treadmillStateRevision, v11 = os.clock() + arg4, 0, arg.treadmillStateRevision

			while true do
				local destroyed = arg.destroyed
				if not (if destroyed then not destroyed else os.clock() < n21) then
					break
				end
				local now = os.clock()

				if now >= n22 then
					arg:_requestUnequip()
					n22 = now + n10
				end

				local v12 = arg:_syncActiveTreadmillSnapshot()
				local v13 = arg:_isGameHudRestored()

				if arg.treadmillStateRevision ~= treadmillStateRevision then
					treadmillStateRevision = arg.treadmillStateRevision
					v11 = nil
				end

				if v12 then
					v11 = nil
				else
					if arg.activeTreadmill == nil then
						if v13 then
							local v14 = v11 or now
							if now - v14 >= n18 then
								return true
							end
							v11 = v14
						else
							v11 = nil
						end
					else
						v11 = nil
					end
				end

				task.wait(n15)
			end

			return false
		end

		local function fn68(arg4, arg5)
			if not arg4 then
				fn67(n14 + n18)
			end

			arg.treadmillEquipPending = false
			arg.carryPulseRunning = false

			if arg4 then
				arg:_setStatus("Automation active", "Preparation complete")
			elseif not arg.destroyed then
				arg:_setStatus("Automation active", tostring(arg5 or "Preparation failed"))
			end

			if arg:_shouldBlockTreadmill() and arg.activeTreadmill ~= nil then
				arg:_startUnequipGuard()
			end

			return arg4, arg5
		end

		arg:_syncActiveTreadmillSnapshot()
		local str3
		local flag5 = false

		for i = 1, n20, 1 do
			if fn66() then
				local cancelled, v11 = fn68(false, "Cancelled")
				return cancelled, v11
			end
			local cancelled = arg:_resolveStandCFrame()

			if cancelled then
				arg:_setStatus("Preparing carry", i == 1 and "Positioning" or "Repositioning")
				local ok, result = pcall(arg2, cancelled)

				if ok then
					local v11

					if result == true then
						task.wait(n12)
						arg.treadmillEquipPending = true
						arg:_setStatus("Preparing carry", "Activating")
						local n21 = os.clock() + n19
						local n22 = 0
						local flag6 = flag5
						local n23 = 0
						v11 = str3

						while true do
							local v12 = fn66()
							if not (if v12 then not v12 else os.clock() < n21) then
								break
							end
							local now = os.clock()

							if now >= n22 then
								n22 = now + n17
								arg:_syncActiveTreadmillSnapshot()
							end

							if arg.activeTreadmill ~= nil and arg:_isTreadmillHudActive() then
								flag6 = true
								break
							end

							if arg.activeTreadmill == nil and now >= n23 then
								local n24, ok2, result2, result3 = now + n16, pcall(function()
									return Remotes.Treadmill.AskWearStill:InvokeServer()
								end)

								if if ok2 then result2 == false else not ok2 then
									local str4 = tostring(result3 or result2)
									arg:_setStatus("Preparing carry", "Activation retry")
									v11 = str4
								end

								n23 = n24
							end

							task.wait(n15)
						end

						str3 = v11
						flag5 = flag6
					else
						str3 = "Positioning failed"
					end
				else
					str3 = "Positioning failed"
				end
			else
				str3 = "Position unavailable"
			end

			if flag5 then
				break
			end

			if fn66() then
				cancelled, i = fn68(false, "Cancelled")
				return cancelled, i
			end
			arg:_setStatus("Preparing carry", "Resetting position")
			fn67(n14 + n18)
		end

		if not flag5 then
			local v11, v12 = fn68(false, "Activation not confirmed: " .. tostring(str3 or "Unknown"))
			return v11, v12
		end
		arg.treadmillEquipPending = false
		arg:_setStatus("Preparing carry", "Active")
		local n21 = os.clock() + n13

		while true do
			local v11 = fn66()
			if not (if v11 then not v11 else os.clock() < n21) then
				break
			end
			task.wait(n15)
		end

		if fn66() then
			local cancelled, v11 = fn68(false, "Cancelled")
			return cancelled, v11
		end
		arg:_setStatus("Preparing carry", "Releasing")
		if fn67(n14 + n18) then
			local v11, v12 = fn68(true)
			return v11, v12
		end
		local v11, v12 = fn68(false, fn66() and "Cancelled" or "Release not confirmed")
		return v11, v12
	end

	index.yieldForBackground = function(arg)
		if arg.destroyed then
			return
		end
		arg:_cancelIdle(false)
		if arg.backgroundYieldRunning then
			return
		end
		arg.backgroundYieldRunning = true

		task.spawn(function()
			local n21 = n10

			while not arg.destroyed do
				if arg.coordinator then
					if not arg.coordinator:isBackgroundBusy() then
						break
					end
				else
					break
				end

				arg.lastBackgroundYieldAt = os.clock()
				arg:_setStatus("Idle", "Yielding to background inventory")
				arg:_requestUnequip()
				task.wait(n21)
				if not arg:_syncActiveTreadmillSnapshot() then
					break
				end
				n21 = math.min(n21 * 2, n11)
			end

			arg.backgroundYieldRunning = false

			if not arg.destroyed and not arg:isEngaged() then
				arg:_setStatus("Idle", "Background inventory ready")
			end
		end)
	end

	index._startIdle = function(arg)
		if arg.destroyed then
			return
		elseif arg.busy then
			return
		elseif not arg.config.idleFarm then
			return
		end

		arg:_cancelIdle(false)
		local idleGeneration = arg.idleGeneration
		local now = os.clock()
		arg.idleRunning = idleGeneration

		task.spawn(function()
			local ok, result = xpcall(function()
				while true do
					local destroyed = arg.destroyed
					if not ((if destroyed then not destroyed else not arg.busy) and arg.config.idleFarm and idleGeneration == arg.idleGeneration) then
						break
					end

					if arg.coordinator and arg.coordinator:isBackgroundBusy() then
						now = os.clock()
						arg:_setStatus("Idle", "Waiting for background inventory")
						task.wait(0.25)
						continue
					end

					if fn64() then
						now = os.clock()
						arg:_setStatus("Idle", "Yielding to Auto Steal")
						task.wait(0.25)
						continue
					end

					if genv.__FanKunHUBIsAutoSellEggBusy and genv.__FanKunHUBIsAutoSellEggBusy() then
						now = os.clock()
						arg:_setStatus("Idle", "Waiting for Auto Sell Egg")
						task.wait(0.25)
						continue
					end

					if fn63() then
						now = os.clock()
						arg:_setStatus("Idle", fn65())
						task.wait(0.25)
						continue
					end

					local n21 = n9 - (os.clock() - now)

					if n21 > 0 then
						arg:_setStatus("Idle", string.format("Starting in %.0fs", math.ceil(n21)))
						task.wait(math.min(n21, 0.25))
						continue
					end

					local v11 = arg:_resolveStandCFrame()

					if not v11 then
						arg:_setStatus("Idle", "Position unavailable")
						task.wait(2)
						continue
					end

					arg.travelingToTreadmill = true
					arg:_setStatus("Moving", "Waiting")
					local flag5 = false
					local travel = arg.travel
					local character = localPlayer2.Character
					local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")

					if travel and (humanoidRootPart and (humanoid and (type(travel._teleportRoot) == "function" and (type(travel._isInSafeArea) == "function" and (travel:_isInSafeArea(humanoidRootPart) and (humanoidRootPart.Position - v11.Position).Magnitude < 250))))) then
						local ok, result = pcall(travel._teleportRoot, travel, humanoidRootPart, humanoid, v11)
						flag5 = ok and result == true
					end

					local travel2 = flag5 or arg.travel and arg.travel:travelAndWait(v11, {abort = function()
						return arg.destroyed or arg.busy or not arg.config.idleFarm or idleGeneration ~= arg.idleGeneration or arg.coordinator and arg.coordinator:isBackgroundBusy() or genv.__FanKunHUBIsAutoSellEggBusy and genv.__FanKunHUBIsAutoSellEggBusy() or fn63()
					end})

					arg.travelingToTreadmill = false

					if not travel2 then
						if not arg.busy and arg.config.idleFarm then
							arg:_setStatus("Idle", "Travel failed")
							task.wait(1)
						end

						continue
					end

					if arg.busy or not arg.config.idleFarm or idleGeneration ~= arg.idleGeneration or arg.coordinator and arg.coordinator:isBackgroundBusy() then
						continue
					elseif genv.__FanKunHUBIsAutoSellEggBusy then
						if genv.__FanKunHUBIsAutoSellEggBusy() then
							continue
						elseif fn63() then
							continue
						end
					elseif fn63() then
						continue
					end

					task.wait(n12)

					if arg.busy or not arg.config.idleFarm or idleGeneration ~= arg.idleGeneration or arg.coordinator and arg.coordinator:isBackgroundBusy() then
						continue
					elseif genv.__FanKunHUBIsAutoSellEggBusy then
						if genv.__FanKunHUBIsAutoSellEggBusy() then
							continue
						elseif fn63() then
							continue
						end
					elseif fn63() then
						continue
					end

					arg.treadmillEquipPending = true

					character, destroyed, travel = pcall(function()
						return Remotes.Treadmill.AskWearStill:InvokeServer()
					end)

					if if character then destroyed == false else not character then
						arg.treadmillEquipPending = false
						arg:_setStatus("Preparing carry", "Activation failed: " .. tostring(travel or destroyed))
					else
						arg.lastEquipAt = os.clock()
						arg:_setStatus("Active", "Waiting for gain")

						task.delay(2, function()
							if not arg.destroyed and arg.activeTreadmill == nil then
								arg.treadmillEquipPending = false
							end
						end)
					end

					local n22 = os.clock() + n8

					while (arg.activeTreadmill ~= nil or os.clock() < n22) and not arg.destroyed and not arg.busy and arg.config.idleFarm and idleGeneration == arg.idleGeneration and not (arg.coordinator and arg.coordinator:isBackgroundBusy()) do
						if fn64() then
							arg:_cancelIdle(true)
							arg:_setStatus("Idle", "Yielding to Auto Steal")
							break
						end

						if genv.__FanKunHUBIsAutoSellEggBusy and genv.__FanKunHUBIsAutoSellEggBusy() then
							arg:_cancelIdle(true)
							arg:_setStatus("Idle", "Yielding to Auto Sell Egg")
							break
						end

						if fn63() then
							arg:_requestUnequip()
							arg:_setStatus("Idle", fn65())
							break
						end

						task.wait(0.25)
					end
				end
			end, debug.traceback)

			if not ok then
				warn("[SAE][treadmill] idle error:\n" .. tostring(result))
			end

			if arg.idleRunning == idleGeneration then
				arg.idleRunning = nil
			end
		end)
	end

	index._onCoordinator = function(arg, arg2)
		local busy = arg.busy
		arg.busy = arg2.busy == true

		if arg.busy then
			arg:_cancelIdle(arg.config.disableDuringAutomation)
			arg:_startUnequipGuard()
			arg:_setStatus("Automation active", arg.config.disableDuringAutomation and "Blocked" or "Unchanged")
		elseif busy or arg.config.idleFarm then
			if arg.config.idleFarm then
				arg:_startIdle()
			else
				arg:_setStatus("Idle", "Disabled")
			end
		end
	end

	index._listenCoordinator = function(arg)
		if not arg.coordinator then
			return
		end

		table.insert(arg.resources, arg.coordinator:subscribe(function(arg2)
			arg:_onCoordinator(arg2)
		end))

		table.insert(arg.resources, arg.coordinator:subscribeBackground(function(arg2)
			if arg2.busy then
				arg:_cancelIdle(false)
				arg:_setStatus("Idle", "Waiting for background inventory")
			elseif not arg.destroyed then
				if not arg.busy and arg.config.idleFarm then
					arg:_startIdle()
				end
			end
		end))
	end

	index._syncActiveTreadmillSnapshot = function(arg)
		local ok, result = pcall(function()
			return Remotes.Treadmill.AskRenderSnapshot:InvokeServer()
		end)

		if ok then
			if type(result) ~= "table" then
				return arg.activeTreadmill ~= nil
			end
		else
			return arg.activeTreadmill ~= nil
		end

		local flag5 = table.find(result, localPlayer2.UserId) ~= nil
		arg.activeTreadmill = flag5 and "snapshot" or nil

		if not flag5 then
			arg.treadmillEquipPending = false
		end

		return flag5
	end

	index._listenActiveTreadmill = function(arg)
		local function fn66(activeTreadmill)
			arg.treadmillStateRevision = arg.treadmillStateRevision + 1
			arg.activeTreadmill = activeTreadmill
			arg.treadmillEquipPending = false

			if activeTreadmill ~= nil and arg:_shouldBlockTreadmill() then
				arg:_startUnequipGuard()
			elseif activeTreadmill == nil and arg:_shouldBlockTreadmill() then
				arg:_setStatus("Automation active", "Blocked")
			elseif activeTreadmill == nil then
				arg:_setStatus("Idle", arg.config.idleFarm and "Released" or "Disabled")
			elseif not arg.busy then
				arg:_setStatus("Active", "Waiting for gain")
			end
		end

		local assignedBeltShifted, renderStateShifted

		pcall(function()
			assignedBeltShifted = Remotes.Treadmill.AssignedBeltShifted
		end)

		pcall(function()
			renderStateShifted = Remotes.Treadmill.RenderStateShifted
		end)

		if assignedBeltShifted then
			table.insert(arg.resources, assignedBeltShifted.OnClientEvent:Connect(function(arg2)
				fn66(arg2)
			end))

			return
		end

		if renderStateShifted then
			table.insert(arg.resources, renderStateShifted.OnClientEvent:Connect(function(arg2, arg3)
				if arg2 ~= localPlayer2.Name then
					return
				end
				fn66(arg3 and arg2 or nil)
			end))
		end
	end

	index._listenSpeedGain = function(arg)
		local speedGained = Remotes.Treadmill.SpeedGained

		if speedGained then
			table.insert(arg.resources, speedGained.OnClientEvent:Connect(function()
				arg.activeTreadmill = arg.activeTreadmill or true
				arg.treadmillEquipPending = false
				if arg:_shouldBlockTreadmill() then
					arg:_startUnequipGuard()
					return
				end
				arg:_setStatus("Active", "Gain ticking")
			end))
		end
	end

	index.destroy = function(arg)
		if arg.destroyed then
			return
		end
		arg.destroyed = true
		arg:_cancelIdle(true)

		for i, resource in ipairs(arg.resources) do
			pcall(function()
				if typeof(resource) == "RBXScriptConnection" then
					resource:Disconnect()
				elseif type(resource) == "function" then
					resource()
				elseif type(resource) == "table" then
					if type(resource.Disconnect) == "function" then
						resource:Disconnect()
					end
				end
			end)
		end

		table.clear(arg.resources)
		table.clear(arg.listeners)
	end

	index.Destroy = index.destroy
	return index
end)()


local v12 = v5.new()
local v13 = v8.new(v6, v7, v12)
genv.__FanKunHUBEggRuntime = v13
local v14 = v11.new(v12, v13)
genv.__FanKunHUBTreadmillManager = v14

fanKunHubTaskLadder.register("treadmill", {wants = function()
	return v14.config.idleFarm == true and not v14.destroyed
end, active = function()
	local destroyed = v14.destroyed
	return if destroyed then not destroyed else v14:isEngaged() == true
end, enabled = function()
	return v14.config.idleFarm == true
end, status = function()
	local stats = v14.stats or {}
	local str3 = tostring(stats.mode or "")
	local str4 = tostring(stats.boost or "")
	if str4 ~= "" and str4 ~= "Waiting" then
		return str3 .. "  \194\183  " .. str4
	end
	return str3
end})

v13:setTreadmillManager(v14)
v14:setDisableDuringAutomation(true)


-- [task ladder registration for auto_steal]
do
	local tbl12 = {at = 0, value = false}

	genv.__FanKunHUBStealWantsCharacter = function()
		local fanKunHubPlayerSteal = genv.__FanKunHUBPlayerSteal

		if fanKunHubPlayerSteal then
			if fanKunHubPlayerSteal.running then
				return true
			elseif fanKunHubPlayerSteal.wantsTarget then
				return true
			end
		end

		local fanKunHubEggRuntime = genv.__FanKunHUBEggRuntime

		if fanKunHubEggRuntime and fanKunHubEggRuntime.enabled then
			if fanKunHubEggRuntime.destroyed then
				return false
			end
		else
			return false
		end

		local flag5 = fanKunHubEggRuntime.activeTween and not fanKunHubEggRuntime.activeTween.sharedTravel

		if fanKunHubEggRuntime.running then
			return true
		elseif flag5 then
			return true
		elseif fanKunHubEggRuntime.carry then
			if fanKunHubEggRuntime.carry.active then
				return true
			end
		end

		if type(fanKunHubEggRuntime._eggInventoryFull) == "function" and fanKunHubEggRuntime:_eggInventoryFull() then
			return false
		end
		local now = os.clock()
		if now - tbl12.at < 0.5 then
			return tbl12.value
		end
		tbl12.at = now

		local ok, result = pcall(function()
			return fanKunHubEggRuntime:_wallOpen() and fanKunHubEggRuntime:_chooseTarget() or nil
		end)

		tbl12.value = ok and result ~= nil
		return tbl12.value
	end

	register = fanKunHubTaskLadder.register
	tbl = {}
	tbl.wants = genv.__FanKunHUBStealWantsCharacter

	tbl.active = function()
		local fanKunHubPlayerSteal = genv.__FanKunHUBPlayerSteal
		if fanKunHubPlayerSteal and fanKunHubPlayerSteal.running then
			return true
		end
		local fanKunHubEggRuntime = genv.__FanKunHUBEggRuntime

		if fanKunHubEggRuntime then
			if fanKunHubEggRuntime.destroyed then
				return false
			end
		else
			return false
		end

		local flag5 = fanKunHubEggRuntime.activeTween and not fanKunHubEggRuntime.activeTween.sharedTravel
		return fanKunHubEggRuntime.running == true or flag5 == true or fanKunHubEggRuntime.carry ~= nil and fanKunHubEggRuntime.carry.active == true
	end

	tbl.enabled = function()
		local fanKunHubPlayerSteal = genv.__FanKunHUBPlayerSteal
		local fanKunHubEggRuntime = genv.__FanKunHUBEggRuntime
		return fanKunHubEggRuntime ~= nil and fanKunHubEggRuntime.enabled == true or fanKunHubPlayerSteal ~= nil and fanKunHubPlayerSteal.enabled == true
	end

	tbl.status = function()
		local fanKunHubPlayerSteal = genv.__FanKunHUBPlayerSteal
		if fanKunHubPlayerSteal and fanKunHubPlayerSteal.running then
			return tostring(fanKunHubPlayerSteal.status or "Stealing from a player")
		end
		local fanKunHubEggRuntime = genv.__FanKunHUBEggRuntime
		return fanKunHubEggRuntime and fanKunHubEggRuntime.stats and tostring(fanKunHubEggRuntime.stats.status or "") or ""
	end

	register("auto_steal", tbl)
end



----------------------------------------------------------------------
-- Wiring: Anti Guard Knockback + Aura Bat
----------------------------------------------------------------------
local v15 = v9.new(v13)
v15:install()
v15:setEnabled(fanKunHubConfig.AntiGuardKnockback == true)
genv.__FanKunHUBAntiGuard = v15

local v16 = v10.new(v13)
v16:setEnabled(true)
genv.__FanKunHUBGodMode = v16

----------------------------------------------------------------------
-- Cleanup / shutdown
----------------------------------------------------------------------
genv.__FanKunHUBEggRuntimeCleanup = function()
	pcall(v13.destroy, v13)
	pcall(v14.destroy, v14)

	if genv.__FanKunHUBEggRuntime == v13 then
		genv.__FanKunHUBEggRuntime = nil
	end

	if genv.__FanKunHUBTreadmillManager == v14 then
		genv.__FanKunHUBTreadmillManager = nil
	end
end

genv.__FanKunHUBAntiGuardCleanup = function()
	pcall(v15.destroy, v15)
	pcall(v16.destroy, v16)

	if genv.__FanKunHUBAntiGuard == v15 then
		genv.__FanKunHUBAntiGuard = nil
	end

	if genv.__FanKunHUBGodMode == v16 then
		genv.__FanKunHUBGodMode = nil
	end
end


----------------------------------------------------------------------
-- Steal API: setter yang dipanggil UI (mengikuti pengaturan Auto Steal di FanKunHub)
----------------------------------------------------------------------
local Steal = {}
Steal.engine = v13
Steal.config = fanKunHubConfig

local function cleanList(list)
	local out = {}
	for _, item in ipairs(type(list) == "table" and list or {}) do
		if item ~= "None" and item ~= "" then
			out[#out + 1] = item
		end
	end
	return out
end

Steal.cleanList = cleanList

function Steal.setEnabled(on)
	fanKunHubConfig.AutoSteal = on == true
	v13:setEnabled(fanKunHubConfig.AutoSteal)

	if type(genv.__FanKunHUBSetStealDeclutter) == "function" then
		pcall(genv.__FanKunHUBSetStealDeclutter, fanKunHubConfig.AutoSteal)
	end
end

function Steal.setHoldSeconds(value)
	fanKunHubConfig.StealHoldSeconds = math.clamp(math.floor((tonumber(value) or 5) + 0.5), 1, 10)
end

function Steal.setHelpFriend(on)
	fanKunHubConfig.HelpFriend = on == true
end

function Steal.setLowSpeedBoost(on)
	fanKunHubConfig.LowSpeedBoost = on == true
end

-- Aura Bat selalu aktif (toggle dihapus dari UI)
function Steal.setAuraBat(on)
	fanKunHubConfig.GodMode = true
	v16:setEnabled(true)
end

function Steal.setAntiGuard(on)
	fanKunHubConfig.AntiGuardKnockback = on == true
	v15:setEnabled(fanKunHubConfig.AntiGuardKnockback)
end

local MODE_INSTANT = "Instant Steal"
local MODE_RUN = "Run"

function Steal.setStealMode(label)
	local text = type(label) == "string" and label or ""
	local mode = (text == MODE_RUN or text:find("Run") == 1) and "Fly" or "Instant"

	fanKunHubConfig.StealMode = mode
	fanKunHubConfig.FlyAerial = false
	fanKunHubConfig.FlyZigzag = false

	if v13.captureObjectiveEnabled then
		v13._modeBeforeCapture = {mode, false, false}
	else
		v13:setStealMode(mode, false, false)
	end
end

function Steal.stealModeLabel()
	if fanKunHubConfig.StealMode == "Fly" then
		return MODE_RUN
	end
	return MODE_INSTANT
end

function Steal.setSpeed(value)
	local speed = math.clamp(math.floor((tonumber(value) or 60) + 0.5), 50, 100)
	fanKunHubConfig.TweenSpeedMultiplier = speed
	v13:setSpeed(speed)
end

function Steal.setRunDropCount(value)
	fanKunHubConfig.RunDropCount = math.clamp(math.floor((tonumber(value) or 0) + 0.5), 0, 10)
end

-- filter list: key engine, key enable, key config
local LIST_FILTERS = {
	names = {"name", "StealNamesFilter"},
	rarities = {"rarity", "StealRarities"},
	areas = {"area", "StealAreas"},
	mutations = {"mutation", "StealMutations"},
}

function Steal.setListFilter(kind, selected)
	local info = LIST_FILTERS[kind]
	if not info then
		return
	end
	local list = cleanList(selected)
	fanKunHubConfig[info[2]] = list
	v13:setFilter(kind, list)
	v13:setFilterEnabled(info[1], #list > 0)
end

function Steal.setMinValue(text)
	fanKunHubConfig:applyStealValueInput(text)
	v13:setMinValuePerSec(fanKunHubConfig.StealMinValue or 0)
end

function Steal.setMinWeight(text)
	local weight = tonumber((tostring(text or ""):gsub("[^%d%.]", ""))) or 0
	fanKunHubConfig.StealMinWeight = weight
	v13:setMinWeightKg(weight)
end

function Steal.setPriority(label)
	fanKunHubConfig.StealPriority = tostring(label or "Rarity")
	v13:setHighestValueFirst(fanKunHubConfig.StealPriority == "Highest Value")
	v13:setHeaviestFirst(fanKunHubConfig.StealPriority == "Heaviest")
end

function Steal.setAutoIndex(on)
	fanKunHubConfig.AutoIndex = on == true
	v13:setIndexObjective(fanKunHubConfig.AutoIndex)
end

function Steal.clearFilters()
	for kind in pairs(LIST_FILTERS) do
		Steal.setListFilter(kind, {})
	end
	Steal.setMinValue("")
	Steal.setMinWeight("")
	Steal.setPriority("Rarity")
end

-- dorong seluruh config ke engine (dipanggil sekali setelah config dimuat)
function Steal.applyAll()
	Steal.setStealMode(Steal.stealModeLabel())
	Steal.setSpeed(fanKunHubConfig.TweenSpeedMultiplier)
	Steal.setRunDropCount(fanKunHubConfig.RunDropCount)
	Steal.setHoldSeconds(fanKunHubConfig.StealHoldSeconds)
	Steal.setAuraBat(fanKunHubConfig.GodMode)
	Steal.setAntiGuard(fanKunHubConfig.AntiGuardKnockback)
	for kind in pairs(LIST_FILTERS) do
		Steal.setListFilter(kind, fanKunHubConfig[LIST_FILTERS[kind][2]])
	end
	v13:setMinValuePerSec(fanKunHubConfig.StealMinValue or 0)
	v13:setMinWeightKg(fanKunHubConfig.StealMinWeight or 0)
	Steal.setPriority(fanKunHubConfig.StealPriority)
	v13:setIndexObjective(fanKunHubConfig.AutoIndex == true)
end

local Options = {}

function Options.rarities()
	local list = {}
	pcall(function()
		for _, rarity in ipairs(v6.getRarities()) do
			list[#list + 1] = rarity
		end
	end)
	if #list == 0 then
		list = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Eternal", "Divine"}
	end
	return list
end

function Options.mutations()
	local list = {}
	pcall(function()
		for _, mutation in ipairs(v6.getMutations()) do
			list[#list + 1] = mutation
		end
	end)
	if #list == 0 then
		list = {"Golden", "Rainbow", "Shocked", "Frozen", "Burnt", "Boss"}
	end
	return list
end

function Options.eggNames()
	local names, seen = {}, {}
	pcall(function()
		local areas = require(ReplicatedStorage.Data.Areas).Directory
		local assets = require(ReplicatedStorage.Data.Assets).Directory
		for _, area in pairs(areas) do
			if type(area) == "table" and type(area.DropTable) == "table" then
				for _, row in ipairs(area.DropTable) do
					local id = row[1]
					if type(id) == "string" and not seen[id] then
						seen[id] = true
						local asset = assets[id]
						names[#names + 1] = asset and asset.DisplayName or id
					end
				end
			end
		end
	end)
	table.sort(names)
	return names
end

function Options.areas()
	local preferred = {"Lake", "Jungle", "Desert", "Snow", "Volcano", "Abyss Ocean", "Prehistoric", "Cosmic", "Cherry Blossom", "Titan Temple"}
	local exists = {}

	local ok = pcall(function()
		for key, area in pairs(require(ReplicatedStorage.Data.Areas).Directory) do
			if type(area) == "table" and type(area.DropTable) == "table" then
				exists[key] = true
			end
		end
	end)

	if not ok or next(exists) == nil then
		for _, area in ipairs(preferred) do
			exists[area] = true
		end
	end

	local handled = {Forest = true, ["Titan Temple"] = true}
	local list = {}

	for _, area in ipairs(preferred) do
		if area ~= "Titan Temple" and exists[area] then
			list[#list + 1] = area
			handled[area] = true
		end
	end

	local extra = {}
	for area in pairs(exists) do
		if not handled[area] then
			extra[#extra + 1] = area
		end
	end
	table.sort(extra)
	for _, area in ipairs(extra) do
		list[#list + 1] = area
	end

	if exists["Titan Temple"] then
		list[#list + 1] = "Titan Temple"
	end
	return list
end

----------------------------------------------------------------------
-- Config save / load
----------------------------------------------------------------------
local CONFIG_DIR = "FanKunHUB"
local CONFIG_FILE = CONFIG_DIR .. "/config.json"
local PERSIST_KEYS = {
	"HelpFriend", "LowSpeedBoost", "StealMode", "FlyAerial", "FlyZigzag", "StealHoldSeconds",
	"StealAreas", "StealRarities", "StealNamesFilter", "StealMinValue", "StealMutations",
	"StealMinWeight", "StealPriority", "AutoIndex", "AntiAfkTreadmill", "AntiAfkJump", "GodMode", "AntiGuardKnockback", "TweenSpeedMultiplier", "RunDropCount", "Language",
	"TaskOrder", "TaskOrderPicked", "TaskNumbers",
}

local Storage = {}

function Storage.available()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

function Storage.save()
	if not Storage.available() then
		return false
	end
	local data = {}
	for _, key in ipairs(PERSIST_KEYS) do
		data[key] = fanKunHubConfig[key]
	end
	local ok = pcall(function()
		if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(CONFIG_DIR) then
			makefolder(CONFIG_DIR)
		end
		writefile(CONFIG_FILE, HttpService:JSONEncode(data))
	end)
	return ok
end

function Storage.load()
	if not Storage.available() then
		return false
	end
	local ok, data = pcall(function()
		if not isfile(CONFIG_FILE) then
			return nil
		end
		return HttpService:JSONDecode(readfile(CONFIG_FILE))
	end)
	if not ok or type(data) ~= "table" then
		return false
	end
	for _, key in ipairs(PERSIST_KEYS) do
		local value = data[key]
		if value ~= nil and type(value) == type(fanKunHubConfig[key]) then
			fanKunHubConfig[key] = value
		end
	end
	return true
end

function Storage.reset()
	if Storage.available() and type(delfile) == "function" then
		pcall(function()
			if isfile(CONFIG_FILE) then
				delfile(CONFIG_FILE)
			end
		end)
	end
end



----------------------------------------------------------------------
-- UI Library (minimalis, lebar ke samping, ikon Lucide ala WindUI)
----------------------------------------------------------------------
local UI = {}

UI.lang = "Indonesia"
UI.binds = {}
UI.refreshers = {}
UI.dict = {
	["Run"] = "Run",
	["Instant Steal"] = "Instant Steal",
	["Speed Advice"] = "Saran Kecepatan",
	["Reading your speed..."] = "Membaca kecepatan...",
	["Instant Steal Multiplier"] = "Pengali Instant Steal",
	["For Instant Steal mode. Higher = faster grab, lower = safer."] = "Untuk mode Instant Steal. Makin tinggi = lebih cepat, makin rendah = lebih aman.",
	["Boost For Instant Steal"] = "Boost Instant Steal",
	["Faster Instant Steal on every area except Forest."] = "Instant Steal lebih cepat di semua area kecuali Forest.",
	["Aura Bat"] = "Aura Bat",
	["Hits guards around you while stealing."] = "Memukul guard di sekitar saat steal.",
	["Steals keep failing"] = "Steal terus gagal",
	["Low Speed User"] = "Low Speed User",
	["Auto Steal"] = "Auto Steal",
	["Egg Filter"] = "Filter Telur",
	["Steal"] = "Steal",
	["Filter"] = "Filter",
	["Settings"] = "Setelan",
	["Anti AFK"] = "Anti AFK",
	["Auto Treadmill"] = "Treadmill Otomatis",
	["Climb the treadmill automatically; jump off when another task runs."] = "Naik treadmill otomatis; turun otomatis saat fitur/task lain berjalan.",
	["Auto Jump (20s)"] = "Lompat Otomatis (20 detik)",
	["Jump once every 20 seconds."] = "Lompat sekali setiap 20 detik.",
	["Options"] = "Opsi",
	["Egg"] = "Telur",
	["Value & Priority"] = "Nilai & Prioritas",
	["Reset"] = "Reset",
	["Order"] = "Urutan",
	["Task Order"] = "Urutan Tugas",
	["How it works"] = "Cara Kerja",
	["Top runs first"] = "Paling atas jalan duluan",
	["A task lower in the list waits while a higher one is working. Use Up / Down to change the order."] = "Tugas yang lebih bawah menunggu selama tugas di atasnya bekerja. Pakai Naik / Turun untuk mengubah urutan.",
	["Up"] = "Naik",
	["Down"] = "Turun",
	["Pin"] = "Kunci",
	["Highest priority"] = "Prioritas tertinggi",
	["Always last (pinned)"] = "Selalu terakhir (dikunci)",
	["Reset Order"] = "Reset Urutan",
	["Back to the default order."] = "Kembali ke urutan bawaan.",
	["Task order reset"] = "Urutan tugas direset",
	["Tick to set priority"] = "Centang untuk atur prioritas",
	["Tick the features in the order you want. The first one you tick runs first, the next one waits for it. Untick to remove it. Features you do not tick run last."] = "Centang fitur sesuai urutan yang kamu mau. Yang pertama dicentang jalan duluan, berikutnya menunggu. Hilangkan centang untuk mengeluarkan. Fitur yang tidak dicentang jalan paling akhir.",
	["Waits for the ones above"] = "Menunggu yang di atasnya",
	["Not ticked (runs last)"] = "Belum dicentang (jalan paling akhir)",
	["Type a number to set the order"] = "Ketik angka untuk atur urutan",
	["1 runs first, 2 next, and so on. Leave a box empty to use the default order (it goes after the numbered ones). Status: [RUN] working, [WAIT] waiting for a higher one, [IDLE] on but nothing to do, [OFF] switched off."] = "1 jalan duluan, 2 berikutnya, dst. Kosongkan kotak untuk pakai urutan bawaan (jalan setelah yang bernomor). Status: [RUN] sedang jalan, [WAIT] menunggu yang lebih atas, [IDLE] nyala tapi belum ada yang dikerjakan, [OFF] mati.",
	["Feature Order"] = "Urutan Fitur",
	["Movement"] = "Gerakan",
	["Config"] = "Konfigurasi",
	["Language"] = "Bahasa",
	["Interface language."] = "Bahasa antarmuka.",
	["RightShift  \226\128\148  hide"] = "RightShift  \226\128\148  sembunyikan",
	["Steal matching eggs and bank them."] = "Curi telur yang cocok lalu simpan ke base.",
	["Steal Mode"] = "Mode Steal",
	["Instant: needs stable ping & FPS. Run: walk to the egg."] = "Instant: harus ms & FPS stabil. Run: lari ke target.",
	["Instant Multiplier"] = "Pengali Instant",
	["Higher = faster grab, lower = safer."] = "Makin tinggi = lebih cepat, makin rendah = lebih aman.",
	["Instant Boost"] = "Instant Boost",
	["Faster Instant Steal, every area but Forest."] = "Instant Steal lebih cepat, semua area kecuali Forest.",
	["Help Friend"] = "Bantu Teman",
	["Drop the egg at the safe line for a friend."] = "Jatuhkan telur di garis aman untuk teman.",
	["Egg Name"] = "Nama Telur",
	["Empty = any egg."] = "Kosong = semua telur.",
	["Rarity"] = "Rarity",
	["Empty = any rarity."] = "Kosong = semua rarity.",
	["Mutation"] = "Mutasi",
	["Empty = any mutation."] = "Kosong = semua mutasi.",
	["Area"] = "Area",
	["Empty = every area."] = "Kosong = semua area.",
	["Min Value"] = "Nilai Minimum",
	["Money per second (k, m, b)."] = "Uang per detik (k, m, b).",
	["Min Weight"] = "Berat Minimum",
	["Kilograms. 0 = any weight."] = "Kilogram. 0 = semua berat.",
	["Priority"] = "Prioritas",
	["Which egg first."] = "Telur mana yang diambil duluan.",
	["Auto Index"] = "Auto Index",
	["Also take pets missing from your Index."] = "Ambil juga pet yang belum ada di Index.",
	["Clear Filters"] = "Hapus Filter",
	["Steal any available egg."] = "Curi telur apa saja yang tersedia.",
	["Clear"] = "Hapus",
	["Move Speed"] = "Kecepatan Gerak",
	["Decoy Height"] = "Ketinggian Visual",
	["Height of the floating visual character while carrying (0 = on the ground)."] = "Ketinggian karakter visual yang melayang saat carry (0 = di tanah).",
	["Lower it if steals start failing."] = "Turunkan jika steal mulai gagal.",
	["Save Config"] = "Simpan Konfigurasi",
	["Save"] = "Simpan",
	["Also saved automatically."] = "Juga tersimpan otomatis.",
	["No file access: resets every run."] = "Tanpa akses file: reset tiap dijalankan.",
	["Unload"] = "Tutup Script",
	["Stop Auto Steal and remove the UI."] = "Hentikan Auto Steal dan hapus UI.",
	["Any"] = "Semua",
	["Select..."] = "Pilih...",
	["Search..."] = "Cari...",
	["Enabled"] = "Aktif",
	["Disabled"] = "Nonaktif",
	["All filters cleared"] = "Semua filter dibersihkan",
	["Saved"] = "Tersimpan",
	["Save failed (no file access)"] = "Gagal menyimpan (tanpa akses file)",
	["Config loaded"] = "Konfigurasi dimuat",
	["Steal Panel"] = "Panel Steal",
	["Show a floating panel with every egg. Tap a pet name to steal it."] = "Munculkan panel melayang berisi semua egg. Klik nama pet untuk mencurinya.",
	["Tap a pet to steal it"] = "Klik pet untuk mencurinya",
	["Eggs"] = "Egg",
	["Stop Steal"] = "Hentikan Steal",
	["Stealing"] = "Mencuri",
	["Dropped"] = "Jatuh",
		["No eggs available right now."] = "Belum ada egg yang tersedia.",
	["Ready"] = "Siap",
}

function UI.tr(text)
	if UI.lang == "Indonesia" and type(text) == "string" then
		return UI.dict[text] or text
	end
	return text
end

function UI.bind(inst, prop, orig, upper)
	local entry = {inst = inst, prop = prop, orig = orig, upper = upper}
	table.insert(UI.binds, entry)
	local text = UI.tr(orig)
	pcall(function()
		inst[prop] = upper and string.upper(text) or text
	end)
	return inst
end

function UI.setLanguage(lang)
	UI.lang = lang == "English" and "English" or "Indonesia"
	for _, entry in ipairs(UI.binds) do
		pcall(function()
			if entry.inst and entry.inst.Parent then
				local text = UI.tr(entry.orig)
				entry.inst[entry.prop] = entry.upper and string.upper(text) or text
			end
		end)
	end
	for _, refresh in ipairs(UI.refreshers) do
		pcall(refresh)
	end
end

local THEME = {
	bg = Color3.fromRGB(8, 8, 8),
	panel = Color3.fromRGB(14, 14, 14),
	side = Color3.fromRGB(11, 11, 11),
	elem = Color3.fromRGB(20, 20, 20),
	elemHover = Color3.fromRGB(30, 30, 30),
	stroke = Color3.fromRGB(44, 44, 44),
	text = Color3.fromRGB(245, 245, 245),
	sub = Color3.fromRGB(140, 140, 140),
	accent = Color3.fromRGB(255, 255, 255),
	accent2 = Color3.fromRGB(200, 200, 200),
	good = Color3.fromRGB(110, 205, 150),
	bad = Color3.fromRGB(232, 98, 98),
	off = Color3.fromRGB(52, 52, 52),
	onAccent = Color3.fromRGB(10, 10, 10),
}

local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold
local FONT_REG = Enum.Font.Gotham

local function make(class, props, children)
	local inst = Instance.new(class)
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(inst, radius)
	return make("UICorner", {CornerRadius = UDim.new(0, radius or 8), Parent = inst})
end

local function stroke(inst, color, thickness)
	return make("UIStroke", {
		Color = color or THEME.stroke,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
end

local function tween(inst, props, duration)
	local ok, result = pcall(function()
		return TweenService:Create(inst, TweenInfo.new(duration or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	end)
	if ok and result then
		result:Play()
	end
end

local function pickParent()
	local ok, container = pcall(function()
		return gethui and gethui()
	end)
	if ok and container then
		return container
	end
	local okCore, coreGui = pcall(function()
		return game:GetService("CoreGui")
	end)
	if okCore and coreGui then
		return coreGui
	end
	return localPlayer:WaitForChild("PlayerGui")
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

----------------------------------------------------------------------
-- Icons: Lucide lewat modul ikon yang sama dengan WindUI (Footagesus/Icons).
-- Dimuat di background; kalau gagal (tanpa HttpGet) otomatis pakai glyph cadangan.
----------------------------------------------------------------------
local ICON_URL = "https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua"

local GLYPH = {
	signal = "l", monitor = "#", languages = "A", zap = "F", filter = "Y", settings = "S", gem = "*",
	egg = "O", weight = "kg", coins = "$", x = "X",
	hand = "H", flag = "F", ghost = "G", skull = "X", fish = "~", star = "*", ["train-front"] = "T",
	minus = "-", ["chevron-down"] = "v", shield = "+", target = "o",
	activity = "~", sword = "/", users = "U", gauge = ">",
	save = "S", power = "P", ["trash-2"] = "X", sparkles = "*",
	["flask-conical"] = "M", ["arrow-up-down"] = "=", ["map-pin"] = "o",
	crown = "^", ["layout-dashboard"] = "#", ["rotate-ccw"] = "R", ["list-ordered"] = "=",
}

-- nama alternatif di Lucide (versi baru mengganti beberapa nama)
local ICON_ALIAS = {
	filter = {"filter", "funnel", "list-filter", "sliders-horizontal"},
	["list-ordered"] = {"list-ordered", "list", "list-checks", "align-justify"},
	["layout-dashboard"] = {"layout-dashboard", "layout-grid", "layout"},
	["flask-conical"] = {"flask-conical", "flask-round", "flask"},
	["trash-2"] = {"trash-2", "trash"},
	["rotate-ccw"] = {"rotate-ccw", "undo-2", "refresh-ccw"},
	egg = {"egg", "circle"},
	weight = {"weight", "scale", "dumbbell"},
	gauge = {"gauge", "activity"},
	signal = {"signal", "wifi", "antenna"},
	monitor = {"monitor", "gauge", "activity"},
	hand = {"hand", "hand-grab", "grab", "pointer"},
	flag = {"flag", "flag-triangle-right", "timer"},
	ghost = {"ghost", "skull"},
	skull = {"skull", "ghost", "swords"},
	fish = {"fish", "waves"},
	star = {"star", "sparkle"},
	["train-front"] = {"train-front", "train", "tram-front", "bus"},
}

local Icons = {registry = {}, lib = nil, state = "loading"}

local function lookupIconRaw(name)
	local ok, result = pcall(function()
		return Icons.lib.Icon(name)
	end)
	if not ok or result == nil then
		return nil
	end
	if type(result) == "string" then
		return {image = result}
	end
	if type(result) == "number" then
		return {image = "rbxassetid://" .. tostring(result)}
	end
	if type(result) ~= "table" then
		return nil
	end
	local image, data = result[1], result[2]
	if type(image) == "number" then
		image = "rbxassetid://" .. tostring(image)
	end
	if type(image) ~= "string" or image == "" then
		return nil
	end
	local info = {image = image}
	if type(data) == "table" then
		info.size = data.ImageRectSize
		info.pos = data.ImageRectPosition
	end
	return info
end

local function lookupIcon(name)
	for _, candidate in ipairs(ICON_ALIAS[name] or {name}) do
		local info = lookupIconRaw(candidate)
		if info then
			return info
		end
	end
	return nil
end

local function resolveIcon(obj)
	if obj.raw then
		-- ikon gambar (rbxassetid://...), tidak perlu pustaka ikon
		obj.img.Image = obj.name
		obj.img.ImageColor3 = Color3.new(1, 1, 1)
		obj.img.Visible = true
		obj.glyph.Visible = false
		return
	end
	if Icons.state == "loading" then
		return
	end
	local info = Icons.state == "ready" and lookupIcon(obj.name) or nil
	if info then
		obj.img.Image = info.image
		if typeof(info.size) == "Vector2" then
			obj.img.ImageRectSize = info.size
		end
		if typeof(info.pos) == "Vector2" then
			obj.img.ImageRectOffset = info.pos
		end
		obj.img.Visible = true
		obj.glyph.Visible = false
	else
		obj.img.Visible = false
		obj.glyph.Visible = true
	end
end

function Icons.new(name, size, color, parent)
	local holder = make("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local img = make("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ImageColor3 = color,
		Visible = false,
		Parent = holder,
	})
	local glyph = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = FONT_BOLD,
		Text = GLYPH[name] or "\226\128\162",
		TextColor3 = color,
		TextSize = math.max(size - 4, 8),
		Visible = false,
		Parent = holder,
	})
	local obj = {holder = holder, img = img, glyph = glyph, name = name, raw = type(name) == "string" and name:sub(1, 13) == "rbxassetid://"}

	function obj:SetColor(newColor, animate)
		if obj.raw then
			return
		end
		if animate then
			tween(img, {ImageColor3 = newColor}, 0.12)
			tween(glyph, {TextColor3 = newColor}, 0.12)
		else
			img.ImageColor3 = newColor
			glyph.TextColor3 = newColor
		end
	end

	table.insert(Icons.registry, obj)
	resolveIcon(obj)
	return obj
end

task.spawn(function()
	local ok = pcall(function()
		local lib = loadstring(game:HttpGet(ICON_URL))()
		if type(lib) == "table" and type(lib.Icon) == "function" then
			if type(lib.SetIconsType) == "function" then
				lib.SetIconsType("lucide")
			end
			Icons.lib = lib
		end
	end)
	Icons.state = (ok and Icons.lib ~= nil) and "ready" or "failed"
	for _, obj in ipairs(Icons.registry) do
		if obj.holder and obj.holder.Parent then
			resolveIcon(obj)
		end
	end
end)

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------
-- Logo: isi UI.logoAssetId dengan "rbxassetid://ID_GAMBAR_TELUR" untuk ikon kustom.
-- Jika kosong, dipakai ikon telur Lucide (juga berbasis rbxassetid lewat modul ikon).
UI.logoAssetId = "rbxassetid://96012031195817"

-- Suara UI (bisa diganti ID-nya / dimatikan: UI.soundEnabled = false)
UI.soundEnabled = true
UI.soundHolder = nil
UI.sounds = {
	click  = {id = "rbxassetid://6895079853", speed = 1.0, vol = 0.45},
	tab    = {id = "rbxassetid://6895079853", speed = 1.2, vol = 0.4},
	on     = {id = "rbxassetid://6895079853", speed = 1.45, vol = 0.5},
	off    = {id = "rbxassetid://6895079853", speed = 0.8, vol = 0.5},
	open   = {id = "rbxassetid://6895079853", speed = 1.1, vol = 0.4},
	notify = {id = "rbxassetid://6895079853", speed = 1.3, vol = 0.4},
}

function UI.playSound(kind)
	if not UI.soundEnabled or not UI.soundHolder then
		return
	end
	local info = UI.sounds[kind] or UI.sounds.click
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = info.id
		sound.Volume = info.vol or 0.45
		sound.PlaybackSpeed = info.speed or 1
		sound.Parent = UI.soundHolder
		sound:Play()
		game:GetService("Debris"):AddItem(sound, 2)
	end)
end

function UI.logo(size, color, parent, bare)
	local id = UI.logoAssetId
	if type(id) == "string" and id ~= "" then
		local holder = make("Frame", {
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = THEME.elem,
			BackgroundTransparency = bare and 1 or 0,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Parent = parent,
		})
		make("UICorner", {CornerRadius = UDim.new(0.5, 0), Parent = holder})
		local logoImage = make("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = id,
			ScaleType = Enum.ScaleType.Crop,
			Parent = holder,
		})
		make("UICorner", {CornerRadius = UDim.new(0.5, 0), Parent = logoImage})
		return {holder = holder, SetColor = function() end}
	end
	return Icons.new("egg", size, color, parent)
end

-- Ukuran logis window lebih besar, lalu seluruh UI (tab + isi fitur) diperkecil dengan UI_SCALE
-- supaya semua tampil kecil & muat (kartu ikon Butterfly tidak terpotong). Di layar ~445x265.
local BASE_W, BASE_H = 570, 340
local SIDE_W = 118
local UI_SCALE = 0.78

function UI.new(opts)
	local window = {tabs = {}, connections = {}, scale = 1}

	local gui = make("ScreenGui", {
		Name = "FanKunHUBUI_" .. tostring(math.random(1000, 9999)),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
	})
	if syn and syn.protect_gui then
		pcall(syn.protect_gui, gui)
	end
	gui.Parent = pickParent()
	window.gui = gui
	UI.soundHolder = gui

	local main = make("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(BASE_W, BASE_H),
		BackgroundColor3 = THEME.bg,
		BorderSizePixel = 0,
		Active = true,
		ClipsDescendants = true,
		Parent = gui,
	})
	corner(main, 14)
	stroke(main, THEME.stroke, 1)
	local uiScale = make("UIScale", {Parent = main})
	window.main = main

	local function fitScale()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local view = camera.ViewportSize
		local scale = math.min(UI_SCALE, (view.X - 24) / BASE_W, (view.Y - 24) / BASE_H)
		window.scale = math.max(scale, 0.45)
		uiScale.Scale = window.scale
	end
	fitScale()
	if Workspace.CurrentCamera then
		table.insert(window.connections, Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale))
	end

	---------------------------------------------------------------- top bar
	local top = make("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Active = true,
		Parent = main,
	})
	make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = THEME.stroke,
		BorderSizePixel = 0,
		Parent = top,
	})
	local logo = Icons.new("egg", 20, THEME.accent, top)
	logo.holder.Position = UDim2.fromOffset(12, 10)
	make("TextLabel", {
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -110, 1, 0),
		BackgroundTransparency = 1,
		Font = FONT_BOLD,
		Text = opts.Title or "",
		TextColor3 = THEME.text,
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = top,
	})

	-- FPS & ms real-time: selalu tampil di tengah atas layar (tidak ikut tersembunyi)
	local statsPill = make("Frame", {
		Name = "StatsPill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.2, 0),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = THEME.bg,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ZIndex = 50,
		Parent = gui,
	})
	corner(statsPill, 13)
	stroke(statsPill, THEME.stroke, 1)
	make("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10), Parent = statsPill})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = statsPill,
	})
	local pillLogo = UI.logo(18, THEME.accent, statsPill)
	pillLogo.holder.LayoutOrder = 1
	pillLogo.holder.ZIndex = 51

	local function pillLabel(order, width)
		return make("TextLabel", {
			Size = UDim2.fromOffset(width, 26),
			BackgroundTransparency = 1,
			Font = FONT_BOLD,
			Text = "--",
			TextColor3 = THEME.text,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
			ZIndex = 51,
			Parent = statsPill,
		})
	end
	local fpsIcon = Icons.new("monitor", 13, THEME.sub, statsPill)
	fpsIcon.holder.LayoutOrder = 2
	fpsIcon.holder.ZIndex = 51
	local fpsLabel = pillLabel(3, 54)
	make("Frame", {
		Size = UDim2.fromOffset(1, 12),
		BackgroundColor3 = THEME.stroke,
		BorderSizePixel = 0,
		LayoutOrder = 4,
		ZIndex = 51,
		Parent = statsPill,
	})
	local msIcon = Icons.new("signal", 13, THEME.sub, statsPill)
	msIcon.holder.LayoutOrder = 5
	msIcon.holder.ZIndex = 51
	local msLabel = pillLabel(6, 48)

	-- Activity pill: ramping, slim, tepat di bawah FPS/ms.
	local activityPill = make("Frame", {
		Name = "ActivityPill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.2, 30),
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = THEME.bg,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ZIndex = 50,
		Parent = gui,
	})
	corner(activityPill, 12)
	stroke(activityPill, THEME.stroke, 1)
	make("UIPadding", {PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 9), Parent = activityPill})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = activityPill,
	})
	local activityIcon = Icons.new("activity", 12, THEME.accent, activityPill)
	activityIcon.holder.LayoutOrder = 1
	activityIcon.holder.ZIndex = 51
	local activityLabel = make("TextLabel", {
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = FONT_BOLD,
		Text = "Idle",
		TextColor3 = THEME.sub,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 2,
		ZIndex = 51,
		Parent = activityPill,
	})
	window.activityPill = activityPill
	window.activityLabel = activityLabel
	window.activityIcon = activityIcon
	function window:SetActivity(status, active)
		local text = tostring(status or "")
		if text == "" then text = "Idle" end
		if #text > 64 then text = text:sub(1, 61) .. "..." end
		activityLabel.Text = text
		activityLabel.TextColor3 = active == false and THEME.sub or THEME.text
		activityIcon:SetColor(active == false and THEME.sub or THEME.accent, true)
	end

	-- ===== Log Aktivitas: merekam kejadian nyata (kupu-kupu, Halloween, monster, steal, dst) =====
	-- Pill di atas = aktivitas terakhir. Klik pill untuk membuka/menutup daftar log lengkap.
	do
		local MAX_LOG = 100
		local CATS = {
			butterfly = {"Kupu-kupu", Color3.fromRGB(110, 190, 255)},
			halloween = {"Halloween", Color3.fromRGB(255, 160, 70)},
			monster = {"Monster", Color3.fromRGB(255, 105, 95)},
			candy = {"Candy", Color3.fromRGB(255, 205, 90)},
			steal = {"Steal", Color3.fromRGB(140, 225, 130)},
			star = {"Bintang", Color3.fromRGB(255, 235, 130)},
			train = {"Phantom", Color3.fromRGB(190, 150, 255)},
			fishing = {"Fishing", Color3.fromRGB(100, 220, 220)},
			dog = {"Ghost Dog", Color3.fromRGB(200, 200, 215)},
			task = {"Aktivitas", Color3.fromRGB(180, 180, 180)},
		}
		local totals = {butterfly = 0, halloween = 0, monster = 0, candy = 0, steal = 0, star = 0}
		local function hex(c)
			return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
		end
		local function esc(s)
			return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
		end

		local panel = make("Frame", {
			Name = "ActivityLogPanel",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.2, 58),
			Size = UDim2.fromOffset(310, 176),
			BackgroundColor3 = THEME.bg,
			BackgroundTransparency = 0.04,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 60,
			Parent = gui,
		})
		corner(panel, 10)
		stroke(panel, THEME.stroke, 1)
		make("TextLabel", {
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -100, 0, 18),
			BackgroundTransparency = 1,
			Font = FONT_BOLD,
			Text = "Log Aktivitas",
			TextColor3 = THEME.text,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 61,
			Parent = panel,
		})
		local summary = make("TextLabel", {
			Position = UDim2.fromOffset(10, 22),
			Size = UDim2.new(1, -20, 0, 14),
			BackgroundTransparency = 1,
			Font = FONT_REG,
			Text = "",
			TextColor3 = THEME.sub,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 61,
			Parent = panel,
		})
		local clearButton = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -34, 0, 5),
			Size = UDim2.fromOffset(52, 18),
			BackgroundColor3 = THEME.elem,
			AutoButtonColor = false,
			Font = FONT_BOLD,
			Text = "Hapus",
			TextColor3 = THEME.sub,
			TextSize = 9,
			ZIndex = 61,
			Parent = panel,
		})
		corner(clearButton, 6)
		local closeButton = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 5),
			Size = UDim2.fromOffset(22, 18),
			BackgroundColor3 = THEME.elem,
			AutoButtonColor = false,
			Font = FONT_BOLD,
			Text = "X",
			TextColor3 = THEME.sub,
			TextSize = 10,
			ZIndex = 61,
			Parent = panel,
		})
		corner(closeButton, 6)
		closeButton.MouseButton1Click:Connect(function()
			panel.Visible = false
		end)
		local list = make("ScrollingFrame", {
			Position = UDim2.fromOffset(6, 40),
			Size = UDim2.new(1, -12, 1, -46),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ZIndex = 61,
			Parent = panel,
		})
		make("UIListLayout", {
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = list,
		})

		local rows, seq, latest, seen = {}, 0, nil, {}
		local function refreshSummary()
			summary.Text = string.format(
				"Kupu-kupu %d  |  Egg HW %d  |  Monster %d  |  Candy +%d  |  Steal %d",
				totals.butterfly, totals.halloween, totals.monster, totals.candy, totals.steal
			)
		end
		refreshSummary()

		-- cat: butterfly | halloween | monster | candy | steal | star
		-- amount: angka yang dijumlahkan ke ringkasan (0 = hanya dicatat). throttle: detik, anti-spam teks sama.
		function window:AddActivityLog(cat, text, amount, throttle)
			text = tostring(text or "")
			if text == "" then return end
			local now = os.clock()
			if throttle and seen[text] and now - seen[text] < throttle then return end
			seen[text] = now
			local meta = CATS[cat] or {"Info", THEME.sub}
			if totals[cat] ~= nil then
				totals[cat] = totals[cat] + (tonumber(amount) or 0)
			end
			seq = seq + 1
			latest = {text = "[" .. meta[1] .. "] " .. text, at = now}
			local row = make("TextLabel", {
				Size = UDim2.new(1, -6, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Font = FONT_REG,
				RichText = true,
				TextSize = 10,
				TextWrapped = true,
				TextColor3 = THEME.text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Text = string.format('<font color="#8A8F98">%s</font> <font color="%s"><b>%s</b></font> %s', os.date("%H:%M:%S"), hex(meta[2]), meta[1], esc(text)),
				LayoutOrder = -seq,
				ZIndex = 62,
				Parent = list,
			})
			rows[#rows + 1] = row
			if #rows > MAX_LOG then
				local old = table.remove(rows, 1)
				if old then old:Destroy() end
			end
			refreshSummary()
		end

		function window:GetLatestActivity()
			if latest then
				return latest.text, os.clock() - latest.at
			end
			return nil, 0
		end

		clearButton.MouseButton1Click:Connect(function()
			for _, row in ipairs(rows) do row:Destroy() end
			rows, latest, seen = {}, nil, {}
			for key in pairs(totals) do totals[key] = 0 end
			refreshSummary()
		end)

		activityPill.Active = true
		activityPill.InputBegan:Connect(function(input)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
				panel.Visible = not panel.Visible
				if panel.Visible then refreshSummary() end
			end
		end)
	end

	do
		-- satu koneksi ringan: hanya hitung frame, teks/warna diubah hanya kalau nilainya berubah
		local frames, elapsed = 0, 0
		local lastFps, lastMs, fpsBucket, msBucket = -1, -1, nil, nil
		local pingItem
		pcall(function()
			pingItem = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]
		end)
		table.insert(window.connections, RunService.Heartbeat:Connect(function(dt)
			frames = frames + 1
			elapsed = elapsed + dt
			if elapsed < 0.5 then
				return
			end
			local fps = math.floor(frames / elapsed + 0.5)
			frames, elapsed = 0, 0

			local ms = 0
			if pingItem then
				local ok, value = pcall(pingItem.GetValue, pingItem)
				if ok then
					ms = math.floor((tonumber(value) or 0) + 0.5)
				end
			end

			if fps ~= lastFps then
				lastFps = fps
				fpsLabel.Text = fps .. " FPS"
				local bucket = fps >= 50 and 1 or (fps >= 30 and 2 or 3)
				if bucket ~= fpsBucket then
					fpsBucket = bucket
					local color = bucket == 1 and THEME.good or (bucket == 2 and THEME.text or THEME.bad)
					fpsLabel.TextColor3 = color
					fpsIcon:SetColor(color)
				end
			end
			if ms ~= lastMs then
				lastMs = ms
				msLabel.Text = ms .. " ms"
				local bucket = ms < 100 and 1 or (ms < 200 and 2 or 3)
				if bucket ~= msBucket then
					msBucket = bucket
					local color = bucket == 1 and THEME.good or (bucket == 2 and THEME.text or THEME.bad)
					msLabel.TextColor3 = color
					msIcon:SetColor(color)
				end
			end
		end))
	end

	local function topButton(iconName, offset, hoverColor)
		local button = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, offset, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = THEME.elem,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			Parent = top,
		})
		corner(button, 7)
		local icon = Icons.new(iconName, 14, THEME.sub, button)
		icon.holder.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.holder.Position = UDim2.fromScale(0.5, 0.5)
		button.MouseEnter:Connect(function()
			tween(button, {BackgroundTransparency = 0}, 0.1)
			icon:SetColor(hoverColor or THEME.text, true)
		end)
		button.MouseLeave:Connect(function()
			tween(button, {BackgroundTransparency = 1}, 0.1)
			icon:SetColor(THEME.sub, true)
		end)
		return button
	end

	local closeButton = topButton("x", -10, THEME.bad)
	local hideButton = topButton("minus", -42)

	do
		local dragging, dragStart, startPos
		top.InputBegan:Connect(function(input)
			if isPress(input) then
				dragging = true
				dragStart = input.Position
				startPos = main.Position
			end
		end)
		table.insert(window.connections, UserInputService.InputChanged:Connect(function(input)
			if dragging and isMove(input) then
				local delta = input.Position - dragStart
				main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X / window.scale, startPos.Y.Scale, startPos.Y.Offset + delta.Y / window.scale)
			end
		end))
		table.insert(window.connections, UserInputService.InputEnded:Connect(function(input)
			if isPress(input) then
				dragging = false
			end
		end))
	end

	---------------------------------------------------------------- sidebar + pages
	local sidebar = make("Frame", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(0, SIDE_W, 1, -40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = main,
	})
	make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = THEME.stroke,
		BorderSizePixel = 0,
		Parent = sidebar,
	})
	local tabList = make("ScrollingFrame", {
		Name = "TabList",
		Size = UDim2.new(1, 0, 1, -62),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = THEME.stroke,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
		Parent = sidebar,
	})
	make("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 9), Parent = tabList})
	make("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabList})

	---------------------------------------------------------------- avatar (di bawah tab)
	do
		local card = make("Frame", {
			Name = "AvatarCard",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 8, 1, -8),
			Size = UDim2.new(1, -17, 0, 46),
			BackgroundColor3 = THEME.elem,
			BorderSizePixel = 0,
			Parent = sidebar,
		})
		corner(card, 10)
		stroke(card, THEME.stroke, 1)
		local avatarImage = make("ImageLabel", {
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = THEME.panel,
			BorderSizePixel = 0,
			Image = "",
			Parent = card,
		})
		corner(avatarImage, 17)
		make("TextLabel", {
			Position = UDim2.fromOffset(46, 7),
			Size = UDim2.new(1, -50, 0, 15),
			BackgroundTransparency = 1,
			Font = FONT_BOLD,
			Text = localPlayer.DisplayName,
			TextColor3 = THEME.text,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		make("TextLabel", {
			Position = UDim2.fromOffset(46, 22),
			Size = UDim2.new(1, -50, 0, 14),
			BackgroundTransparency = 1,
			Font = FONT_REG,
			Text = "@" .. localPlayer.Name,
			TextColor3 = THEME.sub,
			TextSize = 10,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		task.spawn(function()
			local ok, content = pcall(function()
				return Players:GetUserThumbnailAsync(localPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			end)
			if ok and type(content) == "string" and avatarImage.Parent then
				avatarImage.Image = content
			end
		end)
	end

	local pages = make("Frame", {
		Position = UDim2.fromOffset(SIDE_W, 40),
		Size = UDim2.new(1, -SIDE_W, 1, -40),
		BackgroundTransparency = 1,
		Parent = main,
	})

	---------------------------------------------------------------- bubble (buka/tutup)
	local bubble = make("TextButton", {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 10, 0.5, -26),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = THEME.panel,
		BackgroundTransparency = 1,
		Visible = false,
		AutoButtonColor = false,
		Text = "",
		Parent = gui,
	})
	corner(bubble, 26)
	stroke(bubble, THEME.accent, 1.5)
	local bubbleIcon = UI.logo(52, THEME.accent, bubble, true)
	bubbleIcon.holder.AnchorPoint = Vector2.new(0.5, 0.5)
	bubbleIcon.holder.Position = UDim2.fromScale(0.5, 0.5)

	function window:SetVisible(state)
		main.Visible = state
		bubble.Visible = not state
	end

	function window:Toggle()
		UI.playSound("open")
		main.Visible = not main.Visible
		bubble.Visible = not main.Visible
	end

	do
		-- bubble bisa di-drag; tap singkat (tanpa geser) = buka/tutup UI
		local dragging, moved, dragStart, startPos = false, false, nil, nil
		bubble.InputBegan:Connect(function(input)
			if isPress(input) then
				dragging, moved = true, false
				dragStart = input.Position
				startPos = bubble.Position
			end
		end)
		table.insert(window.connections, UserInputService.InputChanged:Connect(function(input)
			if dragging and isMove(input) then
				local delta = input.Position - dragStart
				if delta.Magnitude > 6 then
					moved = true
				end
				if moved then
					bubble.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
				end
			end
		end))
		table.insert(window.connections, UserInputService.InputEnded:Connect(function(input)
			if isPress(input) and dragging then
				dragging = false
				if not moved then
					window:Toggle()
				end
			end
		end))
	end
	hideButton.MouseButton1Click:Connect(function()
		UI.playSound("open")
		main.Visible = false
		bubble.Visible = true
	end)
	window.onClose = nil
	closeButton.MouseButton1Click:Connect(function()
		if window.onClose then
			window.onClose()
		end
	end)

	table.insert(window.connections, UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.RightShift then
			window:Toggle()
		end
	end))

	---------------------------------------------------------------- popup overlay (dropdown)
	local overlay = make("Frame", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 100,
		Visible = false,
		Parent = gui,
	})
	local overlayBack = make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 100,
		Parent = overlay,
	})
	window.overlay = overlay
	window.activePopup = nil

	function window:ClosePopup()
		if window.activePopup then
			window.activePopup:Destroy()
			window.activePopup = nil
		end
		overlay.Visible = false
	end
	overlayBack.MouseButton1Click:Connect(function()
		window:ClosePopup()
	end)

	---------------------------------------------------------------- notifications
	local toastHolder = make("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.fromOffset(250, 300),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	make("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Parent = toastHolder,
	})

	function window:Notify(heading, body, duration)
		UI.playSound("notify")
		local toast = make("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = THEME.panel,
			BorderSizePixel = 0,
			Parent = toastHolder,
		})
		corner(toast, 10)
		stroke(toast, THEME.accent, 1)
		make("UIPadding", {PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12), Parent = toast})
		local toastIcon = UI.logo(22, THEME.accent, toast)
		toastIcon.holder.Position = UDim2.fromOffset(0, 1)
		local textBox = make("Frame", {
			Position = UDim2.fromOffset(30, 0),
			Size = UDim2.new(1, -30, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = toast,
		})
		make("UIListLayout", {Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder, Parent = textBox})
		make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 15),
			BackgroundTransparency = 1,
			Font = FONT_BOLD,
			Text = UI.tr(heading),
			TextColor3 = THEME.text,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			Parent = textBox,
		})
		make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = FONT_REG,
			Text = UI.tr(body or ""),
			TextColor3 = THEME.sub,
			TextSize = 11,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			Parent = textBox,
		})
		task.delay(duration or 3, function()
			if toast and toast.Parent then
				toast:Destroy()
			end
		end)
	end

	---------------------------------------------------------------- tabs
	-- urutan tab: tab yang tidak disebut ikut di belakang sesuai urutan dibuat
	function window:SetTabOrder(names)
		local rank = {}
		for index, name in ipairs(names) do
			rank[name] = index
		end
		local original = {}
		for index, tab in ipairs(window.tabs) do
			original[tab] = index
		end
		table.sort(window.tabs, function(a, b)
			local ra, rb = rank[a.name] or (1000 + original[a]), rank[b.name] or (1000 + original[b])
			return ra < rb
		end)
		for index, tab in ipairs(window.tabs) do
			tab.button.LayoutOrder = index
		end
	end

	function window:AddTab(name, iconName)
		local tab = {name = name, sections = {}}

		local button = make("TextButton", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = THEME.elem,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = #window.tabs + 1,
			Parent = tabList,
		})
		corner(button, 8)
		local indicator = make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(3, 0),
			BackgroundColor3 = THEME.accent,
			BorderSizePixel = 0,
			Parent = button,
		})
		corner(indicator, 2)
		local icon = Icons.new(iconName or "gem", 16, THEME.sub, button)
		icon.holder.Position = UDim2.new(0, 9, 0.5, -8)
		local label = make("TextLabel", {
			Position = UDim2.fromOffset(32, 0),
			Size = UDim2.new(1, -34, 1, 0),
			BackgroundTransparency = 1,
			Font = FONT,
			Text = name,
			TextColor3 = THEME.sub,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = button,
		})

		UI.bind(label, "Text", name)

		local page = make("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = THEME.stroke,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
			Parent = pages,
		})
		make("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12), Parent = page})

		local columnsRow = make("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = page,
		})
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Parent = columnsRow,
		})
		local columns = {}
		for columnIndex = 1, 2 do
			local column = make("Frame", {
				Size = columnIndex == 1 and UDim2.new(1, 0, 0, 0) or UDim2.new(0, 0, 0, 0),
				Visible = columnIndex == 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = columnIndex,
				Parent = columnsRow,
			})
			make("UIListLayout", {Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = column})
			columns[columnIndex] = column
		end

		function tab:Select()
			window:ClosePopup()
			for _, other in ipairs(window.tabs) do
				local active = other == tab
				other.page.Visible = active
				tween(other.button, {BackgroundTransparency = active and 0 or 1}, 0.12)
				tween(other.label, {TextColor3 = active and THEME.text or THEME.sub}, 0.12)
				tween(other.indicator, {Size = UDim2.fromOffset(3, active and 16 or 0)}, 0.15)
				other.icon:SetColor(active and THEME.accent or THEME.sub, true)
			end
		end

		tab.button, tab.page, tab.label, tab.indicator, tab.icon = button, page, label, indicator, icon
		button.MouseButton1Click:Connect(function()
			UI.playSound("tab")
			tab:Select()
		end)
		table.insert(window.tabs, tab)
		if #window.tabs == 1 then
			tab:Select()
		end

		------------------------------------------------------------ sections
		function tab:AddSection(heading, sectionIcon, columnIndex)
			local section = {}

			local holder = make("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = #tab.sections + 1,
				Parent = columns[1],
			})
			make("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder})

			local head = make("Frame", {
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				LayoutOrder = 0,
				Parent = holder,
			})
			local headTextX = 0
			if sectionIcon then
				local headIcon = Icons.new(sectionIcon, 12, THEME.accent, head)
				headIcon.holder.Position = UDim2.new(0, 2, 0.5, -6)
				headTextX = 20
			end
			UI.bind(make("TextLabel", {
				Position = UDim2.fromOffset(headTextX, 0),
				Size = UDim2.new(1, -headTextX, 1, 0),
				BackgroundTransparency = 1,
				Font = FONT_BOLD,
				Text = string.upper(heading),
				TextColor3 = THEME.accent,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = head,
			}), "Text", heading, true)
			table.insert(tab.sections, section)

			local order = 0
			local function newRow(rowOpts, controlWidth)
				order += 1
				local row = make("Frame", {
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = THEME.elem,
					BorderSizePixel = 0,
					LayoutOrder = order,
					Parent = holder,
				})
				corner(row, 10)
				stroke(row, THEME.stroke, 1)
				make("UISizeConstraint", {MinSize = Vector2.new(0, 42), Parent = row})

				local iconPad = rowOpts.Icon and 38 or 12
				local text = make("Frame", {
					Size = UDim2.new(1, controlWidth > 0 and -(controlWidth + 18) or 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Parent = row,
				})
				make("UIPadding", {PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9), PaddingLeft = UDim.new(0, iconPad), PaddingRight = UDim.new(0, 6), Parent = text})
				make("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = text})

				local titleLabel = make("TextLabel", {
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Font = FONT,
					Text = rowOpts.Title,
					TextColor3 = THEME.text,
					TextSize = 13,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 1,
					Parent = text,
				})
				local descLabel
				if rowOpts.Content and rowOpts.Content ~= "" then
					descLabel = make("TextLabel", {
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						Font = FONT_REG,
						Text = rowOpts.Content,
						TextColor3 = THEME.sub,
						TextSize = 11,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 2,
						Parent = text,
					})
				end
				UI.bind(titleLabel, "Text", rowOpts.Title)
				if descLabel then
					UI.bind(descLabel, "Text", rowOpts.Content)
				end
				if rowOpts.Icon then
					local rowIcon = Icons.new(rowOpts.Icon, 16, THEME.accent, row)
					rowIcon.holder.AnchorPoint = Vector2.new(0, 0.5)
					rowIcon.holder.Position = UDim2.new(0, 13, 0.5, 0)
				end
				return row, titleLabel, descLabel
			end

			---------------------------------------------------- Toggle
			function section:AddToggle(toggleOpts)
				local row = newRow(toggleOpts, 40)
				local object = {Value = toggleOpts.Default == true, Row = row}

				local track = make("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.fromOffset(38, 20),
					BackgroundColor3 = THEME.off,
					AutoButtonColor = false,
					Text = "",
					Parent = row,
				})
				corner(track, 10)
				local knob = make("Frame", {
					Position = UDim2.fromOffset(3, 3),
					Size = UDim2.fromOffset(14, 14),
					BackgroundColor3 = THEME.text,
					BorderSizePixel = 0,
					Parent = track,
				})
				corner(knob, 7)

				local function render(animate)
					local on = object.Value
					local goalPos = on and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3)
					local goalColor = on and THEME.accent or THEME.off
					local knobColor = on and THEME.onAccent or THEME.text
					if animate then
						tween(knob, {Position = goalPos, BackgroundColor3 = knobColor})
						tween(track, {BackgroundColor3 = goalColor})
					else
						knob.Position = goalPos
						knob.BackgroundColor3 = knobColor
						track.BackgroundColor3 = goalColor
					end
				end

				function object:Set(value, silent)
					object.Value = value == true
					render(true)
					if not silent and toggleOpts.Callback then
						task.spawn(toggleOpts.Callback, object.Value)
					end
				end
				function object:Get()
					return object.Value
				end

				track.MouseButton1Click:Connect(function()
					object:Set(not object.Value)
					UI.playSound(object.Value and "on" or "off")
				end)
				render(false)
				return object
			end

			---------------------------------------------------- Button
			function section:AddButton(buttonOpts)
				local row = newRow(buttonOpts, 70)
				local button = make("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(70, 26),
					BackgroundColor3 = buttonOpts.Danger and THEME.bad or THEME.accent,
					AutoButtonColor = false,
					Font = FONT_BOLD,
					Text = buttonOpts.Label or "Run",
					TextColor3 = buttonOpts.Danger and Color3.new(1, 1, 1) or THEME.onAccent,
					TextSize = 12,
					Parent = row,
				})
				UI.bind(button, "Text", buttonOpts.Label or "Run")
				corner(button, 7)
				button.MouseButton1Click:Connect(function()
					UI.playSound("click")
					tween(button, {BackgroundTransparency = 0.4}, 0.06)
					task.delay(0.08, function()
						tween(button, {BackgroundTransparency = 0}, 0.12)
					end)
					if buttonOpts.Callback then
						task.spawn(buttonOpts.Callback)
					end
				end)
				return button
			end

			---------------------------------------------------- Canvas (kartu bebas: ikon + angka, mis. Butterfly)
			function section:AddCanvas(canvasOpts)
				order += 1
				local UNIT = 16
				local lines = 3.3
				local row = make("Frame", {
					Size = UDim2.new(1, 0, 0, math.ceil(lines * UNIT) + 6),
					BackgroundColor3 = THEME.elem,
					BorderSizePixel = 0,
					ClipsDescendants = true,
					LayoutOrder = order,
					Parent = holder,
				})
				corner(row, 10)
				stroke(row, THEME.stroke, 1)
				local content = make("Frame", {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Parent = row,
				})

				local function toColor(value)
					if typeof(value) == "Color3" then
						return value
					end
					if type(value) == "string" then
						local ok, color = pcall(Color3.fromHex, value)
						if ok then
							return color
						end
					end
					return THEME.text
				end

				local function track(instance, props)
					local geo = {X = props.X or 0, Y = props.Y or 0, Width = props.Width or 1, Height = props.Height or 1}
					local function layout()
						instance.Position = UDim2.fromOffset(geo.X * UNIT, geo.Y * UNIT)
						instance.Size = UDim2.fromOffset(geo.Width * UNIT, geo.Height * UNIT)
					end
					layout()
					return geo, layout
				end

				local canvas = {}
				function canvas:Text(props)
					local label = make("TextLabel", {
						BackgroundTransparency = 1,
						Font = FONT_BOLD,
						Text = tostring(props.Text or ""),
						TextColor3 = toColor(props.Color),
						TextSize = math.clamp(math.floor(UNIT * 0.78 * (props.Scale or 1)), 9, 20),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
						TextWrapped = false,
						TextStrokeTransparency = props.TextStrokeTransparency or 1,
						Parent = content,
					})
					local geo, layout = track(label, props)
					return {
						Set = function(update)
							if type(update) ~= "table" then
								return
							end
							for key in pairs(geo) do
								if update[key] ~= nil then
									geo[key] = update[key]
								end
							end
							layout()
							if update.Text ~= nil then
								label.Text = tostring(update.Text)
							end
							if update.Color ~= nil then
								label.TextColor3 = toColor(update.Color)
							end
						end,
						Destroy = function()
							label:Destroy()
						end,
					}
				end
				function canvas:Image(props)
					local image = make("ImageLabel", {
						BackgroundTransparency = props.BackgroundTransparency or 1,
						Image = props.Image or "",
						ScaleType = Enum.ScaleType.Fit,
						Parent = content,
					})
					local geo, layout = track(image, props)
					return {
						Set = function(update)
							if type(update) ~= "table" then
								return
							end
							for key in pairs(geo) do
								if update[key] ~= nil then
									geo[key] = update[key]
								end
							end
							layout()
							if update.Image ~= nil then
								image.Image = update.Image
							end
						end,
						Destroy = function()
							image:Destroy()
						end,
					}
				end
				function canvas:SetContentLines(count)
					lines = tonumber(count) or lines
					row.Size = UDim2.new(1, 0, 0, math.ceil(lines * UNIT) + 6)
				end
				local resizeCallbacks = {}
				local lastWidth
				local function fireResize()
					local width = row.AbsoluteSize.X / math.max(window.scale or 1, 0.01)
					if width <= 0 or width == lastWidth then
						return
					end
					lastWidth = width
					for _, callback in ipairs(resizeCallbacks) do
						pcall(callback, nil, width, UNIT)
					end
				end
				function canvas:OnResize(callback)
					table.insert(resizeCallbacks, callback)
					task.defer(fireResize)
				end
				row:GetPropertyChangedSignal("AbsoluteSize"):Connect(fireResize)

				if type(canvasOpts.Build) == "function" then
					pcall(canvasOpts.Build, canvas)
				end
				task.defer(fireResize)

				local object = {}
				function object:Destroy()
					row:Destroy()
				end
				return object
			end

			---------------------------------------------------- Label
			function section:AddLabel(labelOpts)
				local _, titleLabel, descLabel = newRow({Title = labelOpts.Title, Content = labelOpts.Content or " ", Icon = labelOpts.Icon}, 0)
				local object = {}
				function object:SetTitle(textValue)
					titleLabel.Text = textValue
				end
				function object:SetContent(textValue)
					if descLabel then
						descLabel.Text = textValue
					end
				end
				return object
			end

			---------------------------------------------------- Input
			function section:AddInput(inputOpts)
				local row, titleLabel, descLabel = newRow(inputOpts, 92)
				local object = {Value = tostring(inputOpts.Default or ""), Row = row}

				local box = make("TextBox", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(92, 26),
					BackgroundColor3 = THEME.bg,
					Font = FONT,
					Text = object.Value,
					PlaceholderText = inputOpts.Placeholder or "",
					PlaceholderColor3 = THEME.sub,
					TextColor3 = THEME.text,
					TextSize = 12,
					ClearTextOnFocus = false,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = row,
				})
				corner(box, 7)
				local boxStroke = stroke(box, THEME.stroke, 1)
				make("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = box})

				box.Focused:Connect(function()
					tween(boxStroke, {Color = THEME.accent}, 0.1)
				end)
				box.FocusLost:Connect(function()
					tween(boxStroke, {Color = THEME.stroke}, 0.1)
					object.Value = box.Text
					if inputOpts.Callback then
						task.spawn(inputOpts.Callback, object.Value)
					end
				end)

				function object:Set(value, silent)
					object.Value = tostring(value or "")
					box.Text = object.Value
					if not silent and inputOpts.Callback then
						task.spawn(inputOpts.Callback, object.Value)
					end
				end
				function object:Get()
					return object.Value
				end
				function object:SetTitle(textValue)
					titleLabel.Text = textValue
				end
				function object:SetContent(textValue)
					if descLabel then
						descLabel.Text = textValue
					end
				end
				return object
			end

			---------------------------------------------------- Slider
			function section:AddSlider(sliderOpts)
				local row = newRow(sliderOpts, 112)
				local min, max, step = sliderOpts.Min, sliderOpts.Max, sliderOpts.Increment or 1
				local object = {Value = math.clamp(sliderOpts.Default or min, min, max)}

				local control = make("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(112, 20),
					BackgroundTransparency = 1,
					Parent = row,
				})
				local valueLabel = make("TextLabel", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.fromOffset(28, 20),
					BackgroundTransparency = 1,
					Font = FONT_BOLD,
					Text = tostring(object.Value),
					TextColor3 = THEME.accent,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Right,
					Parent = control,
				})
				local hit = make("TextButton", {
					Size = UDim2.new(1, -34, 1, 0),
					BackgroundTransparency = 1,
					Text = "",
					AutoButtonColor = false,
					Parent = control,
				})
				local bar = make("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.new(1, 0, 0, 4),
					BackgroundColor3 = THEME.off,
					BorderSizePixel = 0,
					Parent = hit,
				})
				corner(bar, 2)
				local fill = make("Frame", {
					Size = UDim2.fromScale(0, 1),
					BackgroundColor3 = THEME.accent,
					BorderSizePixel = 0,
					Parent = bar,
				})
				corner(fill, 2)
				local handle = make("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromOffset(12, 12),
					BackgroundColor3 = THEME.accent2,
					BorderSizePixel = 0,
					Parent = bar,
				})
				corner(handle, 6)

				local function render()
					local alpha = (object.Value - min) / math.max(max - min, 1e-9)
					fill.Size = UDim2.fromScale(alpha, 1)
					handle.Position = UDim2.fromScale(alpha, 0.5)
					valueLabel.Text = tostring(object.Value)
				end

				local function setFromX(x)
					local alpha = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
					local value = min + (max - min) * alpha
					value = math.clamp(math.floor(value / step + 0.5) * step, min, max)
					if value ~= object.Value then
						object.Value = value
						render()
						if sliderOpts.Callback then
							task.spawn(sliderOpts.Callback, value)
						end
					end
				end

				local dragging = false
				hit.InputBegan:Connect(function(input)
					if isPress(input) then
						dragging = true
						setFromX(input.Position.X)
					end
				end)
				table.insert(window.connections, UserInputService.InputChanged:Connect(function(input)
					if dragging and isMove(input) then
						setFromX(input.Position.X)
					end
				end))
				table.insert(window.connections, UserInputService.InputEnded:Connect(function(input)
					if isPress(input) then
						dragging = false
					end
				end))

				function object:Set(value, silent)
					object.Value = math.clamp(tonumber(value) or min, min, max)
					render()
					if not silent and sliderOpts.Callback then
						task.spawn(sliderOpts.Callback, object.Value)
					end
				end
				function object:Get()
					return object.Value
				end
				render()
				return object
			end

			---------------------------------------------------- Dropdown
			function section:AddDropdown(dropOpts)
				local row = newRow(dropOpts, 112)
				local multi = dropOpts.Multi == true
				local options = dropOpts.Options or {}
				local object = {Value = multi and {} or nil}

				local selected = {}
				local function applyDefault(value)
					selected = {}
					if multi then
						for _, item in ipairs(type(value) == "table" and value or {}) do
							selected[item] = true
						end
					elseif value ~= nil then
						selected[value] = true
					end
				end
				applyDefault(dropOpts.Default)

				local function orderedSelection()
					local list = {}
					for _, option in ipairs(options) do
						if selected[option] then
							list[#list + 1] = option
						end
					end
					return list
				end

				local button = make("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(112, 26),
					BackgroundColor3 = THEME.bg,
					AutoButtonColor = false,
					Text = "",
					Parent = row,
				})
				corner(button, 7)
				stroke(button, THEME.stroke, 1)
				local summary = make("TextLabel", {
					Position = UDim2.fromOffset(8, 0),
					Size = UDim2.new(1, -26, 1, 0),
					BackgroundTransparency = 1,
					Font = FONT,
					Text = "",
					TextColor3 = THEME.text,
					TextSize = 12,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = button,
				})
				local chevron = Icons.new("chevron-down", 12, THEME.sub, button)
				chevron.holder.AnchorPoint = Vector2.new(1, 0.5)
				chevron.holder.Position = UDim2.new(1, -7, 0.5, 0)

				local function refreshSummary()
					local list = orderedSelection()
					if #list == 0 then
						summary.Text = UI.tr(multi and (dropOpts.EmptyText or "Any") or "Select...")
						summary.TextColor3 = THEME.sub
					else
						summary.TextColor3 = THEME.text
						if multi and #list > 1 then
							summary.Text = list[1] .. "  +" .. (#list - 1)
						else
							summary.Text = table.concat(list, ", ")
						end
					end
					object.Value = multi and list or list[1]
				end

				local function fire()
					refreshSummary()
					if dropOpts.Callback then
						task.spawn(dropOpts.Callback, object.Value)
					end
				end

				local function open()
					window:ClosePopup()
					overlay.Visible = true

					local absPos, absSize = button.AbsolutePosition, button.AbsoluteSize
					local view = gui.AbsoluteSize
					local popupWidth = math.max(absSize.X, 180)
					local popupHeight = math.min(46 + #options * 28 + 6, 250)
					local x = math.clamp(absPos.X + absSize.X - popupWidth, 4, math.max(view.X - popupWidth - 4, 4))
					local y = absPos.Y + absSize.Y + 4
					if y + popupHeight > view.Y - 4 then
						y = math.max(absPos.Y - popupHeight - 4, 4)
					end

					local popup = make("Frame", {
						Position = UDim2.fromOffset(x, y),
						Size = UDim2.fromOffset(popupWidth, popupHeight),
						BackgroundColor3 = THEME.panel,
						BorderSizePixel = 0,
						ZIndex = 101,
						Parent = overlay,
					})
					corner(popup, 10)
					stroke(popup, THEME.accent, 1)
					window.activePopup = popup

					local search = make("TextBox", {
						Position = UDim2.fromOffset(6, 6),
						Size = UDim2.new(1, multi and -70 or -12, 0, 28),
						BackgroundColor3 = THEME.bg,
						Font = FONT,
						Text = "",
						PlaceholderText = UI.tr("Search..."),
						PlaceholderColor3 = THEME.sub,
						TextColor3 = THEME.text,
						TextSize = 12,
						ClearTextOnFocus = false,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 102,
						Parent = popup,
					})
					corner(search, 7)
					make("UIPadding", {PaddingLeft = UDim.new(0, 8), Parent = search})

					local entries = {}

					if multi then
						local clear = make("TextButton", {
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, -6, 0, 6),
							Size = UDim2.fromOffset(54, 28),
							BackgroundColor3 = THEME.elem,
							AutoButtonColor = false,
							Font = FONT_BOLD,
							Text = UI.tr("Clear"),
							TextColor3 = THEME.text,
							TextSize = 11,
							ZIndex = 102,
							Parent = popup,
						})
						corner(clear, 7)
						clear.MouseButton1Click:Connect(function()
							selected = {}
							for _, entry in pairs(entries) do
								entry.BackgroundColor3 = THEME.elem
								entry.TextColor3 = THEME.text
							end
							fire()
						end)
					end

					local list = make("ScrollingFrame", {
						Position = UDim2.fromOffset(6, 40),
						Size = UDim2.new(1, -12, 1, -46),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 2,
						CanvasSize = UDim2.new(),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						ZIndex = 102,
						Parent = popup,
					})
					make("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list})

					for index, option in ipairs(options) do
						local entry = make("TextButton", {
							Size = UDim2.new(1, -4, 0, 26),
							BackgroundColor3 = selected[option] and THEME.accent or THEME.elem,
							AutoButtonColor = false,
							Font = FONT,
							Text = option,
							TextColor3 = selected[option] and THEME.onAccent or THEME.text,
							TextSize = 12,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
							LayoutOrder = index,
							ZIndex = 103,
							Parent = list,
						})
						corner(entry, 6)
						make("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = entry})
						entries[option] = entry

						entry.MouseButton1Click:Connect(function()
							UI.playSound("click")
							if multi then
								selected[option] = not selected[option] or nil
								entry.BackgroundColor3 = selected[option] and THEME.accent or THEME.elem
								entry.TextColor3 = selected[option] and THEME.onAccent or THEME.text
								fire()
							else
								selected = {[option] = true}
								fire()
								window:ClosePopup()
							end
						end)
					end

					search:GetPropertyChangedSignal("Text"):Connect(function()
						local query = string.lower(search.Text)
						for option, entry in pairs(entries) do
							entry.Visible = query == "" or string.find(string.lower(option), query, 1, true) ~= nil
						end
					end)
				end

				button.MouseButton1Click:Connect(function()
					UI.playSound("click")
					open()
				end)

				function object:Set(value, silent)
					applyDefault(value)
					refreshSummary()
					if not silent and dropOpts.Callback then
						task.spawn(dropOpts.Callback, object.Value)
					end
				end
				function object:Get()
					return object.Value
				end
				-- dipakai ci.lua (mis. daftar Weapon) untuk memperbarui pilihan setelah dropdown dibuat
				function object:SetOptions(newOptions, newSelected)
					options = type(newOptions) == "table" and newOptions or {}
					if newSelected ~= nil then
						applyDefault(newSelected)
					end
					local valid = {}
					for _, option in ipairs(options) do
						valid[option] = true
					end
					for key in pairs(selected) do
						if not valid[key] then
							selected[key] = nil
						end
					end
					refreshSummary()
					if dropOpts.Callback then
						task.spawn(dropOpts.Callback, object.Value)
					end
				end
				refreshSummary()
				table.insert(UI.refreshers, refreshSummary)
				return object
			end

			return section
		end

		return tab
	end

	function window:Destroy()
		for _, connection in ipairs(window.connections) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		window.connections = {}
		if gui then
			gui:Destroy()
		end
	end

	return window
end


----------------------------------------------------------------------
-- Live HUD (pop-up progress: ikon pet, nama, rarity, kg, harga, progress)
----------------------------------------------------------------------
function UI.hud(window)
	local hud = {shown = false}
	local HUD_W, HUD_H = 236, 60

	local frame = make("Frame", {
		Name = "LiveHud",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, HUD_W + 24, 0, 12),
		Size = UDim2.fromOffset(HUD_W, HUD_H),
		BackgroundColor3 = THEME.bg,
		BorderSizePixel = 0,
		Active = true,
		Visible = false,
		Parent = window.gui,
	})
	corner(frame, 10)
	stroke(frame, THEME.stroke, 1)
	hud.frame = frame
	hud.home = UDim2.new(1, -10, 0, 12) -- pojok kanan atas

	local function hiddenPos(home)
		return UDim2.new(home.X.Scale, home.X.Offset + HUD_W + 24, home.Y.Scale, home.Y.Offset)
	end

	-- kotak ikon pet
	local box = make("Frame", {
		Position = UDim2.fromOffset(8, 11),
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = THEME.elem,
		BorderSizePixel = 0,
		Parent = frame,
	})
	corner(box, 8)
	local boxStroke = stroke(box, THEME.stroke, 1.5)
	local petImage = make("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
		Parent = box,
	})
	local placeholder = Icons.new("egg", 18, THEME.sub, box)
	placeholder.holder.AnchorPoint = Vector2.new(0.5, 0.5)
	placeholder.holder.Position = UDim2.fromScale(0.5, 0.5)

	local nameLabel = make("TextLabel", {
		Position = UDim2.fromOffset(54, 6),
		Size = UDim2.new(1, -62, 0, 14),
		BackgroundTransparency = 1,
		Font = FONT_BOLD,
		Text = "No target yet",
		TextColor3 = THEME.sub,
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})

	local statsRow = make("Frame", {
		Position = UDim2.fromOffset(54, 21),
		Size = UDim2.new(1, -62, 0, 12),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = frame,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = statsRow,
	})

	local function stat(iconName, order)
		local item = make("Frame", {
			Size = UDim2.fromOffset(0, 12),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = statsRow,
		})
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Parent = item,
		})
		local icon = Icons.new(iconName, 10, THEME.accent, item)
		icon.holder.LayoutOrder = 1
		local label = make("TextLabel", {
			Size = UDim2.fromOffset(0, 12),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Font = FONT_BOLD,
			Text = "--",
			TextColor3 = THEME.sub,
			TextSize = 10,
			LayoutOrder = 2,
			Parent = item,
		})
		return label, icon
	end

	local rarityText, rarityIcon = stat("gem", 1)
	local kgText = stat("weight", 2)
	local priceText = stat("coins", 3)

	local statusText = make("TextLabel", {
		Position = UDim2.fromOffset(54, 34),
		Size = UDim2.new(1, -100, 0, 12),
		BackgroundTransparency = 1,
		Font = FONT_REG,
		Text = "Idle",
		TextColor3 = THEME.sub,
		TextSize = 10,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	local percentText = make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 34),
		Size = UDim2.fromOffset(34, 12),
		BackgroundTransparency = 1,
		Font = FONT_BOLD,
		Text = "0%",
		TextColor3 = THEME.accent,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	})
	local track = make("Frame", {
		Position = UDim2.fromOffset(54, 50),
		Size = UDim2.new(1, -62, 0, 3),
		BackgroundColor3 = THEME.off,
		BorderSizePixel = 0,
		Parent = frame,
	})
	corner(track, 2)
	local fill = make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = THEME.accent,
		BorderSizePixel = 0,
		Parent = track,
	})
	corner(fill, 2)
	make("UIGradient", {Color = ColorSequence.new(THEME.accent, THEME.accent2), Parent = fill})

	-- drag
	do
		local dragging, dragStart, startPos
		frame.InputBegan:Connect(function(input)
			if isPress(input) then
				dragging = true
				dragStart = input.Position
				startPos = frame.Position
			end
		end)
		table.insert(window.connections, UserInputService.InputChanged:Connect(function(input)
			if dragging and isMove(input) then
				local delta = input.Position - dragStart
				frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end))
		table.insert(window.connections, UserInputService.InputEnded:Connect(function(input)
			if isPress(input) and dragging then
				dragging = false
				hud.home = frame.Position
			end
		end))
	end

	function hud:SetVisible(state)
		state = state == true
		if hud.shown == state then
			return
		end
		hud.shown = state
		local home = hud.home
		if state then
			frame.Visible = true
			frame.Position = hiddenPos(home)
			tween(frame, {Position = home}, 0.25)
		else
			tween(frame, {Position = hiddenPos(home)}, 0.2)
			task.delay(0.23, function()
				if not hud.shown and frame.Parent then
					frame.Visible = false
				end
			end)
		end
	end

	local lastSig, lastPct

	function hud:Update(data)
		data = data or {}
		local hasTarget = data.name ~= nil
		local alpha = math.clamp(tonumber(data.alpha) or 0, 0, 1)
		local pct = math.floor(alpha * 100 + 0.5)

		-- lewati kalau tidak ada yang berubah (hemat FPS)
		local sig = table.concat({tostring(data.name), tostring(data.rarity), tostring(data.kg), tostring(data.price), tostring(data.status), tostring(data.icon), tostring(pct)}, "|")
		if sig == lastSig then
			return
		end
		lastSig = sig

		local color = typeof(data.color) == "Color3" and data.color or THEME.accent

		nameLabel.Text = hasTarget and tostring(data.name) or "No target yet"
		nameLabel.TextColor3 = hasTarget and THEME.text or THEME.sub

		rarityText.Text = hasTarget and tostring(data.rarity or "?") or "--"
		rarityText.TextColor3 = hasTarget and color or THEME.sub
		rarityIcon:SetColor(hasTarget and color or THEME.accent)
		kgText.Text = hasTarget and tostring(data.kg or "--") or "--"
		kgText.TextColor3 = hasTarget and THEME.text or THEME.sub
		priceText.Text = hasTarget and tostring(data.price or "--") or "--"
		priceText.TextColor3 = hasTarget and THEME.good or THEME.sub
		boxStroke.Color = hasTarget and color or THEME.stroke

		if hasTarget and type(data.icon) == "string" and data.icon ~= "" then
			if petImage.Image ~= data.icon then
				petImage.Image = data.icon
			end
			petImage.Visible = true
			placeholder.holder.Visible = false
		else
			petImage.Visible = false
			placeholder.holder.Visible = true
		end

		statusText.Text = tostring(data.status or "")
		percentText.Text = pct .. "%"
		if pct ~= lastPct then
			lastPct = pct
			tween(fill, {Size = UDim2.fromScale(alpha, 1)}, 0.2)
		end
	end

	return hud
end


----------------------------------------------------------------------
-- Build UI
----------------------------------------------------------------------
local loaded = Storage.load()
fanKunHubConfig.AutoSteal = false
Steal.applyAll()

UI.lang = fanKunHubConfig.Language == "English" and "English" or "Indonesia"

local window = UI.new({Title = "FanKunHUB / STEAL AN EGG V4"})
local hud = UI.hud(window)
local controls = {}

local saveQueued = false
local function queueSave()
	if saveQueued then
		return
	end
	saveQueued = true
	task.delay(0.6, function()
		saveQueued = false
		Storage.save()
	end)
end

local function persist(callback)
	return function(value)
		callback(value)
		queueSave()
	end
end

local function unload()
	if genv.__FanKunHUBHubSession == fanKunHubHubSession then
		genv.__FanKunHUBHubSession = nil
	end
	pcall(Steal.setEnabled, false)
	if type(genv.__FanKunHUBStealDeclutterCleanup) == "function" then
		pcall(genv.__FanKunHUBStealDeclutterCleanup)
	end
	pcall(genv.__FanKunHUBEggRuntimeCleanup)
	pcall(genv.__FanKunHUBAntiGuardCleanup)
	pcall(function()
		window:Destroy()
	end)
	genv.__FanKunHUBHubShutdown = nil
end

genv.__FanKunHUBHubShutdown = unload
window.onClose = unload

local cfg = fanKunHubConfig

------------------------------------------------------------ Tab: Auto Steal
local stealTab = window:AddTab("Steal", "hand")

local autoSection = stealTab:AddSection("Auto Steal", "hand", 1)
local optionsSection = stealTab:AddSection("Options", "sparkles", 2)

controls.autoSteal = autoSection:AddToggle({
	Title = "Auto Steal",
	Content = "Steal matching eggs and bank them.",
	Icon = "power",
	Default = false,
	Callback = function(value)
		Steal.setEnabled(value)
		window:Notify("Auto Steal", value and "Enabled" or "Disabled", 2)
	end,
})

-- Steal Panel: panel melayang berisi semua egg yang bisa dicuri. Klik nama pet = masuk antrian steal.
-- Memakai antrian manual milik engine (queueManual), jadi tetap jalan walau Auto Steal mati.
do
	local panel, scroll, hintLabel, emptyLabel
	local rows = {}
	local looping = false
	local refresh

	local function buildPanel()
		panel = make("Frame", {
			Name = "StealPanel",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(300, 330),
			BackgroundColor3 = THEME.bg,
			BorderSizePixel = 0,
			Active = true,
			Visible = false,
			Parent = window.gui,
		})
		corner(panel, 12)
		stroke(panel, THEME.stroke, 1)
		local panelScale = make("UIScale", {Scale = math.clamp(window.scale or 0.78, 0.55, 0.9), Parent = panel})

		local header = make("Frame", {
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
			Active = true,
			Parent = panel,
		})
		make("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = THEME.stroke,
			BorderSizePixel = 0,
			Parent = header,
		})
		UI.bind(make("TextLabel", {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -52, 1, 0),
			BackgroundTransparency = 1,
			Font = FONT_BOLD,
			Text = "",
			TextColor3 = THEME.text,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = header,
		}), "Text", "Steal Panel")

		local closeButton = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = THEME.elem,
			AutoButtonColor = false,
			Font = FONT_BOLD,
			Text = "X",
			TextColor3 = THEME.text,
			TextSize = 12,
			Parent = header,
		})
		corner(closeButton, 7)
		closeButton.MouseButton1Click:Connect(function()
			UI.playSound("click")
			if controls.stealPanelToggle then
				controls.stealPanelToggle:Set(false)
			else
				controls.stealPanel.Set(false)
			end
		end)

		hintLabel = make("TextLabel", {
			Position = UDim2.fromOffset(12, 38),
			Size = UDim2.new(1, -24, 0, 18),
			BackgroundTransparency = 1,
			Font = FONT_REG,
			Text = "",
			TextColor3 = THEME.sub,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = panel,
		})

		scroll = make("ScrollingFrame", {
			Position = UDim2.fromOffset(6, 60),
			Size = UDim2.new(1, -12, 1, -100),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = THEME.accent2,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Parent = panel,
		})
		make("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll})

		emptyLabel = make("TextLabel", {
			Position = UDim2.fromOffset(12, 90),
			Size = UDim2.new(1, -24, 0, 30),
			BackgroundTransparency = 1,
			Font = FONT_REG,
			Text = "",
			TextColor3 = THEME.sub,
			TextSize = 11,
			Visible = false,
			Parent = panel,
		})
		UI.bind(emptyLabel, "Text", "No eggs available right now.")

		local clearButton = make("TextButton", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -7),
			Size = UDim2.new(1, -16, 0, 28),
			BackgroundColor3 = THEME.elem,
			AutoButtonColor = false,
			Font = FONT_BOLD,
			Text = "",
			TextColor3 = THEME.text,
			TextSize = 12,
			Parent = panel,
		})
		corner(clearButton, 8)
		stroke(clearButton, THEME.stroke, 1)
		UI.bind(clearButton, "Text", "Stop Steal")
		clearButton.MouseButton1Click:Connect(function()
			UI.playSound("click")
			pcall(function()
				v13:clearManual()
			end)
			pcall(refresh)
		end)

		-- geser panel lewat header
		local dragging, dragStart, startPos = false, nil, nil
		header.InputBegan:Connect(function(input)
			if isPress(input) then
				dragging = true
				dragStart = input.Position
				startPos = panel.Position
			end
		end)
		table.insert(window.connections, UserInputService.InputChanged:Connect(function(input)
			if dragging and isMove(input) and dragStart then
				local delta = input.Position - dragStart
				local scale = panelScale.Scale
				panel.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + delta.X / scale,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y / scale
				)
			end
		end))
		table.insert(window.connections, UserInputService.InputEnded:Connect(function(input)
			if isPress(input) then
				dragging = false
			end
		end))
	end

	local function makeRow(uid)
		local row = make("TextButton", {
			Size = UDim2.new(1, -4, 0, 46),
			BackgroundColor3 = THEME.elem,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Parent = scroll,
		})
		corner(row, 8)
		local rowStroke = stroke(row, THEME.stroke, 1)
		local iconImage = make("ImageLabel", {
			Position = UDim2.fromOffset(6, 5),
			Size = UDim2.fromOffset(36, 36),
			BackgroundTransparency = 1,
			Image = "",
			ScaleType = Enum.ScaleType.Fit,
			Visible = false,
			Parent = row,
		})
		local nameLabel = make("TextLabel", {
			Position = UDim2.fromOffset(48, 5),
			Size = UDim2.new(1, -122, 0, 18),
			BackgroundTransparency = 1,
			Font = FONT_BOLD,
			Text = "",
			TextColor3 = THEME.text,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		local infoLabel = make("TextLabel", {
			Position = UDim2.fromOffset(48, 25),
			Size = UDim2.new(1, -122, 0, 15),
			BackgroundTransparency = 1,
			Font = FONT_REG,
			Text = "",
			TextColor3 = THEME.sub,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		local tag = make("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(62, 20),
			BackgroundColor3 = THEME.panel,
			Font = FONT_BOLD,
			Text = "",
			TextColor3 = THEME.sub,
			TextSize = 10,
			Parent = row,
		})
		corner(tag, 6)

		local entry = {row = row, rowStroke = rowStroke, iconImage = iconImage, nameLabel = nameLabel, infoLabel = infoLabel, tag = tag, name = ""}
		row.MouseEnter:Connect(function()
			tween(row, {BackgroundColor3 = THEME.elemHover}, 0.1)
		end)
		row.MouseLeave:Connect(function()
			tween(row, {BackgroundColor3 = THEME.elem}, 0.1)
		end)
		row.MouseButton1Click:Connect(function()
			UI.playSound("click")
			local ok = pcall(function()
				v13:stealNow(uid)
			end)
			if ok then
				window:Notify(UI.tr("Steal Panel"), entry.name .. "  \194\183  " .. UI.tr("Stealing"), 2)
			end
			pcall(refresh)
		end)

		rows[uid] = entry
		return entry
	end

	refresh = function()
		if not panel or not panel.Visible then
			return
		end

		local ok, list = pcall(function()
			return v13:listStealableEggs()
		end)
		if not ok or type(list) ~= "table" then
			list = {}
		end

		table.sort(list, function(a, b)
			if a.rarityRank ~= b.rarityRank then
				return a.rarityRank > b.rarityRank
			end
			return (a.distance or 1e9) < (b.distance or 1e9)
		end)

		local seen = {}
		local shown = 0

		for i, egg in ipairs(list) do
			if i > 80 then
				break
			end
			shown += 1
			seen[egg.uid] = true

			local entry = rows[egg.uid] or makeRow(egg.uid)
			local queued = v13.activeTarget ~= nil and v13.activeTarget.Uid == egg.uid
			local parts = {egg.rarity}

			if type(egg.kg) == "number" then
				parts[#parts + 1] = string.format("%d Kg", math.floor(egg.kg))
			end
			if egg.mutations and egg.mutations ~= "" then
				parts[#parts + 1] = egg.mutations
			end
			if egg.value then
				parts[#parts + 1] = "$" .. egg.value .. "/s"
			end
			if egg.area then
				parts[#parts + 1] = egg.area
			end
			if egg.distance then
				parts[#parts + 1] = string.format("%d st", math.floor(egg.distance))
			end

			entry.name = egg.name
			entry.row.LayoutOrder = i
			entry.nameLabel.Text = egg.name
			if entry.iconImage.Image ~= (egg.icon or "") then
				entry.iconImage.Image = egg.icon or ""
			end
			entry.iconImage.Visible = egg.icon ~= nil
			entry.nameLabel.TextColor3 = egg.color or THEME.text
			entry.infoLabel.Text = table.concat(parts, "  \194\183  ")

			if queued then
				entry.tag.Text = string.upper(UI.tr("Stealing"))
				entry.tag.TextColor3 = THEME.onAccent
				entry.tag.BackgroundColor3 = THEME.accent
				entry.rowStroke.Color = THEME.accent
			else
				entry.tag.Text = string.upper(UI.tr(egg.dropped and "Dropped" or "Steal"))
				entry.tag.TextColor3 = THEME.sub
				entry.tag.BackgroundColor3 = THEME.panel
				entry.rowStroke.Color = THEME.stroke
			end
		end

		for uid, entry in pairs(rows) do
			if not seen[uid] then
				pcall(function()
					entry.row:Destroy()
				end)
				rows[uid] = nil
			end
		end

		emptyLabel.Visible = shown == 0
		hintLabel.Text = UI.tr("Tap a pet to steal it") .. "  \194\183  " .. tostring(shown) .. " " .. UI.tr("Eggs")
	end

	local function startLoop()
		if looping then
			return
		end
		looping = true
		task.spawn(function()
			while fn2() and panel and panel.Parent and panel.Visible do
				pcall(refresh)
				task.wait(0.5)
			end
			looping = false
		end)
	end

	controls.stealPanel = {
		Set = function(on)
			if on then
				if not panel then
					buildPanel()
				end
				panel.Visible = true
				pcall(refresh)
				startLoop()
			elseif panel then
				panel.Visible = false
			end
		end,
	}

	table.insert(UI.refreshers, function()
		pcall(refresh)
	end)
end

controls.stealPanelToggle = autoSection:AddToggle({
	Title = "Steal Panel",
	Content = "Show a floating panel with every egg. Tap a pet name to steal it.",
	Icon = "layout-dashboard",
	Default = false,
	Callback = function(value)
		controls.stealPanel.Set(value)
	end,
})

controls.stealMode = autoSection:AddDropdown({
	Title = "Steal Mode",
	Content = "Instant: needs stable ping & FPS. Run: walk to the egg.",
	Icon = "zap",
	Options = {MODE_INSTANT, MODE_RUN},
	Default = Steal.stealModeLabel(),
	Multi = false,
	Callback = persist(Steal.setStealMode),
})

controls.runDropCount = autoSection:AddSlider({
	Title = "Run Return Drops",
	Content = "Saat Run return: drop egg lalu ambil lagi beberapa kali sebelum base. 0 = off.",
	Icon = "repeat-2",
	Min = 0,
	Max = 10,
	Increment = 1,
	Default = math.clamp(tonumber(cfg.RunDropCount) or 3, 0, 10),
	Callback = persist(Steal.setRunDropCount),
})

local speedAdvice = autoSection:AddLabel({
	Title = "Speed Advice",
	Content = "Reading your speed...",
	Icon = "gauge",
})

task.spawn(function()
	while fn2() do
		if type(v13.lowSpeedStatus) == "function" then
			pcall(function()
				local status = v13:lowSpeedStatus()
				local range = status.safe == status.fast and tostring(status.fast) or status.safe .. "\226\128\147" .. status.fast
				local text = ("Current Speed: %s (WS %d)\nRecommended Instant Steal Multiplier: %s  \194\183  yours: %d"):format(status.speedText, status.walkSpeed, range, status.level)
				local advice = status.advice

				if advice then
					text ..= ("\nSteals keep failing (%d of the last %d) - lower it to %d."):format(advice.fails, advice.total, advice.to)
					if advice.fresh then
						advice.fresh = false
						window:Notify("Low Speed User", ("Steals keep failing at %d - lower the multiplier to %d."):format(advice.from, advice.to), 6)
					end
				elseif status.level > status.fast then
					text ..= "\nAbove the recommendation - lower it if steals start failing."
				end

				speedAdvice:SetContent(text)
			end)
		end
		task.wait(2)
	end
end)

controls.hold = autoSection:AddSlider({
	Title = "Instant Steal Multiplier",
	Content = "For Instant Steal mode. Higher = faster grab, lower = safer.",
	Icon = "gauge",
	Min = 1,
	Max = 10,
	Increment = 1,
	Default = cfg.StealHoldSeconds,
	Callback = persist(Steal.setHoldSeconds),
})

controls.boost = optionsSection:AddToggle({
	Title = "Boost For Instant Steal",
	Content = "Faster Instant Steal on every area except Forest.",
	Icon = "sparkles",
	Default = cfg.LowSpeedBoost,
	Callback = persist(Steal.setLowSpeedBoost),
})

controls.helpFriend = optionsSection:AddToggle({
	Title = "Help Friend",
	Content = "Drop the egg at the safe line for a friend.",
	Icon = "users",
	Default = cfg.HelpFriend,
	Callback = persist(Steal.setHelpFriend),
})

------------------------------------------------------------ Tab: Egg Filter
local filterTab = window:AddTab("Filter", "filter")
local eggSection = filterTab:AddSection("Egg", "egg", 1)

controls.names = eggSection:AddDropdown({
	Title = "Egg Name",
	Content = "Empty = any egg.",
	Icon = "egg",
	Options = Options.eggNames(),
	Multi = true,
	Default = Steal.cleanList(cfg.StealNamesFilter),
	Callback = persist(function(value)
		Steal.setListFilter("names", value)
	end),
})

controls.rarities = eggSection:AddDropdown({
	Title = "Rarity",
	Content = "Empty = any rarity.",
	Icon = "gem",
	Options = Options.rarities(),
	Multi = true,
	Default = Steal.cleanList(cfg.StealRarities),
	Callback = persist(function(value)
		Steal.setListFilter("rarities", value)
	end),
})

controls.mutations = eggSection:AddDropdown({
	Title = "Mutation",
	Content = "Empty = any mutation.",
	Icon = "flask-conical",
	Options = Options.mutations(),
	Multi = true,
	Default = Steal.cleanList(cfg.StealMutations),
	Callback = persist(function(value)
		Steal.setListFilter("mutations", value)
	end),
})

controls.areas = eggSection:AddDropdown({
	Title = "Area",
	Content = "Empty = every area.",
	Icon = "map-pin",
	Options = Options.areas(),
	Multi = true,
	Default = Steal.cleanList(cfg.StealAreas),
	Callback = persist(function(value)
		Steal.setListFilter("areas", value)
	end),
})

local function formatValue(amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then
		return ""
	end
	for _, unit in ipairs({{1e9, "b"}, {1e6, "m"}, {1e3, "k"}}) do
		if amount >= unit[1] then
			local scaled = amount / unit[1]
			return (scaled == math.floor(scaled) and tostring(math.floor(scaled)) or tostring(scaled)) .. unit[2]
		end
	end
	return tostring(amount)
end

local valueSection = filterTab:AddSection("Value & Priority", "coins", 2)

controls.value = valueSection:AddInput({
	Title = "Min Value",
	Content = "Money per second (k, m, b).",
	Icon = "coins",
	Placeholder = "500k, 2m",
	Default = formatValue(cfg.StealMinValue),
	Callback = persist(Steal.setMinValue),
})

controls.weight = valueSection:AddInput({
	Title = "Min Weight",
	Content = "Kilograms. 0 = any weight.",
	Icon = "weight",
	Placeholder = "12000",
	Default = (cfg.StealMinWeight or 0) > 0 and tostring(cfg.StealMinWeight) or "",
	Callback = persist(Steal.setMinWeight),
})

controls.priority = valueSection:AddDropdown({
	Title = "Priority",
	Content = "Which egg first.",
	Icon = "arrow-up-down",
	Options = {"Rarity", "Highest Value", "Heaviest"},
	Multi = false,
	Default = cfg.StealPriority,
	Callback = persist(Steal.setPriority),
})

controls.autoIndex = valueSection:AddToggle({
	Title = "Auto Index",
	Content = "Also take pets missing from your Index.",
	Icon = "crown",
	Default = cfg.AutoIndex,
	Callback = persist(Steal.setAutoIndex),
})

local resetSection = filterTab:AddSection("Reset", "rotate-ccw", 2)
resetSection:AddButton({
	Title = "Clear Filters",
	Content = "Steal any available egg.",
	Icon = "rotate-ccw",
	Label = "Clear",
	Callback = function()
		Steal.clearFilters()
		controls.names:Set({}, true)
		controls.rarities:Set({}, true)
		controls.areas:Set({}, true)
		controls.mutations:Set({}, true)
		controls.value:Set("", true)
		controls.weight:Set("", true)
		controls.priority:Set("Rarity", true)
		queueSave()
		window:Notify("Egg Filter", "All filters cleared", 2)
	end,
})

------------------------------------------------------------ Tab: Order
-- Setiap fitur (Steal, Butterfly, Shooting Star, Phantom Express, Halloween Eggs,
-- Pumpkin Moon, Auto Farm Monsters, Ghost Dog, Fishing) punya kotak angka urutan + status.
-- Barisnya dibuat oleh Events add-on (ladder.orderList), karena fiturnya ada di sana.
xpcall(function()
	local ladder = fanKunHubTaskLadder
	local orderTab = window:AddTab("Order", "list-ordered")
	local listSection = orderTab:AddSection("Feature Order", "arrow-up-down", 1)
	local infoSection = orderTab:AddSection("How it works", "target", 2)
	local orderResetSection = orderTab:AddSection("Reset", "rotate-ccw", 2)

	infoSection:AddLabel({
		Title = "Type a number to set the order",
		Content = "1 runs first, 2 next, and so on. Leave a box empty to use the default order (it goes after the numbered ones). Status: [RUN] working, [WAIT] waiting for a higher one, [IDLE] on but nothing to do, [OFF] switched off.",
		Icon = "target",
	})

	orderResetSection:AddButton({
		Title = "Reset Order",
		Content = "Back to the default order.",
		Icon = "rotate-ccw",
		Label = "Reset",
		Callback = function()
			fanKunHubConfig.TaskNumbers = {}
			queueSave()
			if type(ladder.orderReset) == "function" then
				pcall(ladder.orderReset)
			end
			window:Notify("Task Order", "Task order reset", 2)
		end,
	})

	ladder.orderList = listSection
end, function(err)
	warn("[FanKunHUB] Order tab failed: " .. tostring(err))
end)

------------------------------------------------------------ Tab: Anti AFK
local afkTab = window:AddTab("Anti AFK", "activity")
local afkSection = afkTab:AddSection("Anti AFK", "activity", 1)

controls.afkTreadmill = afkSection:AddToggle({
	Title = "Auto Treadmill",
	Content = "Climb the treadmill automatically; jump off when another task runs.",
	Icon = "gauge",
	Default = cfg.AntiAfkTreadmill == true,
	Callback = persist(function(value)
		cfg.AntiAfkTreadmill = value == true
		local m = genv.__FanKunHUBTreadmillManager
		if m then
			m:setIdleFarm(value == true)
		end
	end),
})

controls.afkJump = afkSection:AddToggle({
	Title = "Auto Jump (20s)",
	Content = "Jump once every 20 seconds.",
	Icon = "zap",
	Default = cfg.AntiAfkJump == true,
	Callback = persist(function(value)
		cfg.AntiAfkJump = value == true
	end),
})

-- Terapkan state tersimpan (Default tidak memicu Callback)
if cfg.AntiAfkTreadmill == true then
	local m = genv.__FanKunHUBTreadmillManager
	if m then
		pcall(m.setIdleFarm, m, true)
	end
end

-- Loop lompat tiap 20 detik + turun dari treadmill saat task lain aktif
task.spawn(function()
	local lastJump = os.clock()
	while fn2() do
		task.wait(1)
		local m = genv.__FanKunHUBTreadmillManager
		if cfg.AntiAfkTreadmill == true and m and not m.destroyed and m.activeTreadmill ~= nil then
			local okHold, holder = pcall(fanKunHubTaskLadder.holder, "treadmill")
			if okHold and holder ~= nil then
				pcall(m._requestUnequip, m)
			end
		end
		if cfg.AntiAfkJump == true then
			if os.clock() - lastJump >= 20 then
				lastJump = os.clock()
				local char = localPlayer.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					pcall(function()
						hum:ChangeState(Enum.HumanoidStateType.Jumping)
					end)
				end
			end
		else
			lastJump = os.clock()
		end
	end
end)

------------------------------------------------------------ Tab: Settings
local settingsTab = window:AddTab("Settings", "settings")
local moveSection = settingsTab:AddSection("Movement", "gauge", 1)

controls.speed = moveSection:AddSlider({
	Title = "Move Speed",
	Content = "Lower it if steals start failing.",
	Icon = "gauge",
	Min = 50,
	Max = 100,
	Increment = 1,
	Default = cfg.TweenSpeedMultiplier,
	Callback = persist(Steal.setSpeed),
})

local languageSection = settingsTab:AddSection("Language", "languages", 1)

controls.language = languageSection:AddDropdown({
	Title = "Language",
	Content = "Interface language.",
	Icon = "languages",
	Options = {"English", "Indonesia"},
	Multi = false,
	Default = cfg.Language,
	Callback = persist(function(value)
		cfg.Language = value == "English" and "English" or "Indonesia"
		UI.setLanguage(cfg.Language)
	end),
})

local configSection = settingsTab:AddSection("Config", "save", 2)
configSection:AddButton({
	Title = "Save Config",
	Content = Storage.available() and "Also saved automatically." or "No file access: resets every run.",
	Icon = "save",
	Label = "Save",
	Callback = function()
		local ok = Storage.save()
		window:Notify("Config", ok and "Saved" or "Save failed (no file access)", 2)
	end,
})

configSection:AddButton({
	Title = "Unload",
	Content = "Stop Auto Steal and remove the UI.",
	Icon = "power",
	Label = "Unload",
	Danger = true,
	Callback = unload,
})

local formatModule
local function fmtCompact(amount)
	amount = tonumber(amount) or 0
	if formatModule == nil then
		local ok, result = pcall(require, ReplicatedStorage.Packages.FormatNumber.Simple)
		formatModule = (ok and type(result) == "table" and type(result.FormatCompact) == "function") and result or false
	end
	if formatModule then
		local ok, text = pcall(formatModule.FormatCompact, amount, ".#")
		if ok and type(text) == "string" then
			return text
		end
	end
	local size = math.abs(amount)
	if size >= 1e12 then
		return string.format("%.2fT", amount / 1e12)
	elseif size >= 1e9 then
		return string.format("%.2fB", amount / 1e9)
	elseif size >= 1e6 then
		return string.format("%.1fM", amount / 1e6)
	elseif size >= 1e3 then
		return string.format("%.1fK", amount / 1e3)
	end
	return tostring(math.floor(amount + 0.5))
end

local function fmtKg(kg)
	if type(kg) ~= "number" then
		return "-- Kg"
	end
	if kg >= 1e6 then
		return fmtCompact(kg) .. " Kg"
	end
	local digits = tostring(math.floor(kg + 0.5))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	grouped = grouped:gsub("^,", "")
	return grouped .. " Kg"
end

local assetEarnings
local function eggValue(record)
	if type(record) ~= "table" then
		return nil
	end
	if assetEarnings == nil then
		local ok, result = pcall(require, ReplicatedStorage.Shared.Util.AssetEarnings)
		assetEarnings = ok and result or false
	end
	if not assetEarnings then
		return nil
	end
	local category = record.AssetCategory
	local scale = tonumber(record.AssetScale)
	if type(category) ~= "string" or not scale or scale <= 0 then
		return nil
	end
	local ok, value = pcall(assetEarnings.MutationOnlyRatePerSecond, {
		Category = category,
		Scale = scale,
		Mutations = type(record.Mutations) == "table" and table.clone(record.Mutations) or {},
		BaseMutation = type(record.BaseMutation) == "string" and record.BaseMutation or nil,
	})
	return ok and type(value) == "number" and value or nil
end

-- target yang sedang diincar / dibawa (bukan egg "primer" milik Instant Steal)
local lastRecord, lastRecordAt = nil, 0
local function currentRecord()
	local uid
	local carry = v13.carry

	if carry and carry.active and carry.uid and not v13:_isPrimerEgg(carry.uid) then
		uid = carry.uid
	end
	uid = uid or v13.targetUid

	local record = uid and (EggState.ReadFieldEgg(uid) or v13.records[uid]) or nil
	if not record then
		local active = v13.activeTarget
		if type(active) == "table" and active.Uid and not v13:_isPrimerEgg(active.Uid) then
			record = active
		end
	end

	if record then
		lastRecord, lastRecordAt = record, os.clock()
		return record
	end
	if lastRecord and os.clock() - lastRecordAt < 4 then
		return lastRecord
	end
	return nil
end

local lastAlpha = 0

local function computeProgress(stats)
	local status = tostring(stats.status or "")
	local result = tostring(stats.lastResult or "")

	if not v13.enabled then
		return 0, "Auto Steal off"
	end
	if status == "Searching" or status:find("No matching") or status:find("Waiting for reset") or status:find("hand over") or status:find("^Waiting \194\183") or status:find("Yielding") or status == "Idle" or status == "Ready" then
		return 0, status ~= "" and status or "Searching"
	end
	if status:find("Preparing") then
		return 0.08, "Preparing steal"
	end
	if status:find("Heading") or status:find("Returning to egg") or status:find("Re%-approaching") then
		return 0.2, "Heading to target egg"
	end
	local hold = status:match("Securing target egg %(([%d%.]+)s%)")
	if hold then
		local total = math.max(tonumber(fanKunHubConfig.StealHoldSeconds) or 5, 1)
		local remain = tonumber(hold) or 0
		return 0.25 + 0.4 * math.clamp(1 - remain / (total * 2), 0, 1), string.format("Securing egg  \194\183  %.1fs left", remain)
	end
	if status:find("Securing") or status:find("Waiting for carry") or status:find("Confirming") then
		return 0.65, "Confirming carry"
	end
	if status:find("Carry confirmed") then
		return 0.72, "Carry confirmed"
	end
	if status:find("Bringing egg home") or status:find("Taking the egg") or status:find("Returning to safe") then
		return 0.85, "Bringing egg home"
	end
	if status:find("Waiting for deposit") or status:find("Validating") or status:find("Deposit pending") then
		return 0.95, "Depositing egg"
	end
	if result == "Safe return complete" and not v13.running then
		return 1, "Steal complete"
	end
	return lastAlpha, status
end

task.spawn(function()
	while fn2() do
		pcall(function()
			local engineBusy = v13.enabled == true and (v13.running or v13._instantReturnToken ~= nil
				or (v13.carry and v13.carry.active) or v13.activeTween ~= nil)

			-- Activity pill = aktivitas terakhir yang direkam (bukan status toggle).
			-- Steal: catat saat egg berhasil dibawa / diamankan.
			local resNow = tostring(v13.stats and v13.stats.lastResult or "")
			if resNow ~= v13._actLastResult then
				v13._actLastResult = resNow
				if resNow == "Carry confirmed" or resNow == "Safe return complete" then
					local nm
					if lastRecord then
						local okInfo, inf = pcall(v6.resolve, lastRecord)
						if okInfo and inf then
							nm = tostring(inf.name) .. (inf.rarity and (" [" .. tostring(inf.rarity) .. "]") or "")
						end
					end
					pcall(window.AddActivityLog, window, "steal",
						(resNow == "Carry confirmed" and "Egg diambil: " or "Egg aman di base: ") .. (nm or tostring(v13.stats and v13.stats.lastTarget or "?")),
						resNow == "Safe return complete" and 1 or 0)
				end
			end

			local activity, activityActive = "Idle", false
			if window.RunningActivity then
				activity, activityActive = window.RunningActivity, true
			elseif type(window.GetLatestActivity) == "function" then
				local latestText, age = window:GetLatestActivity()
				if latestText and age < 4 then
					activity, activityActive = latestText, true
				end
			end
			window:SetActivity(activity, activityActive)

			local record = engineBusy and currentRecord() or nil
			local wantHud = engineBusy and record ~= nil
			hud:SetVisible(wantHud)
			if not wantHud then
				lastAlpha = 0
				lastRecord = nil
				return
			end

			local alpha, statusText = computeProgress(v13.stats or {})
			-- progres tidak mundur di tengah steal
			if alpha > 0 and alpha < lastAlpha and v13.running then
				alpha = lastAlpha
			end
			lastAlpha = alpha

			local data = {status = statusText, alpha = alpha}

			if record then
				local info = v6.resolve(record)
				data.name = info.name
				data.rarity = info.rarity
				data.color = info.rarityColor
				data.icon = info.icon
				data.kg = fmtKg(v13:_resolveWeightKg(record))
				local value = eggValue(record)
				data.price = value and ("$" .. fmtCompact(value) .. "/s") or "--"
			end

			hud:Update(data)
		end)
		task.wait(0.25)
	end
end)



------------------------------------------------------------------------
-- EVENTS ADD-ON
-- Logic diambil dari ci.lua: Halloween Dimension, Halloween Monsters,
-- Ghost Dog + Fishing, Phantom Express, Shooting Star, Butterfly Bloom.
-- Bagian di bawah ini adalah "jembatan" supaya modul ci.lua bisa
-- jalan di FanKunHUB (HubState / GameModules / UI adapter).
------------------------------------------------------------------------
local function installEventsAddon()
	local ladder = fanKunHubTaskLadder
	local PlayersService = Players
	local ReplicatedStorageService = ReplicatedStorage
	local LocalPlayerRef = localPlayer
	local ReturnHomeSpeed = 400

	local function alive()
		return genv.__FanKunHUBHubSession == fanKunHubHubSession
	end

	-- cleanup
	local addonCleanups = {}
	local function RegisterCleanup(callback)
		if not alive() then
			pcall(callback)
			return
		end
		addonCleanups[#addonCleanups + 1] = callback
	end

	local RunServiceRef = setmetatable({
		FanKunDead = function()
			return not alive()
		end,
	}, {
		__index = function(_, key)
			return RunService[key]
		end,
	})

	local NetworkingPackage
	do
		local packages = ReplicatedStorage:FindFirstChild("Packages") or ReplicatedStorage:WaitForChild("Packages", 10)
		NetworkingPackage = packages and (packages:FindFirstChild("Networking") or packages:WaitForChild("Networking", 10))
		NetworkingPackage = NetworkingPackage or Instance.new("Folder")
	end

	-- GameModules (require modul game)
	local function findPath(...)
		local node = ReplicatedStorage
		for _, name in ipairs({...}) do
			node = node and node:FindFirstChild(name)
		end
		return node
	end

	local function safeRequire(...)
		local path = {...}
		local ok, result = pcall(function()
			return require(findPath(table.unpack(path)))
		end)
		return ok and result or nil
	end

	local GameModules = {
		EggState = safeRequire("Client", "EggState"),
		AreaEggs = safeRequire("Shared", "Types", "AreaEggs"),
		Assets = safeRequire("Data", "Assets"),
		Guards = safeRequire("Data", "Guards"),
		EggRecords = safeRequire("Shared", "Util", "EggRecords"),
		Mutations = safeRequire("Shared", "Modules", "Mutations"),
		AreaEggCycle = safeRequire("Shared", "Util", "AreaEggCycle"),
		AreaEggResetWall = safeRequire("Client", "AreaEggResetWall"),
		AreaEggResetCycle = safeRequire("Data", "AreaEggResetCycle"),
		Gears = safeRequire("Data", "Gears"),
		Areas = safeRequire("Data", "Areas"),
		LimitedEgg = safeRequire("Data", "LimitedEgg"),
		BrainrotEgg = safeRequire("Data", "BrainrotEgg"),
		MonsterEgg = safeRequire("Data", "MonsterEgg"),
	}

	do
		local save = safeRequire("Shared", "Save")
		if type(save) == "table" then
			if type(save.Get) ~= "function" and type(save.Peek) == "function" then
				local raw = save
				save = setmetatable({Get = function(...)
					return raw.Peek(...)
				end}, {__index = raw})
			end
			if type(save.Get) ~= "function" or type(save.FieldSignal) ~= "function" then
				local raw = save
				save = setmetatable({
					Get = type(raw.Get) == "function" and raw.Get or raw.Peek,
					FieldSignal = type(raw.FieldSignal) == "function" and raw.FieldSignal or raw.Watch,
				}, {__index = raw})
			end
		end
		GameModules.Save = save
	end

	local function currentChar()
		return localPlayer.Character
	end

	-- HubState (versi ringan dari ci.lua, disesuaikan ke FanKunHUB)
	local HubState = {
		ConfigSettleUntil = 0,
		Movement = {Owner = nil, OwnerAt = 0},
		MovementWaiting = {},
		Treadmill = {Riding = false},
		SafeCarry = {HopLift = 42, HopGap = 0.1, HopRatio = 1.515, V2DirectRadius = 69},
		AdminAbuse = {OnAdmin = false},
		Flying = false,
		Driving = 0,
		TravelCarryUntil = 0,
	}

	-- Jembatan log aktivitas: dipakai modul Butterfly / Halloween / Star lewat HubState.LogActivity
	HubState.LogActivity = function(cat, text, amount, throttle)
		if window and type(window.AddActivityLog) == "function" then
			pcall(window.AddActivityLog, window, cat, text, amount, throttle)
		end
	end

	HubState.Steal = setmetatable({}, {
		__index = function(_, key)
			if key == "Carrying" then
				return ladder.stealCarrying() == true
			elseif key == "Active" then
				return ladder.active("auto_steal") == true
			elseif key == "Wanted" then
				return ladder.wants("auto_steal") == true
			end
			return nil
		end,
	})

	HubState.Root = function()
		local character = currentChar()
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return root and root:IsDescendantOf(workspace) and root or nil
	end

	HubState.WalkSpeed = function()
		local character = currentChar()
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		return humanoid and humanoid.WalkSpeed or 16
	end

	HubState.IsNight = function()
		local cycle = GameModules.AreaEggCycle
		if type(cycle) ~= "table" or type(cycle.IsNightPhase) ~= "function" then
			return false
		end
		local ok, result = pcall(cycle.IsNightPhase, workspace:GetServerTimeNow())
		return ok and result == true
	end

	HubState.WallSealed = function()
		local wall = GameModules.AreaEggResetWall
		if type(wall) ~= "table" or type(wall.IsSealed) ~= "function" then
			return false
		end
		local ok, result = pcall(wall.IsSealed)
		return ok and result == true
	end

	-- PATCH Auto Farm Monsters: ci.lua mendefinisikan HubState.IsBatTool dan
	-- HubState.Combat.PickBat, di FanKunHUB keduanya tidak ada. Akibatnya modul
	-- monster selalu menganggap "tidak punya bat", lalu kabur ke safe zone.
	HubState.IsBatTool = HubState.IsBatTool or function(tool)
		if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
			return false
		end
		local env = (getgenv and getgenv()) or _G
		local external = env.__FanKunHUBIsBatTool
		if type(external) == "function" then
			local ok, result = pcall(external, tool)
			if ok and result == true then
				return true
			end
		end
		if tool:GetAttribute("IsBat") == true or tool:GetAttribute("GearName") == "Bat" then
			return true
		end
		local name = string.lower(tostring(tool:GetAttribute("GearName") or tool.Name))
		return string.find(name, "bat", 1, true) ~= nil
	end

	HubState.Combat = HubState.Combat or {}
	HubState.Combat.PickBat = HubState.Combat.PickBat or function(character)
		if not character then
			return nil
		end
		local backpack = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("Backpack")
		local holders = {character, backpack}
		local function isScrambler(tool)
			return string.find(string.lower(tostring(tool:GetAttribute("GearName") or tool.Name)), "scrambler", 1, true) ~= nil
		end
		-- 1) bat yang sedang dipegang, 2) bat di backpack, 3) senjata lain (Katana dst)
		for _, holder in ipairs(holders) do
			for _, tool in ipairs(holder and holder:GetChildren() or {}) do
				if tool:IsA("Tool") and HubState.IsBatTool(tool) then
					return tool
				end
			end
		end
		for _, holder in ipairs(holders) do
			for _, tool in ipairs(holder and holder:GetChildren() or {}) do
				if tool:IsA("Tool") and tostring(tool:GetAttribute("ItemType")) == "Gear" and not isScrambler(tool) then
					return tool
				end
			end
		end
		return nil
	end

	HubState.WallOpenDelay = function()
		local cycle = GameModules.AreaEggResetCycle
		if type(cycle) ~= "table" then
			return 5
		end
		return (tonumber(cycle.WallCountdownDelayAfterDayStartsSeconds) or 2) + (tonumber(cycle.WallCountdownSeconds) or 3)
	end

	HubState.InsideBase = function(position)
		if not position then
			local root = HubState.Root()
			position = root and root.Position
		end
		if position == nil then
			return false
		end
		local world = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
		local areas = world and world:FindFirstChild("Areas")
		local line = areas and areas:FindFirstChild("SeparationLine")
		return (line and line:IsA("BasePart") and line.Position.X or 552) > position.X
	end

	-- Sama seperti ci.lua: "menapak" hanya bila state Running / RunningNoPhysics / Landed.
	-- (versi lama memakai daftar hitam, jadi Humanoid Swap bisa jalan saat karakter masih melayang)
	local landedStates = {
		[Enum.HumanoidStateType.Running] = true,
		[Enum.HumanoidStateType.RunningNoPhysics] = true,
		[Enum.HumanoidStateType.Landed] = true,
	}
	HubState.Grounded = function(humanoid)
		if not humanoid then
			local character = currentChar()
			humanoid = character and character:FindFirstChildOfClass("Humanoid")
		end
		if not humanoid or humanoid.Health <= 0 or humanoid.FloorMaterial == Enum.Material.Air then
			return false
		end
		return landedStates[humanoid:GetState()] == true
	end

	HubState.BeginFlight = function()
		HubState.Flying = true
		local character = currentChar()
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = true
			pcall(function()
				humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			end)
		end
		return HubState.Root() ~= nil
	end

	HubState.SetFlightVelocity = function(velocity)
		local root = HubState.Root()
		if root then
			root.AssemblyLinearVelocity = velocity
			root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end
	end

	HubState.EndFlight = function()
		HubState.Flying = false
		local root = HubState.Root()
		if root then
			pcall(function()
				root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			end)
		end
		local character = currentChar()
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = false
		end
	end

	-- Terbang jarak jauh (portal Halloween, Phantom Express, Ghouler Boss, dst).
	-- Disamakan dengan ci.lua: naik dulu, terbang mendatar di ketinggian aman, lalu turun,
	-- dibungkus Shield + Driving. Versi lama terbang lurus dengan PlatformStand/Freefall,
	-- menembus map dan tidak punya Shield, sehingga karakter bisa mati saat berpindah target.
	do
		local CRUISE_CLEARANCE = 40

		local function separationX()
			local world = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
			local areas = world and world:FindFirstChild("Areas")
			local line = areas and areas:FindFirstChild("SeparationLine")
			return line and line:IsA("BasePart") and line.Position.X or 552
		end

		-- kalau tujuan ada di sisi base yang berbeda, mampir ke StealHome dulu (seperti ci.lua)
		local function homeWaypoint(root, target)
			local line = separationX()
			if (root.Position.X < line) == (target.X < line) then
				return nil
			end
			local ok, home = pcall(HubState.StealHome)
			if not ok or typeof(home) ~= "Vector3" then
				return nil
			end
			if (home - target).Magnitude <= 12 or (root.Position - home).Magnitude <= 12 then
				return nil
			end
			return home
		end

		local function moveTo(goal, shouldStop)
			local root = HubState.Root()
			if not root then
				return false
			end
			local position = root.Position
			local budget = (goal - position).Magnitude / math.max(ReturnHomeSpeed, 1) + 3
			local spent = 0
			local result = nil
			local connection = RunService.Heartbeat:Connect(function(dt)
				if result ~= nil then
					return
				end
				spent += dt
				local current = HubState.Root()
				if not current or not alive() or (shouldStop and shouldStop()) or spent > budget then
					result = false
					return
				end
				if (current.Position - position).Magnitude > 6 then
					position = current.Position
				end
				local delta = goal - position
				local stepLength = ReturnHomeSpeed * dt
				local arrived = delta.Magnitude <= math.max(stepLength, 0.05)
				position = arrived and goal or position + delta.Unit * stepLength
				local flat = Vector3.new(delta.X, 0, delta.Z)
				local rotation = flat.Magnitude > 0.05 and CFrame.lookAt(Vector3.new(0, 0, 0), flat.Unit) or current.CFrame.Rotation
				pcall(function()
					current.CFrame = CFrame.new(position) * rotation
					current.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					current.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
				end)
				if arrived then
					result = true
				end
			end)
			while result == nil do
				RunService.Heartbeat:Wait()
			end
			connection:Disconnect()
			return result
		end

		local function flyLeg(target, shouldStop, label, skipWaypoint)
			local root = HubState.Root()
			if not root or typeof(target) ~= "Vector3" then
				return false
			end
			if not skipWaypoint then
				local via = homeWaypoint(root, target)
				if via and not flyLeg(via, shouldStop, label, true) then
					return false
				end
			end
			if shouldStop and shouldStop() then
				return false
			end
			root = HubState.Root()
			if not root then
				return false
			end
			local reason = label or "fly"
			HubState.Shield(reason, true)
			HubState.Driving = HubState.Driving + 1
			task.wait(0.2)
			local goal = target + Vector3.new(0, 3, 0)
			local cruise = math.max(root.Position.Y, goal.Y) + CRUISE_CLEARANCE
			local ok, done = pcall(function()
				return moveTo(Vector3.new(root.Position.X, cruise, root.Position.Z), shouldStop)
					and moveTo(Vector3.new(goal.X, cruise, goal.Z), shouldStop)
					and moveTo(goal, shouldStop)
			end)
			HubState.Driving = math.max(0, HubState.Driving - 1)
			HubState.Shield(reason, false)
			return ok and done == true
		end

		HubState.FlyTo = function(target, shouldStop, label)
			return flyLeg(target, shouldStop, label, false)
		end
	end

	-- treadmill / belt: FanKunHUB mengatur treadmill sendiri lewat task ladder
	HubState.OnBelt = function()
		local m = genv.__FanKunHUBTreadmillManager
		return m ~= nil and m.activeTreadmill ~= nil
	end
	HubState.ExitBelt = function()
		local m = genv.__FanKunHUBTreadmillManager
		if m then
			pcall(m._requestUnequip, m)
		end
	end
	HubState.HoldBelt = function() end
	HubState.ReleaseBelt = function() end
	HubState.StealPanelSync = function() end
	HubState.ButterflyYield = function()
		return nil
	end
	HubState.StarOver = function()
		return false
	end
	HubState.ButterflyOver = function()
		return false
	end

	-- ===== Helper tambahan dari ci.lua (sebelumnya tidak terbawa) =====
	HubState.GodMode = function() end -- God Mode FanKunHUB dikelola terpisah (genv.__FanKunHUBGodMode)
	HubState.GodTick = function() end

	-- StealHome: titik "rumah" Auto Steal (dari ci.lua)
	do
		local homePoints = {
			{Path = {"GearGiver_Slap", "Podium"}, Offset = Vector3.new(-16.415, 21.072, -6.106)},
			{Path = {"World", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003"}, Offset = Vector3.new(-26.776, 1.75, 18.665)},
			{Path = {"__OBJECTS", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003"}, Offset = Vector3.new(-26.776, 1.75, 18.665)},
		}
		local homeFallback = Vector3.new(528.7, 70.57, -364.11)
		HubState.StealHome = function()
			for _, point in ipairs(homePoints) do
				local node = workspace
				for _, name in ipairs(point.Path) do
					node = node and node:FindFirstChild(name) or nil
				end
				if node and node:IsA("BasePart") then
					return node.CFrame:PointToWorldSpace(point.Offset)
				end
			end
			return homeFallback
		end
	end

	-- Priority + RaceRank: ci.lua memakai tabel Priority; di FanKunHUB urutannya
	-- diambil dari Task Order (ladder) supaya modul event bisa membaca ranking.
	do
		local rankTask = {
			StealTop = "auto_steal", StealFilter = "auto_steal", StealWisp = "auto_steal",
			Place = "auto_place", Treadmill = "treadmill", Essence = "use_scrambled",
			Butterfly = "butterfly", Star = "star", Train = "train",
			HwPumpkin = "halloween", HwDog = "halloween", HwM = "halloween", Halloween = "halloween",
			HwMonsters = "halloween", HwFishing = "halloween",
		}
		local nameTask = {
			steal = "auto_steal", place = "auto_place", treadmill = "treadmill", wisp = "auto_steal",
			banjo = "auto_steal", essence = "use_scrambled", butterfly = "butterfly", star = "star",
			train = "train", halloween = "halloween",
		}
		local function rankOf(task)
			for index, name in ipairs(ladder.order()) do
				if name == task then
					return index
				end
			end
			return 99
		end
		HubState.Priority = {
			Labels = ladder.TITLES,
			Rank = setmetatable({}, {
				__index = function(_, key)
					if type(ladder.rankFor) == "function" then
						local entryRank = ladder.rankFor(key)
						if entryRank then
							return entryRank
						end
					end
					local task = rankTask[key]
					return task and rankOf(task) or 99
				end,
			}),
			StealTop = function()
				if type(ladder.rankFor) == "function" then
					local entryRank = ladder.rankFor("StealTop")
					if entryRank then
						return entryRank
					end
				end
				return rankOf("auto_steal")
			end,
			TreadmillOver = function()
				return false
			end,
		}
		HubState.RaceRank = function(name)
			if name == nil then
				return nil
			end
			if name == "capture" then
				return 0
			end
			if name == "halloween" and type(HubState.HalloweenRank) == "function" then
				return HubState.HalloweenRank()
			end
			if type(ladder.rankFor) == "function" then
				local rankKey = ({steal = "StealTop", butterfly = "Butterfly", star = "Star", train = "Train"})[name]
				local entryRank = rankKey and ladder.rankFor(rankKey)
				if entryRank then
					return entryRank
				end
			end
			local task = nameTask[name]
			return task and rankOf(task) or 99
		end
	end

	HubState.Notify = function(title, body)
		pcall(function()
			window:Notify(tostring(title), tostring(body), 5)
		end)
	end

	HubState.ShowRow = function(handle, text)
		if type(handle) ~= "table" or type(handle.Set) ~= "function" then
			return
		end
		text = tostring(text)
		if rawget(handle, "__last") == text then
			return
		end
		rawset(handle, "__last", text)
		pcall(handle.Set, handle, text)
	end

	HubState.Toggle = function(handle, default)
		if not alive() then
			return false
		end
		if type(handle) ~= "table" then
			return default == true
		end
		local ok, value = pcall(function()
			return handle:Get()
		end)
		if ok and type(value) == "boolean" then
			return value
		end
		return default == true
	end

	------------------------------------------------------------------
	-- SHIELD (port dari ci.lua)
	-- Dulu HubState.Shield / UndoSwap / Swapped di FanKunHUB kosong. Akibatnya Phantom Express
	-- dan Auto Vacuum Ghouler Boss berjalan TANPA perlindungan: karakter terbang lalu mati
	-- saat pindah target. Di ci.lua perlindungan ini selalu aktif.
	--   "Humanoid Swap"   : Humanoid asli dilepas, diganti klon di karakter yang sama.
	--   "Disable Monitor" : mematikan koneksi monitor anti-cheat (script "UGI").
	------------------------------------------------------------------
	xpcall(function()
		local METHODS = {"Humanoid Swap", "Disable Monitor"}
		HubState.ShieldMethods = METHODS
		HubState.ShieldPaused = false

		local method = METHODS[1]
		local reasons = {}
		local monitorDisabled = {}
		local heartbeatConnection, characterAddedConnection
		local elapsed = 0
		local undoToken = 0
		local swap = {Original = nil, Clone = nil, Links = {}, RigAt = 0, BodyAt = 0, Gate = false}
		local listeners = {}

		local function disconnectAll(list)
			for _, connection in ipairs(list) do
				pcall(function()
					connection:Disconnect()
				end)
			end
			table.clear(list)
		end

		-- lacak apakah karakter lama mati atau hanya diganti oleh game (RigSync)
		do
			local died, removedAlive = false, false
			local diedLinks, baseLinks = {}, {}
			local function track(character)
				disconnectAll(diedLinks)
				died = false
				if not character then
					return
				end
				local function watch(child)
					if child:IsA("Humanoid") then
						table.insert(diedLinks, child.Died:Connect(function()
							died = true
						end))
					end
				end
				for _, child in ipairs(character:GetChildren()) do
					watch(child)
				end
				table.insert(diedLinks, character.ChildAdded:Connect(watch))
			end
			table.insert(baseLinks, LocalPlayerRef.CharacterRemoving:Connect(function()
				removedAlive = not died
			end))
			table.insert(baseLinks, LocalPlayerRef.CharacterAdded:Connect(function(character)
				track(character)
				swap.Gate = removedAlive
				swap.BodyAt = os.clock()
				removedAlive = false
			end))
			local refresh = NetworkingPackage:FindFirstChild("RE/RigSync/Refresh")
			if refresh and refresh:IsA("RemoteEvent") then
				table.insert(baseLinks, refresh.OnClientEvent:Connect(function()
					swap.RigAt = os.clock()
				end))
			end
			track(LocalPlayerRef.Character)
			RegisterCleanup(function()
				disconnectAll(baseLinks)
				disconnectAll(diedLinks)
			end)
		end

		HubState.OnHumanoidChanged = function(callback)
			table.insert(listeners, callback)
			local handle
			handle = {
				Connected = true,
				Disconnect = function()
					handle.Connected = false
					local index = table.find(listeners, callback)
					if index then
						table.remove(listeners, index)
					end
				end,
			}
			return handle
		end

		local function fireChanged()
			for _, callback in ipairs(listeners) do
				task.defer(function()
					pcall(callback)
				end)
			end
		end

		local function bindControls(humanoid)
			pcall(function()
				local scripts = LocalPlayerRef:FindFirstChild("PlayerScripts")
				local module = scripts and scripts:FindFirstChild("PlayerModule")
				if module then
					local controls = require(module):GetControls()
					if type(controls) == "table" then
						controls.humanoid = humanoid
					end
				end
			end)
		end

		local function kickAnimate(character)
			local animate = character and character:FindFirstChild("Animate")
			if animate and animate:IsA("LocalScript") then
				task.spawn(function()
					animate.Enabled = false
					task.wait()
					animate.Enabled = true
				end)
			end
		end

		local function clearLinks()
			disconnectAll(swap.Links)
		end

		local function undoSwap()
			clearLinks()
			local character = LocalPlayerRef.Character
			local original, clone = swap.Original, swap.Clone
			swap.Original = nil
			swap.Clone = nil
			if original and clone and character and original.Parent == nil and clone.Parent == character then
				original.Parent = character
				workspace.CurrentCamera.CameraSubject = original
				bindControls(original)
				pcall(function()
					clone:Destroy()
				end)
				kickAnimate(character)
				fireChanged()
			end
		end
		HubState.UndoSwap = undoSwap

		local function swapIn()
			local character = LocalPlayerRef.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				return
			end
			if swap.Clone and swap.Clone.Parent == character then
				return
			end
			if not HubState.Grounded(humanoid) then
				return
			end
			if swap.Gate then
				if humanoid:GetState() == Enum.HumanoidStateType.Landed then
					return
				end
				if swap.RigAt < swap.BodyAt and os.clock() - swap.BodyAt < 4 then
					return
				end
				swap.Gate = false
			end

			local clone = humanoid:Clone()
			humanoid.Parent = nil
			clone.Parent = character
			workspace.CurrentCamera.CameraSubject = clone
			bindControls(clone)
			kickAnimate(character)
			swap.Original = humanoid
			swap.Clone = clone
			fireChanged()

			table.insert(swap.Links, humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
				if clone.Parent ~= nil then
					clone.WalkSpeed = humanoid.WalkSpeed
				end
			end))

			-- animasi dari Humanoid asli ditiru ke klon
			local originalAnimator = humanoid:FindFirstChildOfClass("Animator")
			local cloneAnimator = clone:FindFirstChildOfClass("Animator")
			if originalAnimator and cloneAnimator then
				table.insert(swap.Links, originalAnimator.AnimationPlayed:Connect(function(track)
					local animation = track.Animation
					if not animation or clone.Parent == nil then
						return
					end
					local loaded, mirror = pcall(function()
						return cloneAnimator:LoadAnimation(animation)
					end)
					if not loaded or not mirror then
						return
					end
					pcall(function()
						mirror.Priority = track.Priority
						mirror.Looped = track.Looped
						mirror:Play(0.05, math.max(track.WeightTarget, 0.01), track.Speed)
					end)
					local stopped
					stopped = track.Stopped:Connect(function()
						stopped:Disconnect()
						pcall(function()
							mirror:Stop(0.1)
						end)
					end)
				end))
			end

			-- klon mati = karakter benar-benar mati: kembalikan yang asli lalu matikan
			table.insert(swap.Links, clone.Died:Connect(function()
				clearLinks()
				swap.Original = nil
				swap.Clone = nil
				local current = LocalPlayerRef.Character
				if current and humanoid.Parent == nil then
					humanoid.Parent = current
					workspace.CurrentCamera.CameraSubject = humanoid
					bindControls(humanoid)
					fireChanged()
				end
				pcall(function()
					clone:Destroy()
				end)
				humanoid.Health = 0
			end))
		end

		local function disableMonitor()
			if type(getconnections) ~= "function" then
				return
			end
			for _, signal in ipairs({RunService.Heartbeat, RunService.PreSimulation, RunService.PostSimulation}) do
				local ok, connections = pcall(getconnections, signal)
				if ok and type(connections) == "table" then
					for _, connection in ipairs(connections) do
						local hasFunction, callback = pcall(function()
							return connection.Function
						end)
						if hasFunction and type(callback) == "function" then
							local hasSource, source = pcall(debug.info, callback, "s")
							if hasSource and string.find(tostring(source), "UGI", 1, true) then
								local hasEnabled, enabled = pcall(function()
									return connection.Enabled
								end)
								if (hasEnabled and enabled ~= false) or not hasEnabled then
									if pcall(function()
										connection:Disable()
									end) then
										table.insert(monitorDisabled, connection)
									end
								end
							end
						end
					end
				end
			end
		end

		local function enableMonitor()
			for _, connection in ipairs(monitorDisabled) do
				pcall(function()
					connection:Enable()
				end)
			end
			table.clear(monitorDisabled)
		end

		local function stopShield()
			if heartbeatConnection then
				heartbeatConnection:Disconnect()
				heartbeatConnection = nil
			end
			if characterAddedConnection then
				characterAddedConnection:Disconnect()
				characterAddedConnection = nil
			end
			enableMonitor()
		end

		local function tick()
			if HubState.ShieldPaused then
				return
			end
			if type(HubState.HalloweenRealHum) == "function" and HubState.HalloweenRealHum() then
				enableMonitor()
				pcall(undoSwap)
				return
			end
			if method == METHODS[1] then
				swapIn()
			else
				disableMonitor()
			end
		end

		local function startShield()
			tick()
			elapsed = 0
			heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
				elapsed += dt
				local character = LocalPlayerRef.Character
				local needSwap = method == METHODS[1] and not (swap.Clone and character and swap.Clone.Parent == character)
				if elapsed >= (needSwap and 0.25 or 3) then
					elapsed = 0
					tick()
				end
			end)
			characterAddedConnection = LocalPlayerRef.CharacterAdded:Connect(function(character)
				clearLinks()
				swap.Original = nil
				swap.Clone = nil
				if method ~= METHODS[1] then
					return
				end
				task.spawn(function()
					character:WaitForChild("Humanoid", 10)
					task.wait(1)
					if heartbeatConnection and LocalPlayerRef.Character == character then
						tick()
					end
				end)
			end)
		end

		HubState.Swapped = function()
			if method ~= METHODS[1] then
				return true
			end
			local character = LocalPlayerRef.Character
			return swap.Clone ~= nil and character ~= nil and swap.Clone.Parent == character
		end

		HubState.Shield = function(name, on)
			if not alive() then
				table.clear(reasons)
				return
			end
			local hadReasons = next(reasons) ~= nil
			reasons[name] = on == true or nil
			if next(reasons) == nil then
				if not hadReasons then
					return
				end
				stopShield()
				-- jangan langsung dilepas: tugas berikutnya (mis. train -> ghouler) biasanya
				-- segera menyusul, jadi Humanoid asli baru dikembalikan setelah jeda singkat
				undoToken += 1
				local token = undoToken
				task.delay(4, function()
					if token == undoToken and next(reasons) == nil then
						pcall(undoSwap)
					end
				end)
				return
			end
			undoToken += 1
			if heartbeatConnection then
				return
			end
			startShield()
		end

		HubState.SetShieldMethod = function(newMethod)
			if not table.find(METHODS, newMethod) or newMethod == method then
				return
			end
			local wasRunning = heartbeatConnection ~= nil
			stopShield()
			method = newMethod
			if wasRunning and next(reasons) ~= nil then
				startShield()
			end
		end

		-- saat Unload: lepas shield dan kembalikan Humanoid asli
		RegisterCleanup(function()
			table.clear(reasons)
			stopShield()
			pcall(undoSwap)
		end)
	end, function(err)
		warn("[FanKunHUB] Shield failed to load: " .. tostring(err))
		HubState.Shield = HubState.Shield or function() end
		HubState.UndoSwap = HubState.UndoSwap or function() end
		HubState.Swapped = HubState.Swapped or function()
			return false
		end
	end)

	-- koordinasi gerakan antar fitur event (sama seperti ci.lua, tanpa Priority UI)
	local eventNames = {star = true, butterfly = true, halloween = true, train = true}

	HubState.ClaimMovementBase = function(name)
		local movement = HubState.Movement
		local only = type(HubState.HalloweenOnly) == "function" and HubState.HalloweenOnly() or nil
		if only then
			local denied = name ~= only
				and not (only == "halloween" and name == "train" or only == "train" and name == "invisibility" or only == "halloween" and name == "invisibility")
				or name == "halloween" and movement.Owner == "train"
			if denied then
				HubState.MovementWaiting[name] = os.clock()
				return false
			end
			movement.Owner = name
			movement.OwnerAt = os.clock()
			HubState.MovementWaiting[name] = nil
			return true
		end
		-- Auto Steal / task ladder yang lebih tinggi jalan duluan
		if eventNames[name] and ladder.blocker(name) ~= nil then
			HubState.MovementWaiting[name] = os.clock()
			return false
		end
		if movement.Owner ~= nil and movement.Owner ~= name and os.clock() - (movement.OwnerAt or 0) > 4 then
			movement.Owner = nil
		end
		if movement.Owner == nil or movement.Owner == name then
			movement.Owner = name
			movement.OwnerAt = os.clock()
			HubState.MovementWaiting[name] = nil
			return true
		end
		HubState.MovementWaiting[name] = os.clock()
		return false
	end

	HubState.ReleaseMovementBase = function(name)
		if HubState.Movement.Owner == name then
			HubState.Movement.Owner = nil
		end
	end

	-- Phantom Express & Auto Vacuum Ghouler Boss wajib berjalan dengan Shield (seperti di ci.lua,
	-- di mana shield selalu aktif). Shield dipasang SEBELUM tugas mulai terbang dan dilepas saat
	-- gerakan dilepas. Kalau Humanoid Swap belum jadi, klaim ditahan maksimal ~2 detik.
	local shieldedMovers = {ghouler = true, train = true}
	local shieldWarmSince = {}

	HubState.ClaimMovement = function(name)
		local claimed = HubState.ClaimMovementBase(name)
		if not shieldedMovers[name] then
			return claimed
		end
		if not claimed then
			-- tidak kebagian gerak: jangan biarkan shield menggantung
			local since = shieldWarmSince[name]
			if since and os.clock() - since > 6 then
				shieldWarmSince[name] = nil
				HubState.Shield("mv_" .. name, false)
			end
			return false
		end
		-- Phantom Express harus bisa langsung mengambil movement lock dan menjalankan
		-- prosedur boarding. Shield tetap dinyalakan, tetapi jangan menahan boarding
		-- hanya karena Humanoid Swap belum selesai pada frame yang sama.
		HubState.Shield("mv_" .. name, true)
		if name == "train" then
			shieldWarmSince[name] = nil
			return true
		end
		if not HubState.Swapped() then
			shieldWarmSince[name] = shieldWarmSince[name] or os.clock()
			if os.clock() - shieldWarmSince[name] < 2 then
				-- fitur lain tetap menunggu shield seperti sebelumnya
				HubState.ReleaseMovementBase(name)
				HubState.MovementWaiting[name] = os.clock()
				return false
			end
		end
		shieldWarmSince[name] = nil
		return true
	end

	HubState.ReleaseMovement = function(name)
		if shieldedMovers[name] then
			shieldWarmSince[name] = nil
			HubState.Shield("mv_" .. name, false)
		end
		HubState.ReleaseMovementBase(name)
	end

	-- Auto Steal harus mengalah selama fitur event sedang memegang gerakan
	local originalBossFighting = ladder.bossFighting
	ladder.bossFighting = function()
		if originalBossFighting() then
			return true
		end
		local movement = HubState.Movement
		if movement.Owner ~= nil and eventNames[movement.Owner] and os.clock() - (movement.OwnerAt or 0) < 3 then
			return true
		end
		if type(HubState.HalloweenOnly) == "function" then
			local ok, only = pcall(HubState.HalloweenOnly)
			if ok and only ~= nil then
				return true
			end
		end
		return false
	end

	RegisterCleanup(function()
		ladder.bossFighting = originalBossFighting
	end)

	-- scheduler (diambil apa adanya dari ci.lua)
	local TaskScheduler = {}

local SetupTaskSchedulerModule = function()
    local F,o,N,t,i,k=0.35,5,6,{},true;
    local k= TaskScheduler;
    k.Add=function(k)
        local Y={Run=k,Gap=F,Idle=o,Repeat=false,Hold=0};
        table.insert(t,Y);
        return Y;
    end;
    local k= TaskScheduler;
    k.Wake=function()
        i=true;
    end;
    local k= TaskScheduler;
    k.Backoff=function(O,k)
        if O then O.Hold=tonumber(k)or N;
        end;
    end;
    local O,N=0;
    local N= RunServiceRef;
    local I=N.Heartbeat:Connect(function(k)
        local Y=#t;
        for z,z in ipairs(t)do z.Gap=z.Gap+k;
            z.Idle=z.Idle+k;
            z.Woke=z.Woke or i;
            if z.Hold>0 then z.Hold=z.Hold-k;
            end;
        end;
        i=false;
        k=0;
        for i=1,Y,1 do O=O%Y+1;
            i=t[O];
            if i.Hold<=0 and(i.Repeat and i.Gap>=F or i.Woke and i.Gap>=0.6 or i.Idle>=o)then i.Gap=0;
                i.Idle=0;
                i.Woke=false;
                local F,O=pcall(i.Run,i);
                i.Repeat=F and O==true;
                k+=1;
                if k>=3 then break;
                end;
            else end;
            end;
        end);
        local F;
        N= RegisterCleanup;
        N(function()
            I:Disconnect();
        end);
    end
    SetupTaskSchedulerModule()


	-- UI adapter: API Create* milik ci.lua -> Add* milik UI FanKunHUB
	local function inertControl()
		return {
			Get = function()
				return false
			end,
			Set = function() end,
			SetOptions = function() end,
		}
	end

		-- deskripsi toggle: [Nama] = {English, Indonesia}. Bahasa mengikuti setting Language.
	local TOGGLE_DESC = {
		["Auto Butterfly Bloom"] = {"Automatically catches butterflies during the Butterfly Bloom event.", "Otomatis menangkap kupu-kupu saat event Butterfly Bloom."},
		["Auto Trade Up"] = {"Automatically trades up your pets at the Enchanted Tree.", "Otomatis trade up pet kamu di Enchanted Tree."},
		["Smart Trade For Essence"] = {"Picks trades in a smarter way to earn more Essence. Works with Auto Trade Up.", "Memilih trade dengan lebih pintar untuk dapat lebih banyak Essence. Jalan bersama Auto Trade Up."},
		["Auto Craft Essence"] = {"Automatically crafts Essence at the Enchanted Tree.", "Otomatis craft Essence di Enchanted Tree."},
		["Auto Steal Halloween Eggs"] = {"Automatically steals eggs in the Halloween Dimension.", "Otomatis mencuri egg di Halloween Dimension."},
		["Instant Steal Halloween Eggs"] = {"Grab Halloween eggs instantly instead of walking to them.", "Ambil egg Halloween secara instan tanpa jalan ke egg-nya."},
		["Auto Farm Monsters"] = {"Automatically fights the Halloween monsters.", "Otomatis melawan monster Halloween."},
		["Auto Pumpkin Moon"] = {"Automatically handles the Pumpkin Moon event.", "Otomatis mengurus event Pumpkin Moon."},
		["Auto Buy Halloween Dimension Egg"] = {"Automatically buys eggs in the Halloween Dimension.", "Otomatis membeli egg di Halloween Dimension."},
		["Auto Ghost Dog Quest"] = {"Automatically does the Ghost Dog quest.", "Otomatis mengerjakan quest Ghost Dog."},
		["Auto Fishing"] = {"Automatically goes fishing.", "Otomatis memancing."},
		["Auto Phantom Express"] = {"Automatically rides the Phantom Express.", "Otomatis naik Phantom Express."},
		["Auto Vacuum Ghouler Boss"] = {"Automatically vacuums the Ghouler boss during the Phantom Express.", "Otomatis menyedot boss Ghouler saat Phantom Express."},
		["Auto Trade Souls"] = {"Automatically trades your Souls once you have enough.", "Otomatis menukar Souls saat jumlahnya sudah cukup."},
		["Auto Play Cursed Island Wars"] = {"Automatically plays Cursed Island Wars.", "Otomatis bermain Cursed Island Wars."},
		["Auto Catch Shooting Star"] = {"Automatically catches Shooting Stars.", "Otomatis menangkap Shooting Star."},
		["Auto Capture Event Egg"] = {"Automatically captures the event egg.", "Otomatis menangkap egg event."},
		["Take It From The Holder"] = {"If another player holds the event egg, take it from them.", "Kalau egg event dipegang pemain lain, ambil dari dia."},
		["Halloween Egg ESP"] = {"Marks eggs in the Halloween Dimension with pet icon and rarity.", "Menandai egg di Halloween Dimension dengan ikon pet dan rarity."},
		["Normal Egg ESP"] = {"Marks eggs in the normal world with pet icon and rarity.", "Menandai egg di dunia biasa dengan ikon pet dan rarity."},
		["Monster ESP"] = {"Marks the Halloween monsters so you can see them.", "Menandai monster Halloween supaya terlihat."},
		["Monster Box"] = {"Draws a box around each marked monster.", "Menggambar kotak di sekitar monster yang ditandai."},
		["Monster Tracer"] = {"Draws a line from you to each marked monster.", "Menggambar garis dari kamu ke monster yang ditandai."},
		["Monster Name"] = {"Shows the name of each marked monster.", "Menampilkan nama monster yang ditandai."},
	}

	local function toggleNote(o)
		local desc = TOGGLE_DESC[o.Name]
		if desc then
			UI.dict[desc[1]] = desc[2]
			return desc[1]
		end
		return o.Note or o.Content or ""
	end

	local toggles = {}

	local function adaptSection(section, hidden)
		local S = {}
		local function noteOf(o)
			return o.Note or o.Content or ""
		end

		function S:CreateText(o)
			if hidden then
				return inertControl()
			end
			local label = section:AddLabel({Title = o.Name, Content = o.Text or "Off", Icon = o.Icon})
			local handle = {}
			function handle:Set(text)
				label:SetContent(tostring(text))
			end
			function handle:Get()
				return nil
			end
			return handle
		end

		-- Activity HUD: hanya fitur yang benar-benar punya toggle di tab UI.
		-- Task internal seperti "Mech Boss" tidak boleh muncul kalau tidak ada
		-- toggle/fitur dengan nama tersebut di UI.
		local activityFeatureOrder = {
			"Auto Steal",
			"Auto Butterfly Bloom",
			"Auto Trade Up",
			"Smart Trade For Essence",
			"Auto Craft Essence",
			"Auto Steal Halloween Eggs",
			"Auto Farm Monsters",
			"Auto Pumpkin Moon",
			"Auto Buy Halloween Dimension Egg",
			"Auto Ghost Dog Quest",
			"Auto Fishing",
			"Auto Phantom Express",
			"Auto Vacuum Ghouler Boss",
			"Auto Trade Souls",
			"Auto Play Cursed Island Wars",
			"Auto Catch Shooting Star",
			"Auto Capture Event Egg",
			"Auto Index",
		}

		window.GetActiveActivities = function()
			local result = {}
			for _, name in ipairs(activityFeatureOrder) do
				local control = toggles[name]
				if control and control.Value == true then
					result[#result + 1] = name
				end
			end
			return result
		end

		function S:CreateToggle(o)
			if hidden then
				return inertControl()
			end
			local control = section:AddToggle({
				Title = o.Name,
				Content = toggleNote(o),
				Icon = o.Icon,
				Default = o.Default == true,
				Callback = function(value)
					if o.Callback then
						pcall(o.Callback, value)
					end
				end,
			})
			toggles[o.Name] = control
			return control
		end

		function S:CreateSlider(o)
			if hidden then
				return inertControl()
			end
			local default = o.Default or o.Min
			local control = section:AddSlider({
				Title = o.Name,
				Content = noteOf(o) ~= "" and noteOf(o) or (o.Unit and ("Unit:" .. tostring(o.Unit)) or ""),
				Icon = o.Icon,
				Min = o.Min,
				Max = o.Max,
				Increment = o.Increment or 1,
				Default = default,
				Callback = function(value)
					if o.Callback then
						pcall(o.Callback, value)
					end
				end,
			})
			if o.Callback then
				task.spawn(pcall, o.Callback, default)
			end
			return control
		end

		local function dropdown(o, multi)
			if hidden then
				return inertControl()
			end
			local options = o.Options or {}
			local default = o.Default
			if multi then
				default = type(default) == "table" and default or {}
			elseif default == nil then
				default = options[1]
			end
			local control = section:AddDropdown({
				Title = o.Name,
				Content = noteOf(o),
				Icon = o.Icon,
				Options = options,
				Default = default,
				Multi = multi,
				Callback = function(value)
					if o.Callback then
						pcall(o.Callback, value)
					end
				end,
			})
			control.SetOptions = control.SetOptions or function() end
			if o.Callback then
				task.spawn(pcall, o.Callback, default)
			end
			return control
		end

		function S:CreateDropdown(o)
			return dropdown(o, false)
		end

		function S:CreateMultiDropdown(o)
			return dropdown(o, true)
		end

		function S:CreateButton(o)
			if hidden then
				return inertControl()
			end
			section:AddButton({
				Title = o.Name,
				Content = noteOf(o),
				Icon = o.Icon,
				Label = o.Text or "Run",
				Callback = function()
					if o.Callback then
						pcall(o.Callback)
					end
				end,
			})
			return inertControl()
		end

		function S:CreateCanvas(o)
			if hidden then
				return inertControl()
			end
			return section:AddCanvas(o)
		end

		function S:CreateInput(o)
			if hidden then
				return inertControl()
			end
			return section:AddInput({
				Title = o.Name,
				Content = noteOf(o),
				Icon = o.Icon,
				Default = tostring(o.Default or ""),
				Callback = function(value)
					if o.Callback then
						pcall(o.Callback, value)
					end
				end,
			})
		end

		return S
	end

	local function CreateFormattedValueSlider(section, o)
		return section:CreateInput({
			Name = o.Name,
			Note = "Minimal value per detik (0 = semua)",
			Default = "0",
			Callback = function(value)
				if o.OnRaw then
					o.OnRaw(tonumber(value) or 0)
				end
			end,
		})
	end

	local function WrapMultiDropdownWithAll(handle)
		return handle
	end

	local function newEventTab(tabName, tabIcon, sectionName, sectionIcon)
		local tab = window:AddTab(tabName, tabIcon)
		return adaptSection(tab:AddSection(sectionName, sectionIcon, 1))
	end

	do
		local espTab = window:AddTab("ESP", "eye")
		GameModules.EspEggSection = adaptSection(espTab:AddSection("Egg ESP", "egg", 1))
		GameModules.EspMonsterSection = adaptSection(espTab:AddSection("Monster ESP", "skull", 2))
	end
	GameModules.HalloweenSection = newEventTab("Halloween", "ghost", "Halloween Dimension", "ghost")
	GameModules.MonsterSection = newEventTab("Monsters", "skull", "Halloween Monsters", "skull")
	GameModules.GhostDogSection = newEventTab("Ghost & Fishing", "fish", "Ghost Dog & Fishing", "fish")
	GameModules.TrainSection = newEventTab("Phantom Express", "train-front", "Phantom Express", "train-front")
	GameModules.StarSection = newEventTab("Shooting Star", "star", "Shooting Star", "star")
	GameModules.ButterflySection = newEventTab("Butterfly", "rbxassetid://107744695034799", "Butterfly Bloom", "rbxassetid://107744695034799")
	GameModules.IslandWarsSection = adaptSection(nil, true) -- Island Wars tidak diminta: disembunyikan & mati

	-- Urutan tab: Steal, Filter, Order, Butterfly, ... , Settings (paling akhir)
	window:SetTabOrder({"Steal", "Filter", "Order", "Butterfly", "Halloween", "Monsters", "Ghost & Fishing", "Phantom Express", "Shooting Star", "ESP", "Anti AFK", "Settings"})

	-- Anti-sky guard: saat Auto Fishing aktif, karakter tidak boleh terlempar tinggi ke atas.
	-- Hanya bereaksi pada lonjakan vertikal mendadak (posisi horizontal hampir sama), jadi
	-- teleport/terbang legit (ke portal, ke spot) tidak terganggu.
	do
		local runSvc = game:GetService("RunService")
		local safePos
		runSvc.Heartbeat:Connect(function()
			local control = toggles["Auto Fishing"]
			if not control or control.Value ~= true then
				safePos = nil
				return
			end
			local root = HubState.Root()
			if not root or HubState.Flying then
				safePos = nil
				return
			end
			local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
			local pos = root.Position
			if safePos then
				local dx, dz = pos.X - safePos.X, pos.Z - safePos.Z
				local flat = math.sqrt(dx * dx + dz * dz)
				if flat > 80 then
					safePos = nil
				elseif pos.Y - safePos.Y > 40 or root.AssemblyLinearVelocity.Y > 150 then
					pcall(function()
						root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
						root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
						root.CFrame = CFrame.new(safePos + Vector3.new(0, 3, 0)) * root.CFrame.Rotation
					end)
					return
				end
			end
			if not safePos or (humanoid and humanoid.FloorMaterial ~= Enum.Material.Air) then
				safePos = pos
			end
		end)
	end


HubState.ButterflyBoot = function(O)
    if not(O)then return;
    end;
    local A,e,Z,R="butterfly",{{Label="Emerald To Sapphire",From="Green"},{Label="Sapphire To Amethyst",From="Blue"},{Label="Amethyst To Radiant",From="Purple"}},{Status="Off",Shown=nil,Busy=false,Generation=0,Speed=320,Mode="Stand Still",Priority="Strict Rarity",Interval=1800,Offset=900,Reach=14,SwingGap=0.45,Counts={Green=0,Blue=0,Purple=0,Golden=0},Essence=0,Caught=0,NetClaimed=false,Recipe={Green=240,Blue=115,Purple=40,Golden=1},TradeCost={Green=10,Blue=10,Purple=50},Trades={},Tiers={Green=true,Blue=true,Purple=true,Golden=true},Pending={},LastSwing=0,Links={},Handle=nil,TradeHandle=nil,CraftHandle=nil};
    local R= HubState;
    R.Butterfly=Z;
    local W,m;
    task.spawn(function()
        pcall(function()
            local L,L;
            L,W= ReplicatedStorageService ,require( ReplicatedStorageService .Shared.Modules.ButterflyCatalog);
        end);
        pcall(function()
            local L,L;
            L,m= ReplicatedStorageService ,require( ReplicatedStorageService .Controllers.Game.AdminAbuseClientController.Events.ButterflyBloom.Swarm);
        end);
        pcall(function()
            local L;
            local L,L= ReplicatedStorageService ,require( ReplicatedStorageService .Shared.Flags.ButterflyFlags);
            Z.Interval=tonumber(L.IntervalSeconds:Get())or Z.Interval;
            Z.Offset=tonumber(L.OffsetSeconds:Get())or Z.Offset;
            Z.Reach=tonumber(L.NetReach:Get())or Z.Reach;
            Z.SwingGap=tonumber(L.SwingCooldownSeconds:Get())or Z.SwingGap;
            Z.TradeCost.Green=tonumber(L.GreenToBlueCost:Get())or Z.TradeCost.Green;
            Z.TradeCost.Blue=tonumber(L.BlueToPurpleCost:Get())or Z.TradeCost.Blue;
            Z.TradeCost.Purple=tonumber(L.PurpleToGoldenCost:Get())or Z.TradeCost.Purple;
            Z.Recipe={Green=tonumber(L.EssenceGreen:Get())or Z.Recipe.Green,Blue=tonumber(L.EssenceBlue:Get())or Z.Recipe.Blue,Purple=tonumber(L.EssencePurple:Get())or Z.Recipe.Purple,Golden=tonumber(L.EssenceGolden:Get())or Z.Recipe.Golden};
        end);
    end);
    local function d(L)local j;
        local j= NetworkingPackage;
        return j:FindFirstChild(L);
    end;
    local function o(L,...)local j=d(L);
        if j then if not(j:IsA("RemoteFunction"))then return false,"missing";
        end;
    else return false,"missing";
    end;
    L=table.pack(pcall(j.InvokeServer,j,...));
    if not(L[1])then return false,tostring(L[2]);
    end;
    return L[2],L[3],L[4];
end;
local function L()local j= HubState;
    return j.Toggle(Z.Handle,false)==true;
end;
local function j()return workspace:GetAttribute("Event_ButterflyBloom")==true;
end;
local function X(U)U=math.max(0,math.floor(U+0.5));
    return string.format("%d:%02d",math.floor(U/60),U%60);
end;
local function U()local a=workspace:GetServerTimeNow();
    if j()then local g=tonumber(workspace:GetAttribute("ButterflyBloomEndsAt"));
        return g and"Butterfly Bloom live, "..X(g-a).." left"or"Butterfly Bloom live";
    end;
    local g=math.floor((a-Z.Offset)/Z.Interval)*Z.Interval+Z.Offset;
    return"Next Butterfly Bloom in "..X((if g<=a then g+Z.Interval else g)-a);
    end;
    local function X()local a=Z.Counts;
        local g=string.format("Emerald %d  Sapphire %d  Amethyst %d  Radiant %d  |  Essence %d",a.Green or 0,a.Blue or 0,a.Purple or 0,a.Golden or 0,Z.Essence or 0);
        g=if Z.MachineNote then g.."  |  "..Z.MachineNote else g;
            a= HubState;
            if a.Toggle(Z.CraftHandle,false)then local a,M,f={},{Green="Emerald",Blue="Sapphire",Purple="Amethyst",Golden="Radiant"},{"Green","Blue","Purple","Golden"};
                for T,T in ipairs(f)do if next(Z.Tiers)~=nil then if Z.Tiers[T]~=true then if(Z.Counts[T]or 0)<(Z.Recipe[T]or 0)then table.insert(a,M[T]);
                end;
            end;
        end;
    end;
    g=if#a>0 then g.."  |  Craft needs "..table.concat(a,", ").." (pick it in Catch Butterflies)"
    else g;
    else end;
        return g;
    end;
    task.spawn(function()
        while true do local a;
            local a= RunServiceRef;
            if a.FanKunDead()then break;
            end;
            pcall(function()
                local a;
                local a= GameModules;
                local g=a.Save;
                a=g and g.Get and g.Get();
                g=type(a)=="table"and a.Butterflies or nil;
                if type(g)=="table"then a=type(g.Counts)=="table"and g.Counts or{};
                    local actOldCounts,actOldCaught,actOldEss=Z.Counts,Z.Caught,Z.Essence;
                    Z.Counts={Green=tonumber(a.Green)or 0,Blue=tonumber(a.Blue)or 0,Purple=tonumber(a.Purple)or 0,Golden=tonumber(a.Golden)or 0};
                    Z.Essence=tonumber(g.Essence)or 0;
                    Z.Caught=tonumber(g.TotalCaught)or 0;
                    if Z.ActSeeded then pcall(function()
                        local actNames={Green="Emerald",Blue="Sapphire",Purple="Amethyst",Golden="Radiant"};
                        local dCaught=(Z.Caught or 0)-(actOldCaught or 0);
                        for _,tier in ipairs({"Green","Blue","Purple","Golden"})do
                            local d=(Z.Counts[tier]or 0)-((actOldCounts and actOldCounts[tier])or 0);
                            if d>0 then
                                local asCatch=math.min(d,math.max(dCaught,0));
                                dCaught=dCaught-asCatch;
                                if asCatch>0 then HubState.LogActivity("butterfly","Tangkap kupu-kupu "..actNames[tier].." x"..asCatch,asCatch);end;
                                if d>asCatch then HubState.LogActivity("butterfly","Dapat "..actNames[tier].." x"..(d-asCatch).." (trade/craft)",0);end;
                            end;
                        end;
                        local dEss=(Z.Essence or 0)-(actOldEss or 0);
                        if dEss>0 then HubState.LogActivity("butterfly","Essence +"..dEss,0);end;
                    end);end;
                    Z.ActSeeded=true;
                    Z.NetClaimed=g.NetClaimed==true;
                end;
            end);
            task.wait(2);
        end;
    end);
    local a={};
    local function g(M)if type(M)=="table"then if M.Id~=nil then a[M.Id]=M;
    end;
end;
end;
pcall(function()
    local M=d("RE/Butterflies/Spawned");
    if M then table.insert(Z.Links,M.OnClientEvent:Connect(function(f)
        g(f);
    end));
end;
M=d("RE/Butterflies/Removed");
if M then table.insert(Z.Links,M.OnClientEvent:Connect(function(f)
    a[f]=nil;
end));
end;
M=d("RE/Butterflies/Escaped");
if M then table.insert(Z.Links,M.OnClientEvent:Connect(function(d,M)
    if type(d)=="table"then g(d);
    elseif type(M)=="table"then g(M);
    end;
end));
end;
end);
local function d(g)if typeof(g)~="Instance"then return nil;
end;
if g:IsA("BasePart")then return g.Position;
end;
if g:IsA("Model")then local M,f=pcall(g.GetPivot,g);
    return M and f.Position or nil;
end;
return nil;
end;
local function g()local M,f,T={},{},m;
    if T then local h=type(m.Each)=="function";
        if h then pcall(function()
            local h=m;
            for m,S in h.Each()do local h=type(S)=="table"and S.Flight or nil;
                local E,D=h and h.Id or m,d(S.Body);
                if E~=nil then if D then if not(Z.Pending[E])then f[E]=true;
                    S,m=table.insert,{Id=E};
                    m.Tier,m.Position,m.Flight=tostring(h and h.Tier or"Green"),D,h;
                    S(M,m);
                end;
            end;
        end;
    end;
end);
end;
end;
T=W and type(W.PositionAt)=="function";
if T then local d=workspace:GetServerTimeNow();
    for m,T in pairs(a)do local a=f[m];
        if not(a)then local a=Z.Pending[m];
            if not(a)then local a,f=pcall(W.PositionAt,T,d);
                if a then if typeof(f)=="Vector3"then local d,a=table.insert,{Id=m};
                    a.Tier,a.Position,a.Flight=tostring(T.Tier or"Green"),f,T;
                    d(M,a);
                end;
            end;
        end;
    end;
end;
end;
return M;
end;
local d,m={Golden=4,Purple=1.6,Blue=0.8,Green=0},{Golden=4,Purple=3,Blue=2,Green=1};
local function a(M)local f=workspace:FindFirstChild("World");
    local T=f and(f:FindFirstChild("Areas"));
    f=T and(T:FindFirstChild("ButterflyBloom"));
    T=f and(f:FindFirstChild("Bounds"));
    if T then if not(T:IsA("BasePart"))then return true;
    end;
else return true;
end;
f=T.CFrame:PointToObjectSpace(M);
return math.abs(f.X)<=T.Size.X/2+80 and math.abs(f.Z)<=T.Size.Z/2+80 and math.abs(f.Y)<=120;
end;
local function M(f,T)local h,S;
    for E,D in ipairs(f)do if a(D.Position)then if next(Z.Tiers)~=nil then if Z.Tiers[D.Tier]~=true then continue;
    end;
end;
else continue;
end;
E=(D.Position-T).Magnitude/math.max(Z.Speed,1);
E=if Z.Priority=="Rarest First"then E-(d[D.Tier]or 0)
else if Z.Priority=="Strict Rarity"then E+(5-(m[D.Tier]or 1))*1000 else E;
    if h then if E<h then h,S=E,D;
    else end;
    else h,S=E,D;
    end;
end;
return S;
end;
local function d()local m;
    local m,a,f= LocalPlayerRef , LocalPlayerRef ,ipairs;
    local T={m.Character,(a:FindFirstChildOfClass("Backpack"))};
    for m,m in f(T)do if m then for a,a in ipairs(m:GetChildren())do if a:IsA("Tool")then if a:GetAttribute("ButterflyNet")==true then return a;
    elseif tostring(a:GetAttribute("ItemType"))=="ButterflyNet"then return a;
    elseif a.Name=="Butterfly Net"then return a;
    end;
end;
end;
end;
end;
return nil;
end;
local function m()local a=d();
    local f;
    local f= LocalPlayerRef;
    local T=f.Character;
    local f=T and(T:FindFirstChildOfClass("Humanoid"));
    if a and f then if a.Parent~=T then pcall(function()
        f:EquipTool(a);
    end);
end;
end;
return a;
end;
local function a(f)local T=workspace:FindFirstChild("World");
    local h=T and(T:FindFirstChild("Machines"));
    T=h and(h:FindFirstChild("ButterflyStation"));
    h=T and(T:FindFirstChild(f));
    T=h and(h:FindFirstChild("Anchor"));
    if T then if T:IsA("BasePart")then return T.Position;
    end;
end;
if h then if h:IsA("Model")then f,T=pcall(h.GetPivot,h);
    return f and T.Position or nil;
end;
end;
return nil;
end;
local function f(T)local h;
    local h= LocalPlayerRef;
    local S,E=h.Character, HubState;
    local h=E.Root();
    if not S or not h then return false;
    elseif not T then return false;
    end;
    pcall(function()
        local E= LocalPlayerRef;
        E:RequestStreamAroundAsync(T,3);
    end);
    pcall(function()
        S:PivotTo(CFrame.new(T+Vector3.new(0,3,4)));
        h.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
    end);
    task.wait(0.6);
    return true;
end;
local T=RaycastParams.new();
T.FilterType=Enum.RaycastFilterType.Exclude;
local function h(S)local E;
    local E= LocalPlayerRef;
    local D,J=E.Character, HubState;
    local G,V=J.Root(),D and(D:FindFirstChildOfClass("Humanoid"));
    if D then if not(G)then return S;
    end;
else return S;
end;
E=workspace:FindFirstChild("ButterflyBloomSwarm");
T.FilterDescendantsInstances=E and{D,E}or{D};
E=workspace:Raycast(S+Vector3.new(0,25,0),Vector3.new(0,-120,0),T);
if not E then return S;
end;
D=(V and V.HipHeight or 2)+G.Size.Y/2;
return Vector3.new(S.X,E.Position.Y+D,S.Z);
end;
local function T()local S=workspace:FindFirstChild("World");
    local E=S and(S:FindFirstChild("Areas"));
    S=E and(E:FindFirstChild("ButterflyBloom"));
    local D,J=S and(S:FindFirstChild("Bounds")),Vector3.new(0,0,-1);
    if D then if D:IsA("BasePart")then E=D.Size.X>=D.Size.Z and D.CFrame.LookVector or D.CFrame.RightVector;
        S=Vector3.new(E.X,0,E.Z);
        J=if S.Magnitude>0.1 then S.Unit else J;
        else end;
        else end;
            return CFrame.lookAt(Vector3.new(0.0,0.0,0.0),J);
        end;
        local function S()local E=workspace:FindFirstChild("World");
            local D=E and(E:FindFirstChild("Areas"));
            E=D and(D:FindFirstChild("ButterflyBloom"));
            D=E and(E:FindFirstChild("Bounds"));
            if D then if D:IsA("BasePart")then return D.Position+Vector3.new(0,6,0);
            end;
        end;
        return Vector3.new(6700,74,-364);
    end;
    local function E()local D=workspace:FindFirstChild("World");
        local J=D and(D:FindFirstChild("Areas"));
        D=J and(J:FindFirstChild("ButterflyBloom"));
        J=D and(D:FindFirstChild("Bounds"));
        if J then if not(J:IsA("BasePart"))then return S();
        end;
    else return S();
    end;
    D=J.Size.X>=J.Size.Z;
    local G=D and J.CFrame.RightVector or J.CFrame.LookVector;
    G=Vector3.new(G.X,0,G.Z).Unit;
    local V,P=math.max(20,(D and J.Size.X or J.Size.Z)/2-30),os.clock();
    Z.PatrolTravel=((Z.PatrolTravel or 0)+(Z.Speed or 320)*math.clamp(P-(Z.PatrolAt or P),0,0.1))%(4*V);
    Z.PatrolAt=P;
    P=Z.PatrolTravel;
    D=P<2*V and P-V or 3*V-P;
    return J.Position+G*D+Vector3.new(0,6,0);
end;
local function D()local J=workspace:FindFirstChild("World");
    local G=J and(J:FindFirstChild("Areas"));
    J=G and(G:FindFirstChild("ButterflyBloom"));
    G=J and(J:FindFirstChild("Bounds"));
    if G then if not(G:IsA("BasePart"))then return S();
    end;
else return S();
end;
local J,V,P=Vector3.new(G.CFrame.RightVector.X,0,G.CFrame.RightVector.Z).Unit,Vector3.new(G.CFrame.LookVector.X,0,G.CFrame.LookVector.Z).Unit,os.clock();
Z.CircleAngle=((Z.CircleAngle or 0)+(Z.Speed or 320)/25*math.clamp(P-(Z.CircleAt or P),0,0.1))%6.283185307179586;
Z.CircleAt=P;
return G.Position+J*(math.cos(Z.CircleAngle)*25)+V*(math.sin(Z.CircleAngle)*25)+Vector3.new(0,6,0);
end;
local function J()local G= HubState;
    local V=G.Root();
    if V then pcall(function()
        V.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
        V.AssemblyAngularVelocity=Vector3.new(0.0,0.0,0.0);
    end);
end;
end;
local function G(V,P)local p= HubState;
    local s=p.Root();
    if not s then return 1/0;
    end;
    local r=V-s.Position;
    p=r.Magnitude;
    if p<0.5 then J();
        return p;
    end;
    local V=math.min(Z.Speed,p/math.max(P,0.016666666666666666));
    pcall(function()
        s.AssemblyLinearVelocity=r.Unit*V;
        s.AssemblyAngularVelocity=Vector3.new(0.0,0.0,0.0);
    end);
    return p;
end;
local function V(P)local p= HubState;
    local s,r=p.Root(),S();
    if not(s)then return;
    end;
    if(s.Position-r).Magnitude<1200 then Z.RagdollTries=0;
        return;
    end;
    s= HubState;
    p=s.IsNight();
    s=nil;
    if p then s=p;
    else local B= HubState;
        s=B.WallSealed();
    end;
    if s then p= HubState;
        Z.Status=p.IsNight()and"Night, waiting for daylight before the ragdoll TP"or"Waiting for the wall to drop before the ragdoll TP";
        return"wait";
    end;
    s,p=(Z.RagdollTries or 0)>=2;
    if s then p=s;
    else local B;
        B,p= HubState ,type( HubState .RagdollTravel)~="function";
    end;
    if p then Z.RagdollTries=0;
        Z.ClaimBackoffUntil=os.clock()+10;
        Z.Status="Ragdoll TP did not land, trying again soon";
        return"wait";
    end;
    Z.RagdollTries=(Z.RagdollTries or 0)+1;
    if Z.RagdollTries==1 then task.wait(1.5);
    end;
    Z.Status=string.format("Ragdoll TP to the butterfly bloom (try %d/2)",Z.RagdollTries);
    local B;
    p= LocalPlayerRef;
    s=p.Character;
    local B=s and(s:FindFirstChildOfClass("Humanoid"));
    if B then pcall(function()
        B:UnequipTools();
    end);
end;
local function B()return P~=Z.Generation or not L()or not j();
end;
s= HubState;
s.TravelCarryUntil=os.clock()+999;
local P,P,s= HubState ,pcall( HubState .RagdollTravel,function()
    return r;
end,B);
p= HubState;
p.TravelCarryUntil=os.clock()+2;
if P then if not(s==true)then return;
end;
else return;
end;
end;
local function P(p)local s,r={a("NetStand"),a("ButterflyMachine")},ipairs;
    for B,_ in r(s)do if p~=Z.Generation then return Z.NetClaimed;
    elseif Z.NetClaimed then return Z.NetClaimed;
    end;
    if _ then Z.Status="Going to claim the Butterfly Net";
        f(_);
        for s=1,5,1 do if p~=Z.Generation then return false;
        end;
        B= HubState;
        s=B.Root();
        if s then if(s.Position-_).Magnitude>12 then f(_);
        end;
    end;
    local f,p=o("RF/Butterflies/AskClaimNet");
    if f==true then Z.NetClaimed=true;
        return true;
    end;
    Z.Status="Net claim: "..tostring(p or"no answer");
    task.wait(0.8);
end;
end;
end;
return false;
end;
local function f()local p={Green=0,Blue=0,Purple=0,Golden=0};
    pcall(function()
        local s;
        local s= GameModules;
        local t=s.Save;
        s=t and t.Get and t.Get();
        t=type(s)=="table"and s.Butterflies or nil;
        s=type(t)=="table"and type(t.Counts)=="table"and t.Counts or{};
        for r in pairs(p)do p[r]=tonumber(s[r])or 0;
        end;
        Z.Essence=tonumber(t and t.Essence)or Z.Essence;
    end);
    Z.Counts=p;
    return p;
end;
local function t()local p;
    local p= LocalPlayerRef;
    return p:GetAttribute("InEnchantedTree")==true;
end;
local function p(s)local r=workspace:FindFirstChild("World");
    local B=r and(r:FindFirstChild("Build"));
    r=B and(B:FindFirstChild("EnchantedTreeInterior"));
    B=r and(r:FindFirstChild("Markers"));
    r=B and(B:FindFirstChild(s));
    return r and r:IsA("BasePart")and r.Position or nil;
end;
local function s(r)local B;
    local B= LocalPlayerRef;
    local _=B.Character;
    local q=_ and(_:FindFirstChildOfClass("Humanoid"));
    B,_=os.clock()+(r or 2),0;
    while os.clock()<B do r= HubState;
        local B=r.Root();
        if B then pcall(function()
            B.Anchored=false;
            B.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
            B.AssemblyAngularVelocity=Vector3.new(0.0,0.0,0.0);
        end);
    end;
    local B= HubState;
    if B.Grounded()then _+=1;
        if _>=8 then break;
        end;
    else _=0;
    end;
    local _;
    B= RunServiceRef;
    B.Heartbeat:Wait();
end;
if q then r=q:GetState();
    if r==Enum.HumanoidStateType.Freefall or r==Enum.HumanoidStateType.None or r==Enum.HumanoidStateType.Physics or r==Enum.HumanoidStateType.Ragdoll or r==Enum.HumanoidStateType.FallingDown then pcall(function()
        q:ChangeState(Enum.HumanoidStateType.GettingUp);
    end);
    task.wait(0.3);
end;
end;
end;
local function r(B,_)local q;
    local q= LocalPlayerRef;
    local v=q.Character;
    local c,H=v and(v:FindFirstChildOfClass("Humanoid")), HubState;
    local C=H.Root();
    if not c or not C then return false;
    elseif not B then return false;
    end;
    s(0.3);
    q=(C.Position-B).Magnitude>6;
    if q then pcall( HubState .FlyTo,B+Vector3.new(0,3,0),function()
        return not t();
    end,A);
    s(0.5);
end;
q= HubState;
local K=q.Root()or C;
H=t()and(K.Position-B).Magnitude>8;
if H then Z.Status="Walking to the machine";
    local H,C=p("ExitTrigger"),{B};
    pcall(function()
        local w=game:GetService("PathfindingService"):CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true,WaypointSpacing=6});
        w:ComputeAsync(K.Position,B);
        local l=w.Status==Enum.PathStatus.Success;
        if l then C={};
            local l,Q=ipairs, table.pack (w:GetWaypoints());
            for w,w in l( table.unpack(Q, 1, Q.n) )do table.insert(C,w.Position);
            end;
            table.insert(C,B);
        end;
    end);
    v,q=os.clock()+(_ or 15),C;
    for F,_ in ipairs(q)do if(K.Position-B).Magnitude<=6 then break;
    elseif t()then if os.clock()>=v then break;
    end;
else break;
end;
if not(H and(_-H).Magnitude<14)then F=math.min(v,os.clock()+3);
    while os.clock()<F and(t())do if Vector3.new(_.X-K.Position.X,0,_.Z-K.Position.Z).Magnitude<=2.5 then break;
    elseif(K.Position-B).Magnitude<=6 then break;
    end;
    c:MoveTo(_);
    task.wait(0.05);
end;
end;
end;
pcall(function()
    c:MoveTo(K.Position);
    K.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
end);
task.wait(0.4);
end;
return t()and(K.Position-B).Magnitude<=8;
end;
local function F()local B=workspace:FindFirstChild("World");
    local _=B and(B:FindFirstChild("Build"));
    B=_ and(_:FindFirstChild("EnchantedTreeInterior"));
    _=B and(B:FindFirstChild("Markers"));
    B=_ and(_:FindFirstChild("EnterTrigger"));
    _=B and(B:FindFirstChild("EnchantedTreeEntrance"));
    B=_ and(_:FindFirstChild("EnchantedTreePrompt"));
    if B then if B:IsA("ProximityPrompt")then _=B.Parent;
        if _:IsA("Attachment")then return B,_.WorldPosition;
        elseif _:IsA("BasePart")then return B,_.Position;
        end;
    end;
end;
return nil,nil;
end;
local function B(_,q)if q%2==1 then if type(fireproximityprompt)=="function"then pcall(fireproximityprompt,_);
    return;
end;
end;
pcall(function()
    _:InputHoldBegin();
    task.wait((tonumber(_.HoldDuration)or 0)+0.1);
    _:InputHoldEnd();
end);
end;
local function _(q)if type(Z.TripSay)=="function"then Z.TripSay(q);
else Z.Status=q;
end;
end;
local function q(v)if t()then return true;
end;
local c,H=F();
if c then if not H then Z.MachineError="tree entrance not found";
    return false;
end;
else Z.MachineError="tree entrance not found";
    return false;
end;
local C= HubState;
local K=C.Root();
if not(K)then return false;
end;
local w=H+Vector3.new(0,3,-12);
local l,Q=(K.Position-w).Magnitude>500;
if l then C=nil;
    C,Q= HubState ,type( HubState .RagdollTravel)=="function";
else Q=l;
end;
local K;
if Q then l= HubState;
    C=l.IsNight();
    if C then Z.MachineError="waiting for daylight";
        return false;
    else local K= HubState;
        if K.WallSealed()then Z.MachineError="waiting for daylight";
            return false;
        end;
    end;
    for K=1,2,1 do if v()then return false;
    end;
    local n= HubState;
    local x=n.Root();
    if x then if(x.Position-w).Magnitude<=60 then break;
    end;
else break;
end;
_(string.format("Ragdoll TP to the Enchanted Tree (try %d/2)",K));
n= LocalPlayerRef;
x=n.Character;
local K=x and(x:FindFirstChildOfClass("Humanoid"));
if K then pcall(function()
    K:UnequipTools();
end);
end;
x= HubState;
x.TravelCarryUntil=os.clock()+999;
pcall( HubState .RagdollTravel,function()
    return w;
end,v);
x= HubState;
x.TravelCarryUntil=os.clock()+2;
s(0.5);
end;
end;
Q= HubState;
local K=Q.Root();
C=K and(K.Position-w).Magnitude>60;
if C then if v()then return false;
end;
_("Flying to the Enchanted Tree");
pcall( HubState .FlyTo,w,v,A);
s(0.5);
end;
for w=1,4,1 do if v()then return false;
end;
_("Entering the Enchanted Tree");
Q= LocalPlayerRef;
local _=Q.Character;
C,l=_ and(_:FindFirstChildOfClass("Humanoid")), HubState;
K=l.Root();
if _ and K then pcall(function()
    K.Anchored=false;
    if(K.Position-H).Magnitude>30 then _:PivotTo(CFrame.new(H+Vector3.new(0,1,-12)));
        K.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
    end;
end);
local _=0;
while C and _<3 and(K.Position-H).Magnitude>4 do C:MoveTo(H);
    _+=task.wait(0.05);
end;
end;
task.wait(0.1);
B(c,w);
w=0;
while w<4 and not t()do w+=task.wait(0.1);
end;
if t()then task.wait(0.5);
    return true;
end;
end;
Z.MachineError="could not enter the tree";
return false;
end;
local function B()if not(t())then return;
end;
local _=p("ExitTrigger");
local v;
local v= LocalPlayerRef;
local c=v.Character;
local H,C=c and(c:FindFirstChildOfClass("Humanoid")), HubState;
c=C.Root();
v=_ and c;
if v then pcall( HubState .FlyTo,_,function()
    return not t();
end,A);
C=0;
while C<0.5 and(t())do C+=task.wait(0.05);
end;
end;
if _ and H and c and t()then v=0;
    while v<6 and(t())do H:MoveTo(_);
        v+=task.wait(0.1);
    end;
end;
if not(t())then return;
end;
local c,c=F();
C= LocalPlayerRef;
local F,K=C.Character, HubState;
local C=K.Root();
if c and F then if C then pcall(function()
    F:PivotTo(CFrame.new(c+Vector3.new(0,3,-30)));
    C.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
end);
end;
end;
v=0;
while v<3 and(t())do v+=task.wait(0.25);
end;
H=t()and _;
if H then pcall( HubState .FlyTo,_,function()
    return not t();
end,A);
v=0;
while v<3 and(t())do v+=task.wait(0.25);
end;
end;
end;
R= HubState;
R.TreeTrip={Enter=q,Leave=B,InTree=t,Settle=s,Marker=p};
local function F(p,s,...)local _=a(s);
    if not(_)then Z.MachineError="machine not found";
        return false;
    end;
    if Z.AtStation~=s then local a=r(_,15);
        if a then else if type(Z.TripStopped)=="function"then if Z.TripStopped()then else Z.Status="Trying the tree again";
            if not(t())then q(Z.TripStopped);
            end;
            a=t()and r(_,15);
        end;
    else end;
    end;
    if not(a)then Z.MachineError=t()and"could not reach the machine"or"left the tree";
        return false;
    end;
    Z.AtStation=s;
end;
for t=1,3,1 do s,t=o(p,...);
    if s==true then return true;
    end;
    Z.MachineError=tostring(t or"no answer");
    if not(string.find(string.lower(Z.MachineError),"closer",1,true))then return false;
    end;
    if not(r(_,8))then return false;
    end;
end;
return false;
end;
local function o(t)local a,p,s,r,_,v=Z.Recipe,Z.TradeCost,t.Green or 0,t.Blue or 0,t.Purple or 0,t.Golden or 0;
    for c=60,1,-1 do t=math.max(0,c*a.Golden-v);
        local v=math.max(0,c*a.Purple+(p.Purple or 50)*t-_);
        local _=math.max(0,c*a.Blue+(p.Blue or 10)*v-r);
        if s>=c*a.Green+(p.Green or 10)*_ then return{Essence=c,Green=_,Blue=v,Purple=t};
        end;
    end;
    return nil;
end;
local function t()local a= HubState;
    local p=a.Toggle(Z.TradeHandle,false);
    a=nil;
    if p then local s= HubState;
        a=s.Toggle(Z.SmartHandle,false);
    else a=p;
    end;
    return a;
end;
local function a(p)local s= HubState;
    local r,_=s.Toggle(Z.TradeHandle,false), HubState;
    s=_.Toggle(Z.CraftHandle,false);
    if r then elseif s then else return;
    end;
    local v;
    _= LocalPlayerRef;
    if _:GetAttribute("EnchantedTreeUnlocked")~=true then Z.MachineNote="Trade and craft need the Enchanted Tree open (finish the Wisp quest)";
        return;
    end;
    Z.AtStation=nil;
    Z.MachineError=nil;
    local function v()local c,H=p~=Z.TripToken;
        if c then H=c;
        else local p= HubState;
            H=p.ButterflyYield()~=nil;
        end;
        local p,C=H or j()and L();
        if p then C=p;
        else c= HubState;
            H=c.Toggle(Z.TradeHandle,false);
            local p;
            if H then p=H;
            else local c= HubState;
                p=c.Toggle(Z.CraftHandle,false);
            end;
            C=not p;
        end;
        return C;
    end;
    Z.TripStopped=v;
    pcall(function()
        local p= HubState;
        local c,H=p.Treadmill;
        if c then p= HubState;
            H=p.Treadmill.Riding;
        else H=c;
        end;
        c=nil;
        if H then c=H;
        else local H,H= HubState ,type( HubState .OnBelt)=="function";
            if H then p= HubState;
                c=p.OnBelt();
            else c=H;
            end;
        end;
        if c then Z.Status="Leaving the treadmill first";
            p= HubState;
            p.ExitBelt();
        end;
    end);
    if not(q(v))then Z.MachineNote="Could not get into the Enchanted Tree"..(Z.MachineError and" ("..Z.MachineError..")"or"");
        return;
    end;
    local p,q=0,0;
    if r and(t())then _=o(f());
        if _ then local c,H=ipairs,{{From="Green",Count=_.Green},{From="Blue",Count=_.Blue},{From="Purple",Count=_.Purple}};
            for C,C in c(H)do for c=1,C.Count,1 do if v()then break;
            end;
            Z.Status="Smart trade for Enchanted Essence";
            if not(F("RF/Butterflies/AskTradeUp","ButterflyMachine",C.From))then break;
            end;
            p+=1;
            task.wait(0.15);
        end;
    end;
else end;
else if r then for c,c in ipairs(e)do if Z.Trades[c.Label]then local H,C=Z.TradeCost[c.From]or 10,s and(Z.Recipe[c.From]or 0)or 0;
    for K=1,400,1 do if v()then break;
    end;
    if(f()[c.From]or 0)-C<H then break;
    end;
    Z.Status="Trading "..c.Label.." at the machine";
    if not(F("RF/Butterflies/AskTradeUp","ButterflyMachine",c.From))then break;
    end;
    p+=1;
    task.wait(0.15);
end;
else end;
end;
else end;
end;
if s then for s=1,50,1 do if v()then break;
end;
_,r=f(),true;
for s,v in pairs(Z.Recipe)do r=if(_[s]or 0)<v then false else r;
end;
if not r then break;
end;
Z.Status="Crafting Enchanted Essence at the shrine";
if not(F("RF/Butterflies/AskCraftEssence","MutationShrine"))then break;
end;
q+=1;
task.wait(0.3);
end;
else end;
    Z.MachineNote=string.format("Last visit: %d trade%s, %d essence",p,p==1 and""or"s",q);
    if Z.MachineError then if p==0 then if q==0 then Z.MachineNote=Z.MachineNote.." ("..Z.MachineError..")";
    end;
end;
end;
f();
end;
local function F()local f;
    local f= LocalPlayerRef;
    if f:GetAttribute("EnchantedTreeUnlocked")~=true then return false;
    end;
    f= HubState;
    local p,s=f.Toggle(Z.TradeHandle,false), HubState;
    local r,_=s.Toggle(Z.CraftHandle,false),Z.Counts or{};
    if t()then f=o(_);
        if not f then return false;
        end;
        return r or f.Green+f.Blue+f.Purple>0;
    end;
    if r then s=true;
        for o,t in pairs(Z.Recipe)do s=if(_[o]or 0)<t then false else s;
        end;
        if s then return true;
        end;
    end;
    if p then for o,o in ipairs(e)do if Z.Trades[o.Label]then f=r and(Z.Recipe[o.From]or 0)or 0;
        if(_[o.From]or 0)-f>=(Z.TradeCost[o.From]or 10)then return true;
        end;
    end;
end;
end;
return false;
end;
local o;
local function o()Z.Busy=true;
    Z.Generation=Z.Generation+1;
    local t=Z.Generation;
    local function f()return t==Z.Generation and L()and j();
    end;
    Z.Wants=true;
    Z.RagdollTries=0;
    local p= HubState;
    p.Shield(A,true);
    pcall(function()
        local s= HubState;
        local r,_=s.Treadmill;
        if r then s= HubState;
            _=s.Treadmill.Riding;
        else _=r;
        end;
        if _ then s= HubState;
            s.ExitBelt();
        else local s,s= HubState ,type( HubState .OnBelt)=="function";
            if s then r= HubState;
                local s=r.OnBelt();
                if s then local s= HubState;
                    s.ExitBelt();
                end;
            end;
        end;
    end);
    pcall(function()
        local s= HubState;
        local r=s.SafeCarry;
        if type(r.V2_InZone)=="function"then if r.V2_InZone()then Z.Status="Leaving the fuse area first";
            r.V2_LeaveZone();
        end;
    end;
end);
p= HubState;
p.BeginFlight();
if not(Z.NetClaimed)then if f()then P(t);
end;
end;
while f()do local s;
    p= RunServiceRef;
    local N,s=p.Heartbeat:Wait(), HubState;
    local r=s.ButterflyYield();
    if r then Z.Status=r;
        break;
    end;
    r=Z.NetClaimed;
    s=if r then not r else not d();
        if s then if not(P(t))then Z.Status="Could not claim the net yet, retrying";
            task.wait(2);
        end;
    else if V(t)=="wait"then J();
        break;
    end;
    m();
    r= HubState;
    local d=r.Root();
    if d then local t=g();
        if Z.Mode=="Stand Still"or Z.Mode=="Patrol"or Z.Mode=="Circle"then local m,g=d.Position,{};
            for V,V in ipairs(t)do if(V.Position-m).Magnitude<=Z.Reach-2 then table.insert(g,V);
            end;
        end;
        local V,P=M(g,m),h(Z.Mode=="Patrol"and E()or Z.Mode=="Circle"and D()or S());
        local m=T();
        if(P-d.Position).Magnitude>8 then G(P,N);
            pcall(function()
                d.CFrame=CFrame.new(d.Position)*m;
                d.AssemblyAngularVelocity=Vector3.new(0.0,0.0,0.0);
            end);
            Z.Status="Going to the middle of the bloom";
        else pcall(function()
            d.CFrame=CFrame.new(P)*m;
            d.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
            d.AssemblyAngularVelocity=Vector3.new(0.0,0.0,0.0);
        end);
        if V then Z.Status=string.format("Standing, catching a %s butterfly  |  %d flying",({Green="Emerald",Blue="Sapphire",Purple="Amethyst",Golden="Radiant"})[V.Tier]or V.Tier,#t);
        else Z.Status=string.format("Standing in the bloom  |  %d flying",#t);
        end;
    end;
    continue;
end;
local m;
local g=Z.ChaseLock;
if g then if os.clock()<g.Until then local E=m;
    for D,D in ipairs(t)do if D.Id==g.Id then E=D;
        break;
    end;
end;
m=E;
else end;
else end;
    if m then else m=M(t,d.Position);
        if m then Z.ChaseLock={Id=m.Id,Until=os.clock()+1};
        end;
    end;
    if m then local M=Vector3.zero;
        g=W and type(W.VelocityAt)=="function"and type(m.Flight)=="table";
        if g then local g,E=pcall(W.VelocityAt,m.Flight,workspace:GetServerTimeNow());
            if g and typeof(E)=="Vector3"then M=E;
            else end;
            else end;
                local W,g=d.Position,T();
                local T,E=(m.Position-W).Magnitude,m.Position;
                if(E-W).Magnitude<=40 then pcall(function()
                    d.CFrame=CFrame.new(E)*g;
                    d.AssemblyLinearVelocity=Vector3.new(M.X,0,M.Z);
                    d.AssemblyAngularVelocity=Vector3.new(0.0,0.0,0.0);
                end);
            else G(E,N);
                pcall(function()
                    d.CFrame=CFrame.new(d.Position)*g;
                    d.AssemblyAngularVelocity=Vector3.new(0.0,0.0,0.0);
                end);
            end;
            Z.Status=string.format("Catching a %s butterfly, %d studs  |  %d flying",({Green="Emerald",Blue="Sapphire",Purple="Amethyst",Golden="Radiant"})[m.Tier]or m.Tier,math.floor(T+0.5),#t);
            W=T<=Z.Reach-2;
        else G(h(S()),N);
            Z.Status="Waiting for butterflies in the bloom";
        end;
    end;
end;
end;
Z.Wants=false;
p= HubState;
local d,N=p.InvisButterfly;
if d then p=j();
    N=if p then not L()
    else not p;
    else N=d;
    end;
    if N then p= HubState;
        p.InvisButterfly=false;
        f= HubState;
        d=f.InvisibilityHandle;
        local N=d~=nil;
        if N then local N= HubState;
            local t=N.Toggle(d,false);
            if t then N= HubState;
                N.Notify("Invisibility","Butterfly catching is done, Invisibility is back on.");
            end;
        end;
    end;
    J();
    pcall( HubState .EndFlight);
    d= HubState;
    d.Shield(A,false);
    d= HubState;
    d.ReleaseMovement(A);
    Z.Busy=false;
    d= TaskScheduler;
    d.Wake();
end;
if type(O.CreateCanvas)~="function"then Z.Row=O:CreateText({Name="Butterfly Status",Text="Off"});
end;
local d,N=type(O.CreateCanvas)=="function";
if d then local N,t={{Key="Green",Icon="rbxassetid://107744695034799",Color="#5BE873"},{Key="Blue",Icon="rbxassetid://89995151383384",Color="#5FA2FF"},{Key="Purple",Icon="rbxassetid://121235713836098",Color="#C27BFF"},{Key="Golden",Icon="rbxassetid://98126365702697",Color="#FFD452"},{Key="Essence",Icon="rbxassetid://114750647204247",Color="#6FF0FF"}},{};
    local W=O:CreateCanvas({Name="Butterflies",ShowTitle=false,Layout="free",Style={TextScale=1,LineHeight=1.1,MinLines=3.3,MaxLines=3.3,AutoHeight=true,BackgroundTransparency=0.35,TextColor=Color3.fromRGB(255,255,255),TextStrokeTransparency=0.7},Build=function(m)
            Z.StatusUi=m:Text({X=0.7,Y=0.15,Width=1,Height=1.1,Scale=1,Wrap=false,Text="Off",Color="#FFFFFF",TextStrokeTransparency=0.6});
            local g={};
            for M,f in ipairs(N)do local T=0.7+(M-1)*4.7;
                g[M]=m:Image({X=T,Y=1.35,Width=1.85,Height=1.85,Image=f.Icon,BackgroundTransparency=1});
                t[f.Key]=m:Text({X=T+2.05,Y=1.6,Width=3,Height=1.35,Scale=1.2,Wrap=false,Text="0",Color=f.Color,TextStrokeTransparency=0.6});
            end;
            pcall(function()
                m:SetContentLines(3.3);
            end);
            local M;
            local f=24;
            function Z.LayoutCard()local T,h={},0;
                for E,D in ipairs(N)do T[E]=2.05+#(Z.CountShown and Z.CountShown[D.Key]or"0")*0.62;
                    h+=T[E];
                end;
                local E,D=math.max(0.5,(f-1.4-h)/math.max(1,#N-1)),0.7;
                for h,G in ipairs(N)do pcall(g[h].Set,{X=D});
                    local N,g=pcall,G.Key;
                    local G,V=t[g].Set,{X=D+2.05};
                    V.Width=T[h]-2.05+0.3;
                    N(G,V);
                    D+=T[h]+E;
                end;
            end;
            m:OnResize(function(N,m,g)
                N=M;
                if m==N then return;
                end;
                M=m;
                f=m/math.max(g,1);
                Z.LayoutCard();
            end);
        end});
    Z.CountUi=t;
    Z.CountShown={};
    R= RegisterCleanup;
    R(function()
        pcall(function()
            W:Destroy();
        end);
    end);
else Z.Counter=O:CreateText({Name="Butterflies",Text=X()});
end;
Z.Handle=O:CreateToggle({Name="Auto Butterfly Bloom",Default=false,Callback=function()
        if not(L())then Z.Generation=Z.Generation+1;
        end;
        local N= TaskScheduler;
        N.Wake();
    end});
O:CreateDropdown({Name="Catch Mode",Options={"Stand","Chase","Circle","Patrol"},Default="Stand",SubOf=Z.Handle,Callback=function(N)
        N=tostring(N);
        Z.Mode=(N=="Chase"or N=="Patrol"or N=="Circle")and N or"Stand Still";
    end});
O:CreateDropdown({Name="Catch Priority",Note="Only for Chase mode",Options={"Rarest","Nearest"},Default="Rarest",SubOf=Z.Handle,Callback=function(N)
        N=tostring(N);
        Z.Priority=(N=="Nearest"or N=="Nearest First")and"Nearest First"or"Strict Rarity";
    end});
local N,t,W={["Radiant Butterfly"]="Golden",["Amethyst Butterfly"]="Purple",["Sapphire Butterfly"]="Blue",["Emerald Butterfly"]="Green",["Legendary (Radiant)"]="Golden",["Epic (Amethyst)"]="Purple",["Rare (Sapphire)"]="Blue",["Common (Emerald)"]="Green",["Radiant (Golden)"]="Golden",["Amethyst (Purple)"]="Purple",["Sapphire (Blue)"]="Blue",["Emerald (Green)"]="Green",Golden="Golden",Purple="Purple",Blue="Blue",Green="Green"},{"Radiant Butterfly","Amethyst Butterfly","Sapphire Butterfly","Emerald Butterfly"};
d= WrapMultiDropdownWithAll;
d(O:CreateMultiDropdown({Name="Catch Butterflies",Note="Only for Chase mode",Options=t,Default=t,SubOf=Z.Handle,Callback=function(d)
        local z={};
        if type(d)=="table"then for W,m in pairs(d)do local d=m==true and type(W)=="string"and W or type(m)=="string"and m or nil;
            W=d and N[d];
            if W then z[W]=true;
            end;
        end;
    end;
    Z.Tiers=z;
    z= TaskScheduler;
    z.Wake();
end}));
O:CreateSlider({Name="Tween Speed  ",Min=100,Max=600,Default=320,Increment=10,Unit="studs/s",SubOf=Z.Handle,Callback=function(d)
        Z.Speed=math.clamp(tonumber(d)or 320,100,600);
    end});
Z.BuiltAt=os.clock();
Z.TradeHandle=O:CreateToggle({Name="Auto Trade Up",Default=false,Callback=function(d)
        local N=d==true;
        if N then d=os.clock()-(Z.BuiltAt or 0)>4;
            if d then local d;
                local d= LocalPlayerRef;
                local z=d:GetAttribute("EnchantedTreeUnlocked")~=true;
                if z then d= HubState;
                    d.Notify("Butterfly Bloom","Trade and craft need the Enchanted Tree open (finish the Wisp quest). It stays on and starts by itself once the tree is open.");
                end;
            end;
        end;
        N= TaskScheduler;
        N.Wake();
    end});
O:CreateMultiDropdown({Name="Trade Up Tiers",Options={e[1].Label,e[2].Label,e[3].Label},Default={},SubOf=Z.TradeHandle,Callback=function(d)
        local N,z={["Green To Blue"]="Emerald To Sapphire",["Blue To Purple"]="Sapphire To Amethyst",["Purple To Golden"]="Amethyst To Radiant"},{};
        for e,e in ipairs(type(d)=="table"and d or{})do z[N[tostring(e)]or tostring(e)]=true;
        end;
        Z.Trades=z;
    end});
Z.SmartHandle=O:CreateToggle({Name="Smart Trade For Essence",Default=false,SubOf=Z.TradeHandle,Callback=function(d)
        local N=d==true;
        if N then d=os.clock()-(Z.BuiltAt or 0)>4;
            if d then local d;
                local d= LocalPlayerRef;
                local z=d:GetAttribute("EnchantedTreeUnlocked")~=true;
                if z then d= HubState;
                    d.Notify("Butterfly Bloom","Trade and craft need the Enchanted Tree open (finish the Wisp quest). It stays on and starts by itself once the tree is open.");
                end;
            end;
        end;
        N= TaskScheduler;
        N.Wake();
    end});
Z.CraftHandle=O:CreateToggle({Name="Auto Craft Essence",Default=false,Callback=function(O)
        local d=O==true;
        if d then O=os.clock()-(Z.BuiltAt or 0)>4;
            if O then local d;
                local d= LocalPlayerRef;
                local N=d:GetAttribute("EnchantedTreeUnlocked")~=true;
                if N then d= HubState;
                    d.Notify("Butterfly Bloom","Trade and craft need the Enchanted Tree open (finish the Wisp quest). It stays on and starts by itself once the tree is open.");
                end;
            end;
        end;
        O= TaskScheduler;
        O.Wake();
    end});
t= TaskScheduler;
t.Add(function()
    local O,d=Z.Row,if L()then if Z.Busy then Z.Status.."  |  "..U()
    else
        (U())
    else
        "Off  |  "..U();
        if O then Z.Shown=d;
            local N= HubState;
            N.ShowRow(O,d);
        end;
        if Z.StatusUi then if Z.StatusShown~=d then if type(Z.StatusUi.Set)=="function"then Z.Shown=d;
            Z.StatusShown=d;
            pcall(Z.StatusUi.Set,{Text=d});
        end;
    end;
end;
if Z.CountUi then O=Z.Counts or{};
    local d={Green=O.Green,Blue=O.Blue,Purple=O.Purple,Golden=O.Golden,Essence=Z.Essence};
    for N,t in pairs(Z.CountUi)do local z=Z.Recipe[N];
        local e=z and string.format("%d/%d",d[N]or 0,z)or tostring(d[N]or 0);
        if Z.CountShown[N]~=e then if type(t.Set)=="function"then Z.CountShown[N]=e;
            pcall(t.Set,{Text=e});
            Z.CardDirty=true;
        end;
    end;
end;
if Z.CardDirty then if type(Z.LayoutCard)=="function"then Z.CardDirty=false;
    pcall(Z.LayoutCard);
end;
end;
end;
local d,N=X(),Z.Counter;
if N then Z.CounterShown=d;
    O= HubState;
    O.ShowRow(Z.Counter,d);
end;
N=Z.Busy;
d,O=(if N then not N else not j())and os.clock()>=(Z.NextTrip or 0);
    if d then N= HubState;
        O=not N.IsNight();
    else O=d;
    end;
    N=nil;
    if O then d= HubState;
        N=not d.WallSealed();
    else N=O;
    end;
    d=N and(F());
    if d then N= HubState;
        O=N.ButterflyYield();
        if O then Z.Status=O;
        else local F= HubState;
            local t=F.ClaimMovement(A);
            if t then Z.NextTrip=os.clock()+60;
                Z.Busy=true;
                Z.TripToken=(Z.TripToken or 0)+1;
                local F=Z.TripToken;
                task.spawn(function()
                    pcall(a,F);
                    pcall(B);
                    local F= HubState;
                    F.ReleaseMovement(A);
                    Z.Busy=false;
                    F= TaskScheduler;
                    F.Wake();
                end);
                return true;
            end;
        end;
    end;
    d=Z.Busy;
    O,N=not d;
    if d then N=O;
    else local F= HubState;
        N=F.InvisButterfly;
    end;
    d=nil;
    if N then O=L();
        d=if O then not j()
        else not O;
        else d=N;
        end;
        if d then O= HubState;
            O.InvisButterfly=false;
            N= HubState;
            local F=N.InvisibilityHandle;
            local t=F~=nil;
            if t then local t= HubState;
                local k=t.Toggle(F,false);
                if k then t= HubState;
                    t.Notify("Invisibility","Butterfly catching is done, Invisibility is back on.");
                end;
            end;
        end;
        if L()then if not(j())then Z.Claiming=false;
        end;
    else Z.Claiming=false;
    end;
    if L()then if Z.Busy then return true;
    elseif not(j())then return true;
    end;
else return true;
end;
d= HubState;
N=d.ButterflyYield();
if N then Z.Status=N;
    Z.Claiming=false;
    return true;
end;
N= HubState;
O=N.IsNight();
d=nil;
if O then d=O;
else N= HubState;
    d=N.WallSealed();
end;
if d then N= HubState;
    O=N.Root();
    if O then if(O.Position-S()).Magnitude>=1200 then Z.Status="Night, waiting for daylight before the ragdoll TP";
        Z.Claiming=false;
        return true;
    end;
end;
end;
if os.clock()<(Z.ClaimBackoffUntil or 0)then Z.Claiming=false;
    Z.Status="Another task is moving, trying the butterflies again soon";
    return true;
end;
Z.Claiming=true;
O= HubState;
N=O.InvisButterfly;
if not N then d= HubState;
    d.InvisButterfly=true;
    O= HubState;
    local F=O.InvisibilityHandle;
    local t=F~=nil;
    if t then local t= HubState;
        local k=t.Toggle(F,false);
        if k then t= HubState;
            t.Notify("Invisibility","Invisibility is paused while catching butterflies and comes back after it.");
        end;
    end;
end;
local F;
d= LocalPlayerRef;
O=d.Character;
if O then if O:GetAttribute("InvisApplied")==true then Z.Status="Leaving Invisibility before catching";
    return true;
end;
end;
O= HubState;
N=O.ClaimMovement(A);
if not N then Z.ClaimWaitSince=Z.ClaimWaitSince or os.clock();
    if os.clock()-Z.ClaimWaitSince>10 then Z.ClaimWaitSince=nil;
        Z.ClaimBackoffUntil=os.clock()+20;
        Z.Claiming=false;
    end;
    O=nil;
    O,Z.Status= HubState ,"Waiting for "..tostring( HubState .Movement.Owner or"movement");
    return true;
end;
Z.ClaimWaitSince=nil;
task.spawn(function()
    local F,O=pcall(o);
    if not(F)then Z.Status="Stopped: "..tostring(O);
        Z.Wants=false;
        local F= HubState;
        F.InvisButterfly=false;
        pcall(J);
        pcall( HubState .EndFlight);
        pcall( HubState .Shield,A,false);
        F= HubState;
        F.ReleaseMovement(A);
        Z.Busy=false;
    end;
end);
return true;
end);
R= RegisterCleanup;
R(function()
    Z.Generation=Z.Generation+1;
    Z.TripToken=(Z.TripToken or 0)+1;
    for F,F in ipairs(Z.Links)do pcall(function()
        F:Disconnect();
    end);
end;
table.clear(Z.Links);
pcall( HubState .Shield,A,false);
pcall( HubState .ReleaseMovement,A);
end);
end
HubState.ButterflyBoot(GameModules.ButterflySection)

local SetupFieldTimerAndStarEvent = function()
    local O;
    local O,Z= HubState;
    O.FieldOpensIn=function()
        local O= GameModules;
        local Z=O.AreaEggCycle;
        local R=workspace:GetServerTimeNow();
        O=type(Z)=="table";
        if O then local W,m,L=pcall(function()
            return Z.IsNightPhase(R),Z.NextResetTime(R);
        end);
        if W then local Z=m==true;
            if Z then local Z=type(L)=="number";
                if Z then local Z,W= HubState , HubState;
                    Z.FieldOpenAt=L+W.WallOpenDelay();
                end;
            end;
        end;
    end;
    O= HubState;
    local Z=O.WallSealed();
    if Z then O= HubState;
        return math.max((O.FieldOpenAt or R)-R,0.3);
    end;
    Z= HubState;
    O=(Z.FieldOpenAt or 0)-R;
    return O>0 and O or 0;
end;
local O,Z= HubState;
O.WaitFieldOpen=function(O,Z)
    local R;
    local W=false;
    while not O()do local m= HubState;
        local L=m.FieldOpensIn();
        m=L<=0;
        if m then if W then local j=os.clock()+5;
            while os.clock()<j do if O()then return false;
            end;
            local O= RunServiceRef;
            O.Heartbeat:Wait();
        end;
    end;
    return true;
end;
W=true;
m= HubState;
local O=m.Root();
if O then R=R or O.Position;
    pcall(function()
        if(O.Position-R).Magnitude>4 then O.CFrame=CFrame.new(R)*O.CFrame.Rotation;
        end;
        O.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
    end);
else end;
    if Z then Z(string.format("waiting in the safe zone, field opens in %ds",math.ceil(L)));
    end;
    m= RunServiceRef;
    m.Heartbeat:Wait();
end;
return false;
end;
local O= HubState;
O.StepTo=function(O,Z,R)
    local W= HubState;
    local m=W.SafeCarry;
    local L,j,X,X,U=tonumber(m.HopLift)or 42,tonumber(m.HopGap)or 0.1, HubState ,type( HubState .StealHome)=="function";
    if X then W= HubState;
        U=W.StealHome();
    else U=X;
    end;
    X,W=U or nil, HubState;
    U=W.Root();
    local a,g=X and U;
    if a then W= HubState;
        g=W.InsideBase();
    else g=a;
    end;
    a=g and(U.Position-X).Magnitude>(m.V2DirectRadius or 69);
    if a then if R then R("leaving the base through the safe zone");
    end;
    g,U=X+Vector3.new(0,3,0),os.clock()+20;
    while os.clock()<U and not Z()do W= HubState;
        local M=W.Root();
        if not M then return false;
        end;
        local f=g-M.Position;
        if f.Magnitude<=4 then break;
        end;
        local T,T= RunServiceRef ,math.min(250* RunServiceRef .Heartbeat:Wait(),f.Magnitude);
        pcall(function()
            M.CFrame=CFrame.new(M.Position+f.Unit*T)*M.CFrame.Rotation;
            M.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
        end);
    end;
    task.wait(0.3);
end;
U= HubState;
X=U.InsideBase();
if X then W= HubState;
    if not(W.WaitFieldOpen(Z,R))then return false;
    end;
end;
X,U,a=os.clock()+30,1/0,0;
while os.clock()<X and not Z()do g= HubState;
    local Z=g.Root();
    local X=O();
    if not Z or not X then return false;
    end;
    local g,M,M=Vector3.new(X.X-Z.Position.X,0,X.Z-Z.Position.Z), HubState ,math.max( HubState .WalkSpeed()*(tonumber(m.HopRatio)or 1.515),40);
    if g.Magnitude>U-M*0.5 then a+=1;
        if a>=2 then return false;
        end;
    else a=0;
    end;
    U=g.Magnitude;
    W=g.Magnitude<=M;
    if W then pcall(function()
        Z.CFrame=CFrame.new(X)*Z.CFrame.Rotation;
        Z.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
    end);
    task.wait(0.5);
    local W= HubState;
    local m,U=W.Root(),O();
    return m~=nil and U~=nil and Vector3.new(U.X-m.Position.X,0,U.Z-m.Position.Z).Magnitude<=M;
end;
local O=Vector3.new(Z.Position.X,X.Y+L,Z.Position.Z)+g.Unit*M;
if R then R(math.floor(g.Magnitude-M+0.5));
end;
g=0;
while g<j do M= HubState;
    local Z=M.Root();
    if Z then pcall(function()
        Z.CFrame=CFrame.new(O)*Z.CFrame.Rotation;
        Z.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
        Z.AssemblyAngularVelocity=Vector3.new(0.0,0.0,0.0);
    end);
end;
local O= RunServiceRef;
g+=O.Heartbeat:Wait();
end;
end;
return false;
end;
local O,Z= HubState;
O.GlideTo=function(O,Z,R,W,m)
    local L= HubState;
    local j=L.InsideBase();
    if j then L= HubState;
        if not(L.WaitFieldOpen(Z,W))then return false;
        end;
    end;
    L= HubState;
    j=L.Root();
    if not j then return false;
    end;
    L= LocalPlayerRef;
    local X,U=L.Character,j.Position;
    j,L=os.clock()+(m or 40),false;
    local a,g=0,0;
    while true do local M,f=os.clock()<j and not Z();
        if M then m= LocalPlayerRef;
            f=m.Character==X;
        else f=M;
        end;
        if not f then break;
        end;
        M= RunServiceRef;
        local Z,m=M.Heartbeat:Wait(), HubState;
        local j=m.Root();
        f=O();
        if not j or not f then break;
        end;
        M=Vector3.new(f.X-j.Position.X,0,f.Z-j.Position.Z).Magnitude;
        if M<=R then L=true;
            break;
        end;
        local O,R=j.Anchored;
        if O then m=nil;
            m,R= HubState ,type( HubState .ExitBelt)=="function";
        else R=O;
        end;
        if R then pcall( HubState .ExitBelt);
            U=j.Position;
        else end;
            O=U;
            if os.clock()<a then pcall(function()
                j.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
                j.AssemblyAngularVelocity=Vector3.new(0.0,0.0,0.0);
            end);
            U=j.Position;
            continue;
        end;
        m=g;
        if(j.Position-O).Magnitude>25 then g=m+1;
            a,U=os.clock()+math.min(0.25+0.25*g,1),j.Position;
            if W then W(string.format("lagged back, waiting a moment (%d)",g));
            end;
            continue;
        end;
        local X;
        local X,a= ReturnHomeSpeed *(m<2 and 1 or math.max(0.5,0.8^(m-1))),f-O;
        R=X*Z;
        U=a.Magnitude<=R and f or O+a.Unit*R;
        R=Vector3.new(a.X,0,a.Z);
        local O=R.Magnitude>0.05 and CFrame.lookAt(Vector3.new(0.0,0.0,0.0),R.Unit)or j.CFrame.Rotation;
        pcall(function()
            j.CFrame=CFrame.new(U)*O;
            j.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
            j.AssemblyAngularVelocity=Vector3.new(0.0,0.0,0.0);
        end);
        if W then W(math.floor(M+0.5));
        end;
    end;
    return L;
end;
    local SetupHalloweenAndMinigameEventsModule = function()
    local y = PlayersService
    local p = RunServiceRef
    local V = HubState
    local U = NetworkingPackage
    local K = RegisterCleanup
    local S = GameModules
    local t = ReplicatedStorageService
    local M = TaskScheduler
    local B = CreateFormattedValueSlider
    local o = game:GetService("CollectionService")
    local H,z,l,h,i,a,I,r,m={Bad={},Eggs=0,Kills=0,Fish=0,HitAt=0,BuyAt=0,FishAt=0,DogAt=0,Busy=false,Gen=0,Status="Off"},{At=0,Prompts={},Missing={},Rides=0,Busy=false,Gen=0},{Cooldowns={},Shot=0,At=0,Busy=false,Gen=0},{Busy=false},{Prep=true,Match=true,SuddenDeath=true},{Intro=true,Reveal=true,Prep=true,Match=true,SuddenDeath=true,Win=true,Outro=true},{Boarded=true,Departing=true,Returning=true,Respawning=true},{"Meet the dog","Find 4 memories","Talk to the fisherman","Catch the ghost dog","Done"};
    V.HwState=H;
    V.TrainState=z;
    local m=y;
    local e=m.LocalPlayer;
    local function J(O)return e:GetAttribute(O);
    end;
    do
        local lastTokens=tonumber(J("HalloweenTokens"));
        pcall(function()
            e:GetAttributeChangedSignal("HalloweenTokens"):Connect(function()
                local nowTokens=tonumber(J("HalloweenTokens"))or 0;
                local gain=nowTokens-(lastTokens or nowTokens);
                lastTokens=nowTokens;
                if gain>0 and V.LogActivity then
                    local src=V.ActSource;
                    local from=(src and os.clock()-src.at<8)and(" dari "..tostring(src.label))or"";
                    if os.clock()-(H.LastReelAt or -1e9)<8 and H.FishStats then
                        from=" dari Fishing";
                        H.FishStats.Candy=H.FishStats.Candy+gain;
                        if H.FishRefresh then pcall(H.FishRefresh);end;
                    end;
                    V.LogActivity("candy","Candy +"..gain..from.." (total "..nowTokens..")",gain);
                end;
            end);
        end);
    end;
    local O;
    local function O()local E=p;
    return E.Heartbeat:Wait();
    end;
    local E;
    local function E()local N=V;
    return N.Root();
    end;
    local function N()local x=e.Character;
    return x and(x:FindFirstChildOfClass("Humanoid"));
    end;
    local function x()local F=N();
    return math.max(F and F.WalkSpeed or 16,16);
    end;
    local function F(d,...)local Q;
    local Q=U;
    local j=Q:FindFirstChild(d);
    if j then if not(j:IsA("RemoteFunction"))then return false;
    end;
    else return false;
    end;
    return pcall(j.InvokeServer,j,...);
    end;
    local function d(Q,...)local j;
    local j=U;
    local q=j:FindFirstChild(Q);
    if q and(q:IsA("RemoteEvent"))then local Q=table.pack(...);
    pcall(function()q:FireServer(table.unpack(Q,1,Q.n));
    end);
    end;
    end;
    local Q;
    local function Q(j,q)local R;
    local R=U;
    local U=R:FindFirstChild(j);
    if U and(U:IsA("RemoteEvent"))then local j,R=U.OnClientEvent:Connect(q),K;
    R(function()j:Disconnect();
    end);
    end;
    end;
    local U;
    local function U()local j=S;
    local q=j.Save;
    local j,R=pcall(function()return(q.Peek or q.Get)();
    end);
    return j and type(R)=="table"and R or nil;
    end;
    local function j(q)local R=U();
    return R and R[q];
    end;
    local function q(R,A)local c,k=pcall(function()local w;
    local w,w=t,require(t.Shared.Flags[R])[A];
    return w:Get();
    end);
    if c then return k;
    end;
    return nil;
    end;
    local function R(...)local A,c={...},workspace:FindFirstChild("World")or workspace:FindFirstChild("__OBJECTS");
    for k,k in ipairs(A)do c=c and(c:FindFirstChild(k));
    end;
    return c;
    end;
    local function A(c)return Vector3.new(c.X,0,c.Z);
    end;
    local function c(k)if typeof(k)~="Instance"then return nil;
    end;
    if k:IsA("BasePart")then return k.Position;
    elseif k:IsA("Attachment")then return k.WorldPosition;
    elseif k:IsA("Model")then return k:GetPivot().Position;
    end;
    return k.Parent and c(k.Parent);
    end;
    local function k(w)local L=E();
    if not L then return;
    end;
    pcall(function()if L.Anchored then L.Anchored=false;
    end;
    L.CFrame=w;
    L.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
    L.AssemblyAngularVelocity=Vector3.new(0.0,0.0,0.0);
    end);
    end;
    local function w(L)local Z=E();
    if Z then if L then if type(firetouchinterest)=="function"then pcall(firetouchinterest,Z,L,0);
    task.wait();
    pcall(firetouchinterest,Z,L,1);
    end;
    end;
    end;
    end;
    local function L(Z)if Z and type(fireproximityprompt)=="function"then pcall(function()Z.HoldDuration=0;
    fireproximityprompt(Z);
    end);
    end;
    end;
    local function Z(G)local g,Y=ipairs,{e.Character,e:FindFirstChildOfClass("Backpack")};
    for P,P in g(Y)do for g,g in ipairs(P and P:GetChildren()or{})do if g:IsA("Tool")then if G(g)then return g;
    end;
    end;
    end;
    end;
    return nil;
    end;
    local function G(g)local Y=N();
    if g then if Y then if g.Parent~=e.Character then pcall(Y.EquipTool,Y,g);
    end;
    end;
    end;
    return g;
    end;
    local function g(Y,P)local n=os.clock()+Y;
    while os.clock()<n do if P then if not(P())then return false;
    end;
    end;
    O();
    end;
    return true;
    end;
    local function Y(P,n,b)local C=os.clock()+n;
    while os.clock()<C do if P()then return true;
    end;
    if b then if not(b())then return false;
    end;
    end;
    O();
    end;
    return P();
    end;
    local function P(n)local b=E();
    if b and n then local C=A(n-b.Position);
    if C.Magnitude>0.1 then pcall(function()b.CFrame=CFrame.new(b.Position,b.Position+C.Unit);
    end);
    end;
    end;
    end;
    local function n()local b=V;
    local C=b.AdminAbuse;
    for D=1,3,1 do D,b=E(),V;
    local X,W=b.Treadmill.Riding==true;
    if X then W=X;
    else local b,b=V,type(V.OnBelt)=="function";
    if b then local X=V;
    W=X.OnBelt();
    else W=b;
    end;
    end;
    if not(W)then if type(C)=="table"then if C.OnAdmin==true then elseif D then if not(D.Anchored)then return true;
    end;
    else return true;
    end;
    elseif D then if not(D.Anchored)then return true;
    end;
    else return true;
    end;
    end;
    if type(C)=="table"then C.OnAdmin=false;
    end;
    W=V;
    W.Treadmill.Riding=false;
    pcall(V.ExitBelt);
    end;
    C=E();
    return not(C and C.Anchored);
    end;
    local b,C,D={},{},0;
    local function X(W)local T=e.Character;
    if W then for W,W in ipairs(T and T:GetDescendants()or{})do if W:IsA("BasePart")then if W.CanCollide then b[W]=true;
    W.CanCollide=false;
    end;
    end;
    end;
    local W=E();
    if W and os.clock()-D>0.15 then D=os.clock();
    local D,f=RaycastParams.new(),OverlapParams.new();
    D.FilterType,D.FilterDescendantsInstances=Enum.RaycastFilterType.Exclude,{T};
    f.FilterType,f.FilterDescendantsInstances=Enum.RaycastFilterType.Exclude,{T};
    local _=workspace:Raycast(W.Position,Vector3.new(0,-12,0),D);
    local D,u=_ and _.Position.Y or W.Position.Y-3,{};
    for s,s in ipairs(workspace:GetPartBoundsInRadius(W.Position,14,f))do if s.CanCollide or C[s]then if s~=(_ and _.Instance)then if s.Position.Y+s.Size.Y/2>D+1.5 then u[s]=true;
    C[s]=true;
    s.CanCollide=false;
    end;
    end;
    end;
    end;
    for D in next,C,nil do if not(u[D])then C[D]=nil;
    if D.Parent then D.CanCollide=true;
    end;
    end;
    end;
    end;
    else for D in next,b,nil do if D.Parent then D.CanCollide=true;
    end;
    end;
    table.clear(b);
    local b={};
    if T then local D=OverlapParams.new();
    D.FilterType,D.FilterDescendantsInstances=Enum.RaycastFilterType.Exclude,{T};
    local W,f=T:GetBoundingBox();
    local T,_,u=ipairs,workspace,f+Vector3.new(1,1,1);
    for f,f in T(_:GetPartBoundsInBox(W,u,D))do b[f]=true;
    end;
    end;
    for D in next,C,nil do local W=b[D];
    if if W then not D.Parent else not W then C[D]=nil;
    if D.Parent then D.CanCollide=true;
    end;
    end;
    end;
    end;
    end;
    local b,D;
    local function W()return os.clock()<(H.VisSettleUntil or 0);
    end;
    m=p;
    local T,f=m.Stepped:Connect(function()local _,u=H.FishPin,E();
    H.OthersOff=H.OthersOff or{};
    if _ then local s=y;
    for vQ,HQ in ipairs(s:GetPlayers())do vQ=HQ~=e and HQ.Character;
    if vQ then for s,s in ipairs(vQ:GetChildren())do if s:IsA("BasePart")then if s.CanCollide then H.OthersOff[s]=true;
    s.CanCollide=false;
    end;
    end;
    end;
    end;
    end;
    elseif next(H.OthersOff)then for s in next,H.OthersOff,nil do if s.Parent then s.CanCollide=true;
    end;
    end;
    table.clear(H.OthersOff);
    end;
    if _ then if u then u.CFrame=_;
    u.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
    u.AssemblyAngularVelocity=Vector3.new(0.0,0.0,0.0);
    end;
    end;
    u=e.Character;
    _=u~=nil and u:GetAttribute("InvisApplied")==true;
    if u~=b or _~=D then if b~=nil then H.VisSettleUntil=os.clock()+1.5;
    end;
    b,D=u,_;
    end;
    if H.Move then X(true);
    elseif next(C)then X(false);
    end;
    end),K;
    f(function()T:Disconnect();
    X(false);
    for b in next,C,nil do if b.Parent then b.CanCollide=true;
    end;
    end;
    end);
    local function b(C,D,T)if not(n())then return false;
    end;
    local _,u=os.clock,1/0;
    local s,vQ=_(),0.016666666666666666;
    while D()do _=E();
    if not _ then return false;
    end;
    local D=C-_.Position;
    if D.Magnitude<3 then k(CFrame.new(C)*_.CFrame.Rotation);
    return true;
    end;
    if D.Magnitude<u-3 then u,s=D.Magnitude,os.clock();
    else if os.clock()-s>6 then return false;
    end;
    end;
    k(CFrame.new(_.Position+D.Unit*math.min((T or x()*0.92)*vQ,D.Magnitude))*_.CFrame.Rotation);
    vQ=math.clamp(O(),0.004166666666666667,0.05);
    end;
    return false;
    end;
    local function C(D,...)H.MoveDepth=(H.MoveDepth or 0)+1;
    H.Move=true;
    local T,_=pcall(D,...);
    H.MoveDepth=H.MoveDepth-1;
    if H.MoveDepth==0 then H.Move=false;
    X(false);
    end;
    if not(T)then error(_,0);
    end;
    return _;
    end;
    local function D(T,_,u)return C(b,T,_,u);
    end;
    local function b(T,_)local u=E();
    if not(u)then return false;
    end;
    if(u.Position-T).Magnitude<=400 then return D(T,_);
    end;
    if not(n())then return false;
    end;
    local u,u,s=V,pcall(V.FlyTo,T,function()return not _();
    end,"halloween");
    if u then if not(s)then return false;
    end;
    else return false;
    end;
    return D(T,_);
    end;
    local function T()local _=J("TrainEventPhase");
    if _~=nil then return _;
    end;
    return z.State and os.clock()-z.At<10 and z.State.Phase or nil;
    end;
    local function _()return J("InHalloweenDimension")==true;
    end;
    l.Me=function()local u=l.Snap;
    for s,s in ipairs(u and type(u.Entries)=="table"and u.Entries or{})do if type(s)=="table"then if s.UserId==e.UserId then return s;
    end;
    end;
    end;
    return nil;
    end;
    l.Held=function()local u=l.Snap;
    return u~=nil and a[u.Phase]==true and os.clock()-l.At<30 and l.Me()~=nil;
    end;
    local u=V;
    u.HalloweenOnly=function()if l.Held()then return"islandwars";
    end;
    if e:GetAttribute("TrainEventTravelStage")=="Prepare"then return"train";
    end;
    local u,u=V,type(V.TrainWanted);
    if u=="function"then local u=V;
    local s,vQ=u.Steal;
    if s then u=V;
    vQ=u.Steal.Carrying==true;
    else vQ=s;
    end;
    if not(vQ)then s=V;
    if s.TrainWanted()then return"train";
    end;
    end;
    end;
    local u,s=T(),e.Character;
    if I[u]then return"train";
    elseif u=="Town"then return"train";
    elseif s then if s:GetAttribute("TrainEventInForgottenTown")==true then return"train";
    end;
    end;
    if H.Chase then return"halloween";
    elseif J("GhostDogChase")~=nil then return"halloween";
    elseif _()then return"halloween";
    end;
    return nil;
    end;
    local u=V;
    u.HalloweenRealHum=function()return I[T()]==true or l.Held()or _();
    end;
    local u,s={steal="StealTop",place="Place",treadmill="Treadmill",wisp="StealWisp",banjo="StealWisp",essence="Essence",butterfly="Butterfly",star="Star",train="Train"},{["Pumpkin Moon"]="HwPumpkin",["Ghost Dog Quest"]="HwDog",Eggs="StealFilter",Monsters="HwMonsters",Fishing="HwFishing"};
    local function vQ(HQ)local yQ=V;
    local pQ,VQ=yQ.Priority,u[HQ];
    if VQ then if type(pQ)~="table"then return 0;
    end;
    else return 0;
    end;
    if VQ=="StealTop"then yQ=V;
    local UQ,KQ=yQ.Steal;
    if UQ then HQ=V;
    KQ=HQ.Steal.WantedRank;
    else KQ=UQ;
    end;
    return KQ or pQ.StealTop();
    end;
    return pQ.Rank[VQ]or 99;
    end;
    local function HQ(yQ)local pQ=V;
    local VQ=pQ.Priority;
    pQ=type(VQ)=="table"and VQ.Rank[s[yQ]]or 99;
    if yQ=="Eggs"then if H.EggsRank then return H.EggsRank(pQ);
    end;
    end;
    return pQ;
    end;
    local function yQ(pQ)local VQ,UQ=not pQ;
    if pQ then UQ=VQ;
    else local KQ;
    KQ,UQ=V,type(V.HalloweenRank)=="function";
    end;
    VQ=nil;
    if UQ then local KQ=V;
    VQ=KQ.HalloweenRank();
    else VQ=UQ;
    end;
    local KQ,SQ=VQ or 99,V;
    UQ=SQ.Steal;
    if UQ then if UQ.Carrying==true then return"Auto Steal";
    elseif UQ.Wanted==true then if pQ then return"Auto Steal";
    elseif vQ("steal")<KQ then return"Auto Steal";
    end;
    end;
    end;
    VQ,UQ=V,type(V.TrainWanted);
    if UQ=="function"then SQ=V;
    if SQ.TrainWanted()then if pQ then return"train";
    elseif vQ("train")<KQ then return"train";
    end;
    end;
    end;
    SQ,UQ=os.clock(),V;
    for VQ,tQ in pairs(UQ.MovementWaiting)do if VQ~="halloween"then if VQ~="steal"then if VQ~="treadmill"then if SQ-tQ<6 then if pQ then return VQ;
    elseif vQ(VQ)<KQ then return VQ;
    end;
    end;
    end;
    end;
    end;
    end;
    return nil;
    end;
    m=S;
    f=m.HalloweenSection;
    local pQ=f:CreateText({Name="Halloween Status",Text="Off"});
    local function VQ(UQ)H.Status=UQ;
    end;
    local UQ;
    local function UQ()H.Gen=H.Gen+1;
    H.IdleUntil=0;
    local KQ=M;
    KQ.Wake();
    end;
    H.Eggs_=f:CreateToggle({Name="Auto Steal Halloween Eggs",Default=false,Callback=function()UQ();
    local KQ=V;
    if KQ.StealPanelSync then pcall(V.StealPanelSync);
    end;
    end});
    m=V;
    m.HalloweenToggle=H.Eggs_;
    H.Instant_=f:CreateToggle({Name="Instant Steal Halloween Eggs",Default=true});
    H.Step=40;
    f:CreateSlider({Name="Steal Speed",Min=10,Max=100,Default=40,AllowDecimals=false,Increment=5,Unit=" st",Quick=false,Callback=function(KQ)H.Step=tonumber(KQ)or 40;
    end});
    H.MonsterOrder="Closest";
    H.MonsterKinds={};
    H.Weapons={};
    H.EggNames={};
    H.EggRarities={};
    local KQ,SQ={},{};
    pcall(function()local tQ=S;
    local MQ,BQ=tQ.Assets;
    if MQ then tQ=S;
    BQ=tQ.Assets.Directory;
    else BQ=MQ;
    end;
    local oQ,zQ,lQ,hQ=BQ or{},{},next;
    BQ,tQ=t,require(t.Data.HalloweenPets);
    for BQ,hQ in lQ,tQ.Specs,nil do MQ=type(hQ)=="table"and hQ.Id or BQ;
    BQ=oQ[MQ];
    hQ=type(BQ)=="table"and type(BQ.Rarity)=="table"and BQ.Rarity or{};
    zQ[#zQ+1]={Name=tostring(MQ),Rank=tonumber(hQ.RarityNumber or hQ.Rank)or 0,Rarity=tostring(hQ.DisplayName or hQ._id or"?")};
    end;
    table.sort(zQ,function(tQ,BQ)if tQ.Rank~=BQ.Rank then return tQ.Rank>BQ.Rank;
    end;
    return tQ.Name<BQ.Name;
    end);
    for tQ,tQ in ipairs(zQ)do MQ=string.format("%s [%s]",tQ.Name,tQ.Rarity);
    KQ[#KQ+1]=MQ;
    SQ[MQ]=tQ.Name;
    end;
    end);
    f:CreateMultiDropdown({Name="Halloween Eggs To Steal",Options=#KQ>0 and KQ or{"Whiskers","Jesterpop","Candlefang","Spirit Knight","Graveyard Brute","Ghost Reaper","Hooded Gerbil","Toadstool","Patchwork Imp","Haunted Scorpio","BloodBloom","Shelltide Voyager","Mimic Chest","Crowshade","Hexed Pumpkin","Werewolf","Abomination Kong","Voidseer Pumpkin"},Default={},Callback=function(KQ)local tQ={};
    for MQ,MQ in ipairs(type(KQ)=="table"and KQ or{})do tQ[SQ[MQ]or MQ]=true;
    end;
    H.EggNames=tQ;
    end});
    f:CreateMultiDropdown({Name="Halloween Egg Rarities",Options={"Epic","Legendary","Mythic","Cosmic","Secret","Eternal","Divine"},Default={},Callback=function(KQ)local SQ={};
    for tQ,tQ in ipairs(type(KQ)=="table"and KQ or{})do SQ[tQ]=true;
    end;
    H.EggRarities=SQ;
    end});
    local KQ;
    m=B;
    m(f,{Name="Min Value",OnRaw=function(B)H.MinValue=tonumber(B)or 0;
    end});
    m=S;
    local B=m.MonsterSection or f;
    H.Monsters_=B:CreateToggle({Name="Auto Farm Monsters",Default=false,Callback=UQ});
    B:CreateMultiDropdown({Name="Monsters To Kill",Options={"Candy Corn (+12 Candy)","Hollow Bat (+12 Candy)","Scarecrow (+28 Candy)","Chest Mimic (+28 Candy)","Pumpkin Golem (+65 Candy)","Soul Phantom (+65 Candy)"},Default={},Callback=function(KQ)local SQ={};
    for tQ,tQ in ipairs(type(KQ)=="table"and KQ or{})do SQ[tQ:match("^(.-) %(")or tQ]=true;
    end;
    H.MonsterKinds=SQ;
    end});
    B:CreateDropdown({Name="Monster Order",Options={"Closest","Most Tokens"},Default="Closest",Callback=function(KQ)H.MonsterOrder=KQ;
    end});
    H.MonsterSpeed=300;
    B:CreateSlider({Name="Walk Speed",Min=100,Max=1000,Default=300,AllowDecimals=false,Increment=10,Unit=" st/s",Quick=false,Callback=function(KQ)H.MonsterSpeed=tonumber(KQ)or 300;
    end});
    local KQ,SQ,tQ,MQ={},{},{},{};
    pcall(function()local BQ,oQ=next;
    local oQ,oQ=t,require(t.Data.Gears);
    for zQ,lQ in BQ,oQ.Directory,nil do if type(lQ)=="table"and(lQ.BatControllerData or lQ.ToolController=="Slap")then local BQ=lQ.DisplayName or zQ;
    KQ[#KQ+1]=BQ;
    SQ[BQ]=zQ;
    tQ[zQ]=lQ.BatControllerData~=nil or nil;
    MQ[zQ]=true;
    end;
    end;
    table.sort(KQ);
    end);
    local function BQ()local oQ=U();
    local zQ,lQ,hQ,iQ=type(oQ)=="table"and type(oQ.GearInventory)=="table"and table.clone(oQ.GearInventory)or{},{},ipairs,{e.Character,e:FindFirstChildOfClass("Backpack")};
    for oQ,oQ in hQ(iQ)do for hQ,hQ in ipairs(oQ and oQ:GetChildren()or{})do if hQ:IsA("Tool")then zQ[hQ:GetAttribute("GearName")or hQ.Name]=true;
    end;
    end;
    end;
    for oQ,oQ in ipairs(KQ)do if zQ[SQ[oQ]]then lQ[#lQ+1]=oQ;
    end;
    end;
    return lQ;
    end;
    H.WeaponsShown=BQ();
    H.WeaponsKey=table.concat(H.WeaponsShown,"|");
    local KQ=B:CreateMultiDropdown({Name="Use Weapons",Options=#H.WeaponsShown>0 and H.WeaponsShown or{"No Weapons"},Default=table.clone(H.WeaponsShown),Callback=function(oQ)local zQ={};
    for lQ,lQ in ipairs(type(oQ)=="table"and oQ or{})do if SQ[lQ]then zQ[SQ[lQ]]=true;
    end;
    end;
    H.Weapons=zQ;
    end});
    H.WeaponsAt=0;
    m=M;
    m.Add(function()if os.clock()<H.WeaponsAt then return false;
    end;
    H.WeaponsAt=os.clock()+5;
    local SQ=BQ();
    local BQ=table.concat(SQ,"|");
    if#SQ==0 then return false;
    elseif BQ==H.WeaponsKey then return false;
    end;
    local oQ,zQ=pcall(KQ.Get,KQ);
    local lQ={};
    for hQ,hQ in ipairs(oQ and type(zQ)=="table"and zQ or{})do lQ[hQ]=true;
    end;
    oQ=true;
    for hQ,hQ in ipairs(H.WeaponsShown)do oQ=if lQ[hQ]then oQ else false;
    end;
    zQ={};
    for hQ,hQ in ipairs(SQ)do if oQ then zQ[#zQ+1]=hQ;
    elseif lQ[hQ]then zQ[#zQ+1]=hQ;
    end;
    end;
    H.WeaponsShown=SQ;
    H.WeaponsKey=BQ;
    pcall(KQ.SetOptions,KQ,SQ,zQ,true);
    return false;
    end);
    H.BatIds=tQ;
    H.ToolIds=MQ;
    H.Pumpkin_=f:CreateToggle({Name="Auto Pumpkin Moon",Default=true,Callback=UQ});
    H.PumpkinSpeed=300;
    f:CreateSlider({Name="Walk Speed",Min=100,Max=1000,Default=300,AllowDecimals=false,Increment=10,Unit=" st/s",Quick=false,Callback=function(KQ)H.PumpkinSpeed=tonumber(KQ)or 300;
    end});
    H.Buy_=f:CreateToggle({Name="Auto Buy Halloween Dimension Egg",Default=false,Callback=UQ});
    m=S;
    f=m.GhostDogSection;
    local KQ=f:CreateText({Name="Ghost Dog Status",Text="Off"});
    H.Dog_=f:CreateToggle({Name="Auto Ghost Dog Quest",Default=false,Callback=UQ});
    H.Fishing_=f:CreateToggle({Name="Auto Fishing",Default=false,Callback=UQ});
    -- Kartu hasil memancing (gaya kartu Butterfly): ikon Candy Corn + jumlah yang didapat dari memancing
    pcall(function()
        if type(f.CreateCanvas)~="function"then return;end;
        H.FishStats={Candy=0,Fish=0,Icon="rbxassetid://112785428441728",IconSet=false};
        f:CreateCanvas({Name="Fishing Catch",ShowTitle=false,Layout="free",Style={TextScale=1,LineHeight=1.1,MinLines=2.6,MaxLines=2.6,AutoHeight=true,BackgroundTransparency=0.35,TextColor=Color3.fromRGB(255,255,255),TextStrokeTransparency=0.7},Build=function(m)
            m:Text({X=0.7,Y=0.15,Width=12,Height=1.1,Scale=1,Wrap=false,Text="Hasil Memancing",Color="#FFFFFF",TextStrokeTransparency=0.6});
            H.FishUi={
                Emoji=m:Text({X=0.7,Y=1.35,Width=2,Height=1.6,Scale=1.2,Wrap=false,Text="",Color="#FFFFFF",TextStrokeTransparency=1}),
                Icon=m:Image({X=0.7,Y=1.35,Width=1.85,Height=1.85,Image="",BackgroundTransparency=1}),
                Candy=m:Text({X=3.0,Y=1.6,Width=10,Height=1.35,Scale=1.2,Wrap=false,Text="Candy Corn: 0",Color="#FFB03B",TextStrokeTransparency=0.6}),
                Fish=m:Text({X=14,Y=1.6,Width=9,Height=1.35,Scale=1,Wrap=false,Text="Tangkapan: 0",Color="#B8B8B8",TextStrokeTransparency=0.6}),
            };
            pcall(function()m:SetContentLines(2.6);end);
            if H.FishRefresh then pcall(H.FishRefresh);end;
        end});
        H.FishRefresh=function()
            local st,ui=H.FishStats,H.FishUi;
            if not(st and ui)then return;end;
            local total=tonumber(j("HalloweenTokens"))or tonumber(J("HalloweenTokens"));
            if total then st.Total=total;end;
            local shown=st.Total and math.floor(st.Total)or nil;
            pcall(ui.Candy.Set,{Text=shown and("Candy Corn: "..shown..(st.Candy>0 and("  (+"..st.Candy.." fishing)")or""))or("Candy Corn: "..st.Candy)});
            pcall(ui.Fish.Set,{Text="Tangkapan: "..st.Fish});
            if st.Icon and not st.IconSet then
                st.IconSet=true;
                pcall(ui.Icon.Set,{Image=st.Icon});
                pcall(ui.Emoji.Set,{Text=""});
            end;
        end;
        if H.FishUi then pcall(H.FishRefresh);end;
        -- Candy Corn total: ikut data save (HalloweenTokens), update otomatis saat bertambah
        pcall(function()
            local sv=S.Save;
            if type(sv)=="table" and type(sv.FieldSignal)=="function" then
                local ok,sig=pcall(sv.FieldSignal,"HalloweenTokens");
                if ok and type(sig)=="table" and type(sig.Connect)=="function" then
                    local ok2,conn=pcall(sig.Connect,sig,function() if H.FishRefresh then pcall(H.FishRefresh);end;end);
                    if ok2 and conn then K(function() pcall(function() conn:Disconnect();end);end);end;
                end;
            end;
        end);
        local candyDead=false;
        K(function() candyDead=true;end);
        task.spawn(function()
            while not candyDead do
                if H.FishRefresh then pcall(H.FishRefresh);end;
                task.wait(3);
            end;
        end);
    end);
    H.Charge=0.875;
    f:CreateDropdown({Name="Cast Luck",Options={"x1.5 Perfect","x1.2","x1.1","x1.0 Fastest"},Default="x1.5 Perfect",Callback=function(SQ)H.Charge=({["x1.2"]=1,["x1.1"]=0.5,["x1.0 Fastest"]=0.02})[SQ]or 0.875;
    H.LuckName=SQ;
    end});
    local function SQ(tQ,MQ)local BQ=V;
    return BQ.Toggle(tQ,MQ)==true;
    end;
    local function tQ()local MQ=V;
    if MQ.IsNight()then return true;
    else local MQ=V;
    if MQ.WallSealed()then return true;
    end;
    end;
    local MQ,BQ=pcall(function()local oQ=S;
    return oQ.AreaEggCycle.NextResetTime(workspace:GetServerTimeNow())-workspace:GetServerTimeNow();
    end);
    return MQ and tonumber(BQ)~=nil and BQ<10;
    end;
    local function MQ()return os.clock()>=(H.IdleUntil or 0)and(SQ(H.Eggs_,false)or SQ(H.Monsters_,false)or SQ(H.Dog_,false)or SQ(H.Fishing_,false)or SQ(H.Pumpkin_,true)and workspace:GetAttribute("HalloweenWorldEvent")=="PumpkinMoon");
    end;
    local function BQ()local oQ=U();
    local U=oQ and oQ.GuardTutorialProgress;
    return oQ~=nil and(tonumber(oQ.SpeedPower)or 0)>=(q("HalloweenDimensionFlags","SpeedPowerRequirement")or 2500000)and type(U)=="table"and U.Completed==true;
    end;
    local function U()return workspace:FindFirstChild("HalloweenDimension");
    end;
    local function oQ(zQ)return function()local lQ=E();
    return lQ~=nil and zQ~=nil and(lQ.Position-zQ).Magnitude>12;
    end;
    end;
    local function zQ(lQ)if _()then return true;
    end;
    local hQ=R("HalloweenDimensionPortal");
    local iQ=hQ and(hQ:FindFirstChild("Hitbox",true));
    if iQ then if not(iQ:IsA("BasePart"))then VQ("Halloween portal is not here");
    return false;
    end;
    else VQ("Halloween portal is not here");
    return false;
    end;
    hQ=(E());
    while true do local aQ;
    if hQ then local IQ=V;
    aQ=IQ.InsideBase(hQ.Position);
    else aQ=hQ;
    end;
    local IQ;
    if aQ then local rQ=V;
    IQ=not rQ.InsideBase(iQ.Position);
    else IQ=aQ;
    end;
    aQ=nil;
    if IQ then local rQ=V;
    local mQ=rQ.IsNight();
    if mQ then aQ=mQ;
    else rQ=V;
    aQ=rQ.WallSealed();
    end;
    else aQ=IQ;
    end;
    if not aQ then break;
    end;
    VQ("Field wall is up, waiting to go to the Halloween portal");
    if not(g(1,lQ))then return false;
    end;
    hQ=(E());
    end;
    if not(n())then VQ("Getting off the treadmill first");
    return false;
    end;
    VQ("Teleporting to the Halloween portal");
    for n=1,3,1 do if n==3 then if not(b(iQ.Position+Vector3.new(0,3,0),lQ))then return false;
    end;
    end;
    hQ=iQ.Position;
    do
    local rootNow=E();
    local from=rootNow and rootNow.Position or hQ;
    local flat=Vector3.new(from.X-hQ.X,0,from.Z-hQ.Z);
    if flat.Magnitude<3 then local lv=iQ.CFrame.LookVector;
    flat=Vector3.new(lv.X,0,lv.Z);
    end;
    if flat.Magnitude<0.01 then flat=Vector3.new(0,0,1);
    end;
    flat=flat.Unit;
    local reach=math.max(iQ.Size.X,iQ.Size.Z)/2+6;
    local front=Vector3.new(hQ.X,hQ.Y,hQ.Z)+flat*reach;
    k(CFrame.lookAt(front,Vector3.new(hQ.X,front.Y,hQ.Z)));
    g(0.2,lQ);
    local t0,limit,tog=os.clock(),(n<3 and 4 or 10),false;
    while os.clock()-t0<limit and not _()and lQ()do
    tog=not tog;
    local inner=tog and hQ or(hQ-flat*2);
    k(CFrame.lookAt(inner,Vector3.new(hQ.X-flat.X*6,inner.Y,hQ.Z-flat.Z*6)));
    w(iQ);
    g(0.3,lQ);
    end;
    end;
    if _()then Y(oQ(hQ),6,lQ);
    pcall(V.UndoSwap);
    g(1.5,lQ);
    local n=j("HalloweenDimension");
    if type(n)=="table"then if n.TutorialSeen~=true then task.spawn(F,"RF/HalloweenDimension/AskTutorialSeen");
    end;
    end;
    return true;
    end;
    end;
    VQ("The Halloween portal did not take you");
    return false;
    end;
    local function n(lQ)for hQ=1,2,1 do if not(_())then return true;
    end;
    hQ=U();
    local iQ=hQ and(hQ:FindFirstChild("ExitPortal",true));
    local aQ=iQ and(iQ:FindFirstChild("Hitbox",true));
    if aQ then else iQ=hQ and(hQ:FindFirstChild("PortalHome",true));
    aQ=iQ and(iQ:FindFirstChild("Portal")or iQ:FindFirstChildWhichIsA("BasePart",true));
    end;
    if not(aQ)then break;
    end;
    VQ("Leaving the Halloween Dimension");
    k(CFrame.new(aQ.Position));
    iQ=aQ.Position;
    w(aQ);
    if Y(function()return not _();
    end,10,lQ)then Y(oQ(iQ),6,lQ);
    g(1.5,lQ);
    return true;
    end;
    end;
    return not _();
    end;
    local function oQ(lQ)H.Entering=true;
    local hQ=R("HalloweenDimensionPortal");
    local iQ=hQ and(hQ:FindFirstChild("Hitbox",true));
    if iQ then if iQ:IsA("BasePart")then iQ.CanTouch=true;
    end;
    end;
    iQ,hQ=pcall(zQ,lQ);
    H.Entering=false;
    if not iQ then error(hQ,0);
    end;
    return hQ;
    end;
    B=p;
    local function zQ()local lQ=R("HalloweenDimensionPortal");
    local hQ,iQ=lQ and(lQ:FindFirstChild("Hitbox",true)),V;
    lQ=iQ.Movement.Owner;
    local aQ,IQ=lQ~=nil and lQ~="halloween"and lQ~="train"and lQ~="invisibility"and lQ~="ghouler"and lQ~="islandwars";
    if aQ then IQ=aQ;
    else lQ=V;
    IQ=lQ.Steal.Active==true;
    end;
    aQ=nil;
    if IQ then aQ=IQ;
    else lQ=V;
    aQ=lQ.Steal.Carrying==true;
    end;
    lQ=nil;
    if aQ then lQ=aQ;
    else iQ=V;
    lQ=iQ.Flying==true;
    end;
    iQ=nil;
    if lQ then iQ=lQ;
    else IQ=V;
    iQ=(IQ.Driving or 0)>0;
    end;
    IQ=H.Entering==true or not iQ;
    if hQ then if hQ:IsA("BasePart")then if hQ.CanTouch~=IQ then hQ.CanTouch=IQ;
    end;
    end;
    end;
    end;
    local lQ,hQ=B.Heartbeat:Connect(zQ),K;
    hQ(function()lQ:Disconnect();
    local lQ=R("HalloweenDimensionPortal");
    local iQ=lQ and(lQ:FindFirstChild("Hitbox",true));
    if iQ then if iQ:IsA("BasePart")then iQ.CanTouch=true;
    end;
    end;
    end);
    local function lQ(iQ)local aQ=U();
    local IQ=aQ and(aQ:FindFirstChild("Zones"));
    aQ=IQ and(IQ:FindFirstChild(iQ));
    return aQ and aQ:IsA("BasePart")and aQ or nil;
    end;
    local function iQ(aQ,IQ,rQ)local mQ=aQ.CFrame:PointToObjectSpace(IQ);
    return math.abs(mQ.X)<=aQ.Size.X/2-(rQ or 0)and math.abs(mQ.Z)<=aQ.Size.Z/2-(rQ or 0);
    end;
    local function aQ(IQ)for rQ=3,1,-1 do local mQ=lQ("Zone"..rQ);
    if mQ then if iQ(mQ,IQ)then return rQ;
    end;
    end;
    end;
    return 0;
    end;
    local function IQ()local rQ,mQ=lQ("SafeZone"),E();
    if rQ then if not(mQ)then return nil;
    end;
    else return nil;
    end;
    local eQ,JQ,OQ=rQ.CFrame:PointToObjectSpace(mQ.Position),math.max(rQ.Size.X/2-6,0),math.max(rQ.Size.Z/2-6,0);
    local EQ=rQ.CFrame:PointToWorldSpace(Vector3.new(math.clamp(eQ.X,-JQ,JQ),eQ.Y,math.clamp(eQ.Z,-OQ,OQ)));
    return Vector3.new(EQ.X,mQ.Position.Y,EQ.Z),rQ;
    end;
    local rQ={};
    local function mQ(eQ)local JQ,OQ=eQ:GetAttribute("HalloweenEggUid"),eQ:GetAttribute("PreparedSourceName");
    H.Known=H.Known or{};
    if JQ then if OQ then H.Known[JQ]=OQ;
    end;
    end;
    local EQ=OQ or JQ and H.Known[JQ]or"Mystery Egg (Zone "..tostring(eQ:GetAttribute("Zone")or"?")..")";
    if EQ==nil then return rQ[EQ]or EQ;
    elseif rQ[EQ]then return rQ[EQ]or EQ;
    end;
    OQ=pcall(function()local eQ;
    local eQ,eQ=t,require(t.Data.HalloweenPets).Specs;
    rQ[EQ]=EQ;
    if not(eQ[EQ])then for JQ,NQ in next,eQ,nil do if type(NQ)=="table"then if NQ.EggSource==EQ then rQ[EQ]=NQ.Id or JQ;
    break;
    elseif NQ.EggModel==EQ then rQ[EQ]=NQ.Id or JQ;
    break;
    end;
    end;
    end;
    end;
    end);
    return OQ and rQ[EQ]or EQ;
    end;
    local function rQ(eQ)local JQ=S;
    local OQ,EQ=JQ.Assets;
    if OQ then JQ=S;
    EQ=JQ.Assets.Directory;
    else EQ=OQ;
    end;
    JQ=type(EQ)=="table"and EQ[eQ];
    H.Entries=H.Entries or{};
    if type(JQ)=="table"then H.Entries[eQ]=JQ;
    end;
    return H.Entries[eQ];
    end;
    local function eQ(JQ)local OQ=rQ(mQ(JQ));
    local EQ,NQ,xQ=OQ~=nil,OQ and OQ.EarningRate,JQ:IsA("Model")and JQ:GetScale()or 1;
    OQ=xQ>5 and(xQ/5)^1.2*19.637875755794113 or xQ^1.85;
    return(EQ and tonumber(NQ)or 0)*OQ;
    end;
    local function JQ(OQ)local EQ=mQ(OQ);
    if next(H.EggNames)~=nil then if not(H.EggNames[EQ])then return false;
    end;
    end;
    local NQ=H.MinValue;
    if NQ then if NQ>0 then if eQ(OQ)<H.MinValue then return false;
    end;
    end;
    end;
    if next(H.EggRarities)~=nil then NQ=rQ(EQ);
    OQ=NQ and type(NQ.Rarity)=="table"and NQ.Rarity._id;
    return OQ~=nil and H.EggRarities[OQ]==true;
    end;
    return true;
    end;
    local function rQ()local OQ,EQ=U(),E();
    local NQ=OQ and(OQ:FindFirstChild("WorldEggs"));
    if NQ then if not(EQ)then return nil;
    end;
    else return nil;
    end;
    for xQ,xQ in ipairs(H.Pick and NQ:GetChildren()or{})do OQ=xQ:FindFirstChild("StealPrompt",true);
    if xQ:GetAttribute("HalloweenEggUid")==H.Pick then if OQ then if OQ.Enabled then return xQ,aQ(c(xQ));
    end;
    end;
    end;
    end;
    H.Pick=nil;
    local xQ,FQ,dQ,QQ;
    for jQ,qQ in ipairs(NQ:GetChildren())do jQ=qQ:FindFirstChild("StealPrompt",true);
    if jQ then if jQ:IsA("ProximityPrompt")then if jQ.Enabled then if(H.Bad[qQ]or 0)<os.clock()then if JQ(qQ)then OQ=c(qQ);
    local NQ=OQ and(aQ(OQ));
    if NQ then if NQ>=1 then local NQ,jQ,RQ=(OQ-EQ.Position).Magnitude,eQ(qQ),(H.OrderIndex or{})[qQ:GetAttribute("HalloweenEggUid")]or 1/0;
    if(if xQ then RQ<FQ else not xQ)or RQ==FQ and(jQ>dQ or jQ==dQ and NQ<QQ)then xQ,FQ,dQ,QQ=qQ,RQ,jQ,NQ;
    else end;
    else end;
    else end;
    else end;
    else end;
    else end;
    else end;
    else end;
    end;
    return xQ,xQ and aQ(c(xQ))or 0;
    end;
    local function OQ(EQ,NQ)local xQ=U();
    local FQ=xQ and(xQ:FindFirstChild("WorldEggs"));
    task.spawn(F,"RF/HalloweenDimension/AskDropEgg");
    local dQ,QQ=os.clock(),false;
    while NQ()and os.clock()-dQ<3 do if J("HalloweenCarrying")~=true then QQ=true;
    else if QQ then return true;
    end;
    end;
    xQ=nil;
    for NQ,NQ in ipairs(FQ and FQ:GetChildren()or{})do xQ=if NQ:GetAttribute("HalloweenEggUid")==EQ then NQ else xQ;
    end;
    local EQ=xQ and(xQ:FindFirstChild("StealPrompt",true));
    if QQ then if EQ then if EQ.Enabled then k(CFrame.new(c(xQ)+Vector3.new(0,3,0)));
    L(EQ);
    end;
    end;
    end;
    O();
    end;
    end;
    local function EQ(NQ,xQ)local FQ=os.clock()+15;
    while xQ()and J("HalloweenCarrying")==true and os.clock()<FQ do local xQ=E();
    if not(xQ)then return;
    end;
    local FQ=Vector3.new(NQ.X,xQ.Position.Y,NQ.Z)-xQ.Position;
    if FQ.Magnitude<2 then return true;
    end;
    k(CFrame.new(xQ.Position+FQ.Unit*math.min(FQ.Magnitude,H.Step or 40)));
    O();
    end;
    end;
    local function NQ(xQ)local FQ=J("HalloweenDelivered");
    local dQ,QQ,jQ,qQ,RQ,AQ=os.clock()+60,{},H.CarryUid,SQ(H.Instant_,true),lQ("SafeZone"),E();
    VQ("Carrying the Halloween egg to safety");
    if qQ and jQ and RQ and AQ and J("HalloweenCarrying")==true then local cQ,kQ,wQ=RQ.CFrame:PointToObjectSpace(AQ.Position),RQ.Size.X/2+10,RQ.Size.Z/2+10;
    VQ("Carrying: instant steal");
    local LQ=RQ.CFrame:PointToWorldSpace(Vector3.new(math.clamp(cQ.X,-kQ,kQ),0,math.clamp(cQ.Z,-wQ,wQ)));
    EQ(LQ,xQ);
    for kQ=1,4,1 do kQ,wQ=os.clock()+0.8,false;
    while xQ()and J("HalloweenCarrying")==true and os.clock()<kQ do cQ=E();
    if cQ and A(cQ.Position-LQ).Magnitude>=100 then wQ=true;
    break;
    end;
    O();
    end;
    if not wQ then break;
    end;
    VQ("Pulled back, stepping to the safe zone edge again");
    EQ(LQ,xQ);
    end;
    if OQ(jQ,xQ)then g(0.5,xQ);
    end;
    end;
    RQ=nil;
    while xQ()and J("HalloweenCarrying")==true and os.clock()<dQ do local OQ,EQ,xQ=E(),lQ("SafeZone"),e.Character;
    if OQ then if EQ then if not(xQ)then break;
    end;
    else break;
    end;
    else break;
    end;
    RQ=RQ or OQ.Position.Y;
    for cQ,cQ in ipairs(xQ:GetDescendants())do if cQ:IsA("BasePart")then if cQ.CanCollide then QQ[cQ]=true;
    cQ.CanCollide=false;
    end;
    end;
    end;
    xQ,jQ=EQ.CFrame:PointToObjectSpace(OQ.Position),qQ and 6 or 40;
    local cQ,kQ=math.max(EQ.Size.X/2-jQ,0),math.max(EQ.Size.Z/2-jQ,0);
    AQ=A(EQ.CFrame:PointToWorldSpace(Vector3.new(math.clamp(xQ.X,-cQ,cQ),xQ.Y,math.clamp(xQ.Z,-kQ,kQ)))-OQ.Position);
    OQ.AssemblyLinearVelocity=(AQ.Magnitude>3 and AQ.Unit*math.min(x()*(qQ and 1 or 1.5),AQ.Magnitude/0.05)or Vector3.new(0.0,0.0,0.0))+Vector3.new(0,(RQ-OQ.Position.Y)*8,0);
    O();
    end;
    RQ=E();
    if RQ then RQ.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
    end;
    for OQ in next,QQ,nil do if OQ.Parent then OQ.CanCollide=true;
    end;
    end;
    if J("HalloweenCarrying")==true then if os.clock()>=dQ then F("RF/HalloweenDimension/AskDropEgg");
    end;
    end;
    Y(function()return J("HalloweenDelivered")~=FQ;
    end,0.6);
    if J("HalloweenDelivered")~=FQ then H.Eggs=H.Eggs+1;
    H.DeliveredAt=os.clock();
    VQ("Halloween egg secured");
    pcall(function()
        local eggName=H.Known and jQ and H.Known[jQ]or"Egg";
        V.ActSource={label="Egg "..tostring(eggName),at=os.clock()};
        V.LogActivity("halloween","Egg diamankan: "..tostring(eggName),1);
    end);
    end;
    end;
    local OQ=V;
    OQ.HalloweenEggs=function()local OQ,EQ,xQ=U(),{},H.Current;
    if xQ then xQ.Current=true;
    EQ[1]=xQ;
    end;
    local FQ=OQ and(OQ:FindFirstChild("WorldEggs"));
    for OQ,OQ in ipairs(FQ and FQ:GetChildren()or{})do local FQ,dQ,QQ=OQ:GetAttribute("HalloweenEggUid"),OQ:FindFirstChild("StealPrompt",true),c(OQ);
    if FQ then if QQ then if dQ then if dQ.Enabled then if not(xQ and xQ.Uid==FQ)then EQ[#EQ+1]={Uid=FQ,Name=mQ(OQ),Value=eQ(OQ),Zone=aQ(QQ),Scale=OQ:IsA("Model")and OQ:GetScale()or 1,Target=JQ(OQ)and aQ(QQ)>=1,Picked=H.Pick==FQ,Order=(H.OrderIndex or{})[FQ]};
    end;
    end;
    end;
    end;
    end;
    end;
    return EQ;
    end;
    local aQ=V;
    aQ.HalloweenPick=function(aQ)H.Pick=aQ;
    if aQ==nil then return;
    end;
    if not(SQ(H.Eggs_,false))then pcall(H.Eggs_.Set,H.Eggs_,true);
    end;
    aQ=V;
    aQ.Notify("Halloween","Stealing this Halloween egg next");
    UQ();
    end;
    local function aQ(JQ)return C(NQ,JQ);
    end;
    local function JQ(OQ)local EQ,NQ=rQ();
    if not EQ then return false;
    end;
    local xQ=EQ:FindFirstChild("StealPrompt",true);
    VQ("Going to a zone "..NQ.." Halloween egg");
    local function FQ()return OQ()and EQ.Parent~=nil and xQ.Enabled and J("HalloweenCarrying")~=true;
    end;
    local dQ=EQ:GetAttribute("HalloweenEggUid");
    H.Stealing=true;
    H.Current={Uid=dQ,Name=mQ(EQ),Value=eQ(EQ),Zone=NQ,Scale=EQ:IsA("Model")and EQ:GetScale()or 1};
    for mQ=1,3,1 do NQ=c(EQ);
    if NQ then if not(FQ())then break;
    end;
    else break;
    end;
    if SQ(H.Instant_,true)then mQ=os.clock()+3;
    while FQ()and os.clock()<mQ do local QQ,jQ=E(),c(EQ);
    if QQ then if not(jQ)then break;
    end;
    else break;
    end;
    local qQ=jQ+Vector3.new(0,3,0)-QQ.Position;
    if qQ.Magnitude<3 then break;
    end;
    k(CFrame.new(QQ.Position+qQ.Unit*math.min(qQ.Magnitude,H.Step or 40)));
    O();
    end;
    end;
    mQ=E();
    if if mQ then(mQ.Position-NQ).Magnitude>20 else not mQ then if not(D(NQ+Vector3.new(0,3,0),FQ))then break;
    end;
    end;
    local NQ,QQ=os.clock()+4,0;
    while FQ()and os.clock()<NQ do mQ=c(EQ);
    if mQ then k(CFrame.new(mQ+Vector3.new(0,3,0)));
    end;
    if os.clock()-QQ>0.1 then QQ=os.clock();
    L(xQ);
    else end;
    O();
    end;
    if J("HalloweenCarrying")==true then break;
    end;
    end;
    if J("HalloweenCarrying")==true then if H.Pick==dQ then H.Pick=nil;
    end;
    H.CarryUid=dQ;
    aQ(OQ);
    elseif EQ.Parent then H.Bad[EQ]=os.clock()+30;
    end;
    H.Current=nil;
    H.Stealing=false;
    return true;
    end;
    local function mQ(OQ)local EQ=IQ();
    if not(EQ)then return;
    end;
    VQ("Low health, healing in the safe zone");
    D(EQ,OQ);
    Y(function()local EQ=N();
    return if EQ then EQ.Health>=EQ.MaxHealth*0.85 else not EQ;
    end,25,OQ);
    end;
    local function OQ()local EQ=V;
    local NQ,xQ=EQ.Combat,e.Character;
    return type(NQ)=="table"and xQ and type(NQ.PickBat)=="function"and NQ.PickBat(xQ)or nil;
    end;
    Q("RE/HalloweenDimension/MonsterHit",function()H.HitAt=os.clock();
    end);
    local function EQ(NQ)local xQ,FQ=RaycastParams.new(),U();
    xQ.FilterType=Enum.RaycastFilterType.Exclude;
    xQ.FilterDescendantsInstances={e.Character,FQ and FQ:FindFirstChild("Monsters"),FQ and FQ:FindFirstChild("Ghosts")};
    FQ=workspace:Raycast(NQ+Vector3.new(0,25,0),Vector3.new(0,-80,0),xQ);
    return FQ and Vector3.new(NQ.X,FQ.Position.Y+3,NQ.Z)or NQ;
    end;
    local function NQ()local xQ,FQ,dQ,QQ=next(H.Weapons)~=nil and H.Weapons or H.ToolIds,e.Character,{},ipairs;
    local jQ={FQ,e:FindFirstChildOfClass("Backpack")};
    for qQ,qQ in QQ(jQ)do for RQ,AQ in ipairs(qQ and qQ:GetChildren()or{})do RQ=AQ:IsA("Tool")and(AQ:GetAttribute("GearName")or AQ.Name);
    if RQ then if xQ[RQ]then if H.ToolIds[RQ]then dQ[#dQ+1]=AQ;
    end;
    end;
    end;
    end;
    end;
    if#dQ==0 then return OQ();
    end;
    table.sort(dQ,function(qQ,RQ)return qQ.Name<RQ.Name;
    end);
    local function qQ(RQ)return tonumber(RQ:GetAttribute("CooldownEndTime"))or 0;
    end;
    jQ=FQ and(FQ:FindFirstChildOfClass("Tool"));
    xQ,FQ=jQ and table.find(dQ,jQ),dQ[1];
    if xQ then QQ=os.clock()-(H.WeaponAt or 0)>=0.5 or qQ(jQ)~=H.WeaponCooldown;
    if#dQ==1 then return jQ;
    elseif QQ then else return jQ;
    end;
    local QQ;
    for jQ=1,#dQ-1,1 do local RQ=dQ[(xQ+jQ-1)%#dQ+1];
    jQ=qQ(RQ)-workspace:GetServerTimeNow();
    if jQ<=0 then FQ=RQ;
    break;
    end;
    if QQ then if jQ<QQ then FQ,QQ=RQ,jQ;
    else end;
    else FQ,QQ=RQ,jQ;
    end;
    end;
    else end;
    H.WeaponAt,H.WeaponCooldown=os.clock(),qQ(FQ);
    return FQ;
    end;
    local function xQ(FQ,dQ)local QQ,jQ=E(),N();
    if QQ then if not(jQ)then return;
    end;
    else return;
    end;
    local qQ=A(FQ-QQ.Position);
    H.WalkSpeed0=H.WalkSpeed0 or jQ.WalkSpeed;
    local RQ=FQ.Y-QQ.Position.Y;
    local AQ=RQ>2 and math.min(RQ*6,40)or math.min(QQ.AssemblyLinearVelocity.Y,8);
    if qQ.Magnitude>2 then RQ=RaycastParams.new();
    RQ.FilterType,RQ.FilterDescendantsInstances=Enum.RaycastFilterType.Exclude,{e.Character};
    local cQ,kQ,wQ=workspace,QQ.Position+qQ.Unit*math.min(qQ.Magnitude,6)+Vector3.new(0,5,0),Vector3.new(0,-40,0);
    if not(cQ:Raycast(kQ,wQ,RQ))then jQ:MoveTo(QQ.Position);
    QQ.AssemblyLinearVelocity=Vector3.new(0,math.min(QQ.AssemblyLinearVelocity.Y,0),0);
    return;
    end;
    jQ.WalkSpeed=dQ;
    jQ:MoveTo(Vector3.new(FQ.X,QQ.Position.Y,FQ.Z));
    QQ.AssemblyLinearVelocity=qQ.Unit*math.min(dQ,qQ.Magnitude/0.05)+Vector3.new(0,AQ,0);
    else jQ:MoveTo(QQ.Position);
    QQ.AssemblyLinearVelocity=Vector3.new(0,AQ,0);
    end;
    end;
    local function FQ()local dQ,QQ=N(),E();
    if QQ then QQ.AssemblyLinearVelocity=Vector3.new(0,math.min(QQ.AssemblyLinearVelocity.Y,0),0);
    end;
    if dQ then dQ:MoveTo(QQ and QQ.Position or dQ.WalkToPoint);
    if H.WalkSpeed0 then dQ.WalkSpeed=H.WalkSpeed0;
    H.WalkSpeed0=nil;
    end;
    end;
    end;
    local function dQ(QQ,jQ,qQ)local RQ=os.clock()+25;
    while jQ()and os.clock()<RQ do local RQ=E();
    if RQ then if A(QQ-RQ.Position).Magnitude<3 then if QQ.Y-RQ.Position.Y<2 then break;
    end;
    end;
    else break;
    end;
    xQ(QQ,qQ);
    O();
    end;
    FQ();
    return jQ();
    end;
    local function QQ(jQ)return C(JQ,jQ);
    end;
    local function JQ(jQ)local qQ,RQ=OQ(),N();
    if not(qQ)then VQ("Get a bat to fight monsters");
    return false;
    end;
    if RQ then if RQ.Health<RQ.MaxHealth*0.4 then mQ(jQ);
    return true;
    end;
    end;
    RQ=E();
    if not RQ then return false;
    end;
    local mQ=lQ("SafeZone");
    local lQ;
    local OQ,AQ,cQ={Small=12,Medium=28,Large=65},ipairs;
    local cQ=o;
    local kQ,wQ=table.pack(cQ:GetTagged("HalloweenMonster")),1/0;
    for LQ,ZQ in AQ(table.unpack(kQ, 1, kQ.n))do cQ=ZQ:IsDescendantOf(workspace)and ZQ:GetAttribute("KilledBy")==nil and(next(H.MonsterKinds)==nil or H.MonsterKinds[ZQ.Name])and(c(ZQ));
    LQ=cQ and(cQ-RQ.Position).Magnitude;
    local v=LQ and(H.MonsterOrder=="Most Tokens"and LQ-(OQ[ZQ:GetAttribute("MonsterSize")]or 0)*1000 or LQ);
    if v and v<wQ and not(mQ and iQ(mQ,cQ))then lQ=ZQ;
    wQ=v;
    else end;
    end;
    wQ=lQ and(c(lQ)-RQ.Position).Magnitude or wQ;
    if not lQ then return false;
    end;
    VQ("Fighting a "..tostring(lQ:GetAttribute("MonsterSize")or"Halloween").." monster");
    pcall(function()
        if H.LoggedMonster~=lQ then
            H.LoggedMonster=lQ;
            V.ActSource={label=lQ.Name,at=os.clock()};
            V.LogActivity("monster","Menuju "..lQ.Name.." ("..tostring(lQ:GetAttribute("MonsterSize")or"?")..")",0);
        end;
    end);
    local function v()local RQ=N();
    return jQ()and lQ.Parent~=nil and lQ:GetAttribute("KilledBy")==nil and J("HalloweenCarrying")~=true and(if RQ then RQ.Health>=RQ.MaxHealth*0.4 else not RQ);
    end;
    if wQ>30 then if not(dQ(EQ(c(lQ)),v,H.MonsterSpeed))then return true;
    end;
    end;
    OQ=os.clock()+15;
    while v()and os.clock()<OQ do kQ,AQ=c(lQ),E();
    if kQ then if not AQ then break;
    end;
    else break;
    end;
    mQ=A(AQ.Position-kQ);
    xQ(EQ(kQ+(mQ.Magnitude>0.1 and mQ.Unit or Vector3.new(0,0,1))*4),H.MonsterSpeed);
    P(kQ);
    cQ=NQ()or qQ;
    G(cQ);
    if not(H.BatIds[cQ:GetAttribute("GearName")or cQ.Name])then if cQ.Parent==e.Character then if workspace:GetServerTimeNow()>=(tonumber(cQ:GetAttribute("CooldownEndTime"))or 0)then if os.clock()-(H.TriggerAt or 0)>0.1 then if os.clock()-(H.WeaponAt or 0)>0.15 then H.TriggerAt=os.clock();
    d("RE/ToolTrigger/Trigger",cQ);
    end;
    end;
    end;
    end;
    end;
    O();
    end;
    FQ();
    if lQ:GetAttribute("KilledBy")==e.UserId then H.Kills=H.Kills+1;
    pcall(function()
        V.ActSource={label=lQ.Name,at=os.clock()};
        V.LogActivity("monster","Bunuh "..lQ.Name.." ("..tostring(lQ:GetAttribute("MonsterSize")or"?")..")",1);
    end);
    end;
    return true;
    end;
    local function v(lQ)return C(JQ,lQ);
    end;
    local function lQ(mQ)local JQ=U();
    if not(JQ)then return false;
    end;
    local OQ=JQ:FindFirstChild("Altar");
    OQ=OQ and(OQ:FindFirstChild("PumpkinDeposit"));
    if J("HalloweenPumpkinCarrying")==true then VQ("Bringing a pumpkin to the altar");pcall(function()V.ActSource={label="Pumpkin",at=os.clock()};V.LogActivity("halloween","Pumpkin Moon: bawa labu ke altar",0,10);end);
    if OQ and OQ:GetAttribute("Open")~=false then local function EQ()return mQ()and J("HalloweenPumpkinCarrying")==true;
    end;
    C(dQ,(c(OQ:FindFirstChild("Target"))or OQ.Position)+Vector3.new(0,3,0),EQ,H.PumpkinSpeed);
    for NQ=1,4,1 do if not(EQ())then break;
    end;
    k(CFrame.new(OQ.Position+Vector3.new(0,3,0)));
    w(OQ);
    L(OQ:FindFirstChildWhichIsA("ProximityPrompt",true));
    g(0.3,EQ);
    end;
    else g(0.5,mQ);
    end;
    return true;
    end;
    local w,OQ,EQ,NQ=JQ:FindFirstChild("RunawayPumpkins"),E(),1/0;
    for jQ,qQ in ipairs(w and w:GetChildren()or{})do JQ=qQ:IsA("Model")and qQ:FindFirstChild("CatchPrompt",true);
    jQ=JQ and JQ.Enabled and c(qQ);
    local RQ=jQ and OQ and(jQ-OQ.Position).Magnitude;
    if RQ then if RQ<EQ then EQ,NQ=RQ,qQ;
    else end;
    else end;
    end;
    if not(NQ)then VQ("Pumpkin Moon: looking for pumpkins");
    return false;
    end;
    VQ("Pumpkin Moon: catching a pumpkin");pcall(function()V.LogActivity("halloween","Pumpkin Moon: menangkap labu",0,10);end);
    JQ=os.clock()+10;
    H.Move=true;
    while mQ()and NQ.Parent and(NQ:FindFirstChild("CatchPrompt",true))and os.clock()<JQ and J("HalloweenPumpkinCarrying")~=true do OQ,w=c(NQ),E();
    if OQ then if not w then break;
    end;
    else break;
    end;
    local mQ,EQ=OQ-w.Position,NQ:FindFirstChild("CatchPrompt",true);
    if EQ then if EQ:IsA("ProximityPrompt")then if mQ.Magnitude<=EQ.MaxActivationDistance+2 then L(EQ);
    end;
    end;
    end;
    xQ(OQ,H.PumpkinSpeed);
    O();
    end;
    H.Move=false;
    X(false);
    FQ();
    JQ=E();
    if JQ then JQ.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
    end;
    return true;
    end;
    local function w(mQ)local JQ=U();
    local U=JQ and(JQ:FindFirstChild("GhostDogQuest"));
    JQ=U and(U:FindFirstChild("Markers"));
    U=JQ and(JQ:FindFirstChild(mQ));
    return U and U:IsA("BasePart")and U or nil;
    end;
    local function U(mQ,JQ)local OQ=w(mQ);
    return OQ~=nil and D(OQ.Position+Vector3.new(0,3,0),JQ);
    end;
    local function mQ(JQ,OQ,EQ)local NQ,xQ;
    for FQ=1,3,1 do local FQ,jQ;
    FQ,FQ,jQ=F("RF/GhostDogQuest/Talk",OQ);
    if FQ then NQ,xQ=FQ,jQ;
    break;
    elseif type(jQ)=="string"then if not(jQ:lower():find("closer"))then NQ,xQ=FQ,jQ;
    break;
    end;
    else NQ,xQ=FQ,jQ;
    break;
    end;
    U(JQ,EQ);
    g(0.4,EQ);
    NQ,xQ=FQ,jQ;
    end;
    return NQ,xQ;
    end;
    local function JQ()local OQ=j("GhostDogQuest");
    return type(OQ)=="table"and tonumber(OQ.Stage)or 0,type(OQ)=="table"and OQ or{};
    end;
    local function OQ()return Z(function(EQ)return EQ:GetAttribute("GhostDogRod")==true;
    end);
    end;
    local function EQ()local NQ,xQ=JQ();
    local FQ=0;
    for jQ in next,type(xQ.Artifacts)=="table"and xQ.Artifacts or{},nil do FQ+=1;
    end;
    return NQ*10+FQ+(OQ()and 5 or 0);
    end;
    local function NQ(xQ,FQ,jQ)local qQ;
    local qQ,qQ,RQ=t,pcall(require,t.Data.GhostDogQuest);
    local function AQ(cQ)local kQ,wQ=pcall(RQ.ChaseFrame,xQ,cQ);
    return kQ and typeof(wQ)=="CFrame"and wQ or nil;
    end;
    if qQ then if type(RQ)=="table"then if not(AQ(0))then return false;
    end;
    else return false;
    end;
    else return false;
    end;
    H.Chase=true;
    VQ("Ghost Dog: underwater chase");
    local xQ,RQ=pcall(function()Y(function()local cQ,kQ=E(),AQ(0);
    return cQ and kQ and(cQ.Position-kQ.Position).Magnitude<40;
    end,8,jQ);
    local cQ,kQ=N(),CFrame.Angles(-1.2566,0,0);
    if cQ then cQ.PlatformStand=true;
    end;
    cQ=os.clock()+4;
    while jQ()and os.clock()<cQ do k(AQ(0)*kQ);
    O();
    end;
    local wQ,LQ=q("GhostDogQuestFlags","ChaseSpeed")or 58,os.clock();
    cQ=FQ*wQ;
    while jQ()and J("GhostDogChase")~=nil do local FQ=math.min((os.clock()-LQ)*wQ,cQ);
    local jQ=AQ(FQ);
    if jQ then k(jQ*kQ);
    end;
    if FQ>=cQ then break;
    end;
    O();
    end;
    wQ=false;
    for FQ=1,8,1 do local jQ,jQ=F("RF/GhostDogQuest/Claim");
    if jQ==true then wQ=true;
    break;
    end;
    if FQ==4 then LQ=os.clock()+5;
    while os.clock()<LQ do jQ=AQ(cQ);
    if jQ then k(jQ*kQ);
    end;
    O();
    end;
    else task.wait(0.7);
    end;
    end;
    task.wait(wQ and 3 or 0.5);
    for FQ=1,3,1 do kQ,FQ=F("RF/GhostDogQuest/Surface");
    if FQ==true then break;
    end;
    task.wait(0.5);
    end;
    Y(function()local FQ,jQ=w("ReturnSpot"),E();
    return if FQ then jQ and(jQ.Position-FQ.Position).Magnitude<25 else not FQ;
    end,6);
    return wQ;
    end);
    qQ=N();
    if qQ then qQ.PlatformStand=false;
    end;
    F("RF/GhostDogQuest/Abort");
    H.Chase=false;
    return xQ and RQ;
    end;
    local function xQ(FQ)local jQ;
    local jQ,jQ,qQ=t,pcall(require,t.Controllers.Game.FishingController[FQ]);
    return jQ and qQ or nil;
    end;
    local function FQ(jQ,qQ)if not(E())then return nil;
    end;
    P(jQ);
    local RQ,AQ=1.2*H.Charge^0.7142857142857143,xQ("Ui");
    local cQ;
    local cQ,cQ,kQ=t,pcall(require,t.Shared.Util.Fishing);
    local wQ,wQ,LQ=t,pcall(require,t.Shared.Flags.FishingFlags);
    d("RE/Fishing/Hold");
    local ZQ,GQ=os.clock(),false;
    while os.clock()-ZQ<RQ do if not(qQ())then if AQ then pcall(AQ.ShowCharge,false);
    end;
    return nil;
    end;
    local gQ=(os.clock()-ZQ-RQ+0.25)/0.2;
    if AQ then if cQ then if gQ>=0 then if GQ then else pcall(AQ.ShowCharge,true,wQ and LQ.PerfectMin:Get()or 0.8,wQ and LQ.PerfectMax:Get()or 0.95);
    GQ=true;
    end;
    local GQ,YQ,PQ=kQ.ChargeAt(RQ)*math.min(gQ,1),e.Character and e.Character:FindFirstChild("Head"),workspace.CurrentCamera;
    local gQ=YQ and PQ:WorldToViewportPoint(YQ.Position);
    pcall(AQ.SetCharge,GQ,kQ.LuckText(kQ.LuckFor(GQ)),kQ.IsPerfect(GQ),gQ and Vector2.new(gQ.X/PQ.ViewportSize.X,gQ.Y/PQ.ViewportSize.Y));
    else end;
    else end;
    else end;
    O();
    end;
    if AQ then pcall(AQ.ShowCharge,false);
    qQ=e.Character and e.Character:FindFirstChild("Head");
    if qQ then if cQ then if kQ.IsPerfect(kQ.ChargeAt(RQ))then wQ=workspace.CurrentCamera;
    ZQ=wQ:WorldToViewportPoint(qQ.Position+Vector3.new(0,2.6,0));
    pcall(AQ.Perfect,Vector2.new(ZQ.X/wQ.ViewportSize.X,ZQ.Y/wQ.ViewportSize.Y));
    end;
    end;
    end;
    end;
    LQ,cQ,kQ=F("RF/Fishing/Cast",RQ,jQ);
    if type(cQ)~="table"then VQ("Fishing: "..tostring(kQ or"no answer"));
    end;
    return type(cQ)=="table"and cQ or nil,kQ;
    end;
    local function jQ(qQ,RQ,AQ)if not(g(3.5,AQ))then F("RF/GhostDogQuest/Abort");
    return false;
    end;
    F("RF/GhostDogQuest/Dive");
    return NQ(qQ,RQ,AQ);
    end;
    local function NQ(qQ,RQ)if not(g((tonumber(qQ.Wait)or 3)+0.45,RQ))then return;
    end;
    local AQ,AQ=F("RF/GhostDogQuest/Cast",qQ.Id);
    if type(AQ)~="number"then F("RF/GhostDogQuest/Abort");
    return;
    end;
    if jQ(AQ,q("GhostDogQuestFlags","FishChaseSeconds")or 25,RQ)then qQ=V;
    qQ.Notify("Fishing","Caught a Ghost Fish!");
    end;
    end;
    local function qQ(RQ)local AQ,cQ=JQ();
    local kQ=EQ();
    local wQ;
    VQ("Ghost Dog quest: "..(r[AQ+1]or"Done"));
    if AQ==0 then if U("DogSpot",RQ)then wQ=mQ("DogSpot","Dog",RQ);
    Y(function()return JQ()>=1;
    end,5,RQ);
    else end;
    else if AQ==1 then local LQ,ZQ={"Collar","Bone","Toy","Photo"},true;
    for GQ,GQ in ipairs(LQ)do if type(cQ.Artifacts)=="table"and cQ.Artifacts[GQ]then else ZQ=false;
    if RQ()then if U("Artifact_"..GQ,RQ)then g(0.3,RQ);
    local cQ,cQ=F("RF/GhostDogQuest/Collect",GQ);
    g(0.5,RQ);
    wQ=cQ;
    else end;
    else end;
    end;
    end;
    if ZQ then if U("DogSpot",RQ)then LQ=mQ("DogSpot","Dog",RQ);
    Y(function()return JQ()>=2;
    end,5,RQ);
    wQ=LQ;
    else end;
    else end;
    else local cQ=AQ==2 or AQ==3 and not OQ();
    if cQ then if U("FishermanSpot",RQ)then wQ=mQ("FishermanSpot","Fisherman",RQ);
    if wQ=="FisherReunion"or wQ=="FisherHint"then g(2.5,RQ);
    wQ=mQ("FishermanSpot","Rod",RQ);
    Y(function()return OQ()~=nil;
    end,5,RQ);
    else end;
    else end;
    else if AQ==3 then local mQ=w("CastTarget");
    if mQ then if U("CastSpot",RQ)then G(OQ());
    g(0.5,RQ);
    local U=FQ(mQ.Position,RQ);
    if U and U.Mode=="Quest"then g((tonumber(U.Wait)or 3)+0.45,RQ);
    d("RE/Fishing/Cancel",U.Id);
    local mQ,mQ=F("RF/GhostDogQuest/Cast");
    if type(mQ)=="number"then if jQ(mQ,q("GhostDogQuestFlags","ChaseSeconds")or 50,RQ)then local q=V;
    q.Notify("Ghost Dog","Phantom Express Ticket unlocked");
    end;
    end;
    elseif U then if U.Id then d("RE/Fishing/Cancel",U.Id);
    end;
    end;
    end;
    end;
    end;
    end;
    end;
    end;
    if EQ()==kQ then H.DogAt=os.clock()+20;
    if type(wQ)=="string"then VQ("Ghost Dog: "..wQ);
    end;
    end;
    return true;
    end;
    local function U(q)local mQ=RaycastParams.new();
    mQ.FilterType=Enum.RaycastFilterType.Exclude;
    local EQ={e.Character};
    for jQ=1,6,1 do mQ.FilterDescendantsInstances=EQ;
    jQ=workspace:Raycast(q+Vector3.new(0,40,0),Vector3.new(0,-180,0),mQ);
    if not jQ then return nil;
    end;
    local q=jQ.Instance;
    if jQ.Material==Enum.Material.Water then return jQ.Position;
    elseif q:GetAttribute("TerrainRole")=="Basin"then return jQ.Position;
    elseif q:GetAttribute("FishingWater")then return jQ.Position;
    else local mQ;
    local mQ=o;
    if mQ:HasTag(q,"FishingWater")then return jQ.Position;
    end;
    end;
    if q:IsA("BasePart")then if not(q.Transparency>=0.95)then return nil;
    end;
    else return nil;
    end;
    EQ[#EQ+1]=q;
    end;
    return nil;
    end;
    local function o(q,mQ)local EQ,jQ,RQ=RaycastParams.new(),{},y;
    for y,y in ipairs(RQ:GetPlayers())do if y.Character then table.insert(jQ,y.Character);
    end;
    end;
    EQ.FilterType=Enum.RaycastFilterType.Exclude;
    EQ.FilterDescendantsInstances=jQ;
    EQ.RespectCanCollide=true;
    jQ,RQ=workspace:Raycast(q.Position+Vector3.new(0,4,0),Vector3.new(0,-20,0),EQ),N();
    EQ=jQ and jQ.Position.Y+(RQ and RQ.HipHeight or 2)+q.Size.Y/2 or q.Position.Y;
    jQ=Vector3.new(q.Position.X,EQ,q.Position.Z);
    if RQ then RQ:Move((Vector3.new(0.0,0.0,0.0)));
    RQ:MoveTo(jQ);
    end;
    return CFrame.lookAt(jQ,Vector3.new(mQ.X,EQ,mQ.Z));
    end;
    local y;
    local function q(mQ)local EQ,jQ=pcall(y,mQ);
    H.FishPin=nil;
    if not(EQ)then error(jQ,0);
    end;
    return jQ;
    end;
    y=function(y)if JQ()==3 then VQ("Ghost Dog quest blocks fishing, casting at the ripples");
    return qQ(y);
    end;
    local mQ,EQ=0,false;
    local function jQ()if SQ(H.Eggs_,false)then if HQ("Eggs")<HQ("Fishing")then if os.clock()>=mQ then local RQ,AQ=os.clock()+0.5,rQ()~=nil;
    mQ,EQ=RQ,AQ;
    end;
    end;
    end;
    local mQ=y()and not EQ;
    return mQ;
    end;
    local y=OQ();
    if y then if H.FishAt-os.clock()>5 then return false;
    end;
    else return false;
    end;
    if os.clock()<H.FishAt then g(H.FishAt-os.clock(),jQ);
    return true;
    end;
    local mQ=E();
    if not(mQ)then return false;
    end;
    local OQ=w("ReturnSpot");
    if OQ and(A(mQ.Position-OQ.Position).Magnitude>8 or OQ.Position.Y+1>mQ.Position.Y)then VQ("Going to the fishing spot");
    return C(dQ,OQ.Position+Vector3.new(0,3,0),jQ,300);
    end;
    local C,EQ=w("CastTarget"),workspace:FindFirstChild("GhostFisherman");
    local dQ;
    local RQ=EQ and EQ:IsA("Model")and EQ:GetPivot().LookVector or OQ and OQ.CFrame.LookVector or Vector3.new(0,0,-1);
    OQ=math.atan2(RQ.Z,RQ.X);
    for AQ=0,12,1 do EQ=OQ+(AQ%2==0 and 1 or-1)*math.ceil(AQ/2)*3.141592653589793/18;
    AQ=U(mQ.Position+Vector3.new(math.cos(EQ),0,math.sin(EQ))*(10+32*H.Charge));
    if AQ and not(C and A(AQ-C.Position).Magnitude<12)then dQ=AQ;
    break;
    end;
    end;
    if not dQ then VQ("Looking for water to fish");
    g(1,jQ);
    return true;
    end;
    H.FishPin=o(mQ,dQ);
    VQ("Casting ("..tostring(H.LuckName or"x1.5 Perfect")..")");
    G(y);
    RQ,EQ=FQ(dQ,jQ);
    H.FishAt=os.clock()+1.2;
    if not RQ then H.FishAt=os.clock()+(tostring(EQ):lower():find("closed")and 30 or 3);
    return true;
    end;
    local U,o=tonumber(RQ.Wait)or 3,xQ("Line");
    local C,FQ=xQ("Ui"),y:FindFirstChild("RodTip",true);
    local xQ,AQ,cQ=FQ and FQ:IsA("Attachment")and FQ.WorldPosition or mQ.Position+Vector3.new(0,4,0),false;
    if o then AQ,cQ=pcall(o.Spawn,FQ,xQ);
    else end;
    cQ=AQ and cQ;
    local AQ,kQ,wQ=cQ or nil,true,false;
    if AQ then task.spawn(function()pcall(o.Fly,AQ,xQ,dQ,0.75,function()return kQ;
    end);
    local xQ=os.clock();
    while kQ and AQ.Parent do if wQ then pcall(o.Thrash,AQ,dQ,1);
    task.wait(0.06);
    else pcall(o.Float,AQ,dQ,os.clock()-xQ,0);
    task.wait();
    end;
    end;
    end);
    end;
    VQ("Waiting for a bite");
    if RQ.Mode=="GhostFish"then NQ(RQ,jQ);
    else if RQ.Mode=="Nothing"or RQ.Mode=="Hint"or RQ.Mode=="Quest"then g(U,jQ);
    d("RE/Fishing/Cancel",RQ.Id);
    else if g(U,jQ)then VQ("Reeling in");
    wQ=true;
    EQ,y=os.clock(),false;
    while os.clock()-EQ<1.2 and(jQ())do OQ=(os.clock()-EQ-1.05)/0.15;
    if C then if OQ>=0 then if y then else pcall(C.ShowReel,true,"Click Fast!");
    y=true;
    end;
    mQ=math.min(OQ,1);
    pcall(C.SetReel,mQ,math.floor(mQ*16),"Click Fast!");
    pcall(C.PunchReel);
    else end;
    else end;
    task.wait();
    end;
    if C then pcall(C.ShowReel,false);
    end;
    H.LastReelAt=os.clock();
    local y,y,U=F("RF/Fishing/Reel",RQ.Id,"Caught",16);
    if y then if type(U)=="table"then H.Fish=H.Fish+1;
    VQ("Caught "..tostring(U.DisplayName).." x"..tostring(U.Amount));
    pcall(function()
        local nm=tostring(U.DisplayName or U.Name or"?");
        local amt=tonumber(U.Amount)or 1;
        V.ActSource={label="Fishing",at=os.clock()};
        V.LogActivity("fishing","Dapat "..nm.." x"..amt,0);
        local st=H.FishStats;
        if st then
            st.Fish=st.Fish+1;
            if H.FishRefresh then H.FishRefresh();end;
        end;
    end);
    if C then task.spawn(pcall,C.Reveal,U,2.6);
    end;
    end;
    end;
    else d("RE/Fishing/Cancel",RQ.Id);
    end;
    end;
    end;
    kQ=false;
    if AQ then task.spawn(function()pcall(o.Return,AQ,FQ,0.3);
    AQ:Destroy();
    end);
    end;
    H.FishAt=os.clock();
    return true;
    end;
    local y=V;
    y.HalloweenGoesFirst=function()local y=V;
    local U,o=y.SafeCarry.LastDelivered or 0,H.DeliveredAt or 0;
    if H.Turn then if math.max(U,o)<H.TurnAt then return H.Turn=="halloween";
    end;
    end;
    if U==o then return nil;
    end;
    return U>o;
    end;
    local y=V;
    y.HalloweenMove=function(y,U,o)local C,mQ={},V;
    for OQ,OQ in ipairs(mQ.HalloweenEggs())do if not(OQ.Current)then C[#C+1]=OQ;
    end;
    end;
    table.sort(C,function(OQ,EQ)local NQ,xQ=OQ.Order or 1/0,EQ.Order or 1/0;
    if NQ~=xQ then return NQ<xQ;
    end;
    return(tonumber(OQ.Value)or 0)>(tonumber(EQ.Value)or 0);
    end);
    mQ={};
    for OQ,OQ in ipairs(C)do mQ[#mQ+1]=OQ.Uid;
    end;
    if y and U then local OQ,EQ=table.find(mQ,y),table.find(mQ,U);
    if OQ then if EQ then mQ[OQ],mQ[EQ]=mQ[EQ],mQ[OQ];
    end;
    end;
    else local OQ,EQ=y or U,y~=nil==(o<0);
    H.Turn,H.TurnAt=EQ and"halloween"or"field",os.clock();
    C=EQ and table.find(mQ,OQ);
    if C then table.remove(mQ,C);
    table.insert(mQ,1,OQ);
    end;
    end;
    H.Order=mQ;
    H.OrderIndex={};
    for y,U in ipairs(mQ)do H.OrderIndex[U]=y;
    end;
    UQ();
    end;
    H.EggsRank=function(y)local U=V;
    local o=U.Steal;
    U=o and o.Wanted==true and o.WantedRank;
    local C=U and(rQ());
    if not(C)then return y;
    end;
    local UQ=V;
    local mQ=UQ.HalloweenGoesFirst();
    return(if mQ==nil then eQ(C)>(tonumber(o.WantedValue)or 0)else mQ)and math.min(y,U-0.5)or math.max(y,U+0.5);
    end;
    local function y(U)if U=="Pumpkin Moon"then return SQ(H.Pumpkin_,true)and workspace:GetAttribute("HalloweenWorldEvent")=="PumpkinMoon";
    elseif U=="Ghost Dog Quest"then return SQ(H.Dog_,false)and JQ()<4 and os.clock()>=H.DogAt;
    elseif U=="Eggs"then return SQ(H.Eggs_,false)and rQ()~=nil;
    end;
    return SQ(U=="Monsters"and H.Monsters_ or H.Fishing_,false);
    end;
    local U=V;
    U.HalloweenRank=function()if H.RankNow then return H.RankNow;
    end;
    local U=99;
    for o in pairs(s)do U=if HQ(o)<U then if y(o)then HQ(o)else U else U;
    end;
    return U;
    end;
    local function U()local o=V;
    local C=o.Butterfly;
    local UQ,mQ=type(C)=="table"and workspace:GetAttribute("Event_ButterflyBloom")==true;
    if UQ then o=V;
    mQ=o.Toggle(C.Handle,false);
    else mQ=UQ;
    end;
    UQ=nil;
    if mQ then C=nil;
    C,UQ=V,vQ("butterfly")<V.HalloweenRank();
    else UQ=mQ;
    end;
    return UQ;
    end;
    local o=V;
    o.HalloweenOver=function(o)if o=="halloween"then return false;
    elseif u[o]then if not(MQ())then return false;
    end;
    else return false;
    end;
    if not(_())then if tQ()then return false;
    elseif BQ()then if not(R("HalloweenDimensionPortal"))then return false;
    end;
    else return false;
    end;
    end;
    local C=V;
    return C.HalloweenRank()<vQ(o);
    end;
    local function o()local C,u=99;
    for UQ in pairs(s)do if HQ(UQ)<C then if y(UQ)then local y=HQ(UQ);
    C,u=y,UQ;
    else end;
    else end;
    end;
    return u=="Monsters"or u=="Fishing";
    end;
    local function y()local C,u,u,s=e.Character,V,type(V.InvisWanted)=="function";
    if u then local UQ=V;
    s=UQ.InvisWanted();
    else s=u;
    end;
    return s and C~=nil and C:GetAttribute("InvisApplied")~=true;
    end;
    local function C()local u=e.Character;
    local s,UQ=u~=nil and u:GetAttribute("InvisApplied")==true;
    if s then u=nil;
    u,UQ=V,os.clock()<(V.InvisHalloweenUntil or 0);
    else UQ=s;
    end;
    return UQ or(y());
    end;
    local function y(u)VQ(u);
    u=V;
    u.Movement.Owner="halloween";
    H.Busy=true;
    if not(H.SwapVis)then H.IdleUntil=math.max(H.IdleUntil or 0,os.clock()+30);
    end;
    task.spawn(function()local u=e.Character;
    pcall(n,function()local s,UQ=e.Character==u;
    if s then local u=p;
    UQ=not u.FanKunDead();
    else UQ=s;
    end;
    return UQ;
    end);
    H.SwapVis=nil;
    local u=V;
    u.ReleaseMovement("halloween");
    H.Busy=false;
    u=M;
    u.Wake();
    end);
    end;
    local function u(s)H.Busy=true;
    local UQ=V;
    UQ.Shield("halloween",true);
    local mQ=e.Character;
    local function eQ()local OQ,EQ=s==H.Gen and e.Character==mQ;
    if OQ then local s=p;
    EQ=not s.FanKunDead();
    else EQ=OQ;
    end;
    local s,OQ=EQ and(MQ());
    if s then EQ=V;
    OQ=EQ.Movement.Owner=="halloween";
    else OQ=s;
    end;
    return OQ and(H.Chase or H.Stealing or J("HalloweenCarrying")==true or yQ()==nil and not U());
    end;
    local s,OQ=pcall(function()local EQ=_();
    if not(oQ(eQ))then return;
    end;
    if not(EQ)then g(1,eQ);
    end;
    local function NQ()if H.NeedVis then local xQ=V;
    xQ.InvisHalloweenUntil=os.clock()+10;
    end;
    local xQ,FQ=eQ()and _();
    if xQ then local dQ=tQ();
    FQ=if dQ then J("HalloweenCarrying")==true else not dQ;
    else FQ=xQ;
    end;
    return FQ;
    end;
    EQ=nil;
    while eQ()and(_())do local xQ=false;
    H.RankNow=nil;
    if J("HalloweenCarrying")==true then H.RankNow=0;
    aQ(eQ);
    xQ=true;
    else if tQ()then VQ("Night, waiting in the Halloween safe zone");
    EQ=nil;
    local aQ,FQ=IQ();
    local dQ,jQ=E(),w("ReturnSpot");
    if jQ and dQ and A(dQ.Position-jQ.Position).Magnitude<40 then VQ("Night, waiting at the fishing spot");
    g(1,eQ);
    elseif aQ then if dQ then if iQ(FQ,dQ.Position)then g(1,eQ);
    else D(aQ,eQ);
    end;
    else g(1,eQ);
    end;
    else g(1,eQ);
    end;
    xQ=true;
    else end;
    end;
    local w={"Pumpkin Moon","Ghost Dog Quest","Eggs","Monsters","Fishing"};
    table.sort(w,function(aQ,FQ)return HQ(aQ)<HQ(FQ);
    end);
    local aQ=ipairs;
    for FQ,dQ in aQ(w)do if xQ then break;
    end;
    H.RankNow=HQ(dQ);
    if dQ=="Pumpkin Moon"and SQ(H.Pumpkin_,true)and workspace:GetAttribute("HalloweenWorldEvent")=="PumpkinMoon"then FQ=V;
    H.NeedVis=false;
    FQ.InvisHalloweenUntil=0;
    xQ=C()and"swap"or lQ(NQ);
    else if dQ=="Ghost Dog Quest"and SQ(H.Dog_,false)and JQ()<4 and os.clock()>=H.DogAt then local lQ=V;
    H.NeedVis=false;
    lQ.InvisHalloweenUntil=0;
    xQ=C()and"swap"or qQ(NQ);
    else if dQ=="Eggs"and SQ(H.Eggs_,false)then local lQ=V;
    H.NeedVis=false;
    lQ.InvisHalloweenUntil=0;
    xQ=C()and"swap"or QQ(NQ);
    else if dQ=="Monsters"and SQ(H.Monsters_,false)then local lQ=V;
    H.NeedVis,lQ.InvisHalloweenUntil=true,os.clock()+30;
    xQ=C()and"swap"or v(NQ);
    else if dQ=="Fishing"then if SQ(H.Fishing_,false)then local v=V;
    H.NeedVis,v.InvisHalloweenUntil=true,os.clock()+30;
    xQ=C()and"swap"or q(NQ);
    else end;
    else end;
    end;
    end;
    end;
    end;
    end;
    if xQ=="swap"then VQ("Changing visibility here");
    break;
    end;
    if not(xQ)then H.RankNow=nil;
    end;
    EQ=(if xQ then not xQ else EQ or os.clock())or nil;
    aQ,w=EQ and os.clock()-EQ>6;
    if aQ then local v=yQ(true)~=nil;
    if v then w=v;
    else local v,v=V,type(V.Treadmill.Wanted)=="function";
    if v then local q=V;
    w=q.Treadmill.Wanted();
    else w=v;
    end;
    end;
    else w=aQ;
    end;
    if w then VQ("Nothing to do here, back to other tasks");
    H.IdleUntil=os.clock()+45;
    H.LeaveNow=true;
    break;
    end;
    if not(xQ)then VQ("Waiting in the Halloween safe zone");
    aQ,w=IQ();
    local v=E();
    if aQ and v then if iQ(w,v.Position)then g(0.5,eQ);
    elseif os.clock()-EQ>2 then D(aQ,eQ);
    else g(0.5,eQ);
    end;
    else g(0.5,eQ);
    end;
    end;
    O();
    end;
    end);
    if not(s)then VQ("Halloween error, retrying: "..tostring(OQ));
    end;
    local function v()local q,w=e.Character==mQ;
    if q then local D=p;
    w=not D.FanKunDead();
    else w=q;
    end;
    return w;
    end;
    s=yQ();
    H.NeedVis=false;
    if s~=nil then OQ=V;
    OQ.InvisHalloweenUntil=0;
    elseif H.LeaveNow then UQ=V;
    UQ.InvisHalloweenUntil=0;
    elseif not(MQ())then local q=V;
    q.InvisHalloweenUntil=0;
    end;
    if _()and not H.Chase and(s~=nil and s~="train"or H.LeaveNow or H.SwapVis)then H.LeaveNow=nil;
    if not(H.SwapVis)then H.IdleUntil=math.max(H.IdleUntil or 0,os.clock()+30);
    end;
    pcall(n,v);
    end;
    H.SwapVis=nil;
    H.RankNow=nil;
    H.Stealing=false;
    OQ=V;
    OQ.Shield("halloween",false);
    UQ=V;
    UQ.ReleaseMovement("halloween");
    H.Busy=false;
    OQ=M;
    OQ.Wake();
    end;
    B=M;
    B.Add(function()local v=V;
    local q=v.HalloweenOnly();
    if q then v=V;
    if v.Movement.Owner~=q then if q=="halloween"then local w=V;
    if not(w.Movement.Owner=="train")then local w=V;
    if w.Movement.Owner~="invisibility"then local w=V;
    w.Movement.Owner=q;
    end;
    end;
    else local w=V;
    w.Movement.Owner=q;
    end;
    end;
    end;
    if H.Busy then return true;
    end;
    v,q=_(),yQ();
    local w,n=v and J("HalloweenCarrying")~=true and U(),MQ();
    if(if n then q else not n)or w then if v and(q and q~="train"or w)then if not(H.Chase)then y(q and"Leaving the dimension for "..tostring(q)or"Leaving the dimension");
    return true;
    end;
    end;
    if v then if not(MQ())then if q==nil then if not(H.Chase)then if J("HalloweenCarrying")~=true then local J=V;
    if J.HalloweenOnly()=="halloween"then local J=V;
    if not(J.TrainWanted())then local J=V;
    if J.Movement.Owner~="train"then local J,J=V,type(V.Treadmill.Wanted);
    if J=="function"then local J=V;
    if J.Treadmill.Wanted()then y("Leaving the dimension for the treadmill");
    return true;
    end;
    end;
    end;
    end;
    end;
    end;
    end;
    end;
    end;
    end;
    VQ(MQ()and"Waiting for "..tostring(q)or"Off");
    return false;
    end;
    if not v then if tQ()then if SQ(H.Eggs_,false)then if rQ()==nil then VQ("Night, waiting for daytime");
    return false;
    end;
    else VQ("Night, waiting for daytime");
    return false;
    end;
    end;
    end;
    if not v then if not(BQ())then VQ("Need 2.5M speed and the guard tutorial to enter");
    return false;
    end;
    end;
    if not v then if not(R("HalloweenDimensionPortal"))then VQ("Waiting for the Halloween portal");
    return false;
    end;
    end;
    q=V;
    if q.Steal then n=V;
    if n.Steal.Carrying==true then return false;
    end;
    end;
    if W()then VQ("Waiting 1.5s after changing visibility");
    return false;
    end;
    if not v then if U()then VQ("Butterfly Bloom goes first (Task Priority)");
    return false;
    end;
    end;
    if o()then q=V;
    q.InvisHalloweenUntil=os.clock()+30;
    end;
    n=V;
    w=n.Movement.Owner;
    if w~=nil then if w~="halloween"then if w~="treadmill"then VQ("Waiting for "..tostring(w));
    return false;
    end;
    end;
    end;
    if C()then VQ("Changing visibility here");
    return false;
    end;
    v=V;
    if not(v.ClaimMovement("halloween"))then VQ("Waiting for "..tostring(V.Movement.Owner or"another task"));
    return false;
    end;
    task.spawn(u,H.Gen);
    return true;
    end);
    zQ=M;
    zQ.Add(function()if SQ(H.Buy_,false)then if os.clock()<H.BuyAt then return false;
    end;
    else return false;
    end;
    H.BuyAt=os.clock()+5;
    local v,y=pcall(function()local U;
    local U,U=t,require(t.Data.HalloweenDimensionEgg);
    return U.Price;
    end);
    y=v and tonumber(y)or 2250;
    if(tonumber(j("HalloweenTokens"))or 0)<y then return false;
    end;
    task.spawn(function()local v,v,y=F("RF/HalloweenDimension/AskBuyEgg");
    if v==true then local v=V;
    v.Notify("Halloween","Bought a Halloween Dimension Egg");
    else H.BuyAt=os.clock()+30;
    VQ("Egg shop: "..tostring(y or"refused"));
    end;
    end);
    return false;
    end);
    f=S;
    m=f.TrainSection;
    local v=m:CreateText({Name="Phantom Express Status",Text="Off"});
    local function y(U)z.Status=U;
    end;
    local function U()z.Gen=z.Gen+1;
    local S=M;
    S.Wake();
    end;
    z.Ride_=m:CreateToggle({Name="Auto Phantom Express",Default=false,Callback=U});
    z.Boss_=m:CreateToggle({Name="Auto Vacuum Ghouler Boss",Default=true,Callback=U});
    z.GhostMode="Rarest First";
    m:CreateDropdown({Name="Ghost Target",Options={"Rarest First","Closest"},Default="Rarest First",Callback=function(S)if S=="Rarest First"then z.GhostMode=S;
    elseif S=="Closest"then z.GhostMode=S;
    end;
    end});
    z.GhostGap=12;
    z.GhostMove="Walk";
    z.GhostSpeed=300;
    m:CreateSlider({Name="Walk Speed",Min=100,Max=1000,Default=300,AllowDecimals=false,Increment=10,Unit=" st/s",Quick=false,Callback=function(S)z.GhostSpeed=tonumber(S)or 300;
    end});
    z.Souls_=m:CreateToggle({Name="Auto Trade Souls",Default=false,Callback=U});
    local function S(o)if type(o)=="table"then z.State,z.At=o,os.clock();
    end;
    end;
    local function o(...)return F("RF/TrainEvent/Action",...);
    end;
    local function m()local J,J,q=o("Status");
    if J then S(q);
    end;
    return z.State;
    end;
    Q("RE/TrainEvent/State",S);
    Q("RE/TrainEvent/CaptureState",function(S)if type(S)=="table"then if z.State then z.State.Invasion=S;
    end;
    end;
    end);
    Q("RE/GhostBoss/Defeated",function(S)if type(S)=="table"then local J=V;
    J.Notify("Ghouler","+"..tostring(S.Souls or 0).." Souls");
    end;
    end);
    local function S(J,q)local R=z.Prompts[J..tostring(q)];
    if R then if R.Parent then return R;
    end;
    end;
    if os.clock()<(z.Missing[J..tostring(q)]or 0)then return nil;
    end;
    z.Missing[J..tostring(q)]=os.clock()+5;
    local R,w=ipairs,{workspace:FindFirstChild("TrainEventRuntime"),workspace:FindFirstChild("TrainEventAssets"),workspace};
    for n,n in R(w)do for R,R in ipairs(n and n:GetDescendants()or{})do if R:IsA("ProximityPrompt")and(J=="Name"and R.Name==q or R:GetAttribute(J)==q)then z.Prompts[J..tostring(q)]=R;
    return R;
    end;
    end;
    end;
    return nil;
    end;
    local function J(q,R,w)local n,C,D=E(),q:GetAttribute(R),q:GetAttribute(w);
    if n then if typeof(C)=="Vector3"then if typeof(D)=="Vector3"then w=D-C;
    return C+w*(w.Magnitude>0 and math.clamp((n.Position-C):Dot(w)/w:Dot(w),0,1)or 0);
    end;
    end;
    end;
    return c(q.Parent);
    end;
    local function q(R,w)if not(R)then return false;
    end;
    return b(R+Vector3.new(0,3,0),w);
    end;
    local function R()return Z(function(w)return w:GetAttribute("ConductorTicket")==true;
    end);
    end;
    local function w()local n,b=z.State and z.State.SoulShop,V;
    return b.Toggle(z.Souls_,false)and type(n)=="table"and n.CanTrade==true and(tonumber(n.Souls)or 0)>=(tonumber(n.Cost)or 1/0);
    end;
    local function n()local b=V;
    return b.Toggle(z.Ride_,false)or z.SoulRide==true or w();
    end;
    local function w()local b=j("TrainEvent");
    return type(b)=="table"and(b.AccessUnlocked==true or(tonumber(b.Tickets)or 0)>0 or R()~=nil);
    end;
    local function b()local C=z.State;
    return C~=nil and C.ArrivalOpen==true and workspace:GetServerTimeNow()<(tonumber(C.DepartureAt)or 0)and(C.Phase=="Home"or C.Phase==nil);
    end;
    local function C(D)local f;
    local f=t;
    local u=f:FindFirstChild("GhostBossState");
    f=u and(u:GetAttribute("Phase"));
    return u~=nil and u:GetAttribute("BossId")~=""and(f=="Alive"or f=="Spawning")and u:GetAttribute("Realm")==D and u or nil;
    end;
    local function D(f)return Z(function(u)return u:GetAttribute("GhostVacuum")==true or f and u:GetAttribute("GhostBossVacuum")~=nil;
    end);
    end;
    local function f(u,...)if os.clock()-(z.SuckAt or 0)>=(u=="RE/GhostBoss/Suction"and 0.25 or 0.2)then z.SuckAt=os.clock();
    d(u,...);
    end;
    end;
    local function u(s)local yQ,UQ=s:GetAttribute("Ground"),E();
    if typeof(yQ)~="Vector3"then return;
    elseif UQ then else return;
    end;
    local tQ,BQ=s:GetAttribute("Velocity"),tonumber(s:GetAttribute("MovedAt"))or workspace:GetServerTimeNow();
    yQ=if typeof(tQ)=="Vector3"then yQ+tQ*math.clamp(workspace:GetServerTimeNow()-BQ,0,0.3)else yQ;
    s=A(UQ.Position-yQ);
    BQ=yQ+(s.Magnitude>0.5 and s.Unit or Vector3.new(1,0,0))*42+Vector3.new(0,3,0)-UQ.Position;
    k(CFrame.new(UQ.Position+(BQ.Magnitude>2 and BQ.Unit*math.min(BQ.Magnitude,1.3333333333333333)or BQ),Vector3.new(yQ.X,UQ.Position.Y,yQ.Z)));
    f("RE/GhostBoss/Suction",true,(yQ+Vector3.new(0,8,0)-UQ.Position).Unit);
    end;
    local function f(s,yQ)local UQ,tQ=os.clock()+20;
    local BQ=0.016666666666666666;
    while yQ()and os.clock()<UQ do local yQ=E();
    if not(yQ)then return false;
    end;
    local UQ=A(s-yQ.Position);
    if UQ.Magnitude<=20 then local lQ=RaycastParams.new();
    lQ.FilterType,lQ.FilterDescendantsInstances=Enum.RaycastFilterType.Exclude,{e.Character};
    local iQ=workspace:Raycast(Vector3.new(s.X,(tQ or yQ.Position.Y)+5,s.Z),Vector3.new(0,-250,0),lQ);
    lQ=iQ and Vector3.new(s.X,iQ.Position.Y+3,s.Z)or s+Vector3.new(0,3,0);
    k(CFrame.new(lQ)*yQ.CFrame.Rotation);
    yQ.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
    return true;
    end;
    tQ=tQ or yQ.Position.Y+40;
    local lQ=yQ.Position+UQ.Unit*math.min(UQ.Magnitude,(z.GhostSpeed or 300)*BQ);
    k(CFrame.new(Vector3.new(lQ.X,tQ,lQ.Z),Vector3.new(s.X,tQ,s.Z)));
    yQ.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
    BQ=math.clamp(O(),0.004166666666666667,0.05);
    end;
    return false;
    end;
    local function s(yQ)return type(yQ)=="table"and yQ.CanTrade and(tonumber(yQ.Souls)or 0)>=(tonumber(yQ.Cost)or 1/0);
    end;
    local function yQ(UQ)local tQ=S("TrainEventAction","OpenSoulShop");
    local BQ=tQ and c(tQ.Parent);
    if BQ then if f(BQ,UQ)then L(tQ);
    g(0.5,UQ);
    end;
    end;
    local f,f,f=o("OpenSoulShop");
    BQ=type(f)=="table"and f.SoulShop or z.State and z.State.SoulShop;
    for lQ=1,200,1 do if type(BQ)=="table"then if BQ.CanTrade then if not((tonumber(BQ.Souls)or 0)>=(tonumber(BQ.Cost)or 1/0))then break;
    end;
    else break;
    end;
    else break;
    end;
    tQ,lQ,f=o("TradeSouls",BQ.Cost);
    if not lQ then break;
    end;
    lQ=type(f)=="table"and(f.SoulShop or f.Souls~=nil and f)or nil;
    if type(lQ)=="table"and lQ.Souls~=nil then BQ=lQ;
    else BQ.Souls=(tonumber(BQ.Souls)or 0)-(tonumber(BQ.Cost)or 0);
    end;
    g(0.3,UQ);
    end;
    end;
    local function f(UQ)for tQ=1,4,1 do yQ(UQ);
    local yQ,yQ,yQ=o("Status");
    if UQ()then if type(yQ)=="table"then if not(s(yQ.SoulShop))then return;
    end;
    else return;
    end;
    else return;
    end;
    y("Souls left, trading again");
    end;
    end;
    local function s()local yQ=V;
    local UQ=yQ.Priority;
    local yQ,tQ=type(UQ)=="table"and UQ.Rank.Train or 99,V;
    UQ=tQ.Steal;
    if UQ then if UQ.Wanted==true then if vQ("steal")<yQ then return true;
    end;
    end;
    end;
    return SQ(H.Eggs_,false)and HQ("Eggs")<yQ and rQ()~=nil;
    end;
    local function HQ(yQ)local function UQ()return yQ()and T()=="Town";
    end;
    local yQ;
    z.Left=nil;
    z.Vis=false;
    local function tQ()z.Left=true;
    if os.clock()-(z.ReturnAt or-99)<25 then return;
    end;
    z.ReturnAt=os.clock();
    local BQ=S("Name","TrainReturn");
    if BQ then q(J(BQ,"ReturnRailStart","ReturnRailEnd"),UQ);
    end;
    o("Return");
    end;
    local BQ=0;
    while UQ()do if z.SoulRide then local lQ=V;
    if not(lQ.Toggle(z.Ride_,false))then if not(z.Left)then y("Trading souls");
    f(UQ);
    tQ();
    end;
    g(1,UQ);
    continue;
    end;
    end;
    if z.Vis then local lQ=V;
    lQ.InvisHalloweenUntil=os.clock()+10;
    end;
    if z.Left then else if os.clock()>=BQ then local lQ=os.clock()+2;
    if s()then y("Leaving town to steal an egg");
    tQ();
    end;
    BQ=lQ;
    else end;
    end;
    local BQ,lQ,iQ=z.State and type(z.State.Invasion)=="table"and z.State.Invasion or{},D(true),V;
    local aQ,IQ=iQ.Toggle(z.Boss_,true)and C("Town"),D(false);
    if if IQ then not IQ else not BQ.VacuumOwned then y("Picking up the Ghost Vacuum");
    iQ=S("TrainEventAction","PickupVacuum");
    if iQ then if q(c(iQ.Parent),UQ)then L(iQ);
    Y(function()return D(false)~=nil;
    end,3,UQ);
    else g(1,UQ);
    end;
    else g(1,UQ);
    end;
    else local L=aQ and lQ or BQ.Phase=="Active"and D(false);
    if L and not z.Vis and e.Character and e.Character:GetAttribute("InvisApplied")==true then local L=V;
    L.InvisHalloweenUntil=os.clock()+20;
    y("Turning visible to vacuum ghosts");
    g(0.5,UQ);
    else if aQ and lQ then z.Vis=true;
    y("Sucking in Ghouler");
    G(lQ);
    H.Move=true;
    u(aQ);
    else if BQ.Phase=="Active"and D(false)then z.Vis=true;
    G(D(false));
    local L=workspace:FindFirstChild("TrainGhostVisuals");
    local lQ=E();
    if yQ and yQ.Parent then else yQ=nil;
    local iQ,aQ,IQ=ipairs,L and L:GetChildren()or{},-1/0;
    for rQ,mQ in iQ(aQ)do rQ=mQ:GetAttribute("TrainGhost")and c(mQ);
    local iQ=rQ and lQ and(rQ-lQ.Position).Magnitude;
    if iQ then rQ=mQ.Name:find("Vengeful")and 3 or mQ.Name:find("Haunted")and 2 or 1;
    local aQ=z.GhostMode=="Closest"and-iQ or rQ*100000-iQ;
    if aQ>IQ then yQ=mQ;
    IQ=aQ;
    else end;
    else end;
    end;
    end;
    local iQ=yQ and c(yQ);
    if iQ and lQ then y(("Vacuuming ghosts %s/%s"):format(tostring(BQ.Captured or 0),tostring(BQ.Goal or 50)));
    local aQ,IQ,rQ=z.GhostMove~="Teleport",N(),math.clamp(tonumber(yQ:GetAttribute("ServerCaptureProgress"))or 0,0,1);
    local mQ=rQ>=0.75 and 7 or rQ>=0.5 and 10 or 15;
    H.Move=true;
    rQ=RaycastParams.new();
    rQ.FilterType=Enum.RaycastFilterType.Exclude;
    rQ.FilterDescendantsInstances={e.Character,L};
    local eQ,OQ;
    for EQ=0,15,1 do local NQ=EQ*3.141592653589793/8;
    local xQ,FQ=iQ+Vector3.new(math.cos(NQ),0,math.sin(NQ))*mQ,z.GhostGap;
    for dQ,dQ in ipairs(L:GetChildren())do EQ=dQ~=yQ and c(dQ);
    FQ=if EQ then math.min(FQ,A(xQ-EQ).Magnitude)else FQ;
    end;
    NQ=workspace:Raycast(iQ,xQ-iQ,rQ)~=nil;
    EQ=FQ*10-A(xQ-lQ.Position).Magnitude-(NQ and 1000 or 0);
    if eQ then if EQ>eQ then eQ,OQ=EQ,xQ;
    else end;
    else eQ,OQ=EQ,xQ;
    end;
    end;
    local eQ,EQ,NQ=math.clamp(tonumber(yQ:GetAttribute("ServerCaptureProgress"))or 0,0,1),(lQ.Position-iQ).Magnitude<z.GhostGap*2,math.min(os.clock()-(z.MoveAt or 0),0.1);
    z.MoveAt=os.clock();
    rQ=(aQ and z.GhostSpeed or 150)*(1-0.9*eQ);
    if eQ>0.5 then local function xQ(FQ)local dQ=z.GhostGap;
    for QQ,jQ in ipairs(L:GetChildren())do QQ=jQ~=yQ and c(jQ);
    dQ=if QQ then math.min(dQ,A(FQ-QQ).Magnitude)else dQ;
    end;
    return dQ;
    end;
    local yQ;
    for FQ=0,15,1 do local dQ=FQ*3.141592653589793/8;
    FQ=Vector3.new(iQ.X,lQ.Position.Y,iQ.Z)+Vector3.new(math.cos(dQ),0,math.sin(dQ))*mQ;
    dQ=xQ(FQ)*10-A(FQ-lQ.Position).Magnitude;
    if yQ then if dQ>yQ then yQ,OQ=dQ,FQ;
    else end;
    else yQ,OQ=dQ,FQ;
    end;
    end;
    rQ=xQ(lQ.Position)<z.GhostGap and 60 or 6;
    EQ=true;
    else end;
    eQ=A(OQ-lQ.Position);
    if eQ.Magnitude>20 then z.FlyY=z.FlyY or lQ.Position.Y+40;
    mQ=lQ.Position+eQ.Unit*math.min(eQ.Magnitude,z.GhostSpeed*math.max(NQ,0.016666666666666666));
    k(CFrame.new(Vector3.new(mQ.X,z.FlyY,mQ.Z),Vector3.new(iQ.X,z.FlyY,iQ.Z)));
    elseif z.FlyY then local yQ=RaycastParams.new();
    yQ.FilterType=Enum.RaycastFilterType.Exclude;
    yQ.FilterDescendantsInstances={e.Character,L};
    local L=workspace:Raycast(Vector3.new(OQ.X,z.FlyY,OQ.Z),Vector3.new(0,-200,0),yQ);
    yQ=L and Vector3.new(OQ.X,L.Position.Y+3,OQ.Z)or OQ;
    z.FlyY=nil;
    k(CFrame.new(yQ,Vector3.new(iQ.X,yQ.Y,iQ.Z)));
    elseif aQ and IQ then local L=A(OQ-lQ.Position);
    z.WalkSpeed0=z.WalkSpeed0 or IQ.WalkSpeed;
    IQ.AutoRotate=false;
    if L.Magnitude>1 then local yQ=EQ and rQ or z.GhostSpeed;
    local aQ=math.clamp(L.Magnitude*8,math.min(8,yQ),yQ);
    IQ.WalkSpeed=aQ;
    IQ:MoveTo(Vector3.new(OQ.X,lQ.Position.Y,OQ.Z));
    lQ.AssemblyLinearVelocity=L.Unit*aQ+Vector3.new(0,math.min(lQ.AssemblyLinearVelocity.Y,8),0);
    else IQ:MoveTo(lQ.Position);
    lQ.AssemblyLinearVelocity=Vector3.new(0,math.min(lQ.AssemblyLinearVelocity.Y,8),0);
    end;
    lQ.CFrame=CFrame.new(lQ.Position,Vector3.new(iQ.X,lQ.Position.Y,iQ.Z));
    else local L=OQ-lQ.Position;
    OQ=if EQ then if L.Magnitude>rQ*NQ then lQ.Position+L.Unit*rQ*NQ else OQ else OQ;
    k(CFrame.new(OQ,Vector3.new(iQ.X,OQ.Y,iQ.Z)));
    end;
    else H.Move=false;
    z.FlyY=nil;
    X(false);
    y("Waiting for ghosts");
    end;
    else if BQ.Phase=="Warmup"or BQ.Phase==nil then y("Ghost invasion starts soon");
    g(0.5,UQ);
    elseif BQ.Phase=="Active"then y("Waiting for the Ghost Vacuum");
    g(0.5,UQ);
    else local k=z.State and z.State.DepartureAt;
    if z.TradeDeparture~=k then z.TradeDeparture=k;
    local k=N();
    if k then k:UnequipTools();
    end;
    k=V;
    if k.Toggle(z.Souls_,false)then y("Trading souls");
    f(UQ);
    end;
    end;
    if not(z.Left)then y("Riding back home");
    z.DoneDeparture=z.State and z.State.DepartureAt;
    tQ();
    end;
    g(1,UQ);
    end;
    end;
    end;
    end;
    end;
    O();
    end;
    H.Move=false;
    z.FlyY=nil;
    X(false);
    if z.Vis then tQ=V;
    tQ.InvisHalloweenUntil=0;
    end;
    tQ=N();
    if tQ then tQ:UnequipTools();
    tQ.AutoRotate=true;
    if z.WalkSpeed0 then tQ.WalkSpeed=z.WalkSpeed0;
    z.WalkSpeed0=nil;
    end;
    end;
    end;
    local N=V;
    N.TrainWanted=function()local N=T();
    return n()and(N=="Town"or I[N]==true or b()and w()and z.DoneDeparture~=z.State.DepartureAt and not s());
    end;
    local N=V;
    N.InvisFreeze=function()local N=T();
    local k,L=n()and(N=="Town"or I[N]or b());
    if k then N=nil;
    N,L=V,os.clock()>=(V.InvisHalloweenUntil or 0);
    else L=k;
    end;
    return L;
    end;
    local function N(k)local L=z.State;
    y("Boarding the Phantom Express");
    if not(_())then if not(oQ(k))then z.FailAt=os.clock()+10;
    return;
    end;
    end;
    if L then if not(L.AtStation)then o("Station");
    g(3,k);
    m();
    end;
    end;
    if not(_())then y("Not in the dimension, entering again");
    z.FailAt=os.clock()+3;
    return;
    end;
    L=S("Name","TrainBoard");
    if not L then y("Boarding prompt not found, retrying");
    z.FailAt=os.clock()+5;
    return;
    end;
    if not(q(J(L,"BoardRailStart","BoardRailEnd"),k))then return;
    end;
    L=j("TrainEvent");
    if not(type(L)=="table"and L.AccessUnlocked)then G(R());
    g(0.4,k);
    end;
    local S,S,J=o("Board");
    if S then z.Rides=z.Rides+1;
    y("Boarded the Phantom Express");
    else z.FailAt=os.clock()+5;
    y("Could not board: "..tostring(J or"no answer"));
    end;
    if S then y("Boarded, waiting for the Phantom Express to leave");
    Y(function()local S=T();
    return I[S]==true or S=="Town"or e:GetAttribute("TrainEventTravelStage")=="Failed";
    end,25,k);
    end;
    end;
    local function S(o,J)z.Busy,z.BusyAt=true,os.clock();
    local j=V;
    j.Shield("train",true);
    local R=e.Character;
    local function k()local L,g=J==z.Gen and e.Character==R;
    if L then local J=p;
    g=not J.FanKunDead();
    else g=L;
    end;
    local J,R=g and(n());
    if J then L=V;
    R=L.Movement.Owner=="train";
    else R=J;
    end;
    return R;
    end;
    local J,R=pcall(function()if o=="town"then HQ(k);
    else N(k);
    end;
    end);
    if not(J)then y("Phantom Express error, retrying: "..tostring(R));
    end;
    R=V;
    R.Shield("train",false);
    j=V;
    if j.HalloweenOnly()~="train"then R=V;
    R.ReleaseMovement("train");
    end;
    z.Busy=false;
    R=M;
    R.Wake();
    end;
    B=M;
    B.Add(function()local o=V;
    local J=o.Toggle(z.Ride_,false);
    o=nil;
    if J then o=J;
    else local N=V;
    o=N.Toggle(z.Boss_,true);
    end;
    J=nil;
    if o then J=o;
    else local N=V;
    J=N.Toggle(z.Souls_,false);
    end;
    if J then if os.clock()-(z.PollAt or 0)>=3 then z.PollAt=os.clock();
    task.spawn(m);
    end;
    end;
    J=T();
    if I[J]then if not(z.Unswapped)then z.Unswapped=true;
    pcall(V.UndoSwap);
    end;
    y("On the Phantom Express ("..tostring(J)..")");
    return false;
    end;
    z.Unswapped=nil;
    if z.Busy then if J~="Town"then if os.clock()-(z.BusyAt or os.clock())>45 then z.Gen=z.Gen+1;
    z.Busy,z.FailAt=false,os.clock()+5;
    o=V;
    o.ReleaseMovement("train");
    y("Phantom Express got stuck, trying again");
    end;
    end;
    end;
    if z.Busy then return true;
    end;
    o=V;
    if o.Movement.Owner=="train"then if J~="Town"then local I=V;
    I.ReleaseMovement("train");
    end;
    end;
    if W()then return false;
    end;
    o=V;
    if not(o.Toggle(z.Ride_,false))then if not(z.Busy)then if J~="Town"then if not(b())then z.SoulRide=nil;
    end;
    end;
    end;
    end;
    if not(n())then y(J=="Town"and"In the Forgotten Town"or b()and"Phantom Express is boarding"or"Off");
    return false;
    end;
    o=V;
    if not(o.Toggle(z.Ride_,false))then if b()then z.SoulRide=true;
    end;
    end;
    o=J=="Town"and"town"or b()and os.clock()>=(z.FailAt or 0)and w()and z.DoneDeparture~=z.State.DepartureAt and"board"or nil;
    if not o then y(b()and"Need a Conductor's Ticket (Ghost Dog quest)"or"Waiting for the Phantom Express");
    return false;
    end;
    if o=="board"then local I,m=V;
    m,I.InvisHalloweenUntil=V,math.max(V.InvisHalloweenUntil or 0,os.clock()+30);
    I=V;
    I.TrainNeedsBody=os.clock()+30;
    m=e.Character;
    if m then if m:GetAttribute("InvisApplied")==true then y("Turning visible before boarding");
    return false;
    end;
    end;
    end;
    if o=="board"then if s()then y("Phantom Express is boarding, stealing the egg first");
    return false;
    end;
    end;
    if o=="board"then J=V;
    if J.Steal then local I=V;
    if I.Steal.Carrying==true then y("Phantom Express is boarding, delivering the egg first");
    return false;
    end;
    end;
    end;
    J=V;
    if not(J.ClaimMovement("train"))then z.WaitSince=z.WaitSince or os.clock();
    local I=V;
    local m,J=I.Movement.Owner,V;
    local N,j,R=J.Priority,m=="steal";
    if j then J=V;
    R=J.Steal;
    else R=j;
    end;
    I=nil;
    if R then J=V;
    I=J.Steal.Carrying==true;
    else I=R;
    end;
    j,R=I or vQ(m)<=(type(N)=="table"and N.Rank.Train or 99)or os.clock()-z.WaitSince<6 and m~="halloween";
    if j then R=j;
    else N=V;
    R=N.HalloweenOnly();
    end;
    if R then y("Phantom Express is boarding, waiting for "..tostring(V.Movement.Owner or"another task"));
    return false;
    end;
    m=V;
    m.Movement.Owner="train";
    end;
    z.WaitSince=nil;
    task.spawn(S,o,z.Gen);
    return true;
    end);
    hQ=M;
    hQ.Add(function()if h.Busy then return true;
    end;
    local S=V;
    if S.Toggle(z.Boss_,true)then if T()=="Town"then return false;
    elseif _()then return false;
    end;
    else return false;
    end;
    local o=C("World");
    S=o and(D(true));
    if S then local I=V;
    if I.Steal then local I=V;
    if I.Steal.Carrying==true then return false;
    end;
    end;
    else return false;
    end;
    S=V;
    if not(S.ClaimMovement("ghouler"))then return false;
    end;
    h.Busy=true;
    task.spawn(function()local S=e.Character;
    local function I()local m,J=e.Character==S;
    if m then local S=p;
    J=not S.FanKunDead();
    else J=m;
    end;
    m=nil;
    if J then local S=V;
    m=S.Toggle(z.Boss_,true);
    else m=J;
    end;
    J=nil;
    if m then local S=V;
    J=S.Movement.Owner=="ghouler";
    else J=m;
    end;
    return J and C("World")~=nil;
    end;
    pcall(function()local S=o:GetAttribute("Ground");
    if typeof(S)=="Vector3"then if not(q(S+Vector3.new(42,0,0),I))then return;
    end;
    end;
    while I()do G(D(true));
    y("Sucking in Ghouler");
    u(o);
    O();
    end;
    end);
    d("RE/GhostBoss/Suction",false);
    local y=V;
    y.ReleaseMovement("ghouler");
    h.Busy=false;
    y=M;
    y.Wake();
    end);
    return true;
    end);
    zQ=V;
    B=GameModules.IslandWarsSection;
    local y=B:CreateText({Name="Cursed Island Wars Status",Text="Waiting for Cursed Island Wars"});
    local function S(o)l.Status=o;
    end;
    local function o(h)pcall(function()local I;
    local I,I=t,require(t.Controllers.Game.AdminAbuseClientController.Events.CursedIslandWars.Input);
    l.Knock0=l.Knock0 or I.Knock;
    I.Knock=h and function()end or l.Knock0;
    end);
    end;
    U=K;
    U(function()o(false);
    end);
    l.Handle=B:CreateToggle({Name="Auto Play Cursed Island Wars",Default=true,Callback=function()l.Gen=l.Gen+1;
    local U=V;
    o(U.Toggle(l.Handle,true)and l.Held());
    U=M;
    U.Wake();
    end});
    l.Target="Enemies And Base";
    B:CreateDropdown({Name="Island Wars Target",Options={"Enemies And Base","Walls And Crystal"},Default="Enemies And Base",Callback=function(U)l.Target=U;
    end});
    local function U(K)if type(K)=="table"then l.Snap,l.At=K,os.clock();
    end;
    end;
    local function K()local t,t=F("RF/IslandWars/Fetch");
    U(t);
    end;
    Q("RE/LiveEvents/Began",function(t)if t=="CursedIslandWars"then l.SuddenDeath=false;
    l.Collapse=nil;
    task.spawn(K);
    end;
    end);
    Q("RE/LiveEvents/Ended",function(t)if t=="CursedIslandWars"then l.Snap=nil;
    l.SuddenDeath=false;
    l.Collapse=nil;
    end;
    end);
    Q("RE/IslandWars/State",U);
    Q("RE/IslandWars/Moment",function(U,t,h)if U=="Cooldown"and type(t)=="string"then l.Cooldowns[t]=tonumber(h)or 0;
    elseif U=="SuddenDeath"or U=="EarlySuddenDeath"or U=="Warning"and tonumber(t)and tonumber(t)<=15 then l.SuddenDeath=true;
    elseif U=="CollapseWarn"and type(t)=="table"then l.Collapse,l.CollapseAt=t,os.clock();
    elseif U=="Win"then l.SuddenDeath=false;
    elseif U=="Outro"then l.SuddenDeath=false;
    end;
    end);
    task.spawn(function()local U,U=F("RF/LiveEvents/FetchRunning");
    if type(U)=="table"then if U.CursedIslandWars then K();
    end;
    end;
    end);
    local function U()local t=E();
    if t then if l.Collapse then if not(os.clock()-l.CollapseAt<8)then return false;
    end;
    else return false;
    end;
    else return false;
    end;
    local h=RaycastParams.new();
    h.FilterType=Enum.RaycastFilterType.Include;
    h.FilterDescendantsInstances=l.Collapse;
    return workspace:Raycast(t.Position,Vector3.new(0,-14,0),h)~=nil;
    end;
    local function t(h)return Z(function(I)return I.Name==h;
    end);
    end;
    local function h(I)l.Busy=true;
    o(true);
    local function o()local m,e,J,N=l.Snap,l.Me(),I==l.Gen;
    if J then local I=p;
    N=not I.FanKunDead();
    else N=J;
    end;
    J=nil;
    if N then local p=V;
    J=p.Toggle(l.Handle,true);
    else J=N;
    end;
    return J and m~=nil and i[m.Phase]==true and e~=nil and e.State=="Alive"and os.clock()-l.At<30;
    end;
    pcall(function()while o()do local p,o,I=l.Snap,l.Me(),E();
    if not(I)then break;
    end;
    local m,e,J=o.Team=="Red"and"Blue"or"Red",workspace:GetServerTimeNow(),p.Island and p.Island:FindFirstChild("Centre");
    J=c(J and J:FindFirstChild("Top"));
    if J and(l.SuddenDeath or p.Phase=="SuddenDeath"or U())then if A(I.Position-J).Magnitude>18 then S("Moving to the centre of the island");
    I.AssemblyLinearVelocity=A(J-I.Position).Unit*math.max(x(),30)+Vector3.new(0,I.AssemblyLinearVelocity.Y,0);
    end;
    end;
    local U,J=l.Target=="Walls And Crystal"and 0 or 25;
    for E,N in ipairs(type(p.Entries)=="table"and p.Entries or{})do o=type(N)=="table"and N.Team==m and N.State=="Alive"and typeof(N.Model)=="Instance"and N.Model:FindFirstChild("HumanoidRootPart");
    E=o and(o.Position-I.Position).Magnitude;
    if E then if E<U then U,J=E,o;
    else end;
    else end;
    end;
    if p.Phase~="Prep"then local E,N=t("Bat"),t("PumpkinLauncher");
    if J and U<=10 and E and e>=(l.Cooldowns.Bat or 0)then S("Hitting an enemy");
    G(E);
    P(J.Position);
    d("RE/IslandWars/Use","Swing",J);
    l.Cooldowns.Bat=math.max(l.Cooldowns.Bat or 0,e+0.75);
    elseif N then if e>=(l.Cooldowns.PumpkinLauncher or 0)then local t,E=type(p.Barriers)=="table"and p.Barriers[m],type(p.Crystals)=="table"and p.Crystals[m];
    o=J and J.Position+J.AssemblyLinearVelocity*(U/110)or t and(tonumber(t.Health)or 0)>0 and typeof(t.Model)=="Instance"and c(t.Model:FindFirstChild("Hitbox")or t.Model)or E and(tonumber(E.Health)or 0)>0 and typeof(E.Model)=="Instance"and c(E.Model:FindFirstChild("Pivot",true)or E.Model);
    if o then S(J and"Shooting an enemy"or"Shooting the enemy base");
    G(N);
    P(o);
    t=N:FindFirstChild("Handle");
    E=t and(t:FindFirstChild("Muzzle"));
    local p=E and E:IsA("Attachment")and E.WorldPosition or I.Position+Vector3.new(0,1.5,0);
    if(o-p).Magnitude>1 then l.Shot=l.Shot+1;
    d("RE/IslandWars/Use","Launch",l.Shot,p,(o-p).Unit);
    l.Cooldowns.PumpkinLauncher=math.max(l.Cooldowns.PumpkinLauncher or 0,e+1.25);
    end;
    end;
    end;
    end;
    end;
    O();
    end;
    end);
    l.Busy=false;
    local p=M;
    p.Wake();
    end;
    B=M;
    B.Add(function()local p,U=l.Snap,l.Me();
    if p then if a[p.Phase]then if os.clock()-(l.FetchAt or 0)>=5 then l.FetchAt=os.clock();
    task.spawn(K);
    end;
    end;
    end;
    local K=V;
    if not(K.Toggle(l.Handle,true))then S("Off");
    return false;
    end;
    if l.Busy then return true;
    end;
    if p then if os.clock()-l.At>=30 then S("Waiting for Cursed Island Wars");
    return false;
    end;
    else S("Waiting for Cursed Island Wars");
    return false;
    end;
    if not(U)then S("Watching, you are not on a team");
    return false;
    end;
    S(tostring(p.Phase).." | Team "..tostring(U.Team).." | "..tostring(U.State));
    if i[p.Phase]then if not(U.State=="Alive")then return false;
    end;
    else return false;
    end;
    U=V;
    if not(U.ClaimMovement("islandwars"))then return false;
    end;
    task.spawn(h,l.Gen);
    return true;
    end);
    B=M;
    B.Add(function()if not(H.Busy)then if H.Status~="Off"then if not(MQ())then VQ("Off");
    end;
    end;
    end;
    local p=V;
    p.ShowRow(pQ,H.Status);
    p=V;
    p.ShowRow(v,z.Status or"Off");
    p=V;
    p.ShowRow(y,l.Status or"Waiting for Cursed Island Wars");
    local v,y=JQ(),V;
    y.ShowRow(KQ,(SQ(H.Dog_,false)or SQ(H.Fishing_,false))and"Quest: "..(r[v+1]or"Done").." | Fish caught: "..H.Fish or"Off");
    return false;
    end);
    end
    SetupHalloweenAndMinigameEventsModule()
end
SetupFieldTimerAndStarEvent()

local SetupStarCatcherEngine = function()
    local F,k,Y,z="star",25,{Payload=nil,Status="Off",Busy=false,Caught=0,Generation=0,AskAt=0,Slipped=0,WaitClaimSince=nil};
    local z= HubState;
    z.ShootingStar=Y;
    local A;
    z= GameModules;
    local I=z.StarSection;
    local z=I:CreateText({Name="Shooting Star Status",Text="Off"});
    local function A(e)Y.Status=e;
        local Z= HubState;
        Z.ShowRow(z,e);
    end;
    local z;
    Y.Handle=I:CreateToggle({Name="Auto Catch Shooting Star",Default=false,Callback=function()
            Y.Generation=Y.Generation+1;
            local I= TaskScheduler;
            I.Wake();
        end});
    local function I()local z= HubState;
        return z.Toggle(Y.Handle,false)==true;
    end;
    local function z(e)local Z;
        local Z= NetworkingPackage;
        return Z:FindFirstChild(e);
    end;
    local function o(e,...)local Z=z(e);
        if Z and(Z:IsA("RemoteEvent"))then local e=table.pack(...);
            pcall(function()
                Z:FireServer(table.unpack(e,1,e.n));
            end);
        end;
    end;
    local function e(Z)local R=type(Z)=="table";
        if R then local R=Z.Id~=nil;
            if R then if Y.Payload then if not(Y.Payload.Id==Z.Id)then Y.Slipped=0;
            end;
        else Y.Slipped=0;
        end;
        Y.Payload=Z;
        local Z= TaskScheduler;
        Z.Wake();
    end;
end;
end;
local function Z()Y.AskAt=os.clock()+15;
    task.spawn(function()
        local R=z("RF/ShootingStar/AskState");
        if R then if R:IsA("RemoteFunction")then local W,m=pcall(R.InvokeServer,R);
            if W then e(m);
            end;
        end;
    end;
end);
end;
local R={};
local function W(m,L)local j=z(m);
    if j then if j:IsA("RemoteEvent")then table.insert(R,j.OnClientEvent:Connect(L));
    end;
end;
end;
W("RE/ShootingStar/Fall",e);
W("RE/ShootingStar/Wander",function(e,m,L)
    if Y.Payload then if Y.Payload.Id==e then if type(m)=="table"then Y.Payload.Leg=m;
        Y.Payload.Noticed=L==true;
    end;
end;
end;
end);
W("RE/ShootingStar/Slipped",function(e)
    if Y.Payload then if Y.Payload.Id==e then Y.Slipped=Y.Slipped+1;
        Y.HoldStarted=nil;
    end;
end;
end);
W("RE/ShootingStar/Claimed",function(e)
    if Y.Payload then if Y.Payload.Id==e then Y.Caught=Y.Caught+1;pcall(function()HubState.LogActivity("star","Bintang jatuh berhasil ditangkap",1);end);
        Y.Payload=nil;
        Y.Generation=Y.Generation+1;
    end;
end;
end);
W("RE/ShootingStar/Expired",function(e)
    if Y.Payload then if Y.Payload.Id==e then Y.Payload=nil;
        Y.Generation=Y.Generation+1;
    end;
end;
end);
local e;
W= RegisterCleanup;
W(function()
    for N,N in ipairs(R)do N:Disconnect();
    end;
end);
Z();
local function N()local e=workspace:FindFirstChild("ShootingStarClient");
    local R=e and(e:FindFirstChild("Buddy"));
    e=R and(R:FindFirstChild("RootPart")or R.PrimaryPart);
    return e and e:IsA("BasePart")and e.Position or nil;
end;
local function e(R)local m=N();
    if m then return m,nil;
    end;
    local N,L=workspace:GetServerTimeNow(),R.Leg;
    if type(L)=="table"then if typeof(L.From)=="Vector3"then if typeof(L.To)=="Vector3"then m=tonumber(L.StartAt)or N;
        local j=(tonumber(L.ArriveAt)or m)-m;
        local X,U=j>0 and math.clamp((N-m)/j,0,1)or 1,L.To-L.From;
        return L.From:Lerp(L.To,X),X<1 and U.Magnitude>0.5 and Vector3.new(U.X,0,U.Z).Unit or nil;
    end;
end;
end;
L=R.Landing;
if typeof(L)=="CFrame"then return L.Position,nil;
end;
return typeof(L)=="Vector3"and L or nil,nil;
end;
local function N()local R= HubState;
    local m=R.AdminAbuse;
    for L=1,3,1 do L= HubState;
        local j,X=L.Root(), HubState;
        L,R=X.Treadmill.Riding==true;
        if L then R=L;
        else local U,U= HubState ,type( HubState .OnBelt)=="function";
            if U then X= HubState;
                R=X.OnBelt();
            else R=U;
            end;
        end;
        if not R then if type(m)=="table"then if m.OnAdmin==true then elseif j then if not(j.Anchored)then return true;
        end;
    else return true;
    end;
elseif j then if not(j.Anchored)then return true;
end;
else return true;
end;
end;
if type(m)=="table"then m.OnAdmin=false;
end;
j= HubState;
j.Treadmill.Riding=false;
X,L= HubState ,type( HubState .ExitBelt)=="function";
if L then pcall( HubState .ExitBelt);
else j=z("RF/Treadmill/AskDoff");
    if j then if j:IsA("RemoteFunction")then pcall(j.InvokeServer,j);
    end;
end;
task.wait(0.4);
end;
end;
m= HubState;
local z=m.Root();
return not(z and z.Anchored);
end;
local function z(R,m)local L= HubState;
    local j=L.Root();
    if not j then return;
    end;
    L= HubState;
    local X=L.Flying;
    if not(X)then L= HubState;
        L.BeginFlight();
    end;
    local L=j.Position;
    local X,U=(R-L)*10;
    if X.Magnitude>200 then X=X.Unit*200;
        U=X;
    else U=X;
    end;
    local R=m and Vector3.new(m.X-L.X,0,m.Z-L.Z)or Vector3.new(0.0,0.0,0.0);
    pcall(function()
        if R.Magnitude>0.05 then j.CFrame=CFrame.lookAt(L,L+R.Unit);
        end;
        j.AssemblyLinearVelocity=U;
        j.AssemblyAngularVelocity=Vector3.new(0.0,0.0,0.0);
    end);
end;
local function R(m,L)local function j()return L~=Y.Generation or not I()or Y.Payload~=m;
end;
local function L()local X=e(m);
    return X and X+Vector3.new(0,3,3)or nil;
end;
local function X()local U= HubState;
    local a,g=U.Root(),L();
    return a and g and(a.Position-g).Magnitude or 1/0;
end;
local U,a,a=X()>12;
if U then local a,a,g= HubState ,type( HubState .StealHome)=="function";
    if a then local M= HubState;
        g=M.StealHome();
    else g=a;
    end;
    local M,f=g or nil, HubState;
    a=f.Root();
    g,f=M and a;
    if g then local T= HubState;
        f=T.InsideBase();
    else f=g;
    end;
    g=f and(a.Position-M).Magnitude>6;
    if g then A("Leaving the base through the safe zone for the star");
        f,a=M+Vector3.new(0,3,0),os.clock()+20;
        while os.clock()<a and not j()do local T= HubState;
            local h=T.Root();
            if not h then return false;
            end;
            local T=f-h.Position;
            if T.Magnitude<=4 then break;
            end;
            local S,S= RunServiceRef ,math.min(250* RunServiceRef .Heartbeat:Wait(),T.Magnitude);
            pcall(function()
                h.CFrame=CFrame.new(h.Position+T.Unit*S)*h.CFrame.Rotation;
                h.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
            end);
        end;
    end;
    f= HubState;
    M=f.IsNight();
    g=nil;
    if M then g=M;
    else a= HubState;
        g=a.WallSealed();
    end;
    if g then f= HubState;
        M=f.InsideBase();
        if M then a= HubState;
            if not(a.WaitFieldOpen(j,function(T)
                A("Star: "..T);
            end))then return false;
        end;
    end;
end;
Y.RagdollTried=Y.RagdollTried or{};
M=Y.RagdollTried[m.Id];
if not M then a,g= HubState ,type( HubState .RagdollTravel)=="function";
    if g then f= HubState;
        local a=f.IsNight();
        if not(a)then local a= HubState;
            local T=a.WallSealed();
            if not(T)then Y.RagdollTried[m.Id]=true;
                A("Ragdoll TP to the star");
                a= LocalPlayerRef;
                local T,h=a.Character;
                if T then local a= LocalPlayerRef;
                    h=a.Character:FindFirstChildOfClass("Humanoid");
                else h=T;
                end;
                if h then pcall(h.UnequipTools,h);
                end;
                T= HubState;
                T.TravelCarryUntil=os.clock()+999;
                pcall( HubState .RagdollTravel,L,j);
                h= HubState;
                h.TravelCarryUntil=os.clock()+2;
            end;
        end;
    end;
end;
if j()then return false;
end;
M=X()>40;
if M then f= HubState;
    f.StepTo(L,j,function(a)
        A(type(a)=="string"and"Star: "..a or"Step TP to the star, "..a.." studs");
    end);
end;
if j()then return false;
end;
g= HubState;
g.GlideTo(L,j,4,function(a)
    A(type(a)=="string"and"Star: "..a or string.format("Flying to the star, %d studs",a));
end,40);
end;
if j()then return false;
elseif X()>12 then return false;
end;
U= HubState;
U.Root();
local a,a,g= LocalPlayerRef ,0.5+math.clamp( LocalPlayerRef :GetNetworkPing(),0,1)*2,os.clock();
A("At the star, letting the server catch up");
while os.clock()-g<a do if j()then return false;
end;
U,X=L(), HubState;
local L=X.Root();
if U then if not(L)then return false;
end;
else return false;
end;
if(L.Position-U).Magnitude>8 then if(L.Position-U).Magnitude>25 then A("Pulled back from the star, moving again");
    return false;
end;
g=os.clock();
else end;
    z(U,e(m));
    L= RunServiceRef;
    L.Heartbeat:Wait();
end;
return true;
end;
local function m(L,j)local function X()return j~=Y.Generation or not I()or Y.Payload~=L;
end;
local j;
local j= LocalPlayerRef;
local U,a=j.Character,(tonumber(L.HoldSeconds)or 1.6)+0.3;
Y.HoldStarted=nil;
j=nil;
local g=0;
while true do local M=X();
    local X,f=not M;
    if M then f=X;
    else local T= LocalPlayerRef;
        f=T.Character==U;
    end;
    if not f then break;
    end;
    if(tonumber(L.ExpiresAt)or 1/0)<=workspace:GetServerTimeNow()then Y.Payload=nil;
        return;
    end;
    f,M=e(L);
    X= HubState;
    local i=X.Root();
    if f then if not(i)then return;
    end;
else return;
end;
if Vector3.new(f.X-i.Position.X,0,f.Z-i.Position.Z).Magnitude>k then return;
end;
X=i.Anchored;
if X then N();
else local k,k= HubState ,type( HubState .AdminAbuse)=="table";
    if k then i= HubState;
        if i.AdminAbuse.OnAdmin then N();
        end;
    end;
end;
z(f+Vector3.new(0,3,0)+(M and M*2 or Vector3.new(0,0,3)),f);
if Y.HoldStarted then if if j then not j else os.clock()-Y.HoldStarted>=a then g+=1;
    j=os.clock();
    o("RE/ShootingStar/Catch",L.Id);
    A("Catching the star (try "..g..")");
else if j then if os.clock()-j>=2 then Y.HoldStarted=nil;
    o("RE/ShootingStar/Hold",L.Id,false);
    if g%3==0 then Z();
    end;
    j=nil;
else end;
else end;
end;
else Y.HoldStarted=os.clock();
    o("RE/ShootingStar/Hold",L.Id,true);
    A("Holding the star"..(Y.Slipped>0 and" (slipped "..Y.Slipped..")"or""));
end;
local k;
i= RunServiceRef;
i.Heartbeat:Wait();
end;
if Y.Payload==L then o("RE/ShootingStar/Hold",L.Id,false);
end;
end;
local function o(t,i)Y.Busy=true;
    local k= HubState;
    k.Shield(F,true);
    pcall( HubState .HoldBelt);
    local z,e=pcall(function()
        if not(N())then A("Could not get off the treadmill, retrying");
            return;
        end;
        if R(t,i)then m(t,i);
        end;
    end);
    if not(z)then A("Star catch error, retrying: "..tostring(e));
    end;
    z= HubState;
    k=z.Flying;
    if k then pcall( HubState .EndFlight);
    end;
    pcall( HubState .ReleaseBelt);
    e= HubState;
    e.Shield(F,false);
    z= HubState;
    z.ReleaseMovement(F);
    Y.Busy=false;
    z= TaskScheduler;
    z.Wake();
end;
W= TaskScheduler;
W.Add(function()
    if not(I())then Y.Wanted=false;
        A("Off");
        return false;
    end;
    if os.clock()>=Y.AskAt then Z();
    end;
    local I,d=Y.Payload,workspace:GetServerTimeNow();
    Y.Wanted=I~=nil and d>=(tonumber(I.LandAt)or d)and(tonumber(I.ExpiresAt)or 1/0)>d;
    if not(I)then Y.WaitClaimSince=nil;
        A("Waiting for a shooting star"..(Y.Caught>0 and" (caught "..Y.Caught..")"or""));
        return false;
    end;
    if(tonumber(I.ExpiresAt)or 1/0)<=d then Y.Payload=nil;
        return false;
    end;
    local N=tonumber(I.LandAt)or d;
    if d<N then A("Star falling, lands in "..math.ceil(N-d).."s");
        return false;
    end;
    if Y.Busy then return true;
    end;
    N= HubState;
    d=N.ClaimMovement(F);
    if not d then Y.WaitClaimSince=Y.WaitClaimSince or os.clock();
        N= HubState;
        local d,t=N.Steal;
        if d then local N= HubState;
            t=N.Steal.Carrying==true;
        else t=d;
        end;
        local N,N,i= HubState ,type( HubState .InRaceNow)=="function";
        if N then d= HubState;
            i=d.InRaceNow();
        else i=N;
        end;
        N= HubState;
        local k,z=N.Movement.Owner, HubState;
        d=z.RaceRank(k);
        N,z=d==nil;
        if N then z=N;
        else k= HubState;
            z=(k.Priority.Rank.Star or 99)>=d;
        end;
        k=i or t or z or os.clock()-Y.WaitClaimSince<6;
        if k then A("Star landed, waiting for "..tostring( HubState .Movement.Owner or"another task"));
            return false;
        end;
        N= HubState;
        N.Movement.Owner=F;
    end;
    Y.WaitClaimSince=nil;
    A("Going to the star");
    task.spawn(o,I,Y.Generation);
    return true;
end);
end
SetupStarCatcherEngine()


	----------------------------------------------------------------------
	-- CAPTURE THE EGG (disembunyikan / mati). Modul ini dari ci.lua dibawa
	-- hanya karena ia mendefinisikan HubState.RagdollTravel yang dipakai
	-- Butterfly, Halloween dan Shooting Star untuk melompat lewat tembok.
	----------------------------------------------------------------------
	HubState.CaptureSection = adaptSection(nil, true)

HubState.CaptureBoot = function()
    local O;
    local O= HubState;
    local A=O.CaptureSection;
    if not(A)then return;
    end;
    local e,Z,R,W,m,L,j,X,U,a,g,M,f,T,h,S="Event_CaptureTheEgg","Event_CaptureTheEggGameplay","Event_CaptureTheEggUid","capture","capturefly",400,220,160,14,40,50,32,1.4,3,0.25,2;
    local E={Handle=nil,TakeHandle=nil,Row=nil,Height=45,KeepAway=45,Generation=0,Status="Off",Shown=nil,Mode=nil,Goal=nil,Speed=L,Target=nil,Plan=nil,Controlling=false,Flight=false,Woken=nil,Hover=nil,HoverAt=0,Prints=nil,PrintsAt=-1/0,Seconds=nil,Rank=nil,Links={}};
    local function D(J)return J~=nil and J~=false and J~=0 and J~="";
    end;
    local function J()local G=workspace:GetAttribute(R);
        if type(G)=="string"then if G~=""then return G;
        end;
    end;
    return nil;
end;
local function R()return D(workspace:GetAttribute(e))or D(workspace:GetAttribute(Z));
end;
local function e(Z)local D;
    local D= GameModules;
    local G=D.EggState;
    if type(G)~="table"then return nil;
    end;
    if type(G.ReadFieldEgg)=="function"then local V,P=pcall(G.ReadFieldEgg,Z);
        if V then if type(P)=="table"then return P;
        end;
    end;
end;
if type(G.ReadFieldEggs)=="function"then local V,P=pcall(G.ReadFieldEggs);
    D=V and type(P)=="table"and P.Records or nil;
    if type(D)=="table"then P=D[Z];
        if type(P)=="table"then return P;
        end;
        for G,G in pairs(D)do if type(G)=="table"then if G.Uid==Z then return G;
        end;
    end;
end;
end;
end;
return nil;
end;
local function Z(D)if not D or not D:IsA("Model")then return nil;
end;
local G,V=pcall(function()
    return D:GetPivot().Position;
end);
return G and V or nil;
end;
local function D()local G=workspace:FindFirstChild("World")or workspace:FindFirstChild("__OBJECTS");
    local V,P=G and(G:FindFirstChild("Areas")),{"CaptureTheEggSpawn","AdminAbuseEggSpawn"};
    for p,p in ipairs(P)do G=V and(V:FindFirstChild(p));
        if G then if G:IsA("BasePart")then return G.Position;
        end;
    end;
end;
return nil;
end;
local function G(V,P)local p=workspace:FindFirstChild("AreaEggSlotsClient");
    local s=Z(p and p:FindFirstChild(V));
    if s then return s;
    end;
    s=Z(workspace:FindFirstChild(V));
    if s then return s;
    end;
    if type(P)=="table"then if typeof(P.BottomCFrame)=="CFrame"then return P.BottomCFrame.Position;
    end;
end;
return D();
end;
local function D(V)local P=type(V)=="table"and tonumber(V.CarrierUserId)or nil;
    if P then if P<=0 then return nil;
    end;
else return nil;
end;
local p;
V= PlayersService;
return V:GetPlayerByUserId(P),P;
end;
local V;
local function V(P,p)local s= HubState;
    local r=s.Steal.Carrying;
    if r then s= HubState;
        if s.Steal.CarryUid==P then return true;
        end;
    end;
    P,r=D(p);
    p= LocalPlayerRef;
    return r==p.UserId;
end;
local function P()if E.Prints then if os.clock()-E.PrintsAt<5 then return E.Prints;
end;
end;
local p,s={},workspace:FindFirstChild("World")or workspace:FindFirstChild("__OBJECTS");
local r=s and(s:FindFirstChild("Areas"));
s=r and(r:FindFirstChild("EggCarryBounds"));
if s then for B,_ in ipairs(s:GetChildren())do if _:IsA("BasePart")and _.Name~="SafeZone"and _.Position.Y>0 and _.Size.X>60 and _.Size.Z>60 then local s,q,v,c,H,C=_.Size/2,{-1,1},1/0,-1/0,1/0,-1/0;
    for K,w in ipairs(q)do K={-1,1};
        for q,q in ipairs(K)do B=_.CFrame:PointToWorldSpace(Vector3.new(s.X*w,0,s.Z*q));
            v,c,H=math.min(v,B.X),math.max(c,B.X),math.min(H,B.Z);
            C=math.max(C,B.Z);
        end;
    end;
    s,r=table.insert,{MinX=v,MaxX=c,MinZ=H,MaxZ=C};
    r.Y=_.Position.Y+_.Size.Y/2;
    s(p,r);
end;
end;
end;
E.Prints,E.PrintsAt=p,os.clock();
return p;
end;
local function p(s,r)r=r or 0;
    for B,B in ipairs(P())do if s.X>=B.MinX+r then if s.X<=B.MaxX-r then if s.Z>=B.MinZ+r then if s.Z<=B.MaxZ-r then return B;
    end;
end;
end;
end;
end;
return nil;
end;
local function s()local r,B={},workspace:FindFirstChild("World")or workspace:FindFirstChild("__OBJECTS");
    local _=B and(B:FindFirstChild("Areas"));
    B=_ and(_:FindFirstChild("GuardAreas"));
    if B then for q,v in ipairs(B:GetChildren())do _=v:FindFirstChild("Guard");
        if _ then q=_:FindFirstChild("HumanoidRootPart",true);
            v=q and q:IsA("BasePart")and q.Position or Z(_);
            if v then table.insert(r,v);
            end;
        end;
    end;
end;
return r;
end;
local function r()local B,_,q={},ipairs;
    local q= PlayersService;
    local o= table.pack (q:GetPlayers());
    for v,c in _( table.unpack(o, 1, o.n) )do q= LocalPlayerRef;
        if c~=q then v=c.Character;
            local F,o=v and(v:FindFirstChild("HumanoidRootPart")),v and(v:FindFirstChildOfClass("Humanoid"));
            if F then if o then if o.Health>0 then table.insert(B,F.Position);
            end;
        end;
    end;
end;
end;
return B;
end;
local function F(o,B,_)local q=1/0;
    for v,v in ipairs(B)do q=math.min(q,(v-o).Magnitude);
    end;
    for B,v in ipairs(_)do B=Vector3.new(v.X-o.X,0,v.Z-o.Z).Magnitude;
        q=math.min(q,B*E.KeepAway/M);
    end;
    return q;
end;
local function o(M)local B,_,q,v,c=r(),s(),E.KeepAway+10,1/0;
    local H,C,K=-1/0,1/0;
    for w,l in ipairs(P())do local P,Q,n=(l.MinZ+l.MaxZ)/2,math.min(a,math.max(0,(l.MaxZ-l.MinZ)/2-U)),l.MinX+U;
        while n<=l.MaxX-U do local a,x=ipairs,{P-Q,P,P+Q};
            for P,Q in a(x)do w=Vector3.new(n,l.Y+E.Height,Q);
                Q,P=F(w,B,_),(w-M).Magnitude;
                if Q>=q then if P<v then v,c=P,w;
                else end;
                else end;
                    if Q>H then H,C,K=Q,P,w;
                    else if Q==H then if P<C then H,C,K=Q,P,w;
                    else end;
                    else end;
                    end;
                end;
                n=n+g;
            end;
        end;
        return c or K;
    end;
    local function a(g)if g then if not(p(g,U-1))then return false;
    end;
else return false;
end;
return F(g,r(),s())>=E.KeepAway;
end;
local function F()local U= HubState;
    local g=U.Combat;
    if type(g)=="table"then if type(g.SelfRagdolled)=="function"then local U,M=pcall(g.SelfRagdolled);
        return U and M==true;
    end;
end;
return false;
end;
local U;
O= RunServiceRef;
local function U(g)local M=E.Controlling;
    if M then local P= HubState;
        if P.Movement.Owner~=W then return;
        end;
    else return;
    end;
    M= HubState;
    local P=M.Root();
    if not P or F()then return;
    end;
    M=E.Mode=="chase";
    if M then local s= HubState;
        s.GodTick();
        s= HubState;
        local r,B=s.Combat,E.Target;
        if type(r)~="table"then E.Plan=nil;
            return;
        elseif B then if not(r.Hittable(B))then E.Plan=nil;
            return;
        end;
    else E.Plan=nil;
        return;
    end;
    local s,_=pcall(r.Plan,B,P);
    E.Plan=s and _ or nil;
    if E.Plan then pcall(r.TryHit,B,E.Plan,true);
    end;
    return;
end;
if E.Mode~="glide"then return;
elseif E.Flight then return;
elseif typeof(E.Goal)~="Vector3"then return;
end;
M=P.Position;
local s,r=E.Goal-M,E.Speed*g;
local g=s.Magnitude<=math.max(r,0.05)and E.Goal or M+s.Unit*r;
r=Vector3.new(s.X,0,s.Z);
local M=r.Magnitude>0.5 and CFrame.lookAt(Vector3.new(0.0,0.0,0.0),r.Unit)or P.CFrame.Rotation;
pcall(function()
    P.CFrame=CFrame.new(g)*M;
    P.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
    P.AssemblyAngularVelocity=Vector3.new(0.0,0.0,0.0);
end);
end;
local g=O.Heartbeat:Connect(U);
table.insert(E.Links,g);
O= RunServiceRef;
local function M(P)if E.Controlling then if E.Mode~="chase"then return;
elseif not(E.Plan)then return;
end;
else return;
end;
local s= HubState;
if s.Movement.Owner~=W then return;
elseif F()then return;
end;
s= HubState;
local F,r=s.Combat, HubState;
s=r.Root();
if s then if type(F)=="table"then if type(F.Steer)=="function"then pcall(F.Steer,s,E.Plan,400,750,P);
end;
end;
end;
end;
U=O.PreSimulation:Connect(M);
table.insert(E.Links,U);
local function F(P)local s=P and not E.Flight;
    if s then E.Flight=true;
        local s= HubState;
        s.BeginFlight();
        s= HubState;
        s.GodMode(true);
    elseif P then else local P=E.Flight;
        if P then E.Flight=false;
            pcall( HubState .EndFlight);
            pcall( HubState .GodMode,false);
        end;
    end;
end;
local function P()local s= HubState;
    if not(s.ClaimMovement(W))then return false;
    end;
    if E.Controlling then return true;
    end;
    s= HubState;
    local r=s.Treadmill.Riding;
    if r then pcall( HubState .ExitBelt);
    else s= HubState;
        local B=s.OnBelt();
        if B then pcall( HubState .ExitBelt);
        end;
    end;
    s= HubState;
    s.Shield(W,true);
    r=0;
    while true do s= HubState;
        local B=s.Swapped();
        if not(if B then not B else r<T)then break;
        end;
        r+=task.wait(0.1);
    end;
    s= HubState;
    r=s.Movement.Owner~=W;
    if r then s= HubState;
        s.Shield(W,false);
        return false;
    end;
    E.Controlling=true;
    r= HubState;
    r.Driving=r.Driving+1;
    return true;
end;
local function T()E.Mode=nil;
    E.Goal=nil;
    E.Target=nil;
    E.Plan=nil;
    E.Hover=nil;
    F(false);
    local s=E.Controlling;
    if s then E.Controlling=false;
        local r,B= HubState;
        B,r.Driving= HubState ,math.max(0, HubState .Driving-1);
        B= HubState;
        B.Shield(W,false);
    end;
    s= HubState;
    s.ReleaseMovement(W);
end;
local function s()local r,B=E.Controlling;
    if r then local _= HubState;
        B=_.Movement.Owner==W;
    else B=r;
    end;
    if B then r= HubState;
        local B=r.Root();
        local r=B and p(B.Position,-4)or nil;
        local _=B and r and B.Position.Y>r.Y+8;
        if _ then E.Mode="glide";
            E.Speed=X;
            E.Goal=Vector3.new(B.Position.X,r.Y+3.5,B.Position.Z);
            local X=0;
            while X<1.5 do X+=task.wait(0.05);
                local X= HubState;
                local r=X.Root();
                if r then if(r.Position-E.Goal).Magnitude<1 then break;
                end;
            else break;
            end;
        end;
    end;
end;
T();
end;
local function X()local r= LocalPlayerRef;
    local B=r.Character;
    local r=B and(B:FindFirstChildOfClass("Humanoid"));
    if r and(B:FindFirstChildWhichIsA("Tool"))then pcall(function()
        r:UnequipTools();
    end);
end;
end;
local function r(B,_)local q,v,c=14;
    for H,C in ipairs(workspace:GetChildren())do if C.Name=="SmartPromptPart"then if C:IsA("BasePart")then H=C:FindFirstChild("CarryAreaEgg");
        if H then if H:IsA("ProximityPrompt")then local K=Vector3.new(C.Position.X-_.X,0,C.Position.Z-_.Z).Magnitude;
            if K<q then q,v,c=K,H,C;
            else end;
            else end;
            else end;
            else end;
            else end;
            end;
            if not(v)then return nil;
            end;
            _=workspace:FindFirstChild("AreaEggSlotsClient");
            if _ then for H,C in ipairs(_:GetChildren())do if C.Name~=B then H=Z(C);
                if H then if Vector3.new(H.X-c.Position.X,0,H.Z-c.Position.Z).Magnitude+1.5<q then return nil;
                end;
            end;
        end;
    end;
end;
return v;
end;
local function Z(B,_,q)X();
    local X;
    local X= GameModules;
    local v,c,H,C=X.EggState,if type(_)=="table"then if type(_.AreaId)=="string"then if type(_.NestId)=="string"then _.AreaId..":".._.NestId else nil else nil else nil,0,1/0;
        while H<f and not q()do _=e(B);
            if V(B,_)then return true;
            end;
            X=D(_);
            if X then local f= LocalPlayerRef;
                if X~=f then return false;
                end;
            end;
            local X=G(B,_);
            if X then E.Goal=X+Vector3.new(0,2.5,0);
            end;
            if C>=0.08 and X then local f=r(B,X);
                if f then pcall(function()
                    f.HoldDuration=0;
                end);
                if typeof(fireproximityprompt)=="function"then pcall(fireproximityprompt,f);
                end;
            elseif type(v)=="table"then if type(v.CarryFieldEgg)=="function"then pcall(v.CarryFieldEgg,B,c);
            end;
        end;
        C=0;
    else end;
        X=task.wait();
        H,C=H+X,C+X;
    end;
    return V(B,e(B));
end;
local function X()local f=workspace:FindFirstChild("World")or workspace:FindFirstChild("__OBJECTS");
    local r=f and(f:FindFirstChild("Areas"));
    f=r and(r:FindFirstChild("SeparationLine"));
    return f and f:IsA("BasePart")and f.Position.X or 552;
end;
local function f(r)F(false);
    E.Target=nil;
    E.Plan=nil;
    E.Mode="glide";
    E.Speed=j;
    local j=E.Hover;
    if if j then os.clock()-E.HoverAt>=h else not j then E.HoverAt=os.clock();
        if not(a(E.Hover))then E.Hover=o(r.Position);
        end;
    end;
    if not(E.Hover)then j=p(r.Position,0);
        if j then E.Hover=Vector3.new(r.Position.X,j.Y+E.Height,r.Position.Z);
        end;
    end;
    E.Goal=E.Hover;
    j="";
    if E.Seconds then j=string.format("  %.1fs",E.Seconds);
        j=if E.Rank then j..string.format("  #%d",E.Rank)
        else j;
        else end;
            E.Status="Holding the event egg"..j;
        end;
        local function o(j)local a=workspace:FindFirstChild("World")or workspace:FindFirstChild("__OBJECTS");
            local h=a and(a:FindFirstChild("Areas"));
            a=h and(h:FindFirstChild("GuardAreas"));
            h=a and type(j)=="string"and a:FindFirstChild(j)or nil;
            a=h and(h:FindFirstChild("Guard"));
            j=a and(a:FindFirstChild("HumanoidRootPart",true));
            if j then if j:IsA("BasePart")then return j;
            end;
        end;
        return nil;
    end;
    local function j(a,h)local r;
        local r= GameModules;
        local B=r.EggState;
        if type(B)~="table"then return nil;
        elseif type(B.ReadFieldEggs)~="function"then return nil;
        end;
        local _,q=pcall(B.ReadFieldEggs);
        B=_ and type(q)=="table"and q.Records or nil;
        if type(B)~="table"then return nil;
        end;
        local v,v,c,H,C,K= LocalPlayerRef ,"FirstAreaEgg_"..tostring( LocalPlayerRef .UserId),"FirstAreaEgg_",workspace:FindFirstChild("AreaEggSlotsClient"),1/0;
        q,r=1/0;
        for w,l in pairs(B)do _=type(l)=="table"and(l.Uid or w)or nil;
            if type(_)=="string"then if _==h or type(h)=="table"and h[_]then else if typeof(l.BottomCFrame)=="CFrame"then if l.State~="Carried"then local h,h=D(l);
                w=if string.sub(_,1,13)==c then if string.sub(_,1,#v)==v then string.match(_,"_([%w ]+:Slot_%d+)$")
                else nil else if type(l.AreaId)=="string"then if type(l.NestId)=="string"then l.AreaId..":"..l.NestId else nil else nil;
                    local B=w and o(l.AreaId)or nil;
                    B=if w then B or(if string.sub(_,1,#v)==v then o("Forest")
                    else B)
                    else B;
                        if w and B and not h and(l.State==nil or l.State=="Slot"or l.State=="Dropped")then local o,h=l.BottomCFrame.Position,H and H:FindFirstChild(_)or nil;
                            if h and(h:IsA("Model"))then local v,c=pcall(function()
                                return h:GetPivot().Position;
                            end);
                            o=if v then if typeof(c)=="Vector3"then Vector3.new(c.X,math.min(c.Y,o.Y+6),c.Z)
                            else o else o;
                            else end;
                                local v,c=Vector3.new(o.X-a.X,0,o.Z-a.Z).Magnitude,{Uid=_,Slot=w,Guard=B,At=o};
                                if h and v<C then C,K=v,c;
                                else end;
                                    if v<q then q,r=v,c;
                                    else end;
                                    else end;
                                    else end;
                                    else end;
                                    end;
                                else end;
                                end;
                                return K or r;
                            end;
                            local function o(a)local h= HubState;
                                local r=h.Steal.Carrying;
                                if r then h= HubState;
                                    if h.Steal.CarryUid==a then return true;
                                    end;
                                end;
                                r,h=D(e(a));
                                a= LocalPlayerRef;
                                return h==a.UserId;
                            end;
                            local function a()local h,h= LocalPlayerRef ,tonumber( LocalPlayerRef :GetAttribute("RagdollEndTime"))or 0;
                                return h;
                            end;
                            local function h()E.Mode=nil;
                                F(false);
                                local r=E.Controlling;
                                if r then E.Controlling=false;
                                    local r,B= HubState;
                                    B,r.Driving= HubState ,math.max(0, HubState .Driving-1);
                                    r= HubState;
                                    r.Shield(W,false);
                                end;
                            end;
                            local function r(B)local _= HubState;
                                local q=_.Root();
                                if not q then return false;
                                end;
                                pcall(function()
                                    q.CFrame=CFrame.new(B)*q.CFrame.Rotation;
                                    q.AssemblyLinearVelocity=Vector3.new(0.0,0.0,0.0);
                                    q.AssemblyAngularVelocity=Vector3.new(0.0,0.0,0.0);
                                end);
                                return true;
                            end;
                            local function B(_,q)local v= HubState;
                                local c=v.Root();
                                if not(c)then return false,"no character";
                                end;
                                if not(j(c.Position,_))then return false,"no egg to start the jump";
                                end;
                                local H;
                                v= NetworkingPackage;
                                local H=v:FindFirstChild("RE/GuardPatrol/ForestStrike");
                                if not H or not H:IsA("RemoteEvent")then return false,"no guard strike";
                                end;
                                local C;
                                v= GameModules;
                                local C=v.EggState;
                                h();
                                E.Status="Ragdoll jump: taking the closest egg";
                                local h,K={[_]=true};
                                for w=1,3,1 do w= HubState;
                                    v=j((w.Root()or c).Position,h);
                                    if v then if q()then break;
                                    end;
                                else break;
                                end;
                                local l,Q=v.At+Vector3.new(0,3,0),0;
                                while true do w=o(v.Uid);
                                    if not((if w then not w else Q<2.5)and not q())then break;
                                    end;
                                    r(l);
                                    local w,l,n=pcall(C.CarryFieldEgg,v.Uid,v.Slot);
                                    if w then if l~=true then if type(n)=="string"then if Q>0.4 then if not(string.find(string.lower(n),"closer",1,true))then break;
                                    end;
                                end;
                            end;
                        end;
                    end;
                    Q+=task.wait();
                end;
                if o(v.Uid)then K=v;
                    break;
                end;
                h[v.Uid]=true;
            end;
            if not K then return false,"no egg would come for the jump";
            end;
            local function w()local l=e(_);
                local Q=l and(G(_,l));
                return Q and Q+Vector3.new(0,3,0)or nil;
            end;
            local l,Q=false, HubState;
            h=Q.AntiGuard;
            if type(h)=="table"then h.HitArms=(h.HitArms or 0)+1;
                h.HitArmedAt=os.clock();
            end;
            v= LocalPlayerRef;
            c=v:GetAttributeChangedSignal("RagdollEndTime"):Connect(function()
                local n=l;
                if n then return;
                elseif a()<=workspace:GetServerTimeNow()then return;
                end;
                n=w();
                if n then l=true;
                    r(n);
                end;
            end);
            E.Status="Ragdoll jump: calling the guard strike";
            pcall(function()
                H:FireServer({EggUid=K.Uid,GuardCFrame=K.Guard.CFrame});
            end);
            waited=0;
            while true do v=not l and waited<3;
                if not(v and not q())then break;
                end;
                waited+=task.wait();
            end;
            c:Disconnect();
            if type(h)=="table"then h.HitArms=math.max(0,(h.HitArms or 1)-1);
            end;
            if o(K.Uid)then if type(C.DropFieldEgg)=="function"then pcall(C.DropFieldEgg,"PlayerRequest");
            end;
        end;
        c=not l;
        if c then return false,"the guard strike did not land";
        end;
        E.Status="Ragdoll jump: landed, grabbing the event egg";
        v= RunServiceRef;
        local function H()if a()>workspace:GetServerTimeNow()then local K=w();
            if K then r(K);
            end;
        end;
    end;
    c,h=v.Heartbeat:Connect(H),os.clock()+8;
    while os.clock()<h and not q()do Q=e(_);
        if Q then if o(_)then break;
        end;
    else break;
    end;
    C=D(Q);
    if C then v= LocalPlayerRef;
        if C~=v then break;
        end;
    end;
    H=w();
    if H then r(H);
    end;
    Z(_,Q,q);
end;
c:Disconnect();
if o(_)then E.Hover=nil;
    return true,"got the event egg";
end;
return true,"landed";
end;
local h= HubState;
h.RagdollTravel=function(h,_)
    local q= HubState;
    local v=q.Root();
    if v then if type(h)~="function"then return false,"no character";
    end;
else return false,"no character";
end;
if not(j(v.Position,nil))then return false,"no egg to start the jump";
end;
local c;
q= NetworkingPackage;
local i=q:FindFirstChild("RE/GuardPatrol/ForestStrike");
if not i or not i:IsA("RemoteEvent")then return false,"no guard strike";
end;
local c;
q= GameModules;
local d,c,H=q.EggState,{};
for C=1,3,1 do C= HubState;
    q=j((C.Root()or v).Position,c);
    if q then if _()then break;
    end;
else break;
end;
local j,K,w=q.At+Vector3.new(0,3,0),0,1/0;
while true do C=o(q.Uid);
    if not((if C then not C else K<2.5)and not _())then break;
    end;
    if w>=0 then w=0;
        r(j);
        local j,C,l=pcall(d.CarryFieldEgg,q.Uid,q.Slot);
        if j then if C~=true then if type(l)=="string"then if K>0.4 then if not(string.find(string.lower(l),"closer",1,true))then break;
        end;
    end;
end;
end;
end;
else end;
    local j=task.wait();
    K,w=K+j,w+j;
end;
if o(q.Uid)then H=q;
    break;
end;
c[q.Uid]=true;
end;
if not H then return false,"no egg would come for the jump";
end;
local j,C=false, HubState;
c=C.AntiGuard;
if type(c)=="table"then c.HitArms=(c.HitArms or 0)+1;
    c.HitArmedAt=os.clock();
end;
q= LocalPlayerRef;
C=q:GetAttributeChangedSignal("RagdollEndTime"):Connect(function()
    local K=j;
    if K then return;
    elseif a()<=workspace:GetServerTimeNow()then return;
    end;
    K=h();
    if K then j=true;
        r(K);
    end;
end);
pcall(function()
    i:FireServer({EggUid=H.Uid,GuardCFrame=H.Guard.CFrame});
end);
waited=0;
while true do q=not j and waited<3;
    if not(q and not _())then break;
    end;
    waited+=task.wait();
end;
C:Disconnect();
if type(c)=="table"then c.HitArms=math.max(0,(c.HitArms or 1)-1);
end;
if o(H.Uid)then if type(d.DropFieldEgg)=="function"then pcall(d.DropFieldEgg,"PlayerRequest");
end;
end;
c=not j;
if c then return false,"the guard strike did not land";
end;
while true do d,v=a(),workspace;
    if not(d>v:GetServerTimeNow()and not _())then break;
    end;
    C=h();
    if C then r(C);
    end;
    c= RunServiceRef;
    c.Heartbeat:Wait();
end;
return true,"landed";
end;
local d,o=220,220;
local function t(i,j,a,h)F(false);
    E.Target=nil;
    E.Plan=nil;
    E.Hover=nil;
    local _=G(i,j);
    if not(_)then E.Mode=nil;
        E.Status="Looking for the event egg";
        return;
    end;
    local q,v=X(),Vector3.new(_.X-a.Position.X,0,_.Z-a.Position.Z).Magnitude;
    local X,c=a.Position.X<q;
    if X then local H= HubState;
        local C=H.WallSealed();
        if C then c=C;
        else H= HubState;
            c=H.IsNight();
        end;
    else c=X;
    end;
    if v>d then if not(c)then if os.clock()>=(E.RagdollNext or 0)then E.RagdollNext=os.clock()+4;
        local d,H,C=pcall(B,i,h);
        E.LastJump=d and tostring(C)or tostring(H);
        if d then if H then E.RagdollNext=os.clock()+2;
        end;
    end;
    E.Status="Ragdoll jump: "..E.LastJump;
    return;
end;
end;
end;
X=a.Position.X<q;
if X then a=_.X>=q;
    if a then if c then E.Mode=nil;
        E.Status="Field wall is up, waiting to go out";
        return;
    end;
    E.Mode=nil;
    E.Status="Leaving the base for the event egg";
    pcall( HubState .FlyTo,_+Vector3.new(0,2.5,0),function()
        return h()or V(i,e(i));
    end,m);
    return;
end;
end;
X=_+Vector3.new(0,2.5,0);
if v<=o then E.Mode=nil;
    E.Goal=nil;
    E.Status="Grabbing the event egg";
    r(X);
    if Z(i,j,h)then E.Status="Got the event egg";
        E.Hover=nil;
    end;
    return;
end;
E.Mode="glide";
E.Speed=L;
E.Goal=X;
E.Status=string.format("Going for the event egg  %d studs",math.floor(v+0.5));
end;
local function d(o,i,Z)local m= HubState;
    local j,X=m.Combat, LocalPlayerRef;
    m=X.Character;
    local X,a=type(j)=="table"and m and type(j.PickBat)=="function"and j.PickBat(m)or nil, HubState;
    m=a.Toggle(E.TakeHandle,true);
    a=(if m then not X else not m)or not j.Hittable(Z);
        if a then F(false);
            E.Target=nil;
            E.Plan=nil;
            m=G(o,i);
            if m then if p(m,0)then E.Mode="glide";
                E.Speed=L;
                E.Goal=m+Vector3.new(0,25,0);
            else E.Mode=nil;
            end;
        else E.Mode=nil;
        end;
        j= HubState;
        if j.Toggle(E.TakeHandle,true)then if X then E.Status=Z.DisplayName.." has the event egg, waiting";
        else E.Status=Z.DisplayName.." has the event egg, get a bat to take it";
        end;
    else E.Status=Z.DisplayName.." has the event egg, waiting";
    end;
    return;
end;
F(true);
E.Hover=nil;
E.Target=Z;
E.Mode="chase";
E.Status="Taking the event egg from "..Z.DisplayName;
end;
local function o(i,Z,m)local L=P();
    if not(L)then F(false);
        E.Mode=nil;
        local j;
        j,E.Status= HubState ,"Waiting for "..tostring( HubState .Movement.Owner or"another feature").." to stop";
        return;
    end;
    L= HubState;
    local j=L.Root();
    if not(j)then E.Mode=nil;
        E.Status="Waiting for your character";
        return;
    end;
    if V(i,Z)then f(j);
        return;
    end;
    L=D(Z);
    if L then local X= LocalPlayerRef;
        if L~=X then d(i,Z,L);
            return;
        end;
    end;
    if Z.State=="Carried"then if not L then F(false);
        E.Mode=nil;
        E.Status="Someone has the event egg";
        return;
    end;
end;
t(i,Z,j,m);
end;
local function F(d)local function t()local i,Z=d~=E.Generation;
    if i then Z=i;
    else local i= HubState;
        Z=not i.Toggle(E.Handle,false);
    end;
    return Z;
end;
local i;
while not t()do local i=J();
    local Z=i and e(i)or nil;
    local e=if i then not Z else not i;
        if e then local m= HubState;
            m.Movement.CaptureUntil=0;
            m=E.Controlling;
            if m then s();
            else local m= HubState;
                if m.Movement.Owner==W then s();
                end;
            end;
            E.Seconds=nil;
            E.Rank=nil;
            E.Status=R()and"Event starting, waiting for the egg"or"Waiting for Capture The Egg";
            task.wait(i and 0.2 or 0.5);
        else local W= HubState;
            W.Movement.CaptureUntil=os.clock()+S;
            if not(pcall(o,i,Z,t))then E.Mode=nil;
                E.Status="Retrying";
                task.wait(0.3);
            end;
            task.wait(0.05);
        end;
        Z=E.Woken~=E.Status;
        if Z then E.Woken=E.Status;
            e= TaskScheduler;
            e.Wake();
        end;
    end;
    t= HubState;
    t.Movement.CaptureUntil=0;
    t=d==E.Generation;
    if t then s();
    else local d= HubState;
        if not(d.Toggle(E.Handle,false))then s();
        end;
    end;
    t= HubState;
    E.Status=t.Toggle(E.Handle,false)and E.Status or"Off";
    t= TaskScheduler;
    t.Wake();
end;
local d;
M= ReplicatedStorageService;
U=M:FindFirstChild("Packages");
g=nil;
if U then O= ReplicatedStorageService;
    g=O.Packages:FindFirstChild("Networking");
else g=U;
end;
U=g and(g:FindFirstChild("RE/EggCapture/StandingsRefreshed"));
if U then g=U:IsA("RemoteEvent");
    if g then table.insert(E.Links,U.OnClientEvent:Connect(function(O)
        local d=type(O)=="table"and(O.Entries or O.Standings or O)or nil;
        if type(d)~="table"then return;
        end;
        local o,t,i=ipairs;
        for Y,e in o(d)do local d,o=type(e)=="table";
            if d then O=nil;
                O,o= LocalPlayerRef ,tonumber(e.UserId)== LocalPlayerRef .UserId;
            else o=d;
            end;
            if o then t,i=tonumber(e.Seconds),tonumber(e.Rank)or Y;
                break;
            end;
        end;
        E.Seconds=t;
        E.Rank=i;
    end));
end;
end;
table.insert(E.Links, LocalPlayerRef .CharacterAdded:Connect(function()
    if E.Controlling then T();
    end;
end));
E.Row=nil;
E.Handle=A:CreateToggle({Name="Auto Capture Event Egg",Default=false,Callback=function()
        E.Generation=E.Generation+1;
        local O,d=E.Generation, HubState;
        local o=d.Toggle(E.Handle,false);
        if o then E.Status="Waiting for Capture The Egg";
            task.spawn(F,O);
        else d= HubState;
            d.Movement.CaptureUntil=0;
            E.Status="Off";
        end;
        local F;
        d= TaskScheduler;
        d.Wake();
    end});
E.TakeHandle=A:CreateToggle({Name="Take It From The Holder",Default=true,SubOf=E.Handle,Callback=function()
        local F;
        local F= TaskScheduler;
        F.Wake();
    end});
A:CreateSlider({Name="Hold Height",Min=20,Max=120,Default=45,Increment=1,Unit="studs",SubOf=E.Handle,Callback=function(F)
        E.Height=math.clamp(tonumber(F)or 45,20,120);
        E.Hover=nil;
    end});
A:CreateSlider({Name="Keep Away Distance",Min=20,Max=150,Default=45,Increment=1,Unit="studs",SubOf=E.Handle,Callback=function(F)
        E.KeepAway=math.clamp(tonumber(F)or 45,20,150);
    end});
U= HubState;
U.CaptureView={Row=E.Row,Status=function()
        return E.Status;
    end,EventRunning=R};
local F;
U= RegisterCleanup;
U(function()
    E.Generation=E.Generation+1;
    local F= HubState;
    F.Movement.CaptureUntil=0;
    pcall(T);
    for F,F in ipairs(E.Links)do pcall(function()
        F:Disconnect();
    end);
end;
table.clear(E.Links);
end);
end
HubState.CaptureBoot()

	----------------------------------------------------------------------
	-- ESP: Egg Halloween Dimension, Egg dunia biasa, dan Monster Halloween.
	-- Murni Instance (BillboardGui / SelectionBox / Frame), tanpa Drawing API,
	-- jadi tetap jalan di executor mobile.
	-- Egg  : icon pet + rarity (warna rarity) + nama + jarak
	-- Monster : box + tracer + nama
	----------------------------------------------------------------------
	do
		local CollectionService = game:GetService("CollectionService")
		local esp = {Halloween = false, Normal = false, Monster = false, Box = true, Tracer = true, Name = true, MaxDist = 2000}

		local eggSection = GameModules.EspEggSection
		local monsterSection = GameModules.EspMonsterSection

		eggSection:CreateToggle({
			Name = "Halloween Egg ESP",
			Note = "Egg di Halloween Dimension: icon pet + rarity",
			Default = false,
			Callback = function(value) esp.Halloween = value == true end,
		})
		eggSection:CreateToggle({
			Name = "Normal Egg ESP",
			Note = "Egg di dunia biasa (AreaEgg): icon pet + rarity",
			Default = false,
			Callback = function(value) esp.Normal = value == true end,
		})
		eggSection:CreateSlider({
			Name = "ESP Max Distance",
			Min = 100, Max = 5000, Default = 2000, Increment = 100, Unit = " st",
			Callback = function(value) esp.MaxDist = tonumber(value) or 2000 end,
		})

		monsterSection:CreateToggle({
			Name = "Monster ESP",
			Note = "Tandai monster Halloween",
			Default = false,
			Callback = function(value) esp.Monster = value == true end,
		})
		monsterSection:CreateToggle({
			Name = "Monster Box",
			Default = true,
			Callback = function(value) esp.Box = value == true end,
		})
		monsterSection:CreateToggle({
			Name = "Monster Tracer",
			Default = true,
			Callback = function(value) esp.Tracer = value == true end,
		})
		monsterSection:CreateToggle({
			Name = "Monster Name",
			Default = true,
			Callback = function(value) esp.Name = value == true end,
		})

		-- container GUI (protected parent kalau ada)
		local okParent, parent = pcall(pickParent)
		if not okParent or not parent then
			parent = localPlayer:WaitForChild("PlayerGui")
		end
		local holder = Instance.new("Folder")
		holder.Name = "FanKunHUB_ESP"
		holder.Parent = parent
		local tracerGui = Instance.new("ScreenGui")
		tracerGui.Name = "FanKunHUB_ESPTracers"
		tracerGui.IgnoreGuiInset = true
		tracerGui.ResetOnSpawn = false
		tracerGui.DisplayOrder = 5
		tracerGui.Parent = parent

		-- ---------- helper umum ----------
		local function posOf(inst)
			if inst:IsA("Model") then
				return inst:GetPivot().Position
			elseif inst:IsA("BasePart") then
				return inst.Position
			elseif inst:IsA("Attachment") then
				return inst.WorldPosition
			end
			return nil
		end

		local function partOf(inst)
			if inst:IsA("BasePart") then
				return inst
			elseif inst:IsA("Model") then
				return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
			end
			return inst:FindFirstChildWhichIsA("BasePart", true)
		end

		local function assetOf(id)
			local assets = GameModules.Assets
			local directory = type(assets) == "table" and assets.Directory or nil
			return type(directory) == "table" and directory[id] or nil
		end

		-- info tampilan egg dari id aset (pet)
		local function describe(id, fallbackName)
			local asset = assetOf(id)
			local rarity = type(asset) == "table" and asset.Rarity or nil
			local rarityName = type(rarity) == "table" and (rarity.DisplayName or rarity._id) or "Unknown"
			local color = type(rarity) == "table" and typeof(rarity.Color) == "Color3" and rarity.Color or Color3.fromRGB(255, 255, 255)
			local icon = type(asset) == "table" and type(asset.Icon) == "string" and asset.Icon or ""
			return {
				name = type(asset) == "table" and (asset.DisplayName or asset._id) or fallbackName or tostring(id),
				rarity = tostring(rarityName),
				color = color,
				icon = icon,
			}
		end

		-- ---------- ESP EGG ----------
		local tags = {}

		local function newEggTag(adornee)
			local gui = Instance.new("BillboardGui")
			gui.Name = "FanKunESPTag"
			gui.AlwaysOnTop = true
			gui.Size = UDim2.fromOffset(200, 80)
			gui.StudsOffset = Vector3.new(0, 3.5, 0)
			gui.Adornee = adornee
			gui.Parent = holder

			local icon = Instance.new("ImageLabel")
			icon.Name = "Icon"
			icon.AnchorPoint = Vector2.new(0.5, 0)
			icon.Position = UDim2.new(0.5, 0, 0, 0)
			icon.Size = UDim2.fromOffset(40, 40)
			icon.BackgroundTransparency = 1
			icon.ScaleType = Enum.ScaleType.Fit
			icon.Parent = gui

			local rarityLabel = Instance.new("TextLabel")
			rarityLabel.Name = "Rarity"
			rarityLabel.Position = UDim2.fromOffset(0, 42)
			rarityLabel.Size = UDim2.new(1, 0, 0, 18)
			rarityLabel.BackgroundTransparency = 1
			rarityLabel.Font = Enum.Font.GothamBold
			rarityLabel.TextSize = 14
			rarityLabel.TextStrokeTransparency = 0.35
			rarityLabel.Parent = gui

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Name = "Name"
			nameLabel.Position = UDim2.fromOffset(0, 60)
			nameLabel.Size = UDim2.new(1, 0, 0, 16)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Font = Enum.Font.GothamMedium
			nameLabel.TextSize = 12
			nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			nameLabel.TextStrokeTransparency = 0.35
			nameLabel.Parent = gui

			return {gui = gui, icon = icon, rarity = rarityLabel, name = nameLabel}
		end

		local function applyEggTag(key, adornee, info, dist)
			local tag = tags[key]
			if not tag or not tag.gui.Parent then
				tag = newEggTag(adornee)
				tags[key] = tag
			end
			tag.gui.Adornee = adornee
			tag.gui.MaxDistance = esp.MaxDist
			tag.icon.Image = info.icon
			tag.icon.Visible = info.icon ~= ""
			tag.rarity.Text = string.upper(info.rarity)
			tag.rarity.TextColor3 = info.color
			tag.name.Text = string.format("%s  [%dm]", info.name, math.floor(dist))
			tag.seen = true
		end

		-- egg Halloween: cari id pet dari nama sumber egg (sama seperti modul Halloween)
		local hwKnown, hwIdCache = {}, {}
		local function hwPetId(source)
			if hwIdCache[source] then
				return hwIdCache[source]
			end
			local id = source
			pcall(function()
				local specs = require(ReplicatedStorage.Data.HalloweenPets).Specs
				if not specs[source] then
					for key, spec in next, specs do
						if type(spec) == "table" and (spec.EggSource == source or spec.EggModel == source) then
							id = spec.Id or key
							break
						end
					end
				end
			end)
			hwIdCache[source] = id
			return id
		end

		local function refreshEggs(cam)
			for _, tag in pairs(tags) do
				tag.seen = false
			end
			local camPos = cam and cam.CFrame.Position

			if esp.Halloween and camPos then
				local dimension = workspace:FindFirstChild("HalloweenDimension")
				local eggs = dimension and dimension:FindFirstChild("WorldEggs")
				for _, egg in ipairs(eggs and eggs:GetChildren() or {}) do
					local part = partOf(egg)
					if part then
						local dist = (part.Position - camPos).Magnitude
						if dist <= esp.MaxDist then
							local uid = egg:GetAttribute("HalloweenEggUid")
							local src = egg:GetAttribute("PreparedSourceName")
							if uid and src then
								hwKnown[uid] = src
							end
							local source = src or (uid and hwKnown[uid])
							local info
							if source then
								info = describe(hwPetId(source), tostring(source))
							else
								info = {
									name = "Mystery Egg (Zone " .. tostring(egg:GetAttribute("Zone") or "?") .. ")",
									rarity = "Unknown",
									color = Color3.fromRGB(200, 200, 200),
									icon = "",
								}
							end
							applyEggTag(egg, part, info, dist)
						end
					end
				end
			end

			if esp.Normal and camPos then
				local slots = workspace:FindFirstChild("AreaEggSlotsClient")
				local eggState = GameModules.EggState
				if slots and eggState and type(eggState.ReadFieldEggs) == "function" then
					local ok, snapshot = pcall(eggState.ReadFieldEggs)
					if ok and type(snapshot) == "table" then
						local byUid = {}
						for k, record in pairs(snapshot.Records or snapshot) do
							if type(record) == "table" then
								local key = type(record.Uid) == "string" and record.Uid or (type(k) == "string" and k or nil)
								if key then
									byUid[key] = record
								end
							end
						end
						local states = GameModules.AreaEggs and GameModules.AreaEggs.States
						for _, child in ipairs(slots:GetChildren()) do
							local record = byUid[child.Name]
							if record and (not states or record.State == states.Slot or record.State == states.Dropped) then
								local part = child:FindFirstChild("Hitbox") or child:FindFirstChildWhichIsA("BasePart", true)
								if part then
									local dist = (part.Position - camPos).Magnitude
									if dist <= esp.MaxDist then
										applyEggTag(child, part, describe(record.AssetCategory, tostring(record.AssetCategory)), dist)
									end
								end
							end
						end
					end
				end
			end

			for key, tag in pairs(tags) do
				if not tag.seen then
					pcall(tag.gui.Destroy, tag.gui)
					tags[key] = nil
				end
			end
		end

		-- ---------- ESP MONSTER ----------
		local monsters = {}
		local SIZE_COLOR = {
			Small = Color3.fromRGB(255, 235, 100),
			Medium = Color3.fromRGB(255, 150, 60),
			Large = Color3.fromRGB(255, 70, 70),
		}
		local DEFAULT_MONSTER_COLOR = Color3.fromRGB(255, 110, 80)

		local function newMonster()
			local box = Instance.new("SelectionBox")
			box.Name = "FanKunESPBox"
			box.LineThickness = 0.06
			box.SurfaceTransparency = 1
			box.Parent = holder

			local label = Instance.new("BillboardGui")
			label.Name = "FanKunESPMonsterName"
			label.AlwaysOnTop = true
			label.Size = UDim2.fromOffset(220, 22)
			label.StudsOffset = Vector3.new(0, 4, 0)
			label.Parent = holder

			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.GothamBold
			text.TextSize = 13
			text.TextStrokeTransparency = 0.3
			text.Parent = label

			local line = Instance.new("Frame")
			line.Name = "Tracer"
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.BorderSizePixel = 0
			line.Visible = false
			line.Parent = tracerGui

			return {box = box, label = label, text = text, line = line}
		end

		local function destroyMonster(m)
			pcall(m.box.Destroy, m.box)
			pcall(m.label.Destroy, m.label)
			pcall(m.line.Destroy, m.line)
		end

		local function refreshMonsters(cam)
			for _, m in pairs(monsters) do
				m.seen = false
			end

			if esp.Monster and cam then
				local camPos = cam.CFrame.Position
				local viewport = cam.ViewportSize
				local origin = Vector2.new(viewport.X / 2, viewport.Y)

				for _, inst in ipairs(CollectionService:GetTagged("HalloweenMonster")) do
					if inst:IsDescendantOf(workspace) and inst:GetAttribute("KilledBy") == nil then
						local pos = posOf(inst)
						if pos then
							local dist = (pos - camPos).Magnitude
							if dist <= esp.MaxDist then
								local m = monsters[inst]
								if not m then
									m = newMonster()
									monsters[inst] = m
								end
								m.seen = true

								local size = inst:GetAttribute("MonsterSize")
								local color = SIZE_COLOR[size] or DEFAULT_MONSTER_COLOR

								-- box
								m.box.Color3 = color
								m.box.Adornee = (esp.Box and (inst:IsA("Model") or inst:IsA("BasePart"))) and inst or nil

								-- name
								m.label.Adornee = partOf(inst)
								m.label.Enabled = esp.Name
								m.label.MaxDistance = esp.MaxDist
								m.text.TextColor3 = color
								m.text.Text = string.format("%s%s [%dm]", inst.Name, size and (" (" .. tostring(size) .. ")") or "", math.floor(dist))

								-- tracer: dari tengah-bawah layar ke monster
								local screenPos = cam:WorldToViewportPoint(pos)
								if esp.Tracer and screenPos.Z > 0 then
									local target = Vector2.new(screenPos.X, screenPos.Y)
									local delta = target - origin
									m.line.Visible = true
									m.line.BackgroundColor3 = color
									m.line.Size = UDim2.fromOffset(delta.Magnitude, 1.5)
									m.line.Position = UDim2.fromOffset((origin.X + target.X) / 2, (origin.Y + target.Y) / 2)
									m.line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
								else
									m.line.Visible = false
								end
							end
						end
					end
				end
			end

			for key, m in pairs(monsters) do
				if not m.seen then
					destroyMonster(m)
					monsters[key] = nil
				end
			end
		end

		-- ---------- loop ----------
		local lastEggRefresh = 0
		local connection
		local function cleanup()
			if connection then
				connection:Disconnect()
				connection = nil
			end
			for key, tag in pairs(tags) do
				pcall(tag.gui.Destroy, tag.gui)
				tags[key] = nil
			end
			for key, m in pairs(monsters) do
				destroyMonster(m)
				monsters[key] = nil
			end
			pcall(holder.Destroy, holder)
			pcall(tracerGui.Destroy, tracerGui)
		end

		connection = RunService.RenderStepped:Connect(function()
			if not alive() then
				cleanup()
				return
			end
			local cam = workspace.CurrentCamera
			local now = os.clock()
			if now - lastEggRefresh >= 0.25 then
				lastEggRefresh = now
				pcall(refreshEggs, cam)
			end
			pcall(refreshMonsters, cam)
		end)
		RegisterCleanup(cleanup)
	end
	----------------------------------------------------------------------
	-- Task ladder: urutan prioritas + status supaya Auto Steal dan Treadmill
	-- mengalah ke fitur event ini.
	----------------------------------------------------------------------
	local function toggleOn(name)
		local control = toggles[name]
		return control ~= nil and HubState.Toggle(control, false) == true
	end

	local function anyToggleOn(names)
		for _, name in ipairs(names) do
			if toggleOn(name) then
				return true
			end
		end
		return false
	end

	local halloweenToggles = {
		"Auto Steal Halloween Eggs",
		"Auto Farm Monsters",
		"Auto Pumpkin Moon",
		"Auto Buy Halloween Dimension Egg",
		"Auto Ghost Dog Quest",
		"Auto Fishing",
	}
	local trainToggles = {"Auto Phantom Express", "Auto Vacuum Ghouler Boss", "Auto Trade Souls"}

	-- Auto Pumpkin Moon default ON (sama seperti ci.lua) tapi hanya "wants" saat event Pumpkin Moon benar-benar jalan,
	-- supaya Halloween tidak menahan fitur lain di luar event.
	local function halloweenWanted()
		for _, name in ipairs(halloweenToggles) do
			if toggleOn(name) then
				if name ~= "Auto Pumpkin Moon" or workspace:GetAttribute("HalloweenWorldEvent") == "PumpkinMoon" then
					return true
				end
			end
		end
		return false
	end

	local function movementOwnedBy(name)
		local movement = HubState.Movement
		if movement.Owner == name and os.clock() - (movement.OwnerAt or 0) < 3 then
			return true
		end
		if type(HubState.HalloweenOnly) == "function" then
			local ok, only = pcall(HubState.HalloweenOnly)
			return ok and only == name
		end
		return false
	end

	ladder.TITLES.train = "Phantom Express"
	ladder.TITLES.halloween = "Halloween Event"
	-- butterfly di urutan pertama: ia hanya "wants" saat toggle ON dan event Bloom sedang live,
	-- jadi tidak mengganggu di luar event. Kalau di bawah Auto Steal/Halloween ia tidak pernah kebagian gerak.
	local newOrder = {"butterfly", "auto_steal", "star", "train", "halloween", "mech_boss", "auto_place", "use_scrambled", "auto_sell", "treadmill"}
	ladder.DEFAULT = newOrder
	-- Urutan bawaan baru dipakai kalau user belum pernah mengubah lewat tab Order.
	-- (sebelumnya selalu ditimpa tiap script dijalankan, jadi pengaturan user hilang)
	do
		local saved = fanKunHubConfig.TaskOrder
		local untouched = type(saved) ~= "table"
		if not untouched then
			-- config lama masih memuat "race" (fitur sudah dihapus): abaikan saat membandingkan
			local cleaned = {}
			for _, name in ipairs(saved) do
				if name ~= "race" then
					cleaned[#cleaned + 1] = name
				end
			end
			saved = cleaned
			local initial = {"auto_steal", "star", "mech_boss", "butterfly", "auto_place", "use_scrambled", "auto_sell", "treadmill"}
			untouched = #saved == #initial
			if untouched then
				for index, name in ipairs(initial) do
					if saved[index] ~= name then
						untouched = false
						break
					end
				end
			end
		end
		if untouched then
			fanKunHubConfig.TaskOrder = table.clone(newOrder)
		end
	end

	ladder.register("star", {
		wants = function()
			local star = HubState.ShootingStar
			return star ~= nil and HubState.Toggle(star.Handle, false) and star.Payload ~= nil
		end,
		active = function()
			local star = HubState.ShootingStar
			return star ~= nil and star.Busy == true
		end,
		enabled = function()
			local star = HubState.ShootingStar
			return star ~= nil and HubState.Toggle(star.Handle, false)
		end,
		status = function()
			local star = HubState.ShootingStar
			return star and star.Status or ""
		end,
	})

	ladder.register("butterfly", {
		wants = function()
			local bloom = HubState.Butterfly
			return bloom ~= nil and HubState.Toggle(bloom.Handle, false) and workspace:GetAttribute("Event_ButterflyBloom") == true
		end,
		active = function()
			local bloom = HubState.Butterfly
			return bloom ~= nil and (bloom.Busy == true or bloom.Claiming == true)
		end,
		enabled = function()
			local bloom = HubState.Butterfly
			return bloom ~= nil and HubState.Toggle(bloom.Handle, false)
		end,
		status = function()
			local bloom = HubState.Butterfly
			return bloom and bloom.Status or ""
		end,
	})

	ladder.register("halloween", {
		wants = function()
			return halloweenWanted()
		end,
		active = function()
			return movementOwnedBy("halloween")
		end,
		enabled = function()
			return anyToggleOn(halloweenToggles)
		end,
		status = function()
			return "Halloween"
		end,
	})

	ladder.register("train", {
		wants = function()
			if not anyToggleOn(trainToggles) then
				return false
			end
			-- toggle Vacuum Ghouler Boss default ON (seperti ci.lua): jangan menahan fitur lain di luar event
			if type(HubState.TrainWanted) == "function" then
				return HubState.TrainWanted() == true
			end
			return true
		end,
		active = function()
			return movementOwnedBy("train")
		end,
		enabled = function()
			return anyToggleOn(trainToggles)
		end,
		status = function()
			return "Phantom Express"
		end,
	})


	------------------------------------------------------------------
	-- URUTAN PER FITUR (angka) + STATUS
	-- Angka di tab Order menentukan siapa jalan duluan. Urutan dihitung ulang
	-- tiap saat dari angka itu (dan dari fitur mana yang sedang ON), jadi tidak
	-- ada lagi cache lama / saling tunggu antara Auto Steal dan Halloween.
	------------------------------------------------------------------
	do
		local function hwStatus(toggleName)
			if not toggleOn(toggleName) then
				return "Off", "off"
			end
			if toggleName == "Auto Pumpkin Moon" and workspace:GetAttribute("HalloweenWorldEvent") ~= "PumpkinMoon" then
				return "Waiting for the Pumpkin Moon event", "idle"
			end
			local hw = HubState.HwState
			local text = hw and tostring(hw.Status or "") or ""
			if text == "" or text == "Off" then
				text = "On"
			end
			if (hw and hw.Busy == true) or movementOwnedBy("halloween") then
				return text, "run"
			end
			return text, "wait"
		end

		local function taskStatus(task)
			local text, kind = ladder.describe(task)
			if kind == "off" and text == "Idle" then
				kind = "idle"
			end
			return text, kind
		end

		local ENTRIES = {
			{key = "butterfly", title = "Butterfly Bloom", tab = "Butterfly", task = "butterfly",
				enabled = function() return ladder.enabled("butterfly") end,
				status = function() return taskStatus("butterfly") end},
			{key = "steal", title = "Auto Steal", tab = "Steal", task = "auto_steal",
				enabled = function() return ladder.enabled("auto_steal") end,
				status = function() return taskStatus("auto_steal") end},
			{key = "star", title = "Shooting Star", tab = "Shooting Star", task = "star",
				enabled = function() return ladder.enabled("star") end,
				status = function() return taskStatus("star") end},
			{key = "train", title = "Phantom Express", tab = "Phantom Express", task = "train",
				enabled = function() return anyToggleOn(trainToggles) end,
				status = function()
					if not anyToggleOn(trainToggles) then
						return "Off", "off"
					end
					local tz = HubState.TrainState
					local text = tz and tostring(tz.Status or "") or ""
					if text == "" or text == "Off" then
						text = "On"
					end
					if movementOwnedBy("train") then
						return text, "run"
					end
					return text, "wait"
				end},
			{key = "hw_eggs", title = "Halloween Eggs", tab = "Halloween", task = "halloween",
				enabled = function() return toggleOn("Auto Steal Halloween Eggs") end,
				status = function() return hwStatus("Auto Steal Halloween Eggs") end},
			{key = "hw_pumpkin", title = "Pumpkin Moon", tab = "Halloween", task = "halloween",
				enabled = function() return toggleOn("Auto Pumpkin Moon") end,
				status = function() return hwStatus("Auto Pumpkin Moon") end},
			{key = "hw_monsters", title = "Auto Farm Monsters", tab = "Monsters", task = "halloween",
				enabled = function() return toggleOn("Auto Farm Monsters") end,
				status = function() return hwStatus("Auto Farm Monsters") end},
			{key = "hw_dog", title = "Ghost Dog Quest", tab = "Ghost & Fishing", task = "halloween",
				enabled = function() return toggleOn("Auto Ghost Dog Quest") end,
				status = function() return hwStatus("Auto Ghost Dog Quest") end},
			{key = "hw_fishing", title = "Auto Fishing", tab = "Ghost & Fishing", task = "halloween",
				enabled = function() return toggleOn("Auto Fishing") end,
				status = function() return hwStatus("Auto Fishing") end},
		}
		for index, entry in ipairs(ENTRIES) do
			entry.index = index
		end

		-- Watcher aktivitas: setiap fitur yang SEDANG berjalan dicatat ke Log Aktivitas
		-- tiap kali yang dikerjakannya berganti (angka countdown/jarak diabaikan).
		task.spawn(function()
			local CAT_OF = {steal = "steal", butterfly = "butterfly", star = "star", train = "train",
				hw_eggs = "halloween", hw_pumpkin = "halloween", hw_monsters = "monster",
				hw_dog = "dog", hw_fishing = "fishing"}
			local watch = {}
			for _, entry in ipairs(ENTRIES) do
				watch[#watch + 1] = {id = entry.key, title = entry.title, cat = CAT_OF[entry.key] or "task", get = entry.status}
			end
			for _, extra in ipairs({
				{"auto_place", "Auto Place"}, {"use_scrambled", "Use Scrambled"}, {"auto_sell", "Auto Sell"},
				{"treadmill", "Treadmill"}, {"mech_boss", "Mech Boss"},
			}) do
				watch[#watch + 1] = {id = extra[1], title = extra[2], cat = "task", get = function() return taskStatus(extra[1]) end}
			end
			local lastKey, lastAt = {}, {}
			while fn2() do
				local running = {}
				for _, w in ipairs(watch) do
					pcall(function()
						local text, kind = w.get()
						text = tostring(text or "")
						if kind == "run" and text ~= "" and text ~= "On" and text ~= "Off" then
							running[#running + 1] = w.title .. ": " .. text
							local norm = text:gsub("%d+%.?%d*", "#")
							local now = os.clock()
							if norm ~= lastKey[w.id] and now - (lastAt[w.id] or 0) >= 1.5 then
								lastKey[w.id], lastAt[w.id] = norm, now
								window:AddActivityLog(w.cat, w.title .. ": " .. text, 0)
							end
						elseif kind ~= "run" then
							lastKey[w.id] = nil
						end
					end)
				end
				window.RunningActivity = #running > 0 and table.concat(running, "  |  ") or nil
				task.wait(0.7)
			end
		end)

		local RANK_ENTRY = {
			StealTop = "steal", StealWisp = "steal", StealFilter = "hw_eggs",
			Butterfly = "butterfly", Star = "star", Train = "train",
			HwPumpkin = "hw_pumpkin", HwDog = "hw_dog", HwMonsters = "hw_monsters", HwM = "hw_monsters",
			HwFishing = "hw_fishing",
		}

		local function numbersTable()
			local saved = fanKunHubConfig.TaskNumbers
			return type(saved) == "table" and saved or {}
		end

		local snapshotCache, snapshotAt = nil, -1e9
		local function snapshot()
			local now = os.clock()
			if snapshotCache and now - snapshotAt < 0.2 then
				return snapshotCache
			end
			local numbers = numbersTable()
			local sorted = table.clone(ENTRIES)
			table.sort(sorted, function(a, b)
				local na = tonumber(numbers[a.key])
				local nb = tonumber(numbers[b.key])
				na = (na and na >= 1) and na or math.huge
				nb = (nb and nb >= 1) and nb or math.huge
				if na ~= nb then
					return na < nb
				end
				return a.index < b.index
			end)
			local pos = {}
			for index, entry in ipairs(sorted) do
				pos[entry.key] = index
			end

			-- Halloween satu task di ladder: posisinya = fitur Halloween pertama yang sedang ON
			local chosen
			for _, entry in ipairs(sorted) do
				if entry.task == "halloween" then
					local ok, on = pcall(entry.enabled)
					if ok and on == true then
						chosen = entry
						break
					end
				end
			end
			if not chosen then
				for _, entry in ipairs(sorted) do
					if entry.task == "halloween" then
						chosen = entry
						break
					end
				end
			end

			local order, seen = {}, {}
			for _, entry in ipairs(sorted) do
				if entry.task ~= "halloween" then
					if not seen[entry.task] then
						seen[entry.task] = true
						order[#order + 1] = entry.task
					end
				elseif entry == chosen then
					seen.halloween = true
					order[#order + 1] = "halloween"
				end
			end

			snapshotCache = {pos = pos, order = ladder.sanitize(order), sorted = sorted}
			snapshotAt = now
			return snapshotCache
		end

		ladder.order = function()
			return snapshot().order
		end

		ladder.rankFor = function(key)
			local entryKey = RANK_ENTRY[key]
			if entryKey then
				return snapshot().pos[entryKey]
			end
			return nil
		end

		-- UI: satu baris per fitur (kotak angka + status)
		local listSection = ladder.orderList
		if listSection then
			local controls = {}

			local function refreshTitles()
				local snap = snapshot()
				for _, entry in ipairs(ENTRIES) do
					local control = controls[entry.key]
					if control then
						pcall(control.SetTitle, control, "#" .. tostring(snap.pos[entry.key]) .. "  " .. entry.title)
					end
				end
			end

			local PREFIX = {run = "[RUN] ", wait = "[WAIT] ", idle = "[IDLE] ", off = "[OFF] "}
			local function refreshStatus()
				for _, entry in ipairs(ENTRIES) do
					local control = controls[entry.key]
					if control then
						local ok, text, kind = pcall(entry.status)
						if not ok then
							text, kind = "error", "off"
						end
						local enabledOk, enabled = pcall(entry.enabled)
						if enabledOk and enabled ~= true then
							kind, text = "off", "Off"
						end
						pcall(control.SetContent, control, entry.tab .. " | " .. (PREFIX[kind] or "") .. tostring(text or ""))
					end
				end
			end

			for _, entry in ipairs(ENTRIES) do
				local saved = tonumber(numbersTable()[entry.key])
				local control
				control = listSection:AddInput({
					Title = entry.title,
					Content = entry.tab .. " | ...",
					Default = saved and tostring(math.floor(saved)) or "",
					Placeholder = "No.",
					Callback = function(text)
						local value = tonumber(text)
						local numbers = table.clone(numbersTable())
						if value and value >= 1 then
							numbers[entry.key] = math.floor(value)
						else
							numbers[entry.key] = nil
							if control then
								pcall(control.Set, control, "", true)
							end
						end
						fanKunHubConfig.TaskNumbers = numbers
						snapshotAt = -1e9
						refreshTitles()
						queueSave()
					end,
				})
				controls[entry.key] = control
			end

			ladder.orderReset = function()
				for _, control in pairs(controls) do
					pcall(control.Set, control, "", true)
				end
				snapshotAt = -1e9
				refreshTitles()
			end

			refreshTitles()
			refreshStatus()
			task.spawn(function()
				while alive() do
					task.wait(1)
					pcall(refreshStatus)
					pcall(refreshTitles)
				end
			end)
		end
	end

	-- cleanup saat Unload
	local previousShutdown = genv.__FanKunHUBHubShutdown
	genv.__FanKunHUBHubShutdown = function()
		if type(previousShutdown) == "function" then
			pcall(previousShutdown)
		end
		for _, callback in ipairs(addonCleanups) do
			pcall(callback)
		end
		table.clear(addonCleanups)
		genv.__FanKunHUBHubShutdown = nil
	end
	window.onClose = genv.__FanKunHUBHubShutdown
end

local eventsOk, eventsErr = pcall(installEventsAddon)
if not eventsOk then
	warn("[FanKunHUB] Events add-on failed: " .. tostring(eventsErr))
	pcall(function()
		window:Notify("Events add-on", "Failed to load: " .. tostring(eventsErr), 8)
	end)
end


window:Notify("FanKunHUB", loaded and "Config loaded" or "Ready", 3)
