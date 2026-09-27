--!strict
-- Profile persistence with session locking via DataStoreService:UpdateAsync.
-- Handles session locking, schema migrations, slot key string/number conversions,
-- retries with backoff, Studio in-memory fallback, and parallel BindToClose saving.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

export type SlotEntry = {
	Id: string,
	Growth: number,
	Mutation: string?,
}

export type Profile = {
	Money: number,
	Rebirths: number,
	Slots: { [number]: SlotEntry },
	Bank: number,
	LastOnline: number,
	Reserved: { [number]: SlotEntry }?, -- slots whose kaiju a thief is carrying (saved as normal slots)
	Stats: {
		Bought: number,
		Stolen: number,
		Lost: number,
	},
}

type StoredSlots = { [string]: SlotEntry }

type StoredProfileData = {
	Money: number,
	Rebirths: number,
	Slots: StoredSlots,
	Bank: number,
	LastOnline: number,
	Stats: {
		Bought: number,
		Stolen: number,
		Lost: number,
	},
}

type SessionLock = {
	JobId: string,
	Time: number,
}

type StoredRecord = {
	Data: StoredProfileData,
	Lock: SessionLock?,
}

local DATA_STORE_NAME = Config.DataStoreName or "PlayerData_v1"
local AUTO_SAVE_INTERVAL = Config.DataAutoSaveInterval or 60
local SESSION_LOCK_TIMEOUT = Config.SessionLockTimeout or 1800 -- 30 minutes in seconds
local MAX_RETRIES = Config.DataMaxRetries or 5
local RETRY_BASE_DELAY = Config.DataRetryDelay or 2
local MAX_SAVE_RETRIES = 3
local PLAYER_KEY_PREFIX = "Player_"

-- Unique identifier for this game server instance
local SERVER_SESSION_ID = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false)

local Data = {}

local loadedEvent = Instance.new("BindableEvent")
loadedEvent.Name = "DataLoaded"
Data.loaded = loadedEvent

local profiles: { [Player]: Profile } = {}
local isSaving: { [Player]: boolean } = {}
local isInitialized = false
local isRunning = true

local isStudio = RunService:IsStudio()
local useMock = false
local mockStorage: { [string]: StoredRecord } = {}
local dataStore: any = nil

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function checkDataStoreAccess()
	if not isStudio then
		dataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)
		return
	end

	-- In Studio, test if API services are enabled
	local ok, err = pcall(function()
		local testStore = DataStoreService:GetDataStore(DATA_STORE_NAME)
		testStore:GetAsync("__StudioApiCheck__")
	end)

	if not ok then
		warn(string.format("[Data] Studio DataStore API unavailable (%s). Running in memory-only mode.", tostring(err)))
		useMock = true
	else
		dataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)
	end
end

local function performUpdateAsync(key: string, transform: (any) -> any): (boolean, any)
	if useMock then
		local current = mockStorage[key]
		local currentClone = if current then deepCopy(current) else nil
		local transformed = transform(currentClone)
		if transformed ~= nil then
			mockStorage[key] = deepCopy(transformed)
		end
		return true, mockStorage[key]
	else
		local result
		local ok, err = pcall(function()
			result = dataStore:UpdateAsync(key, transform)
		end)

		-- Dynamic fallback for Studio if API calls fail during runtime
		if not ok and isStudio then
			warn(string.format("[Data] DataStore API failed in Studio (%s). Switching to memory-only mode.", tostring(err)))
			useMock = true
			return performUpdateAsync(key, transform)
		end

		return ok, if ok then result else err
	end
end

local function normalizeRecord(raw: any): (StoredProfileData?, SessionLock?)
	if typeof(raw) ~= "table" then
		return nil, nil
	end

	local data = raw.Data or raw.data
	local lock = raw.Lock or raw.lock

	-- If stored in modern wrapper { Data = ..., Lock = ... }
	if data ~= nil or lock ~= nil then
		return data, lock
	end

	-- Legacy schema: root table is the profile data
	return raw, nil
end

local function isLockActiveOnAnotherServer(lock: any, now: number): (boolean, string?)
	if typeof(lock) ~= "table" then
		return false, nil
	end

	local lockJobId = lock.JobId or lock.jobId
	local lockTime = lock.Time or lock.time or 0

	if lockJobId and lockJobId ~= SERVER_SESSION_ID then
		local age = now - lockTime
		if age < SESSION_LOCK_TIMEOUT then
			return true, tostring(lockJobId)
		end
	end

	return false, nil
end

local function createDefaultProfile(): Profile
	return {
		Money = Config.StartMoney or 50,
		Rebirths = 0,
		Slots = {},
		Bank = 0,
		LastOnline = os.time(),
		Stats = {
			Bought = 0,
			Stolen = 0,
			Lost = 0,
		},
	}
end

local function serializeProfile(profile: Profile): StoredProfileData
	local storedSlots: StoredSlots = {}
	-- A kaiju a thief is still carrying belongs to the owner until it is delivered
	local allSlots = {}
	if typeof(profile.Reserved) == "table" then
		for slotNum, entry in profile.Reserved do
			allSlots[slotNum] = entry
		end
	end
	if typeof(profile.Slots) == "table" then
		for slotNum, entry in profile.Slots do
			allSlots[slotNum] = entry
		end
	end
	do
		for slotNum, entry in allSlots do
			local num = tonumber(slotNum)
			if num and typeof(entry) == "table" and typeof(entry.Id) == "string" then
				storedSlots[tostring(math.floor(num))] = {
					Id = entry.Id,
					Growth = if typeof(entry.Growth) == "number" then math.max(0, entry.Growth) else 0,
					Mutation = if typeof(entry.Mutation) == "string" then entry.Mutation else nil,
				}
			end
		end
	end

	local bought = 0
	local stolen = 0
	local lost = 0
	if typeof(profile.Stats) == "table" then
		bought = if typeof(profile.Stats.Bought) == "number" then math.max(0, profile.Stats.Bought) else 0
		stolen = if typeof(profile.Stats.Stolen) == "number" then math.max(0, profile.Stats.Stolen) else 0
		lost = if typeof(profile.Stats.Lost) == "number" then math.max(0, profile.Stats.Lost) else 0
	end

	return {
		Money = if typeof(profile.Money) == "number" then math.max(0, profile.Money) else (Config.StartMoney or 50),
		Rebirths = if typeof(profile.Rebirths) == "number" then math.max(0, profile.Rebirths) else 0,
		Slots = storedSlots,
		Bank = if typeof(profile.Bank) == "number" then math.max(0, profile.Bank) else 0,
		LastOnline = os.time(),
		Stats = {
			Bought = bought,
			Stolen = stolen,
			Lost = lost,
		},
	}
end

local function deserializeProfile(raw: any): Profile
	if typeof(raw) ~= "table" then
		raw = {}
	end

	local stats = {
		Bought = 0,
		Stolen = 0,
		Lost = 0,
	}
	if typeof(raw.Stats) == "table" then
		if typeof(raw.Stats.Bought) == "number" then
			stats.Bought = math.max(0, raw.Stats.Bought)
		end
		if typeof(raw.Stats.Stolen) == "number" then
			stats.Stolen = math.max(0, raw.Stats.Stolen)
		end
		if typeof(raw.Stats.Lost) == "number" then
			stats.Lost = math.max(0, raw.Stats.Lost)
		end
	end

	local slots: { [number]: SlotEntry } = {}
	if typeof(raw.Slots) == "table" then
		for key, entry in raw.Slots do
			local slotNum = tonumber(key)
			if slotNum and typeof(entry) == "table" and typeof(entry.Id) == "string" then
				slots[math.floor(slotNum)] = {
					Id = entry.Id,
					Growth = if typeof(entry.Growth) == "number" then math.max(0, entry.Growth) else 0,
					Mutation = if typeof(entry.Mutation) == "string" then entry.Mutation else nil,
				}
			end
		end
	end

	return {
		Money = if typeof(raw.Money) == "number" and raw.Money >= 0 then raw.Money else (Config.StartMoney or 50),
		Rebirths = if typeof(raw.Rebirths) == "number" and raw.Rebirths >= 0 then raw.Rebirths else 0,
		Slots = slots,
		Bank = if typeof(raw.Bank) == "number" and raw.Bank >= 0 then raw.Bank else 0,
		LastOnline = if typeof(raw.LastOnline) == "number" and raw.LastOnline > 0 then raw.LastOnline else os.time(),
		Stats = stats,
	}
end

local function loadAndLockProfile(player: Player): Profile?
	local dataKey = PLAYER_KEY_PREFIX .. tostring((player :: any).UserId)
	local attempts = 0
	local isLockedByOther = false
	local otherServerJobId: string? = nil

	while attempts < MAX_RETRIES do
		if not player:IsDescendantOf(Players) then
			return nil
		end

		attempts += 1
		isLockedByOther = false
		otherServerJobId = nil
		local acquiredRecord: StoredRecord? = nil

		local ok, err = performUpdateAsync(dataKey, function(current)
			-- UpdateAsync may run the transform more than once; only the last run counts
			isLockedByOther = false
			otherServerJobId = nil
			acquiredRecord = nil
			local now = os.time()
			local currentData, currentLock = normalizeRecord(current)

			local activeOnOther, otherJob = isLockActiveOnAnotherServer(currentLock, now)
			if activeOnOther then
				isLockedByOther = true
				otherServerJobId = otherJob
				return nil -- Abort update without modifying DataStore
			end

			-- Lock is free, owned by this server, or expired
			local profileDataToSave
			if currentData and next(currentData :: any) ~= nil then
				profileDataToSave = currentData
			else
				profileDataToSave = serializeProfile(createDefaultProfile())
			end

			local newRecord: StoredRecord = {
				Data = profileDataToSave,
				Lock = {
					JobId = SERVER_SESSION_ID,
					Time = now,
				},
			}
			acquiredRecord = newRecord
			return newRecord
		end)

		if not player:IsDescendantOf(Players) then
			-- If player left while network call was in flight, immediately release the acquired lock
			if acquiredRecord then
				task.spawn(function()
					performUpdateAsync(dataKey, function(current)
						local curData, curLock = normalizeRecord(current)
						if curLock and curLock.JobId == SERVER_SESSION_ID then
							return {
								Data = curData or serializeProfile(createDefaultProfile()),
								Lock = nil,
							}
						end
						return nil
					end)
				end)
			end
			return nil
		end

		if ok and not isLockedByOther and acquiredRecord ~= nil then
			-- Lock acquired and data loaded successfully
			local profile = deserializeProfile(acquiredRecord.Data)
			profiles[player] = profile

			player:SetAttribute("Money", profile.Money)
			player:SetAttribute("Rebirths", profile.Rebirths)

			Data.loaded:Fire(player, profile)
			return profile
		end

		if isLockedByOther then
			warn("[Data] Profile for " .. tostring((player :: any).Name) .. " (UserId: " .. tostring((player :: any).UserId) .. ") is locked by server session " .. tostring(otherServerJobId or "unknown") .. " (attempt " .. tostring(attempts) .. "/" .. tostring(MAX_RETRIES) .. ")")
		else
			warn("[Data] Failed to load data for " .. tostring((player :: any).Name) .. " (attempt " .. tostring(attempts) .. "/" .. tostring(MAX_RETRIES) .. "): " .. tostring(err))
		end

		if attempts < MAX_RETRIES then
			local delay = RETRY_BASE_DELAY * (1.5 ^ (attempts - 1))
			task.wait(delay)
		end
	end

	-- Retries exhausted: kick player with an informative message
	if player:IsDescendantOf(Players) then
		if isLockedByOther then
			player:Kick("Your save profile is currently loaded on another server. Please wait a minute and reconnect.")
		else
			player:Kick("Failed to load your save data due to a DataStore error. Please reconnect.")
		end
	end

	return nil
end

local function saveProfile(player: Player, unlock: boolean): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end

	-- Wait if another save is currently executing for this player
	while isSaving[player] do
		task.wait(0.05)
	end

	profile = profiles[player]
	if not profile then
		return false
	end

	isSaving[player] = true
	local dataKey = PLAYER_KEY_PREFIX .. tostring((player :: any).UserId)
	local serialized = serializeProfile(profile)
	local saveSuccess = false

	for attempt = 1, MAX_SAVE_RETRIES do
		local lockStolen = false
		local ok, err = performUpdateAsync(dataKey, function(current)
			lockStolen = false
			local now = os.time()
			local _curData, curLock = normalizeRecord(current)

			local activeOnOther, _ = isLockActiveOnAnotherServer(curLock, now)
			if activeOnOther then
				lockStolen = true
				return nil -- Do not overwrite data if another server claimed the profile
			end

			local newRecord: StoredRecord = {
				Data = serialized,
				Lock = if unlock then nil else {
					JobId = SERVER_SESSION_ID,
					Time = now,
				},
			}
			return newRecord
		end)

		if lockStolen then
			warn(string.format("[Data] Save aborted for %s: session lock was claimed by another server", tostring((player :: any).Name)))
			if player:IsDescendantOf(Players) then
				player:Kick("Your save session was claimed by another server.")
			end
			break
		end

		if ok then
			saveSuccess = true
			break
		else
			warn(string.format("[Data] Save attempt %d failed for %s: %s", attempt, tostring((player :: any).Name), tostring(err)))
			if attempt < MAX_SAVE_RETRIES then
				task.wait(1 * attempt)
			end
		end
	end

	isSaving[player] = false

	if unlock then
		profiles[player] = nil
	end

	return saveSuccess
end

local function startAutoSaveLoop()
	task.spawn(function()
		while isRunning do
			task.wait(AUTO_SAVE_INTERVAL)
			if not isRunning then
				break
			end

			for _, player in Players:GetPlayers() do
				if not isRunning then
					break
				end
				if profiles[player] and not isSaving[player] then
					task.spawn(function()
						saveProfile(player, false)
					end)
					task.wait(0.5) -- Stagger requests across players
				end
			end
		end
	end)
end

local function onBindToClose()
	isRunning = false
	local playersToSave: { Player } = {}
	for player, _ in profiles do
		table.insert(playersToSave, player)
	end

	if #playersToSave == 0 then
		return
	end

	print(string.format("[Data] BindToClose: saving %d player profiles in parallel...", #playersToSave))

	local remaining = #playersToSave
	local currentThread = coroutine.running()

	for _, player in playersToSave do
		task.spawn(function()
			local ok, err = pcall(function()
				saveProfile(player, true) -- Save and release lock
			end)
			if not ok then
				warn(string.format("[Data] BindToClose save error for %s: %s", player.Name, tostring(err)))
			end
			remaining -= 1
			if remaining == 0 and coroutine.status(currentThread) == "suspended" then
				task.spawn(currentThread)
			end
		end)
	end

	-- Wait for parallel saves to finish, with a safety timeout (25 seconds)
	local timeout = 25
	local startTime = os.clock()
	while remaining > 0 and (os.clock() - startTime) < timeout do
		task.wait(0.1)
	end

	print(string.format("[Data] BindToClose complete. Unsaved count: %d", remaining))
end

local function onPlayerAdded(player: Player)
	loadAndLockProfile(player)
end

local function onPlayerRemoving(player: Player)
	if profiles[player] then
		saveProfile(player, true)
	end
end

function Data.init()
	if isInitialized then
		return
	end
	isInitialized = true

	checkDataStoreAccess()

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(onPlayerRemoving)

	game:BindToClose(onBindToClose)

	startAutoSaveLoop()
end

function Data.get(player: Player): Profile?
	return profiles[player]
end

function Data.addMoney(player: Player, n: number): number?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	profile.Money = math.max(0, profile.Money + n)
	player:SetAttribute("Money", profile.Money)
	return profile.Money
end

function Data.setMoney(player: Player, amount: number): number?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	profile.Money = math.max(0, amount)
	player:SetAttribute("Money", profile.Money)
	return profile.Money
end

function Data.setRebirths(player: Player, rebirths: number): number?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	profile.Rebirths = math.max(0, rebirths)
	player:SetAttribute("Rebirths", profile.Rebirths)
	return profile.Rebirths
end

function Data.save(player: Player): boolean
	return saveProfile(player, false)
end

function Data.release(player: Player): boolean
	return saveProfile(player, true)
end

return Data
