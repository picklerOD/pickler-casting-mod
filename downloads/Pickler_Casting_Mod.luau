local function dist(a, b) return (a - b):length() end
local function damp(cur, tgt, spd, dt) return cur + (tgt - cur) * (1 - math.exp(-spd * dt)) end
local function dampV(cur, tgt, spd, dt) return Vec3.lerp(cur, tgt, 1 - math.exp(-spd * dt)) end

local function smoothDampF(cur, tgt, vel, smoothTime, dt)
	smoothTime = math.max(0.0001, smoothTime)
	local omega = 2 / smoothTime
	local x = omega * dt
	local expf = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
	local change = cur - tgt
	local temp   = (vel + omega * change) * dt
	local newVel = (vel - omega * temp) * expf
	return tgt + (change + temp) * expf, newVel
end

local function smoothDampVec(cur, tgt, vel, smoothTime, dt)
	smoothTime = math.max(0.0001, smoothTime)
	local omega = 2 / smoothTime
	local x = omega * dt
	local expf = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
	local change = cur - tgt
	local temp   = (vel + change * omega) * dt
	local newVel = (vel - temp * omega) * expf
	return tgt + (change + temp) * expf, newVel
end

local function quatDot(a, b) return a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w end
local function quatNeg(q)   return Quat.new(-q.x, -q.y, -q.z, -q.w) end

local function dampQ(cur, tgt, spd, dt)
	if quatDot(cur, tgt) < 0 then tgt = quatNeg(tgt) end
	local t = math.clamp(1 - math.exp(-spd * dt), 0, 1)
	return Quat.slerp(cur, tgt, t)
end

local function flattenDir(v, up)
	local flat = v - up * Vec3.dot(v, up)
	if flat:length() < 0.001 then return nil end
	return flat:getSafeNormal()
end

local function safeFromXZ(lookDir, up, fallback)
	if lookDir:length() < 0.001 then return fallback end
	local flat = lookDir - up * Vec3.dot(lookDir, up)
	if flat:length() < 0.05 then return fallback end
	return Quat.fromXZ(lookDir, up)
end

local _frameCache  = {}
local _loadedCount = nil

local function loadedCount()
	if _loadedCount == nil then
		local ok, list = pcall(Replay.listLoaded)
		_loadedCount = (ok and list) and #list or 0
	end
	return _loadedCount
end

local function getFrame(i)
	i = math.clamp(i, 0, loadedCount())
	local cached = _frameCache[i]
	if cached ~= nil then return cached end
	local r = Replay.getByIndex(i)
	local f = (r and r:getCurrentFrame(true)) or getGameData()
	_frameCache[i] = f
	return f
end

local function isArenaBall(b)
	local j = b:toJson()
	local c1, c2 = j:match('"color1"%s*:%s*(%b{})'), j:match('"color2"%s*:%s*(%b{})')
	if not c1 or not c2 then return false end
	local function ok(s)
		for _, k in ipairs({"r","g","b","a"}) do
			if tonumber(s:match('"'..k..'"%s*:%s*(%d+)')) ~= 255 then return false end
		end
		return true
	end
	return ok(c1) and ok(c2)
end

local function dictSize(d)
	local n = 0; if d then for _ in pairs(d) do n = n + 1 end end; return n
end

local function deepCopy(src, dst)
	local changed = false
	if type(src) ~= "table" then return changed end
	for k, v in pairs(src) do
		if dst[k] == nil or type(dst[k]) ~= type(v) then
			changed = true; dst[k] = v
		elseif type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {}; changed = true end
			if deepCopy(v, dst[k]) then changed = true end
		end
	end
	return changed
end

local function deepClean(src, dst)
	local changed = false
	if type(dst) ~= "table" then return changed end
	for k in pairs(dst) do
		if src[k] == nil then changed = true; dst[k] = nil
		elseif type(dst[k]) == "table" then
			if deepClean(src[k], dst[k]) then changed = true end
		end
	end
	return changed
end

local function upgradeConfig()
	local ver = config.version or 1
	if ver < 2 then
		config.bcPosSmooth = 40
		config.bcRotSmooth = 5
		config.bcDirSmooth = 10
		config.bcLookAhead = 0.060
		config.bcFOV       = 130
		config.version = 2
		saveConfig()
	end
	if ver < 3 then
		config.bcPosSmooth = 40
		config.bcRotSmooth = 10
		config.bcDirSmooth = 5
		config.bcLookAhead = 0.060
		config.bcFOV       = 125
		config.version = 3
		saveConfig()
	end
	if ver < 4 then
		config.bcPosSmooth = 40
		config.bcRotSmooth = 10
		config.bcDirSmooth = 5
		config.bcLookAhead = 0.060
		config.bcFOV       = 125
		config.version = 4
		saveConfig()
	end
	if ver < 5 then
		-- (smooth-follow defaults removed with the mode)
		config.version = 5
		saveConfig()
	end
	if ver < 6 then
		config.bcCrowdRadius    = 650
		config.bcCrowdThreshold = 4
		config.bcCrowdFull      = 4
		config.bcCrowdStepBack  = 0.6
		config.bcLeadDot        = 0.6
		config.version = 6
		saveConfig()
	end
	if ver < 7 then
		config.camBlendDuration = 0.40
		config.version = 7
		saveConfig()
	end
	if ver < 8 then
		config.bcGoalLookBias = 0.5
		config.version = 8
		saveConfig()
	end
	if ver < 9 then
		-- Third Person + Smooth Follow removed. Any leftover sf* keys are
		-- stripped automatically by deepClean against the new defaults.
		config.version = 9
		saveConfig()
	end
	if ver < 10 then
		-- Pickler Flicker becomes the default goal celebration (one-time switch).
		config.goalFxType = 11
		config.version = 10
		saveConfig()
	end
	if ver < 11 then
		-- Old celebrations replaced by the Rocket League top 10; start on Top 10 Shuffle.
		config.goalFxType = 11
		config.version = 11
		saveConfig()
	end
	if ver < 12 then
		-- Goal explosions rebuilt (v2 engine): old picks don't map, so start on Shuffle, and give
		-- the new effects enough time to play out.
		config.goalFxType = 9
		config.goalFxDuration = 3.6
		config.version = 12
		saveConfig()
	end
	if ver < 13 then
		-- Halloween + Guacward added before Shuffle, which moved from 9 to 12.
		if config.goalFxType == 9 then config.goalFxType = 12 end
		config.version = 13
		saveConfig()
	end
	if ver < 14 then
		-- Old ball trails replaced by Yuki-style themes (old numbers don't map); start on Yuki Classic.
		config.ballTrailStyle = 1
		config.version = 14
		saveConfig()
	end
	if ver < 15 then
		-- Death Note added before Shuffle, which moved from 12 to 13.
		if config.goalFxType == 12 then config.goalFxType = 13 end
		config.version = 15
		saveConfig()
	end
	if ver < 16 then
		-- Goal camera pulled further back so the whole explosion fits on screen.
		if (config.goalFxFreeCamDist or 450) <= 450 then config.goalFxFreeCamDist = 750 end
		config.version = 16
		saveConfig()
	end
	if ver < 17 then
		-- Christmas explosions added before Shuffle, which moved from 13 to 16.
		if config.goalFxType == 13 then config.goalFxType = 16 end
		config.version = 17
		saveConfig()
	end
	if ver < 18 then
		-- Eight more explosions added before Shuffle, which moved from 16 to 24.
		if config.goalFxType == 16 then config.goalFxType = 24 end
		config.version = 18
		saveConfig()
	end
	if ver < 19 then
		-- Private Property meme added before Shuffle, which moved from 24 to 25.
		if config.goalFxType == 24 then config.goalFxType = 25 end
		config.version = 19
		saveConfig()
	end
	if ver < 20 then
		-- Divine Ascension added before Shuffle, which moved from 25 to 26.
		if config.goalFxType == 25 then config.goalFxType = 26 end
		config.version = 20
		saveConfig()
	end
	if ver < 21 then
		-- New Year's and Valentine's added before Shuffle, which moved from 26 to 28.
		if config.goalFxType == 26 then config.goalFxType = 28 end
		config.version = 21
		saveConfig()
	end
	if ver < 22 then
		-- GG EZ meme added before Shuffle, which moved from 28 to 29.
		if config.goalFxType == 28 then config.goalFxType = 29 end
		config.version = 22
		saveConfig()
	end
	if ver < 23 then
		-- Plutus dribble first-person removed: drop its saved settings.
		for _,k in ipairs({"plDribbleFP","plDribbleHold","plDribbleLook","plFirstPersonFOV","plFPForward","plFPLead",
			"plFPDrawHands","plFPHideHead","plFollowRadius","plFollowPosSmooth"}) do config[k] = nil end
		config.version = 23
		saveConfig()
	end
	if ver < 24 then
		-- Jackpot and Paparazzi added before Shuffle, which moved from 29 to 31.
		if config.goalFxType == 29 then config.goalFxType = 31 end
		config.version = 24
		saveConfig()
	end
	if ver < 25 then
		-- Shuffle Favorites added, then Busted, Bullseye and Light Show before the shuffles:
		-- Shuffle 31 -> 34, Shuffle Favorites 32 -> 35.
		if config.goalFxType == 31 then config.goalFxType = 34
		elseif config.goalFxType == 32 then config.goalFxType = 35 end
		config.version = 25
		saveConfig()
	end
	if ver < 26 then
		-- Rocket Launch and UFO Abduction added before the shuffles: 34 -> 36, 35 -> 37.
		if config.goalFxType == 34 then config.goalFxType = 36
		elseif config.goalFxType == 35 then config.goalFxType = 37 end
		config.version = 26
		saveConfig()
	end
	if ver < 27 then
		-- Four Christmas explosions added before the shuffles: 36 -> 40, 37 -> 41.
		if config.goalFxType == 36 then config.goalFxType = 40
		elseif config.goalFxType == 37 then config.goalFxType = 41 end
		config.version = 27
		saveConfig()
	end
	if ver < 28 then
		-- Xeno added before the shuffles: 40 -> 41, 41 -> 42.
		if config.goalFxType == 40 then config.goalFxType = 41
		elseif config.goalFxType == 41 then config.goalFxType = 42 end
		config.version = 28
		saveConfig()
	end
end

local function initConfig(dc)
	if type(config) ~= "table" then config = {} end
	local s = deepCopy(dc, config) or deepClean(dc, config)
	if s then saveConfig() end
	upgradeConfig()
end

local TI = {None = -1, Home = 0, Away = 1}

local Box = {}; Box.__index = Box

function Box.new(pos, size, rot)
	local self = setmetatable({position = pos, size = size, rotation = rot}, Box)
	self:_build(); return self
end

function Box:_build()
	local s = self.size * 0.5
	local vecs   = {Vec3.new(1,0,0), Vec3.new(0,1,0), Vec3.new(0,0,1)}
	local halves = {s.x, s.y, s.z}
	local axes   = {}
	for i = 1, 3 do
		axes[i] = {normal = self.rotation:rotateVector(vecs[i]):getSafeNormal(), half = halves[i]}
	end
	self._axes = axes
end

function Box:contains(point)
	if not point then return false end
	local d = point - self.position
	for _, a in ipairs(self._axes) do
		if math.abs(Vec3.dot(d, a.normal)) > a.half then return false end
	end
	return true
end

Box.empty = Box.new(Vec3.zeroVector, Vec3.zeroVector, Quat.identity)

initConfig({
	version = 28,

	firstPersonFOV = 100,

	-- Follow-camera framing (used by PLAYER FOLLOW)
	tpDist = 200, tpHeight = 70, tpFOV = 90,
	tpSmooth = 14, tpRotSmooth = 16, tpDirSmooth = 8,

	bcDist = 190, bcHeight = 115, bcFOV = 125,
	bcPosSmooth = 40, bcRotSmooth = 10, bcDirSmooth = 5,
	bcMaxDirChangeRate = 2.5, bcFOVSmooth = 3.0,
	bcSpeedFOVEnabled = true, bcSpeedFOVMax = 15,
	bcLeadDot = 0.6,
	-- Camera profile: 1 = Plutus (orbit cam), 2 = Zepy (crowd + goal awareness), 3 = Yuki (sideline)
	camProfile = 1,
	-- Plutus orbit camera (profile 1), defaults from Plutus' autocaster
	plBaseFOV = 90, plSmooth = 8, plDistBase = 220, plHeightBase = 120,
	plDistMax = 1500, plHeightMax = 1000,
	plDistSpeedBonus = 120, plHeightSpeedBonus = 60,
	plDistSpreadBonus = 80, plHeightSpreadBonus = 45,
	plDistGoalPenalty = 60, plHeightGoalBonus = 30,
	plOrbitBias = 0.6, plLead = 0.4,
	plCollision = true, plCollisionStrength = 1.0, plCollisionRadius = 80,
	plPlayerRay = true, plPlayerRayStrength = 1.2, plPlayerRayUp = 25,
	-- Snowman casting camera (profile 4), defaults from Snowman's CastCam
	snMode = 1, snDist = 300, snHeight = 200, snSmooth = 6, snDirSmooth = 4, snFOV = 90, snBuffer = 0.3,
	-- Yuki sideline camera (profile 3)
	yukiSideDist = 2093, yukiSwitchWidth = 1000, yukiHeightOffset = 200,
	yukiAutoSwitch = true, yukiInstantSwitch = true, yukiSewerCam = true,
	yukiHookEnabled = true, yukiHookY = 1.4, yukiHookX = 0,
	yukiRiser = false, yukiRailLength = 4000, yukiMaxHeight = 1329,
	yukiPostFx = false,
	yukiZoomEnabled = true, yukiZoomSize = 0.035, yukiFOV = 60,
	yukiPosSmooth = 0.3, yukiRotSmooth = 0.3, yukiFovSmooth = 0.05,
	bcCrowdRadius = 650, bcCrowdThreshold = 4, bcCrowdFull = 4,
	bcCrowdStepBack = 0.6,
	bcGoalProximity = 1200, bcGoalLookBias = 0.5,
	bcIntelligentMode = true,
	bcMinPlayerDist = 180, bcMinWallDist = 100,
	bcCeilingBuffer = 30, bcCollisionProbeRadius = 80, bcMinCamDist = 200,
	bcBallStationaryThreshold = 50, bcBallIdleTime = 0.5,
	bcGoalCelebrationTime = 3.0, bcGoalCamDist = 500, bcGoalCamHeight = 200,

	bcKickoffOrbitEnabled = true, bcKickoffOrbitSpeed = 20,
	bcKickoffRadius = 450, bcKickoffHeight = 160,
	bcKickoffCenterDist = 350, bcKickoffFOV = 95,

	useSpringSmoothing = true,
	bcLookAhead = 0.060,

	-- cross-mode blend (eases switches so they don't cut)
	camBlendDuration = 0.40,

	playerFollowEnabled = false,
	playerFollowTargetName = "zepyX",

	autoFollowEnabled = false,
	autoFollowTargetName = "zepyX",
	autoFollowDist = 400, autoFollowHeight = 200, autoFollowFOV = 100,
	autoFollowPosSmooth = 5, autoFollowRotSmooth = 6,

	verticalCameraEnabled  = false,
	verticalCameraMaxAngle = 60,
	verticalCameraSmooth   = 6,

	showNameTags = true,
	keyboardKeybinds = "",
	gamepadKeybinds  = "",

	showGui = true,

	kfInterpMode       = 1,
	kfTension          = 0.5,
	kfFreeCamSpeed     = 1600,
	kfFreeCamRotSpeed  = 180,
	kfMouseSensitivity = 3.6,
	kfFreeCamFOV       = 90,
	kfSpeedMultiplier  = 1.0,
	kfLooping          = false,
	kfUseFreeCam       = true,
	kfLookSmoothness   = 0.0,
	kfFovRotSpeedMult  = 2.0,
	kfZoomSpeedMouse   = 5.0,
	kfZoomSpeedKey     = 60.0,
	kfMinFOV           = 10,
	kfMaxFOV           = 160,
	kfAlignToGravity   = true,
	kfGravityChaseSpeed= 3.0,
	kfGravitySlowChase = 0.4,
	kfMinMoveSpeed     = 50,
	kfMaxMoveSpeed     = 6000,
	kfSpeedAdjustRate  = 2.0,
	kfLocalMoveAxes    = false,
	kfRollResetTol     = 5,

	kfShowPath         = true,
	kfPathSamples      = 16,
	kfMarkerSize       = 40,
	kfLineThickness    = 8,

	kfSnapEnabled      = true,
	kfSnapStep         = 1.0,

	hudStatsEnabled     = true,
	hudDist             = 600,
	hudScale            = 7,
	hudThickness        = 2,
	hudStatsRightOffset = 240,
	hudStatsTopOffset   = 120,
	hudStatsLineGap     = 9,
	hudColorR           = 1.0,
	hudColorG           = 1.0,
	hudColorB           = 1.0,

	showLeaderboard      = true,

	ballTrailEnabled      = true,
	ballTrailStyle        = 1,
	pfView = 1,            -- Player camera: 1 third person, 2 first person
	pfThirdStyle = 1,      -- 1 Pickler chase, 2 Follow+ head, 3 Follow+ velocity, 4 Follow+ face the ball
	followEngine = 1,      -- 1 use Follow+ when installed, 2 always built-in
	followRadius = 20,     -- Follow+ third person distance
	followPosSmooth = 0.1, -- Follow+ third person position smoothing
	clipPostSeconds = 5,   -- seconds after the goal to keep, used by the clip companion and game replays
	clipEventId = 0,       -- goes up by one for every clip; the companion watches this in the config file
	clipEventTeam = "",
	clipRecordReplays = false,
	ballTrailMode         = 1,      -- 1 = Pixelated trails, 2 = Beam trails
	yukiBeamWidth         = 0.6,    -- beam trail width multiplier
	ballTrailLength       = 28,
	ballTrailChunkSize    = 30,
	ballTrailThickness    = 10,
	yukiTrailSeconds      = 0.15,   -- Yuki trail: how long the trail is (seconds)
	yukiTrailThick        = 25,     -- Yuki trail: thickness at the ball
	yukiTrailGlow         = 1.5,    -- Yuki trail: brightness
	ballTrailParticles    = true,
	ballTrailParticleSize = 9,
	ballTrailParticleRate = 0.86,

	goalFxEnabled = true,
	plDribbleFP = true, plDribbleHold = 1.0, plDribbleLook = 1, plFirstPersonFOV = 110,   -- Plutus first person
	goalFxType = 41,   -- 1-40 = goal explosions, 41 = Shuffle, 42 = Shuffle Favorites
	goalFxFavs = "",   -- favorites as "|Name|Name|"
	goalFxShake = true,          -- big goal explosions shake the camera a little
	goalFxBrowseCat = "all",     -- explosion browser tab: all / premium / holiday / meme
	-- QUALITY tab
	qualityPreset = 4,           -- 1 Potato .. 5 Ultra (last overall preset clicked)
	shEnabled = false,           -- in-game shaders on (false = game default post-process)
	shPreset = 1,
	shBloom = 0.675, shBloomThreshold = -1, shExposure = 0, shVignette = 0.4,
	shChroma = 0, shMotion = 0.5,
	shDof = false, shDofFstop = 2.8, shDofSensor = 24.576, shDofAuto = true, shDofDist = 1000,
	-- AUDIO tab: 0 = leave voice chat alone, 1 = mute everyone, 2 = only hear the selected arena
	audioMode = 0,
	uiAccent = 1,                -- menu accent colour (CREDITS tab)
	deathNoteTestName = "Pickler", -- name the Death Note writes when you TEST / PLAY it
	deathNoteDim      = true,      -- Death Note dims the scene and adds a vignette while it plays
	goalFxColorR = 0.10,
	goalFxColorG = 0.82,
	goalFxColorB = 0.92,
	goalFxSize = 1.0,
	-- Ascendancy celebration layout (tune in GOAL EXPLOSIONS settings)
	goalFxTextOffsetX = 0,     -- + moves right (as the camera sees it), - moves left
	goalFxTextOffsetY = 110,   -- height above the goal's centre point
	goalFxTextSize    = 1.0,   -- scales the lettering AND the fireworks beside it
	goalFxDuration    = 3.6,   -- total seconds for the explosion timeline
	goalFxQuality     = 3,     -- 1 Low, 2 Medium, 3 High, 4 Ultra (particle budget)
	goalFxGlow        = 1.6,   -- brightness of the glow (higher = more bloom)
	goalFxLights      = true,  -- big hits spawn real point lights that light up the arena
	goalFxTeamDragons = false, -- Dragon Duel uses the two team colours instead of blue vs red
	-- Preview helpers (GOAL EXPLOSIONS settings)
	goalFxTestFreeCam = true,  -- TEST / PLAY buttons also fly the camera to the goal in free cam
	goalFxFlash = false,       -- false = bright flashes in the celebrations are softened
	bcGoalCamEnabled = false,  -- false = the broadcast camera does NOT swing to the goal after a score
	uiAdvanced = false,        -- UI: show advanced options
	goalFxFreeCamDist = 750,   -- how far back the goal camera sits (real goals and previews)
	goalFxCamHeight   = 60,    -- how high the goal camera sits above the celebration's centre
	goalFxCamFOV      = 100,   -- goal camera zoom (higher = wider view)
	goalFxTestLoop    = false, -- keep replaying a previewed celebration so you can tune it
	goalFxAutoCam     = true,  -- on a real goal, move the camera in front of the goal so the celebration is visible
	kickoffFxEnabled  = true,  -- play an explosion at the ball when a kickoff happens
	kickoffFxSize     = 1.0,
	kickoffFxDuration = 1.6,
	kickCamBack = 400,   -- how far the camera eases back while the ball waits in the middle
	kickCountEnabled = true,
	kickCountNumbers = true,
	kickCountRing = true,
	kickCountFrom = 5,
	kickCountHeight = 170,
	kickFxColor = 1,
	clipHomeGoals = false,   -- Auto Clip: count HOME team goals
	clipAwayGoals = false,   -- Auto Clip: count AWAY team goals
	clipCount = 0,           -- how many counted goals so far
	presetSel = 1,
	presetName1 = "Preset 1",
	presetData1 = "",
	presetName2 = "Preset 2",
	presetData2 = "",
	presetName3 = "Preset 3",
	presetData3 = "",
	presetName4 = "Preset 4",
	presetData4 = "",
	presetName5 = "Preset 5",
	presetData5 = "",
	presetName6 = "Preset 6",
	presetData6 = "",

	showLeanIndicators  = false,
	leanLineLength      = 30,
	leanSideOffset      = 35,
	leanLineThickness   = 4,
	leanMaxAngle        = 45,


	guiTabOpen = {
		players     = true,
		broadcast   = true,
		movement    = false,
		autoFollow  = false,
		advanced    = false,
		followCam   = true,
		fpSettings  = true,
		keyframes   = false,
		scoreboard  = true,
		ballTrail   = true,
		history     = true,
		caster      = true,
	},
})

local Arena = {}; Arena.__index = Arena

function Arena.new(gm, fi, boxSize, boxOff, centerOff, goalSize, goalOff, hRot, aRot)
	local self = setmetatable({}, Arena)
	self.frameIndex = fi; self.gamemode = gm; self.transform = gm.transform
	self.slotId = gm:getSlotId(); self.name = self.slotId:gsub("TKB", "")
	self._bs = boxSize; self._bo = boxOff; self._co = centerOff
	self._gs = goalSize; self._go = goalOff; self._hr = hRot; self._ar = aRot
	self.players = {}; self.ball = nil
	self.home = {players={}, score=0, color=LinearColor.White, goal={}}
	self.away = {players={}, score=0, color=LinearColor.White, goal={}}
	self.isActive = false; self.wasActive = false
	self.lastHomeScore = 0; self.lastAwayScore = 0
	self.goalScoredTime = 0; self.goalScoredTeam = -1; self.goalScoredGoal = nil
	self:_setup()
	return self
end

function Arena:_setup()
	local t = self.transform
	self.box = Box.new(t.position + t.rotation:rotateVector(self._bo), self._bs, t.rotation)
	self.forward = t.rotation:getForwardVector()
	self.right   = t.rotation:getRightVector()
	self.up      = t.rotation:getUpVector()
	self.center  = t.position + t.rotation:rotateVector(self._co)
	for _, ti in ipairs({TI.Home, TI.Away}) do
		local rOff = ti == TI.Home and self._hr or self._ar
		local gPos = t.position + (t.rotation * rOff):rotateVector(self._go)
		local gRot = t.rotation * rOff:inverse()
		local team = ti == TI.Home and self.home or self.away
		team.goal  = {position=gPos, rotation=gRot, box=Box.new(gPos, self._gs, gRot), teamIndex=ti}
	end
end

function Arena:_findBall()
	local balls = self.frame.balls; local best, bd = nil, math.huge
	for i in pairs(balls) do
		local b = balls[i]
		if not self.box:contains(b.transform.position) then continue end
		if not isArenaBall(b) then continue end
		local d = dist(self.transform.position, b.transform.position)
		if d < bd then bd = d; best = b end
	end
	return best
end

function Arena:tick(totalTime, frameIndex)
	if frameIndex ~= nil then self.frameIndex = frameIndex end
	self.frame = getFrame(self.frameIndex)
	local tc = self.gamemode:getTeamColorsArray()
	if tc[1] and tc[1].primary then self.home.color = tc[1].primary end
	if tc[2] and tc[2].primary then self.away.color = tc[2].primary end
	self.ball = self:_findBall()
	self.wasActive = self.isActive
	self.isActive  = self.gamemode:getIsGameRunning()
	local nH = self.gamemode:getTeamScore(TI.Home)
	local nA = self.gamemode:getTeamScore(TI.Away)
	if nH > self.lastHomeScore then
		self.goalScoredTime = totalTime; self.goalScoredTeam = TI.Home; self.goalScoredGoal = self.away.goal
	elseif nA > self.lastAwayScore then
		self.goalScoredTime = totalTime; self.goalScoredTeam = TI.Away; self.goalScoredGoal = self.home.goal
	end
	self.home.score = nH; self.away.score = nA
	self.lastHomeScore = nH; self.lastAwayScore = nA
	local th, ta = {}, {}
	for _, p in ipairs(self.frame.players) do
		if p.teamIndex == TI.None or not self.box:contains(p.root.position) then continue end
		if p.teamIndex == TI.Home then th[#th+1] = p else ta[#ta+1] = p end
	end
	self.home.players = th; self.away.players = ta
	local all = {}
	for _, p in ipairs(th) do all[#all+1] = p end
	for _, p in ipairs(ta) do all[#all+1] = p end
	self.players = all
end

local Q = Quat.fromEuler
local presets = {
	["3v3"] = {Vec3.new(5100,6750,1440),  Vec3.new(0,0,650), Vec3.new(0,0,300), Vec3.new(150,500,225), Vec3.new(3250,0,175), Q(0,0,90), Q(0,0,-90)},
	["4v4"] = {Vec3.new(6110,8400,1490),  Vec3.new(0,0,600), Vec3.new(0,0,250), Vec3.new(220,450,225), Vec3.new(4050,0,175), Q(0,0,90), Q(0,0,-90)},
	drift  = {Vec3.new(7270,11825,1440),  Vec3.new(0,0,740), Vec3.new(0,0,100), Vec3.new(100,890,300), Vec3.new(5295,0,175), Q(0,0,90), Q(0,0,-90)},
	zdrift = {Vec3.new(7180,17800,1710),  Vec3.new(0,0,880), Vec3.new(0,0,500), Vec3.new(600,600,600), Vec3.new(8200,0,585), Q(0,0,90), Q(0,0,-90)},
}

local function classifyArena(id)
	if id:find("ZDrift")  then return "zdrift" end
	if id:find("Soccer")  then return "drift"  end
	if id:find("Jakeball") or id:find("Driftball") or id:find("Beta") or id:find("Gamma") or id:find("Alpha")
		or (id:find("TKB") and id:find("Driftplex") and not id:find("Full")) then return "4v4" end
	if id:find("TKB") and not id:find("Driftplex") and not id:find("Full") and not id:find("Playground") then return "3v3" end
	return nil
end

-- Mode ids are intentionally left with gaps where THIRD PERSON (2) and
-- SMOOTH FOLLOW (7) used to sit, so existing keybinds keep working.
local Mode = {FP=1, DYN=3, PFOLLOW=4, KEYFRAME=5, CASTER=6}
local MODE_NAMES = {[1]="FIRST PERSON",[3]="BROADCAST",[4]="PLAYER FOLLOW",[5]="KEYFRAME",[6]="CASTER"}

local dt, totalTime, readLocation = 0, 0, 0
local camPos = Vec3.new(0,0,500)
local camRot = Quat.fromEuler(0,-30,0)
local camFOV = 90
local targetFOV = 90

local camPosVel = Vec3.zeroVector
local camFOVVel = 0

local curMode  = Mode.DYN
local prevMode = Mode.DYN

-- cross-mode blend state: when the active mode changes we snapshot the
-- current camera and ease the final transform from that snapshot to the
-- new mode's live output, so switches never read as a hard cut.
local lastAppliedMode = nil
local modeBlend = {
	active = false, t = 0, dur = 0.40,
	pos = Vec3.zeroVector, rot = Quat.identity, fov = 90,
}

local curTarget = nil
local isLocked  = false
local curIdx    = 1
local arenas, selectedArena, arenaIdx, arenaKeys = nil, nil, 0, {}
local cachedGMCount = 0
local allServerPlayers = {}

local lastFullArenaTick     = -1
local fullArenaTickInterval = 0.1

local showGui = true
local lastTickError = nil

local smoothBallPos = Vec3.zeroVector
local smoothBallVel = Vec3.zeroVector

local possession = {player=nil, timer=0, team=-1}
local camBehavior = "IDLE"

local lockedDir      = Vec3.new(1,0,0)
local smoothDir      = Vec3.new(1,0,0)
local dirInitialized = false

local ballStationaryTimer = 0
local isBallStationary    = false

local bcSmoothPitch = 0

-- Broadcast lead smoothing.
local bcCrowdSmooth = 0   -- Zepy profile: 0 = open play .. 1 = full scrum
local bcGoalSmooth  = 0   -- Zepy profile: 0 = no goal bias .. 1 = look fully at the goal
local bcGoalLastPos = nil -- Zepy profile: last goal we biased toward
local bcLeadSmooth  = 0

local playerFollow = {
	targetName       = "zepyX",
	targetPlayer     = nil,
	isFollowing      = false,
	enabled          = false,
	smoothDir        = Vec3.new(1,0,0),
	dirInitialized   = false,
	smoothPitch      = 0,
}

local autoFollow = {
	enabled = false, targetName = "zepyX",
	foundPlayer = nil, foundArena = nil,
	isInArena = false, isActive = false,
	lastScanTime = 0, scanInterval = 0.25,
	smoothDir = Vec3.new(1,0,0), dirInitialized = false,
	smoothPitch = 0,
}

local goalCelebration = {isActive=false, startTime=0, goal=nil}
local kickoff = {active=false, angle=0}

local caster = {
	freecamActive = false,
	pos   = Vec3.zeroVector,
	yaw   = 0,
	pitch = 0,
	fov   = 90,
	speed = 1600,
	axisLock   = false,
	lookAtBall = false,
}


local ballTrail = {
	points = {},
	lastPos = nil,
	headPos = nil,
	fxTime = 0,
	moving = false,
	stillTime = 0,
}

-- BALL TRAILS: every style is a Yuki-style trail (time based, thick at the ball and thin at the
-- tail, colour fading from head to tail; see drawYukiTrail). Each theme is its colour stops from
-- head to tail plus an optional animation. team = Yuki's original team colours,
-- teamColor = the colour of the team that last had the ball in this arena.
YUKI_TRAIL_THEMES = {
	{name="Yuki Classic", team=true},
	{name="Inferno", stops={{1,1,.75},{1,.6,.05},{1,.15,0},{.35,.02,0}}, anim="flicker"},
	{name="Frostbite", stops={{1,1,1},{.55,.9,1},{.1,.45,1},{.02,.1,.4}}},
	{name="Toxic Waste", stops={{.9,1,.4},{.3,1,.1},{.05,.5,.05}}, anim="pulse"},
	{name="Galaxy", stops={{1,.85,1},{.9,.3,1},{.35,.2,1},{.05,.05,.35}}, anim="shimmer"},
	{name="Deep Ocean", stops={{.7,1,1},{0,.8,.9},{0,.35,.8},{0,.08,.3}}},
	{name="Sunset", stops={{1,.95,.5},{1,.55,.2},{1,.25,.5},{.4,.1,.6}}},
	{name="24K Gold", stops={{1,1,.85},{1,.8,.25},{.8,.5,.05},{.35,.2,.02}}, anim="shimmer"},
	{name="Blood Moon", stops={{1,.5,.4},{.9,.05,.05},{.4,0,0}}},
	{name="Pickle Juice", stops={{.85,1,.6},{.35,.9,.15},{.08,.45,.05}}},
	{name="Neon Rainbow", anim="rainbow"},
	{name="Vaporwave", stops={{.4,1,1},{.6,.5,1},{1,.3,.8}}},
	{name="Spooky", stops={{1,.6,.1},{.7,.2,1},{.2,1,.3}}, anim="pulse"},
	{name="Candy Cane", stops={{1,.1,.1},{1,1,1}}, anim="stripes"},
	{name="Electric", stops={{1,1,1},{.5,.8,1},{.15,.35,1}}, anim="flicker"},
	{name="Ghost", stops={{1,1,1},{.6,.75,.8},{.1,.12,.15}}},
	{name="Team Colors", teamColor=true},
	-- Christmas
	{name="Christmas Lights", stops={{1,.1,.1},{.1,1,.2},{1,.8,.1},{.2,.4,1}}, anim="stripes", stripeRate=16},
	{name="Santa", stops={{1,1,1},{1,.1,.08},{.6,.02,.02}}},
	{name="Holly Jolly", stops={{.2,1,.3},{1,.15,.1},{.05,.4,.1}}, anim="pulse"},
	{name="Frosty", stops={{1,1,1},{.75,.9,1},{.35,.6,1}}, anim="shimmer"},
	{name="Gingerbread", stops={{.6,.32,.12},{1,.95,.9}}, anim="stripes"},
	{name="Grinch", stops={{.6,1,.2},{.2,.7,.1},{.05,.25,.05}}, anim="flicker"},
	{name="Mistletoe", stops={{1,1,.9},{.3,.8,.3},{.1,.35,.1}}},
}

local BALL_TRAIL_STYLES = {}
for i, th in ipairs(YUKI_TRAIL_THEMES) do BALL_TRAIL_STYLES[i] = th.name end

local function resetBallTrail()
	ballTrail.points={}
	ballTrail.lastPos=nil
	ballTrail.headPos=nil
	ballTrail.fxTime=0
	ballTrail.moving=false
	ballTrail.stillTime=0
end

local function copyTrailV(v)
	return Vec3.new(v.x,v.y,v.z)
end

local function updateBallTrail(d)
	if not config.ballTrailEnabled or not selectedArena or not selectedArena.ball then
		resetBallTrail()
		return
	end

	-- Presentation only: raw ball transform keeps the PicklerCaster trail attached to the ball.
	local p=copyTrailV(selectedArena.ball.transform.position)
	local vel=selectedArena.ball.velocity or Vec3.zeroVector
	local speed=vel:length()
	local threshold=math.max(25,(config.bcBallStationaryThreshold or 50)*.60)
	local moved=ballTrail.lastPos and dist(p,ballTrail.lastPos) or 0

	if speed<=threshold and moved<5 then
		ballTrail.stillTime=ballTrail.stillTime+d
		ballTrail.moving=false
		if ballTrail.stillTime>=.045 then
			ballTrail.points={}
			ballTrail.lastPos=copyTrailV(p)
			ballTrail.headPos=nil
		end
		return
	end

	ballTrail.stillTime=0
	ballTrail.moving=true
	ballTrail.fxTime=ballTrail.fxTime+d
	ballTrail.headPos=copyTrailV(p)

	if not ballTrail.lastPos then
		ballTrail.lastPos=copyTrailV(p)
		return
	end

	moved=dist(p,ballTrail.lastPos)
	if moved<1.5 then return end

	local old=copyTrailV(ballTrail.lastPos)
	local dir=(p-old):getSafeNormal()
	local spacing=5
	local steps=math.min(math.max(1,math.ceil(moved/spacing)),36)

	for s=0,steps-1 do
		local frac=s/steps
		table.insert(ballTrail.points,1,{pos=copyTrailV(old+dir*(moved*frac))})
	end
	ballTrail.lastPos=copyTrailV(p)

	local maxPoints=math.floor(math.clamp(config.ballTrailLength or 28,6,80))
	while #ballTrail.points>maxPoints do table.remove(ballTrail.points) end
end

local function drawBallTrail()
	if not WorldDraw or not config.ballTrailEnabled then return end
	drawYukiTrail(math.floor(config.ballTrailStyle or 1))
end

-- PicklerCaster GOAL EXPLOSIONS -----------------------------------------------------
-- Twenty-three original goal explosions in the style of big arena-game celebrations, drawn with
-- the v2 engine further down (filled triangles, particles and real lights; no game assets).
-- Presentation-only. 24 = Shuffle: a different one of the twenty-three on every goal.
-- "Size" (goalFxSize) scales every effect, "How long it lasts" (goalFxDuration) times them.

GOAL_FX_TYPES = {
	"Dragon Duel",
	"Supernova",
	"Inferno Eruption",
	"Thunderstrike",
	"Event Horizon",
	"Grand Finale",
	"Glacier Shatter",
	"Team Pride",
	"Jack-o'-Blast (Halloween)",
	"Spirit Swarm (Halloween)",
	"Guacward",
	"Death Note (writes the scorer's name)",
	"Present Pop (Christmas)",
	"Christmas Tree (Christmas)",
	"Frozen Cataclysm",
	"Meteor Strike",
	"Orbital Strike",
	"Phoenix Rising",
	"Hyperdrive Portal",
	"Reality Break",
	"Splash",
	"Snowman Smash (Christmas)",
	"Ornament Shatter (Christmas)",
	"Private Property",
	"Divine Ascension",
	"Midnight Countdown (New Year's)",
	"Heartbreaker (Valentine's)",
	"GG EZ",
	"Jackpot",
	"Paparazzi",
	"Busted",
	"Bullseye",
	"Light Show",
	"Rocket Launch",
	"UFO Abduction",
	"Santa's Sleigh Run (Christmas)",
	"The Naughty List (Christmas)",
	"Candy Cane Cracker (Christmas)",
	"Snow Globe (Christmas)",
	"Xeno",
	"Shuffle (random each goal)",
	"Shuffle Favorites",
}
GOALFX_SHUFFLE = 41
GOALFX_SHUFFLE_FAV = 42
-- Tier ranking (best to worst) and category for every explosion, used by the explosion browser.
-- Ranked on how much is going on (real 3D geometry, layers, choreography, a clear payoff), not
-- on age. S = showpiece, A = excellent, B = good but simpler, C = basic / due an upgrade.
-- cat: "premium" (regular), "holiday", "meme" (shown in the Special section). hol = which holiday.
GOAL_FX_INFO = {
	[1]={tier="S",cat="premium",desc="3D red vs blue dragons climb, roar and lock beams in a huge clash"},
	[12]={tier="S",cat="premium",desc="Notebook rises, pages flip, a pen writes the scorer's name, it crumbles to ash"},
	[16]={tier="S",cat="premium",desc="Flaming meteor smashes the goal: rocks, molten chunks, mushroom cloud"},
	[17]={tier="S",cat="premium",desc="Target lock, then a giant beam from orbit and a detonation"},
	[21]={tier="S",cat="premium",desc="Water bomb: 3D dome, crown of water, jet and a second splash"},
	[18]={tier="S",cat="premium",desc="A 3D firebird with real feathered wings hatches, climbs, screeches and dives into the goal"},
	[20]={tier="A",cat="premium",desc="Space cracks and shatters like glass, revealing a starry void"},
	[7]={tier="A",cat="premium",desc="3D ice crystals pop up, crack and shatter into tumbling shards"},
	[19]={tier="A",cat="premium",desc="Neon portal with a tunnel and warp streaks, then the jump"},
	[9]={tier="A",cat="holiday",hol="Halloween",desc="Giant 3D jack-o'-lantern cracks open: chunks, seeds, bats, ghost-fire"},
	[14]={tier="A",cat="holiday",hol="Christmas",desc="A tree grows, lights up, bursts; the star rockets into a firework"},
	[2]={tier="S",cat="premium",desc="A star forms with plasma loops, collapses, erupts into a nebula and a pulsar"},
	[3]={tier="S",cat="premium",desc="Lava cracks, a volcano rises and erupts twice with ash lightning"},
	[25]={tier="S",cat="premium",desc="Rune circle, a pillar of light, wings of light, then a radiant burst"},
	[6]={tier="A",cat="premium",desc="Three-act fireworks show: fan salvo, saturn shell, gold willow finale"},
	[15]={tier="A",cat="premium",desc="Icy shockwave raises a wave of 3D ice spikes and a spire, then it all shatters"},
	[5]={tier="A",cat="premium",desc="Black hole with an accretion disk and jets swallows debris, then bursts as a white hole"},
	[4]={tier="A",cat="premium",desc="Storm vortex, four strikes leaving scorch marks, then a mega-bolt and chain lightning"},
	[10]={tier="B",cat="holiday",hol="Halloween",desc="Moon rises, ghosts spiral from ghost-fire and burst"},
	[13]={tier="B",cat="holiday",hol="Christmas",desc="A giant present rattles, the lid blasts off, confetti and ornaments"},
	[23]={tier="B",cat="holiday",hol="Christmas",desc="A glossy bauble lowers, cracks and shatters into glitter"},
	[22]={tier="B",cat="holiday",hol="Christmas",desc="A snowman builds itself, waves, then blows apart into snowballs"},
	[11]={tier="B",cat="team",desc="An awkward avocado walks in, stares, and its pit explodes into guac"},
	[24]={tier="B",cat="meme",desc="'State?'... 'STATE?!' A farmer in a pickup says it's private property"},
	[8]={tier="A",cat="premium",desc="Searchlights and drumbeats, then a giant team flag, flame jets, confetti and fireworks"},
	[26]={tier="A",cat="holiday",hol="New Year's",desc="3-2-1 countdown, the ball drops, HAPPY NEW YEAR! and a fireworks barrage"},
	[27]={tier="A",cat="holiday",hol="Valentine's",desc="A beating heart is struck by an arrow and shatters into hearts and petals"},
	[28]={tier="A",cat="meme",desc="The scorer types GG EZ, 3D letters slam down, shades on... then the BAN HAMMER"},
	[29]={tier="S",cat="premium",desc="A giant slot machine hits $ $ $, then bursts into gold bars, coins and raining money"},
	[30]={tier="A",cat="meme",desc="Red carpet, velvet ropes, flashbulbs on the goalie... then a polaroid: CAUGHT IN 4K"},
	[31]={tier="A",cat="meme",desc="Cop cars drift round the goalie, a helicopter spotlight, FREEZE!, cuffs and a BUSTED! stamp"},
	[32]={tier="A",cat="premium",desc="Giant target rises, three arrows fly in, the last splits the second: BULLSEYE!"},
	[33]={tier="S",cat="premium",desc="Laser towers, beat-synced fans and a strobing grid, a mirror ball, then a rainbow finale"},
	[34]={tier="A",cat="premium",desc="A 3D rocket rises from the goal, ignites, blasts off and bursts into fireworks"},
	[35]={tier="A",cat="meme",desc="A flying saucer beams up a cow and the ball, then warps away in a flash"},
	[36]={tier="S",cat="holiday",hol="Christmas",desc="SPECIAL: Santa's sleigh and reindeer drop a giant present, then HO HO HO! and fireworks"},
	[37]={tier="S",cat="holiday",hol="Christmas",desc="SPECIAL: A scroll writes the goalie's name, stamps it NAUGHTY! and coal rains down and explodes"},
	[38]={tier="B",cat="holiday",hol="Christmas",desc="A ring of candy canes whirls faster and faster, then snaps into pieces"},
	[39]={tier="B",cat="holiday",hol="Christmas",desc="A giant snow globe shakes, cracks and shatters into ice and snow"},
	[40]={tier="A",cat="team",desc="The Xeno logo spins up with a ring, grows and sparkles over the goal, then breaks apart"},
	[41]={tier="",cat="all",desc="A different explosion every goal"},
	[42]={tier="",cat="all",desc="A different one of your favorites every goal (star them first)"},
}
GOAL_FX_TIER_COL = {S={1,.75,.2},A={.45,.85,1},B={.55,1,.5},C={.7,.7,.75}}
GOAL_FX_TIER_ORDER = {S=1,A=2,B=3,C=4}

-- the goal explosion picker: one dropdown split into sections (Random, favorites, Big Hits, Special, Esports Teams, each holiday),
-- best tier first inside each section; hover a name for what it does.
-- < PREV / TEST IT / NEXT > underneath. Special = Death Note plus the meme-style ones.
GOAL_FX_SECTIONS={
	{"Random",function(i,inf) return i==GOALFX_SHUFFLE or i==GOALFX_SHUFFLE_FAV end,true},
	{"Your Favorites",function(i,inf) return GoalFxIsFav(i) end,true},
	{"Big Hits",function(i,inf) return inf.cat=="premium" and i~=12 end},
	{"Special",function(i,inf) return inf.cat=="meme" or i==12 end},
	{"Esports Teams",function(i,inf) return inf.cat=="team" end},
	{"Halloween",function(i,inf) return inf.hol=="Halloween" end},
	{"Christmas",function(i,inf) return inf.hol=="Christmas" end},
	{"New Year's",function(i,inf) return inf.hol=="New Year's" end},
	{"Valentine's",function(i,inf) return inf.hol=="Valentine's" end},
}

-- rarity names for the tiers, shown on the tabs
GOAL_FX_RARITY={S="LEGENDARY",A="EPIC",B="RARE",C="COMMON"}

-- Favorites are saved as one string "|Name|Name|" (the config loader strips unknown keys inside
-- saved tables, but keeps strings), keyed by name so adding new explosions never shuffles them.
function GoalFxIsFav(i)
	local nm=GOAL_FX_TYPES[i]
	return nm~=nil and string.find(config.goalFxFavs or "","|"..nm.."|",1,true)~=nil
end

function GoalFxToggleFav(i)
	local nm=GOAL_FX_TYPES[i]
	if not nm or i>=GOALFX_SHUFFLE then return end
	local s=config.goalFxFavs or ""
	if GoalFxIsFav(i) then
		local a,b=string.find(s,"|"..nm.."|",1,true)
		s=string.sub(s,1,a)..string.sub(s,b+1)
		if s=="|" then s="" end
	else
		if s=="" then s="|" end
		s=s..nm.."|"
	end
	config.goalFxFavs=s
	pcall(saveConfig)
end

-- the explosions in the dropdown's sections for one section entry, best tier first
function GoalFxSectionList(sec)
	local list={}
	for _,i in ipairs(GoalFxList("all")) do
		if sec[2](i,GOAL_FX_INFO[i] or {}) then list[#list+1]=i end
	end
	return list
end

-- the explosion picker: one dropdown, then one row of buttons, with what's selected described below
function PicklerGoalFxBrowser()
	local cur=math.floor(config.goalFxType or GOALFX_SHUFFLE)
	local star=PicklerIcon("Star")
	local inf=GOAL_FX_INFO[cur] or {}

	if Gui.beginCombo("Goal Explosion##vxGoalType",GOAL_FX_TYPES[cur] or GOAL_FX_TYPES[1]) then
		for si,sec in ipairs(GOAL_FX_SECTIONS) do
			local list=GoalFxSectionList(sec)
			if #list>0 then
				local okS=pcall(function() Gui.separatorText(sec[1]) end)
				if not okS then Gui.text("[ "..sec[1].." ]") end
				for _,i in ipairs(list) do
					local mark=GoalFxIsFav(i) and (star~="" and star or "* ") or ""
					if Gui.selectable(mark..GOAL_FX_TYPES[i].."##vxGoal"..si.."_"..i,cur==i) then config.goalFxType=i end
					local one=GOAL_FX_INFO[i] or {}
					if one.desc then PicklerUiTip(one.desc) end
				end
			end
		end
		Gui.endCombo()
	end
	if inf.desc then PicklerUiHint(inf.desc) end

	-- PREV / NEXT walk the dropdown's order, skipping the Random and Favorites sections
	local pool={}
	for _,sec in ipairs(GOAL_FX_SECTIONS) do
		if not sec[3] then
			for _,i in ipairs(GoalFxSectionList(sec)) do pool[#pool+1]=i end
		end
	end
	local function step(dir)
		if #pool==0 then return end
		local at=0
		for j,i in ipairs(pool) do if i==cur then at=j end end
		if at==0 and dir<0 then at=1 end
		config.goalFxType=pool[((at-1+dir)%#pool)+1]
	end
	if Gui.button("< PREV##vxGoalPrev") then step(-1) end
	Gui.sameLine()
	local ok,res=pcall(function() return Gui.buttonColored(PicklerAccent(.85),"TEST IT##vxGoalTest") end)
	if ok and res then PicklerPlayGoalFx(nil) end
	Gui.sameLine()
	if Gui.button("NEXT >##vxGoalNext") then step(1) end
	if goalFx.active and goalFx.preview then
		Gui.sameLine()
		if Gui.button("STOP##vxGoalStop") then PicklerStopPreview() end
	end
	if GFX_LAST_ERROR then PicklerUiColorText(LinearColor.new(1,.4,.35,1),"Explosion error: "..GFX_LAST_ERROR) end
	if not selectedArena then PicklerUiHint("No arena loaded: TEST plays in front of the camera") end
	if cur<GOALFX_SHUFFLE then
		Gui.sameLine()
		local fav=GoalFxIsFav(cur)
		local okF,resF=pcall(function()
			if fav then return Gui.buttonColored(LinearColor.new(.85,.65,.15,1),star.."FAVORITED##vxGoalFav") end
			return Gui.button(star.."FAVORITE##vxGoalFav")
		end)
		if okF and resF then GoalFxToggleFav(cur) end
	end
end

-- the explosions in a browser category, best tier first then A-Z
function GoalFxList(cat)
	local list={}
	for i=1,#GOAL_FX_TYPES do
		local inf=GOAL_FX_INFO[i] or {tier="C",cat="premium"}
		if cat=="all" or inf.cat==cat then list[#list+1]=i end
	end
	table.sort(list,function(a,b)
		local ta=GOAL_FX_TIER_ORDER[(GOAL_FX_INFO[a] or {}).tier or ""] or 9
		local tb=GOAL_FX_TIER_ORDER[(GOAL_FX_INFO[b] or {}).tier or ""] or 9
		if ta~=tb then return ta<tb end
		return GOAL_FX_TYPES[a]<GOAL_FX_TYPES[b]
	end)
	return list
end

goalFx = {
	active=false,
	startTime=0,
	goal=nil,
	initialized=false,
	lastStamp=0,
}

function goalFxNoise(seed)
	local x=math.sin(seed*12.9898+78.233)*43758.5453
	return x-math.floor(x)
end

function resetGoalFx()
	goalFx.active=false
	goalFx.typeOverride=nil
	goalFx.preview=false
	goalFx.previewSnap=nil
	goalFx.freeSnap=nil
	goalFx.startTime=0
	goalFx.goal=nil
	goalFx.initialized=false
	goalFx.lastStamp=0
	if GFX and GFX.stop then GFX.stop() end
end

function updateGoalFxTrigger()
	if not config.goalFxEnabled or not selectedArena then
		-- a TEST preview still plays with match celebrations switched off or no arena loaded
		if not goalFx.preview then goalFx.active=false end
		return
	end
	local stamp=selectedArena.goalScoredTime or 0
	if not goalFx.initialized then
		goalFx.initialized=true
		goalFx.lastStamp=stamp
		return
	end
	if stamp>goalFx.lastStamp and selectedArena.goalScoredGoal then
		goalFx.lastStamp=stamp
		goalFx.active=true
		goalFx.typeOverride=nil   -- a real goal always uses the selected explosion
		goalFx.preview=false
		goalFx.startTime=totalTime
		goalFx.goal=selectedArena.goalScoredGoal
		goalFx.scorerName=nil
		pcall(function() goalFx.scorerName=PicklerScorerName(selectedArena.goalScoredTeam) end)
	end
end

-- where a TEST plays when there is no arena or goal to use (an empty server): on the floor level
-- in front of the camera, fixed at the moment TEST was pressed
function goalFxCameraFrame()
	local up=Vec3.new(0,0,1)
	local fwd=camRot:getForwardVector()
	local flat=fwd-up*Vec3.dot(fwd,up)
	if flat:length()<.05 then flat=camRot:getRightVector() end
	flat=flat:getSafeNormal()
	local toward=flat*-1
	return {c=camPos+flat*750,u=up,r=Vec3.cross(up,toward):getSafeNormal(),t=toward}
end

function goalFxFrame()
	if not selectedArena or not goalFx.goal then
		if not goalFx.preview then return nil end
		if not goalFx.freeFrame then goalFx.freeFrame=goalFxCameraFrame() end
		local F=goalFx.freeFrame
		return F.c,F.u,F.r,F.t
	end
	local center=goalFx.goal.position
	local up=selectedArena.up:getSafeNormal()
	local toward=(selectedArena.center-center):getSafeNormal()
	local right=Vec3.cross(up,toward)
	if right:length()<.01 then right=selectedArena.right end
	right=right:getSafeNormal()
	center=center+toward*65+up*12
	return center,up,right,toward
end

function customGoalColor(r,g,b,mix)
	local m=math.clamp(mix or .20,0,1)
	return
		r*(1-m)+(config.goalFxColorR or .10)*m,
		g*(1-m)+(config.goalFxColorG or .82)*m,
		b*(1-m)+(config.goalFxColorB or .92)*m
end

GOALFX_RIGHT = -1   -- direction "right" means for the X offset, relative to the frame's `right`

function goalFxSmooth(t) t=math.clamp(t,0,1) return t*t*(3-2*t) end
function goalFxEaseOut(t) t=math.clamp(t,0,1) return 1-(1-t)^3 end

function goalFxAnchor(c,u,r)
	local dirR=r*GOALFX_RIGHT
	local ox=config.goalFxTextOffsetX or 0
	local oy=config.goalFxTextOffsetY or 110
	return c+dirR*ox+u*oy, dirR
end

-- shared setup for every explosion: duration, size, anchor point, right axis, fade-out
function goalFxBegin(age,c,u,r)
	local D=math.clamp(config.goalFxDuration or 2.4,.5,8)
	local size=math.clamp(config.goalFxSize or 1,.3,3)
	local anchor,dirR=goalFxAnchor(c,u,r)
	local out=goalFxSmooth((D-age)/.45)
	return D,size,anchor,dirR,out
end

function goalFxFloorBase(c,u,dirR,adj)
	local drop=60
	local gb=goalFx.goal and goalFx.goal.box
	if gb and gb.size and gb.size.z then drop=gb.size.z*.5 end
	return c+dirR*(config.goalFxTextOffsetX or 0)-u*(drop+12+(adj or 0))
end

-- drawing primitives ---------------------------------------------------------------------
function goalFxQMix(col,t)
	return col[1]+(1-col[1])*t, col[2]+(1-col[2])*t, col[3]+(1-col[3])*t
end

-- one glowing segment, three layers like camera bloom: a faint wide bloom, a coloured halo,
-- then a thin white-hot core. Thin lines (w<1.5) skip the bloom to keep the cost down.
function goalFxQLine(p,q,col,a,w,hot)
	if a<=.01 then return end
	a=math.min(a,1)
	local hr,hg,hb=goalFxQMix(col,hot or .35)
	if w>=1.5 then
		WorldDraw.drawLine(p,q,col[1]*a*.10,col[2]*a*.10,col[3]*a*.10,w*4.5,0)
	end
	WorldDraw.drawLine(p,q,col[1]*a*.32,col[2]*a*.32,col[3]*a*.32,w*2.2,0)
	WorldDraw.drawLine(p,q,col[1]*a*.9,col[2]*a*.9,col[3]*a*.9,w,0)
	local cr,cg,cb=goalFxQMix({hr,hg,hb},.5)
	WorldDraw.drawLine(p,q,cr*a,cg*a,cb*a,math.max(1,w*.4),0)
end

-- glowing dot: soft coloured halo behind a whiter centre
function goalFxQDot(p,col,a,size,hot)
	if a<=.01 then return end
	a=math.min(a,1)
	local hr,hg,hb=goalFxQMix(col,hot or 0)
	if size>=5 then
		WorldDraw.drawPoint(p,col[1]*a*.22,col[2]*a*.22,col[3]*a*.22,math.min(17,size*2.1),0)
	end
	WorldDraw.drawPoint(p,hr*a,hg*a,hb*a,math.max(2,size),0)
	if size>=6 then
		local cr,cg,cb=goalFxQMix({hr,hg,hb},.6)
		WorldDraw.drawPoint(p,cr*a,cg*a,cb*a,math.max(2,size*.45),0)
	end
end

function goalFxXLine(p,q,col,a,w)
	if a<=.01 then return end
	WorldDraw.drawLine(p,q,col[1]*a,col[2]*a,col[3]*a,w,0)
end

-- flat ring/ellipse lying in the plane spanned by axA and axB
function goalFxQRing(center,axA,axB,radA,radB,n,col,a,w)
	if a<=.01 or radA<=0 then return end
	local prev=nil
	for i=0,n do
		local th=(i/n)*math.pi*2
		local p=center+axA*(math.cos(th)*radA)+axB*(math.sin(th)*radB)
		if prev then goalFxQLine(prev,p,col,a,w,.3) end
		prev=p
	end
end

-- ring whose radius wobbles a little all the way round, so it never looks like a perfect circle
function goalFxQRingRough(center,axA,axB,rad,n,col,a,w,seed,rough)
	if a<=.01 or rad<=0 then return end
	local prev=nil
	for i=0,n do
		local th=(i/n)*math.pi*2
		local k=(i==n) and 0 or i
		local rr=rad*(1+(goalFxNoise(seed+k*1.7)-.5)*2*rough)
		local p=center+axA*(math.cos(th)*rr)+axB*(math.sin(th)*rr)
		if prev then goalFxQLine(prev,p,col,a,w,.3) end
		prev=p
	end
end

-- jagged electric arc from a to b; s1/s2 are the directions it is allowed to zig-zag in
function goalFxBolt(a,b,seed,jag,s1,s2,col,al,w)
	local n=7
	local prev=a
	for i=1,n do
		local t=i/n
		local p=a+(b-a)*t
		if i<n then
			local j=jag*math.sin(t*math.pi)
			p=p+s1*((goalFxNoise(seed+i*1.3)-.5)*2*j)+s2*((goalFxNoise(seed+i*2.9)-.5)*2*j)
		end
		goalFxQLine(prev,p,col,al,w,.55)
		prev=p
	end
end

-- direction k of n spread evenly over a (slightly flattened) sphere
function goalFxSphereDir(k,n,dirR,u,toward,depth)
	local y=1-(k-.5)/n*2
	local rad=math.sqrt(math.max(0,1-y*y))
	local th=k*2.39996
	return dirR*(math.cos(th)*rad)+u*y+toward*(math.sin(th)*rad*(depth or .6))
end

-- =====================================================================================
-- GOAL EXPLOSIONS v2 ENGINE
-- Built from scratch. Instead of thin lines and screen-space dots, everything here is made of
-- filled triangles with a real world-space size (so it looks solid at any distance), turned to
-- face the camera, with HDR-bright colours so the game's bloom makes them glow. A small physics
-- particle system moves the pieces (velocity, drag, gravity, attraction), and real point lights
-- light up the arena for a moment on the big hits.
--   goalFxQuality 1-4   particle budget (Low / Medium / High / Ultra)
--   goalFxGlow          overall brightness of the glow
--   goalFxLights        spawn real point lights on the big hits
-- Particle kinds: 1 = glow sprite, 2 = spark streak, 3 = smoke puff, 4 = tumbling shard/confetti,
-- 5 = flapping bat
-- =====================================================================================

GFX={parts={},lights={},run=nil,stamp=nil,rs=1,cap=750,K=1.6,
	bR=Vec3.new(0,1,0),bU=Vec3.new(0,0,1),cp=Vec3.zeroVector}
GFX_CAPS={240,450,750,1150}
GFX_QMUL={.35,.6,1,1.45}
GFX_QUALITY_NAMES={"Low","Medium","High","Ultra"}

-- deterministic random (Park-Miller), reseeded per celebration
function GFX.rand(a,b)
	GFX.rs=(GFX.rs*16807)%2147483647
	local v=GFX.rs/2147483647
	if a then return a+(b-a)*v end
	return v
end

-- random direction in the goal's frame; depth < 1 flattens it toward the camera plane
function GFX.rdir(x,depth)
	local z=GFX.rand()*2-1
	local th=GFX.rand()*6.2832
	local rad=math.sqrt(1-z*z)
	return x.r*(math.cos(th)*rad)+x.u*z+x.f*(math.sin(th)*rad*(depth or 1))
end

function GFX.mixW(c,t) return {c[1]+(1-c[1])*t,c[2]+(1-c[2])*t,c[3]+(1-c[3])*t} end
function GFX.mulC(c,k) return {c[1]*k,c[2]*k,c[3]*k} end

-- colour along a gradient of 1+ stops, t in 0..1
function GFX.ramp(R,t)
	local n=#R
	if n==1 then return R[1][1],R[1][2],R[1][3] end
	local f=math.clamp(t,0,1)*(n-1)
	local i=math.min(math.floor(f),n-2)
	local a,b=R[i+1],R[i+2]
	local w=f-i
	return a[1]+(b[1]-a[1])*w,a[2]+(b[2]-a[2])*w,a[3]+(b[3]-a[3])*w
end

-- drawing primitives -----------------------------------------------------------------------
-- flat hexagon facing the camera, rotated by rot
function GFX.hex(p,s,rot,lc)
	local R,U=GFX.bR,GFX.bU
	local c0,s0=math.cos(rot),math.sin(rot)
	local ax=R*(c0*s)+U*(s0*s)
	local ay=U*(c0*s)-R*(s0*s)
	local p1=p+ax
	local p2=p+ax*.5+ay*.866
	local p3=p-ax*.5+ay*.866
	local p4=p-ax
	local p5=p-ax*.5-ay*.866
	local p6=p+ax*.5-ay*.866
	WorldDraw.drawTriangle(p,p1,p2,lc,0)
	WorldDraw.drawTriangle(p,p2,p3,lc,0)
	WorldDraw.drawTriangle(p,p3,p4,lc,0)
	WorldDraw.drawTriangle(p,p4,p5,lc,0)
	WorldDraw.drawTriangle(p,p5,p6,lc,0)
	WorldDraw.drawTriangle(p,p6,p1,lc,0)
end

-- diamond facing the camera (2 triangles), used for small sparkles and hot cores
function GFX.diamond(p,s,rot,lc)
	local R,U=GFX.bR,GFX.bU
	local c0,s0=math.cos(rot),math.sin(rot)
	local ax=R*(c0*s)+U*(s0*s)
	local ay=U*(c0*s)-R*(s0*s)
	WorldDraw.drawTriangle(p+ax,p+ay,p-ax,lc,0)
	WorldDraw.drawTriangle(p-ax,p-ay,p+ax,lc,0)
end

-- filled 16-sided disc facing the camera
function GFX.disc(p,rad,lc)
	if rad<=0 then return end
	local R,U=GFX.bR,GFX.bU
	local prev=p+R*rad
	for i=1,16 do
		local th=i/16*6.2832
		local q=p+R*(math.cos(th)*rad)+U*(math.sin(th)*rad)
		WorldDraw.drawTriangle(p,prev,q,lc,0)
		prev=q
	end
end

-- soft glowing sprite: wide faint halo, mid glow, white-hot core
function GFX.glow(p,s,r,g,b,a,rot,hot)
	if a<=.01 or s<=.4 then return end
	local k=GFX.K
	rot=rot or 0
	if s<10 then
		GFX.diamond(p,s,rot,LinearColor.new(r*k*a,g*k*a,b*k*a,a))
		return
	end
	GFX.hex(p,s,rot,LinearColor.new(r*k*a*.30,g*k*a*.30,b*k*a*.30,a*.20))
	GFX.hex(p,s*.52,rot+.5,LinearColor.new(r*k*a*.85,g*k*a*.85,b*k*a*.85,a*.50))
	local h=hot or .5
	local hk=k*1.3*a
	GFX.diamond(p,s*.24,rot,LinearColor.new((r+(1-r)*h)*hk,(g+(1-g)*h)*hk,(b+(1-b)*h)*hk,a))
end

-- camera-facing quad from p to q with half width w
function GFX.beam(p,q,w,lc)
	local side=Vec3.cross(q-p,GFX.cp-p)
	if side:length()<.0001 then return end
	side=side:getSafeNormal()*w
	WorldDraw.drawTriangle(p+side,p-side,q-side,lc,0)
	WorldDraw.drawTriangle(p+side,q-side,q+side,lc,0)
end

-- comet-shaped spark: wide at the head, pointed at the tail, with a hot core line
function GFX.streak(p,tail,w,r,g,b,a)
	if a<=.01 then return end
	local side=Vec3.cross(p-tail,GFX.cp-p)
	if side:length()<.0001 then return end
	local k=GFX.K
	side=side:getSafeNormal()*w
	WorldDraw.drawTriangle(p+side,p-side,tail,LinearColor.new(r*k*a,g*k*a,b*k*a,a),0)
	local hk=k*a
	WorldDraw.drawLine(p,tail,(r+(1-r)*.6)*hk,(g+(1-g)*.6)*hk,(b+(1-b)*.6)*hk,1.5,0)
end

-- flat ring band (annulus) in the plane of ax/ay
function GFX.ring(cen,ax,ay,rad,w,n,r,g,b,a)
	if a<=.01 or rad<=0 then return end
	local k=GFX.K
	local lc=LinearColor.new(r*k*a,g*k*a,b*k*a,a*.75)
	local ri,ro=math.max(0,rad-w),rad+w
	local lastIn,lastOut=nil,nil
	for i=0,n do
		local th=i/n*6.2832
		local dir=ax*math.cos(th)+ay*math.sin(th)
		local pin,pout=cen+dir*ri,cen+dir*ro
		if lastIn then
			WorldDraw.drawTriangle(lastIn,lastOut,pout,lc,0)
			WorldDraw.drawTriangle(lastIn,pout,pin,lc,0)
		end
		lastIn,lastOut=pin,pout
	end
end

-- triangle fan around c through the points in list (close the loop by repeating the first)
function GFX.fan(c,list,lc)
	for i=1,#list-1 do WorldDraw.drawTriangle(c,list[i],list[i+1],lc,0) end
end

-- particles --------------------------------------------------------------------------------
function GFX.add(pt)
	local P=GFX.parts
	if #P>=GFX.cap then return nil end
	pt.age=0
	pt.seed=pt.seed or GFX.rand(0,100)
	pt.rot=pt.rot or GFX.rand(0,6.28)
	if pt.kind==4 and not pt.sa then
		local x=GFX.run
		local a=GFX.rdir(x):getSafeNormal()
		local b=Vec3.cross(a,x.u)
		if b:length()<.01 then b=Vec3.cross(a,x.r) end
		b=b:getSafeNormal()
		pt.sa,pt.sb,pt.sn=a,b,Vec3.cross(a,b)
	end
	P[#P+1]=pt
	return pt
end

-- shard (or confetti when pt.quad) tumbling around one of its own edges
function GFX.drawShard(pt,s,r,g,b,a)
	local w=pt.age*(pt.spin or 6)+pt.rot
	local e1=pt.sa
	local e2=pt.sb*math.cos(w)+pt.sn*math.sin(w)
	local shade=.35+.65*math.abs(math.cos(w))   -- catches the light as it turns
	local k=GFX.K*(pt.emis or .8)*shade*a
	local lc=LinearColor.new(r*k,g*k,b*k,a*(pt.op or .9))
	local p=pt.p
	if pt.quad then
		local A,B=e1*s,e2*(s*.45)
		WorldDraw.drawTriangle(p+A+B,p-A+B,p-A-B,lc,0)
		WorldDraw.drawTriangle(p+A+B,p-A-B,p+A-B,lc,0)
	else
		local A=p+e1*s
		local B=p-e1*(s*.5)+e2*(s*.8)
		local C=p-e1*(s*.4)-e2*(s*.45)
		WorldDraw.drawTriangle(A,B,C,lc,0)
		if shade>.85 then
			local gk=GFX.K*a*1.5
			WorldDraw.drawLine(A,B,gk,gk,gk,1.5,0)
		end
	end
end

function GFX.drawPart(pt,t)
	local a=math.min(1,t/(pt.fin or .05))*(1-t)^(pt.fp or 1)*(pt.a or 1)
	if pt.tw then a=a*(.45+.55*math.abs(math.sin(pt.age*pt.tw+pt.seed))) end
	if a<=.01 then return end
	local r,g,b=GFX.ramp(pt.ramp,t)
	local s=pt.s0+(pt.s1-pt.s0)*t
	local kind=pt.kind
	if kind==1 then
		GFX.glow(pt.p,s,r,g,b,a,pt.rot+pt.age*(pt.spin or 0),pt.hot)
	elseif kind==2 then
		local sp=pt.v:length()
		if sp<1 then
			GFX.diamond(pt.p,s,pt.rot,LinearColor.new(r*GFX.K*a,g*GFX.K*a,b*GFX.K*a,a))
		else
			local len=math.max(s*2,sp*(pt.st or .045))
			GFX.streak(pt.p,pt.p-pt.v*(len/sp),s,r,g,b,a)
		end
	elseif kind==3 then
		GFX.hex(pt.p,s,pt.rot+pt.age*(pt.spin or .4),LinearColor.new(r*a,g*a,b*a,a*(pt.op or .35)))
	elseif kind==5 then
		GFX.drawBat(pt,s,a)
	elseif kind==6 then
		GFX.comicDrop(pt.p,pt.v,s,a,pt.rot)
	elseif kind==7 then
		-- little heart, spinning gently in the camera plane
		local ang=pt.rot+pt.age*(pt.spin or 0)
		local ax=GFX.bR*math.cos(ang)+GFX.bU*math.sin(ang)
		local ay=GFX.bU*math.cos(ang)-GFX.bR*math.sin(ang)
		local k=GFX.K*a
		GFX.heart(pt.p,ax,ay,s,LinearColor.new(r*k,g*k,b*k,a),10)
	else
		GFX.drawShard(pt,s,r,g,b,a)
	end
end

function GFX.sim(x,d)
	local P=GFX.parts
	local u=x.u
	local i=1
	while i<=#P do
		local pt=P[i]
		pt.age=pt.age+d
		local t=pt.age/pt.life
		local dead=t>=1
		if not dead and pt.att and pt.killR then
			dead=(pt.p-pt.att):length()<pt.killR
		end
		if dead then
			P[i]=P[#P]
			P[#P]=nil
		else
			if pt.att then pt.v=pt.v+(pt.att-pt.p)*(pt.attK*d) end
			if pt.drag then pt.v=pt.v*math.exp(-pt.drag*d) end
			if pt.grav then pt.v=pt.v-u*(pt.grav*d) end
			pt.p=pt.p+pt.v*d
			GFX.drawPart(pt,t)
			i=i+1
		end
	end
end

-- timed flashes and shockwave rings ----------------------------------------------------------
function GFX.flashAt(x,pos,s,col,dur)
	x.fx[#x.fx+1]={k=1,t0=x.age,dur=dur or .35,pos=pos,s=s,col=col}
end

function GFX.shock(x,pos,ax,ay,r1,w,col,dur)
	x.fx[#x.fx+1]={k=2,t0=x.age,dur=dur or .7,pos=pos,ax=ax,ay=ay,r1=r1,w=w,col=col}
end

function GFX.drawTimed(x)
	local fm=config.goalFxFlash and 1 or .5
	for i=#x.fx,1,-1 do
		local e=x.fx[i]
		local t=(x.age-e.t0)/e.dur
		if t>=1 then
			table.remove(x.fx,i)
		elseif t>=0 then
			local c=e.col
			if e.k==1 then
				GFX.glow(e.pos,e.s*(.6+.8*goalFxEaseOut(t)),c[1],c[2],c[3],(1-t)^2*fm,t*.6,.8)
			else
				local q=goalFxEaseOut(t)
				GFX.ring(e.pos,e.ax,e.ay,e.r1*q,e.w*(1-t*.7),48,c[1],c[2],c[3],(1-t)^1.5)
			end
		end
	end
end

-- real point lights ----------------------------------------------------------------------------
-- ramps up over `attack`, holds for `hold`, then fades with time constant `decay`
function GFX.light(x,pos,col,peak,radius,attack,hold,decay,flick)
	if not config.goalFxLights or not WorldDraw.spawnPointLight or #GFX.lights>=6 then return nil end
	local ok,h=pcall(WorldDraw.spawnPointLight,pos,0,Vec3.new(col[1],col[2],col[3]),radius)
	if not ok or not h then return nil end
	local L={h=h,peak=peak,t0=x.age,att=math.max(attack or .03,.001),hold=hold or 0,dec=decay or .5,flick=flick}
	GFX.lights[#GFX.lights+1]=L
	return L
end

function GFX.lightsTick(x,age)
	local mul=config.goalFxFlash and 1 or .6
	for i=#GFX.lights,1,-1 do
		local L=GFX.lights[i]
		local t=age-L.t0
		local e
		if t<L.att then e=t/L.att
		elseif t<L.att+L.hold then e=1
		else e=math.exp(-(t-L.att-L.hold)/L.dec) end
		if L.flick then e=e*(.7+.3*math.sin(t*37)*math.sin(t*23+1)) end
		if t>L.att+L.hold and e<.02 then
			pcall(function() L.h:destroy() end)
			table.remove(GFX.lights,i)
		else
			pcall(function() L.h.intensity=L.peak*e*mul end)
		end
	end
end

-- timeline helpers -------------------------------------------------------------------------------
function GFX.rate(x,key,perSec)
	local acc=(x.acc[key] or 0)+perSec*x.q*x.d
	local n=math.floor(acc)
	x.acc[key]=acc-n
	return n
end

function GFX.once(x,key,at)
	if x.fired[key] or x.age<at then return false end
	x.fired[key]=true
	return true
end

function GFX.n(x,count) return math.max(1,math.floor(count*x.q+.5)) end

-- camera shake for big impacts: effects raise it, it dies away by itself, and it is only added
-- to the final camera position (never fed back into the camera smoothing)
GFX.shakeAmt=0
function GFX.addShake(a)
	if config.goalFxShake==false then return end
	GFX.shakeAmt=math.max(GFX.shakeAmt or 0,a)
end
function GFX.shakeVec()
	local s=GFX.shakeAmt or 0
	if s<.05 then return Vec3.zeroVector end
	return Vec3.new((math.random()-.5)*s,(math.random()-.5)*s,(math.random()-.5)*s)
end

-- shaded sphere (latitude/longitude), front faces only; spec adds a glossy highlight
function GFX.drawSphere(x,c,rad,col,kk,alpha,nLat,nLon,spec)
	local cp=GFX.cp
	local U,R,F=x.u,x.r,x.f
	local view=(cp-c):getSafeNormal()
	local half=(view+x.ld):getSafeNormal()
	local g={}
	for i=0,nLat do
		local phi=i/nLat*math.pi
		local row={}
		for j=0,nLon do
			local th=j/nLon*6.2832
			row[j]=(R*math.cos(th)+F*math.sin(th))*math.sin(phi)+U*math.cos(phi)
		end
		g[i]=row
	end
	for i=0,nLat-1 do
		for j=0,nLon-1 do
			local n=(g[i][j]+g[i+1][j]+g[i][j+1]+g[i+1][j+1]):getSafeNormal()
			local vd=Vec3.dot(n,view)
			if vd>-.05 then
				local sh=(.3+.7*math.max(0,Vec3.dot(n,x.ld)))*kk
				local sp=spec and (math.max(0,Vec3.dot(n,half))^24*spec*kk) or 0
				local rim=(1-math.max(0,vd))^2*.15*kk
				local lc=LinearColor.new(col[1]*sh+sp+rim,col[2]*sh+sp+rim,col[3]*sh+sp+rim,alpha or 1)
				local a,b=c+g[i][j]*rad,c+g[i][j+1]*rad
				local d2,e=c+g[i+1][j+1]*rad,c+g[i+1][j]*rad
				WorldDraw.drawTriangle(a,b,d2,lc,0)
				WorldDraw.drawTriangle(a,d2,e,lc,0)
			end
		end
	end
end

-- part of a ring band, from angle a0 to a1, in the plane of ax/ay
function GFX.arc(cen,ax,ay,rad,w,a0,a1,n,r,g,b,a)
	if a<=.01 or rad<=0 then return end
	local k=GFX.K
	local lc=LinearColor.new(r*k*a,g*k*a,b*k*a,a*.8)
	local ri,ro=math.max(0,rad-w),rad+w
	local li,lo=nil,nil
	for i=0,n do
		local th=a0+(a1-a0)*i/n
		local dir=ax*math.cos(th)+ay*math.sin(th)
		local pin,pout=cen+dir*ri,cen+dir*ro
		if li then
			WorldDraw.drawTriangle(li,lo,pout,lc,0)
			WorldDraw.drawTriangle(li,pout,pin,lc,0)
		end
		li,lo=pin,pout
	end
end

-- filled disc in the plane of ax/ay
function GFX.flatDisc(c,ax,ay,rad,lc)
	if rad<=0 then return end
	local prev=c+ax*rad
	for i=1,20 do
		local th=i/20*6.2832
		local q=c+(ax*math.cos(th)+ay*math.sin(th))*rad
		WorldDraw.drawTriangle(c,prev,q,lc,0)
		prev=q
	end
end

-- springy ease: overshoots past 1 then settles, so things "pop" into place (0 before t=0)
function GFX.backOut(t)
	if t<=0 then return 0 end
	if t>=1 then return 1 end
	local c1=1.9
	local s=t-1
	return 1+(c1+1)*s*s*s+c1*s*s
end

-- heart shape (the classic heart curve), size s, in the plane of ax (right) / ay (up)
function GFX.heartPts(c,ax,ay,s,n)
	local pts={}
	for i=0,n do
		local t=i/n*6.2832
		local hx=16*math.sin(t)^3
		local hy=13*math.cos(t)-5*math.cos(2*t)-2*math.cos(3*t)-math.cos(4*t)
		pts[#pts+1]=c+ax*(hx/17*s)+ay*(hy/17*s)
	end
	return pts
end

function GFX.heart(c,ax,ay,s,lc,n)
	GFX.fan(c,GFX.heartPts(c,ax,ay,s,n or 16),lc)
end

-- comic-book water: dark blue outline, light blue fill, white shine. Drawn in layers stepping
-- toward the camera so the outline sits behind the fill.
GFX_COMIC_INK={.02,.12,.4}
GFX_COMIC_FILL={.45,.82,1}
GFX_COMIC_SHINE={.95,1,1}

function GFX.comicBlob(p,ax,ay,a,shine)
	local k=GFX.K*.8
	local tc=(GFX.cp-p):getSafeNormal()
	local ink,fill,sh=GFX_COMIC_INK,GFX_COMIC_FILL,GFX_COMIC_SHINE
	local ol=(ax:length()+ay:length())*.07+1.2*(GFX.run and GFX.run.S or 1)
	GFX.ellipse(p,ax+ax:getSafeNormal()*ol,ay+ay:getSafeNormal()*ol,LinearColor.new(ink[1]*k,ink[2]*k,ink[3]*k,a))
	GFX.ellipse(p+tc*1,ax,ay,LinearColor.new(fill[1]*k,fill[2]*k,fill[3]*k,a))
	if shine~=false then
		GFX.ellipse(p+tc*2-ax*.3+ay*.35,ax*.32,ay*.22,LinearColor.new(sh[1]*k*1.2,sh[2]*k*1.2,sh[3]*k*1.2,a))
	end
end

-- a cartoon water drop: a blob stretched along its motion with a pointed tail behind it
function GFX.comicDrop(p,v,s,a,rot)
	if a<=.01 then return end
	local R,U=GFX.bR,GFX.bU
	local sp=v:length()
	local dir
	if sp>1 then
		-- motion projected onto the screen
		local dv=R*Vec3.dot(v,R)+U*Vec3.dot(v,U)
		dir=(dv:length()>.01) and dv:getSafeNormal() or R
	else
		dir=R*math.cos(rot or 0)+U*math.sin(rot or 0)
	end
	local perp=U*Vec3.dot(dir,R)-R*Vec3.dot(dir,U)
	local stretch=1+math.min(sp/1500,1)*.8
	local k=GFX.K*.8
	local ink,fill=GFX_COMIC_INK,GFX_COMIC_FILL
	local tc=(GFX.cp-p):getSafeNormal()
	local tail=p-dir*(s*stretch*2.2)
	WorldDraw.drawTriangle(p+perp*(s*1.15),p-perp*(s*1.15),tail-dir*(s*.25),LinearColor.new(ink[1]*k,ink[2]*k,ink[3]*k,a),0)
	WorldDraw.drawTriangle(p+perp*s+tc,p-perp*s+tc,tail+tc,LinearColor.new(fill[1]*k,fill[2]*k,fill[3]*k,a),0)
	GFX.comicBlob(p,dir*(s*stretch),perp*s,a)
end

-- flying bat: dark body, scalloped wings that flap, red eyes and a purple rim so it reads at night
function GFX.drawBat(pt,s,a)
	local R,U=GFX.bR,GFX.bU
	local flap=math.sin(pt.age*(pt.fl or 22)+pt.seed)
	local p=pt.p
	local body=LinearColor.new(.05*a,.02*a,.08*a,a)
	local rk=GFX.K*a*.7
	for sd=-1,1,2 do
		local sh=p+R*(sd*.15*s)
		local mid=p+R*(sd*.55*s)+U*(flap*.35*s+.18*s)
		local tip=p+R*(sd*s)+U*(flap*.65*s)
		local e1=p+R*(sd*.72*s)+U*(flap*.45*s-.22*s)
		local e2=p+R*(sd*.38*s)+U*(flap*.2*s-.18*s)
		WorldDraw.drawTriangle(sh,mid,tip,body,0)
		WorldDraw.drawTriangle(sh,tip,e1,body,0)
		WorldDraw.drawTriangle(sh,e1,e2,body,0)
		WorldDraw.drawLine(sh,mid,.45*rk,.15*rk,.75*rk,1.5,0)
		WorldDraw.drawLine(mid,tip,.45*rk,.15*rk,.75*rk,1.5,0)
		WorldDraw.drawTriangle(p+R*(sd*.05*s)+U*(.12*s),p+R*(sd*.16*s)+U*(.12*s),p+R*(sd*.13*s)+U*(.3*s),body,0)
		GFX.diamond(p+R*(sd*.06*s)+U*(.06*s),.035*s+1,0,LinearColor.new(GFX.K*a*1.5,.1*a,.05*a,a))
	end
	GFX.diamond(p,.17*s,0,body)
end

-- palettes ---------------------------------------------------------------------------------------
GFX_PAL_FIRE={flash={1,.85,.6},ring={1,.55,.15},ring2={1,.3,.05},light={1,.5,.18},
	spark={{1,1,.8},{1,.65,.15},{.9,.2,.02}},
	fire={{1,.95,.7},{1,.55,.08},{.7,.12,.02},{.15,.03,.02}},
	ember={{1,.9,.5},{1,.45,.05},{.5,.08,.01}},
	smoke={{.14,.09,.07},{.05,.045,.045}}}
GFX_PAL_NOVA={flash={.85,.9,1},ring={.55,.75,1},ring2={.8,.5,1},light={.6,.7,1},
	spark={{1,1,1},{1,.85,.45},{1,.45,.15}},
	fire={{1,1,1},{.55,.75,1},{.45,.2,.9},{.06,.03,.15}},
	ember={{1,1,1},{.6,.8,1},{.3,.2,.8}},
	smoke={{.12,.07,.2},{.04,.03,.07}},
	inflow={{.3,.5,1},{.8,.9,1},{1,1,1}},
	nebula={{.55,.35,1},{.2,.4,1},{.05,.05,.2}}}
GFX_PAL_STORM={flash={.8,.9,1},ring={.45,.75,1},ring2={.75,.9,1},light={.55,.75,1},
	spark={{1,1,1},{.6,.85,1},{.2,.4,1}},
	fire={{1,1,1},{.5,.8,1},{.15,.3,1},{.03,.05,.2}},
	ember={{1,1,1},{.55,.85,1},{.2,.35,.9}},
	smoke={{.08,.09,.14},{.04,.04,.06}}}
GFX_PAL_VOID={flash={1,.8,.95},ring={.85,.35,1},ring2={1,.55,.2},light={.75,.35,1},
	spark={{1,1,1},{1,.5,.9},{.5,.1,.9}},
	fire={{1,.95,.9},{1,.45,.75},{.45,.08,.7},{.05,0,.1}},
	ember={{1,.85,.6},{.9,.35,1},{.3,.05,.5}},
	smoke={{.1,.03,.14},{.03,.01,.05}},
	disk={{.45,.1,.9},{.95,.3,.75},{1,.6,.25},{1,1,.9}}}
GFX_PAL_ICE={flash={.85,.95,1},ring={.55,.85,1},ring2={.8,.95,1},light={.5,.8,1},
	spark={{1,1,1},{.7,.92,1},{.3,.6,1}},
	fire={{1,1,1},{.6,.88,1},{.25,.5,.95},{.05,.1,.2}},
	ember={{1,1,1},{.65,.9,1},{.3,.55,.9}},
	smoke={{.35,.45,.55},{.12,.16,.2}},
	shard={{.75,.95,1},{.45,.75,1}}}
-- Dragon Duel's clash explosion: red and blue only
GFX_PAL_DUEL={flash={1,.75,.85},ring={.1,.4,1},ring2={1,.1,.05},light={.9,.4,.6},
	spark={{1,.5,.5},{1,.12,.06},{.15,.35,1}},
	fire={{1,.55,.55},{1,.12,.08},{.1,.25,1},{.02,.03,.18}},
	ember={{1,.4,.35},{.9,.08,.04},{.15,.3,1}},
	smoke={{.12,.04,.08},{.04,.03,.06}}}
GFX_FW_COLS={{1,.25,.2},{.25,.6,1},{.35,1,.45},{1,.8,.25},{.85,.35,1},{1,.45,.8},{.4,1,1}}

function GFX.teamPal(c)
	return {flash=GFX.mixW(c,.6),ring=c,ring2=GFX.mixW(c,.4),light=c,
		spark={{1,1,1},GFX.mixW(c,.4),c},
		fire={{1,1,1},GFX.mixW(c,.3),c,GFX.mulC(c,.2)},
		ember={{1,1,1},c,GFX.mulC(c,.3)},
		smoke={GFX.mulC(c,.15),{.05,.05,.06}}}
end

-- colour of the scoring team (scorer=true) or the other team, normalised so it glows.
-- Falls back to the celebration colour mix when the arena has no real team colour.
function GFX.teamColor(scorer)
	local col={config.goalFxColorR or .1,config.goalFxColorG or .82,config.goalFxColorB or .92}
	if not scorer then col={1,.3,.1} end
	pcall(function()
		local a=selectedArena
		local homeScored=(goalFx.goal==a.away.goal)
		local team
		if scorer==homeScored then team=a.home else team=a.away end
		local c=team.color
		local r,g,b=c.R or c.r,c.G or c.g,c.B or c.b
		if r and g and b then
			local m=math.max(r,g,b)
			if m>.05 and not (r>.95 and g>.95 and b>.95) then col={r/m,g/m,b/m} end
		end
	end)
	return col
end

-- the shared big boom: flash, two shockwaves, sparks, fireball, embers, smoke and a light
function GFX.blast(x,pos,P,pow)
	local pw=pow or 1
	local S=x.S*pw
	GFX.flashAt(x,pos,260*S,P.flash,.35)
	GFX.shock(x,pos,GFX.bR,GFX.bU,520*S,22*S,P.ring,.8)
	GFX.shock(x,pos,x.r,x.f,420*S,16*S,P.ring2 or P.ring,1.0)
	GFX.light(x,pos,P.light,60000*pw,2600*S,.03,0,.7)
	for i=1,GFX.n(x,150*pw) do
		local dir=GFX.rdir(x,.8)
		GFX.add({kind=2,p=pos+dir*(10*S),v=dir*(GFX.rand(700,1700)*S),life=GFX.rand(.5,1.1)*x.ts,
			s0=GFX.rand(2.5,5)*S,s1=.5*S,ramp=P.spark,drag=2.4,grav=420*S,st=.05})
	end
	for i=1,GFX.n(x,40*pw) do
		local dir=GFX.rdir(x,.8)
		GFX.add({kind=1,p=pos+dir*(GFX.rand(0,40)*S),v=dir*(GFX.rand(120,480)*S),life=GFX.rand(.45,.9)*x.ts,
			s0=GFX.rand(35,60)*S,s1=GFX.rand(80,130)*S,ramp=P.fire,drag=3.2,grav=-90*S,fin=.02,fp=1.6,spin=GFX.rand(-1,1)})
	end
	for i=1,GFX.n(x,36) do
		local dir=GFX.rdir(x,.8)
		GFX.add({kind=1,p=pos,v=dir*(GFX.rand(250,700)*S)+x.u*(200*S),life=GFX.rand(1.2,2.2)*x.ts,
			s0=GFX.rand(5,8)*S,s1=2*S,ramp=P.ember,drag=1.2,grav=380*S,tw=GFX.rand(10,22)})
	end
	for i=1,GFX.n(x,12) do
		local dir=GFX.rdir(x,.6)
		GFX.add({kind=3,p=pos+dir*(GFX.rand(0,60)*S),v=dir*(GFX.rand(60,170)*S),life=GFX.rand(1.6,2.6)*x.ts,
			s0=50*S,s1=GFX.rand(150,190)*S,ramp=P.smoke,drag=1.2,grav=-50*S,op=.35,fin=.15,spin=GFX.rand(-.6,.6)})
	end
end

GFX_DEFS={}

-- 1: DRAGON DUEL ----------------------------------------------------------------------------
-- Two original elemental dragons, frost-blue and ember-red, erupt from a swirl of fire at the
-- goal and climb in a double helix. They are real 3D: shaded tube bodies with a scale pattern,
-- dark flank stripes, glowing seams and an energy pulse running down them, back spikes, horned
-- heads with glowing eyes and an opening jaw full of teeth, and bat wings with bones and glowing
-- membranes. They break off to either side, roar while energy gathers in their mouths, and fire
-- beams at each other. The beams lock in a crackling clash that detonates into a huge two-colour
-- explosion and blows the dragons apart into sparks.
-- Bodies follow their heads like a snake (a follow-the-leader trail), so they stay stretched
-- out and keep swaying even while hovering.
-- strictly BLUE (1) and RED (2): saturated colours only, no white/orange/purple in the mix
GFX_DRAGON_PALS={
	{body={.04,.22,1},dark={.01,.04,.32},belly={.25,.5,1},glow={.1,.45,1},horn={.55,.75,1},
		breath={{.6,.8,1},{.15,.45,1},{.03,.18,1},{.01,.03,.3}}},
	{body={1,.06,.03},dark={.32,.01,.01},belly={1,.3,.2},glow={1,.12,.04},horn={1,.6,.55},
		breath={{1,.65,.6},{1,.18,.08},{.85,.03,.02},{.3,.01,.01}}},
}

function GFX.dragonPal(col)
	return {body=col,dark=GFX.mulC(col,.3),belly=GFX.mixW(col,.6),glow=GFX.mixW(col,.3),horn=GFX.mixW(col,.75),
		breath={{1,1,1},GFX.mixW(col,.45),col,GFX.mulC(col,.2)}}
end

-- one shaded triangle of a solid; its normal is turned away from `inside`, and it is skipped
-- when it faces away from the camera. rimCol adds a glowing edge light.
function GFX.solidTri(x,a,b,c,inside,col,kk,rimCol)
	local n=Vec3.cross(b-a,c-a)
	if n:length()<1e-6 then return end
	n=n:getSafeNormal()
	local cen=(a+b+c)*(1/3)
	if Vec3.dot(n,cen-inside)<0 then n=n*-1 end
	local vd=Vec3.dot(n,(GFX.cp-cen):getSafeNormal())
	if vd<=0 then return end
	local sh=(.3+.7*math.max(0,Vec3.dot(n,x.ld)))*kk
	local rr,rg,rb=0,0,0
	if rimCol then
		local rim=(1-vd)^2*kk*1.2
		rr,rg,rb=rimCol[1]*rim,rimCol[2]*rim,rimCol[3]*rim
	end
	WorldDraw.drawTriangle(a,b,c,LinearColor.new(col[1]*sh+rr,col[2]*sh+rg,col[3]*sh+rb,1),0)
end

function GFX.solidQuad(x,a,b,c,d,inside,col,kk,rimCol)
	GFX.solidTri(x,a,b,c,inside,col,kk,rimCol)
	GFX.solidTri(x,a,c,d,inside,col,kk,rimCol)
end

-- tapered tube through pts with the given radii, shaded, front faces only
function GFX.tube(x,pts,radii,sides,col,kk,rimCol)
	local n=#pts
	if n<2 then return end
	local cp=GFX.cp
	local rings={}
	for i=1,n do
		local T
		if i==1 then T=pts[2]-pts[1] elseif i==n then T=pts[n]-pts[n-1] else T=pts[i+1]-pts[i-1] end
		T=T:getSafeNormal()
		local a=Vec3.cross(T,x.u)
		if a:length()<.05 then a=Vec3.cross(T,x.r) end
		a=a:getSafeNormal()
		rings[i]={a=a,b=Vec3.cross(T,a)}
	end
	for i=1,n-1 do
		local r0,r1=radii[i],radii[i+1]
		for j=0,sides-1 do
			local t0,t1=j/sides*6.2832,(j+1)/sides*6.2832
			local A0=rings[i].a*math.cos(t0)+rings[i].b*math.sin(t0)
			local A1=rings[i].a*math.cos(t1)+rings[i].b*math.sin(t1)
			local B0=rings[i+1].a*math.cos(t0)+rings[i+1].b*math.sin(t0)
			local B1=rings[i+1].a*math.cos(t1)+rings[i+1].b*math.sin(t1)
			local nrm=(A0+A1):getSafeNormal()
			local p0=pts[i]+A0*r0
			local vd=Vec3.dot(nrm,(cp-p0):getSafeNormal())
			if vd>0 then
				local sh=(.3+.7*math.max(0,Vec3.dot(nrm,x.ld)))*kk
				local rr,rg,rb=0,0,0
				if rimCol then
					local rim=(1-vd)^2*kk*1.2
					rr,rg,rb=rimCol[1]*rim,rimCol[2]*rim,rimCol[3]*rim
				end
				local lc=LinearColor.new(col[1]*sh+rr,col[2]*sh+rg,col[3]*sh+rb,1)
				local q1,q2=pts[i+1]+B1*r1,pts[i+1]+B0*r1
				WorldDraw.drawTriangle(p0,pts[i]+A1*r0,q1,lc,0)
				WorldDraw.drawTriangle(p0,q1,q2,lc,0)
			end
		end
	end
end

-- head position of dragon sg (+1 / -1) at time t
function GFX.dragonPath(x,sg,t)
	local S,D=x.S,x.D
	local T1,T2,TX=.42*D,.56*D,x.TX
	local A=x.dAxis
	local side=x.r*sg
	if t<T1 then
		-- double helix out of the goal (before t=0 it circles underground, which is where the
		-- bodies start coiled)
		local k=t/T1
		local e=goalFxEaseOut(math.max(k,0))
		local ang=((sg>0) and 0 or math.pi)+k*6.2832
		local rad=(110+170*e)*S
		return A+x.r*(math.cos(ang)*rad)+x.f*(math.sin(ang)*rad*.65)+x.u*((-140+520*e)*S)
	end
	local p1=A+side*(280*S)+x.u*(380*S)
	local hov=A+side*(330*S)+x.u*(360*S)+x.f*(40*S)
	local k=goalFxSmooth((t-T1)/(T2-T1))
	local p=p1+(hov-p1)*k+x.u*(math.sin(t*2.6+sg)*14*S*k)
	if t>TX then
		local kb=goalFxEaseOut((t-TX)/(.15*D))
		p=p+side*(kb*450*S)+x.u*(kb*220*S)
	end
	return p
end

-- N points along the dragon's body, spaced evenly along the trail its head has left behind
function GFX.dragonBody(x,sg,head,N,L)
	local tr=x.trail[sg]
	local pts={head}
	local cur=head
	local idx=#tr
	local spacing=L/(N-1)
	local left=spacing
	while #pts<N and idx>=1 do
		local q=tr[idx]
		local dd=(q-cur):length()
		if dd>=left then
			cur=cur+(q-cur)*(left/dd)
			pts[#pts+1]=cur
			left=spacing
		else
			left=left-dd
			cur=q
			idx=idx-1
		end
	end
	while #pts<N do
		local dir=(#pts>=2) and (pts[#pts]-pts[#pts-1]):getSafeNormal() or x.u*-1
		local last=pts[#pts]
		pts[#pts+1]=last+dir*spacing
	end
	return pts
end

-- bat wings: an arm (shoulder, elbow, wrist) and three finger bones holding a scalloped,
-- glowing membrane; flaps fast in flight and slowly while hovering
function GFX.dragonWings(x,pts,fr,radii,pal,alpha)
	local S,age=x.S,x.age
	local N=#pts
	local wi=math.max(2,math.floor(N*.22))
	local ti=math.min(N,wi+math.max(2,math.floor(N*.18)))
	local f=fr[wi]
	local r=radii[wi]
	local Lw=230*S
	local fly=x.dFly or 1
	local flap=math.sin(age*(4+4*fly)+.5)*(.45+.35*fly)
	local kk=GFX.K*.5*alpha
	local back=f.t*-1
	local gl,hc=pal.glow,pal.horn
	for sd=-1,1,2 do
		local out=f.b*sd
		local d=(out*math.cos(flap)+f.n*math.sin(flap)):getSafeNormal()
		local R=pts[wi]+f.n*(r*.6)+out*(r*.5)
		local E=R+d*(Lw*.42)+f.n*(Lw*.12)+back*(Lw*.04)
		local Wr=E+d*(Lw*.36)-back*(Lw*.08)
		local tips={Wr+d*(Lw*.26)+back*(Lw*.12),Wr+d*(Lw*.1)+back*(Lw*.42),Wr-d*(Lw*.12)+back*(Lw*.62)}
		local T0=pts[ti]+fr[ti].n*(radii[ti]*.5)+fr[ti].b*(sd*radii[ti]*.4)
		local function mid(a,b)
			local m=(a+b)*.5
			return m+(R-m)*.16
		end
		local ring={E,Wr,tips[1],mid(tips[1],tips[2]),tips[2],mid(tips[2],tips[3]),tips[3],mid(tips[3],T0),T0}
		local nrm=Vec3.cross(E-R,T0-R):getSafeNormal()
		local sh=(.35+.65*math.abs(Vec3.dot(nrm,x.ld)))*kk
		local mc=pal.dark
		local mem=LinearColor.new(mc[1]*sh*1.8+gl[1]*kk*.25,mc[2]*sh*1.8+gl[2]*kk*.25,mc[3]*sh*1.8+gl[3]*kk*.25,.88*alpha)
		for k=1,#ring-1 do WorldDraw.drawTriangle(R,ring[k],ring[k+1],mem,0) end
		GFX.tube(x,{R,E,Wr},{r*.28,r*.22,r*.16},4,pal.body,kk,gl)
		local bk=GFX.K*.9*alpha
		for _,tp in ipairs(tips) do
			WorldDraw.drawLine(Wr,tp,hc[1]*bk,hc[2]*bk,hc[3]*bk,2.5,0)
			GFX.glow(tp,6*S,gl[1],gl[2],gl[3],.8*alpha,0,.6)
		end
		local ek=GFX.K*1.1*alpha
		for k=3,#ring-1 do WorldDraw.drawLine(ring[k],ring[k+1],gl[1]*ek,gl[2]*ek,gl[3]*ek,1.5,0) end
	end
end

-- horned head with glowing eyes, teeth and a lower jaw hinged open by `jaw` (radians);
-- returns the mouth position and the direction the head faces
function GFX.dragonHead(x,sg,pts,fr,pal,alpha,jaw)
	local S=x.S
	local F=fr[1].t
	if (x.dFace or 0)>0 then F=(F*(1-x.dFace)+x.r*(-sg*x.dFace)):getSafeNormal() end
	local Up=x.u-F*Vec3.dot(x.u,F)
	if Up:length()<.1 then Up=fr[1].n end
	Up=Up:getSafeNormal()
	local Sd=Vec3.cross(F,Up)
	local hs=26*S*1.9
	local hp=pts[1]+F*(hs*.15)
	local function H(a,b,c) return hp+F*(a*hs)+Up*(b*hs)+Sd*(c*hs) end
	local kk=GFX.K*.5*alpha
	local body,belly,gl=pal.body,pal.belly,pal.glow
	local mouth={.35,.04,.04}
	local tooth={1,.97,.9}
	local inside=H(.6,.1,0)
	for c=-1,1,2 do
		local B1,B2,R1,C1=H(-.2,.55,.5*c),H(-.25,-.25,.5*c),H(.55,.6,.45*c),H(.6,-.2,.52*c)
		local S1,S2,N1,N2=H(1.45,.3,.25*c),H(1.45,-.1,.28*c),H(1.75,.12,.12*c),H(1.75,-.08,.12*c)
		GFX.solidQuad(x,B1,R1,C1,B2,inside,body,kk,gl)
		GFX.solidQuad(x,R1,S1,S2,C1,inside,body,kk,gl)
		GFX.solidQuad(x,S1,N1,N2,S2,inside,body,kk,gl)
		-- horns sweeping back
		GFX.tube(x,{H(-.05,.5,.32*c),H(-.6,.95,.5*c),H(-1.25,1.15,.58*c),H(-1.9,1.05,.52*c)},
			{.17*hs,.12*hs,.07*hs,.01*hs},4,pal.horn,kk,gl)
		-- glowing eye with a bright slit
		local ep=H(.66,.4,.49*c)
		GFX.glow(ep,.22*hs,gl[1],gl[2],gl[3],alpha,0,.8)
		local ek=GFX.K*1.6*alpha
		GFX.flatBeam(ep-F*(.09*hs),ep+F*(.09*hs),.025*hs,Sd*c,LinearColor.new(ek,ek,ek,alpha))
		for t=0,3 do
			local tp=H(.9+t*.2,-.12,(.42-.06*t)*c)
			GFX.solidTri(x,tp-F*(.05*hs),tp+F*(.05*hs),tp-Up*(.16*hs),inside,tooth,kk*1.1)
		end
	end
	-- top of the head, nose, and the roof of the mouth
	GFX.solidQuad(x,H(-.2,.55,.5),H(-.2,.55,-.5),H(.55,.6,-.45),H(.55,.6,.45),inside,body,kk,gl)
	GFX.solidQuad(x,H(.55,.6,.45),H(.55,.6,-.45),H(1.45,.3,-.25),H(1.45,.3,.25),inside,body,kk,gl)
	GFX.solidQuad(x,H(1.45,.3,.25),H(1.45,.3,-.25),H(1.75,.12,-.12),H(1.75,.12,.12),inside,body,kk,gl)
	GFX.solidQuad(x,H(1.75,.12,.12),H(1.75,.12,-.12),H(1.75,-.08,-.12),H(1.75,-.08,.12),inside,body,kk,gl)
	GFX.solidQuad(x,H(-.25,-.25,.5),H(.6,-.2,.52),H(.6,-.2,-.52),H(-.25,-.25,-.5),inside,mouth,kk)
	GFX.solidQuad(x,H(.6,-.2,.52),H(1.45,-.1,.28),H(1.45,-.1,-.28),H(.6,-.2,-.52),inside,mouth,kk)
	GFX.solidQuad(x,H(1.45,-.1,.28),H(1.75,-.08,.12),H(1.75,-.08,-.12),H(1.45,-.1,-.28),inside,mouth,kk)
	-- lower jaw, hinged at the back
	local ca,sa=math.cos(jaw),math.sin(jaw)
	local function J(a,b,c)
		local da,db=a,b+.25
		return H(da*ca+db*sa,-.25+db*ca-da*sa,c)
	end
	local jin=J(.7,-.4,0)
	for c=-1,1,2 do
		GFX.solidQuad(x,J(0,-.25,.45*c),J(1.5,-.25,.22*c),J(1.55,-.42,.12*c),J(.4,-.6,.35*c),jin,body,kk,gl)
		for t=0,2 do
			local tp=J(.9+t*.22,-.27,(.36-.06*t)*c)
			GFX.solidTri(x,tp-F*(.05*hs),tp+F*(.05*hs),tp+Up*(.14*hs),jin,tooth,kk*1.1)
		end
	end
	GFX.solidQuad(x,J(0,-.25,.45),J(1.5,-.25,.22),J(1.5,-.25,-.22),J(0,-.25,-.45),jin,mouth,kk)
	GFX.solidQuad(x,J(.4,-.6,.35),J(1.55,-.42,.12),J(1.55,-.42,-.12),J(.4,-.6,-.35),jin,belly,kk,gl)
	GFX.solidQuad(x,J(1.5,-.25,.22),J(1.55,-.42,.12),J(1.55,-.42,-.12),J(1.5,-.25,-.22),jin,belly,kk,gl)
	return H(1.8,-.12-jaw*.6,0),F
end

-- the whole dragon; returns the mouth position and facing
function GFX.drawDragon3D(x,sg,pal,alpha,jaw)
	local S,age=x.S,x.age
	local N=({14,18,24,30})[x.qi]
	local m=({5,6,7,8})[x.qi]
	local R0=26*S
	local pts=GFX.dragonBody(x,sg,x.dHead[sg],N,x.dLen)
	-- a frame along the body: t toward the head, n up (the back), b across
	local fr={}
	for i=1,N do
		local T
		if i==1 then T=pts[1]-pts[2] elseif i==N then T=pts[N-1]-pts[N] else T=pts[i-1]-pts[i+1] end
		T=T:getSafeNormal()
		local up=x.u-T*Vec3.dot(x.u,T)
		if up:length()<.15 then up=fr[i-1] and fr[i-1].n or x.f end
		up=up:getSafeNormal()
		fr[i]={t=T,n=up,b=Vec3.cross(T,up)}
	end
	-- the body keeps swaying like a snake, more toward the tail
	for i=2,N do
		local s=(i-1)/(N-1)
		pts[i]=pts[i]+fr[i].b*(math.sin(age*3.5-i*.7)*16*S*s)+fr[i].n*(math.cos(age*2.7-i*.5)*8*S*s)
	end
	x.dPts[sg]=pts
	local cp=GFX.cp
	local kk=GFX.K*.5*alpha
	local radii={}
	for i=1,N do
		local s=(i-1)/(N-1)
		local pr
		if s<.07 then pr=.55+.45*s/.07 elseif s<.32 then pr=1 else pr=1-(s-.32)/.68*.92 end
		radii[i]=R0*pr
	end
	local gl=pal.glow
	local pulseS=(age*.9)%1
	for i=1,N-1 do
		local r0,r1=radii[i],radii[i+1]
		local s=(i-.5)/(N-1)
		local pk=math.max(0,1-math.abs(s-pulseS)*8)   -- energy pulse running down the body
		local f0,f1=fr[i],fr[i+1]
		for j=0,m-1 do
			local a0,a1=j/m*6.2832,(j+1)/m*6.2832
			local A0=f0.n*math.cos(a0)+f0.b*math.sin(a0)
			local A1=f0.n*math.cos(a1)+f0.b*math.sin(a1)
			local B0=f1.n*math.cos(a0)+f1.b*math.sin(a0)
			local B1=f1.n*math.cos(a1)+f1.b*math.sin(a1)
			local p00=pts[i]+A0*r0
			local nrm=(A0+A1+B0+B1):getSafeNormal()
			local vd=Vec3.dot(nrm,(cp-p00):getSafeNormal())
			if vd>0 then
				local topness=(math.cos((a0+a1)*.5)+1)*.5    -- 1 along the back, 0 on the belly
				local base=(topness>.35) and pal.body or pal.belly
				if topness>.35 and topness<.6 then base=pal.dark end
				local chk=((i+j)%2==0) and 1 or .82            -- scale pattern
				local sh=(.28+.72*math.max(0,Vec3.dot(nrm,x.ld)))*chk*kk
				local rim=(1-vd)^2*kk*1.3+pk*kk*.8
				local lc=LinearColor.new(base[1]*sh+gl[1]*rim,base[2]*sh+gl[2]*rim,base[3]*sh+gl[3]*rim,alpha)
				local p11,p10=pts[i+1]+B1*r1,pts[i+1]+B0*r1
				WorldDraw.drawTriangle(p00,pts[i]+A1*r0,p11,lc,0)
				WorldDraw.drawTriangle(p00,p11,p10,lc,0)
			end
		end
		-- glowing seams along both flanks
		local gk=GFX.K*(1+pk*2)*alpha
		for sd=-1,1,2 do
			WorldDraw.drawLine(pts[i]+f0.b*(sd*r0*1.02),pts[i+1]+f1.b*(sd*r1*1.02),gl[1]*gk,gl[2]*gk,gl[3]*gk,2,0)
		end
		-- back spikes
		if i>=2 and i<=N-2 then
			local sl=r0*(1.1-.6*s)*((i%2==0) and 1 or .7)
			local bp=pts[i]+f0.n*(r0*.9)
			local tip=bp+f0.n*sl-f0.t*(sl*.7)
			GFX.solidTri(x,bp+f0.t*(r0*.35),bp-f0.t*(r0*.3)+f0.b*(r0*.22),tip,pts[i],pal.horn,kk*.9,gl)
			GFX.solidTri(x,bp+f0.t*(r0*.35),bp-f0.t*(r0*.3)-f0.b*(r0*.22),tip,pts[i],pal.horn,kk*.9,gl)
		end
	end
	GFX.glow(pts[N],R0*1.6,gl[1],gl[2],gl[3],.7*alpha,age*4,.5)
	GFX.dragonWings(x,pts,fr,radii,pal,alpha)
	return GFX.dragonHead(x,sg,pts,fr,pal,alpha,jaw)
end

GFX_DEFS[1]={
	duration=function() return math.max(math.clamp(config.goalFxDuration or 3.6,1,8),4.6) end,
	init=function(x)
		local S,D=x.S,x.D
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.dAxis=x.base+x.f*(80*S)
		x.dLen=520*S
		x.TB0,x.TX=.58*D,.72*D
		x.dHead,x.dPts,x.trail,x.mouth={},{},{},{}
		x.pals={GFX_DRAGON_PALS[1],GFX_DRAGON_PALS[2]}   -- always blue vs red
		-- start each body coiled underground, along the path the head took before t=0
		for _,sg in ipairs({1,-1}) do
			local tr={}
			local T1=.42*D
			for i=0,80 do tr[#tr+1]=GFX.dragonPath(x,sg,-T1*1.2+i/80*T1*1.2) end
			x.trail[sg]=tr
		end
		GFX.flashAt(x,x.base+x.u*(40*S),220*S,{.8,.4,.9},.4)
		GFX.shock(x,x.base+x.u*(4*S),x.r,x.f,380*S,16*S,x.pals[1].glow,.9)
		GFX.shock(x,x.base+x.u*(6*S),x.r,x.f,300*S,12*S,x.pals[2].glow,.7)
		GFX.light(x,x.base+x.u*(150*S),{1,.7,.6},30000,2400*S,.05,.2,.5)
		GFX.addShake(6*S)
	end,
	update=function(x,age,d)
		local D,S=x.D,x.S
		local T1,T2,TB0,TX=.42*D,.56*D,x.TB0,x.TX
		x.dFly=1-goalFxSmooth((age-T1)/(T2-T1))
		x.dFace=goalFxSmooth((age-T1)/(T2-T1))
		local alpha=1-goalFxSmooth((age-TX)/(.06*D))

		-- heads move along their paths; bodies follow the trail they leave
		for _,sg in ipairs({1,-1}) do
			local h=GFX.dragonPath(x,sg,age)
			x.dHead[sg]=h
			local tr=x.trail[sg]
			if (h-tr[#tr]):length()>3*S then tr[#tr+1]=h end
			if #tr>400 then table.remove(tr,1) end
		end

		-- swirling twin pillars of fire they burst out of
		if age<.3*D then
			local e=1-goalFxSmooth((age-.18*D)/(.12*D))
			for di=1,2 do
				local sg=(di==1) and 1 or -1
				for i=1,GFX.rate(x,"pillar"..di,120*e) do
					local th=age*6+((sg>0) and 0 or math.pi)+GFX.rand(-.6,.6)
					local radial=x.r*math.cos(th)+x.f*math.sin(th)
					local tang=x.f*math.cos(th)-x.r*math.sin(th)
					GFX.add({kind=1,p=x.dAxis+radial*(GFX.rand(40,130)*S)+x.u*(GFX.rand(0,40)*S),
						v=x.u*(GFX.rand(500,900)*S)+tang*(200*S),life=GFX.rand(.5,.8),s0=15*S,s1=GFX.rand(40,55)*S,
						ramp=x.pals[di].breath,drag=1,grav=-100*S,fin=.04,fp=1.4,spin=GFX.rand(-2,2)})
				end
			end
		end

		-- jaws: shut while flying, wide open for the roar and the beams
		local jaw=.08+.05*math.sin(age*5)
		if age>T2-.04*D then jaw=.1+.5*goalFxSmooth((age-(T2-.04*D))/(.04*D)) end
		if alpha>.01 then
			for di=1,2 do
				local sg=(di==1) and 1 or -1
				local pal=x.pals[di]
				local mouth=GFX.drawDragon3D(x,sg,pal,alpha,jaw)
				x.mouth[sg]=mouth
				local pts=x.dPts[sg]
				-- elemental sparks shedding off the body
				for i=1,GFX.rate(x,"shed"..di,55) do
					local p=pts[math.min(#pts,1+math.floor(GFX.rand()*#pts))]
					GFX.add({kind=1,p=p+GFX.rdir(x)*(20*S),v=GFX.rdir(x)*(GFX.rand(30,90)*S),life=GFX.rand(.4,.7),
						s0=GFX.rand(5,9)*S,s1=1.5*S,ramp=pal.breath,drag=1,grav=-30*S,tw=GFX.rand(12,22)})
				end
				-- energy gathering in the mouth before the beams
				if age>T2-.04*D and age<TB0 then
					local k=goalFxSmooth((age-(T2-.04*D))/(TB0-T2+.04*D))
					local gl=pal.glow
					GFX.glow(mouth,(10+35*k)*S,gl[1],gl[2],gl[3],1,age*5,.7)
					for i=1,GFX.rate(x,"gather"..di,90) do
						local dir=GFX.rdir(x):getSafeNormal()
						GFX.add({kind=2,p=mouth+dir*(GFX.rand(80,150)*S),v=dir*(-300*S),life=.4,s0=2*S,s1=1*S,
							ramp=pal.breath,att=mouth,attK=30,drag=2,killR=10*S,st=.05})
					end
				end
			end
		end

		-- the beams lock together in a crackling clash
		local mA,mB=x.mouth[1],x.mouth[-1]
		if mA and mB and age>=TB0 and age<TX then
			local k=(age-TB0)/(TX-TB0)
			local M=mA+(mB-mA)*(.5+.1*math.sin(age*2.3))
			x.clash=M
			for di=1,2 do
				local sg=(di==1) and 1 or -1
				local pal=x.pals[di]
				local mo=x.mouth[sg]
				local gl,br=pal.glow,pal.breath[2]
				local bk=GFX.K
				local w=(1+.12*math.sin(age*50+di))*S
				GFX.beam(mo,M,30*w,LinearColor.new(gl[1]*bk,gl[2]*bk,gl[3]*bk,.25))
				GFX.beam(mo,M,14*w,LinearColor.new(br[1]*bk*1.2,br[2]*bk*1.2,br[3]*bk*1.2,.65))
				local hot=pal.breath[1]   -- pale red / pale blue core, not white
				GFX.beam(mo,M,5*w,LinearColor.new(hot[1]*bk*1.6,hot[2]*bk*1.6,hot[3]*bk*1.6,1))
				-- a spiral of energy wound round the beam
				local dir=(M-mo):getSafeNormal()
				local a1=Vec3.cross(dir,x.u):getSafeNormal()
				local a2=Vec3.cross(dir,a1)
				local prev=nil
				local len=(M-mo):length()
				for j=0,24 do
					local t=j/24
					local th=t*18-age*20*sg
					local q=mo+dir*(len*t)+(a1*math.cos(th)+a2*math.sin(th))*(18*S)
					if prev then WorldDraw.drawLine(prev,q,gl[1]*bk*1.3,gl[2]*bk*1.3,gl[3]*bk*1.3,2,0) end
					prev=q
				end
				for i=1,GFX.rate(x,"flow"..di,80) do
					GFX.add({kind=1,p=mo+dir*(len*GFX.rand(0,.9)),v=dir*(900*S),life=.15,s0=GFX.rand(8,14)*S,s1=4*S,
						ramp=pal.breath,fin=.1})
				end
			end
			-- the clash point
			GFX.glow(M,(50+110*k)*S*(1+.1*math.sin(age*45)),1,.55,.75,.9,age*6,.6)
			GFX.glow(M+x.r*(10*S),(40+80*k)*S,x.pals[2].glow[1],x.pals[2].glow[2],x.pals[2].glow[3],.6,age,.3)
			GFX.glow(M-x.r*(10*S),(40+80*k)*S,x.pals[1].glow[1],x.pals[1].glow[2],x.pals[1].glow[3],.6,-age,.3)
			if not x.arcT or age-x.arcT>.05 then
				x.arcT=age
				x.arcs={}
				for j=1,GFX.n(x,5) do
					local dir=GFX.rdir(x,.7):getSafeNormal()
					GFX.makeBolt(x,M,M+dir*(GFX.rand(80,200)*S*(1+k)),26*S,3.5*S,x.arcs,0)
				end
			end
			GFX.drawBoltLines(x.arcs,.7+.3*GFX.rand())
			for i=1,GFX.rate(x,"clashSpark",260) do
				local dir=(GFX.rdir(x)+x.u*.4):getSafeNormal()
				GFX.add({kind=2,p=M,v=dir*(GFX.rand(500,1200)*S),life=GFX.rand(.3,.6),s0=3*S,s1=.5*S,
					ramp=x.pals[(GFX.rand()<.5) and 1 or 2].breath,drag=2,grav=400*S,st=.045})
			end
			GFX.addShake(3*S*k)
		end

		-- detonation
		if GFX.once(x,"boom",TX) then
			local M=x.clash or (x.dAxis+x.u*(360*S))
			GFX.blast(x,M,GFX_PAL_DUEL,2.0)
			GFX.shock(x,M,(x.r+x.u):getSafeNormal(),x.f,720*S,14*S,x.pals[1].glow,1.1)
			GFX.shock(x,M,(x.r-x.u):getSafeNormal(),x.f,680*S,14*S,x.pals[2].glow,1.2)
			GFX.light(x,M,{1,.85,.8},90000,3200*S,.02,.1,.7)
			GFX.addShake(26*S)
			for di=1,2 do
				local pal=x.pals[di]
				local pts=x.dPts[(di==1) and 1 or -1]
				if pts then
					-- the dragons break apart into glowing sparks
					for _,p in ipairs(pts) do
						for j=1,2 do
							GFX.add({kind=1,p=p,v=GFX.rdir(x)*(GFX.rand(100,400)*S),life=GFX.rand(.7,1.2),
								s0=GFX.rand(14,24)*S,s1=2*S,ramp=pal.breath,drag=1.6,grav=120*S})
						end
					end
				end
				for i=1,GFX.n(x,70) do
					local dir=GFX.rdir(x,.8)
					GFX.add({kind=2,p=M,v=dir*(GFX.rand(900,1800)*S),life=GFX.rand(.6,1.1),s0=3.5*S,s1=.5*S,
						ramp=pal.breath,drag=2.2,grav=380*S,st=.05})
				end
			end
		end
		if GFX.once(x,"boom2",TX+.06*D) then
			local M=x.clash or (x.dAxis+x.u*(360*S))
			GFX.shock(x,M,GFX.bR,GFX.bU,560*S,10*S,{1,.15,.1},.8)
			GFX.shock(x,M,GFX.bR,GFX.bU,480*S,8*S,{.1,.35,1},.9)
		end
		-- embers of both colours drifting down afterwards
		if age>TX and age<.95*D then
			for di=1,2 do
				for i=1,GFX.rate(x,"after"..di,25) do
					local M=x.clash or (x.dAxis+x.u*(360*S))
					GFX.add({kind=1,p=M+x.r*(GFX.rand(-300,300)*S)+x.u*(GFX.rand(0,200)*S),v=x.u*(-GFX.rand(30,90)*S),
						life=GFX.rand(1,1.6),s0=GFX.rand(4,7)*S,s1=1.5*S,ramp=x.pals[di].breath,drag=.4,tw=GFX.rand(8,16)})
				end
			end
		end
	end,
}

-- 2: SUPERNOVA ---------------------------------------------------------------------------------
-- A star is born over the goal: a blazing sphere grows with its surface churning and loops of
-- plasma arcing off it while matter spirals in. It suddenly collapses to a blue-white point...
-- then erupts: a blinding flash, a shell of light racing outward, three shockwaves, long ejecta
-- streaks and a drifting multi-coloured nebula, leaving a spinning pulsar at the centre.
GFX_DEFS[2]={
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.sc=x.o+x.u*(60*S)
		x.TC,x.TB=.32*x.D,.4*x.D
		x.loops={}
		for i=1,({3,4,6,7})[x.qi] do
			x.loops[i]={a=GFX.rdir(x):getSafeNormal(),b=GFX.rdir(x):getSafeNormal(),ph=GFX.rand(0,6),sp=GFX.rand(.8,1.6)}
		end
		GFX.light(x,x.sc,{1,.8,.5},30000,2400*S,x.TC,0,.08)
	end,
	update=function(x,age,d)
		local D,S,c,TC,TB=x.D,x.S,x.sc,x.TC,x.TB
		local P=GFX_PAL_NOVA
		local k=GFX.K
		if age<TB then
			local grow=goalFxEaseOut(math.min(age/TC,1))
			local col=goalFxSmooth((age-TC)/(TB-TC))          -- 0..1 while it collapses
			local rad=(15+75*grow)*S*(1-col*.92)
			local cr,cg,cb=1-.3*col,.75+.1*col,.35+.65*col    -- yellow star -> blue-white point
			GFX.drawSphere(x,c,rad,{cr,cg,cb},k*1.1,1,6,12,.4)
			GFX.glow(c,rad*2.4,cr,cg*.8,cb*.6,.6+.4*col,age,.5)
			-- churning granules on the side facing the camera
			local view=(GFX.cp-c):getSafeNormal()
			for i=1,10 do
				local sd=i*7.3+math.floor(age*12)
				local z=goalFxNoise(sd)*2-1
				local th=goalFxNoise(sd+1)*6.2832
				local rr=math.sqrt(1-z*z)
				local dir=x.r*(math.cos(th)*rr)+x.f*(math.sin(th)*rr)+x.u*z
				if Vec3.dot(dir,view)>.1 then GFX.glow(c+dir*(rad*1.01),rad*.25,1,.55,.15,.8*(1-col),0,.4) end
			end
			-- plasma loops arcing off the surface
			if col<.9 then
				local lk=k*(1-col)
				for _,lp in ipairs(x.loops) do
					local A=lp.a
					local B=(lp.a+lp.b*.6):getSafeNormal()
					local h=rad*(.5+.5*math.abs(math.sin(age*2*lp.sp+lp.ph)))
					local p0,p2=c+A*rad,c+B*rad
					local p1=c+((A+B)*.5):getSafeNormal()*(rad+h*1.6)
					local prev=p0
					for j=1,10 do
						local t=j/10
						local q=p0*((1-t)*(1-t))+p1*(2*(1-t)*t)+p2*(t*t)
						GFX.beam(prev,q,5*S,LinearColor.new(1*lk,.45*lk,.12*lk,.7))
						GFX.beam(prev,q,2*S,LinearColor.new(1.3*lk,1*lk,.6*lk,1))
						prev=q
					end
				end
			end
			-- matter spiralling in
			for i=1,GFX.rate(x,"in",300) do
				local dir=GFX.rdir(x,.7):getSafeNormal()
				local tang=Vec3.cross(dir,x.u):getSafeNormal()
				GFX.add({kind=2,p=c+dir*(GFX.rand(280,450)*S),v=dir*(-GFX.rand(150,300)*S)+tang*(200*S),life=.7,
					s0=2.5*S,s1=1.5*S,ramp=P.inflow,att=c,attK=20,drag=1.4,killR=rad+5*S,st=.06,fin=.15,fp=.3})
			end
			if col>0 then GFX.addShake(col*5*S) end
		end
		if GFX.once(x,"boom",TB) then
			GFX.flashAt(x,c,520*S,{.9,.95,1},.4)
			GFX.blast(x,c,P,2.2)
			GFX.shock(x,c,(x.r+x.u):getSafeNormal(),x.f,680*S,14*S,P.ring2,1.2)
			GFX.shock(x,c,(x.r-x.u):getSafeNormal(),x.f,640*S,12*S,P.ring,1.3)
			GFX.shock(x,c,x.r,x.f,760*S,18*S,{1,.8,.5},1.1)
			GFX.light(x,c,{.8,.85,1},90000,3400*S,.02,.1,.8)
			GFX.addShake(24*S)
			local neb={{.75,.35,1},{.25,.5,1},{1,.4,.75},{1,.6,.3}}
			for i=1,GFX.n(x,30) do
				local dir=GFX.rdir(x,.6)
				local nc=neb[1+(i%#neb)]
				GFX.add({kind=1,p=c+dir*(GFX.rand(0,80)*S),v=dir*(GFX.rand(70,220)*S),life=GFX.rand(1.8,2.6)*x.ts,
					s0=GFX.rand(60,90)*S,s1=GFX.rand(170,260)*S,ramp={nc,GFX.mulC(nc,.3),{.02,.02,.06}},drag=1.3,a=.45,
					fin=.12,fp=1.3,spin=GFX.rand(-.4,.4),hot=.1})
			end
			for i=1,GFX.n(x,90) do
				local dir=GFX.rdir(x,.8):getSafeNormal()
				GFX.add({kind=2,p=c,v=dir*(GFX.rand(1400,2400)*S),life=GFX.rand(.5,.9),s0=4*S,s1=.5*S,ramp=P.spark,
					drag=2.2,st=.09})
			end
		end
		if GFX.once(x,"boom2",TB+.08*D) then GFX.shock(x,c,GFX.bR,GFX.bU,520*S,10*S,{.85,.9,1},.8) end
		if age>TB then
			-- shell of light racing outward
			local t=(age-TB)/(.35*D)
			if t<1 then GFX.drawSphere(x,c,(60+560*goalFxEaseOut(t))*S,{.6,.75,1},k*.6*(1-t),.3*(1-t),6,14,.2) end
			-- the pulsar left behind: a spinning pair of beams
			local pa=(1-goalFxSmooth((age-.85*D)/(.15*D)))*goalFxSmooth((age-TB)/(.1*D))
			if pa>.01 then
				local w=age*5
				local ax=(x.u*math.cos(w)+x.r*math.sin(w)*.8+x.f*.3):getSafeNormal()
				local bk=k*pa
				for sd=-1,1,2 do
					GFX.beam(c,c+ax*(sd*600*S),12*S,LinearColor.new(.4*bk,.6*bk,bk,.35*pa))
					GFX.beam(c,c+ax*(sd*600*S),3*S,LinearColor.new(1.2*bk,1.2*bk,1.3*bk,pa))
				end
				GFX.glow(c,(18+6*math.sin(age*30))*S,.7,.85,1,pa,age,.8)
			end
		end
	end,
}

-- 3: INFERNO ERUPTION --------------------------------------------------------------------------
-- The goal floor cracks open with glowing lava veins and smoking vents while the ground rumbles.
-- A volcano pushes up out of the floor, its crater glowing, then it erupts: a fountain of fire,
-- lava bombs, a rolling ash ring and lightning crackling inside the ash column. A second, bigger
-- blast follows, lava runs down its sides, and finally it cools, darkens and sinks away.

-- truncated rock cone with a glowing crater; glow 0..1 heats the rock near the top
function GFX.drawVolcano(x,base,h,rad,glow,a)
	if h<=1 or a<=.01 then return end
	local U=x.u
	local n=({10,12,16,18})[x.qi]
	local cp=GFX.cp
	local kk=GFX.K*.5
	local gk=GFX.K*.35*glow
	local top,bot={},{}
	for j=0,n do
		local th=j/n*6.2832
		local dir=x.r*math.cos(th)+x.f*math.sin(th)
		local jr=1+(goalFxNoise((j%n)*3.7)-.5)*.25
		bot[j]=base+dir*(rad*jr)
		top[j]=base+dir*(rad*.28*jr)+U*h
	end
	for j=0,n-1 do
		local mid=(bot[j]+bot[j+1]+top[j]+top[j+1])*.25
		local radial=mid-base
		radial=(radial-U*Vec3.dot(radial,U)):getSafeNormal()
		local nrm=(radial*h+U*(rad*.7)):getSafeNormal()
		if Vec3.dot(nrm,(cp-mid):getSafeNormal())>-.2 then
			local sh=(.3+.7*math.max(0,Vec3.dot(nrm,x.ld)))*kk
			local lc=LinearColor.new(.2*sh+.6*gk,.13*sh+.14*gk,.1*sh,a)
			WorldDraw.drawTriangle(bot[j],bot[j+1],top[j+1],lc,0)
			WorldDraw.drawTriangle(bot[j],top[j+1],top[j],lc,0)
		end
	end
	GFX.flatDisc(base+U*(h+1*x.S),x.r,x.f,rad*.27,LinearColor.new(GFX.K*1.2*glow+.05,.45*GFX.K*glow,.05,a))
	return top
end

GFX_DEFS[3]={
	init=function(x)
		local S,D=x.S,x.D
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.vc=x.base+x.f*(70*S)
		x.TE,x.TE2=.32*D,.55*D
		-- jagged lava cracks spreading out across the floor
		x.cracks={}
		for i=1,({5,6,8,9})[x.qi] do
			local th=i/({5,6,8,9})[x.qi]*6.2832+GFX.rand(-.3,.3)
			local pts={x.vc}
			local p=x.vc
			for j=1,6 do
				th=th+GFX.rand(-.45,.45)
				p=p+(x.r*math.cos(th)+x.f*math.sin(th))*(GFX.rand(45,75)*S)
				pts[#pts+1]=p
			end
			x.cracks[i]=pts
		end
		x.rivers={}
		for i=1,5 do x.rivers[i]=GFX.rand(0,6.2832) end
		GFX.light(x,x.vc+x.u*(160*S),{1,.45,.12},45000,2600*S,.25*D,.45*D,.5,true)
	end,
	update=function(x,age,d)
		local D,S,vc,TE,TE2=x.D,x.S,x.vc,x.TE,x.TE2
		local P=GFX_PAL_FIRE
		local U=x.u
		local k=GFX.K
		local fl=vc+U*(2*S)
		local cool=goalFxSmooth((age-.75*D)/(.2*D))
		-- lava cracks and a glowing floor
		local cg=math.min(age/(.28*D),1)
		local ca=1-cool
		for _,pts in ipairs(x.cracks) do
			local nseg=math.floor(cg*(#pts-1)+.999)
			for j=1,nseg do
				local p,q=pts[j]+U*(2*S),pts[j+1]+U*(2*S)
				local fl2=.75+.25*math.sin(age*20+j)
				GFX.beam(p,q,6*S,LinearColor.new(k*ca*fl2,.35*k*ca*fl2,.05*k*ca,.9*ca))
				GFX.beam(p,q,2*S,LinearColor.new(1.4*k*ca,1.1*k*ca,.5*k*ca,ca))
			end
			if cg>.2 and age<TE2 then
				for i=1,GFX.rate(x,"vent",4) do
					GFX.add({kind=3,p=pts[math.max(2,nseg)]+U*(5*S),v=U*(GFX.rand(80,160)*S),life=GFX.rand(1,1.5),
						s0=20*S,s1=70*S,ramp={{.25,.2,.18},{.08,.07,.07}},op=.4,fin=.1,drag=.5,spin=GFX.rand(-1,1)})
				end
			end
		end
		GFX.flatDisc(fl,x.r,x.f,(80+220*cg)*S,LinearColor.new(.6*k*ca*cg,.15*k*ca*cg,.02,.4*ca))
		if age<TE then GFX.addShake(age/TE*5*S) end

		-- the volcano: pushes up, erupts, cools and sinks
		local grow=goalFxEaseOut(goalFxSmooth((age-.12*D)/(TE-.12*D)))
		local sink=goalFxSmooth((age-.85*D)/(.15*D))
		local vh=230*S*grow*(1-sink)
		local heat=math.max(goalFxSmooth((age-.2*D)/(.12*D))*(1-cool),.15)
		GFX.drawVolcano(x,vc,vh,250*S,heat,1)
		local crater=vc+U*vh
		if age>TE and age<.85*D then
			-- lava running down the sides
			local lr=goalFxEaseOut((age-TE)/(.25*D))*(1-cool)
			for i,th0 in ipairs(x.rivers) do
				local prev=nil
				for j=0,8 do
					local t=j/8*lr
					local th=th0+math.sin(t*6+i)*.15
					local dir=x.r*math.cos(th)+x.f*math.sin(th)
					local q=vc+dir*((.28+.72*t)*250*S)+U*(vh*(1-t)+3*S)
					if prev then GFX.beam(prev,q,5*S,LinearColor.new(k*1.1,.4*k,.05*k,1)) end
					prev=q
				end
			end
		end
		-- eruptions
		for n,T in ipairs({TE,TE2}) do
			if GFX.once(x,"erupt"..n,T) then
				local pw=(n==1) and 1.7 or 2.3
				GFX.blast(x,crater+U*(30*S),P,pw)
				GFX.shock(x,fl,x.r,x.f,(560+n*120)*S,24*S,{1,.45,.1},1.2)
				GFX.addShake((14+n*8)*S)
				for i=1,GFX.n(x,30*n) do
					-- lava bombs
					local dir=(GFX.rdir(x)+U*1.6):getSafeNormal()
					GFX.add({kind=1,p=crater,v=dir*(GFX.rand(600,1300)*S),life=GFX.rand(1.2,1.8),s0=GFX.rand(14,22)*S,
						s1=6*S,ramp={{1,.9,.5},{1,.45,.05},{.4,.08,.02}},grav=1000*S,drag=.2,hot=.6,fin=.01,fp=.5})
				end
				for i=1,GFX.n(x,16) do
					-- rolling ash ring
					local th=GFX.rand(0,6.2832)
					local dirH=x.r*math.cos(th)+x.f*math.sin(th)
					GFX.add({kind=3,p=vc+dirH*(200*S)+U*(20*S),v=dirH*(GFX.rand(250,450)*S)+U*(40*S),life=GFX.rand(1.6,2.2),
						s0=70*S,s1=230*S,ramp={{.22,.18,.16},{.07,.06,.06}},op=.5,fin=.06,drag=1.3,spin=GFX.rand(-.6,.6)})
				end
			end
		end
		if age>TE and age<.8*D then
			local fk=1-goalFxSmooth((age-.65*D)/(.15*D))
			for i=1,GFX.rate(x,"fountain",240*fk) do
				GFX.add({kind=1,p=crater+x.r*(GFX.rand(-30,30)*S)+x.f*(GFX.rand(-30,30)*S),
					v=U*(GFX.rand(700,1200)*S)+GFX.rdir(x)*(120*S),life=GFX.rand(.7,1),s0=25*S,s1=GFX.rand(60,90)*S,
					ramp=P.fire,grav=500*S,drag=.6,fin=.03,fp=1.4,spin=GFX.rand(-2,2)})
			end
			for i=1,GFX.rate(x,"ash",18*fk) do
				GFX.add({kind=3,p=crater+U*(GFX.rand(250,450)*S)+x.r*(GFX.rand(-80,80)*S),v=U*(GFX.rand(100,200)*S),
					life=GFX.rand(1.6,2.2),s0=80*S,s1=220*S,ramp={{.2,.17,.15},{.06,.05,.05}},op=.45,fin=.1,drag=.4,
					spin=GFX.rand(-.5,.5)})
			end
			-- volcanic lightning flickering inside the ash column
			if not x.boltT or age-x.boltT>.18 then
				x.boltT=age
				x.bolts={}
				if GFX.rand()<.7 then
					local a=crater+U*(GFX.rand(300,450)*S)+x.r*(GFX.rand(-150,150)*S)
					GFX.makeBolt(x,a,a+GFX.rdir(x,.5)*(GFX.rand(150,260)*S),40*S,4*S,x.bolts,1)
				end
			end
			if x.bolts then GFX.drawBoltLines(x.bolts,(1-(age-x.boltT)/.18)*fk) end
		end
	end,
}

-- 4: THUNDERSTRIKE -----------------------------------------------------------------------------
-- A storm vortex spins up over the goal with lightning flickering inside it while static crackles
-- across the floor and dust swirls in the wind. Four strikes hammer the floor around the goal,
-- each leaving a glowing scorch mark, coming faster and faster. Then a giant mega-bolt slams into
-- the goal: a blinding flash, a dome of lightning bursting out in every direction, and chain
-- lightning racing out across the floor to the scorch marks before the storm clears.
-- (GFX.makeBolt / GFX.drawBoltLines here are also used by Dragon Duel and Inferno Eruption.)

-- jagged bolt from a to b with branches; adds {pts,w} lines to out
function GFX.makeBolt(x,a,b,jag,w,out,depth)
	local dir=b-a
	local len=dir:length()
	if len<1 then return out end
	local fwd=dir*(1/len)
	local s1=Vec3.cross(fwd,x.f)
	if s1:length()<.05 then s1=x.r else s1=s1:getSafeNormal() end
	local s2=Vec3.cross(fwd,s1)
	local n=(depth>=2) and 12 or 6
	local pts={a}
	for i=1,n-1 do
		local t=i/n
		local j=jag*(.4+.6*math.sin(t*math.pi))
		pts[#pts+1]=a+dir*t+s1*(GFX.rand(-1,1)*j)+s2*(GFX.rand(-.5,.5)*j)
	end
	pts[#pts+1]=b
	out[#out+1]={pts=pts,w=w}
	if depth>0 then
		for i=2,n-1 do
			if GFX.rand()<.3 then
				local bd=(fwd+s1*GFX.rand(-1.3,1.3)+s2*GFX.rand(-.6,.6)):getSafeNormal()
				GFX.makeBolt(x,pts[i],pts[i]+bd*(len*GFX.rand(.15,.32)),jag*.45,w*.55,out,depth-1)
			end
		end
	end
	return out
end

function GFX.drawBoltLines(lines,a)
	if a<=.01 then return end
	local k=GFX.K
	local glow=LinearColor.new(.35*k*a,.55*k*a,k*a,a*.3)
	local hk=k*a*1.4
	local core=LinearColor.new(.85*hk,.92*hk,hk,a)
	for _,ln in ipairs(lines) do
		local pts,w=ln.pts,ln.w
		for i=1,#pts-1 do
			GFX.beam(pts[i],pts[i+1],w*3,glow)
			GFX.beam(pts[i],pts[i+1],w*.6,core)
		end
	end
end

GFX_DEFS[4]={
	init=function(x)
		local S,D=x.S,x.D
		x.tc=x.base+x.f*(70*S)
		x.cloud=x.o+x.u*(380*S)
		x.bolts={}
		x.scorch={}
		x.TM=.6*D
		-- four strikes, each one coming sooner than the last
		x.hits={}
		local times={.16,.3,.4,.47}
		for i,t in ipairs(times) do
			local th=i*1.7+GFX.rand(-.4,.4)
			x.hits[i]={t=t*D,p=x.tc+(x.r*math.cos(th)+x.f*math.sin(th)*.6)*(GFX.rand(200,320)*S)}
		end
		-- the cloud vortex: puffs that orbit the centre
		for i=1,GFX.n(x,18) do
			local th=i/18*6.2832
			local rr=GFX.rand(120,340)*S
			local radial=x.r*math.cos(th)+x.f*math.sin(th)
			local tang=x.f*math.cos(th)-x.r*math.sin(th)
			GFX.add({kind=3,p=x.cloud+radial*rr+x.u*(GFX.rand(-40,60)*S),v=tang*(rr*1.2),life=D*GFX.rand(.85,.95),
				s0=GFX.rand(90,130)*S,s1=GFX.rand(170,240)*S,ramp={{.13,.15,.24},{.07,.08,.13}},op=.62,fin=.12,fp=2,
				att=x.cloud,attK=1.4,spin=GFX.rand(-.4,.4)})
		end
	end,
	update=function(x,age,d)
		local D,S,TM=x.D,x.S,x.TM
		local U=x.u
		local P=GFX_PAL_STORM
		local fl=x.tc+U*(3*S)
		local calm=1-goalFxSmooth((age-.8*D)/(.2*D))
		-- lightning flickering inside the cloud
		if age<.85*D and (not x.flickT or age-x.flickT>.09) then
			x.flickT=age
			x.flick={}
			if GFX.rand()<.6 then
				local a=x.cloud+x.r*(GFX.rand(-260,260)*S)+x.f*(GFX.rand(-60,60)*S)
				GFX.makeBolt(x,a,a+(x.r*GFX.rand(-1,1)+U*GFX.rand(-.3,.3)):getSafeNormal()*(GFX.rand(150,300)*S),30*S,3*S,x.flick,1)
				GFX.flashAt(x,a,180*S,{.5,.6,1},.15)
			end
		end
		if x.flick then GFX.drawBoltLines(x.flick,(1-(age-x.flickT)/.09)*calm) end
		-- static crackling across the floor before the strikes, and wind-blown dust
		if age<TM then
			local charge=age/TM
			if not x.staticT or age-x.staticT>.07 then
				x.staticT=age
				x.static={}
				for i=1,GFX.n(x,3) do
					local th=GFX.rand(0,6.2832)
					local a=x.tc+(x.r*math.cos(th)+x.f*math.sin(th))*(GFX.rand(40,260)*S)+U*(4*S)
					local th2=th+GFX.rand(-.8,.8)
					GFX.makeBolt(x,a,a+(x.r*math.cos(th2)+x.f*math.sin(th2))*(GFX.rand(50,120)*S)+U*(GFX.rand(0,30)*S),
						12*S,1.5*S,x.static,0)
				end
			end
			GFX.drawBoltLines(x.static,.4+.6*charge)
			for i=1,GFX.rate(x,"wind",30) do
				local th=GFX.rand(0,6.2832)
				local radial=x.r*math.cos(th)+x.f*math.sin(th)
				local tang=x.f*math.cos(th)-x.r*math.sin(th)
				GFX.add({kind=3,p=x.tc+radial*(GFX.rand(150,400)*S)+U*(10*S),v=tang*(GFX.rand(250,400)*S)+U*(40*S),
					life=GFX.rand(.8,1.2),s0=20*S,s1=60*S,ramp={{.45,.42,.38},{.2,.19,.18}},op=.3,fin=.1,drag=.6})
			end
			GFX.addShake(charge*4*S)
		end
		-- the four strikes
		for i,h in ipairs(x.hits) do
			if GFX.once(x,"hit"..i,h.t) then
				local top=x.cloud+x.r*(GFX.rand(-150,150)*S)
				x.bolts[#x.bolts+1]={t0=age,lines=GFX.makeBolt(x,top,h.p,70*S,7*S,{},2)}
				GFX.flashAt(x,h.p,130*S,{.85,.92,1},.3)
				GFX.shock(x,h.p+U*(4*S),x.r,x.f,240*S,9*S,{.5,.75,1},.5)
				GFX.light(x,h.p,P.light,32000,2000*S,.01,.05,.2)
				GFX.addShake(9*S)
				x.scorch[#x.scorch+1]={p=h.p,t0=age}
				for j=1,GFX.n(x,30) do
					local dir=(GFX.rdir(x)+U*1.1):getSafeNormal()
					GFX.add({kind=2,p=h.p,v=dir*(GFX.rand(400,900)*S),life=GFX.rand(.35,.7),s0=2.5*S,s1=.5*S,
						ramp=P.spark,drag=2,grav=600*S,st=.04})
				end
			end
		end
		-- glowing scorch marks that cool down
		for _,sc in ipairs(x.scorch) do
			local t=age-sc.t0
			local hot=math.exp(-t*2)*calm
			GFX.flatDisc(sc.p+U*(2*S),x.r,x.f,45*S,LinearColor.new(.02,.02,.03,.7*calm))
			GFX.ring(sc.p+U*(3*S),x.r,x.f,40*S,6*S,24,.5,.75,1,hot)
		end
		-- the mega-bolt
		if GFX.once(x,"mega",TM) then
			local hit=x.tc
			x.bolts[#x.bolts+1]={t0=age,lines=GFX.makeBolt(x,x.cloud,hit,90*S,16*S,{},2),life=.45}
			for j=1,3 do
				local off=x.r*((j-2)*220*S)
				x.bolts[#x.bolts+1]={t0=age,lines=GFX.makeBolt(x,x.cloud+off,hit+U*(80*S),60*S,6*S,{},1),life=.35}
			end
			GFX.flashAt(x,hit+U*(100*S),520*S,{.9,.95,1},.4)
			GFX.blast(x,hit+U*(80*S),P,2.2)
			GFX.shock(x,fl,x.r,x.f,800*S,26*S,{.5,.8,1},1.2)
			GFX.light(x,hit+U*(120*S),P.light,90000,3400*S,.02,.25,.4,true)
			GFX.addShake(28*S)
			-- a dome of lightning bursting out in every direction
			x.dome={}
			for j=1,GFX.n(x,10) do
				local dir=(GFX.rdir(x)+U*.6):getSafeNormal()
				GFX.makeBolt(x,hit+U*(80*S),hit+U*(80*S)+dir*(GFX.rand(280,450)*S),40*S,4*S,x.dome,1)
			end
			-- chain lightning racing out along the floor to every scorch mark
			for _,sc in ipairs(x.scorch) do
				x.bolts[#x.bolts+1]={t0=age+.05,lines=GFX.makeBolt(x,fl,sc.p+U*(4*S),35*S,4*S,{},1),life=.4}
			end
		end
		if x.dome then
			local t=(age-TM)/.5
			if t<1 then GFX.drawBoltLines(x.dome,(1-t)*((math.floor(t*18)%2==0) and 1 or .55)) end
		end
		-- bolts flicker out
		for i=#x.bolts,1,-1 do
			local b=x.bolts[i]
			local t=(age-b.t0)/(b.life or .24)
			if t>=1 then
				table.remove(x.bolts,i)
			elseif t>=0 then
				GFX.drawBoltLines(b.lines,(1-t)^1.4*((math.floor(t*14)%2==0) and 1 or .5))
			end
		end
	end,
}

-- 5: EVENT HORIZON -----------------------------------------------------------------------------
-- Space ripples over the goal (wobbling lensing rings) as stars streak in, and a black hole opens
-- with a real accretion disk: layered rings in a tilted plane, white-hot on the inside fading to
-- violet, with hot spots racing round it and two pulsing jets firing out of its poles. It starts
-- tearing debris up off the goal floor and stretching it in. The disk collapses, the hole shrinks
-- to nothing... and bursts back out as a white hole: an inverted flash, an expanding violet dome,
-- shockwaves and a spray of everything it swallowed.
GFX_DEFS[5]={
	init=function(x)
		local S,D=x.S,x.D
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.hc=x.o+x.u*(40*S)
		x.da=x.r
		x.db=(x.f*.55+x.u*.84):getSafeNormal()
		x.dn=Vec3.cross(x.da,x.db):getSafeNormal()
		x.TC,x.TR=.62*D,.7*D
		GFX.light(x,x.hc,{.75,.35,1},25000,2400*S,.3*D,.35*D,.2)
	end,
	update=function(x,age,d)
		local D,S,c,TC,TR=x.D,x.S,x.hc,x.TC,x.TR
		local P=GFX_PAL_VOID
		local U=x.u
		local k=GFX.K
		local black=LinearColor.new(0,0,0,1)
		if age<TR then
			local open=goalFxEaseOut(age/(.2*D))
			local col=goalFxSmooth((age-TC)/(TR-TC))   -- 0..1 while it collapses
			local hole=60*S*open*(1-col)
			-- lensing ripples
			for j=0,3 do
				local f=(age*.7+j/4)%1
				local rr=(520*(1-f)+hole)*(1+.05*math.sin(age*7+j))
				GFX.ring(c,GFX.bR,GFX.bU,rr,(2+3*f)*S,48,.65,.45,1,.35*f*open*(1-col))
			end
			-- the accretion disk: rings from white-hot (inside) to violet (outside), turning
			if open>.05 then
				local bands={{1.25,{1,.95,.85},.95},{1.6,{1,.6,.3},.85},{2,{1,.35,.6},.7},{2.5,{.7,.25,1},.5},{3.1,{.4,.15,.8},.35}}
				for bi,bd in ipairs(bands) do
					local rr=hole*bd[1]*(1+col*.2)+(1-open)*20*S
					local cc=bd[2]
					GFX.ring(c,x.da,x.db,rr,(10-bi)*S*(1-col*.6),56,cc[1],cc[2],cc[3],bd[3]*open)
					-- hot spots racing round
					local spin=age*(6-bi)
					GFX.arc(c,x.da,x.db,rr,(12-bi)*S,spin,spin+.6,6,1,1,1,.5*open*(1-col))
				end
				-- relativistic jets out of the poles
				local jk=k*open*(1-col)*(.75+.25*math.sin(age*25))
				for sd=-1,1,2 do
					local tip=c+x.dn*(sd*520*S)
					GFX.beam(c,tip,18*S,LinearColor.new(.6*jk,.4*jk,jk,.3))
					GFX.beam(c,tip,5*S,LinearColor.new(jk*1.2,jk*1.1,jk*1.3,.9))
				end
			end
			-- the hole itself, with a bright photon ring
			GFX.disc(c,hole,black)
			GFX.ring(c,GFX.bR,GFX.bU,hole+4*S,4*S,40,1,.85,.65,.95*open)
			-- stars streaking in
			for i=1,GFX.rate(x,"stars",160*open*(1-col)) do
				local dir=GFX.rdir(x,.6):getSafeNormal()
				GFX.add({kind=2,p=c+dir*(GFX.rand(450,650)*S),v=dir*(-250*S),life=.8,s0=2*S,s1=1*S,
					ramp={{.8,.7,1},{1,.85,.9}},att=c,attK=12,drag=1,killR=hole+8*S,st=.08,fin=.2,fp=.3})
			end
			-- matter orbiting in the disk plane
			for i=1,GFX.rate(x,"disk",220*open*(1-col)) do
				local th=GFX.rand(0,6.2832)
				local R0=hole*GFX.rand(2,3.4)+40*S
				local radial=x.da*math.cos(th)+x.db*math.sin(th)
				local tang=x.db*math.cos(th)-x.da*math.sin(th)
				GFX.add({kind=2,p=c+radial*R0,v=tang*(R0*2.3),life=GFX.rand(.8,1.2),s0=2.5*S,s1=1.5*S,ramp=P.disk,att=c,
					attK=5.3,drag=.6,killR=hole+5*S,st=.025,fin=.15,fp=.4})
			end
			-- debris torn up off the goal floor and stretched in
			if age>.3*D then
				for i=1,GFX.rate(x,"debris",30*(1-col)) do
					local th=GFX.rand(0,6.2832)
					local p=x.base+(x.r*math.cos(th)+x.f*math.sin(th))*(GFX.rand(150,400)*S)+U*(5*S)
					local sz=GFX.rand(6,12)*S
					GFX.add({kind=4,p=p,v=U*(GFX.rand(100,250)*S),life=1.2,s0=sz,s1=sz*.3,ramp={{.35,.3,.4}},att=c,attK=6,
						drag=.4,killR=hole+10*S,spin=GFX.rand(4,10),op=1,emis=.6,fin=.001,fp=.3})
				end
			end
			GFX.addShake((open*.5+col*1.5)*3*S)
		end
		-- the white hole
		if GFX.once(x,"release",TR) then
			GFX.flashAt(x,c,560*S,{1,1,1},.4)
			GFX.blast(x,c,P,2.2)
			GFX.shock(x,c,x.da,x.db,720*S,14*S,P.ring,1.1)
			GFX.shock(x,c,GFX.bR,GFX.bU,620*S,10*S,P.ring2,1)
			GFX.light(x,c,{.85,.6,1},90000,3400*S,.02,.1,.8)
			GFX.addShake(26*S)
			for i=1,GFX.n(x,100) do
				local dir=GFX.rdir(x,.8):getSafeNormal()
				GFX.add({kind=2,p=c,v=dir*(GFX.rand(1200,2200)*S),life=GFX.rand(.5,.9),s0=4*S,s1=.5*S,ramp=P.spark,
					drag=2,st=.08})
			end
			for i=1,GFX.n(x,30) do
				local dir=GFX.rdir(x):getSafeNormal()
				local sz=GFX.rand(8,16)*S
				GFX.add({kind=4,p=c,v=dir*(GFX.rand(500,1100)*S),life=GFX.rand(1.2,1.8),s0=sz,s1=sz*.8,ramp={{.35,.3,.4}},
					grav=500*S,drag=.5,spin=GFX.rand(4,10),op=1,emis=.6,fin=.001,fp=.5})
			end
		end
		if age>TR then
			local t=(age-TR)/(.3*D)
			if t<1 then GFX.drawSphere(x,c,(60+600*goalFxEaseOut(t))*S,{.75,.45,1},k*.6*(1-t),.35*(1-t),6,14,.3) end
		end
	end,
}

-- 6: GRAND FINALE ------------------------------------------------------------------------------
-- A choreographed fireworks show in three acts. Act 1: five mortars fire in a fan and burst in a
-- perfectly timed row of rainbow peonies. Act 2: a spinning comet corkscrews up and opens into a
-- giant "saturn" shell, a sphere with a tilted ring round it. Act 3: a rapid-fire finale of strobes
-- and crackle under a huge gold willow canopy that hangs and drifts down.
-- GFX.shell is also used by the Christmas Tree's star. Kinds: 0 peony, 1 ring, 2 willow,
-- 3 strobe, 4 saturn (sphere + ring), 5 crackle (pops into little white sparks).
function GFX.shell(x,pos,kind,col,pow)
	local S=x.S*pow
	local ramp={{1,1,1},col,GFX.mulC(col,.35)}
	GFX.flashAt(x,pos,140*S,GFX.mixW(col,.5),.3)
	GFX.light(x,pos,col,22000*pow,2000*S,.02,0,.45)
	if kind==0 or kind==4 then
		-- peony: a crisp sphere of streaks
		for i=1,GFX.n(x,85) do
			local dir=GFX.rdir(x):getSafeNormal()
			GFX.add({kind=2,p=pos,v=dir*(GFX.rand(520,600)*S),life=GFX.rand(1,1.4),s0=3*S,s1=1*S,ramp=ramp,
				drag=1.7,grav=240*S,st=.06,fp=1.3})
		end
		for i=1,GFX.n(x,30) do
			local dir=GFX.rdir(x):getSafeNormal()
			GFX.add({kind=1,p=pos,v=dir*(GFX.rand(480,580)*S),life=GFX.rand(1.2,1.6),s0=8*S,s1=3*S,ramp=ramp,
				drag=1.7,grav=240*S,tw=GFX.rand(14,26)})
		end
	end
	if kind==1 or kind==4 then
		-- ring in a tilted plane (for saturn: a second colour, wider and tilted toward the camera)
		local th=(kind==4) and .5 or GFX.rand(0,3.14)
		local ay=x.u*math.cos(th)+x.f*math.sin(th)
		local rc=(kind==4) and {{1,1,1},{.4,.8,1},{.1,.3,.8}} or ramp
		local spd=(kind==4) and 820 or 590
		local n=GFX.n(x,70)
		for i=1,n do
			local a=i/n*6.2832
			local dir=x.r*math.cos(a)+ay*math.sin(a)
			GFX.add({kind=2,p=pos,v=dir*(spd*GFX.rand(.96,1.04)*S),life=GFX.rand(1,1.3),s0=3*S,s1=1*S,ramp=rc,
				drag=1.6,grav=200*S,st=.06})
		end
	elseif kind==2 then
		-- willow: gold glitter that droops and hangs in the air
		local gold={{1,1,.85},{1,.75,.3},{.55,.3,.05}}
		for i=1,GFX.n(x,80) do
			local dir=GFX.rdir(x):getSafeNormal()
			GFX.add({kind=1,p=pos,v=dir*(GFX.rand(350,520)*S),life=GFX.rand(1.8,2.5),s0=7*S,s1=2*S,ramp=gold,
				drag=2.6,grav=150*S,tw=GFX.rand(8,16)})
		end
	elseif kind==3 then
		-- strobe: fast-flickering white and colour stars
		local white={{1,1,1}}
		for i=1,GFX.n(x,70) do
			local dir=GFX.rdir(x):getSafeNormal()
			GFX.add({kind=1,p=pos,v=dir*(GFX.rand(300,560)*S),life=GFX.rand(1.2,1.8),s0=9*S,s1=5*S,
				ramp=(i%2==0) and white or ramp,drag=2,grav=120*S,tw=GFX.rand(30,45)})
		end
	elseif kind==5 then
		-- crackle: a burst of stars that each pop into a little cluster of white sparks
		for i=1,GFX.n(x,24) do
			local dir=GFX.rdir(x):getSafeNormal()
			local sp=pos+dir*(GFX.rand(120,220)*S)
			for j=1,3 do
				GFX.add({kind=1,p=sp,v=GFX.rdir(x)*(GFX.rand(60,160)*S),life=GFX.rand(.3,.6),s0=6*S,s1=1*S,
					ramp={{1,1,1},{1,.9,.6}},drag=2,grav=150*S,tw=40,fin=.3})
			end
		end
	end
	for i=1,GFX.n(x,5) do
		local dir=GFX.rdir(x,.6)
		GFX.add({kind=3,p=pos+dir*(GFX.rand(0,60)*S),v=dir*(GFX.rand(30,80)*S),life=GFX.rand(1.6,2.2),
			s0=60*S,s1=150*S,ramp={GFX.mulC(col,.18),{.04,.04,.05}},op=.25,fin=.2,spin=GFX.rand(-.4,.4)})
	end
end

GFX_DEFS[6]={
	init=function(x)
		local S,D=x.S,x.D
		local R=GFX.flatRight(x)
		x.rockets={}
		-- act 1: five mortars in a fan, all bursting at the same moment in a row
		local rainbow={{1,.25,.2},{1,.7,.2},{.35,1,.45},{.3,.6,1},{.85,.35,1}}
		for i=1,5 do
			local off=i-3
			x.rockets[#x.rockets+1]={t0=.02*D+math.abs(off)*.02*D,fly=.3*D-math.abs(off)*.02*D,
				from=x.base+R*(off*60*S)+x.f*(60*S),to=x.o+R*(off*170*S)+x.u*((230-math.abs(off)*25)*S)+x.f*(60*S),
				kind=0,col=rainbow[i],pow=.9}
		end
		-- act 3: rapid-fire finale
		for i=1,({6,8,10,12})[x.qi] do
			x.rockets[#x.rockets+1]={t0=.58*D+i*.012*D,fly=.12*D,from=x.base+R*(GFX.rand(-250,250)*S)+x.f*(60*S),
				to=x.o+R*(GFX.rand(-380,380)*S)+x.u*(GFX.rand(120,330)*S)+x.f*(GFX.rand(0,140)*S),
				kind=(i%3==0) and 5 or 3,col=GFX_FW_COLS[1+(i%#GFX_FW_COLS)],pow=.8}
		end
	end,
	update=function(x,age,d)
		local D,S=x.D,x.S
		local trail={{1,.95,.7},{1,.6,.2},{.6,.2,.05}}
		for i,rk in ipairs(x.rockets) do
			if not rk.done and age>=rk.t0 then
				local k=(age-rk.t0)/rk.fly
				if k>=1 then
					rk.done=true
					GFX.shell(x,rk.to,rk.kind,rk.col,rk.pow)
					GFX.addShake(3*S)
				else
					local p=rk.from+(rk.to-rk.from)*goalFxEaseOut(k)+x.r*(math.sin(age*25+i)*4*S)
					GFX.glow(p,10*S,1,.9,.7,1,age*5,.8)
					for j=1,GFX.rate(x,"trail"..i,110) do
						GFX.add({kind=1,p=p,v=GFX.rdir(x)*(GFX.rand(20,70)*S)-x.u*(60*S),life=GFX.rand(.25,.45),
							s0=GFX.rand(5,8)*S,s1=1*S,ramp=trail,grav=150*S,drag=1,tw=18})
					end
				end
			end
		end
		-- act 2: the corkscrew comet into a saturn shell
		local c0,c1=.34*D,.52*D
		local top=x.o+x.u*(400*S)+x.f*(60*S)
		if age>c0 and age<c1 then
			local t=(age-c0)/(c1-c0)
			local axis=x.base+x.f*(60*S)+(top-x.base-x.f*(60*S))*goalFxEaseOut(t)
			local p=axis+(x.r*math.cos(t*20)+x.f*math.sin(t*20))*(40*S*(1-t))
			GFX.glow(p,16*S,1,.95,.8,1,age*6,.9)
			for j=1,GFX.rate(x,"comet",220) do
				GFX.add({kind=1,p=p,v=GFX.rdir(x)*(GFX.rand(30,90)*S),life=GFX.rand(.4,.7),s0=GFX.rand(7,11)*S,s1=1*S,
					ramp={{1,1,1},{.5,.8,1},{.2,.3,.8}},grav=80*S,drag=1.2,tw=22})
			end
		end
		if GFX.once(x,"saturn",c1) then
			GFX.shell(x,top,4,{1,.8,.3},1.6)
			GFX.shock(x,top,GFX.bR,GFX.bU,560*S,10*S,{1,.85,.5},.9)
			GFX.addShake(10*S)
		end
		-- the finale canopy
		if GFX.once(x,"canopy",.68*D) then
			local p=x.o+x.u*(380*S)+x.f*(60*S)
			GFX.shell(x,p,2,{1,.8,.3},1.7)
			GFX.shell(x,p,5,{1,.9,.6},1.2)
			GFX.light(x,p,{1,.8,.45},60000,3200*S,.02,.3,.8)
			GFX.addShake(14*S)
		end
	end,
}

-- 7: GLACIER SHATTER ---------------------------------------------------------------------------
-- Real 3D ice crystals grow out of the goal floor, light up from inside, crack, and then
-- shatter into tumbling shards with a frost shockwave.
function GFX.drawCrystal(x,c,g,crack)
	local ax=c.axis
	local e1=Vec3.cross(ax,x.f)
	if e1:length()<.01 then e1=x.r else e1=e1:getSafeNormal() end
	local e2=Vec3.cross(ax,e1)
	local h=c.h*g
	local rad=c.rad*(.4+.6*g)
	local top=c.root+ax*(h*.78)
	local tip=c.root+ax*h
	local B,T,N={},{},{}
	for j=0,5 do
		local th=(j/6+c.rot)*6.2832
		local dir=e1*math.cos(th)+e2*math.sin(th)
		B[j]=c.root+dir*rad
		T[j]=top+dir*(rad*.9)
		N[j]=e1*math.cos(th+.5236)+e2*math.sin(th+.5236)   -- face normal, halfway to the next corner
	end
	local k=GFX.K*(1+crack*1.5)
	local cp=GFX.cp
	for j=0,5 do
		local j2=(j+1)%6
		local n=N[j]
		local view=(cp-(B[j]+T[j2])*.5):getSafeNormal()
		local rim=1-math.abs(Vec3.dot(n,view))
		local shade=.25+.55*math.max(0,Vec3.dot(n,x.ld))+.6*rim*rim
		local r,gg,b=.40*shade*k,.72*shade*k,shade*k
		local lc=LinearColor.new(r,gg,b,.78)
		WorldDraw.drawTriangle(B[j],B[j2],T[j2],lc,0)
		WorldDraw.drawTriangle(B[j],T[j2],T[j],lc,0)
		WorldDraw.drawTriangle(T[j],T[j2],tip,LinearColor.new(r*1.3,gg*1.3,b*1.3,.85),0)
		local ek=k*.9
		WorldDraw.drawLine(B[j],T[j],.7*ek,.92*ek,ek,1.5,0)
		WorldDraw.drawLine(T[j],tip,.8*ek,.95*ek,ek,1.5,0)
	end
	GFX.glow(c.root+ax*(h*.45),rad*1.7,.45,.75,1,.35+.4*crack,c.rot*6,.3)
	if crack>0 then
		-- cracks flicker across the surface just before it shatters
		local seed=math.floor(x.age*20)
		local prev=c.root+ax*(h*.1)
		local ck=k*crack
		for j=1,5 do
			local q=c.root+ax*(h*(.1+j*.16))+e1*((goalFxNoise(seed+j*1.7+c.rot*10)-.5)*rad*1.6)
				+e2*((goalFxNoise(seed+j*3.1)-.5)*rad)
			WorldDraw.drawLine(prev,q,ck,ck,ck,2.5,0)
			prev=q
		end
	end
end

GFX_DEFS[7]={
	init=function(x)
		local S,D=x.S,x.D
		x.crystals={}
		local n=({7,9,11,13})[x.qi]
		for i=1,n do
			local off=(i-1)/(n-1)*2-1
			local center=math.abs(off)<.15
			-- outer crystals pop first, the big centre spire last, so it builds toward the middle
			x.crystals[i]={
				root=x.base+x.r*((off*230+GFX.rand(-20,20))*S)+x.f*(GFX.rand(10,110)*S),
				axis=(x.u+x.r*(off*.6+GFX.rand(-.12,.12))+x.f*GFX.rand(-.05,.35)):getSafeNormal(),
				h=(center and GFX.rand(420,480) or GFX.rand(190,340))*S*(1-math.abs(off)*.3),
				rad=GFX.rand(32,50)*S,t0=(1-math.abs(off))*.2*D+GFX.rand(0,.03*D),rot=GFX.rand(0,1),
			}
		end
		x.TS=.5*D
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		GFX.light(x,x.base+x.u*(200*S),{.5,.8,1},18000,2200*S,.3*D,.15*D,.3)
	end,
	update=function(x,age,d)
		local D,S,P,TS=x.D,x.S,GFX_PAL_ICE,x.TS
		if age<TS then
			local crack=goalFxSmooth((age-(TS-.08*D))/(.08*D))
			for _,c in ipairs(x.crystals) do
				local g=GFX.backOut((age-c.t0)/(.12*D))
				if g>0 then
					GFX.drawCrystal(x,c,g,crack)
					if not c.popped then
						-- each crystal bursts out of the floor: flash, frost ring, ice chips and a cold light
						c.popped=true
						GFX.flashAt(x,c.root+x.u*(20*S),90*S,{.8,.95,1},.25)
						GFX.shock(x,c.root+x.u*(4*S),x.r,x.f,140*S,7*S,{.6,.9,1},.45)
						for i=1,GFX.n(x,12) do
							local dir=(GFX.rdir(x)+x.u*1.3):getSafeNormal()
							local sz=GFX.rand(5,11)*S
							GFX.add({kind=4,p=c.root,v=dir*(GFX.rand(300,700)*S),life=GFX.rand(.6,1),s0=sz,s1=sz*.6,
								ramp=P.shard,grav=900*S,drag=.8,spin=GFX.rand(6,14),op=.85,emis=1,fin=.001,fp=.6})
						end
						for i=1,GFX.n(x,8) do
							local dir=(GFX.rdir(x)+x.u*.8):getSafeNormal()
							GFX.add({kind=2,p=c.root,v=dir*(GFX.rand(400,800)*S),life=GFX.rand(.25,.45),s0=2.5*S,s1=.5*S,
								ramp=P.spark,drag=2,grav=500*S,st=.04})
						end
					end
				end
			end
			for i=1,GFX.rate(x,"mist",22) do
				local dir=(x.r*GFX.rand(-1,1)+x.f*GFX.rand(-.3,1)):getSafeNormal()
				GFX.add({kind=3,p=x.base+dir*(GFX.rand(0,120)*S)+x.u*(10*S),v=dir*(GFX.rand(60,140)*S)+x.u*(15*S),
					life=GFX.rand(1.4,2),s0=50*S,s1=GFX.rand(140,190)*S,ramp=P.smoke,op=.22,fin=.25,fp=1.5,drag=.6,
					spin=GFX.rand(-.4,.4)})
			end
			for i=1,GFX.rate(x,"glint",30) do
				local c=x.crystals[math.min(#x.crystals,1+math.floor(GFX.rand()*#x.crystals))]
				local g=math.min(1,GFX.backOut((age-c.t0)/(.12*D)))
				if g>.2 then
					GFX.add({kind=1,p=c.root+c.axis*(c.h*g*GFX.rand(.2,.95))+GFX.rdir(x)*(c.rad*.8),v=Vec3.zeroVector,
						life=GFX.rand(.15,.3),s0=GFX.rand(8,13)*S,s1=0,ramp={{1,1,1},{.6,.9,1}},fin=.3,hot=.9})
				end
			end
		end
		if GFX.once(x,"shatter",TS) then
			for _,c in ipairs(x.crystals) do
				for i=1,GFX.n(x,20) do
					local p=c.root+c.axis*(c.h*GFX.rand(.05,.95))
					local dir=((p-x.base):getSafeNormal()+GFX.rdir(x)*.5+x.u*.5):getSafeNormal()
					local sz=GFX.rand(14,34)*S
					GFX.add({kind=4,p=p,v=dir*(GFX.rand(450,1250)*S),life=GFX.rand(1.2,1.9),s0=sz,s1=sz*.8,
						ramp=P.shard,grav=750*S,drag=.6,spin=GFX.rand(4,11),op=.85,emis=1,fin=.001,fp=.6})
				end
			end
			local mid=x.base+x.u*(180*S)
			GFX.blast(x,mid,P,1.4)
			GFX.shock(x,x.base+x.u*(5*S),x.r,x.f,520*S,20*S,{.7,.92,1},1.1)
			for i=1,GFX.n(x,70) do
				local dir=GFX.rdir(x,.8)
				GFX.add({kind=1,p=mid+dir*(GFX.rand(0,120)*S),v=dir*(GFX.rand(150,500)*S),life=GFX.rand(.8,1.4),
					s0=GFX.rand(5,9)*S,s1=1*S,ramp={{1,1,1},{.6,.9,1}},drag=1.8,grav=90*S,tw=GFX.rand(15,30)})
			end
		end
	end,
}

-- 8: TEAM PRIDE --------------------------------------------------------------------------------
-- Stadium hype in the scoring team's colour. Four searchlights sweep and cross over the goal while
-- three drumbeat pulses build up faster and faster. On the last beat a giant 3D team flag rises
-- on a pole and waves, flame jets roar up on both sides in team-coloured fire, confetti cannons
-- and streamers fire, and team-coloured fireworks burst overhead.
function GFX.drawStreamer(x,st,age)
	local t=age-st.t0
	local life=1.8*x.ts
	if t<=0 or t>life then return end
	local S=x.S
	local kd,g=1.6,500*S
	local a=1-goalFxSmooth((t-life*.6)/(life*.4))
	local c=st.col
	local kk=GFX.K*.9*a
	local lc=LinearColor.new(c[1]*kk,c[2]*kk,c[3]*kk,a)
	local prev=nil
	for i=0,10 do
		local tt=math.max(0,t-i*.035)
		local e=(1-math.exp(-kd*tt))/kd
		local p=st.p0+st.v0*e-x.u*(g*(tt/kd-e/kd))
			+x.r*(math.sin(tt*16+st.ph)*10*S)+x.f*(math.cos(tt*13+st.ph)*6*S)
		if prev then GFX.beam(prev,p,5*S*(1-i/12),lc) end
		prev=p
	end
end

-- a waving cloth flag: team colour with a white band and a white star, rippling along its length
function GFX.drawFlag(x,pole,R,U,F,w,h,col,a,age)
	local S=x.S
	local nx,ny=({6,8,10,12})[x.qi],4
	local k=GFX.K*.55
	local function P(u,v)
		local wave=math.sin(u*4-age*7)*u*28*S+math.sin(u*7-age*11+v*2)*u*6*S
		return pole+R*(u*w)+U*(v*h)+F*wave-U*(u*u*12*S)
	end
	for i=0,nx-1 do
		for j=0,ny-1 do
			local u0,u1=i/nx,(i+1)/nx
			local v0,v1=j/ny,(j+1)/ny
			local a0,b0,b1,a1=P(u0,v0),P(u1,v0),P(u1,v1),P(u0,v1)
			local n=Vec3.cross(b0-a0,a1-a0):getSafeNormal()
			local sh=(.45+.55*math.abs(Vec3.dot(n,x.ld)))
			local white=(j==1 or j==2) and (i>=1 and i<=2)   -- white band near the pole
			local c=white and {1,1,1} or col
			local lc=LinearColor.new(c[1]*k*sh,c[2]*k*sh,c[3]*k*sh,a)
			WorldDraw.drawTriangle(a0,b0,b1,lc,0)
			WorldDraw.drawTriangle(a0,b1,a1,lc,0)
		end
	end
	-- white star on the flag
	local sc=P(.62,.5)+(GFX.cp-P(.62,.5)):getSafeNormal()*(2*S)
	GFX.star(sc,h*.22,h*.09,0,LinearColor.new(GFX.K*1.1,GFX.K*1.1,GFX.K*1.1,a))
end

GFX_DEFS[8]={
	init=function(x)
		local S,D=x.S,x.D
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.tc=GFX.teamColor(true)
		x.pal=GFX.teamPal(x.tc)
		x.pc=x.base+x.f*(60*S)
		x.TB=.4*D
		local R=GFX.flatRight(x)
		x.posts={x.pc+R*(260*S),x.pc-R*(260*S)}
		x.streamers={}
		for i=1,GFX.n(x,10) do
			local side=(i%2==0) and 1 or -1
			x.streamers[i]={p0=x.posts[(side>0) and 1 or 2],
				v0=(x.u+R*(-side*GFX.rand(.15,.55))+x.f*GFX.rand(.1,.5)):getSafeNormal()*(GFX.rand(1100,1500)*S),
				t0=x.TB+GFX.rand(0,.1*D),col=(i%3==0) and {1,1,1} or x.tc,ph=GFX.rand(0,6)}
		end
		x.shells={}
		for i=1,({3,4,5,6})[x.qi] do
			x.shells[i]={t=x.TB+(.1+i*.07)*D,pos=x.o+R*(GFX.rand(-380,380)*S)+x.u*(GFX.rand(250,420)*S)+x.f*(GFX.rand(0,120)*S),
				kind=(i%2==0) and 1 or 0}
		end
	end,
	update=function(x,age,d)
		local D,S,TB=x.D,x.S,x.TB
		local U=x.u
		local R=GFX.flatRight(x)
		local Fv=GFX.cp-x.pc
		local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
		local tc=x.tc
		local k=GFX.K
		local fade=1-goalFxSmooth((age-.85*D)/(.15*D))
		-- four searchlights sweeping and crossing
		if age<.8*D then
			local sa=goalFxSmooth(age/(.1*D))*fade
			for i=1,4 do
				local side=(i<=2) and 1 or -1
				local root=x.pc+R*(side*(380+(i%2)*120)*S)+F*(-40*S)
				local sweep=math.sin(age*(1.6+i*.3)+i)*.6
				local dir=(U+R*(-side*.35+sweep)+F*.15):getSafeNormal()
				local tip=root+dir*(900*S)
				local bk=k*sa
				GFX.beam(root,tip,(14+30)*S,LinearColor.new(tc[1]*bk*.6,tc[2]*bk*.6,tc[3]*bk*.6,.12*sa))
				GFX.beam(root,tip,6*S,LinearColor.new(bk,bk,bk,.35*sa))
				GFX.glow(root,22*S,1,1,1,sa,0,.8)
			end
		end
		-- three drumbeats, each sooner than the last
		for i,t in ipairs({.08,.2,.29}) do
			if GFX.once(x,"drum"..i,t*D) then
				GFX.shock(x,x.pc+U*(4*S),x.r,x.f,(260+i*60)*S,(10+i*3)*S,tc,.5)
				GFX.flashAt(x,x.o,(100+i*40)*S,GFX.mixW(tc,.5),.2)
				GFX.addShake((4+i*3)*S)
			end
		end
		-- the big moment
		if GFX.once(x,"pride",TB) then
			GFX.blast(x,x.o+U*(80*S),x.pal,1.4)
			GFX.light(x,x.o,tc,60000,3200*S,.02,.4,.6)
			GFX.addShake(16*S)
			for pi,post in ipairs(x.posts) do
				local side=(pi==1) and 1 or -1
				for i=1,GFX.n(x,80) do
					local dir=(U+R*(-side*GFX.rand(.1,.6))+F*GFX.rand(.05,.5)+GFX.rdir(x)*.12):getSafeNormal()
					local sz=GFX.rand(6,10)*S
					local cc=({tc,{1,1,1},{1,.82,.3},GFX.mixW(tc,.5)})[1+(i%4)]
					GFX.add({kind=4,quad=true,p=post,v=dir*(GFX.rand(900,1600)*S),life=GFX.rand(2,2.8)*x.ts,s0=sz,s1=sz,
						ramp={cc},grav=380*S,drag=2.3,spin=GFX.rand(6,14),op=.95,emis=.9,fin=.001,fp=.5})
				end
			end
		end
		for _,st in ipairs(x.streamers) do GFX.drawStreamer(x,st,age) end
		-- the flag rising on its pole and waving
		if age>TB-.05*D then
			local rise=goalFxEaseOut((age-(TB-.05*D))/(.15*D))
			local pole=x.pc-R*(120*S)-F*(40*S)
			local poleTop=pole+U*((120+330*rise)*S)
			local pk=k*.6
			GFX.beam(pole,poleTop+U*(20*S),4*S,LinearColor.new(.75*pk,.75*pk,.78*pk,fade))
			GFX.glow(poleTop+U*(20*S),10*S,1,.85,.4,fade,0,.7)
			GFX.drawFlag(x,poleTop-U*(150*S),R,U,F,300*S,150*S,tc,fade,age)
		end
		-- flame jets in team colours on both sides
		if age>TB and age<TB+.35*D then
			local jt=(age-TB)/(.35*D)
			local burst=math.sin(jt*3*math.pi)
			if burst>0 then
				for _,post in ipairs(x.posts) do
					for i=1,GFX.rate(x,"jet"..tostring(post.x),200*burst) do
						GFX.add({kind=1,p=post+R*(GFX.rand(-15,15)*S),v=U*(GFX.rand(900,1400)*S)+GFX.rdir(x)*(60*S),
							life=GFX.rand(.4,.6),s0=20*S,s1=GFX.rand(50,70)*S,ramp=x.pal.fire,drag=1.4,grav=-100*S,fin=.03,
							fp=1.4,spin=GFX.rand(-2,2)})
					end
				end
			end
		end
		-- team-coloured fireworks overhead
		for i,sh in ipairs(x.shells) do
			if GFX.once(x,"shell"..i,sh.t) then GFX.shell(x,sh.pos,sh.kind,tc,1) end
		end
	end,
}

-- filled ellipse (12-triangle fan) in the plane of ax/ay
function GFX.ellipse(c,ax,ay,lc)
	local prev=c+ax
	for i=1,12 do
		local th=i/12*6.2832
		local q=c+ax*math.cos(th)+ay*math.sin(th)
		WorldDraw.drawTriangle(c,prev,q,lc,0)
		prev=q
	end
end

-- camera's right direction with the tilt taken out, so characters and text stand upright
function GFX.flatRight(x)
	local R=GFX.bR-x.u*Vec3.dot(GFX.bR,x.u)
	if R:length()<.01 then return x.r end
	return R:getSafeNormal()
end

GFX_GHOSTFIRE={{.9,1,.8},{.4,1,.25},{.1,.6,.1},{.02,.12,.03}}

-- 9: JACK-O'-BLAST ------------------------------------------------------------------------------
-- A giant 3D jack-o'-lantern bounces up out of the goal and its carved face flickers to life.
-- It rumbles and cracks with light, then blows apart into pumpkin chunks, seeds, bats and green
-- ghost-fire, and its glowing grin floats up into the dark like a spirit.
GFX_PAL_PUMPKIN={flash={1,.8,.4},ring={1,.5,.08},ring2={.5,1,.2},light={1,.5,.12},
	spark={{1,1,.7},{1,.6,.1},{.8,.2,.02}},
	fire={{1,1,.8},{1,.55,.05},{.45,.9,.15},{.05,.12,.02}},
	ember={{1,.9,.5},{1,.5,.05},{.4,.9,.1}},
	smoke={{.16,.06,.2},{.05,.02,.07}}}

-- point on the front of the pumpkin for face coordinates sx,sy in -1..1
function GFX.pumpkinFace(x,pk,sx,sy)
	local w,h=pk.R*pk.wS,pk.R*.82*pk.hS
	local px,py=sx*.8,sy*.75
	local depth=math.sqrt(math.max(.05,1-px*px-py*py))
	return pk.c+x.r*(px*w)+x.u*(py*h)+x.f*(depth*w+3*x.S)
end

-- the carved, candle-lit face (also drawn on its own for the floating grin)
function GFX.pumpkinCarving(x,pk)
	local glow=pk.glow
	if glow<=.01 then return end
	local fl=glow*(.8+.2*math.sin(x.age*31)*math.sin(x.age*17+1))
	local fk=GFX.K*1.4*fl
	local lc=LinearColor.new(fk,.72*fk,.18*fk,math.min(1,glow))
	local function F(sx,sy) return GFX.pumpkinFace(x,pk,sx,sy) end
	for sd=-1,1,2 do
		WorldDraw.drawTriangle(F(sd*.62,.22),F(sd*.18,.22),F(sd*.36,.62),lc,0)
	end
	WorldDraw.drawTriangle(F(-.1,0),F(.1,0),F(0,.18),lc,0)
	-- jagged grin with two top teeth and one bottom tooth
	local prevU,prevL=nil,nil
	for i=0,12 do
		local sx=-.68+i/12*1.36
		local up=-.12+.3*sx*sx
		local lo=up-(.34*(1-(math.abs(sx)/.7)^3)+.02)
		if i==4 or i==8 then up=up-.12 end
		if i==6 then lo=lo+.12 end
		local pu,pl=F(sx,up),F(sx,lo)
		if prevU then
			WorldDraw.drawTriangle(prevU,pu,pl,lc,0)
			WorldDraw.drawTriangle(prevU,pl,prevL,lc,0)
		end
		prevU,prevL=pu,pl
	end
	-- candle light spilling out of the face
	GFX.glow(F(0,0)+x.f*(20*x.S),pk.R*.9,1,.55,.1,.35*math.min(1,fl),x.age,.3)
end

function GFX.drawPumpkin(x,pk)
	local S,R,c=x.S,pk.R,pk.c
	local lobes=8
	local nLon=lobes*((x.qi<=2) and 2 or 3)
	local nLat=({6,7,9,10})[x.qi]
	local G={}
	for i=0,nLat do
		local phi=i/nLat*math.pi
		local row={}
		for j=0,nLon-1 do
			local th=j/nLon*6.2832+math.pi*.5   -- a ridge faces the camera
			local lob=.5+.5*math.cos(th*lobes)
			local rr=R*pk.wS*(.88+.12*lob)*math.sin(phi)
			local y=math.cos(phi)*R*.82*pk.hS
			if i==0 then y=y-R*.12*pk.hS end   -- dimple where the stem sits
			row[j]=c+(x.r*math.cos(th)+x.f*math.sin(th))*rr+x.u*y
		end
		G[i]=row
	end
	local cp=GFX.cp
	local k=GFX.K*.55
	local glow=math.min(1,pk.glow)
	for i=0,nLat-1 do
		for j=0,nLon-1 do
			local j2=(j+1)%nLon
			local a,b,cc,d=G[i][j],G[i][j2],G[i+1][j2],G[i+1][j]
			local mid=(a+b+cc+d)*.25
			local n=(mid-c):getSafeNormal()
			local view=(cp-mid):getSafeNormal()
			if Vec3.dot(n,view)>-.15 then
				local th=(j+.5)/nLon*6.2832+math.pi*.5
				local lob=.5+.5*math.cos(th*lobes)
				local rim=1-math.abs(Vec3.dot(n,view))
				local sh=(.25+.75*math.max(0,Vec3.dot(n,x.ld)))*(.55+.45*lob)+.35*rim*rim*glow
				local lc=LinearColor.new((sh+.25*glow*rim)*k,(.42*sh+.08*glow*rim)*k,.04*sh*k,1)
				WorldDraw.drawTriangle(a,b,cc,lc,0)
				WorldDraw.drawTriangle(a,cc,d,lc,0)
			end
		end
	end
	GFX.pumpkinCarving(x,pk)
	-- light bleeding through cracks before it bursts
	if pk.crack>0 then
		local ck=GFX.K*1.5*pk.crack
		for ci=1,7 do
			local sx,sy=(goalFxNoise(ci*3.1)-.5)*1.7,(goalFxNoise(ci*5.7)-.5)*1.5
			local prev=GFX.pumpkinFace(x,pk,sx,sy)
			for j=1,4 do
				sx=math.clamp(sx+(goalFxNoise(ci*7.3+j)-.5)*.6*pk.crack,-1,1)
				sy=math.clamp(sy+(goalFxNoise(ci*9.1+j*2)-.5)*.6*pk.crack,-1,1)
				local q=GFX.pumpkinFace(x,pk,sx,sy)
				WorldDraw.drawLine(prev,q,ck,.6*ck,.15*ck,3,0)
				prev=q
			end
		end
	end
	-- stem and a curly vine
	local top=c+x.u*(R*.82*pk.hS*.88)
	GFX.beam(top,top+x.u*(R*.38*pk.hS)+x.r*(R*.12)-x.f*(R*.05),R*.09,LinearColor.new(.22*k,.32*k,.08*k,1))
	local prev=top+x.u*(R*.05)
	for j=1,8 do
		local w=j/8
		local q=top+x.r*(-math.cos(w*7)*R*.12*w-w*R*.25)+x.u*(R*.08+math.sin(w*7)*R*.1)+x.f*(R*.1*w)
		WorldDraw.drawLine(prev,q,.2*k,.55*k,.1*k,2.5,0)
		prev=q
	end
end

GFX_DEFS[9]={
	init=function(x)
		local S,D=x.S,x.D
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.pk={R=175*S,wS=0,hS=0,glow=0,crack=0,c=x.base}
		x.TB=.5*D
		GFX.flashAt(x,x.base+x.u*(30*S),160*S,{1,.6,.2},.4)
		GFX.shock(x,x.base+x.u*(4*S),x.r,x.f,360*S,16*S,{1,.5,.1},.8)
	end,
	update=function(x,age,d)
		local D,S,pk,TB=x.D,x.S,x.pk,x.TB
		if age<TB then
			-- bounces up with squash and stretch
			local g=GFX.backOut(age/(.16*D))
			local bounce=math.sin(math.clamp(age/(.16*D),0,1)*math.pi)
			pk.hS=g*(1+.18*bounce)
			pk.wS=math.max(.05,g*(1-.08*bounce))
			local rumble=goalFxSmooth((age-.25*D)/(.25*D))
			pk.glow=goalFxSmooth((age-.1*D)/(.12*D))*(1+1.2*rumble)
			pk.crack=goalFxSmooth((age-.36*D)/(.14*D))
			local sh=rumble*14*S
			pk.c=x.base+x.f*(60*S)+x.u*(pk.R*.82*pk.hS)+x.r*(math.sin(age*53)*sh)+x.u*(math.sin(age*47+1)*sh*.5)
			GFX.drawPumpkin(x,pk)
			if pk.glow>.3 then
				-- green ghost-fire licking out of the top
				local top=pk.c+x.u*(pk.R*.82*pk.hS*.85)
				for i=1,GFX.rate(x,"gfire",70*pk.glow) do
					GFX.add({kind=1,p=top+x.r*(GFX.rand(-40,40)*S),v=x.u*(GFX.rand(200,380)*S)+GFX.rdir(x)*(40*S),
						life=GFX.rand(.4,.7),s0=GFX.rand(14,22)*S,s1=GFX.rand(40,60)*S,ramp=GFX_GHOSTFIRE,drag=1,
						grav=-120*S,fin=.05,fp=1.5,spin=GFX.rand(-2,2)})
				end
			end
			if pk.crack>0 then
				-- sparks spitting out of the cracks
				for i=1,GFX.rate(x,"leak",90*pk.crack) do
					local p=GFX.pumpkinFace(x,pk,GFX.rand(-.9,.9),GFX.rand(-.8,.8))
					GFX.add({kind=2,p=p,v=(x.f+GFX.rdir(x)*.6):getSafeNormal()*(GFX.rand(200,500)*S),
						life=GFX.rand(.25,.45),s0=2.5*S,s1=.5*S,ramp=GFX_PAL_PUMPKIN.spark,drag=1.5,grav=300*S,st=.04})
				end
			end
			if GFX.once(x,"glowlight",.12*D) then
				GFX.light(x,pk.c+x.f*(pk.R*1.3),{1,.55,.15},25000,2200*S,.15*D,TB-.27*D,.15,true)
			end
		end
		if GFX.once(x,"boom",TB) then
			local c,R=pk.c,pk.R
			GFX.blast(x,c,GFX_PAL_PUMPKIN,1.6)
			GFX.shock(x,c,GFX.bR,GFX.bU,620*S,14*S,{.4,1,.2},1.1)
			for i=1,GFX.n(x,46) do
				-- pumpkin shell chunks
				local dir=GFX.rdir(x,.8):getSafeNormal()
				local sz=GFX.rand(22,48)*S
				GFX.add({kind=4,p=c+dir*(R*.8),v=(dir+x.u*.35)*(GFX.rand(500,1200)*S),life=GFX.rand(1.3,2),s0=sz,
					s1=sz*.85,ramp={{1,.45,.04},{.7,.25,.02}},grav=900*S,drag=.5,spin=GFX.rand(3,9),op=1,emis=.75,
					fin=.001,fp=.5})
			end
			for i=1,GFX.n(x,40) do
				-- pale flesh bits and seeds
				local dir=GFX.rdir(x,.8):getSafeNormal()
				GFX.add({kind=4,p=c+dir*(R*.4),v=(dir+x.u*.5)*(GFX.rand(300,900)*S),life=GFX.rand(1,1.6),
					s0=GFX.rand(5,9)*S,s1=4*S,ramp={{1,.92,.7}},grav=850*S,drag=.6,spin=GFX.rand(8,16),op=1,emis=.8,
					fin=.001,fp=.5})
			end
			for i=1,GFX.n(x,45) do
				-- ball of green ghost-fire
				local dir=GFX.rdir(x,.8)
				GFX.add({kind=1,p=c+dir*(GFX.rand(0,60)*S),v=dir*(GFX.rand(200,600)*S),life=GFX.rand(.6,1.1),
					s0=GFX.rand(40,60)*S,s1=GFX.rand(100,150)*S,ramp=GFX_GHOSTFIRE,drag=2.8,grav=-120*S,fin=.02,fp=1.5,
					spin=GFX.rand(-1,1)})
			end
			for i=1,GFX.n(x,26) do
				-- bats burst out
				local dir=(GFX.rdir(x,.5)+x.u*.6):getSafeNormal()
				local bs=GFX.rand(28,44)*S
				GFX.add({kind=5,p=c+dir*(R*.3),v=dir*(GFX.rand(350,800)*S),life=GFX.rand(1.6,2.4),s0=bs,s1=bs,
					ramp={{1,1,1}},drag=.9,grav=-60*S,fl=GFX.rand(18,28),fin=.02,fp=3})
			end
			GFX.light(x,c,{.5,1,.2},30000,2400*S,.05,.1,.6)
			x.grinT=age
			x.grinC=c
		end
		if x.grinT and age<x.grinT+.4*D then
			-- the grin survives the blast and floats away
			local t=(age-x.grinT)/(.4*D)
			GFX.pumpkinCarving(x,{c=x.grinC+x.u*(t*220*S),R=pk.R*(1+t*.6),wS=1,hS=1,glow=(1-t)^1.5*1.6})
		end
	end,
}

-- 10: SPIRIT SWARM ------------------------------------------------------------------------------
-- A full moon rises behind the goal, a ring of green ghost-fire opens on the floor and ghosts
-- spiral up out of it while bats circle. The ghosts swoop together and burst in a spectral blast.
GFX_PAL_SPIRIT={flash={.85,1,.9},ring={.4,1,.6},ring2={.7,.4,1},light={.45,1,.6},
	spark={{1,1,1},{.6,1,.75},{.3,.5,1}},
	fire={{1,1,1},{.55,1,.7},{.35,.25,.9},{.03,.05,.1}},
	ember={{1,1,1},{.6,1,.7},{.5,.3,1}},
	smoke={{.08,.12,.12},{.03,.04,.05}}}

-- sheet ghost with a wavy hem, hollow eyes and a mouth that opens (mouthO 0..1)
function GFX.drawGhost(x,p,s,a,lean,mouthO)
	if a<=.01 then return end
	local R,U=GFX.bR,GFX.bU
	local ax=R*math.cos(lean)+U*math.sin(lean)
	local ay=U*math.cos(lean)-R*math.sin(lean)
	local k=GFX.K*.85*a
	local outline={}
	for i=0,8 do
		local th=i/8*math.pi
		outline[#outline+1]=p+ax*(math.cos(th)*s)+ay*(math.sin(th)*s)
	end
	for i=0,8 do
		local hy=-1.35+.22*math.sin(i*1.7+x.age*9)
		outline[#outline+1]=p+ax*((-1+i/4)*s*(1+.08*math.sin(x.age*5)))+ay*(hy*s)
	end
	outline[#outline+1]=outline[1]
	GFX.fan(p-ay*(.4*s),outline,LinearColor.new(.78*k,k,.9*k,a*.75))
	GFX.glow(p-ay*(.3*s),s*2.2,.5,1,.7,.35*a,x.age,.2)
	local dark=LinearColor.new(0,.02*a,.02*a,a*.95)
	local f=(GFX.cp-p):getSafeNormal()*(2*x.S)
	for sd=-1,1,2 do
		GFX.ellipse(p+ax*(sd*.35*s)+ay*(.1*s)+f,ax*(.14*s),ay*(.22*s),dark)
	end
	local mo=mouthO or .5
	GFX.ellipse(p-ay*(.45*s)+f,ax*(.16*s*(.6+.4*mo)),ay*(.2*s*(.3+.7*mo)),dark)
end

GFX_DEFS[10]={
	init=function(x)
		local S,D=x.S,x.D
		x.ghosts={}
		local n=({4,6,8,10})[x.qi]
		for i=1,n do
			x.ghosts[i]={t0=(i-1)/n*.25*D,ph=i/n*6.2832,rad=GFX.rand(170,260)*S,
				spd=GFX.rand(1.6,2.4)*((i%2==0) and 1 or -1),sz=GFX.rand(38,58)*S,bob=GFX.rand(0,6)}
		end
		x.TB=.68*D
		x.moon=x.o+x.u*(170*S)-x.f*(260*S)
		GFX.shock(x,x.base+x.u*(4*S),x.r,x.f,300*S,14*S,{.4,1,.5},.8)
		GFX.light(x,x.base+x.u*(150*S),{.35,1,.5},22000,2200*S,.2*D,.45*D,.3,true)
	end,
	update=function(x,age,d)
		local D,S,o,TB=x.D,x.S,x.o,x.TB
		-- full moon rising behind it all
		local mr=goalFxEaseOut(age/(.25*D))
		local mf=mr*(1-goalFxSmooth((age-.85*D)/(.15*D)))
		if mf>.01 then
			local mp=x.moon+x.u*((mr-1)*120*S)
			local mk=GFX.K*.6*mf
			GFX.glow(mp,330*S,1,.95,.75,.35*mf,0,.1)
			GFX.disc(mp,190*S,LinearColor.new(mk,.95*mk,.75*mk,mf))
			local zc=(GFX.cp-mp):getSafeNormal()*(3*S)
			for _,cr in ipairs({{-.35,.25,.22},{.3,-.2,.3},{.1,.45,.14},{-.15,-.45,.18}}) do
				GFX.disc(mp+GFX.bR*(cr[1]*190*S)+GFX.bU*(cr[2]*190*S)+zc,cr[3]*190*S,
					LinearColor.new(.8*mk,.72*mk,.5*mk,mf))
			end
		end
		if age<TB then
			-- ring of ghost-fire on the floor
			local e=goalFxSmooth(age/(.1*D))
			GFX.ring(x.base+x.u*(3*S),x.r,x.f,280*S,8*S*(1+.3*math.sin(age*20)),48,.35,1,.45,.8*e)
			for i=1,GFX.rate(x,"rfire",110*e) do
				local th=GFX.rand(0,6.2832)
				GFX.add({kind=1,p=x.base+(x.r*math.cos(th)+x.f*math.sin(th))*(280*S),v=x.u*(GFX.rand(150,320)*S),
					life=GFX.rand(.4,.7),s0=GFX.rand(10,16)*S,s1=GFX.rand(30,45)*S,ramp=GFX_GHOSTFIRE,drag=1,
					grav=-100*S,fin=.05,fp=1.5,spin=GFX.rand(-2,2)})
			end
			if GFX.once(x,"bats",.15*D) then
				-- bats circling the goal
				for i=1,GFX.n(x,18) do
					local th=GFX.rand(0,6.2832)
					local R=GFX.rand(250,380)*S
					local radial=x.r*math.cos(th)+x.u*math.sin(th)
					local tang=x.u*math.cos(th)-x.r*math.sin(th)
					local bs=GFX.rand(22,34)*S
					GFX.add({kind=5,p=o+radial*R,v=tang*(R*2),life=TB-.15*D+.3,s0=bs,s1=bs,ramp={{1,1,1}},
						att=o,attK=4,fl=GFX.rand(18,26),fin=.1,fp=4})
				end
			end
		end
		local hO=Vec3.dot(o-x.base,x.u)
		for gi,gh in ipairs(x.ghosts) do
			local t=age-gh.t0
			if t>0 and age<TB+.25*D then
				local rise=goalFxEaseOut(t/(.3*D))
				local ang=gh.ph+t*gh.spd
				local rad=gh.rad*(.4+.6*rise)
				local pb=x.base+x.f*(60*S)+x.r*(math.cos(ang)*rad)+x.f*(math.sin(ang)*rad*.5)
					+x.u*(hO*rise+math.sin(age*3+gh.bob)*25*S)
				-- swoop into the centre just before the burst
				local conv=goalFxSmooth((age-(TB-.12*D))/(.12*D))
				local p=pb+(o-pb)*(conv*.8)
				local a=math.min(1,t/(.08*D))
				local size=gh.sz
				local mo=.3+.7*conv
				if age>TB then
					local out=(age-TB)/(.25*D)
					p=o+(pb-o):getSafeNormal()*(40*S+out*700*S)
					a=a*(1-out)
					size=size*(1+out*.8)
					mo=1
				end
				GFX.drawGhost(x,p,size,a,math.sin(ang)*.3,mo)
				if a>.05 then
					for i=1,GFX.rate(x,"wisp"..gi,18) do
						GFX.add({kind=1,p=p-x.u*(size*1.2),v=GFX.rdir(x)*(30*S)-x.u*(40*S),life=GFX.rand(.3,.6),
							s0=size*.35,s1=2*S,ramp={{.7,1,.85},{.3,.6,.5}},a=.6*a})
					end
				end
			end
		end
		if GFX.once(x,"burst",TB) then
			GFX.blast(x,o,GFX_PAL_SPIRIT,1.5)
			GFX.shock(x,o,(x.r+x.u):getSafeNormal(),x.f,560*S,10*S,GFX_PAL_SPIRIT.ring2,1.1)
			for i=1,GFX.n(x,22) do
				local dir=(GFX.rdir(x,.5)+x.u*.4):getSafeNormal()
				local bs=GFX.rand(24,38)*S
				GFX.add({kind=5,p=o,v=dir*(GFX.rand(400,900)*S),life=GFX.rand(1.4,2),s0=bs,s1=bs,ramp={{1,1,1}},
					drag=.8,fl=GFX.rand(20,28),fin=.02,fp=3})
			end
			for i=1,GFX.n(x,40) do
				local dir=GFX.rdir(x,.8)
				GFX.add({kind=1,p=o+dir*(GFX.rand(0,60)*S),v=dir*(GFX.rand(200,600)*S),life=GFX.rand(.6,1.1),
					s0=GFX.rand(40,60)*S,s1=GFX.rand(100,150)*S,ramp=GFX_GHOSTFIRE,drag=2.8,grav=-120*S,fin=.02,
					fp=1.5,spin=GFX.rand(-1,1)})
			end
		end
	end,
}

-- 11: GUACWARD ----------------------------------------------------------------------------------
-- An avocado walks in, stops, and does the awkward look-left, look-right stare with its brows up
-- and a sweat drop while GUACWARD pops in letter by letter. Then its pit rockets out of its belly
-- and explodes into guacamole, chips and salsa, and it does a happy little dance.
GFX_PAL_GUAC={flash={.9,1,.7},ring={.5,.9,.15},ring2={.9,.95,.5},light={.5,1,.2},
	spark={{1,1,.8},{.7,1,.3},{.3,.6,.05}},
	fire={{1,1,.85},{.65,.95,.25},{.3,.6,.08},{.05,.12,.02}},
	ember={{1,1,.7},{.6,.95,.2},{.25,.5,.05}},
	smoke={{.12,.18,.06},{.04,.06,.03}}}

-- simple stroke font on a 4 x 6 grid, only the letters we need
GFX_FONT={
	G={{{4,5},{3,6},{1,6},{0,5},{0,1},{1,0},{3,0},{4,1},{4,3},{2,3}}},
	U={{{0,6},{0,1},{1,0},{3,0},{4,1},{4,6}}},
	A={{{0,0},{0,4},{2,6},{4,4},{4,0}},{{0,2.5},{4,2.5}}},
	C={{{4,5},{3,6},{1,6},{0,5},{0,1},{1,0},{3,0},{4,1}}},
	W={{{0,6},{.8,0},{2,4},{3.2,0},{4,6}}},
	R={{{0,0},{0,6},{3,6},{4,5},{4,4},{3,3},{0,3}},{{2,3},{4,0}}},
	D={{{0,0},{0,6},{2.5,6},{4,4.5},{4,1.5},{2.5,0},{0,0}}},
}

-- chunky outlined lettering that pops in one letter at a time, starting at time t0
function GFX.drawWord(x,word,center,us,t0,fill,edge,a)
	local U=x.u
	local R=GFX.flatRight(x)
	local tc=(GFX.cp-center):getSafeNormal()
	local k=GFX.K*.7*a
	local fillC=LinearColor.new(fill[1]*k,fill[2]*k,fill[3]*k,a)
	local edgeC=LinearColor.new(edge[1]*k,edge[2]*k,edge[3]*k,a)
	local n=#word
	for li=1,n do
		local strokes=GFX_FONT[string.sub(word,li,li)]
		local pop=GFX.backOut((x.age-t0-(li-1)*.025*x.D)/(.08*x.D))
		if strokes and pop>0 then
			local lc=center+R*(((li-1)-(n-1)*.5)*5.8*us)+U*(math.sin(x.age*6+li)*.25*us)
			local sc=us*pop
			for layer=1,2 do
				local lcol=(layer==1) and edgeC or fillC
				local w=((layer==1) and .85 or .5)*sc
				local off=tc*((layer==1) and 0 or 2*x.S)
				for _,st in ipairs(strokes) do
					local prev=nil
					for _,v in ipairs(st) do
						local q=lc+R*((v[1]-2)*sc)+U*((v[2]-3)*sc)+off
						if prev then GFX.beam(prev,q,w,lcol) end
						GFX.hex(q,w,0,lcol)
						prev=q
					end
				end
			end
		end
	end
end

-- the avocado, drawn as layered flat shapes facing the camera; returns the belly centre
function GFX.drawAvocado(x,av)
	local S,H,a=x.S,av.H,av.a
	local W=H*.66
	local U=x.u
	local R=GFX.flatRight(x)
	local tc=(GFX.cp-av.pos):getSafeNormal()
	local k=GFX.K*.6*a
	local function col(c) return LinearColor.new(c[1]*k,c[2]*k,c[3]*k,a) end
	local function z(n) return tc*(n*1.5*S) end
	local bc=av.pos+U*(.24*H+H*.5+av.bob)+R*(av.lean*H*.1)
	local limb=col({.16,.42,.08})
	-- legs and feet, behind the body
	for i=1,2 do
		local sd=(i==1) and -1 or 1
		local hip=bc+R*(sd*.17*W)-U*(H*.4)
		local ph=av.walk+((i==1) and 0 or math.pi)
		local foot=av.pos+R*(sd*.2*W)+x.r*(math.sin(ph)*av.stride)+U*(math.max(0,math.cos(ph))*av.lift+av.hop)
		GFX.beam(hip+z(-1),foot+z(-1),.055*H,limb)
		GFX.ellipse(foot+R*(sd*.03*H)+z(-1),R*(.085*H),U*(.04*H),limb)
	end
	-- arms: down at the sides, or up and waving
	for i=1,2 do
		local sd=(i==1) and -1 or 1
		local sh=bc+R*(sd*.36*W)+U*(.02*H)
		local up=av.arms
		local hand=sh+R*(sd*(.2*W+.12*H*up))+U*(-.3*H*(1-up)+.35*H*up+math.sin(x.age*12+i)*.08*H*up)
		GFX.beam(sh+z(-1),hand+z(-1),.05*H,limb)
		GFX.ellipse(hand+z(-1),R*(.05*H),U*(.05*H),limb)
	end
	-- egg-shaped body in three layers: dark rind, green edge, pale flesh
	local function egg(sc,c,zz)
		local pts={}
		local sx,sy=sc*(1+av.squash),sc*(1-av.squash)
		for i=0,20 do
			local th=i/20*6.2832
			pts[#pts+1]=bc+R*(math.sin(th)*W*.5*(1-.24*math.cos(th))*sx)+U*(math.cos(th)*H*.5*sy)+z(zz)
		end
		GFX.fan(bc-U*(H*.08*sy)+z(zz),pts,col(c))
	end
	egg(1,{.13,.38,.06},0)
	egg(.92,{.42,.68,.12},1)
	egg(.82,{.74,.9,.3},2)
	-- belly: glows while the pit is trying to get out, hollow once it's gone
	local belly=bc-U*(H*.14)
	local br=W*.27
	if av.pitOut then
		GFX.ellipse(belly+z(3),R*br,U*(br*1.05),col({.5,.72,.16}))
		GFX.ellipse(belly+U*(br*.1)+z(4),R*(br*.82),U*(br*.86),col({.88,.95,.55}))
	else
		local gl=av.bellyGlow
		GFX.ellipse(belly+z(3),R*br,U*(br*1.05),col({.8+.2*gl,.94,.4+.3*gl}))
		GFX.ellipse(belly+z(4),R*(br*.7),U*(br*.75),col({.86+.14*gl,.97,.5+.3*gl}))
		if gl>0 then GFX.glow(belly+z(5),br*1.6*gl,.6,1,.3,.6*gl*a,x.age,.5) end
	end
	-- face: brown eyes with a highlight, worried brows, and a flat / O / smiling mouth
	local fc=bc+U*(H*.17)
	local dark=col({.28,.13,.05})
	local white=col({1,1,1})
	for i=1,2 do
		local sd=(i==1) and -1 or 1
		local ec=fc+R*(sd*.16*W+av.look*.035*H)
		local big=1+av.surprise*.35
		GFX.ellipse(ec+z(5),R*(.045*H*big),U*(.06*H*big),dark)
		GFX.ellipse(ec-R*(.015*H)+U*(.02*H)+z(6),R*(.014*H),U*(.016*H),white)
		local lift=av.brow*((sd>0) and .05 or .025)*H   -- one brow creeps higher: the awkward look
		GFX.beam(fc+R*(sd*.08*W)+U*(.1*H+lift)+z(5),fc+R*(sd*.26*W)+U*(.085*H+lift+av.brow*.015*H)+z(5),.012*H,dark)
	end
	local mc=fc-U*(.07*H)
	local mouthC=col({.2,.38,.08})
	if av.surprise>.5 then
		GFX.ellipse(mc+z(5),R*(.035*H),U*(.05*H),dark)
	elseif av.smile>0 then
		local prev=nil
		for i=0,6 do
			local t=i/6*2-1
			local q=mc+R*(t*.07*H)+U*((t*t-1)*.03*H*av.smile)+z(5)
			if prev then GFX.beam(prev,q,.008*H,mouthC) end
			prev=q
		end
	else
		GFX.beam(mc-R*(.04*H)+z(5),mc+R*(.04*H)+U*(av.wobble*.01*H)+z(5),.008*H,mouthC)
	end
	if av.sweat>0 then
		local sp=fc+R*(.3*W)+U*(.1*H-av.sweat*.12*H)
		GFX.ellipse(sp+z(6),R*(.018*H),U*(.026*H),LinearColor.new(.5*k,.8*k,k,a*(1-av.sweat*.5)))
	end
	return belly
end

-- spinning brown pit with a highlight
function GFX.drawPit(x,p,rad,spin,a)
	local ax=GFX.bR*math.cos(spin)+GFX.bU*math.sin(spin)
	local ay=GFX.bU*math.cos(spin)-GFX.bR*math.sin(spin)
	local k=GFX.K*.6*a
	GFX.ellipse(p,ax*rad,ay*(rad*.7),LinearColor.new(.42*k,.22*k,.08*k,a))
	GFX.ellipse(p-ax*(.25*rad)+ay*(.2*rad)+(GFX.cp-p):getSafeNormal()*(2*x.S),ax*(rad*.45),ay*(rad*.25),
		LinearColor.new(.7*k,.42*k,.18*k,a))
end

GFX_DEFS[11]={
	init=function(x)
		local S=x.S
		x.av={H=240*S,a=1,bob=0,lean=0,walk=0,stride=0,lift=0,hop=0,arms=0,squash=0,look=0,brow=0,
			surprise=0,smile=0,wobble=0,sweat=0,bellyGlow=0,pitOut=false,pos=x.base}
		x.walkFrom=x.base+x.f*(70*S)-x.r*(380*S)
		x.walkTo=x.base+x.f*(70*S)
	end,
	update=function(x,age,d)
		local D,S,av=x.D,x.S,x.av
		local H=av.H
		local T_WALK,T_PIT,T_POP=.3*D,.58*D,.7*D
		-- walk in from the side
		local wk=goalFxSmooth(age/T_WALK)
		av.pos=x.walkFrom+(x.walkTo-x.walkFrom)*wk
		av.walk=(x.walkTo-x.walkFrom):length()*wk/(H*.28)*math.pi
		local stepping=1-goalFxSmooth((age-(T_WALK-.05*D))/(.05*D))
		av.stride=.1*H*stepping
		av.lift=.06*H*stepping
		av.lean=.08*stepping
		local bob=math.abs(math.sin(av.walk))*.035*H*stepping
		-- the awkward pause: look left, look right, stare, brows up, sweat
		local look=0
		if age>.33*D and age<.4*D then look=-1 elseif age>=.4*D and age<.47*D then look=1 end
		av.look=av.look+(look-av.look)*math.min(1,d*14)
		av.brow=goalFxSmooth((age-.34*D)/(.06*D))
		av.wobble=math.sin(age*9)*goalFxSmooth((age-.4*D)/(.05*D))
		av.sweat=(age>.42*D and age<T_PIT) and math.clamp((age-.42*D)/(.14*D),0,1) or 0
		-- the pit wants out
		av.bellyGlow=(age<T_PIT) and goalFxSmooth((age-.5*D)/(.08*D)) or 0
		av.squash=(age>.5*D and age<T_PIT) and math.sin(age*40)*.03*av.bellyGlow or 0
		av.surprise=(age>T_PIT and age<.8*D) and 1 or 0
		av.pitOut=age>=T_PIT
		-- hop when it blows, then a happy little dance
		av.hop=0
		if age>T_POP and age<T_POP+.1*D then av.hop=math.sin((age-T_POP)/(.1*D)*math.pi)*.25*H end
		if age>.8*D then
			av.smile=1
			av.arms=goalFxSmooth((age-.8*D)/(.04*D))
			av.hop=math.abs(math.sin((age-.8*D)*9))*.08*H
		else
			av.smile=0
			av.arms=(age>T_POP) and goalFxSmooth((age-T_POP)/(.04*D))*.7 or 0
		end
		av.bob=bob+av.hop
		av.a=1-goalFxSmooth((age-.93*D)/(.07*D))
		if av.a<=.01 then return end
		local belly=GFX.drawAvocado(x,av)
		if age>.36*D then
			GFX.drawWord(x,"GUACWARD",av.pos+x.u*(.54*H)+(GFX.cp-av.pos):getSafeNormal()*(35*S),9*S,.36*D,
				{.62,.9,.2},{.1,.3,.04},av.a)
		end
		if GFX.once(x,"popout",T_PIT) then
			GFX.flashAt(x,belly,120*S,{.9,1,.6},.3)
			for i=1,GFX.n(x,20) do
				local dir=(GFX.rdir(x)+x.u*.8):getSafeNormal()
				GFX.add({kind=4,quad=true,p=belly,v=dir*(GFX.rand(250,600)*S),life=GFX.rand(.8,1.2),s0=6*S,s1=4*S,
					ramp={{.6,.85,.2}},grav=900*S,drag=.6,spin=GFX.rand(6,12),op=1,emis=.8,fin=.001,fp=.5})
			end
		end
		if age>=T_PIT and age<T_POP then
			-- the pit rockets up out of the belly
			local t=(age-T_PIT)/(T_POP-T_PIT)
			local p=belly+x.u*(goalFxEaseOut(t)*360*S)+GFX.bR*(math.sin(t*9)*18*S)+(GFX.cp-belly):getSafeNormal()*(30*S)
			x.pitPos=p
			GFX.drawPit(x,p,.2*H*(1+.3*t),age*14,1)
			for i=1,GFX.rate(x,"pittrail",150) do
				GFX.add({kind=1,p=p,v=GFX.rdir(x)*(GFX.rand(40,120)*S)-x.u*(150*S),life=GFX.rand(.3,.5),
					s0=GFX.rand(8,14)*S,s1=2*S,ramp=GFX_PAL_GUAC.ember,grav=200*S,drag=1,tw=18})
			end
		end
		if GFX.once(x,"guac",T_POP) then
			local p=x.pitPos or (x.walkTo+x.u*(500*S))
			GFX.blast(x,p,GFX_PAL_GUAC,1.5)
			GFX.shock(x,p,GFX.bR,GFX.bU,520*S,14*S,{.6,1,.25},1)
			for i=1,GFX.n(x,50) do
				-- guacamole chunks
				local dir=GFX.rdir(x,.8):getSafeNormal()
				local sz=GFX.rand(12,26)*S
				GFX.add({kind=4,quad=GFX.rand()<.5,p=p,v=(dir+x.u*.3)*(GFX.rand(400,1000)*S),life=GFX.rand(1.3,2),
					s0=sz,s1=sz*.8,ramp={{.55,.8,.18},{.4,.65,.1}},grav=800*S,drag=.6,spin=GFX.rand(4,10),op=1,emis=.8,
					fin=.001,fp=.5})
			end
			for i=1,GFX.n(x,24) do
				-- tortilla chips
				local dir=GFX.rdir(x,.8):getSafeNormal()
				local sz=GFX.rand(22,34)*S
				GFX.add({kind=4,p=p,v=(dir+x.u*.4)*(GFX.rand(400,900)*S),life=GFX.rand(1.4,2),s0=sz,s1=sz,
					ramp={{1,.8,.35}},grav=700*S,drag=.7,spin=GFX.rand(3,8),op=1,emis=.8,fin=.001,fp=.5})
			end
			for i=1,GFX.n(x,24) do
				-- tomato and onion bits
				local dir=GFX.rdir(x,.8):getSafeNormal()
				GFX.add({kind=4,quad=true,p=p,v=(dir+x.u*.4)*(GFX.rand(300,800)*S),life=GFX.rand(1.2,1.8),
					s0=GFX.rand(5,8)*S,s1=4*S,ramp={(i%2==0) and {1,.2,.12} or {1,1,.9}},grav=800*S,drag=.6,
					spin=GFX.rand(8,16),op=1,emis=.85,fin=.001,fp=.5})
			end
		end
	end,
}

-- 12: DEATH NOTE (fan tribute, original lettering) --------------------------------------------
-- The scene dims to a spotlight and vignette. A plain matte-black notebook with a pale gothic
-- title (original broad-nib lettering) rises out of the goal in swirling smoke and turns to face
-- the camera. Its cover creaks open as shadow wisps curl out, a few blank aged pages flip past
-- (bending as they turn) and slow down to settle. A floating fountain pen writes the scorer's name
-- stroke by stroke in messy, bleeding ink, lifts off with a flourish, and the name pulses red
-- once. Then the book and pen crumble from the edges inward into ash and embers, and the name is
-- the last thing to fade. Everything it changes (post-process, lights) is put back afterwards.
--
--   DeathNote.play("Name")   play it by hand (uses the selected arena's goal)
--   DEATHNOTE_TIMING         every timing, in seconds
--   DeathNote.onSound        optional function(event) for sound: "drone" (cover opens),
--                            "rustle" (each page), "scratch" (pen starts), "whoosh" (crumble).
--                            The scripting API has no sound playback, so this is a hook only.
DEATHNOTE_TIMING={
	rise=.7,       -- notebook rises out of the goal and turns to face the camera
	open=.45,      -- cover creaks open
	flips=4,       -- pages that flip past (3-5 looks best)
	flipTime=.15,  -- first page flip; each later page turns a little slower
	settle=.25,    -- pause on the blank page while the pen flies in
	write=1.05,    -- pen writes the name
	lift=.3,       -- pen lifts off with a flourish
	glow=.4,       -- the name pulses red
	hold=.15,      -- beat before it crumbles
	crumble=.9,    -- book and pen crumble to ash (the name fades last)
	dimEV=1.2,     -- how far the scene is dimmed, in exposure stops
	vignette=.9,   -- vignette strength while it plays (0..1)
}
DN_INK={.03,.02,.02}
DN_BLOOD={.42,.05,.04}
DN_BONE={.86,.82,.72}
DN_LEATHER={.05,.045,.045}
DN_LINING={.13,.1,.09}

DeathNote={onSound=nil}

function DeathNote.sound(ev)
	if DeathNote.onSound then pcall(DeathNote.onSound,ev) end
end

-- plays the Death Note celebration for scorerName; cleans itself up when it finishes
function DeathNote.play(scorerName,goal)
	if not selectedArena then return false end
	goalFx.active=true
	goalFx.preview=false
	goalFx.typeOverride=GFX_DEATHNOTE
	goalFx.scorerName=scorerName
	goalFx.goal=goal or goalFx.goal or selectedArena.away.goal
	goalFx.startTime=totalTime
	return true
end

-- handwriting stroke font on a 4 x 6 grid (letters, digits and common name punctuation)
GFX_HAND={
	A={{{0,0},{2,6},{4,0}},{{1,2.5},{3,2.5}}},
	B={{{0,0},{0,6},{3,6},{4,5},{3,3.2},{0,3.2}},{{3,3.2},{4,2},{4,1},{3,0},{0,0}}},
	C={{{4,5},{3,6},{1,6},{0,5},{0,1},{1,0},{3,0},{4,1}}},
	D={{{0,0},{0,6},{2.5,6},{4,4.5},{4,1.5},{2.5,0},{0,0}}},
	E={{{4,6},{0,6},{0,0},{4,0}},{{0,3},{3,3}}},
	F={{{4,6},{0,6},{0,0}},{{0,3},{3,3}}},
	G={{{4,5},{3,6},{1,6},{0,5},{0,1},{1,0},{3,0},{4,1},{4,3},{2,3}}},
	H={{{0,0},{0,6}},{{4,0},{4,6}},{{0,3},{4,3}}},
	I={{{1,6},{3,6}},{{2,6},{2,0}},{{1,0},{3,0}}},
	J={{{1,6},{4,6}},{{3,6},{3,1},{2,0},{1,0},{0,1}}},
	K={{{0,0},{0,6}},{{4,6},{0,2.5}},{{1.3,3.5},{4,0}}},
	L={{{0,6},{0,0},{4,0}}},
	M={{{0,0},{0,6},{2,3},{4,6},{4,0}}},
	N={{{0,0},{0,6},{4,0},{4,6}}},
	O={{{1,0},{0,1},{0,5},{1,6},{3,6},{4,5},{4,1},{3,0},{1,0}}},
	P={{{0,0},{0,6},{3,6},{4,5},{4,4},{3,3},{0,3}}},
	Q={{{1,0},{0,1},{0,5},{1,6},{3,6},{4,5},{4,1},{3,0},{1,0}},{{2.5,1.5},{4.2,-.3}}},
	R={{{0,0},{0,6},{3,6},{4,5},{4,4},{3,3},{0,3}},{{2,3},{4,0}}},
	S={{{4,5},{3,6},{1,6},{0,5},{0,4},{1,3},{3,3},{4,2},{4,1},{3,0},{1,0},{0,1}}},
	T={{{0,6},{4,6}},{{2,6},{2,0}}},
	U={{{0,6},{0,1},{1,0},{3,0},{4,1},{4,6}}},
	V={{{0,6},{2,0},{4,6}}},
	W={{{0,6},{.8,0},{2,4},{3.2,0},{4,6}}},
	X={{{0,6},{4,0}},{{4,6},{0,0}}},
	Y={{{0,6},{2,3},{4,6}},{{2,3},{2,0}}},
	Z={{{0,6},{4,6},{0,0},{4,0}}},
	["0"]={{{1,0},{0,1},{0,5},{1,6},{3,6},{4,5},{4,1},{3,0},{1,0}},{{3.5,5},{.5,1}}},
	["1"]={{{1,5},{2,6},{2,0}},{{1,0},{3,0}}},
	["2"]={{{0,5},{1,6},{3,6},{4,5},{4,4},{0,0},{4,0}}},
	["3"]={{{0,5},{1,6},{3,6},{4,5},{4,4},{3,3},{1.5,3}},{{3,3},{4,2},{4,1},{3,0},{1,0},{0,1}}},
	["4"]={{{3,0},{3,6},{0,2},{4,2}}},
	["5"]={{{4,6},{0,6},{0,3.5},{3,3.5},{4,2.5},{4,1},{3,0},{0,0}}},
	["6"]={{{4,5},{3,6},{1,6},{0,5},{0,1},{1,0},{3,0},{4,1},{4,2},{3,3},{0,3}}},
	["7"]={{{0,6},{4,6},{1.5,0}}},
	["8"]={{{1,3},{0,4},{0,5},{1,6},{3,6},{4,5},{4,4},{3,3},{1,3},{0,2},{0,1},{1,0},{3,0},{4,1},{4,2},{3,3}}},
	["9"]={{{4,3},{1,3},{0,4},{0,5},{1,6},{3,6},{4,5},{4,1},{3,0},{1,0}}},
	["."]={{{1.8,0},{2.2,.4}}},
	["_"]={{{0,-.5},{4,-.5}}},
	["-"]={{{1,3},{3,3}}},
	["'"]={{{2,6},{1.7,4.8}}},
	["!"]={{{2,6},{2,1.6}},{{2,.3},{2,0}}},
	["?"]={{{0,5},{1,6},{3,6},{4,5},{4,4},{2,2.5},{2,1.5}},{{2,.3},{2,0}}},
	[","]={{{2.2,.5},{1.6,-.8}}},
}

-- total timeline (seconds from the start) built from DEATHNOTE_TIMING
function GFX.dnTimeline()
	local T=DEATHNOTE_TIMING
	local tl={rise1=T.rise,open0=T.rise,open1=T.rise+T.open,flips={}}
	local t=tl.open1-T.open*.25
	local n=math.clamp(math.floor(T.flips or 4),0,8)
	for i=1,n do
		local dur=T.flipTime*(1+(i-1)*.35)   -- each page turns a little slower: it "settles"
		tl.flips[i]={t0=t,t1=t+dur}
		t=t+dur*.8
	end
	if n>0 then t=tl.flips[n].t1 else t=tl.open1 end
	tl.write0=t+T.settle
	tl.write1=tl.write0+T.write
	tl.lift1=tl.write1+T.lift
	tl.glow0=tl.lift1-T.lift*.4
	tl.glow1=tl.glow0+T.glow
	tl.crumble0=tl.glow1+T.hold
	tl.crumble1=tl.crumble0+T.crumble
	tl.D=tl.crumble1+.15
	return tl
end

-- lays the name out on the right-hand page as messy handwriting: slanted, jittered, with a
-- wobbly baseline, scaled down for long names, plus an underline swash. Returns the strokes
-- (page coordinates, each with its start along the total ink length), total length and letter unit.
function GFX.dnLayout(x,name)
	local W,H=x.W,x.H
	local up=string.upper(name)
	local chars={}
	for i=1,#up do chars[#chars+1]=string.sub(up,i,i) end
	local count=math.max(1,#chars)
	local u=math.min(H*.13/6,W*.84/(count*5.6))
	local x0=W*.5-(count*5.6-1.6)*u*.5
	local y0=-3*u
	local strokes={}
	local L=0
	local function add(pts)
		local len=0
		for k=2,#pts do len=len+math.sqrt((pts[k][1]-pts[k-1][1])^2+(pts[k][2]-pts[k-1][2])^2) end
		strokes[#strokes+1]={pts=pts,len=len,start=L}
		L=L+len+u*1.5   -- the pen needs a moment to hop to the next stroke
	end
	local lastX=x0
	for ci,ch in ipairs(chars) do
		local g=GFX_HAND[ch]
		if g then
			local ox=x0+(ci-1)*5.6*u
			local tilt=(goalFxNoise(ci*3.7+x.seed)-.5)*.12
			local base=(goalFxNoise(ci*5.1+x.seed)-.5)*.6*u
			for si,st in ipairs(g) do
				local pts={}
				for vi,v in ipairs(st) do
					local gx=v[1]+(goalFxNoise(ci*13.1+si*3.3+vi*1.7+x.seed)-.5)*.5
					local gy=v[2]+(goalFxNoise(ci*7.9+si*5.1+vi*2.3+x.seed)-.5)*.5
					gx=gx+gy*.22+(gy-3)*tilt
					pts[#pts+1]={ox+gx*u,y0+gy*u+base}
				end
				add(pts)
			end
			lastX=ox+4.5*u
		end
	end
	-- underline swash, written last, curling back under the name
	local sw={}
	for k=0,8 do
		local t=k/8
		sw[#sw+1]={lastX-(lastX-x0+u)*t,y0-u*(1.2+math.sin(t*math.pi)*.8)+u*.5*t*t}
	end
	add(sw)
	return strokes,math.max(L,1),u
end

-- quad in book space: x across, y up, z toward the camera
function GFX.dnQuad(b,x0,y0,x1,y1,z,lc)
	local p00=b.C+b.R*x0+b.V*y0+b.N*z
	local p10=b.C+b.R*x1+b.V*y0+b.N*z
	local p11=b.C+b.R*x1+b.V*y1+b.N*z
	local p01=b.C+b.R*x0+b.V*y1+b.N*z
	WorldDraw.drawTriangle(p00,p10,p11,lc,0)
	WorldDraw.drawTriangle(p00,p11,p01,lc,0)
end

-- line lying flat on a surface with normal n, half width w
function GFX.flatBeam(p,q,w,n,lc)
	local side=Vec3.cross(q-p,n)
	if side:length()<.0001 then return end
	side=side:getSafeNormal()*w
	WorldDraw.drawTriangle(p+side,p-side,q-side,lc,0)
	WorldDraw.drawTriangle(p+side,q-side,q+side,lc,0)
end

-- one page as a strip of columns from the spine outward (flat or curling), with its faint rows
-- of names. keep(lx,ly), when given, hides writing that has already burnt away.
function GFX.dnPage(x,b,cols,scrib,kk,keep,side)
	local V,H=b.V,x.H
	local cp=GFX.cp
	local n=#cols-1
	local hv=V*(H*.5)
	-- (while crumbling, the paper itself is drawn by the cell grid; only the writing is drawn here)
	for k=1,keep and 0 or n do
		local a0,a1=cols[k],cols[k+1]
		local nrm=Vec3.cross(a1-a0,V):getSafeNormal()
		local sh=(.6+.4*math.abs(Vec3.dot(nrm,(cp-a0):getSafeNormal())))*kk
		local lc=LinearColor.new(DN_BONE[1]*sh,DN_BONE[2]*sh,DN_BONE[3]*sh,1)
		WorldDraw.drawTriangle(a0-hv,a0+hv,a1+hv,lc,0)
		WorldDraw.drawTriangle(a0-hv,a1+hv,a1-hv,lc,0)
	end
	if not scrib then return end
	local ik=kk*.42
	for _,row in ipairs(scrib) do
		local prev,prevOk=nil,false
		for _,pt in ipairs(row) do
			local f=pt[1]*n
			local i=math.min(n-1,math.floor(f))
			local a0,a1=cols[i+1],cols[i+2]
			local base=a0+(a1-a0)*(f-i)
			local nrm=Vec3.cross(a1-a0,V):getSafeNormal()
			if Vec3.dot(nrm,cp-base)<0 then nrm=nrm*-1 end
			local q=base+V*(pt[2]*H)+nrm*(.4*x.S)
			local ok=(not keep) or keep(side,pt[1]*x.W,pt[2]*H)
			if prev and ok and prevOk then WorldDraw.drawLine(prev,q,.34*ik,.31*ik,.28*ik,1,0) end
			prev,prevOk=q,ok
		end
	end
end

function GFX.dnFlatCols(b,side,z,W)
	return {b.C+b.N*z,b.C+b.R*(side*W)+b.N*z}
end

-- a turning page: theta 0 = lying on the right, pi = lying on the left; the outer edge lags
-- behind the spine so the page bends as it turns
function GFX.dnFlipCols(b,theta,z,W,n)
	local cols={b.C+b.N*z}
	for k=1,n do
		local phi=theta-.9*math.sin(theta)*(k/n)^1.3
		cols[k+1]=cols[k]+(b.R*math.cos(phi)+b.N*math.sin(phi))*(W/n)
	end
	return cols
end

-- the cover title, hand-inked: rough brush strokes that swell in the middle and taper to sharp
-- spiky points, letters slightly crooked on a bouncing baseline, tall narrow capitals (D, N)
-- with smaller letters after them, and a few specks of ink. The letter skeletons are the
-- GFX_HAND shapes; all the roughness is fixed noise, so it looks the same every frame.
-- Pale bone-white on the black cover.
function GFX.dnTitle(x,org,ax,ay,nrm,width,kk)
	local word="DEATH NOTE"
	local caps={[1]=true,[7]=true}   -- D and N are the big capitals
	local tk=kk*.9
	local lc=LinearColor.new(.86*tk,.84*tk,.8*tk,1)
	local lift=nrm*(.6*x.S)
	-- lay out: capitals wider and taller, the rest small and narrow
	local adv={}
	local total=0
	for ci=1,#word do
		local a=(string.sub(word,ci,ci)==" ") and 2.6 or (caps[ci] and 5.4 or 4.2)
		adv[ci]=a
		total=total+a
	end
	local u=width*.9/total
	local cx=width*.5-total*u*.5
	local function N(s) return goalFxNoise(s)-.5 end
	for ci=1,#word do
		local glyph=GFX_HAND[string.sub(word,ci,ci)]
		if glyph then
			local big=caps[ci]
			local sx=(big and .95 or .72)*u
			local sy=(big and 1.55 or 1.05)*u
			local tilt=N(ci*3.3)*.14
			local base=N(ci*5.9)*.5*u+(big and -.2*u or 0)
			local ox=cx+(adv[ci]-4*sx/u)*u*.5
			-- glyph point (gx,gy on the 4x6 grid) -> cover, with a wobble that stays put
			local function G(gx,gy,seed)
				gx=gx+N(seed)*.35
				gy=gy+N(seed+.5)*.35
				gx=gx+(gy-3)*tilt
				return org+ax*(ox+gx*sx)+ay*(gy*sy-3.2*u+base)+lift   -- all letters share one baseline
			end
			for si,st in ipairs(glyph) do
				-- resample the stroke into short pieces so the width can swell and taper
				local pts={}
				for vi,v in ipairs(st) do pts[vi]=G(v[1],v[2],ci*17.1+si*5.3+vi*2.9) end
				local seq={}
				for k=1,#pts-1 do
					for m=0,2 do seq[#seq+1]=pts[k]+(pts[k+1]-pts[k])*(m/3) end
				end
				seq[#seq+1]=pts[#pts]
				local cnt=#seq
				local wMax=(big and .5 or .36)*u*(.85+.3*N(ci*7.7+si))
				for k=1,cnt-1 do
					local t=(k-.5)/(cnt-1)
					local w=wMax*(.25+.75*math.sin(t*math.pi)^.5)*(.8+.4*(goalFxNoise(ci*3.1+si*1.9+k*.77)))
					GFX.flatBeam(seq[k],seq[k+1],w*.5,nrm,lc)
				end
				-- sharp ink tails flicking out past both ends of the stroke
				if cnt>=2 then
					for e=0,1 do
						local tipP=(e==0) and seq[1] or seq[cnt]
						local inP=(e==0) and seq[2] or seq[cnt-1]
						local dir=(tipP-inP):getSafeNormal()
						local side=Vec3.cross(dir,nrm):getSafeNormal()*(wMax*.22)
						local tail=tipP+dir*(u*(.35+.35*goalFxNoise(ci*9.3+si*2.1+e)))
						WorldDraw.drawTriangle(tipP+side,tipP-side,tail,lc,0)
					end
				end
			end
			-- a speck of ink beside some letters
			if goalFxNoise(ci*4.4)>.55 then
				local dp=org+ax*(ox+(2+N(ci*6.6)*5)*sx)+ay*((3+N(ci*8.8)*4)*sy-3.2*u+base)+lift
				GFX.ellipse(dp,ax*(u*.13),ay*(u*.13),lc)
			end
		end
		cx=cx+adv[ci]*u
	end
end

-- the closed / opening book (everything except the crumble)
function GFX.dnBook(x,b,age,kk)
	local W,H,T,S=x.W,x.H,x.T,x.S
	local tl=x.tl
	local ov=4*S
	local cp=GFX.cp
	local leather=LinearColor.new(DN_LEATHER[1]*kk,DN_LEATHER[2]*kk,DN_LEATHER[3]*kk,1)
	-- back cover and the right-hand block of pages with its page-edge sides
	GFX.dnQuad(b,0,-H*.5-ov,W+ov,H*.5+ov,0,leather)
	local ek=kk*.72
	local edge=LinearColor.new(DN_BONE[1]*ek,DN_BONE[2]*ek,DN_BONE[3]*ek*.9,1)
	local function P(lx,ly,lz) return b.C+b.R*lx+b.V*ly+b.N*lz end
	WorldDraw.drawTriangle(P(W,-H*.5,0),P(W,H*.5,0),P(W,H*.5,T),edge,0)
	WorldDraw.drawTriangle(P(W,-H*.5,0),P(W,H*.5,T),P(W,-H*.5,T),edge,0)
	WorldDraw.drawTriangle(P(0,H*.5,0),P(W,H*.5,0),P(W,H*.5,T),edge,0)
	WorldDraw.drawTriangle(P(0,H*.5,0),P(W,H*.5,T),P(0,H*.5,T),edge,0)
	for j=1,3 do
		local z=T*j/4
		WorldDraw.drawLine(P(W+.2*S,-H*.5,z),P(W+.2*S,H*.5,z),.45*ek,.42*ek,.37*ek,1,0)
	end
	-- every page is blank; the name gets written on the right-hand one
	GFX.dnPage(x,b,GFX.dnFlatCols(b,1,T,W),nil,kk)

	-- front cover, creaking open around the spine
	local ok=goalFxSmooth((age-tl.open0)/(tl.open1-tl.open0))
	local creak=math.clamp(ok+math.sin(ok*math.pi*3)*.035*(1-ok),0,1)
	local phi=math.pi*creak
	if ok>.45 then
		-- left side: the blank pages that have already turned
		GFX.dnPage(x,b,GFX.dnFlatCols(b,-1,T*.45,W),nil,kk)
	end
	local hinge=b.C+b.N*((T+1.5*S)*(1-ok))
	local dir=b.R*math.cos(phi)+b.N*math.sin(phi)
	local nC=b.N*math.cos(phi)-b.R*math.sin(phi)
	local hy=b.V*(H*.5+ov)
	local far=hinge+dir*(W+ov)
	local outer=Vec3.dot(nC,cp-hinge)>0
	local cc=outer and DN_LEATHER or DN_LINING
	local clc=LinearColor.new(cc[1]*kk,cc[2]*kk,cc[3]*kk,1)
	WorldDraw.drawTriangle(hinge-hy,hinge+hy,far+hy,clc,0)
	WorldDraw.drawTriangle(hinge-hy,far+hy,far-hy,clc,0)
	-- the cover's thickness: a slightly lighter bevel round the edge so it reads as a solid board
	local bv=kk*1.6
	local bev=nC*(-1.5*S)
	WorldDraw.drawLine(hinge+hy,far+hy,.09*bv,.085*bv,.085*bv,2.5,0)
	WorldDraw.drawLine(far+hy,far-hy,.09*bv,.085*bv,.085*bv,2.5,0)
	WorldDraw.drawLine(far-hy,hinge-hy,.09*bv,.085*bv,.085*bv,2.5,0)
	WorldDraw.drawLine(hinge+hy+bev,far+hy+bev,.06*bv,.055*bv,.055*bv,2.5,0)
	WorldDraw.drawLine(far+hy+bev,far-hy+bev,.06*bv,.055*bv,.055*bv,2.5,0)
	if outer then
		-- plain matte black cover with the title near the top
		GFX.dnTitle(x,hinge+b.V*(H*.3)+nC*(.5*S),dir,b.V,nC,W+ov,kk)
	end

	-- pages flipping past
	local cn=({5,6,8,10})[x.qi]
	for i,fp in ipairs(tl.flips) do
		if age>=fp.t0 and age<fp.t1 then
			local th=math.pi*goalFxSmooth((age-fp.t0)/(fp.t1-fp.t0))
			GFX.dnPage(x,b,GFX.dnFlipCols(b,th,T+.5*S,W,cn),nil,kk)
		end
	end
end

-- book crumbling from each page's edges inward: a grid of cells that burn at the edge (ember
-- glow) and then break off into ash. c runs past 1 so the name can fade after the paper is gone.
function GFX.dnCellVal(x,side,lx,ly)
	local W,H,ov=x.W,x.H,4*x.S
	local nx=x.cellN
	local ny=nx+2
	local w=W+ov
	local i=math.clamp(math.floor(lx/w*nx),0,nx-1)
	local j=math.clamp(math.floor((ly+H*.5+ov)/(H+2*ov)*ny),0,ny-1)
	local cx=(i+.5)/nx*w
	local cy=-(H*.5+ov)+(j+.5)/ny*(H+2*ov)
	local e=math.min(math.min(cx,w-cx)/(w*.5),(H*.5+ov-math.abs(cy))/(H*.5+ov))
	return e+(goalFxNoise(side*31+i*7.3+j*3.1+x.seed)-.5)*.3,i,j,cx,cy
end

function GFX.dnCrumble(x,b,c,kk)
	local W,H,T,S=x.W,x.H,x.T,x.S
	local ov=4*S
	local nx=x.cellN
	local ny=nx+2
	local w=W+ov
	local ck=GFX.K*1.3
	local ember=LinearColor.new(1*ck,.35*ck,.05*ck,1)
	for side=-1,1,2 do
		local cov=(side>0) and DN_LEATHER or DN_LINING
		local covLc=LinearColor.new(cov[1]*kk,cov[2]*kk,cov[3]*kk,1)
		local pz=(side>0) and T or T*.45
		for i=0,nx-1 do
			for j=0,ny-1 do
				local x0,x1=i/nx*w,(i+1)/nx*w
				local y0=-(H*.5+ov)+j/ny*(H+2*ov)
				local y1=y0+(H+2*ov)/ny
				local val,_,_,cx,cy=GFX.dnCellVal(x,side,(x0+x1)*.5,(y0+y1)*.5)
				local key=side*1000+i*50+j
				if val>c then
					local burning=val-c<.07
					GFX.dnQuad(b,side*x0,y0,side*x1,y1,0,burning and ember or covLc)
					-- the paper part of this cell, clipped to the page
					local px0,px1=math.max(x0,0),math.min(x1,W)
					local py0,py1=math.max(y0,-H*.5),math.min(y1,H*.5)
					if px1>px0 and py1>py0 then
						local lc=ember
						if not burning then
							lc=LinearColor.new(DN_BONE[1]*kk,DN_BONE[2]*kk,DN_BONE[3]*kk,1)
						end
						GFX.dnQuad(b,side*px0,py0,side*px1,py1,pz,lc)
					end
					if burning and GFX.rand()<.04 then
						local p=b.C+b.R*(side*cx)+b.V*cy+b.N*(pz+2*S)
						GFX.add({kind=1,p=p,v=b.V*(GFX.rand(40,120)*S)+b.N*(GFX.rand(10,50)*S),life=GFX.rand(.5,.9),
							s0=GFX.rand(3,5)*S,s1=1*S,ramp={{1,.7,.3},{1,.3,.05},{.4,.05,.02}},drag=.8,grav=-40*S,tw=GFX.rand(12,22)})
					end
				elseif not x.gone[key] then
					-- breaks off into drifting ash flakes and a couple of embers
					x.gone[key]=true
					local p=b.C+b.R*(side*cx)+b.V*cy+b.N*(pz+S)
					for k=1,GFX.n(x,3) do
						local sz=GFX.rand(3,7)*S
						GFX.add({kind=4,quad=true,p=p+b.R*(GFX.rand(-8,8)*S)+b.V*(GFX.rand(-8,8)*S),
							v=b.V*(GFX.rand(40,140)*S)+b.N*(GFX.rand(20,70)*S)+b.R*(GFX.rand(-50,50)*S),
							life=GFX.rand(1.2,2),s0=sz,s1=sz*.5,ramp={{.1,.09,.09},{.05,.045,.045}},grav=-35*S,drag=.9,
							spin=GFX.rand(3,8),op=.9,emis=.6,fin=.001,fp=1})
					end
					GFX.add({kind=1,p=p,v=b.V*(GFX.rand(60,160)*S)+b.N*(GFX.rand(10,60)*S),life=GFX.rand(.6,1.1),
						s0=GFX.rand(3,6)*S,s1=1*S,ramp={{1,.7,.3},{1,.3,.05},{.4,.05,.02}},drag=.8,grav=-40*S,tw=GFX.rand(10,20)})
				end
			end
		end
	end
end

-- page coords (lx,ly) on the right-hand page -> world point just above the paper
function GFX.dnPagePos(x,b,lx,ly,lift)
	return b.C+b.R*lx+b.V*ly+b.N*(x.T+.6*x.S+(lift or 0))
end

-- the name in bleeding ink, written up to length w; returns where the pen tip is and whether
-- it is up off the paper (hopping between strokes)
function GFX.dnDrawName(x,b,w,r,g,bb,a)
	local u=x.nameU
	local core=LinearColor.new(r*a,g*a,bb*a,a)
	local bleed=LinearColor.new((r*.6+.08)*a,r*.15*a,r*.15*a,a*.45)
	local tipX,tipY=nil,nil
	local lifted=true
	local strokes=x.strokes
	for si,st in ipairs(strokes) do
		local done=w-st.start
		if done<=0 then break end
		local pts=st.pts
		GFX.ellipse(GFX.dnPagePos(x,b,pts[1][1],pts[1][2],.1*x.S),b.R*(u*.22),b.V*(u*.22),core)
		local acc=0
		for k=2,#pts do
			if acc>=done then break end
			local ax,ay,bx,by=pts[k-1][1],pts[k-1][2],pts[k][1],pts[k][2]
			local sl=math.sqrt((bx-ax)^2+(by-ay)^2)
			local f=math.min(1,(done-acc)/math.max(sl,1e-4))
			local ex,ey=ax+(bx-ax)*f,ay+(by-ay)*f
			local p,q=GFX.dnPagePos(x,b,ax,ay),GFX.dnPagePos(x,b,ex,ey)
			GFX.flatBeam(p,q,u*.34,b.N,bleed)
			GFX.flatBeam(p+b.N*(.15*x.S),q+b.N*(.15*x.S),u*.17,b.N,core)
			tipX,tipY=ex,ey
			acc=acc+sl
		end
		lifted=done>st.len
		if lifted and strokes[si+1] and w<strokes[si+1].start then
			-- hopping to the next stroke
			local nx=strokes[si+1].pts[1]
			local h=(done-st.len)/math.max(strokes[si+1].start-st.start-st.len,1e-4)
			tipX=tipX+(nx[1]-tipX)*h
			tipY=tipY+(nx[2]-tipY)*h
		end
	end
	return tipX,tipY,lifted
end

-- floating black fountain pen: gold nib, glossy black barrel, silver band and clip.
-- cut 0..1 crumbles it from both ends inward.
function GFX.dnPen(x,tip,dir,nrm,cut,kk)
	local S=x.S
	local e1=Vec3.cross(dir,nrm)
	if e1:length()<.01 then e1=GFX.bR else e1=e1:getSafeNormal() end
	local e2=Vec3.cross(dir,e1)
	local L=x.lightDir
	local len=85
	local lo,hi=len*cut*.5,len*(1-cut*.5)
	if hi<=lo then return end
	local segs={
		{0,0,14,3.2,{.85,.7,.38},.9},       -- gold nib
		{14,3.4,30,3.4,{.05,.05,.055},.5},   -- grip
		{30,3.9,33,3.9,{.75,.78,.8},.9},     -- silver band
		{33,3.6,78,3.6,{.04,.035,.04},.6},   -- barrel
		{78,3.6,85,.5,{.04,.035,.04},.6},    -- end cap
	}
	for _,sg in ipairs(segs) do
		local s0,s1=math.max(sg[1],lo),math.min(sg[3],hi)
		if s1>s0 then
			local function rad(s) return sg[2]+(sg[4]-sg[2])*(s-sg[1])/(sg[3]-sg[1]) end
			local r0,r1=rad(s0)*S,rad(s1)*S
			local col,gloss=sg[5],sg[6]
			for j=0,5 do
				local t0,t1=j/6*6.2832,(j+1)/6*6.2832
				local d0=e1*math.cos(t0)+e2*math.sin(t0)
				local d1=e1*math.cos(t1)+e2*math.sin(t1)
				local nf=(d0+d1):getSafeNormal()
				local lit=math.max(0,Vec3.dot(nf,L))
				local spec=(lit^8)*gloss
				local k=kk*(.35+.65*lit)
				local lc=LinearColor.new((col[1]*k+spec*kk),(col[2]*k+spec*kk),(col[3]*k+spec*kk),1)
				local a0,a1=tip+dir*(s0*S)+d0*r0,tip+dir*(s0*S)+d1*r0
				local b0,b1=tip+dir*(s1*S)+d0*r1,tip+dir*(s1*S)+d1*r1
				WorldDraw.drawTriangle(a0,a1,b1,lc,0)
				WorldDraw.drawTriangle(a0,b1,b0,lc,0)
			end
		end
	end
	if lo<40 and hi>70 then
		local ck=kk*1.4
		WorldDraw.drawLine(tip+dir*(40*S)+e2*(4.4*S),tip+dir*(70*S)+e2*(4.4*S),.7*ck,.72*ck,.75*ck,2,0)
	end
	if lo<2 then
		WorldDraw.drawLine(tip+dir*(2*S)+e2*(1*S),tip+dir*(11*S)+e2*(2.6*S),.05,.04,.03,1,0)
	end
end

GFX_DEFS[12]={
	duration=function() return GFX.dnTimeline().D end,
	init=function(x)
		local S=x.S
		x.tl=GFX.dnTimeline()
		x.W,x.H,x.T=125*S,170*S,9*S
		x.seed=GFX.rand(0,100)
		x.cellN=({5,6,7,8})[x.qi]
		x.bookC=x.o+x.u*(25*S)
		x.riseDrop=Vec3.dot(x.bookC-x.base,x.u)+x.H*.7
		x.name=goalFx.scorerName
		if not x.name or x.name=="" then x.name="???" end
		x.strokes,x.inkLen,x.nameU=GFX.dnLayout(x,x.name)
		x.gone={}
		x.lightDir=(x.u*.7+x.f*.7):getSafeNormal()
		-- remember the player's own post-process so it can be put back exactly
		x.pp=nil
		if config.deathNoteDim~=false then
			pcall(function()
				x.pp={bias=postProcessSettings.autoExposureBias,vig=postProcessSettings.vignetteIntensity}
			end)
		end
	end,
	cleanup=function(x)
		if x.pp then
			pcall(function()
				postProcessSettings.autoExposureBias=x.pp.bias
				postProcessSettings.vignetteIntensity=x.pp.vig
			end)
		end
	end,
	update=function(x,age,d)
		local S,tl,T=x.S,x.tl,DEATHNOTE_TIMING
		local W,H=x.W,x.H

		-- dim the scene + vignette, and brighten the book by the same amount so it stays lit
		local dl=goalFxSmooth(age/.5)*(1-goalFxSmooth((age-(tl.D-.5))/.5))
		local comp=1
		if x.pp then
			pcall(function()
				postProcessSettings.autoExposureBias=x.pp.bias-T.dimEV*dl
				postProcessSettings.vignetteIntensity=x.pp.vig+(T.vignette-x.pp.vig)*dl
			end)
			comp=2^(T.dimEV*dl)
		end
		local kk=GFX.K*.42*comp

		-- book frame: rises from inside the goal, turning from edge-on to face the camera,
		-- leaning back a little like it rests on a lectern; closed it sits centred, then the
		-- spine slides to the middle as it opens
		local rk=goalFxEaseOut(age/tl.rise1)
		local C=x.bookC-x.u*((1-rk)*x.riseDrop)+x.u*(math.sin(age*1.7)*3*S)
		local U=x.u
		local Fv=GFX.cp-C
		local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
		local R0=GFX.flatRight(x)
		local yaw=(1-rk)*1.5
		local R=R0*math.cos(yaw)+F*math.sin(yaw)
		local Ny=F*math.cos(yaw)-R0*math.sin(yaw)
		local V=U*math.cos(.2)-Ny*math.sin(.2)
		local N=Ny*math.cos(.2)+U*math.sin(.2)
		local ok=goalFxSmooth((age-tl.open0)/(tl.open1-tl.open0))
		local b={C=C-R*(W*.5*(1-ok)),R=R,V=V,N=N}

		if GFX.once(x,"spot",0) then
			GFX.light(x,C+V*(H*1.6)+N*(H*1.1),{1,.92,.8},9000,1600*S,.4,tl.crumble1-.6,.3)
		end
		-- dim spotlight beam falling on the book
		if dl>.01 then
			local apex=b.C+V*(H*1.7)+N*(H*1.1)
			local ctr=C+N*x.T
			local bk=GFX.K*.5*dl
			local beam=LinearColor.new(bk,.93*bk,.78*bk,.05*dl)
			local prev=nil
			for i=0,18 do
				local th=i/18*6.2832
				local q=ctr+R*(math.cos(th)*W*1.15)+V*(math.sin(th)*H*.7)
				if prev then WorldDraw.drawTriangle(apex,prev,q,beam,0) end
				prev=q
			end
		end

		-- swirling smoke while it rises, and a puff when it arrives
		if age<tl.rise1+.15 then
			for i=1,GFX.rate(x,"smoke",110) do
				local th=GFX.rand(0,6.2832)
				local rr=GFX.rand(70,140)*S
				local radial=R*math.cos(th)+N*math.sin(th)
				local tang=N*math.cos(th)-R*math.sin(th)
				GFX.add({kind=3,p=C+radial*rr+V*(GFX.rand(-H*.6,H*.2)),v=tang*(GFX.rand(150,250)*S)+U*(GFX.rand(60,160)*S),
					life=GFX.rand(1,1.6),s0=30*S,s1=GFX.rand(90,120)*S,ramp={{.07,.06,.07},{.02,.02,.025}},
					op=.55,fin=.15,fp=1.4,drag=1,spin=GFX.rand(-1.5,1.5)})
			end
		end
		if GFX.once(x,"arrive",tl.rise1) then
			for i=1,GFX.n(x,14) do
				local dir=GFX.rdir(x,.7)
				GFX.add({kind=3,p=C+dir*(GFX.rand(20,60)*S),v=dir*(GFX.rand(80,180)*S),life=GFX.rand(1.2,1.8),
					s0=50*S,s1=150*S,ramp={{.06,.05,.06},{.02,.02,.025}},op=.45,fin=.1,drag=1.4,spin=GFX.rand(-1,1)})
			end
		end

		-- sound cues
		if GFX.once(x,"sDrone",tl.open0) then DeathNote.sound("drone") end
		for i,fp in ipairs(tl.flips) do
			if GFX.once(x,"sRustle"..i,fp.t0) then
				DeathNote.sound("rustle")
				for k=1,GFX.n(x,6) do
					GFX.add({kind=1,p=b.C+R*(GFX.rand(.5,1)*W)+V*(GFX.rand(-.5,.5)*H)+N*(x.T+4*S),
						v=N*(GFX.rand(30,90)*S)+V*(GFX.rand(-30,60)*S),life=GFX.rand(.4,.7),s0=2.5*S,s1=1*S,
						ramp={DN_BONE},drag=1.5,tw=GFX.rand(10,20),a=.6})
				end
			end
		end
		if GFX.once(x,"sScratch",tl.write0) then DeathNote.sound("scratch") end
		if GFX.once(x,"sWhoosh",tl.crumble0) then DeathNote.sound("whoosh") end

		-- shadow wisps curling out as the cover opens
		if age>tl.open0 and age<tl.open1+.35 then
			for i=1,GFX.rate(x,"wisp",70) do
				local th=GFX.rand(0,6.2832)
				GFX.add({kind=3,p=b.C+R*(GFX.rand(.1,.9)*W)+V*(GFX.rand(-.4,.4)*H)+N*(x.T+3*S),
					v=N*(GFX.rand(60,140)*S)+V*(GFX.rand(20,80)*S)+(R*math.cos(th)+V*math.sin(th))*(40*S),
					life=GFX.rand(.8,1.3),s0=10*S,s1=GFX.rand(45,70)*S,ramp={{.08,.03,.09},{.02,.01,.03}},op=.5,
					fin=.1,fp=1.5,drag=1.2,spin=GFX.rand(-2.5,2.5)})
			end
		end

		-- the book itself, or its crumbling remains
		local c=-1
		if age>=tl.crumble0 then c=(age-tl.crumble0)/T.crumble*1.25-.05 end
		if c<0 then
			GFX.dnBook(x,b,age,kk)
		else
			GFX.dnCrumble(x,b,c,kk)
		end

		-- the name: written, pulsed red, then the last thing to fade
		local tipX,tipY,lifted=nil,nil,true
		if age>=tl.write0 then
			local w=x.inkLen*math.clamp((age-tl.write0)/(tl.write1-tl.write0),0,1)
			local pulse=0
			if age>tl.glow0 and age<tl.glow1 then pulse=math.sin((age-tl.glow0)/(tl.glow1-tl.glow0)*math.pi) end
			local tint=(age>tl.glow0) and .35 or 0   -- after the pulse the ink stays a dried-blood red
			local ik=comp
			local rk2=GFX.K*1.8*pulse*comp
			local r=DN_INK[1]*ik+(DN_BLOOD[1]-DN_INK[1])*tint*ik+DN_BLOOD[1]*rk2
			local g=DN_INK[2]*ik+(DN_BLOOD[2]-DN_INK[2])*tint*ik+DN_BLOOD[2]*rk2
			local bl=DN_INK[3]*ik+(DN_BLOOD[3]-DN_INK[3])*tint*ik+DN_BLOOD[3]*rk2
			local na=1
			if c>.95 then na=1-goalFxSmooth((c-.95)/.2) end
			if na>.01 then tipX,tipY,lifted=GFX.dnDrawName(x,b,w,r,g,bl,na) end
			if pulse>0 then
				GFX.glow(GFX.dnPagePos(x,b,W*.5,0,2*S),W*.45,.8,.05,.03,.3*pulse,age,.2)
			end
			if GFX.once(x,"redlight",tl.glow0) then
				GFX.light(x,GFX.dnPagePos(x,b,W*.5,0,60*S),{1,.08,.05},15000,900*S,(tl.glow1-tl.glow0)*.4,0,.25)
			end
			if GFX.once(x,"nameAsh",tl.crumble0+T.crumble*.8) then
				-- the name finally breaks up into red-black ash
				for _,st in ipairs(x.strokes) do
					for _,pt in ipairs(st.pts) do
						GFX.add({kind=1,p=GFX.dnPagePos(x,b,pt[1],pt[2],S),v=V*(GFX.rand(40,120)*S)+N*(GFX.rand(10,50)*S),
							life=GFX.rand(.6,1.1),s0=GFX.rand(3,5)*S,s1=1*S,ramp={{.9,.15,.08},{.35,.03,.02},{.05,.02,.02}},
							drag=.8,grav=-40*S,tw=GFX.rand(10,20)})
					end
				end
			end
		end

		-- the pen: flies in, writes, lifts off with a flourish, hovers, then crumbles too
		local penTip=nil
		local enter0=tl.write0-T.settle
		if age>=enter0 and age<tl.crumble1 then
			local first=x.strokes[1] and x.strokes[1].pts[1] or {W*.2,0}
			local last=x.strokes[#x.strokes].pts[#x.strokes[#x.strokes].pts]
			local function flourishPos(t)
				return GFX.dnPagePos(x,b,last[1]+t*W*.35,last[2]+math.sin(t*math.pi)*H*.1+t*H*.15,t*t*45*S)
			end
			if age<tl.write0 then
				local t=goalFxSmooth((age-enter0)/T.settle)
				local from=GFX.dnPagePos(x,b,W*1.5,H*.8,140*S)
				penTip=from+(GFX.dnPagePos(x,b,first[1],first[2],6*S)-from)*t
			elseif age<tl.write1 then
				if tipX then penTip=GFX.dnPagePos(x,b,tipX,tipY,lifted and 5*S or 0) end
			elseif age<tl.lift1 then
				penTip=flourishPos((age-tl.write1)/(tl.lift1-tl.write1))
			else
				penTip=flourishPos(1)+U*(math.sin(age*2.5)*4*S)
			end
			if penTip then
				local dir=(V*.75+N*.5+R*.35+R*(math.sin(age*18)*.04)):getSafeNormal()
				local cut=0
				if c>0 then cut=math.clamp(c/.6,0,1) end
				if cut<1 then
					GFX.dnPen(x,penTip,dir,N,cut,kk)
					if cut>0 then
						for i=1,GFX.rate(x,"penAsh",40) do
							local s=(GFX.rand()<.5) and (85*cut*.5) or (85*(1-cut*.5))
							GFX.add({kind=4,quad=true,p=penTip+dir*(s*S),v=V*(GFX.rand(40,120)*S)+N*(GFX.rand(10,50)*S),
								life=GFX.rand(1,1.6),s0=3*S,s1=1.5*S,ramp={{.08,.07,.07}},grav=-35*S,drag=.9,
								spin=GFX.rand(3,8),op=.9,emis=.6,fin=.001,fp=1})
						end
					end
				end
			end
		end
	end,
}
GFX_DEATHNOTE=12

-- CHRISTMAS ------------------------------------------------------------------------------------
GFX_PAL_XMAS={flash={1,.95,.8},ring={1,.15,.1},ring2={.2,1,.3},light={1,.85,.6},
	spark={{1,1,.9},{1,.8,.3},{1,.2,.1}},
	fire={{1,1,.9},{1,.3,.2},{.2,.8,.25},{.05,.1,.05}},
	ember={{1,1,.8},{1,.85,.3},{.9,.2,.1}},
	smoke={{.15,.15,.18},{.05,.05,.06}}}
GFX_XMAS_COLS={{1,.12,.1},{.15,.85,.25},{1,.8,.2},{1,1,1},{.75,.8,.9}}
GFX_XMAS_BULBS={{1,.15,.1},{.2,1,.3},{.25,.5,1},{1,.8,.2},{1,.4,.9}}

-- solid box: centre c, half-size axes ax/ay/az (vectors), shaded by x.ld; only the faces
-- turned toward the camera are drawn
function GFX.drawBox(x,c,ax,ay,az,col,kk,alpha)
	local cp=GFX.cp
	local faces={{az,ax,ay},{az*-1,ax,ay},{ax,ay,az},{ax*-1,ay,az},{ay,az,ax},{ay*-1,az,ax}}
	for _,f in ipairs(faces) do
		local n,a,b=f[1],f[2],f[3]
		local fc=c+n
		local nn=n:getSafeNormal()
		if Vec3.dot(nn,cp-fc)>0 then
			local sh=(.35+.65*math.max(0,Vec3.dot(nn,x.ld)))*kk
			local lc=LinearColor.new(col[1]*sh,col[2]*sh,col[3]*sh,alpha or 1)
			WorldDraw.drawTriangle(fc-a-b,fc+a-b,fc+a+b,lc,0)
			WorldDraw.drawTriangle(fc-a-b,fc+a+b,fc-a+b,lc,0)
		end
	end
end

-- five-pointed star facing the camera
function GFX.star(p,rOut,rIn,rot,lc)
	local R,U=GFX.bR,GFX.bU
	local prev=nil
	for i=0,10 do
		local rr=(i%2==0) and rOut or rIn
		local th=rot+i/10*6.2832+math.pi*.5
		local q=p+R*(math.cos(th)*rr)+U*(math.sin(th)*rr)
		if prev then WorldDraw.drawTriangle(p,prev,q,lc,0) end
		prev=q
	end
end

-- gentle snow drifting down over the goal
function GFX.snowfall(x,rate)
	local S=x.S
	for i=1,GFX.rate(x,"snow",rate) do
		GFX.add({kind=1,p=x.o+x.u*(GFX.rand(300,450)*S)+x.r*(GFX.rand(-500,500)*S)+x.f*(GFX.rand(-100,250)*S),
			v=x.u*(-GFX.rand(60,130)*S)+x.r*(GFX.rand(-30,30)*S),life=GFX.rand(2.5,3.5),s0=GFX.rand(4,7)*S,
			s1=GFX.rand(3,5)*S,ramp={{1,1,1},{.85,.92,1}},drag=.1,a=.85,tw=GFX.rand(3,6),fin=.15,fp=.8})
	end
end

-- 13: PRESENT POP ------------------------------------------------------------------------------
-- A giant red present with a gold ribbon and bow bounces out of the goal, rattles and hops as
-- golden light leaks out of the lid, then the lid blasts off spinning and the box erupts with
-- confetti, shiny ornaments, candy-cane pieces and gold stars.
GFX_DEFS[13]={
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.TB=.45*x.D
		x.h=105*S
		GFX.flashAt(x,x.base+x.u*(30*S),160*S,{1,.9,.7},.35)
		GFX.shock(x,x.base+x.u*(4*S),x.r,x.f,320*S,14*S,{1,.2,.15},.7)
	end,
	update=function(x,age,d)
		local D,S,h,TB=x.D,x.S,x.h,x.TB
		local U=x.u
		-- turned a little so it reads as a 3D box
		local R=x.r*math.cos(.45)+x.f*math.sin(.45)
		local F=x.f*math.cos(.45)-x.r*math.sin(.45)
		local kk=GFX.K*.5
		local red,gold={.85,.06,.06},{1,.78,.2}
		local gk=kk*1.25
		local grow=math.clamp(age/(.15*D),0,1)
		local g=math.max(GFX.backOut(grow),.01)
		local rumble=goalFxSmooth((age-.18*D)/(TB-.18*D))
		local squash=1+.15*math.sin(grow*math.pi)
		local wob=math.sin(age*40)*.04*rumble
		local Rw=R*math.cos(wob)+U*math.sin(wob)
		local Uw=U*math.cos(wob)-R*math.sin(wob)
		local hh=h*g
		local c=x.base+x.f*(70*S)+U*(hh*squash+math.abs(math.sin(age*13))*22*S*rumble)
		local ax,ay,az=Rw*hh,F*hh,Uw*(hh*squash)
		local fade=1-goalFxSmooth((age-(TB+.25*D))/(.15*D))
		if fade>.01 then
			GFX.drawBox(x,c,ax,ay,az,red,kk,fade)
			GFX.drawBox(x,c,ax*1.02,ay*.15,az*1.01,gold,gk,fade)
			GFX.drawBox(x,c,ax*.15,ay*1.02,az*1.01,gold,gk,fade)
		end
		if GFX.once(x,"burst",TB) then
			local top=c+az
			x.lid0=top+Uw*(14*S)
			GFX.blast(x,top+U*(40*S),GFX_PAL_XMAS,1.3)
			for i=1,GFX.n(x,120) do
				-- confetti
				local dir=(GFX.rdir(x)+U*1.4):getSafeNormal()
				local sz=GFX.rand(6,10)*S
				GFX.add({kind=4,quad=true,p=top,v=dir*(GFX.rand(700,1500)*S),life=GFX.rand(2,2.8),s0=sz,s1=sz,
					ramp={GFX_XMAS_COLS[math.min(5,1+math.floor(GFX.rand()*5))]},grav=420*S,drag=2.2,
					spin=GFX.rand(6,14),op=.95,emis=.9,fin=.001,fp=.5})
			end
			for i=1,GFX.n(x,22) do
				-- shiny ornaments
				local dir=(GFX.rdir(x)+U*1.1):getSafeNormal()
				local bs=GFX.rand(12,18)*S
				GFX.add({kind=1,p=top,v=dir*(GFX.rand(500,1000)*S),life=GFX.rand(1.4,2),s0=bs,s1=bs*.8,
					ramp={GFX_XMAS_COLS[math.min(5,1+math.floor(GFX.rand()*5))]},grav=700*S,drag=.5,hot=.6,fin=.01,fp=.6})
			end
			for i=1,GFX.n(x,26) do
				-- candy-cane pieces
				local dir=(GFX.rdir(x)+U*1.2):getSafeNormal()
				local sz=GFX.rand(14,22)*S
				GFX.add({kind=4,p=top,v=dir*(GFX.rand(500,1100)*S),life=GFX.rand(1.4,2),s0=sz,s1=sz*.8,
					ramp={(i%2==0) and {1,.1,.1} or {1,1,1}},grav=800*S,drag=.6,spin=GFX.rand(4,10),op=1,emis=.85,
					fin=.001,fp=.5})
			end
			for i=1,GFX.n(x,40) do
				-- gold stars
				local dir=GFX.rdir(x,.8)
				GFX.add({kind=1,p=top,v=dir*(GFX.rand(300,800)*S)+U*(200*S),life=GFX.rand(1.2,1.8),s0=GFX.rand(6,9)*S,
					s1=2*S,ramp={{1,1,.8},{1,.8,.2}},drag=1.4,grav=200*S,tw=GFX.rand(14,26)})
			end
			GFX.light(x,top,{1,.85,.6},45000,2400*S,.03,.1,.6)
		end
		-- the lid: rattling on top, then blown off spinning
		local lidC,lidU,lidF,la
		if age<TB then
			lidC=c+az+Uw*(14*S)+Uw*(rumble*math.abs(math.sin(age*27))*8*S)
			lidU,lidF,la=Uw,F,fade
		else
			local t=age-TB
			lidU=U*math.cos(7*t)+F*math.sin(7*t)
			lidF=F*math.cos(7*t)-U*math.sin(7*t)
			lidC=(x.lid0 or c)+U*(t*900*S-t*t*500*S)+R*(t*120*S)
			la=1-goalFxSmooth(t/(.35*D))
		end
		if la>.01 then
			local lh=h*g
			GFX.drawBox(x,lidC,Rw*(lh*1.07),lidF*(lh*1.07),lidU*(14*S),red,kk,la)
			GFX.drawBox(x,lidC,Rw*(lh*1.09),lidF*(lh*.16),lidU*(15*S),gold,gk,la)
			GFX.drawBox(x,lidC,Rw*(lh*.16),lidF*(lh*1.09),lidU*(15*S),gold,gk,la)
			-- bow: two loops and a knot
			local bt=lidC+lidU*(14*S)
			local glc=LinearColor.new(gold[1]*gk,gold[2]*gk,gold[3]*gk,la)
			local dlc=LinearColor.new(.7*kk,.45*kk,.08*kk,la)
			for sd=-1,1,2 do
				local lc0=bt+Rw*(sd*lh*.28)+lidU*(lh*.2)
				local axA=(Rw*(sd*.85)+lidU*.5):getSafeNormal()*(lh*.3)
				local axB=(lidU*.85-Rw*(sd*.5)):getSafeNormal()*(lh*.13)
				GFX.ellipse(lc0,axA,axB,glc)
				GFX.ellipse(lc0+lidF*(lh*.02),axA*.55,axB*.45,dlc)
			end
			GFX.ellipse(bt+lidU*(lh*.08)+lidF*(lh*.03),Rw*(lh*.09),lidU*(lh*.09),glc)
		end
		-- golden light leaking out of the lid seam before it pops
		if age<TB and rumble>.01 then
			local seam=c+az
			local bk=GFX.K*.9*rumble
			local lc=LinearColor.new(bk,.8*bk,.3*bk,.25*rumble)
			for i=1,7 do
				local dir=(U+R*(math.cos(i*.9+age)*.8)+F*(math.sin(i*.9+age)*.8)):getSafeNormal()
				GFX.beam(seam,seam+dir*((60+80*rumble)*S),6*S,lc)
			end
			GFX.glow(seam,h*.8,1,.8,.3,.4*rumble,age,.5)
		end
	end,
}

-- 14: CHRISTMAS TREE ---------------------------------------------------------------------------
-- A snowy Christmas tree grows out of the goal tier by tier, a gold garland spirals round it,
-- the lights twinkle on and the star on top flares up. Then the tree bursts into needles and
-- ornaments, and the star rockets up into a gold firework while snow falls.
GFX_TREE_TIERS={{40,170,175},{150,150,138},{250,130,102},{340,115,66}}   -- {base height, height, radius}

function GFX.treeRadius(y)
	local best=0
	for _,tr in ipairs(GFX_TREE_TIERS) do
		if y>=tr[1] and y<=tr[1]+tr[2] then best=math.max(best,tr[3]*(1-(y-tr[1])/tr[2])) end
	end
	return best
end

-- cone with a ragged, drooping lower edge (branch tips), shaded, with a snowy rim
function GFX.drawCone(x,base,apexH,rad,n,col,kk)
	local cp=GFX.cp
	local U,R,F=x.u,x.r,x.f
	local apex=base+U*apexH
	local ring={}
	for j=0,n do
		local th=j/n*6.2832
		local rr=rad*((j%2==0) and 1.06 or .94)
		local drop=(j%2==0) and -rad*.12 or 0
		ring[j]=base+(R*math.cos(th)+F*math.sin(th))*rr+U*drop
	end
	local sk=kk*1.6
	for j=0,n-1 do
		local a,b=ring[j],ring[j+1]
		local mid=(a+b)*.5
		local radial=mid-base
		radial=(radial-U*Vec3.dot(radial,U)):getSafeNormal()
		local nrm=(radial*apexH+U*rad):getSafeNormal()
		if Vec3.dot(nrm,(cp-mid):getSafeNormal())>-.25 then
			local sh=(.3+.7*math.max(0,Vec3.dot(nrm,x.ld)))*kk
			WorldDraw.drawTriangle(apex,a,b,LinearColor.new(col[1]*sh,col[2]*sh,col[3]*sh,1),0)
			WorldDraw.drawLine(a,b,.9*sk,.95*sk,sk,3,0)
		end
	end
end

GFX_DEFS[14]={
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.treeBase=x.base+x.f*(60*S)
		x.bulbs={}
		for i=1,({18,26,36,44})[x.qi] do
			x.bulbs[i]={tier=math.min(4,1+math.floor(GFX.rand()*4)),th=GFX.rand(0,6.2832),hf=GFX.rand(.1,.75),
				col=GFX_XMAS_BULBS[math.min(5,1+math.floor(GFX.rand()*5))],ph=GFX.rand(0,6),t0=GFX.rand(0,.08*x.D)}
		end
		x.TB=.62*x.D
		GFX.flashAt(x,x.base+x.u*(30*S),160*S,{.8,1,.85},.35)
		GFX.shock(x,x.base+x.u*(4*S),x.r,x.f,320*S,14*S,{.2,1,.35},.7)
	end,
	update=function(x,age,d)
		local D,S,TB,tb=x.D,x.S,x.TB,x.treeBase
		local U=x.u
		local kk=GFX.K*.5
		local topY=455
		if age<.95*D then GFX.snowfall(x,50) end
		if age<TB then
			local tg=GFX.backOut(age/(.08*D))
			if tg>0 then GFX.drawBox(x,tb+U*(25*S*tg),x.r*(22*S),x.f*(22*S),U*(25*S*tg),{.35,.2,.08},kk,1) end
			for i,tr in ipairs(GFX_TREE_TIERS) do
				local g=GFX.backOut((age-.04*D-i*.05*D)/(.1*D))
				if g>0 then GFX.drawCone(x,tb+U*(tr[1]*S),tr[2]*S*g,tr[3]*S*g,({10,12,16,20})[x.qi],{.05,.42,.13},kk) end
			end
			-- gold garland spiralling up the tree
			local gg=goalFxSmooth((age-.3*D)/(.1*D))
			if gg>0 then
				local prev=nil
				local gk=kk*2
				for k=0,math.floor(48*gg) do
					local t=k/48
					local y=40+t*380
					local th=t*3.2*6.2832
					local q=tb+U*(y*S)+(x.r*math.cos(th)+x.f*math.sin(th))*((GFX.treeRadius(y)+3)*S)
					if prev then WorldDraw.drawLine(prev,q,gk,.8*gk,.25*gk,3,0) end
					prev=q
				end
			end
			-- twinkling lights on the front of the tree
			local fl=(GFX.cp-tb)
			fl=(fl-U*Vec3.dot(fl,U)):getSafeNormal()
			for _,bl in ipairs(x.bulbs) do
				if age>.3*D+bl.t0 then
					local dirH=x.r*math.cos(bl.th)+x.f*math.sin(bl.th)
					if Vec3.dot(dirH,fl)>-.1 then
						local tr=GFX_TREE_TIERS[bl.tier]
						local p=tb+U*((tr[1]+tr[2]*bl.hf)*S)+dirH*((tr[3]*(1-bl.hf)+3)*S)
						local c=bl.col
						GFX.glow(p,9*S,c[1],c[2],c[3],.6+.4*math.sin(age*6+bl.ph),0,.5)
					end
				end
			end
			-- the star on top
			local sg=GFX.backOut((age-.34*D)/(.06*D))
			if sg>0 then
				local sp=tb+U*((topY+25)*S)
				local sk=GFX.K*1.4
				GFX.star(sp,42*S*sg,17*S*sg,math.sin(age*2)*.2,LinearColor.new(sk,.82*sk,.25*sk,1))
				GFX.glow(sp,70*S*sg,1,.85,.3,.5,age,.6)
			end
			if GFX.once(x,"starOn",.34*D) then
				GFX.flashAt(x,tb+U*((topY+25)*S),120*S,{1,.9,.5},.3)
				GFX.light(x,tb+U*((topY+25)*S),{1,.85,.5},20000,2000*S,.05,TB-.4*D,.3)
			end
		end
		if GFX.once(x,"burst",TB) then
			local mid=tb+U*(200*S)
			GFX.blast(x,mid,GFX_PAL_XMAS,1.4)
			for i=1,GFX.n(x,90) do
				-- needles
				local tr=GFX_TREE_TIERS[math.min(4,1+math.floor(GFX.rand()*4))]
				local hf,th=GFX.rand(0,.9),GFX.rand(0,6.2832)
				local dirH=x.r*math.cos(th)+x.f*math.sin(th)
				local p=tb+U*((tr[1]+tr[2]*hf)*S)+dirH*(tr[3]*(1-hf)*S)
				local sz=GFX.rand(10,18)*S
				GFX.add({kind=4,p=p,v=dirH*(GFX.rand(400,900)*S)+U*(GFX.rand(100,400)*S),life=GFX.rand(1.2,1.8),s0=sz,
					s1=sz*.8,ramp={{.08,.5,.15},{.04,.3,.08}},grav=800*S,drag=.6,spin=GFX.rand(4,10),op=1,emis=.8,
					fin=.001,fp=.5})
			end
			for _,bl in ipairs(x.bulbs) do
				-- the lights fly off as glowing ornaments
				local tr=GFX_TREE_TIERS[bl.tier]
				local dirH=x.r*math.cos(bl.th)+x.f*math.sin(bl.th)
				local p=tb+U*((tr[1]+tr[2]*bl.hf)*S)+dirH*(tr[3]*(1-bl.hf)*S)
				GFX.add({kind=1,p=p,v=dirH*(GFX.rand(400,900)*S)+U*(GFX.rand(200,500)*S),life=GFX.rand(1.4,2),
					s0=GFX.rand(12,16)*S,s1=10*S,ramp={bl.col},grav=700*S,drag=.5,hot=.6,fin=.01,fp=.6})
			end
			for i=1,GFX.n(x,14) do
				local dir=GFX.rdir(x,.6)
				GFX.add({kind=3,p=mid+dir*(GFX.rand(0,120)*S),v=dir*(GFX.rand(80,200)*S),life=GFX.rand(1.4,2),
					s0=60*S,s1=170*S,ramp={{.85,.9,.95},{.4,.45,.5}},op=.35,fin=.1,drag=1.2,spin=GFX.rand(-.6,.6)})
			end
			x.starT=age
		end
		if x.starT then
			-- the star rockets up and bursts into a gold firework
			local t=(age-x.starT)/(.12*D)
			local p0=tb+U*((topY+25)*S)
			if t<1 then
				local p=p0+U*(goalFxEaseOut(t)*350*S)
				local sk=GFX.K*1.4
				GFX.star(p,42*S,17*S,age*8,LinearColor.new(sk,.82*sk,.25*sk,1))
				for i=1,GFX.rate(x,"starTrail",120) do
					GFX.add({kind=1,p=p,v=GFX.rdir(x)*(GFX.rand(20,70)*S)-U*(80*S),life=GFX.rand(.3,.5),s0=GFX.rand(6,9)*S,
						s1=1*S,ramp={{1,1,.8},{1,.75,.2}},grav=150*S,drag=1,tw=18})
				end
			elseif GFX.once(x,"starBoom",x.starT+.12*D) then
				local p=p0+U*(350*S)
				GFX.shell(x,p,0,{1,.85,.3},1.3)
				GFX.shell(x,p,2,{1,.85,.3},1.1)
			end
		end
	end,
}

-- 15: FROZEN CATACLYSM -------------------------------------------------------------------------
-- (Rebuilt from Frosty Flake.) Freezing air swirls into the goal as frost creeps across the floor.
-- Then a huge icy shockwave tears outward and a wave of real 3D ice spikes erupts behind it in two
-- rings, tilted away from the centre, while a giant ice spire stabs up the middle and freezing
-- mist rolls out. Everything hums with cold light for a moment, then it all shatters at once into
-- tumbling shards and glittering ice dust.
GFX_DEFS[15]={
	init=function(x)
		local S,D=x.S,x.D
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.fc=x.base+x.f*(70*S)
		x.TW,x.TS=.2*D,.62*D
		x.spikes={}
		local n=({14,20,26,32})[x.qi]
		for i=1,n do
			local ring=(i%2==0) and 1 or 2
			local th=i/n*6.2832+GFX.rand(-.1,.1)
			local radial=x.r*math.cos(th)+x.f*math.sin(th)
			local rr=((ring==1) and GFX.rand(170,240) or GFX.rand(330,430))*S
			x.spikes[i]={rr=rr,c={root=x.fc+radial*rr,axis=(x.u+radial*GFX.rand(.45,.8)):getSafeNormal(),
				h=((ring==1) and GFX.rand(160,240) or GFX.rand(90,160))*S,rad=GFX.rand(18,30)*S,rot=GFX.rand(0,1)}}
		end
		x.spire={root=x.fc,axis=x.u,h=480*S,rad=55*S,rot=0}
		GFX.light(x,x.fc+x.u*(200*S),{.5,.8,1},25000,2600*S,x.TW,x.TS-x.TW,.3)
	end,
	update=function(x,age,d)
		local D,S,TW,TS=x.D,x.S,x.TW,x.TS
		local P=GFX_PAL_ICE
		local U=x.u
		local fl=x.fc+U*(2*S)
		local k=GFX.K
		if age<.95*D then GFX.snowfall(x,(age>TS) and 70 or 25) end
		-- frost creeping over the floor, then racing out with the shockwave
		local frost=(age<TW) and (age/TW*150*S) or ((150+500*goalFxEaseOut((age-TW)/(.2*D)))*S)
		local fa=1-goalFxSmooth((age-.8*D)/(.2*D))
		GFX.flatDisc(fl,x.r,x.f,frost,LinearColor.new(.45*k,.65*k,.85*k,.3*fa))
		GFX.ring(fl+U*(1*S),x.r,x.f,frost,5*S,48,.8,.95,1,.6*fa)
		if age<TW then
			-- freezing air swirling in
			for i=1,GFX.rate(x,"swirl",120) do
				local th=GFX.rand(0,6.2832)
				local radial=x.r*math.cos(th)+x.f*math.sin(th)
				local tang=x.f*math.cos(th)-x.r*math.sin(th)
				local rr=GFX.rand(250,400)*S
				GFX.add({kind=1,p=x.fc+radial*rr+U*(GFX.rand(20,200)*S),v=tang*(rr*1.8)-radial*(100*S),life=GFX.rand(.6,1),
					s0=GFX.rand(4,7)*S,s1=2*S,ramp={{1,1,1},{.7,.9,1}},att=x.fc+U*(80*S),attK=3,drag=.5,tw=8,fin=.15})
			end
			GFX.glow(x.fc+U*(60*S),(40+120*age/TW)*S,.6,.85,1,.4+.4*age/TW,age,.5)
			GFX.addShake(age/TW*4*S)
		end
		if GFX.once(x,"wave",TW) then
			GFX.flashAt(x,x.fc+U*(80*S),300*S,{.85,.95,1},.3)
			GFX.shock(x,fl,x.r,x.f,700*S,28*S,{.7,.92,1},1)
			GFX.shock(x,x.fc+U*(80*S),GFX.bR,GFX.bU,480*S,10*S,{.85,.95,1},.6)
			GFX.addShake(18*S)
			for i=1,GFX.n(x,22) do
				local th=GFX.rand(0,6.2832)
				local dirH=x.r*math.cos(th)+x.f*math.sin(th)
				GFX.add({kind=3,p=fl+dirH*(GFX.rand(60,140)*S)+U*(15*S),v=dirH*(GFX.rand(300,520)*S)+U*(30*S),
					life=GFX.rand(1.6,2.2),s0=60*S,s1=210*S,ramp=P.smoke,op=.32,fin=.06,drag=1.3,spin=GFX.rand(-.6,.6)})
			end
		end
		if age>=TW and age<TS then
			local crack=goalFxSmooth((age-(TS-.06*D))/(.06*D))
			-- ice spikes erupting as the wave reaches them
			local waveR=(150+500*goalFxEaseOut((age-TW)/(.2*D)))*S
			for i,sp in ipairs(x.spikes) do
				if waveR>sp.rr then
					sp.t0=sp.t0 or age
					local g=GFX.backOut((age-sp.t0)/(.08*D))
					if g>0 then GFX.drawCrystal(x,sp.c,g,crack) end
					if not sp.popped then
						sp.popped=true
						for j=1,GFX.n(x,4) do
							local dir=(GFX.rdir(x)+U*1.2):getSafeNormal()
							local sz=GFX.rand(5,10)*S
							GFX.add({kind=4,p=sp.c.root,v=dir*(GFX.rand(250,550)*S),life=GFX.rand(.5,.9),s0=sz,s1=sz*.6,
								ramp=P.shard,grav=900*S,drag=.8,spin=GFX.rand(6,14),op=.85,emis=1,fin=.001,fp=.6})
						end
					end
				end
			end
			-- the central spire
			local sg=GFX.backOut((age-TW-.02*D)/(.12*D))
			if sg>0 then GFX.drawCrystal(x,x.spire,sg,crack) end
			GFX.glow(x.fc+U*(200*S),180*S,.5,.8,1,.2+.4*crack,age,.3)
		end
		if GFX.once(x,"shatter",TS) then
			local function burst(c,count)
				for i=1,GFX.n(x,count) do
					local p=c.root+c.axis*(c.h*GFX.rand(.05,.95))
					local dir=((p-x.fc):getSafeNormal()+GFX.rdir(x)*.5+U*.5):getSafeNormal()
					local sz=GFX.rand(12,28)*S
					GFX.add({kind=4,p=p,v=dir*(GFX.rand(400,1100)*S),life=GFX.rand(1.2,1.8),s0=sz,s1=sz*.8,
						ramp=P.shard,grav=750*S,drag=.6,spin=GFX.rand(4,11),op=.85,emis=1,fin=.001,fp=.6})
				end
			end
			for _,sp in ipairs(x.spikes) do burst(sp.c,6) end
			burst(x.spire,30)
			local mid=x.fc+U*(200*S)
			GFX.blast(x,mid,P,1.8)
			GFX.shock(x,fl,x.r,x.f,800*S,26*S,{.75,.92,1},1.2)
			GFX.light(x,mid,{.6,.85,1},70000,3200*S,.02,.1,.7)
			GFX.addShake(22*S)
			for i=1,GFX.n(x,100) do
				local dir=GFX.rdir(x,.8)
				GFX.add({kind=1,p=mid+dir*(GFX.rand(0,200)*S),v=dir*(GFX.rand(150,600)*S),life=GFX.rand(1,1.8),
					s0=GFX.rand(4,8)*S,s1=1*S,ramp={{1,1,1},{.6,.9,1}},drag=1.8,grav=80*S,tw=GFX.rand(15,30)})
			end
		end
	end,
}

-- 16: METEOR STRIKE ----------------------------------------------------------------------------
-- A flaming meteor streaks down out of the sky with a fire trail while a warning glow grows on
-- the goal floor, then smashes in: a huge flash, shockwaves along the floor, rocks and molten
-- chunks thrown everywhere, a rolling dust cloud and a mushroom cloud of fire over a glowing crater.
GFX_DEFS[16]={
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.hit=x.base+x.f*(60*S)
		x.mFrom=x.o+x.u*(950*S)-x.r*(750*S)+x.f*(250*S)
		x.TI=.28*x.D
	end,
	update=function(x,age,d)
		local D,S,TI,hit=x.D,x.S,x.TI,x.hit
		local P=GFX_PAL_FIRE
		if age<TI then
			local k=age/TI
			local p=x.mFrom+(hit-x.mFrom)*(k*k)
			local dir=(hit-x.mFrom):getSafeNormal()
			local rad=45*S
			GFX.drawSphere(x,p,rad,{.3,.2,.15},GFX.K*.45,1,6,10,.3)
			GFX.glow(p+dir*(rad*.3),rad*2.2,1,.6,.15,1,age*3,.7)
			GFX.glow(p,rad*1.4,1,.9,.6,.8,0,.9)
			local bk=GFX.K
			GFX.beam(p,p-dir*(500*S*(.5+.5*k)),rad*.9,LinearColor.new(bk,.45*bk,.1*bk,.35))
			GFX.beam(p,p-dir*(300*S),rad*.35,LinearColor.new(1.2*bk,1.02*bk,.6*bk,.7))
			for i=1,GFX.rate(x,"mtrail",260) do
				GFX.add({kind=1,p=p+GFX.rdir(x)*(rad*.6),v=dir*(-GFX.rand(100,300)*S)+GFX.rdir(x)*(80*S),
					life=GFX.rand(.4,.7),s0=20*S,s1=GFX.rand(55,75)*S,ramp=P.fire,drag=1.5,grav=-40*S,fin=.03,fp=1.4,
					spin=GFX.rand(-2,2)})
			end
			for i=1,GFX.rate(x,"msmoke",30) do
				GFX.add({kind=3,p=p,v=dir*(-100*S)+GFX.rdir(x)*(40*S),life=GFX.rand(1.2,1.6),s0=40*S,s1=140*S,
					ramp={{.12,.1,.09},{.04,.04,.04}},op=.45,fin=.1,drag=.8,spin=GFX.rand(-1,1)})
			end
			for i=1,GFX.rate(x,"mspark",60) do
				GFX.add({kind=2,p=p,v=dir*(-GFX.rand(300,700)*S)+GFX.rdir(x)*(200*S),life=GFX.rand(.3,.5),s0=2.5*S,
					s1=.5*S,ramp=P.spark,drag=1.5,grav=300*S,st=.04})
			end
			-- warning glow where it is going to land
			GFX.ring(hit+x.u*(3*S),x.r,x.f,(60+200*(1-k))*S,6*S,40,1,.25,.05,.6*k)
			GFX.glow(hit+x.u*(5*S),(80+120*k)*S,1,.35,.05,.35*k,0,.2)
			if GFX.once(x,"mlight",0) then x.mL=GFX.light(x,p,{1,.55,.2},25000,1800*S,.1,TI,.2) end
			if x.mL then pcall(function() x.mL.h.position=p end) end
			GFX.addShake(k*k*4*S)
		end
		if GFX.once(x,"impact",TI) then
			GFX.blast(x,hit+x.u*(40*S),P,2.3)
			GFX.flashAt(x,hit+x.u*(60*S),420*S,{1,.95,.8},.45)
			GFX.shock(x,hit+x.u*(4*S),x.r,x.f,700*S,30*S,{1,.5,.15},1.2)
			GFX.light(x,hit+x.u*(100*S),{1,.55,.2},90000,3200*S,.02,.15,.8)
			GFX.addShake(30*S)
			for i=1,GFX.n(x,55) do
				-- rocks
				local dir=(GFX.rdir(x)+x.u*1.2):getSafeNormal()
				local sz=GFX.rand(14,34)*S
				GFX.add({kind=4,p=hit+x.u*(20*S),v=dir*(GFX.rand(500,1400)*S),life=GFX.rand(1.6,2.4),s0=sz,s1=sz,
					ramp={{.32,.22,.16},{.18,.13,.1}},grav=1100*S,drag=.3,spin=GFX.rand(3,9),op=1,emis=.5,fin=.001,fp=.4})
			end
			for i=1,GFX.n(x,25) do
				-- molten chunks
				local dir=(GFX.rdir(x)+x.u*1.2):getSafeNormal()
				local sz=GFX.rand(8,18)*S
				GFX.add({kind=4,p=hit+x.u*(20*S),v=dir*(GFX.rand(500,1200)*S),life=GFX.rand(1.2,1.8),s0=sz,s1=sz*.7,
					ramp={{1,.6,.15},{.6,.15,.03}},grav=1000*S,drag=.3,spin=GFX.rand(3,9),op=1,emis=1.3,fin=.001,fp=.6})
			end
			for i=1,GFX.n(x,40) do
				-- lava splashes
				local dir=(GFX.rdir(x)+x.u):getSafeNormal()
				GFX.add({kind=1,p=hit,v=dir*(GFX.rand(300,900)*S),life=GFX.rand(1,1.6),s0=GFX.rand(8,14)*S,s1=3*S,
					ramp=P.ember,grav=900*S,drag=.4})
			end
			for i=1,GFX.n(x,18) do
				-- dust rolling out along the floor
				local th=GFX.rand(0,6.2832)
				local dirH=x.r*math.cos(th)+x.f*math.sin(th)
				GFX.add({kind=3,p=hit+dirH*(GFX.rand(20,80)*S)+x.u*(20*S),v=dirH*(GFX.rand(250,500)*S)+x.u*(40*S),
					life=GFX.rand(2,2.8),s0=80*S,s1=260*S,ramp={{.35,.3,.26},{.12,.1,.09}},op=.5,fin=.08,drag=1.4,
					spin=GFX.rand(-.6,.6)})
			end
		end
		if GFX.once(x,"impact2",TI+.05*D) then GFX.shock(x,hit+x.u*(4*S),x.r,x.f,520*S,18*S,{1,.8,.4},.9) end
		if age>TI and age<TI+.4*D then
			-- mushroom cloud over a glowing crater
			local k=(age-TI)/(.4*D)
			for i=1,GFX.rate(x,"stem",140*(1-k)) do
				GFX.add({kind=1,p=hit+x.r*(GFX.rand(-40,40)*S)+x.f*(GFX.rand(-40,40)*S)+x.u*(GFX.rand(0,60)*S),
					v=x.u*(GFX.rand(600,900)*S)+GFX.rdir(x)*(60*S),life=GFX.rand(.7,1),s0=30*S,s1=80*S,ramp=P.fire,
					drag=1.2,grav=-100*S,fin=.03,fp=1.4,spin=GFX.rand(-1.5,1.5)})
			end
			local capH=(200+380*goalFxEaseOut(k))*S
			for i=1,GFX.rate(x,"cap",90*(1-k*.7)) do
				local th=GFX.rand(0,6.2832)
				local dirH=x.r*math.cos(th)+x.f*math.sin(th)
				GFX.add({kind=1,p=hit+x.u*capH+dirH*(GFX.rand(0,80)*S),v=dirH*(GFX.rand(200,420)*S)+x.u*(GFX.rand(-40,120)*S),
					life=GFX.rand(.9,1.3),s0=40*S,s1=140*S,ramp={{1,.8,.4},{1,.4,.05},{.3,.12,.06},{.08,.06,.05}},
					drag=1.4,fin=.05,fp=1.3,spin=GFX.rand(-1,1)})
			end
			GFX.ring(hit+x.u*(3*S),x.r,x.f,140*S,30*S,40,1,.35,.05,.8*(1-k))
		end
	end,
}

-- 17: ORBITAL STRIKE ---------------------------------------------------------------------------
-- A red targeting reticle locks onto the goal floor under a thin guide laser while energy
-- gathers, then a massive white-blue beam slams down from orbit with rings sliding down it and
-- sparks skidding across the floor. When it cuts out, the strike point detonates.
GFX_PAL_ORBITAL={flash={.9,.97,1},ring={.4,.85,1},ring2={1,1,1},light={.6,.85,1},
	spark={{1,1,1},{.6,.9,1},{.2,.5,1}},
	fire={{1,1,1},{.6,.9,1},{.25,.45,1},{.04,.06,.18}},
	ember={{1,1,1},{.6,.9,1},{.3,.5,1}},
	smoke={{.15,.2,.3},{.05,.06,.1}}}

GFX_DEFS[17]={
	init=function(x)
		x.hit=x.base+x.f*(60*x.S)
		x.TS,x.TE=.4*x.D,.62*x.D
	end,
	update=function(x,age,d)
		local D,S,TS,TE=x.D,x.S,x.TS,x.TE
		local P=GFX_PAL_ORBITAL
		local fl=x.hit+x.u*(3*S)
		local sky=x.hit+x.u*(2200*S)
		if age<TS then
			local k=goalFxSmooth(age/(.08*D))
			local blink=(math.floor(age*8)%2==0) and 1 or .55
			local spin=age*1.5
			for q=0,3 do
				local a0=spin+q*1.5708
				GFX.arc(fl,x.r,x.f,230*S,6*S,a0+.15,a0+1.25,10,1,.15,.1,.8*k*blink)
			end
			for q=0,2 do
				local a0=-spin*1.6+q*2.094
				GFX.arc(fl,x.r,x.f,150*S,4*S,a0,a0+1.4,10,1,.3,.2,.7*k)
			end
			local shrink=1-goalFxSmooth((age-.2*D)/(TS-.2*D))
			GFX.ring(fl,x.r,x.f,(70+60*shrink)*S,3*S,32,1,.2,.15,.9*k*blink)
			local ck=GFX.K*k*blink
			for _,ax in ipairs({x.r,x.f}) do
				WorldDraw.drawLine(fl+ax*(60*S),fl+ax*(260*S),ck,.15*ck,.1*ck,2,0)
				WorldDraw.drawLine(fl-ax*(60*S),fl-ax*(260*S),ck,.15*ck,.1*ck,2,0)
			end
			local gk=GFX.K*.8*k
			GFX.beam(sky,fl,(2+3*goalFxSmooth((age-.25*D)/(TS-.25*D)))*S,LinearColor.new(gk,.2*gk,.15*gk,.5*blink))
			if age>.22*D then
				for i=1,GFX.rate(x,"charge",160) do
					GFX.add({kind=2,p=x.hit+x.u*(GFX.rand(200,1600)*S)+GFX.rdir(x)*(GFX.rand(30,90)*S),
						v=x.u*(-GFX.rand(900,1500)*S),life=GFX.rand(.2,.4),s0=2.5*S,s1=1*S,ramp=P.spark,drag=.2,st=.05})
				end
			end
		end
		if GFX.once(x,"strike",TS) then
			GFX.flashAt(x,fl+x.u*(80*S),300*S,{.85,.95,1},.3)
			GFX.light(x,fl+x.u*(150*S),{.6,.85,1},70000,2600*S,.02,TE-TS,.1,true)
			GFX.addShake(14*S)
		end
		if age>=TS and age<TE then
			local k=(age-TS)/(TE-TS)
			local w=(20+80*goalFxEaseOut(math.min(k*3,1)))*S*(1+.08*math.sin(age*60))
			local bk=GFX.K
			GFX.beam(sky,fl,w*1.8,LinearColor.new(.3*bk,.6*bk,bk,.25))
			GFX.beam(sky,fl,w,LinearColor.new(.72*bk,1.02*bk,1.2*bk,.7))
			GFX.beam(sky,fl,w*.35,LinearColor.new(1.6*bk,1.6*bk,1.6*bk,1))
			for j=0,3 do
				local f=(age*2.2+j/4)%1
				GFX.ring(fl+x.u*((1-f)*1400*S),x.r,x.f,w*(1.3+.4*f),4*S,28,.6,.9,1,.6*(1-f*.5))
			end
			GFX.glow(fl+x.u*(20*S),w*3,.6,.85,1,.8,age*3,.7)
			GFX.ring(fl,x.r,x.f,w*1.6+math.sin(age*30)*6*S,10*S,40,.7,.9,1,.8)
			for i=1,GFX.rate(x,"skid",240) do
				local th=GFX.rand(0,6.2832)
				local dirH=x.r*math.cos(th)+x.f*math.sin(th)
				GFX.add({kind=2,p=fl+dirH*(w*.8)+x.u*(4*S),v=dirH*(GFX.rand(600,1400)*S)+x.u*(GFX.rand(50,350)*S),
					life=GFX.rand(.3,.6),s0=3*S,s1=.5*S,ramp=P.spark,drag=1.6,grav=700*S,st=.04})
			end
			for i=1,GFX.rate(x,"bsmoke",20) do
				local th=GFX.rand(0,6.2832)
				local dirH=x.r*math.cos(th)+x.f*math.sin(th)
				GFX.add({kind=3,p=fl+dirH*(w*1.2),v=dirH*(GFX.rand(80,200)*S)+x.u*(GFX.rand(60,160)*S),life=GFX.rand(1.2,1.8),
					s0=60*S,s1=180*S,ramp=P.smoke,op=.35,fin=.1,drag=.8,spin=GFX.rand(-1,1)})
			end
			GFX.addShake(4*S)
		end
		if GFX.once(x,"det",TE) then
			local c=fl+x.u*(120*S)
			GFX.blast(x,c,P,2.2)
			for j=1,3 do
				local ax=(x.r*math.cos(j*1.05)+x.u*math.sin(j*1.05)):getSafeNormal()
				GFX.shock(x,c,ax,x.f,(500+j*80)*S,12*S,P.ring,1+j*.15)
			end
			GFX.shock(x,fl,x.r,x.f,800*S,26*S,{.7,.9,1},1.3)
			GFX.light(x,c,{.6,.85,1},90000,3200*S,.02,.1,.7)
			GFX.addShake(26*S)
			for i=1,GFX.n(x,40) do
				local dir=(GFX.rdir(x,.8)+x.u*.6):getSafeNormal()
				GFX.add({kind=1,p=c,v=dir*(GFX.rand(150,500)*S),life=GFX.rand(1,1.6),s0=50*S,s1=160*S,ramp=P.fire,
					drag=1.6,grav=-120*S,fin=.02,fp=1.4,spin=GFX.rand(-1,1)})
			end
		end
	end,
}

-- 18: PHOENIX RISING ---------------------------------------------------------------------------
-- A ring of fire roars up and a fireball swells in it until it cracks open into a real 3D
-- firebird: a tapered glowing body, a head with a hooked beak, burning eyes and a swept-back crest,
-- and articulated wings (shoulder, elbow and wrist) carrying layered primary and secondary flight
-- feathers, white-hot at the root and burning down to deep red at the tips. It climbs with real
-- wingbeats (the wings fold on the upstroke and spread wide on the downstroke), trailing long
-- flaming tail plumes and shedding fire from every feather. It hovers, beats twice (each beat
-- throws a wave of fire), throws its head back and screeches, then folds its wings and dives
-- straight into the goal: a pillar of fire, a phoenix-shaped burst of burning feathers and a
-- ring of flame across the floor.
GFX_PHOENIX={{1,1,.85},{1,.85,.3},{1,.45,.05},{.75,.1,.02}}

-- one flame feather from root along fdir, in the wing plane (nrm = wing normal), two-tone
function GFX.phoenixFeather(root,fdir,nrm,len,w,k,a)
	local perp=Vec3.cross(fdir,nrm):getSafeNormal()
	local mid=root+fdir*(len*.45)
	local tip=root+fdir*len
	local m1=root+fdir*(len*.22)
	local m2=root+fdir*(len*.72)
	local c1,c2=GFX_PHOENIX[2],GFX_PHOENIX[4]
	local l1=LinearColor.new(c1[1]*k,c1[2]*k,c1[3]*k,a)
	local l2=LinearColor.new(GFX_PHOENIX[3][1]*k,GFX_PHOENIX[3][2]*k,GFX_PHOENIX[3][3]*k,a*.95)
	local l3=LinearColor.new(c2[1]*k,c2[2]*k,c2[3]*k,a*.85)
	WorldDraw.drawTriangle(root,m1+perp*w,mid,l1,0)
	WorldDraw.drawTriangle(root,mid,m1-perp*w,l1,0)
	WorldDraw.drawTriangle(mid,m2+perp*(w*.9),tip,l2,0)
	WorldDraw.drawTriangle(mid,tip,m2-perp*(w*.9),l2,0)
	-- a hot core line down the shaft
	GFX.beam(root,mid,w*.18,LinearColor.new(k*1.2,k*1.1,k*.8,a))
	return tip
end

-- the firebird at P. fwd = where the head points, side = its right; e = wing elevation,
-- fold = how folded the wings are (0 spread, 1 tucked), headUp 0..1 throws the head back
function GFX.drawPhoenix(x,P,fwd,side,e,fold,headUp,a)
	local S=x.S
	local k=GFX.K*a
	local kk=GFX.K*.9
	local dors=Vec3.cross(side,fwd):getSafeNormal()      -- its back
	local rim={1,.6,.15}
	-- body: tail base, belly, chest, neck
	local tailB=P-fwd*(75*S)
	local neck=P+fwd*(55*S)+dors*(6*S)
	local headDir=(fwd*(1-headUp*.6)+dors*(headUp*.9)):getSafeNormal()
	local head=neck+headDir*(42*S)
	GFX.tube(x,{tailB,P-fwd*(25*S),P+fwd*(20*S),neck,head},{10*S,24*S,26*S,13*S,12*S},10,{1,.62,.12},kk,rim)
	GFX.drawSphere(x,head,16*S,{1,.7,.2},kk*1.1,a,5,8,.3)
	-- beak, eyes, crest
	local hd=Vec3.cross(side,headDir):getSafeNormal()
	GFX.tube(x,{head+headDir*(12*S),head+headDir*(40*S)-hd*(9*S)},{6*S,.6*S},6,{1,.9,.55},kk*1.2)
	for sd=-1,1,2 do
		GFX.glow(head+side*(sd*9*S)+headDir*(8*S)+hd*(5*S),7*S,1,1,.8,a,0,1)
	end
	for i=-1,1 do
		local c0=head+hd*(10*S)+side*(i*6*S)
		local c1=head-headDir*(25*S)+hd*(40*S)+side*(i*14*S)
		local c2=head-headDir*(70*S)+hd*(52*S)+side*(i*24*S)
		GFX.tube(x,{c0,c1,c2},{4*S,3*S,.8*S},5,{1,.8,.3},kk*1.2)
		GFX.glow(c2,9*S,1,.7,.2,a,0,.6)
	end
	-- wings
	for sd=-1,1,2 do
		local out=side*sd
		local sh=P+fwd*(22*S)+out*(20*S)+dors*(10*S)
		local armDir=(out*math.cos(e)+dors*math.sin(e)-fwd*.15):getSafeNormal()
		local elbow=sh+armDir*(95*S)
		local e2=e*.75
		local foreDir=((out*math.cos(e2)+dors*math.sin(e2))*(1-fold)-fwd*(.15+fold*.9)):getSafeNormal()
		local wrist=elbow+foreDir*(90*S)
		local e3=e*.55
		local handDir=((out*math.cos(e3)+dors*math.sin(e3))*(1-fold*.7)-fwd*(.25+fold*1.1)):getSafeNormal()
		local wtip=wrist+handDir*(85*S)
		GFX.tube(x,{sh,elbow,wrist,wtip},{9*S,7*S,5*S,2*S},6,{1,.75,.25},kk*1.2,rim)
		local nrm=Vec3.cross(armDir,fwd):getSafeNormal()
		-- primaries: fan out from the hand, longest at the outside
		for i=1,10 do
			local t=(i-1)/9
			local root=wrist+(wtip-wrist)*(1-t*.9)
			local phi=.05+t*(1.05-fold*.6)
			local fdir=(handDir*math.cos(phi)-fwd*math.sin(phi)):getSafeNormal()
			local len=(165-t*55)*S*(1-fold*.25)
			local tip=GFX.phoenixFeather(root,fdir,nrm,len,(15-t*3)*S,k,a)
			if i%3==1 then
				for j=1,GFX.rate(x,"pf"..sd..i,9) do
					GFX.add({kind=1,p=tip,v=GFX.rdir(x)*(50*S)+x.u*(80*S),life=GFX.rand(.25,.45),s0=10*S,s1=26*S,
						ramp=GFX_PAL_FIRE.fire,drag=1,grav=-120*S,fin=.04,fp=1.3,spin=GFX.rand(-2,2)})
				end
			end
		end
		-- secondaries along the arm, pointing back
		for i=1,9 do
			local t=i/9
			local root=(t<.5) and (sh+(elbow-sh)*(t*2)) or (elbow+(wrist-elbow)*((t-.5)*2))
			local fdir=((fwd*-1)*(.85)+armDir*(.2+t*.2)-dors*.15):getSafeNormal()
			GFX.phoenixFeather(root,fdir,nrm,(120-t*20)*S,13*S,k,a)
		end
		-- coverts: a bright row over the arm
		for i=1,6 do
			local t=i/6
			local root=sh+(wrist-sh)*t
			local fdir=((fwd*-1)+armDir*.3):getSafeNormal()
			GFX.phoenixFeather(root+dors*(2*S),fdir,nrm,55*S,10*S,k*1.15,a)
		end
	end
	-- tail: long flaming plumes that wave, with glowing eye-spots on the two longest
	for i=1,7 do
		local off=(i-4)*.16
		local prev=tailB
		local len=(i==2 or i==6) and 380 or (240+(4-math.abs(i-4))*25)
		local pts={tailB}
		for j=1,9 do
			local t=j/9
			local q=tailB-fwd*(t*len*S)-dors*(t*t*60*S)+side*((off*t*200+math.sin(x.age*4+i+t*5)*30*t)*S)
			local c=GFX_PHOENIX[math.min(4,1+math.floor(t*4))]
			GFX.beam(prev,q,(11*(1-t)+3)*S,LinearColor.new(c[1]*k,c[2]*k,c[3]*k,a*(1-t*.5)))
			prev=q
		end
		if i==2 or i==6 then
			GFX.glow(prev,26*S,1,.75,.2,a,x.age*2,.9)
			GFX.ellipse(prev+(GFX.cp-prev):getSafeNormal()*(1*S),GFX.bR*(12*S),GFX.bU*(16*S),LinearColor.new(.2*k,.5*k,1*k,a))
		end
		for j=1,GFX.rate(x,"tail"..i,10) do
			GFX.add({kind=1,p=prev,v=GFX.rdir(x)*(40*S),life=.4,s0=12*S,s1=30*S,ramp=GFX_PAL_FIRE.fire,drag=1,
				grav=-100*S,fin=.04,fp=1.3})
		end
	end
	-- heat: core glow and fire pouring off the body
	GFX.glow(P,90*S,1,.6,.15,a*.8,x.age*2,.7)
	for j=1,GFX.rate(x,"body",60) do
		GFX.add({kind=1,p=P+GFX.rdir(x)*(30*S),v=fwd*(-120*S)+x.u*(100*S),life=GFX.rand(.3,.55),s0=18*S,s1=50*S,
			ramp=GFX_PAL_FIRE.fire,drag=1,grav=-120*S,fin=.04,fp=1.4,spin=GFX.rand(-2,2)})
	end
end

GFX_DEFS[18]={
	init=function(x)
		local S,D=x.S,x.D
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.pc0=x.base+x.f*(80*S)
		x.T={hatch=.13*D,hover=.46*D,beats={.52*D,.6*D},screech=.66*D,dive=.74*D,impact=.82*D}
	end,
	update=function(x,age,d)
		local D,S,T=x.D,x.S,x.T
		local P=GFX_PAL_FIRE
		local U=x.u
		local R=GFX.flatRight(x)
		local Fv=GFX.cp-x.pc0
		local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
		local hoverPos=x.pc0+U*(360*S)
		-- the ring of fire and the swelling fireball
		if age<T.hatch then
			local k=age/T.hatch
			GFX.ring(x.base+x.u*(3*S),x.r,x.f,(150+60*k)*S,10*S,40,1,.45,.05,.8)
			GFX.glow(x.pc0+U*((40+50*k)*S),(40+50*k)*S*(1+.12*math.sin(age*40)),1,.6,.1,1,age*3,.7)
			for i=1,GFX.rate(x,"pfire",180) do
				local th=GFX.rand(0,6.2832)
				GFX.add({kind=1,p=x.base+(x.r*math.cos(th)+x.f*math.sin(th))*((150+60*k)*S),v=U*(GFX.rand(250,520)*S),
					life=GFX.rand(.4,.7),s0=14*S,s1=42*S,ramp=P.fire,drag=1,grav=-120*S,fin=.04,fp=1.5,spin=GFX.rand(-2,2)})
			end
		end
		if GFX.once(x,"hatch",T.hatch) then
			local pc=x.pc0+U*(90*S)
			GFX.flashAt(x,pc,260*S,{1,.85,.5},.35)
			GFX.blast(x,pc,P,.8)
			GFX.light(x,pc,{1,.55,.15},40000,2600*S,.05,T.impact-T.hatch,.4,true)
			GFX.addShake(8*S)
		end
		if age>=T.hatch and age<T.impact then
			local pos,fwd,e,fold,headUp
			local sideDir=R
			if age<T.hover then
				-- climbing with full wingbeats
				local t=(age-T.hatch)/(T.hover-T.hatch)
				pos=x.pc0+U*((90+270*goalFxEaseOut(t))*S)+R*(math.sin(t*5)*50*S)
				fwd=(U*.85+F*.35):getSafeNormal()
				local ph=(age-T.hatch)*13
				e=.25+.8*math.sin(ph)
				fold=.15+.45*math.max(0,math.cos(ph))     -- tucks on the way up
				headUp=0
			elseif age<T.dive then
				-- hovering: big slow beats, then the screech with wings flung wide
				pos=hoverPos+U*(math.sin(age*5)*10*S)
				fwd=(U*.7+F*.7):getSafeNormal()
				local ph=(age-T.hover)*8
				e=.45+.6*math.sin(ph)
				fold=.1+.3*math.max(0,math.cos(ph))
				headUp=0
				if age>T.screech-.05*D then
					local s=goalFxSmooth((age-(T.screech-.05*D))/(.05*D))
					e=e*(1-s)+1.05*s
					fold=fold*(1-s)
					headUp=s
				end
			else
				-- wings fold and it dives into the goal
				local t=(age-T.dive)/(T.impact-T.dive)
				local tgt=x.base+U*(40*S)
				pos=hoverPos+(tgt-hoverPos)*(t*t)
				fwd=((U*.7+F*.7)*(1-t)+(U*-.85+F*.5)*t):getSafeNormal()
				e=-.1
				fold=.85
				headUp=0
				for i=1,GFX.rate(x,"dive",200) do
					GFX.add({kind=1,p=pos+GFX.rdir(x)*(40*S),v=U*(200*S)+GFX.rdir(x)*(60*S),life=GFX.rand(.4,.7),s0=24*S,s1=70*S,
						ramp=P.fire,drag=1.2,grav=-150*S,fin=.04,fp=1.4,spin=GFX.rand(-2,2)})
				end
			end
			x.pos=pos
			local side=(sideDir-fwd*Vec3.dot(sideDir,fwd)):getSafeNormal()
			GFX.drawPhoenix(x,pos,fwd,side,e,fold,headUp,1)
			-- wingbeats in the hover throw waves of fire and loose feathers
			for i,bt in ipairs(T.beats) do
				if GFX.once(x,"wave"..i,bt) then
					GFX.shock(x,pos,GFX.bR,GFX.bU,560*S,14*S,{1,.55,.1},.8)
					for j=1,GFX.n(x,26) do
						local sd=(j%2==0) and 1 or -1
						local sz=GFX.rand(14,24)*S
						GFX.add({kind=4,p=pos+R*(sd*GFX.rand(80,260)*S),v=(R*sd+U*GFX.rand(-.5,.5)):getSafeNormal()*(GFX.rand(300,700)*S),
							life=GFX.rand(1,1.5),s0=sz,s1=sz*.6,ramp={GFX_PHOENIX[2],GFX_PHOENIX[3]},grav=200*S,drag=1,
							spin=GFX.rand(3,8),op=.95,emis=1.2,fin=.001,fp=.8})
					end
					GFX.addShake(6*S)
				end
			end
			if GFX.once(x,"screech",T.screech) then
				GFX.shock(x,pos,GFX.bR,GFX.bU,700*S,10*S,{1,.85,.4},.6)
				GFX.flashAt(x,pos,300*S,{1,.8,.4},.15)
				GFX.addShake(10*S)
			end
		end
		-- impact: pillar of fire, a phoenix-shaped burst of feathers, a ring of flame
		if GFX.once(x,"burst",T.impact) then
			local pc=x.base+U*(60*S)
			GFX.blast(x,pc,P,2)
			GFX.flashAt(x,pc,700*S,{1,.85,.5},.35)
			GFX.shock(x,x.base+U*(4*S),x.r,x.f,900*S,26*S,{1,.5,.1},1.1)
			GFX.light(x,pc,{1,.6,.2},90000,3600*S,.02,.15,.8)
			GFX.addShake(26*S)
			-- the burst takes the bird's shape: feathers thrown along two wing arcs and a tail
			for i=1,GFX.n(x,110) do
				local t=GFX.rand(0,1)
				local sd=(i%2==0) and 1 or -1
				local dir
				if i%5==0 then
					dir=(U*-.2+F*.3+R*GFX.rand(-.3,.3)):getSafeNormal()
				else
					dir=(R*(sd*math.cos(t*1.2))+U*(math.sin(t*1.2)+.2)+F*.15):getSafeNormal()
				end
				local sz=GFX.rand(16,30)*S
				GFX.add({kind=4,p=pc+dir*(GFX.rand(0,60)*S),v=dir*(GFX.rand(600,1300)*S),life=GFX.rand(1.3,2),s0=sz,
					s1=sz*.5,ramp={GFX_PHOENIX[1],GFX_PHOENIX[3],GFX_PHOENIX[4]},grav=250*S,drag=.9,spin=GFX.rand(3,8),
					op=.95,emis=1.3,fin=.001,fp=.7})
			end
			x.pillar=T.impact
		end
		if x.pillar then
			local t=age-x.pillar
			if t<.8 then
				for i=1,GFX.rate(x,"pillar",260*(1-t/.8)) do
					GFX.add({kind=1,p=x.base+GFX.rdir(x)*(50*S)+U*(20*S),v=U*(GFX.rand(700,1200)*S)+GFX.rdir(x)*(80*S),
						life=GFX.rand(.5,.8),s0=30*S,s1=90*S,ramp=P.fire,drag=1.2,grav=-80*S,fin=.04,fp=1.4,spin=GFX.rand(-2,2)})
				end
				-- a ring of flame running out across the floor
				local rr=(100+t*900)*S
				for i=1,GFX.rate(x,"floorRing",220*(1-t/.8)) do
					local th=GFX.rand(0,6.2832)
					GFX.add({kind=1,p=x.base+(x.r*math.cos(th)+x.f*math.sin(th))*rr+U*(10*S),v=U*(GFX.rand(150,350)*S),
						life=GFX.rand(.35,.6),s0=20*S,s1=55*S,ramp=P.fire,drag=1,grav=-100*S,fin=.04,fp=1.4})
				end
			end
			if t<1.6 then
				for i=1,GFX.rate(x,"embers",50*(1-t/1.6)) do
					local th=GFX.rand(0,6.2832)
					GFX.add({kind=1,p=x.base+(x.r*math.cos(th)+x.f*math.sin(th))*(GFX.rand(30,200)*S),
						v=(x.f*math.cos(th)-x.r*math.sin(th))*(GFX.rand(150,300)*S)+U*(GFX.rand(200,500)*S),
						life=GFX.rand(1.2,1.8),s0=GFX.rand(5,9)*S,s1=2*S,ramp=P.ember,drag=.8,grav=60*S,tw=GFX.rand(10,20)})
				end
			end
		end
	end,
}

-- 19: HYPERDRIVE PORTAL ------------------------------------------------------------------------
-- A neon portal tears open over the goal: a double rim with dashes racing round it and a swirling
-- tunnel of rings falling away into a dark hole, with warp streaks rushing out toward the camera.
-- Then it jumps: a white flash, a radial burst of warp streaks, and the portal collapses.
GFX_PAL_WARP={flash={.9,.95,1},ring={.2,1,1},ring2={1,.3,.9},light={.5,.6,1},
	spark={{1,1,1},{.3,1,1},{.9,.3,1}},
	fire={{1,1,1},{.3,.9,1},{.7,.2,1},{.05,.02,.15}},
	ember={{1,1,1},{.4,1,1},{1,.4,.9}},
	smoke={{.1,.05,.18},{.03,.02,.06}}}

GFX_DEFS[19]={
	init=function(x)
		x.pc=x.o+x.u*(30*x.S)
		x.TJ=.55*x.D
		GFX.light(x,x.pc,{.6,.4,1},25000,2400*x.S,.2*x.D,.35*x.D,.2)
	end,
	update=function(x,age,d)
		local D,S,c,TJ=x.D,x.S,x.pc,x.TJ
		local BR,BU=GFX.bR,GFX.bU
		local Fc=(GFX.cp-c):getSafeNormal()
		local P=GFX_PAL_WARP
		if age<TJ+.08*D then
			local open=goalFxEaseOut(age/(.18*D))
			local col=(age>TJ) and (1-goalFxSmooth((age-TJ)/(.08*D))) or 1
			local rad=260*S*open*col
			GFX.ring(c,BR,BU,rad,7*S,64,.2,1,1,.9)
			GFX.ring(c,BR,BU,rad*1.08,3*S,64,1,.3,.9,.7)
			for q=0,5 do
				local a0=age*2.5+q*1.047
				GFX.arc(c,BR,BU,rad*1.18,3*S,a0,a0+.5,6,.6,1,1,.8)
			end
			for q=0,3 do
				local a0=-age*3.4+q*1.57
				GFX.arc(c,BR,BU,rad*.9,3*S,a0,a0+.7,6,1,.4,1,.7)
			end
			for j=1,9 do
				-- the tunnel: rings falling away from the camera, twisting
				local f=((j/9)+age*.8)%1
				local rot=age*2*(1+f)
				GFX.ring(c-Fc*(f*900*S),BR*math.cos(rot)+BU*math.sin(rot),BU*math.cos(rot)-BR*math.sin(rot),
					rad*(1-f*.75),(5-3*f)*S,36,.2+.8*f,1-.7*f,1,.6*(1-f)*open*col)
			end
			GFX.disc(c-Fc*(40*S),rad*.75,LinearColor.new(.01,0,.03,.85*open*col))
			for i=1,GFX.rate(x,"warp",220*open*col) do
				local th=GFX.rand(0,6.2832)
				local rd=BR*math.cos(th)+BU*math.sin(th)
				local cc=(GFX.rand()<.5) and {{1,1,1},{.3,1,1}} or {{1,1,1},{1,.4,.9}}
				GFX.add({kind=2,p=c-Fc*(GFX.rand(100,700)*S)+rd*(rad*GFX.rand(.1,.7)),
					v=Fc*(GFX.rand(1500,2600)*S)+rd*(GFX.rand(200,500)*S),life=GFX.rand(.25,.45),s0=2.5*S,s1=1*S,
					ramp=cc,st=.07})
			end
			GFX.glow(c,rad*.5,.5,.6,1,.3*open*col,age,.4)
		end
		if GFX.once(x,"jump",TJ) then
			GFX.flashAt(x,c,380*S,{.9,.95,1},.35)
			GFX.blast(x,c,P,2)
			for i=1,GFX.n(x,160) do
				local th=GFX.rand(0,6.2832)
				local rd=BR*math.cos(th)+BU*math.sin(th)
				GFX.add({kind=2,p=c,v=rd*(GFX.rand(1500,2600)*S)+Fc*(GFX.rand(0,800)*S),life=GFX.rand(.4,.7),s0=3*S,
					s1=.5*S,ramp=P.spark,drag=1,st=.08})
			end
			GFX.shock(x,c,BR,BU,700*S,10*S,P.ring,.6)
			GFX.shock(x,c,BR,BU,560*S,8*S,P.ring2,.8)
			GFX.light(x,c,{.5,.7,1},80000,3000*S,.02,.05,.5)
			GFX.addShake(20*S)
		end
	end,
}

-- 20: REALITY BREAK ----------------------------------------------------------------------------
-- Glowing cracks spread across thin air in front of the goal, light leaking through them, until
-- the whole pane of space shatters: real glass shards spin out toward the camera, revealing a
-- starry void behind. The void swirls for a moment, then implodes and blows out in a violet blast.
function GFX.rbPoint(x,u,v) return x.rbC+x.r*u+x.u*v end

GFX_DEFS[20]={
	init=function(x)
		local S=x.S
		x.rbC=x.o+x.u*(30*S)
		x.TS,x.TC=.42*x.D,.78*x.D
		local Rr=300*S
		-- break the pane into triangles: rings of jittered points, zipped together
		local rings={{{0,0}}}
		for k=1,4 do
			local n=4+4*k
			local ring={}
			local off=GFX.rand(0,1)
			for j=0,n-1 do
				local th=(j+off+GFX.rand(-.25,.25))/n*6.2832
				local rr=Rr*k/4*(1+GFX.rand(-.08,.08))
				ring[#ring+1]={math.cos(th)*rr,math.sin(th)*rr}
			end
			rings[#rings+1]=ring
		end
		x.shards={}
		local function add(a,b,c)
			local cu,cv=(a[1]+b[1]+c[1])/3,(a[2]+b[2]+c[2])/3
			local dist=math.sqrt(cu*cu+cv*cv)
			x.shards[#x.shards+1]={a=a,b=b,c=c,cu=cu,cv=cv,t=dist/Rr*.28*x.D+GFX.rand(0,.05*x.D)}
		end
		for j=1,#rings[2] do add(rings[1][1],rings[2][j],rings[2][(j%#rings[2])+1]) end
		for k=2,4 do
			local inner,outer=rings[k],rings[k+1]
			local ni,no=#inner,#outer
			local i,j=1,1
			while i<=ni or j<=no do
				if j>no or (i<=ni and i/ni<j/no) then
					add(inner[((i-1)%ni)+1],inner[(i%ni)+1],outer[((j-1)%no)+1])
					i=i+1
				else
					add(inner[((i-1)%ni)+1],outer[((j-1)%no)+1],outer[(j%no)+1])
					j=j+1
				end
			end
		end
		x.stars={}
		for i=1,60 do
			local th,rr=GFX.rand(0,6.2832),math.sqrt(GFX.rand())*Rr*.9
			x.stars[i]={u=math.cos(th)*rr,v=math.sin(th)*rr,ph=GFX.rand(0,6)}
		end
	end,
	update=function(x,age,d)
		local D,S,TS,TC=x.D,x.S,x.TS,x.TC
		local Rr=300*S
		local P=GFX_PAL_VOID
		local nrm=x.f
		if age<TS then
			-- cracks spreading out from the centre, with a faint glass sheen on the pane
			local trem=goalFxSmooth((age-.25*D)/(TS-.25*D))
			local gk=GFX.K
			for _,sh in ipairs(x.shards) do
				if age>sh.t then
					local k=math.min(1,(age-sh.t)/(.05*D))
					local off=nrm*(math.sin(age*40+sh.cu)*3*S*trem)
					local A=GFX.rbPoint(x,sh.a[1],sh.a[2])+off
					local B=GFX.rbPoint(x,sh.b[1],sh.b[2])+off
					local C=GFX.rbPoint(x,sh.c[1],sh.c[2])+off
					local fl=(.7+.3*math.sin(age*30+sh.cv))*k
					WorldDraw.drawLine(A,B,.85*gk*fl,.75*gk*fl,gk*fl,2,0)
					WorldDraw.drawLine(B,C,.85*gk*fl,.75*gk*fl,gk*fl,2,0)
					WorldDraw.drawTriangle(A,B,C,LinearColor.new(.15*gk,.12*gk,.25*gk,.08*k),0)
				end
			end
			GFX.glow(x.rbC,Rr*(.3+.5*trem),.8,.6,1,.25+.4*trem,age,.4)
			if trem>0 then GFX.addShake(trem*3*S) end
		end
		if GFX.once(x,"shatter",TS) then
			-- the pane breaks: every shard becomes a spinning piece of glass
			x.flying={}
			for _,sh in ipairs(x.shards) do
				local cen=GFX.rbPoint(x,sh.cu,sh.cv)
				local radial=(x.r*sh.cu+x.u*sh.cv)
				if radial:length()<.01 then radial=x.u end
				radial=radial:getSafeNormal()
				x.flying[#x.flying+1]={p=cen,
					v=radial*(GFX.rand(200,600)*S)+nrm*(GFX.rand(300,900)*S)+x.u*(GFX.rand(-100,200)*S),
					ax=GFX.rdir(x):getSafeNormal(),w=GFX.rand(3,9),
					la=GFX.rbPoint(x,sh.a[1],sh.a[2])-cen,lb=GFX.rbPoint(x,sh.b[1],sh.b[2])-cen,lc=GFX.rbPoint(x,sh.c[1],sh.c[2])-cen}
			end
			x.shatterT=age
			GFX.flashAt(x,x.rbC,320*S,{.9,.85,1},.3)
			GFX.shock(x,x.rbC,GFX.bR,GFX.bU,600*S,10*S,{.85,.7,1},.7)
			GFX.light(x,x.rbC,{.7,.5,1},50000,2600*S,.02,TC-TS,.3)
			GFX.addShake(16*S)
			for i=1,GFX.n(x,80) do
				local dir=(GFX.rdir(x)+nrm*.8):getSafeNormal()
				GFX.add({kind=1,p=x.rbC+GFX.rdir(x)*(GFX.rand(0,200)*S),v=dir*(GFX.rand(200,700)*S),life=GFX.rand(.6,1.1),
					s0=GFX.rand(4,7)*S,s1=1*S,ramp={{1,1,1},{.8,.7,1}},drag=1.5,tw=GFX.rand(15,30)})
			end
		end
		if x.flying then
			local t=age-x.shatterT
			local a=1-goalFxSmooth(t/1.4)
			if a>.01 then
				local gk=GFX.K
				for _,f in ipairs(x.flying) do
					local p=f.p+f.v*t-x.u*(250*S*t*t)
					local ang=f.w*t
					local ca,sa=math.cos(ang),math.sin(ang)
					local function rot(v) return v*ca+Vec3.cross(f.ax,v)*sa+f.ax*(Vec3.dot(f.ax,v)*(1-ca)) end
					local A,B,C=p+rot(f.la),p+rot(f.lb),p+rot(f.lc)
					local n=Vec3.cross(B-A,C-A):getSafeNormal()
					local glint=math.abs(Vec3.dot(n,x.f))^6
					local k=gk*(.25+.75*glint)
					WorldDraw.drawTriangle(A,B,C,LinearColor.new(.6*k,.55*k,.9*k,.55*a),0)
					WorldDraw.drawLine(A,B,.9*gk*a,.85*gk*a,gk*a,1.5,0)
					WorldDraw.drawLine(B,C,.9*gk*a,.85*gk*a,gk*a,1.5,0)
					WorldDraw.drawLine(C,A,.9*gk*a,.85*gk*a,gk*a,1.5,0)
				end
			end
		end
		if age>=TS and age<TC+.06*D then
			-- the void behind: dark, starry, swirling, then it implodes
			local open=goalFxEaseOut((age-TS)/(.08*D))
			local close=1-goalFxSmooth((age-TC)/(.06*D))
			local rad=Rr*.95*open*close
			local vc=x.rbC-nrm*(20*S)
			GFX.flatDisc(vc,x.r,x.u,rad,LinearColor.new(.02,.0,.05,.92))
			GFX.ring(vc+nrm*(1*S),x.r,x.u,rad,5*S,48,.8,.5,1,.8*open*close)
			for i=1,3 do
				local th=age*(.6+i*.25)+i*2
				GFX.glow(vc+nrm*(2*S)+(x.r*math.cos(th)+x.u*math.sin(th))*(rad*.35),rad*.45,
					(i==2) and .2 or .6,.2,1,.25*open*close,age,.1)
			end
			local sk=GFX.K
			for _,st in ipairs(x.stars) do
				local u,v=st.u*open*close,st.v*open*close
				local tw=.4+.6*math.abs(math.sin(age*5+st.ph))
				GFX.diamond(vc+nrm*(3*S)+x.r*u+x.u*v,2.5*S,0,LinearColor.new(sk*tw,sk*tw,sk*tw,tw))
			end
		end
		if GFX.once(x,"implode",TC+.06*D) then
			GFX.blast(x,x.rbC,P,1.8)
			GFX.addShake(20*S)
		end
	end,
}

-- 21: SPLASH -----------------------------------------------------------------------------------
-- Comic-book water burst (original art in a pop-art style). The moment the goal goes in, a big
-- spiky cartoon splat pops open in the goal mouth: dark blue outline, light blue fill, white
-- shines and chunky blobs round the rim. It wobbles while cartoon drops (teardrops with outlines)
-- spray everywhere, then it breaks apart into flying blobs. In front of it a huge red "SPLASH!"
-- with a thick dark outline and white edge bounces in, tilted. A floor ring, light flash and
-- camera shake sell the impact. The game can't play sound, so there is only a hook:
-- GFX.splashSound(event) calls Splash.onSound with "impact" and "burst".
-- (GFX.waterDome / GFX.waterCrown below are from the earlier 3D version and are kept as helpers.)
GFX_WATER={{1,1,1},{.65,.88,1},{.2,.55,1},{.05,.2,.5}}
GFX_PAL_WATER={flash={.8,.95,1},ring={.4,.8,1},ring2={.8,.95,1},light={.4,.7,1},
	spark={{1,1,1},{.7,.9,1},{.3,.6,1}},
	fire={{1,1,1},{.6,.85,1},{.25,.55,1},{.05,.15,.35}},
	ember={{1,1,1},{.7,.9,1},{.3,.6,1}},
	smoke={{.75,.85,.95},{.35,.45,.55}}}
SPLASH_TIMING={burst=1.1,total=2.6}   -- splat hangs until burst, then breaks apart
Splash={onSound=nil}
function GFX.splashSound(ev)
	if Splash.onSound then pcall(Splash.onSound,ev) end
end

-- translucent, lumpy water surface: a dome (or any cap of a sphere) of radius rad and height hgt
function GFX.waterDome(x,c,rad,hgt,a,wob)
	if a<=.01 or rad<=0 then return end
	local U,R,F=x.u,x.r,x.f
	local cp=GFX.cp
	local nLat=({3,4,5,6})[x.qi]
	local nLon=({10,12,16,18})[x.qi]
	local half=((cp-c):getSafeNormal()+x.ld):getSafeNormal()
	local function P(i,j)
		local phi=i/nLat*math.pi*.5
		local th=j/nLon*6.2832
		local bump=1+.09*math.sin(j*3+wob*12)*math.sin(phi*2+wob*7)
		local h=(R*math.cos(th)+F*math.sin(th))*(math.sin(phi)*rad*bump)
		return c+h+U*(math.cos(phi)*hgt*bump),(h*(1/math.max(rad,1))+U*math.cos(phi)):getSafeNormal()
	end
	local k=GFX.K
	for i=0,nLat-1 do
		for j=0,nLon-1 do
			local a0,n0=P(i,j)
			local a1=P(i,j+1)
			local b1=P(i+1,j+1)
			local b0=P(i+1,j)
			local vd=Vec3.dot(n0,(cp-a0):getSafeNormal())
			if vd>-.1 then
				local lit=math.max(0,Vec3.dot(n0,x.ld))
				local sp=math.max(0,Vec3.dot(n0,half))^20*1.2
				local rim=(1-math.max(0,vd))^2*.6
				local sh=(.35+.4*lit+rim)*k
				local lc=LinearColor.new(.35*sh+sp*k,.7*sh+sp*k,1*sh+sp*k,a*(.35+.3*rim))
				WorldDraw.drawTriangle(a0,a1,b1,lc,0)
				WorldDraw.drawTriangle(a0,b1,b0,lc,0)
			end
		end
	end
end

-- the crown: a wall of water from radius r0 at the floor to r1 at height h, with n fingers
-- curling out of its rim (fl = finger length)
function GFX.waterCrown(x,c,r0,r1,h,fl,a,seed)
	if a<=.01 or h<=1 then return end
	local U=x.u
	local cp=GFX.cp
	local n=({10,12,16,20})[x.qi]
	local k=GFX.K
	local S=x.S
	local prevB,prevT=nil,nil
	for j=0,n do
		local th=j/n*6.2832+seed
		local out=x.r*math.cos(th)+x.f*math.sin(th)
		local wob=1+.12*goalFxNoise(j*3.1+seed)
		local b=c+out*r0
		local t=c+out*(r1*wob)+U*(h*wob)
		if prevB then
			local nrm=(out+U*.2):getSafeNormal()
			local vd=Vec3.dot(nrm,(cp-t):getSafeNormal())
			local sh=(.4+.4*math.max(0,Vec3.dot(nrm,x.ld))+(1-math.abs(vd))*.5)*k
			local lc=LinearColor.new(.4*sh,.75*sh,sh,a*.55)
			WorldDraw.drawTriangle(prevB,b,t,lc,0)
			WorldDraw.drawTriangle(prevB,t,prevT,lc,0)
			-- foamy white lip along the top
			WorldDraw.drawLine(prevT,t,k*a,k*a,k*a,2.5,0)
		end
		if j<n and fl>1 then
			-- a finger curling outward off the rim, with a drop on the end
			local tip=t+out*(fl*.8)+U*(fl*.55)
			GFX.tube(x,{t,t+out*(fl*.4)+U*(fl*.5),tip},{7*S,4.5*S,2*S},5,{.5,.8,1},GFX.K*.55*a)
			GFX.glow(tip,7*S,.75,.92,1,a,0,.7)
		end
		prevB,prevT=b,t
	end
end

-- a ring of droplets thrown up and out
function GFX.splashCrown(x,c,rad,n,spd,S)
	for i=1,GFX.n(x,n) do
		local th=i/n*6.2832+GFX.rand(-.1,.1)
		local dirH=x.r*math.cos(th)+x.f*math.sin(th)
		local el=GFX.rand(.8,1.3)
		local dir=(dirH*math.cos(el)+x.u*math.sin(el)):getSafeNormal()
		GFX.add({kind=1,p=c+dirH*rad,v=dir*(spd*GFX.rand(.8,1.2)*S),life=GFX.rand(1,1.5),s0=GFX.rand(9,14)*S,s1=5*S,
			ramp=GFX_WATER,grav=1300*S,drag=.3,hot=.4,fin=.02,fp=.6})
		GFX.add({kind=2,p=c+dirH*rad,v=dir*(spd*GFX.rand(1,1.4)*S),life=GFX.rand(.8,1.2),s0=2.5*S,s1=1*S,
			ramp=GFX_WATER,grav=1400*S,drag=.2,st=.03})
	end
end

-- comic splat: a spiky star of water facing the camera, drawn as outline / fill / shine layers,
-- with chunky blobs round the rim. g = how far it has popped open (0..1+), wob animates the edge.
function GFX.comicSplat(x,c,rad,g,wob,a)
	if g<=.01 or a<=.01 then return end
	local R,U=GFX.bR,GFX.bU
	local tc=(GFX.cp-c):getSafeNormal()
	local k=GFX.K*.8
	local ink,fill,sh=GFX_COMIC_INK,GFX_COMIC_FILL,GFX_COMIC_SHINE
	local n=16
	local function star(scale,z,col)
		local pts={}
		for i=0,n do
			local j=i%n
			local th=j/n*6.2832+x.seed
			local spike=(j%2==0) and (1+.35*goalFxNoise(j*3.3+x.seed)) or (.55+.12*goalFxNoise(j*5.1+x.seed))
			local rr=rad*g*scale*spike*(1+.05*math.sin(wob*9+j))
			pts[#pts+1]=c+R*(math.cos(th)*rr)+U*(math.sin(th)*rr*.85)+tc*z
		end
		GFX.fan(c+tc*z,pts,LinearColor.new(col[1]*k,col[2]*k,col[3]*k,a))
	end
	star(1.08,0,ink)
	star(1,1.5*x.S,fill)
	-- chunky blobs riding the rim
	for j=0,n-1,2 do
		local th=j/n*6.2832+x.seed
		local rr=rad*g*(.95+.3*goalFxNoise(j*7.7+x.seed))
		local bp=c+R*(math.cos(th)*rr)+U*(math.sin(th)*rr*.85)+tc*(2*x.S)
		local bs=rad*g*(.14+.06*goalFxNoise(j*2.2))
		GFX.comicBlob(bp,R*bs,U*(bs*.85),a)
	end
	-- inner swirl of lighter water and a big shine
	star(.55,3*x.S,GFX.mixW(fill,.35))
	GFX.comicBlob(c+tc*(4*x.S)-R*(rad*g*.25)+U*(rad*g*.25),R*(rad*g*.18),U*(rad*g*.11),a,false)
	local sk=k*1.2
	GFX.ellipse(c+tc*(5*x.S)-R*(rad*g*.25)+U*(rad*g*.27),R*(rad*g*.12),U*(rad*g*.06),LinearColor.new(sh[1]*sk,sh[2]*sk,sh[3]*sk,a))
end

-- big comic lettering: thick dark outline, red fill, a white inner edge, tilted and popped in
function GFX.comicWord(x,c,text,u,ang,a)
	if a<=.01 then return end
	local R,U=GFX.bR,GFX.bU
	local ax=R*math.cos(ang)+U*math.sin(ang)
	local ay=U*math.cos(ang)-R*math.sin(ang)
	local tc=(GFX.cp-c):getSafeNormal()
	local k=GFX.K*.85
	GFX.memeText(c,text,ax,ay,u,u*1.05,LinearColor.new(.12*k,.02*k,.03*k,a))
	GFX.memeText(c+tc*(2*x.S),text,ax,ay,u,u*.72,LinearColor.new(1*k,.95*k,.9*k,a))
	GFX.memeText(c+tc*(3*x.S),text,ax,ay,u,u*.55,LinearColor.new(1.1*k,.1*k,.06*k,a))
	GFX.memeText(c+tc*(4*x.S)-ax*(u*.15)+ay*(u*.25),text,ax,ay,u,u*.12,LinearColor.new(1.2*k,.55*k,.45*k,a))
end

GFX_DEFS[21]={
	duration=function() return SPLASH_TIMING.total end,
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.sc=x.o+x.u*(10*S)
		x.seed=GFX.rand(0,6)
		GFX.splashSound("impact")
		GFX.flashAt(x,x.sc,300*S,{.85,.95,1},.25)
		GFX.shock(x,x.base+x.f*(70*S)+x.u*(4*S),x.r,x.f,520*S,22*S,{.55,.88,1},.8)
		GFX.light(x,x.sc,{.45,.75,1},55000,2800*S,.02,.25,.6)
		GFX.addShake(16*S)
		-- cartoon drops spraying everywhere, mostly out to the sides and up
		for i=1,GFX.n(x,90) do
			local th=GFX.rand(0,6.2832)
			local dir=(GFX.bR*math.cos(th)+GFX.bU*(math.sin(th)*.8+.25)+(GFX.cp-x.sc):getSafeNormal()*GFX.rand(-.2,.6)):getSafeNormal()
			local sz=GFX.rand(7,16)*S
			GFX.add({kind=6,p=x.sc+dir*(GFX.rand(40,140)*S),v=dir*(GFX.rand(500,1300)*S),life=GFX.rand(.9,1.5),
				s0=sz,s1=sz*.6,ramp={{1,1,1}},grav=900*S,drag=.6,fin=.001,fp=.8})
		end
	end,
	update=function(x,age,d)
		local S,TM=x.S,SPLASH_TIMING
		local c=x.sc
		local a=1-goalFxSmooth((age-(TM.total-.4))/.4)
		-- the splat pops open hard, wobbles while it hangs there, then breaks into blobs
		local pop=GFX.backOut(age/.14)
		local hold=1-goalFxSmooth((age-TM.burst)/.25)
		GFX.comicSplat(x,c,330*S,pop,age,hold*a)
		if GFX.once(x,"break",TM.burst) then
			GFX.splashSound("burst")
			for i=1,GFX.n(x,40) do
				local th=GFX.rand(0,6.2832)
				local dir=(GFX.bR*math.cos(th)+GFX.bU*math.sin(th)*.85):getSafeNormal()
				local sz=GFX.rand(14,26)*S
				GFX.add({kind=6,p=c+dir*(GFX.rand(100,300)*S),v=dir*(GFX.rand(250,700)*S)+x.u*(150*S),
					life=GFX.rand(.8,1.2),s0=sz,s1=sz*.5,ramp={{1,1,1}},grav=1000*S,drag=.6,fin=.001,fp=.7})
			end
		end
		-- a steady drizzle of drops off the splat while it hangs
		if age<TM.burst then
			for i=1,GFX.rate(x,"drip",60) do
				local th=GFX.rand(0,6.2832)
				local dir=(GFX.bR*math.cos(th)+GFX.bU*math.sin(th)*.85):getSafeNormal()
				local sz=GFX.rand(5,10)*S
				GFX.add({kind=6,p=c+dir*(GFX.rand(200,330)*S*pop),v=dir*(GFX.rand(150,400)*S),life=GFX.rand(.6,1),
					s0=sz,s1=sz*.6,ramp={{1,1,1}},grav=900*S,drag=.5,fin=.001,fp=.7})
			end
		end
		-- floor splash ring under it
		if age<1 then
			local fl=x.base+x.f*(70*S)+x.u*(3*S)
			local wv=goalFxEaseOut(age/.6)
			GFX.ring(fl,x.r,x.f,(80+400*wv)*S,(20*(1-wv)+5)*S,40,.5,.85,1,.6*(1-wv))
		end
		-- SPLASH! in front, popping in with a bounce and a shake
		local wa=a*(1-goalFxSmooth((age-(TM.total-.7))/.4))
		if age>.05 then
			local t=age-.05
			local wpop=math.min(GFX.backOut(t/.16),1.2)
			local jit=(t<.35) and (math.sin(t*60)*.02) or 0
			local wc=c-x.u*(60*S)+(GFX.cp-c):getSafeNormal()*(60*S)
			GFX.comicWord(x,wc,"SPLASH!",13*S*wpop,-.12+jit,wa)
		end
	end,
}

-- 22: SNOWMAN SMASH (Christmas) ----------------------------------------------------------------
-- Three snowballs pop out of the goal one on top of the other to build a snowman. A top hat
-- drops onto its head, it gets coal eyes, a smile, buttons, a carrot nose, a red scarf and stick
-- arms, and it waves. Then it shivers and blows apart into snowballs, the hat spinning away.
GFX_DEFS[22]={
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.sb=x.base+x.f*(70*S)
		x.TX=.6*x.D
	end,
	update=function(x,age,d)
		local D,S,TX=x.D,x.S,x.TX
		local U=x.u
		local R=GFX.flatRight(x)
		local Fv=GFX.cp-x.sb
		local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
		local kk=GFX.K*.55
		if age<.95*D then GFX.snowfall(x,40) end
		local snow={.92,.95,1}
		local coal={.04,.04,.05}
		local shiver=0
		if age>.5*D and age<TX then shiver=(age-.5*D)/(TX-.5*D) end
		local jit=R*(math.sin(age*70)*4*S*shiver)
		local r1,r2,r3=95*S,68*S,48*S
		local g1=GFX.backOut((age-.03*D)/(.08*D))
		local g2=GFX.backOut((age-.1*D)/(.08*D))
		local g3=GFX.backOut((age-.17*D)/(.08*D))
		local c1=x.sb+U*(r1*.9)+jit
		local c2=c1+U*(r1*.8+r2*.8)
		local c3=c2+U*(r2*.75+r3*.8)
		if age<TX then
			if g1>0 then GFX.drawSphere(x,c1,r1*g1,snow,kk,1,7,12,.2) end
			if g2>0 then GFX.drawSphere(x,c2,r2*g2,snow,kk,1,6,12,.2) end
			if g3>0 then GFX.drawSphere(x,c3,r3*g3,snow,kk,1,6,12,.2) end
			for i,t in ipairs({.07,.14,.21}) do
				if GFX.once(x,"puff"..i,t*D) then
					local cc=({c1,c2,c3})[i]
					for j=1,GFX.n(x,10) do
						local dir=GFX.rdir(x,.7)
						GFX.add({kind=3,p=cc+dir*(40*S),v=dir*(GFX.rand(80,200)*S),life=GFX.rand(.8,1.2),s0=30*S,s1=90*S,
							ramp={{.95,.97,1},{.6,.65,.7}},op=.35,fin=.05,drag=1.5,spin=GFX.rand(-1,1)})
					end
				end
			end
			-- face, buttons, scarf, arms
			if g3>.9 then
				local fc=c3+F*(r3*.9)
				for sd=-1,1,2 do GFX.drawSphere(x,fc+R*(sd*r3*.35)+U*(r3*.25),5*S,coal,kk,1,3,6) end
				for i=-2,2 do
					local t=i/2
					GFX.drawSphere(x,c3+F*(r3*.88)+R*(t*r3*.42)+U*((t*t*.18-.38)*r3),3.5*S,coal,kk,1,3,6)
				end
				local nb=c3+F*(r3*.95)
				GFX.tube(x,{nb,nb+F*(32*S)+R*(6*S)},{6*S,.5*S},5,{1,.45,.05},kk*1.3)
				GFX.ring(c2+U*(r2*.82),x.r,x.f,r3*.95,8*S,24,.9,.08,.06,.9)
				GFX.beam(c2+U*(r2*.8)+F*(r3*.7)+R*(r3*.4),c2+U*(r2*.2)+F*(r3*.8)+R*(r3*.55),7*S,
					LinearColor.new(.9*kk*1.4,.08*kk,.06*kk,1))
			end
			if g2>.9 then
				for i=-1,1 do GFX.drawSphere(x,c2+F*(r2*.95)+U*(i*r2*.32),4.5*S,coal,kk,1,3,6) end
				for sd=-1,1,2 do
					local wave=(age>.3*D) and math.sin(age*9+sd)*.35 or 0
					local sh=c2+R*(sd*r2*.85)+U*(r2*.2)
					local ang=.55+wave*((sd>0) and 1 or 0)
					local tip=sh+(R*(sd*math.cos(ang))+U*math.sin(ang))*(110*S)
					local bk=kk*1.2
					WorldDraw.drawLine(sh,tip,.35*bk,.2*bk,.08*bk,5,0)
					local tw=sh+(tip-sh)*.7
					WorldDraw.drawLine(tw,tw+U*(22*S)+R*(sd*10*S),.35*bk,.2*bk,.08*bk,3,0)
					WorldDraw.drawLine(tip,tip+R*(sd*16*S)+U*(10*S),.35*bk,.2*bk,.08*bk,3,0)
				end
			end
		end
		-- top hat: drops in, and later flies off spinning
		local hatT=.25*D
		if age>hatT then
			local hp,hU,ha
			if age<TX then
				local k=GFX.backOut((age-hatT)/(.08*D))
				hp=c3+U*(r3*.85+(1-math.min(k,1))*300*S)
				hU,ha=U,1
			else
				local t=age-TX
				local ang=7*t
				hU=U*math.cos(ang)+R*math.sin(ang)
				hp=x.hatP+U*(t*800*S-t*t*450*S)+R*(t*150*S)
				ha=1-goalFxSmooth(t/(.35*D))
			end
			if ha>.01 then
				local hR=R*math.cos(.3)+F*math.sin(.3)
				local hF=F*math.cos(.3)-R*math.sin(.3)
				local hb={.05,.05,.06}
				GFX.drawBox(x,hp,hR*(r3*1.05),hF*(r3*1.05),hU*(3*S),hb,kk,ha)
				GFX.drawBox(x,hp+hU*(r3*.55),hR*(r3*.62),hF*(r3*.62),hU*(r3*.55),hb,kk,ha)
				GFX.drawBox(x,hp+hU*(r3*.18),hR*(r3*.64),hF*(r3*.64),hU*(r3*.12),{.85,.08,.06},kk*1.2,ha)
			end
			x.hatP=x.hatP or hp
			if age<TX then x.hatP=hp end
		end
		if GFX.once(x,"smash",TX) then
			GFX.blast(x,c2,GFX_PAL_ICE,1.5)
			for i=1,GFX.n(x,40) do
				local dir=(GFX.rdir(x)+U*.9):getSafeNormal()
				local bs=GFX.rand(18,32)*S
				GFX.add({kind=1,p=c2+dir*(GFX.rand(0,80)*S),v=dir*(GFX.rand(400,1000)*S),life=GFX.rand(1.2,1.8),s0=bs,
					s1=bs*.8,ramp={{1,1,1},{.85,.9,.95}},grav=900*S,drag=.4,hot=.2,fin=.01,fp=.5})
			end
			for i=1,GFX.n(x,10) do
				local dir=(GFX.rdir(x)+U):getSafeNormal()
				GFX.add({kind=4,p=c3,v=dir*(GFX.rand(300,700)*S),life=GFX.rand(1,1.5),s0=6*S,s1=5*S,ramp={coal},
					grav=900*S,drag=.4,spin=GFX.rand(5,10),op=1,emis=.6,fin=.001,fp=.5})
			end
			GFX.add({kind=4,p=c3+F*(r3),v=(F+U):getSafeNormal()*(700*S),life=1.6,s0=30*S,s1=28*S,ramp={{1,.45,.05}},
				grav=900*S,drag=.3,spin=9,op=1,emis=1,fin=.001,fp=.4})
			for i=1,GFX.n(x,16) do
				local dir=GFX.rdir(x,.7)
				GFX.add({kind=3,p=c2+dir*(GFX.rand(0,100)*S),v=dir*(GFX.rand(100,260)*S),life=GFX.rand(1.4,2),s0=60*S,
					s1=200*S,ramp={{.95,.97,1},{.55,.6,.65}},op=.4,fin=.05,drag=1.2,spin=GFX.rand(-.6,.6)})
			end
			GFX.light(x,c2,{.8,.9,1},40000,2400*S,.03,.1,.5)
			GFX.addShake(16*S)
		end
	end,
}

-- 23: ORNAMENT SHATTER (Christmas) -------------------------------------------------------------
-- A giant glossy red Christmas bauble with a gold cap and band lowers over the goal on a gold
-- thread, swinging and sparkling. Light pulses inside it, cracks race across its surface, and it
-- shatters into glass shards, glitter and confetti.
GFX_DEFS[23]={
	init=function(x)
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.TX=.56*x.D
	end,
	update=function(x,age,d)
		local D,S,TX=x.D,x.S,x.TX
		local U=x.u
		local rad=150*S
		local e=goalFxEaseOut(age/(.25*D))
		local c=x.o+U*((40+(1-e)*600)*S)+x.r*(math.sin(age*2.2)*40*S*(1-e*.5))
		local kk=GFX.K*.55
		if age<.95*D then GFX.snowfall(x,30) end
		if age<TX then
			x.orn=c
			local gk=GFX.K
			WorldDraw.drawLine(c+U*(rad*1.15),c+U*(1100*S),gk,.8*gk,.3*gk,2,0)
			GFX.drawSphere(x,c,rad,{.85,.05,.08},kk,1,10,16,1.2)
			-- gold band round the middle, with a glitter pattern that turns with it
			GFX.ring(c,x.r,x.f,rad*1.01,6*S,40,1,.8,.25,.8)
			local view=(GFX.cp-c):getSafeNormal()
			for i=1,14 do
				local th=age*.8+i*.449
				local lat=(i%2==0) and .45 or -.45
				local dir=((x.r*math.cos(th)+x.f*math.sin(th))*math.cos(lat)+U*math.sin(lat)):getSafeNormal()
				if Vec3.dot(dir,view)>.15 then
					local tw=.5+.5*math.sin(age*7+i)
					GFX.glow(c+dir*(rad*1.02),5*S,1,.9,.6,tw,0,.8)
				end
			end
			GFX.drawBox(x,c+U*(rad*1.02),x.r*(rad*.2),x.f*(rad*.2),U*(16*S),{1,.78,.25},kk*1.3,1)
			GFX.ring(c+U*(rad*1.02+34*S),x.r,U,10*S,2*S,16,1,.8,.3,.9)
			-- inner light pulsing, getting stronger before it breaks
			local charge=goalFxSmooth((age-.4*D)/(TX-.4*D))
			GFX.glow(c+view*(rad*.95),rad*(.35+.25*charge),1,.4+.4*charge,.3+.3*charge,.3+.5*charge,age,.5)
			if charge>.3 then
				local ck=gk*charge*1.3
				for ci=1,6 do
					local seed=ci*13.7
					local th=goalFxNoise(seed)*6.2832
					local lat=(goalFxNoise(seed+1)-.5)*1.2
					local prev=nil
					for j=0,5 do
						local tt=th+j*.12*(goalFxNoise(seed+j)-.3)*charge*3
						local ll=lat+(goalFxNoise(seed+j*2.1)-.5)*.5*j/5*charge
						local dir=((x.r*math.cos(tt)+x.f*math.sin(tt))*math.cos(ll)+U*math.sin(ll)):getSafeNormal()
						local q=c+dir*(rad*1.01)
						if prev and Vec3.dot(dir,view)>0 then WorldDraw.drawLine(prev,q,ck,ck,ck,2,0) end
						prev=q
					end
				end
				GFX.addShake(charge*3*S)
			end
		end
		if GFX.once(x,"shatter",TX) then
			local oc=x.orn or c
			GFX.blast(x,oc,GFX_PAL_XMAS,1.5)
			for i=1,GFX.n(x,90) do
				local dir=GFX.rdir(x):getSafeNormal()
				local sz=GFX.rand(14,30)*S
				GFX.add({kind=4,p=oc+dir*rad,v=dir*(GFX.rand(400,1100)*S),life=GFX.rand(1.3,2),s0=sz,s1=sz*.8,
					ramp={(i%5==0) and {1,.8,.3} or {.9,.08,.1}},grav=700*S,drag=.5,spin=GFX.rand(4,10),op=.8,emis=1.1,
					fin=.001,fp=.5})
			end
			for i=1,GFX.n(x,150) do
				local dir=GFX.rdir(x,.8)
				GFX.add({kind=1,p=oc+dir*(GFX.rand(0,rad)),v=dir*(GFX.rand(200,700)*S),life=GFX.rand(1,1.8),
					s0=GFX.rand(3,6)*S,s1=1.5*S,ramp={GFX_XMAS_COLS[math.min(5,1+math.floor(GFX.rand()*5))]},drag=1.6,
					grav=120*S,tw=GFX.rand(15,30)})
			end
			GFX.add({kind=4,quad=true,p=oc+U*rad,v=U*(800*S),life=1.4,s0=26*S,s1=24*S,ramp={{1,.78,.25}},grav=900*S,
				drag=.3,spin=8,op=1,emis=1.1,fin=.001,fp=.4})
			GFX.shock(x,oc,GFX.bR,GFX.bU,560*S,12*S,{1,.3,.25},.9)
			GFX.light(x,oc,{1,.6,.5},50000,2600*S,.03,.1,.6)
			GFX.addShake(18*S)
		end
	end,
}

-- 24: PRIVATE PROPERTY (Special) ----------------------------------------------------------------
-- Based on the "State Property" / "Hit the road, dude" fishing clip: a guy is fishing, an old man
-- in a white pickup rolls up, leans out the window and asks who said he could fish here; the guy
-- says he thought it was state property; the old man goes "State?" ... "STATE?!" and declares it
-- private property, then tells him to hit the road.
-- The landowner here is an ORIGINAL cartoon farmer (no likeness of the real man), the truck and
-- people are built from shapes, the lines are paraphrased into comic speech bubbles, and the
-- ~15 s clip is squeezed to ~5.5 s. The scripting API can't play sound, so there is only a hook:
--   MemePP.onSound = function(event) ... end  -- "engine", "brakes", "line", "state", "private",
--                                             -- "thud", "honk"
-- Every beat is in MEME_PP_LINES / MEME_PP_TIMING (seconds from the goal).
MEME_PP_TIMING={
	arrive0=.3,     -- truck rolls in from the right
	arrive1=1.1,    -- ...and brakes to a stop
	sign=3.42,      -- the PRIVATE PROPERTY sign slams into the ground
	flee=3.6,       -- the fisherman legs it, dropping his rod
	fish=4.55,      -- even the fish jumps out and follows him
	honk=5.0,       -- parting honk
	total=5.6,
}
MEME_PP_LINES={
	{t=1.15,d=.8,who="driver",text="WHO SAID YOU CAN FISH HERE?",ev="line"},
	{t=1.95,d=.62,who="fisher",text="I THOUGHT IT WAS STATE PROPERTY",ev="line"},
	{t=2.62,d=.38,who="driver",text="STATE?",ev="state"},
	{t=3.0,d=.36,who="driver",text="STATE?!",ev="state"},
	{t=3.38,d=1.05,who="driver",text="THIS IS PRIVATE PROPERTY!",ev="private"},
	{t=4.45,d=.75,who="driver",text="HIT THE ROAD, DUDE!",ev="line"},
}
MemePP={onSound=nil}
function MemePP.sound(ev)
	if MemePP.onSound then pcall(MemePP.onSound,ev) end
end

-- block capitals from the GFX_HAND font, centred on c in the plane of ax (right) / ay (up)
function GFX.memeText(c,text,ax,ay,u,w,lc)
	local n=#text
	local x0=-(n*5.2-1.2)*u*.5
	for i=1,n do
		local g=GFX_HAND[string.sub(text,i,i)]
		if g then
			local ox=x0+(i-1)*5.2*u
			for _,st in ipairs(g) do
				local prev=nil
				for _,v in ipairs(st) do
					local q=c+ax*(ox+v[1]*u)+ay*((v[2]-3)*u)
					if prev then GFX.beam(prev,q,w,lc) end
					prev=q
				end
			end
		end
	end
end

-- comic speech bubble: white oval with a black outline, a tail pointing at the speaker, and the
-- line in black capitals. pop 0..1 scales it in.
function GFX.memeBubble(x,at,text,tailTo,pop,a)
	if pop<=.01 or a<=.01 then return end
	local S=x.S
	local R,U=GFX.flatRight(x),x.u
	local tc=(GFX.cp-at):getSafeNormal()
	local u=math.min(5*S,330*S/(#text*5.2))*pop
	local w=#text*5.2*u*.5+16*S*pop
	local h=3.8*u+12*S*pop
	local k=GFX.K*.9
	local white=LinearColor.new(k,k,k,a)
	local black=LinearColor.new(.01,.01,.01,a)
	local base=at-U*(h*.9)
	GFX.ellipse(at-tc*(1.5*S),R*(w*1.12+4*S),U*(h*1.3+4*S),black)
	WorldDraw.drawTriangle(base-R*(w*.2)-tc*(1.5*S),base+R*(w*.05)-tc*(1.5*S),tailTo-tc*(1.5*S),black,0)
	GFX.ellipse(at,R*(w*1.12),U*(h*1.3),white)
	WorldDraw.drawTriangle(base-R*(w*.16),base+R*(w*.02),tailTo+(at-tailTo):getSafeNormal()*(4*S),white,0)
	GFX.memeText(at+tc*(1.5*S),text,R,U,u,u*.32,black)
end

-- the white pickup. T = the way it faces, F = its side toward the camera. wheelAng spins the
-- wheels, kk = shading brightness, a = fade
function GFX.memeTruck(x,c,T,U,F,wheelAng,kk,a)
	local S=x.S
	local white,glass,grey,dark={.92,.92,.95},{.06,.08,.1},{.45,.46,.48},{.05,.05,.06}
	local function B(t,f,u,ht,hf,hu,col,k2)
		GFX.drawBox(x,c+T*(t*S)+F*(f*S)+U*(u*S),T*(ht*S),F*(hf*S),U*(hu*S),col,kk*(k2 or 1),a)
	end
	B(0,0,55,175,70,28,white)             -- body
	B(110,0,92,65,68,10,white)            -- hood
	B(0,0,125,45,68,42,white)             -- cab
	B(5,0,140,35,69,20,glass)             -- side windows
	B(46,0,140,2,62,18,glass)             -- windscreen
	for sd=-1,1,2 do B(-110,sd*66,95,65,4,14,white) end   -- bed sides
	B(-174,0,95,4,68,14,white)            -- tailgate
	B(-110,0,84,65,62,2,grey)             -- bed floor
	B(178,0,48,5,72,9,grey)               -- front bumper
	B(-178,0,48,5,72,9,grey)              -- rear bumper
	B(176,0,85,2,40,10,dark)              -- grille
	B(52,74,150,6,6,5,grey)               -- mirror
	WorldDraw.drawLine(c+T*(-40*S)+F*(70.5*S)+U*(40*S),c+T*(-40*S)+F*(70.5*S)+U*(100*S),.2*kk,.2*kk,.22*kk,1.5,0)
	for _,wt in ipairs({115,-115}) do
		for sd=-1,1,2 do
			local w=c+T*(wt*S)+F*(sd*70*S)+U*(30*S)
			GFX.tube(x,{w-F*(12*S),w+F*(12*S)},{30*S,30*S},10,dark,kk)
			if sd>0 then
				local face=w+F*(12.5*S)
				GFX.flatDisc(face,T,U,30*S,LinearColor.new(.04*kk,.04*kk,.05*kk,a))
				GFX.flatDisc(face+F*(.5*S),T,U,14*S,LinearColor.new(.6*kk,.6*kk,.62*kk,a))
				for sp=0,2 do
					local ang=wheelAng+sp*2.094
					local d=T*math.cos(ang)+U*math.sin(ang)
					WorldDraw.drawLine(face+F*(1*S),face+F*(1*S)+d*(13*S),.15*kk,.15*kk,.16*kk,2,0)
				end
			end
		end
	end
	for sd=-1,1,2 do
		GFX.glow(c+T*(180*S)+F*(sd*50*S)+U*(80*S),9*S,1,.95,.8,.8*a,0,.8)
		GFX.glow(c+T*(-180*S)+F*(sd*55*S)+U*(85*S),7*S,1,.1,.05,.7*a,0,.4)
	end
end

-- the original grumpy farmer leaning out of the driver's window
function GFX.memeDriver(x,hp,R,U,talk,anger,kk,a)
	local S=x.S
	local Fv=GFX.cp-hp
	local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
	local skin={.85,.6,.47}
	GFX.drawSphere(x,hp,22*S,skin,kk,a,6,10,.1)
	local cap={.75,.12,.08}
	GFX.drawBox(x,hp+U*(15*S),R*(21*S),F*(21*S),U*(9*S),cap,kk,a)
	GFX.drawBox(x,hp+U*(9*S)+F*(20*S),R*(19*S),F*(12*S),U*(2*S),cap,kk,a)
	local face=hp+F*(21*S)
	local blk=LinearColor.new(.02,.02,.02,a)
	local wk=GFX.K*.8
	local whiteLc=LinearColor.new(wk,wk,wk,a)
	for sd=-1,1,2 do
		GFX.ellipse(face+R*(sd*8*S)+U*(4*S),R*(2.5*S),U*(2.5*S),blk)
		-- bushy white eyebrows, angled down to the middle when angry
		GFX.beam(face+R*(sd*3*S)+U*((9-anger*3)*S),face+R*(sd*13*S)+U*((11+anger*2)*S),2.2*S,whiteLc)
	end
	-- big white moustache and a mouth that flaps while he talks
	GFX.ellipse(face+U*(-5*S)+F*(.5*S),R*(13*S),U*(4*S),whiteLc)
	GFX.ellipse(face+U*((-11-talk*3)*S),R*(6*S),U*((1+talk*5)*S),LinearColor.new(.25*kk,.03*kk,.03*kk,a))
end

-- the fisherman (original): bucket hat, green jacket. run 0..1 = legs going, phase drives them
function GFX.memeFisher(x,feet,R,U,run,phase,kk,a)
	local S=x.S
	local Fv=GFX.cp-feet
	local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
	local jacket,pants,skin,hat={.25,.45,.2},{.25,.25,.35},{.85,.65,.5},{.55,.55,.35}
	for sd=-1,1,2 do
		local swing=math.sin(phase+sd*1.6)*run
		local hip=feet+U*(42*S)+R*(sd*7*S)
		local foot=feet+R*(sd*7*S+swing*22*S)+U*(math.max(0,-swing)*10*S)
		GFX.tube(x,{hip,foot},{6*S,5*S},5,pants,kk)
	end
	GFX.drawBox(x,feet+U*(62*S),R*(17*S),F*(11*S),U*(22*S),jacket,kk,a)
	local hd=feet+U*(96*S)
	GFX.drawSphere(x,hd,14*S,skin,kk,a,5,8,.1)
	GFX.drawBox(x,hd+U*(11*S),R*(12*S),F*(12*S),U*(5*S),hat,kk,a)
	GFX.flatDisc(hd+U*(7*S),x.r,x.f,21*S,LinearColor.new(hat[1]*kk*.7,hat[2]*kk*.7,hat[3]*kk*.7,a))
	local face=hd+F*(13*S)
	local blk=LinearColor.new(.02,.02,.02,a)
	for sd=-1,1,2 do GFX.ellipse(face+R*(sd*5*S)+U*(2*S),R*(2*S),U*((2+run*2)*S),blk) end
	return feet+U*(66*S)+R*(18*S)   -- where his hands are
end

GFX_DEFS[24]={
	duration=function() return MEME_PP_TIMING.total end,
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.sc=x.base+x.f*(60*S)
		GFX.flashAt(x,x.base+x.u*(50*S),200*S,{.8,.95,1},.35)
		GFX.shock(x,x.base+x.u*(4*S),x.r,x.f,380*S,14*S,{.5,.85,1},.8)
		GFX.blast(x,x.base+x.u*(60*S),GFX_PAL_WATER,.7)
	end,
	update=function(x,age,d)
		local S,TM=x.S,MEME_PP_TIMING
		local U=x.u
		local R=GFX.flatRight(x)
		local Fv=GFX.cp-x.sc
		local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
		local kk=GFX.K*.5
		local a=1-goalFxSmooth((age-(TM.total-.35))/.35)
		local sc=x.sc

		-- the pond
		local pond=sc-R*(120*S)+F*(60*S)+U*(3*S)
		local pk=goalFxEaseOut(age/.3)*a
		GFX.ellipse(pond,R*(230*S*pk),F*(110*S*pk),LinearColor.new(.05*GFX.K,.25*GFX.K,.55*GFX.K,.55*pk))
		for j=0,1 do
			local f=(age*.9+j*.5)%1
			GFX.ring(pond+U*(1*S),R,F,f*200*S,2*S,32,.6,.85,1,.4*(1-f)*pk)
		end
		for i=1,6 do
			local rb=pond+R*((-200+i*25)*S)-F*(100*S)
			local rk=kk*1.2
			WorldDraw.drawLine(rb,rb+U*((40+i%3*15)*S)+R*(math.sin(age*2+i)*4*S),.15*rk,.45*rk,.12*rk,3,0)
		end

		-- the fisherman: fishing, then legging it
		local fBase=sc-R*(330*S)+F*(70*S)
		local run,phase=0,0
		if age>TM.flee then
			local t=age-TM.flee
			run=1
			phase=t*22
			fBase=fBase-R*(t*t*350*S+t*250*S)+U*(math.abs(math.sin(t*11))*12*S)
			if GFX.once(x,"fleeDust",TM.flee) then
				for i=1,GFX.n(x,8) do
					GFX.add({kind=3,p=fBase+GFX.rdir(x)*(20*S),v=R*(GFX.rand(60,160)*S)+U*(GFX.rand(20,60)*S),
						life=GFX.rand(.6,1),s0=15*S,s1=50*S,ramp={{.6,.55,.45},{.3,.28,.25}},op=.4,fin=.05,drag=1.5})
				end
			end
			for i=1,GFX.rate(x,"runDust",25) do
				GFX.add({kind=3,p=fBase,v=R*(80*S)+U*(30*S),life=.6,s0=10*S,s1=35*S,ramp={{.6,.55,.45},{.3,.28,.25}},
					op=.35,fin=.05,drag=1.5})
			end
		end
		if a>.01 then
			local hands=GFX.memeFisher(x,fBase,R,U,run,phase,kk,a)
			local rk=kk*1.3
			if age<=TM.flee then
				-- rod over the pond and a bobbing float
				local tip=hands+(R*.85+U*.75)*(150*S)
				WorldDraw.drawLine(hands,tip,.4*rk,.25*rk,.1*rk,3,0)
				local bob=pond-R*(40*S)+U*(math.sin(age*5)*3*S)
				WorldDraw.drawLine(tip,bob,.8*rk,.8*rk,.8*rk,1,0)
				GFX.drawSphere(x,bob,6*S,{.9,.1,.1},kk,a,3,6)
			else
				-- dropped rod lying on the bank
				local rb=sc-R*(310*S)+F*(70*S)+U*(2*S)
				WorldDraw.drawLine(rb,rb+R*(150*S)+F*(20*S),.4*rk,.25*rk,.1*rk,3,0)
			end
		end

		-- the truck rolls in, brakes (nose dips and bounces back), dust from the wheels
		local stop=sc+R*(250*S)-F*(40*S)
		local T0=R*-1
		local k=goalFxSmooth((age-TM.arrive0)/(TM.arrive1-TM.arrive0))
		local ek=1-(1-k)^3
		local travel=1150*S*(1-ek)
		local tc=stop+R*travel
		local dip=0
		if age>TM.arrive1 then
			local t=age-TM.arrive1
			dip=.07*math.exp(-t*6)*math.cos(t*18)
		elseif age>TM.arrive0 then
			dip=.04*k*k
		end
		local Tt=T0*math.cos(-dip)+U*math.sin(-dip)
		local Ut=U*math.cos(-dip)-T0*math.sin(-dip)
		if GFX.once(x,"engine",TM.arrive0) then MemePP.sound("engine") end
		if GFX.once(x,"brakes",TM.arrive1-.25) then MemePP.sound("brakes") end
		if age>TM.arrive0 and age<TM.arrive1 then
			for i=1,GFX.rate(x,"dust",60*(1-k)+15) do
				GFX.add({kind=3,p=tc-T0*(115*S)+F*(GFX.rand(-70,70)*S)+U*(10*S),v=R*(GFX.rand(40,140)*S)+U*(GFX.rand(30,90)*S),
					life=GFX.rand(.8,1.3),s0=20*S,s1=GFX.rand(60,90)*S,ramp={{.65,.6,.5},{.35,.32,.28}},op=.4,fin=.05,drag=1.2,
					spin=GFX.rand(-1,1)})
			end
		end
		if a>.01 then
			GFX.memeTruck(x,tc,Tt,Ut,F,-travel/(30*S),kk,a)
		end

		-- who is talking right now
		local driverTalk,anger,shake=0,.4,0
		for _,ln in ipairs(MEME_PP_LINES) do
			if age>=ln.t and age<ln.t+ln.d and ln.who=="driver" then
				driverTalk=.5+.5*math.abs(math.sin(age*18))
				if ln.ev=="state" or ln.ev=="private" then anger=1 end
				if ln.ev=="state" then shake=math.sin(age*30)*4*S end
			end
		end
		local head=tc+Tt*(10*S)+F*(80*S)+Ut*(152*S)
		if age>TM.arrive0 and a>.01 then
			GFX.memeDriver(x,head+R*shake,R,Ut,driverTalk,anger,kk,a)
			GFX.drawBox(x,tc+Tt*(15*S)+F*(76*S)+Ut*(118*S),Tt*(22*S),F*(8*S),Ut*(7*S),{.85,.6,.47},kk,a)
		end

		-- the dialogue
		local fHead=fBase+U*(96*S)
		for i,ln in ipairs(MEME_PP_LINES) do
			if age>=ln.t and age<ln.t+ln.d then
				if GFX.once(x,"say"..i,ln.t) then MemePP.sound(ln.ev) end
				local pop=math.min(GFX.backOut((age-ln.t)/.12),1.15)
				local ba=a*(1-goalFxSmooth((age-(ln.t+ln.d-.08))/.08))
				if ln.who=="driver" then
					local big=(ln.text=="STATE?!") and 1.25 or 1
					GFX.memeBubble(x,head+U*(95*S)-R*(70*S),ln.text,head+U*(20*S),pop*big,ba)
				else
					GFX.memeBubble(x,fHead+U*(85*S)+R*(110*S),ln.text,fHead+U*(15*S),pop,ba)
				end
			end
		end

		-- the payoff: the sign slams in, giant stamp, and everyone (fish included) leaves
		if age>TM.sign-.12 then
			local fall=math.clamp((age-(TM.sign-.12))/.12,0,1)
			local bounce=0
			if age>TM.sign then bounce=math.abs(math.sin((age-TM.sign)*22))*math.exp(-(age-TM.sign)*7)*25*S end
			local sp=sc+R*(20*S)+F*(140*S)+U*((1-fall*fall)*600*S+bounce)
			local wood={.45,.28,.12}
			GFX.drawBox(x,sp+U*(60*S),R*(6*S),F*(6*S),U*(60*S),wood,kk,a)
			GFX.drawBox(x,sp+U*(140*S),R*(115*S),F*(4*S),U*(48*S),{.95,.9,.75},kk*1.1,a)
			local red=LinearColor.new(.85*GFX.K*.8,.05,.05,a)
			local blk=LinearColor.new(.02,.02,.02,a)
			local face=sp+F*(5*S)
			GFX.memeText(face+U*(160*S),"PRIVATE",R,U,4.5*S,1.6*S,red)
			GFX.memeText(face+U*(128*S),"PROPERTY",R,U,4.5*S,1.6*S,red)
			GFX.memeText(face+U*(103*S),"NO FISHING",R,U,2.2*S,.9*S,blk)
			if GFX.once(x,"thud",TM.sign) then
				MemePP.sound("thud")
				GFX.addShake(14*S)
				GFX.shock(x,sc+R*(20*S)+F*(140*S)+U*(3*S),R,F,180*S,8*S,{.8,.7,.5},.5)
				for i=1,GFX.n(x,14) do
					local th=GFX.rand(0,6.2832)
					local dirH=R*math.cos(th)+F*math.sin(th)
					GFX.add({kind=3,p=sc+R*(20*S)+F*(140*S)+dirH*(20*S),v=dirH*(GFX.rand(120,260)*S)+U*(GFX.rand(20,80)*S),
						life=GFX.rand(.8,1.2),s0=20*S,s1=70*S,ramp={{.65,.6,.5},{.35,.32,.28}},op=.45,fin=.05,drag=1.5})
				end
			end
		end
		if age>TM.sign and age<TM.sign+1.2 then
			local t=age-TM.sign
			local pop=math.min(GFX.backOut(t/.15),1.2)
			local sa=1-goalFxSmooth((t-.95)/.25)
			local ang=-.08+math.sin(t*14)*.02*math.exp(-t*4)
			local ax=R*math.cos(ang)+U*math.sin(ang)
			local ay=U*math.cos(ang)-R*math.sin(ang)
			local c=x.o+U*(270*S)+(GFX.cp-x.o):getSafeNormal()*(40*S)
			local u=8*S*pop
			GFX.memeText(c,"PRIVATE PROPERTY!",ax,ay,u,u*.55,LinearColor.new(.02,.02,.02,sa*a))
			GFX.memeText(c+(GFX.cp-c):getSafeNormal()*(2*S),"PRIVATE PROPERTY!",ax,ay,u,u*.3,
				LinearColor.new(GFX.K,.08,.05,sa*a))
		end
		if GFX.once(x,"fishJump",TM.fish) then
			for i=1,GFX.n(x,20) do
				local dir=(GFX.rdir(x)+U*1.5):getSafeNormal()
				GFX.add({kind=1,p=pond,v=dir*(GFX.rand(200,450)*S),life=GFX.rand(.6,.9),s0=6*S,s1=3*S,ramp=GFX_WATER,
					grav=1200*S,drag=.3,hot=.4})
			end
		end
		if age>TM.fish and age<TM.fish+.8 then
			local t=(age-TM.fish)/.8
			local fp=pond-R*(t*420*S)+U*(math.sin(t*math.pi)*230*S)
			local dir=(R*-1+U*math.cos(t*math.pi)*1.6):getSafeNormal()
			local side=Vec3.cross(dir,(GFX.cp-fp):getSafeNormal()):getSafeNormal()
			local fk=GFX.K*.7
			local orange=LinearColor.new(1*fk,.5*fk,.1*fk,a)
			GFX.ellipse(fp,dir*(22*S),side*(10*S),orange)
			WorldDraw.drawTriangle(fp-dir*(18*S),fp-dir*(34*S)+side*(12*S),fp-dir*(34*S)-side*(12*S),orange,0)
			GFX.diamond(fp+dir*(12*S)+side*(3*S),2*S,0,LinearColor.new(.02,.02,.02,a))
		end
		if age>TM.honk and age<TM.honk+.5 then
			if GFX.once(x,"honk",TM.honk) then MemePP.sound("honk") end
			local t=age-TM.honk
			local pop=math.min(GFX.backOut(t/.1),1.2)
			local c=tc+Tt*(200*S)+Ut*(150*S)
			local hk=LinearColor.new(GFX.K,.85*GFX.K,.1,a*(1-t/.5))
			GFX.memeText(c,"HONK!",R,U,4*S*pop,1.8*S*pop,hk)
		end
	end,
}

-- 25: DIVINE ASCENSION -------------------------------------------------------------------------
-- A narrow beam of golden light falls on the goal and a glowing rune circle wakes up on the floor
-- as feathers drift down. The beam ignites into a full pillar of light, halo rings float up it
-- and two great wings of light unfold behind it, sparkles spiralling skyward. Then a radiant
-- burst: a golden flash, god rays sweeping round, expanding rings, a burst of feathers and a slow
-- shower of golden glitter, with one last halo lingering over the goal.
GFX_PAL_DIVINE={flash={1,.97,.85},ring={1,.85,.45},ring2={1,1,.9},light={1,.9,.65},
	spark={{1,1,1},{1,.92,.6},{1,.75,.3}},
	fire={{1,1,1},{1,.95,.75},{1,.8,.4},{.3,.2,.08}},
	ember={{1,1,.9},{1,.88,.5},{.8,.6,.2}},
	smoke={{.3,.28,.22},{.1,.09,.08}}}

-- one great wing of light: layered feathers fanning out from root; sd = -1 / +1 side,
-- spread 0 (folded up) .. 1 (open)
function GFX.lightWing(x,root,sd,spread,a)
	local S=x.S
	local U=x.u
	local R=GFX.flatRight(x)
	local Fv=GFX.cp-root
	local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
	local k=GFX.K*a
	for layer=1,2 do
		for i=1,11 do
			local t=(i-1)/10
			local ang=((1.35-1.55*t)*spread+(1-spread)*1.5)+math.sin(x.age*1.6)*.05
			local len=320*S*(.5+.5*math.sin(t*math.pi*.85+.35))*((layer==1) and 1 or .6)
			local dir=(R*(sd*math.cos(ang))+U*math.sin(ang)-F*(.15*math.cos(ang))):getSafeNormal()
			local perp=Vec3.cross(dir,F):getSafeNormal()
			local wf=len*.07
			local base=root+dir*(len*.04)+F*((layer==2) and 2*S or 0)
			local mid=base+dir*(len*.55)
			local tip=base+dir*len
			local c=(layer==1) and {1,.85,.45} or {1,.98,.9}
			local lc=LinearColor.new(c[1]*k,c[2]*k,c[3]*k,a*((layer==1) and .55 or .8))
			WorldDraw.drawTriangle(base,mid+perp*wf,tip,lc,0)
			WorldDraw.drawTriangle(base,tip,mid-perp*wf,lc,0)
		end
	end
end

GFX_DEFS[25]={
	init=function(x)
		local S,D=x.S,x.D
		x.dc=x.base+x.f*(70*S)
		x.TP,x.TB=.3*D,.62*D
		GFX.light(x,x.dc+x.u*(250*S),{1,.9,.65},25000,2600*S,x.TP,x.TB-x.TP,.4)
	end,
	update=function(x,age,d)
		local D,S,TP,TB=x.D,x.S,x.TP,x.TB
		local P=GFX_PAL_DIVINE
		local U=x.u
		local c=x.dc
		local fl=c+U*(3*S)
		local sky=c+U*(1600*S)
		local k=GFX.K
		local fade=1-goalFxSmooth((age-.85*D)/(.15*D))
		-- the rune circle on the floor
		local rk=goalFxSmooth(age/(.15*D))*fade
		if rk>.01 then
			GFX.ring(fl,x.r,x.f,260*S,4*S,56,1,.85,.45,.8*rk)
			GFX.ring(fl,x.r,x.f,205*S,2.5*S,56,1,.95,.8,.7*rk)
			for q=0,5 do
				local a0=age*.8+q*1.047
				GFX.arc(fl,x.r,x.f,232*S,5*S,a0,a0+.6,6,1,.9,.6,.8*rk)
			end
			for q=0,11 do
				local th=q/12*6.2832-age*.4
				local dir=x.r*math.cos(th)+x.f*math.sin(th)
				local gk=k*rk
				WorldDraw.drawLine(fl+dir*(150*S),fl+dir*(195*S),gk,.9*gk,.6*gk,2,0)
				GFX.glow(fl+dir*(270*S),7*S,1,.9,.6,rk*(.6+.4*math.sin(age*6+q)),0,.6)
			end
		end
		-- feathers drifting down the whole time
		if age<.8*D then
			for i=1,GFX.rate(x,"feather",14) do
				local sz=GFX.rand(10,16)*S
				GFX.add({kind=4,p=c+U*(GFX.rand(450,650)*S)+x.r*(GFX.rand(-350,350)*S)+x.f*(GFX.rand(-80,150)*S),
					v=U*(-GFX.rand(60,110)*S)+x.r*(GFX.rand(-30,30)*S),life=GFX.rand(2.5,3.5),s0=sz,s1=sz,
					ramp={{1,.98,.92}},drag=.3,spin=GFX.rand(1.5,3),op=.9,emis=1,fin=.1,fp=.8})
			end
		end
		if age<TP then
			-- a narrow beam of light falling on the goal
			local t=age/TP
			local bk=k*t
			GFX.beam(sky,fl,(6+20*t)*S,LinearColor.new(bk,.92*bk,.7*bk,.25*t))
			GFX.beam(sky,fl,(2+5*t)*S,LinearColor.new(1.3*bk,1.25*bk,1.1*bk,.8*t))
		end
		if GFX.once(x,"ignite",TP) then
			GFX.flashAt(x,fl+U*(100*S),280*S,P.flash,.35)
			GFX.shock(x,fl,x.r,x.f,420*S,14*S,P.ring,.8)
			GFX.addShake(10*S)
		end
		if age>=TP and age<TB+.15*D then
			local t=math.min((age-TP)/(.08*D),1)
			local pa=(age>TB) and (1-goalFxSmooth((age-TB)/(.15*D))) or 1
			local w=(40+30*t)*S*(1+.06*math.sin(age*20))
			local bk=k*pa
			-- the pillar of light
			GFX.beam(sky,fl,w*2.2,LinearColor.new(bk,.85*bk,.5*bk,.18*pa))
			GFX.beam(sky,fl,w,LinearColor.new(1.1*bk,1*bk,.8*bk,.5*pa))
			GFX.beam(sky,fl,w*.35,LinearColor.new(1.5*bk,1.5*bk,1.4*bk,pa))
			-- halo rings floating up it
			for j=0,3 do
				local f=((age-TP)*.9+j/4)%1
				GFX.ring(fl+U*(f*700*S),x.r,x.f,(110+40*f)*S,6*S,40,1,.88,.5,.8*(1-f)*pa)
			end
			-- wings of light unfolding behind it
			local spread=goalFxEaseOut((age-TP)/(.15*D))
			local Fv=GFX.cp-c
			local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
			local root=c+U*(260*S)-F*(30*S)
			GFX.lightWing(x,root,1,spread,pa)
			GFX.lightWing(x,root,-1,spread,pa)
			-- sparkles spiralling up
			for i=1,GFX.rate(x,"spiral",120*pa) do
				local th=GFX.rand(0,6.2832)
				local radial=x.r*math.cos(th)+x.f*math.sin(th)
				local tang=x.f*math.cos(th)-x.r*math.sin(th)
				GFX.add({kind=1,p=fl+radial*(GFX.rand(50,120)*S)+U*(GFX.rand(0,80)*S),
					v=U*(GFX.rand(300,600)*S)+tang*(180*S),life=GFX.rand(.8,1.3),s0=GFX.rand(4,7)*S,s1=1.5*S,
					ramp=P.ember,drag=.3,tw=GFX.rand(10,22)})
			end
		end
		if GFX.once(x,"burst",TB) then
			local m=c+U*(260*S)
			GFX.flashAt(x,m,520*S,P.flash,.4)
			GFX.blast(x,m,P,2)
			GFX.shock(x,m,GFX.bR,GFX.bU,700*S,12*S,P.ring,1)
			GFX.shock(x,m,GFX.bR,GFX.bU,560*S,8*S,P.ring2,1.2)
			GFX.shock(x,fl,x.r,x.f,750*S,22*S,P.ring,1.1)
			GFX.light(x,m,{1,.9,.65},80000,3400*S,.02,.15,.8)
			GFX.addShake(18*S)
			for i=1,GFX.n(x,60) do
				local dir=GFX.rdir(x,.8):getSafeNormal()
				local sz=GFX.rand(12,20)*S
				GFX.add({kind=4,p=m+dir*(GFX.rand(0,80)*S),v=dir*(GFX.rand(300,800)*S),life=GFX.rand(1.6,2.4),s0=sz,s1=sz,
					ramp={{1,.98,.92},{1,.88,.55}},drag=1.4,grav=60*S,spin=GFX.rand(2,5),op=.9,emis=1.1,fin=.001,fp=.7})
			end
			for i=1,GFX.n(x,120) do
				local dir=GFX.rdir(x,.8)
				GFX.add({kind=1,p=m+dir*(GFX.rand(0,250)*S),v=dir*(GFX.rand(80,300)*S),life=GFX.rand(1.8,2.8),
					s0=GFX.rand(4,7)*S,s1=1.5*S,ramp=P.ember,drag=2,grav=50*S,tw=GFX.rand(8,18)})
			end
		end
		if age>TB then
			-- god rays sweeping round
			local t=(age-TB)/(.3*D)
			local ra=(1-goalFxSmooth(t))*fade
			if ra>.01 then
				local m=c+U*(260*S)
				local R,Up=GFX.bR,GFX.bU
				local len=700*S*goalFxEaseOut(math.min(t*3,1))
				for i=0,15 do
					local th=i/16*6.2832+age*.5
					local dir=R*math.cos(th)+Up*math.sin(th)
					local perp=Up*math.cos(th)-R*math.sin(th)
					local w=((i%2==0) and 26 or 14)*S
					local gk=k*ra
					WorldDraw.drawTriangle(m+perp*w,m-perp*w,m+dir*(len*((i%2==0) and 1 or .7)),
						LinearColor.new(gk,.9*gk,.6*gk,.35*ra),0)
				end
			end
			-- one last halo lingering over the goal
			GFX.ring(c+U*(420*S),x.r,x.f,90*S,7*S,40,1,.9,.55,.9*fade*goalFxSmooth((age-TB)/(.1*D)))
		end
	end,
}

-- 26: MIDNIGHT COUNTDOWN (New Year's) ----------------------------------------------------------
-- Giant glowing 3... 2... 1... count down over the goal while a sparkling crystal ball slides down a
-- pole. At midnight the ball flashes, HAPPY NEW YEAR! bursts in gold, a barrage of fireworks goes
-- off at once with gold and silver confetti and sparkler fountains, and then a rolling volley of
-- fireworks keeps going across the sky.
NEWYEAR_TIMING={count=.5,midnight=1.6,total=5.0}

GFX_DEFS[26]={
	duration=function() return NEWYEAR_TIMING.total end,
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.nc=x.base+x.f*(70*S)
		x.volley={}
		for i=1,({5,7,9,11})[x.qi] do
			x.volley[i]={t=NEWYEAR_TIMING.midnight+.35+i*.28,kind=(i%4),col=GFX_FW_COLS[1+(i%#GFX_FW_COLS)],
				pos=x.o+x.r*(GFX.rand(-420,420)*S)+x.u*(GFX.rand(200,420)*S)+x.f*(GFX.rand(0,160)*S)}
		end
		GFX.light(x,x.o+x.u*(200*S),{1,.85,.55},15000,2400*S,.3,1.3,.3)
	end,
	update=function(x,age,d)
		local S,TM=x.S,NEWYEAR_TIMING
		local U=x.u
		local R=GFX.flatRight(x)
		local k=GFX.K
		local gold={1,.82,.35}
		local top=x.nc+U*(560*S)
		local bottomY=230*S
		-- the countdown: each number pops in big and shrinks away, with a tick ring
		if age<TM.midnight then
			for n=1,3 do
				local t0=(n-1)*TM.count+.05
				local t=age-t0
				if t>0 and t<TM.count then
					local pop=math.min(GFX.backOut(t/.12),1.15)
					local fa=1-goalFxSmooth((t-TM.count*.6)/(TM.count*.4))
					local c=x.o+U*(320*S)+(GFX.cp-x.o):getSafeNormal()*(40*S)
					local digit=tostring(4-n)
					GFX.memeText(c,digit,R,U,22*S*pop,14*S*pop,LinearColor.new(.15*k,.08*k,.02*k,fa))
					GFX.memeText(c+(GFX.cp-c):getSafeNormal()*(2*S),digit,R,U,22*S*pop,8*S*pop,
						LinearColor.new(gold[1]*k*1.3,gold[2]*k*1.3,gold[3]*k*1.3,fa))
					GFX.ring(c,GFX.bR,GFX.bU,(150+200*(t/TM.count))*S,5*S,40,1,.85,.4,.7*fa)
					if GFX.once(x,"tick"..n,t0) then GFX.addShake(4*S) end
				end
			end
			-- the ball sliding down its pole
			local drop=goalFxSmooth(age/TM.midnight)
			local bp=top-U*((560*S-bottomY)*drop)
			local pk=k*.8
			GFX.beam(top+U*(200*S),x.nc,4*S,LinearColor.new(.5*pk,.5*pk,.55*pk,1))
			GFX.drawSphere(x,bp,55*S,{.75,.85,1},k*.6,1,7,14,1.5)
			local view=(GFX.cp-bp):getSafeNormal()
			for i=1,12 do
				-- facets glinting as it turns
				local th=age*1.5+i*.524
				local lat=((i%3)-1)*.5
				local dir=((x.r*math.cos(th)+x.f*math.sin(th))*math.cos(lat)+U*math.sin(lat)):getSafeNormal()
				if Vec3.dot(dir,view)>.2 then
					local tw=.5+.5*math.sin(age*9+i)
					local col=GFX_FW_COLS[1+(i%#GFX_FW_COLS)]
					GFX.glow(bp+dir*(56*S),6*S,col[1],col[2],col[3],tw,0,.8)
				end
			end
			GFX.glow(bp,90*S,.8,.9,1,.35+.3*drop,age,.4)
			x.ballP=bp
		end
		-- midnight
		if GFX.once(x,"midnight",TM.midnight) then
			local bp=x.ballP or (x.nc+U*bottomY)
			GFX.flashAt(x,bp,420*S,{1,.95,.8},.4)
			GFX.blast(x,bp,GFX_PAL_DIVINE,1.4)
			GFX.light(x,bp,{1,.9,.7},70000,3400*S,.02,.3,.8)
			GFX.addShake(18*S)
			GFX.shell(x,x.o+R*(-300*S)+U*(330*S),0,{1,.3,.25},1.1)
			GFX.shell(x,x.o+U*(420*S),4,{1,.85,.35},1.3)
			GFX.shell(x,x.o+R*(300*S)+U*(330*S),0,{.3,.6,1},1.1)
			for side=-1,1,2 do
				-- confetti cannons from both sides
				local post=x.nc+R*(side*260*S)
				for i=1,GFX.n(x,70) do
					local dir=(U+R*(-side*GFX.rand(.1,.6))+x.f*GFX.rand(.05,.5)+GFX.rdir(x)*.12):getSafeNormal()
					local sz=GFX.rand(6,10)*S
					GFX.add({kind=4,quad=true,p=post,v=dir*(GFX.rand(900,1600)*S),life=GFX.rand(2,2.8),s0=sz,s1=sz,
						ramp={(i%2==0) and {1,.82,.3} or {.85,.88,.95}},grav=380*S,drag=2.3,spin=GFX.rand(6,14),op=.95,
						emis=1,fin=.001,fp=.5})
				end
			end
		end
		if age>TM.midnight then
			local t=age-TM.midnight
			local fa=1-goalFxSmooth((t-2.4)/.6)
			if fa>.01 then
				local pop=math.min(GFX.backOut(t/.18),1.15)
				local c=x.o+U*(300*S)+(GFX.cp-x.o):getSafeNormal()*(60*S)
				local sh=1+.04*math.sin(t*6)
				local u=10*S*pop*sh
				local tz=(GFX.cp-c):getSafeNormal()
				for li,line in ipairs({"HAPPY","NEW YEAR!"}) do
					local lc=c+U*((li==1) and 70*S or -10*S)
					GFX.memeText(lc,line,R,U,u,u*.9,LinearColor.new(.15*k,.08*k,.02*k,fa))
					GFX.memeText(lc+tz*(2*S),line,R,U,u,u*.5,LinearColor.new(gold[1]*k*1.3,gold[2]*k*1.3,gold[3]*k*1.3,fa))
				end
			end
			-- sparkler fountains on both sides
			if t<2.6 then
				for side=-1,1,2 do
					for i=1,GFX.rate(x,"spark"..side,120) do
						local post=x.nc+R*(side*260*S)
						GFX.add({kind=2,p=post,v=(U+GFX.rdir(x)*.35):getSafeNormal()*(GFX.rand(500,900)*S),
							life=GFX.rand(.5,.9),s0=2.5*S,s1=.5*S,ramp={{1,1,.9},{1,.8,.3},{1,.4,.1}},grav=700*S,drag=.6,st=.04})
					end
				end
			end
			-- the rolling volley
			for i,v in ipairs(x.volley) do
				if GFX.once(x,"volley"..i,v.t) then
					GFX.shell(x,v.pos,v.kind,v.col,.9)
					GFX.addShake(3*S)
				end
			end
		end
	end,
}

-- 27: HEARTBREAKER (Valentine's) ---------------------------------------------------------------
-- A big glossy heart inflates over the goal and beats, glowing brighter with each beat. A glowing
-- arrow streaks in from the side trailing sparkles and strikes it; it cracks for a heartbeat, then
-- shatters into a cloud of little spinning hearts and rose petals with a pink shockwave.
HEART_TIMING={hit=1.25,total=3.4}

GFX_DEFS[27]={
	duration=function() return HEART_TIMING.total end,
	init=function(x)
		local S=x.S
		x.hc=x.o+x.u*(40*S)
		GFX.light(x,x.hc,{1,.35,.5},20000,2400*S,.3,.9,.3)
	end,
	update=function(x,age,d)
		local S,TM=x.S,HEART_TIMING
		local U=x.u
		local R,BU=GFX.bR,GFX.bU
		local k=GFX.K
		local c=x.hc
		local tc=(GFX.cp-c):getSafeNormal()
		local hit=TM.hit
		local cracked=age>hit
		if age<hit+.12 then
			-- the heart: inflates, then beats (lub-dub) with a pulse ring each time
			local grow=GFX.backOut(age/.3)
			local beat=0
			local bt=age%.55
			if bt<.12 then beat=math.sin(bt/.12*math.pi) elseif bt>.18 and bt<.28 then beat=.6*math.sin((bt-.18)/.1*math.pi) end
			local s=170*S*grow*(1+.08*beat)
			local wob=cracked and math.sin(age*80)*4*S or 0
			local hc=c+R*wob
			GFX.heart(hc,R,BU,s*1.08,LinearColor.new(.35*k*.8,.02,.08*k*.8,1))
			GFX.heart(hc+tc*(1.5*S),R,BU,s,LinearColor.new(1*k*(.8+.3*beat),.08*k,.25*k,1))
			GFX.heart(hc+tc*(3*S)+BU*(s*.12),R,BU,s*.6,LinearColor.new(1*k,.3*k,.5*k,1))
			GFX.ellipse(hc+tc*(4*S)-R*(s*.4)+BU*(s*.35),R*(s*.16),BU*(s*.09),LinearColor.new(k*1.3,k*1.1,k*1.2,.9))
			GFX.glow(hc,s*1.4,1,.3,.5,.3+.3*beat,age,.3)
			if beat>.9 and GFX.once(x,"pulse"..math.floor(age/.55),age) then
				GFX.shock(x,hc,R,BU,s*2.2,5*S,{1,.4,.6},.5)
			end
			if cracked then
				-- crack running down the middle
				local ck=k*1.5
				local prev=hc+tc*(5*S)+BU*(s*.55)
				for j=1,6 do
					local q=hc+tc*(5*S)+BU*(s*(.55-j*.22))+R*(((j%2==0) and 1 or -1)*s*.08)
					GFX.beam(prev,q,3*S,LinearColor.new(ck,ck*.9,ck*.95,1))
					prev=q
				end
			end
		end
		-- the arrow streaking in from the right
		local a0=.75
		if age>a0 and age<hit+.4 then
			local t=math.min((age-a0)/(hit-a0),1)
			local from=c+R*(900*S)+BU*(200*S)
			local to=c+R*(60*S)+BU*(20*S)
			local tip=from+(to-from)*goalFxEaseOut(t)
			local dir=(to-from):getSafeNormal()
			local ak=k*1.2
			GFX.beam(tip-dir*(220*S),tip,3*S,LinearColor.new(ak,.85*ak,.5*ak,1))
			WorldDraw.drawTriangle(tip+dir*(26*S),tip+Vec3.cross(dir,tc)*(12*S),tip-Vec3.cross(dir,tc)*(12*S),
				LinearColor.new(ak,.3*ak,.5*ak,1),0)
			local tail=tip-dir*(210*S)
			for sd=-1,1,2 do
				local fl=Vec3.cross(dir,tc)*(sd*14*S)
				WorldDraw.drawTriangle(tail,tail-dir*(30*S)+fl,tail+dir*(10*S),LinearColor.new(ak,.5*ak,.7*ak,1),0)
			end
			if t<1 then
				for i=1,GFX.rate(x,"arrowTrail",120) do
					GFX.add({kind=7,p=tail,v=GFX.rdir(x)*(GFX.rand(20,60)*S),life=GFX.rand(.4,.7),s0=GFX.rand(6,9)*S,s1=2*S,
						ramp={{1,.6,.75},{1,.3,.5}},drag=1,spin=GFX.rand(-3,3)})
				end
			end
		end
		if GFX.once(x,"hit",hit) then GFX.addShake(8*S) end
		if GFX.once(x,"shatter",hit+.12) then
			GFX.flashAt(x,c,340*S,{1,.75,.85},.35)
			GFX.blast(x,c,GFX.teamPal({1,.25,.5}),1.5)
			GFX.shock(x,c,R,BU,620*S,12*S,{1,.4,.6},.9)
			GFX.shock(x,c,x.r,x.f,560*S,10*S,{1,.6,.75},1)
			GFX.light(x,c,{1,.4,.6},60000,3000*S,.02,.15,.7)
			GFX.addShake(18*S)
			local pinks={{{1,.15,.3}},{{1,.45,.65}},{{1,.75,.85}},{{.9,.05,.15}}}
			for i=1,GFX.n(x,70) do
				local dir=GFX.rdir(x,.7):getSafeNormal()
				GFX.add({kind=7,p=c+dir*(GFX.rand(0,100)*S),v=dir*(GFX.rand(250,800)*S)+U*(150*S),life=GFX.rand(1.4,2.2),
					s0=GFX.rand(14,26)*S,s1=GFX.rand(8,12)*S,ramp=pinks[1+(i%4)],drag=1.2,grav=150*S,spin=GFX.rand(-3,3),
					fin=.01,fp=.6})
			end
			for i=1,GFX.n(x,50) do
				-- rose petals
				local dir=GFX.rdir(x,.8):getSafeNormal()
				local sz=GFX.rand(9,15)*S
				GFX.add({kind=4,p=c+dir*(GFX.rand(0,80)*S),v=dir*(GFX.rand(200,600)*S)+U*(100*S),life=GFX.rand(1.8,2.6),
					s0=sz,s1=sz,ramp={{.85,.05,.12},{.6,.02,.08}},drag=1.6,grav=120*S,spin=GFX.rand(2,5),op=.95,emis=1,
					fin=.001,fp=.6})
			end
		end
	end,
}


-- 28: GG EZ (Special) ---------------------------------------------------------------------------
-- The two most toxic words in online games, as a goal explosion. A giant in-game chat window
-- pops up over the goal and the scorer types "GG EZ" one key at a time. Enter: the letters fly
-- out of the chat toward the camera, grow into huge 3D gold and team-coloured block letters and
-- slam into the floor one by one. Pixel "deal with it" shades drop onto the EZ with a glint...
-- then the moderator's BAN HAMMER drops out of the sky and smashes the lot into confetti, a red
-- BANNED! stamp slams on, the message gets struck out and the chat auto-corrects it to
-- "GOOD GAME, WELL PLAYED!" with a few hearts.
-- No sound API, so there is only a hook:  MemeGG.onSound = function(event) ... end
--   events: "type", "send", "slam", "glasses", "hammer", "smash", "retype"
GGEZ_TIMING={
	pop=.15,       -- chat window pops up
	type0=.4,      -- first key
	key=.11,       -- seconds per key
	send=1.05,     -- enter: the letters leave the chat
	slam={1.4,1.56,1.8,1.96},   -- each letter hits the floor
	glasses=2.1,   -- the shades start dropping
	hammer=2.45,   -- the ban hammer comes down from the sky
	smash=2.95,    -- ...and swings
	retype=3.35,   -- the chat auto-corrects
	total=5.4,
}
MemeGG={onSound=nil}
function MemeGG.sound(ev)
	if MemeGG.onSound then pcall(MemeGG.onSound,ev) end
end

-- left-aligned GFX_HAND text starting at L (vertical centre); returns the point after the last letter
function GFX.textLeft(L,text,ax,ay,u,w,lc)
	local n=#text
	if n>0 then GFX.memeText(L+ax*((n*5.2-1.2)*u*.5),text,ax,ay,u,w,lc) end
	return L+ax*(n*5.2*u)
end

-- a chunky 3D block letter: the GFX_HAND strokes as shaded tubes. base = bottom centre,
-- h = height, tilt turns it in the R/U plane
function GFX.ggLetter(x,ch,base,R,U,h,tilt,col,kk,rim)
	local g=GFX_HAND[ch]
	if not g or h<1 then return end
	local s=h/6
	local c0,s0=math.cos(tilt),math.sin(tilt)
	local ax=R*c0+U*s0
	local ay=U*c0-R*s0
	for _,st in ipairs(g) do
		local pts,radii={},{}
		for _,v in ipairs(st) do
			pts[#pts+1]=base+ax*((v[1]-2)*s)+ay*(v[2]*s)
			radii[#radii+1]=s*.6
		end
		GFX.tube(x,pts,radii,6,col,kk,rim)
	end
end

-- pixel "deal with it" sunglasses: c = centre of the top bar, b = half a pixel block
function GFX.ggShades(x,c,R,U,F,b,kk,a)
	local rows={{-4,-3,-2,-1,0,1,2,3,4},{-4,-3,-2,-1,1,2,3,4},{-3,-2,2,3}}
	local blk={.03,.03,.04}
	for ri,row in ipairs(rows) do
		for _,i in ipairs(row) do
			GFX.drawBox(x,c+R*(i*b*2)+U*((1-ri)*b*2),R*b,U*b,F*(b*.7),blk,kk,a)
		end
	end
	-- white pixel shine on each lens
	for _,i in ipairs({-3,2}) do
		GFX.drawBox(x,c+R*(i*b*2)+U*(b*-2)+F*(b*.75),R*(b*.55),U*(b*.55),F*(b*.1),{1,1,1},GFX.K*1.1,a)
	end
end

-- the moderator's ban hammer. pivot = end of the handle, dir = along the handle, side = across
-- the head; returns the centre of the head
function GFX.ggHammer(x,pivot,dir,side,F,S,kk,a)
	local len=470*S
	GFX.tube(x,{pivot,pivot+dir*len},{13*S,16*S},8,{.42,.24,.1},kk)
	local hc=pivot+dir*(len+48*S)
	GFX.drawBox(x,hc,side*(125*S),dir*(48*S),F*(52*S),{.55,.56,.62},kk,a)
	for sd=-1,1,2 do
		GFX.drawBox(x,hc+side*(sd*108*S),side*(15*S),dir*(52*S),F*(56*S),{1,.75,.25},kk*1.2,a)
	end
	local rk=GFX.K*1.1
	GFX.memeText(hc+F*(53*S),"BAN",side,dir,8*S,2.4*S,LinearColor.new(rk,.06*rk,.05*rk,a))
	return hc
end

GFX_DEFS[28]={
	duration=function() return GGEZ_TIMING.total end,
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.tc=GFX.teamColor(true)
		x.pal=GFX.teamPal(x.tc)
		x.sc=x.base+x.f*(60*S)
		-- the scorer's name in capitals the font can draw (falls back to PLAYER)
		local nm=string.upper(tostring(goalFx.scorerName or "PLAYER"))
		local clean=""
		for i=1,#nm do
			local ch=string.sub(nm,i,i)
			if GFX_HAND[ch] or ch==" " then clean=clean..ch end
		end
		if #clean==0 then clean="PLAYER" end
		x.name=string.sub(clean,1,10)
		x.letters={}
		local cols={{1,.78,.25},{1,.78,.25},x.tc,x.tc}
		local offs={-215,-92,92,215}
		local idx={1,2,4,5}   -- where each letter sits in "GG EZ"
		for i,ch in ipairs({"G","G","E","Z"}) do
			x.letters[i]={ch=ch,off=offs[i],col=cols[i],idx=idx[i],alive=true}
		end
		GFX.blast(x,x.base+x.u*(60*S),x.pal,.8)
		GFX.addShake(8*S)
	end,
	update=function(x,age,d)
		local S,TM=x.S,GGEZ_TIMING
		local U=x.u
		local R=GFX.flatRight(x)
		local Fv=GFX.cp-x.sc
		local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
		local kk=GFX.K*.55
		local k=GFX.K
		local tc=x.tc
		local a=1-goalFxSmooth((age-(TM.total-.4))/.4)
		local sc=x.sc
		local LH=170*S
		local smashed=age>=TM.smash

		-- the chat window: layout first (the letters launch from it), then drawing
		local pc=sc+U*(430*S)+F*(30*S)
		local pop=math.min(GFX.backOut(math.clamp((age-TM.pop)/.22,0,1)),1.1)
		local W,H=340*S*pop,105*S*pop
		local toCam=(GFX.cp-pc):getSafeNormal()
		local tu=4.2*S*pop
		local L=pc-R*(W-18*S*pop)+toCam*(2*S)
		local y1=L+U*(H*.12)
		local y2=L+U*(H*-.5)
		local ms=y1+R*((#x.name+1)*5.2*tu)
		local white=LinearColor.new(k*.95,k*.95,k*.95,a)
		local nameCol=LinearColor.new(tc[1]*k,tc[2]*k,tc[3]*k,a)
		if pop>.02 and a>.01 then
			local bg=LinearColor.new(.015,.02,.04,.8*a)
			local p1,p2,p3,p4=pc-R*W-U*H,pc+R*W-U*H,pc+R*W+U*H,pc-R*W+U*H
			WorldDraw.drawTriangle(p1,p2,p3,bg,0)
			WorldDraw.drawTriangle(p1,p3,p4,bg,0)
			local hb=LinearColor.new(tc[1]*k*.4,tc[2]*k*.4,tc[3]*k*.4,.9*a)
			local h1,h2=p4-U*(30*S*pop)+toCam*(1*S),p3-U*(30*S*pop)+toCam*(1*S)
			WorldDraw.drawTriangle(h1,h2,p3+toCam*(1*S),hb,0)
			WorldDraw.drawTriangle(h1,p3+toCam*(1*S),p4+toCam*(1*S),hb,0)
			-- the window flashes when the message is sent
			local fl=math.max(0,1-math.abs(age-TM.send)/.12)
			local ek=k*(1+fl*1.5)
			local edge=LinearColor.new(tc[1]*ek,tc[2]*ek,tc[3]*ek,a)
			GFX.beam(p1,p2,2.5*S,edge)
			GFX.beam(p2,p3,2.5*S,edge)
			GFX.beam(p3,p4,2.5*S,edge)
			GFX.beam(p4,p1,2.5*S,edge)
			if pop>.3 then
				GFX.textLeft(L+U*(H-15*S*pop),"ALL CHAT",R,U,2.8*S*pop,.9*S,white)
				-- line 1: the scorer types GG EZ
				GFX.textLeft(y1,x.name,R,U,tu,tu*.32,nameCol)
				local msg="GG EZ"
				local typed=0
				if age>=TM.type0 then typed=math.clamp(math.floor((age-TM.type0)/TM.key)+1,0,#msg) end
				local mc=white
				if smashed then mc=LinearColor.new(k,.1*k,.08*k,a) end
				local mEnd=GFX.textLeft(ms,string.sub(msg,1,typed),R,U,tu,tu*.32,mc)
				if age<TM.send and math.floor(age*7)%2==0 then
					GFX.beam(mEnd+R*(tu)+U*(-3*tu),mEnd+R*(tu)+U*(3*tu),tu*.3,white)
				end
				-- struck out once the hammer lands
				if smashed then
					local st=math.clamp((age-TM.smash-.15)/.15,0,1)
					if st>0 then GFX.beam(ms-R*tu,ms-R*tu+(mEnd-ms+R*(2*tu))*st,tu*.45,LinearColor.new(k,.1*k,.08*k,a)) end
				end
				-- line 2: the auto-correct
				if age>=TM.retype then
					local fix="GOOD GAME, WELL PLAYED!"
					local n2=math.clamp(math.floor((age-TM.retype)*24)+1,0,#fix)
					local e2=GFX.textLeft(y2,string.sub(fix,1,n2),R,U,tu,tu*.32,LinearColor.new(.35*k,k,.45*k,a))
					if n2<#fix and math.floor(age*10)%2==0 then
						GFX.beam(e2+R*(tu)+U*(-3*tu),e2+R*(tu)+U*(3*tu),tu*.3,white)
					end
				end
			end
		end
		for i=1,5 do
			if GFX.once(x,"key"..i,TM.type0+(i-1)*TM.key) then
				MemeGG.sound("type")
				GFX.flashAt(x,pc,60*S,tc,.08)
			end
		end
		if GFX.once(x,"send",TM.send) then
			MemeGG.sound("send")
			GFX.flashAt(x,pc,260*S,GFX.mixW(tc,.5),.18)
			GFX.shock(x,pc,R,U,380*S,6*S,tc,.4)
		end

		-- the letters fly out of the chat, grow huge and slam into the floor
		for i,lt in ipairs(x.letters) do
			local land=sc+R*(lt.off*S)
			local tl=TM.slam[i]
			if lt.alive and age>=TM.send then
				local p,h,tilt
				if age<tl then
					local t=(age-TM.send)/(tl-TM.send)
					local start=ms+R*(((lt.idx-1)*5.2+2)*tu)-U*(3*tu)
					local e=t*t
					local arc=math.sin(math.pi*t)
					p=start+(land-start)*e+U*(arc*260*S)+F*(arc*180*S)
					h=LH*(.15+.85*t)
					tilt=(1-t)*6.2832*((i%2==0) and 1 or -1)
					for j=1,GFX.rate(x,"trail"..i,90) do
						GFX.add({kind=2,p=p+U*(h*.5),v=GFX.rdir(x)*(60*S),life=.35,s0=4*S,s1=.5*S,
							ramp={{1,1,1},lt.col},drag=2,st=.03})
					end
				else
					local t=age-tl
					p=land
					h=LH*(1+.18*math.exp(-t*9)*math.sin(t*30))
					tilt=math.sin(t*16)*math.exp(-t*6)*.3
				end
				GFX.ggLetter(x,lt.ch,p,R,U,h,tilt,lt.col,kk*1.4,{1,1,1})
				GFX.glow(p+U*(h*.5)+F*(30*S),h*.9,lt.col[1],lt.col[2],lt.col[3],.25*a,0,.3)
			end
			if GFX.once(x,"slam"..i,tl) then
				MemeGG.sound("slam")
				GFX.shock(x,land+U*(3*S),x.r,x.f,230*S,10*S,lt.col,.5)
				GFX.flashAt(x,land+U*(60*S),150*S,GFX.mixW(lt.col,.5),.15)
				GFX.addShake(10*S)
				for j=1,GFX.n(x,24) do
					local dir=(GFX.rdir(x)+U*1.2):getSafeNormal()
					GFX.add({kind=2,p=land,v=dir*(GFX.rand(300,800)*S),life=GFX.rand(.3,.6),s0=3*S,s1=.5*S,
						ramp={{1,1,1},lt.col},drag=2,grav=600*S,st=.04})
				end
				for j=1,GFX.n(x,8) do
					local th=GFX.rand(0,6.2832)
					GFX.add({kind=3,p=land+U*(8*S),v=(x.r*math.cos(th)+x.f*math.sin(th))*(GFX.rand(120,260)*S)+U*(30*S),
						life=GFX.rand(.7,1.1),s0=25*S,s1=70*S,ramp={{.6,.58,.55},{.3,.29,.28}},op=.35,fin=.05,drag=1.6})
				end
			end
		end

		-- deal with it
		if age>=TM.glasses and not smashed then
			local t=math.clamp((age-TM.glasses)/.35,0,1)
			local gc=sc+R*(153*S)+U*(LH*.8)+F*(30*S)+U*((1-goalFxEaseOut(t))*520*S)
			GFX.ggShades(x,gc,R,U,F,11*S,kk*1.2,a)
			if t>=1 then
				local gt=age-TM.glasses-.35
				if gt<.35 then
					local gk=k*1.4*(1-gt/.35)
					GFX.star(gc+R*((-6+gt*40)*11*S)+U*(-22*S)+F*(10*S),26*S,6*S,gt*3,LinearColor.new(gk,gk,gk,1))
				end
			end
		end
		if GFX.once(x,"glasses",TM.glasses+.35) then MemeGG.sound("glasses") end

		-- the ban hammer: drops out of the sky upright, then swings down onto the letters
		if age>=TM.hammer-.2 and age<TM.smash+.55 then
			local pivot=sc+R*(600*S)+U*(70*S)
			local th
			if age<TM.hammer then
				local t=(age-(TM.hammer-.2))/.2
				pivot=pivot+U*((1-goalFxEaseOut(t))*800*S)
				th=0
			elseif age<TM.smash then
				local t=(age-TM.hammer)/(TM.smash-TM.hammer)
				th=-.25*math.sin(math.min(t/.35,1)*math.pi)+1.5708*(t^2.6)   -- wind up, then swing
			else
				th=1.5708-.18*math.exp(-(age-TM.smash)*6)*math.abs(math.sin((age-TM.smash)*14))
			end
			local dir=U*math.cos(th)+R*(-math.sin(th))
			local side=R*math.cos(th)+U*math.sin(th)
			local ha=1-goalFxSmooth((age-(TM.smash+.3))/.25)
			local hc=GFX.ggHammer(x,pivot,dir,side,F,S,kk*1.2,ha)
			if age>TM.hammer and age<TM.smash then
				for j=1,GFX.rate(x,"swoosh",120) do
					GFX.add({kind=2,p=hc+side*(GFX.rand(-120,120)*S),v=dir*(-100*S),life=.25,s0=3*S,s1=.5*S,
						ramp={{1,1,1},{1,.8,.3}},drag=3,st=.05})
				end
			end
		end
		if GFX.once(x,"hammer",TM.hammer) then MemeGG.sound("hammer") end

		-- SMASH
		if GFX.once(x,"smash",TM.smash) then
			MemeGG.sound("smash")
			local hit=sc+U*(80*S)
			GFX.blast(x,hit,x.pal,1.4)
			GFX.flashAt(x,hit,560*S,{1,.95,.85},.3)
			GFX.shock(x,sc+U*(4*S),x.r,x.f,820*S,22*S,{1,.8,.3},1)
			GFX.light(x,hit,{1,.85,.5},70000,3000*S,.02,.15,.5)
			GFX.addShake(26*S)
			for _,lt in ipairs(x.letters) do
				lt.alive=false
				local lp=sc+R*(lt.off*S)+U*(LH*.5)
				for j=1,GFX.n(x,40) do
					local dir=(GFX.rdir(x,.8)+U*.6):getSafeNormal()
					local sz=GFX.rand(8,16)*S
					GFX.add({kind=4,p=lp+GFX.rdir(x)*(40*S),v=dir*(GFX.rand(400,1100)*S),life=GFX.rand(1.2,1.9),s0=sz,s1=sz*.7,
						ramp={lt.col},grav=700*S,drag=.8,spin=GFX.rand(4,12),op=1,emis=.8,fin=.001,fp=.5})
				end
			end
			-- the shades go flying too
			local gc=sc+R*(153*S)+U*(LH*.8)
			for j=1,GFX.n(x,14) do
				local sz=GFX.rand(10,16)*S
				GFX.add({kind=4,p=gc+GFX.rdir(x)*(40*S),v=(GFX.rdir(x)+U):getSafeNormal()*(GFX.rand(500,900)*S),life=1.4,
					s0=sz,s1=sz,ramp={{.05,.05,.06}},grav=700*S,drag=.6,spin=GFX.rand(4,10),op=1,emis=.2,fin=.001,fp=.4})
			end
			-- confetti everywhere
			for j=1,GFX.n(x,140) do
				local dir=(GFX.rdir(x,.8)+U*.9):getSafeNormal()
				local sz=GFX.rand(6,10)*S
				GFX.add({kind=4,quad=true,p=hit,v=dir*(GFX.rand(700,1500)*S),life=GFX.rand(2,2.8),s0=sz,s1=sz,
					ramp={GFX_FW_COLS[1+(j%#GFX_FW_COLS)]},grav=380*S,drag=2.3,spin=GFX.rand(6,14),op=.95,emis=.9,fin=.001,fp=.5})
			end
		end

		-- BANNED! stamp
		if smashed and age<TM.smash+1.6 then
			local t=age-TM.smash
			local sk=1+1.3*(1-goalFxEaseOut(math.clamp(t/.13,0,1)))
			local ba=a*(1-goalFxSmooth((t-1.3)/.3))
			local cen=sc+U*(250*S)+F*(170*S)
			local tl=-.16
			local ax=R*math.cos(tl)+U*math.sin(tl)
			local ay=U*math.cos(tl)-R*math.sin(tl)
			local rk=k*1.15
			local red=LinearColor.new(rk,.06*rk,.05*rk,ba)
			local w,h=285*S*sk,72*S*sk
			local q1,q2,q3,q4=cen-ax*w-ay*h,cen+ax*w-ay*h,cen+ax*w+ay*h,cen-ax*w+ay*h
			GFX.beam(q1,q2,6*S*sk,red)
			GFX.beam(q2,q3,6*S*sk,red)
			GFX.beam(q3,q4,6*S*sk,red)
			GFX.beam(q4,q1,6*S*sk,red)
			GFX.memeText(cen,"BANNED!",ax,ay,14*S*sk,4.2*S*sk,red)
			GFX.memeText(cen-ay*(h+30*S*sk),"FOR TOXIC CHAT",ax,ay,4.5*S*sk,1.5*S*sk,red)
			if GFX.once(x,"stampShake",TM.smash+.13) then GFX.addShake(12*S) end
		end

		-- the auto-correct, with a few hearts out of the chat
		if GFX.once(x,"retype",TM.retype) then
			MemeGG.sound("retype")
			GFX.flashAt(x,pc,200*S,{.4,1,.5},.15)
			for j=1,GFX.n(x,16) do
				local dir=(U+R*GFX.rand(-.8,.8)+F*GFX.rand(0,.4)):getSafeNormal()
				GFX.add({kind=7,p=pc+R*(GFX.rand(-200,200)*S),v=dir*(GFX.rand(150,350)*S),life=GFX.rand(1.4,2),
					s0=GFX.rand(14,22)*S,s1=GFX.rand(8,12)*S,ramp={{1,.35,.55},{1,.15,.35}},drag=1.2,grav=-40*S,
					spin=GFX.rand(-2,2),fin=.01,fp=.6})
			end
		end
	end,
}
-- 29: JACKPOT ---------------------------------------------------------------------------------
-- A giant 3D slot machine rises out of the goal: red cabinet with gold trim, a marquee ringed
-- with chasing bulbs, three reel windows and a lever. The lever slams down, the reels blur, and
-- they stop one by one on $ $ $ with a clunk. JACKPOT! The bulbs go wild, a fountain of gold
-- coins pours out of the tray... then the whole machine blows apart in a gold blast: tumbling
-- 3D gold bars, a storm of spinning coins, and real paper money (bills that tumble, flutter and
-- sway as they fall) raining down over the goal.
-- No sound API, so there is only a hook:  MoneyFX.onSound = function(event) ... end
--   events: "rise", "lever", "spin", "stop", "jackpot", "boom", "rain"
JACKPOT_TIMING={
	rise=.55,      -- machine fully up
	lever=.62,     -- lever pulled
	stop={1.45,1.8,2.15},   -- reels stop
	jackpot=2.25,  -- JACKPOT
	boom=2.9,      -- the machine bursts
	rainEnd=4.4,   -- last bills spawned
	total=5.6,
}
MoneyFX={onSound=nil}
function MoneyFX.sound(ev)
	if MoneyFX.onSound then pcall(MoneyFX.onSound,ev) end
end

GFX_GOLD={1,.74,.2}
GFX_PAL_GOLD={flash={1,.92,.65},ring={1,.8,.3},ring2={1,.9,.55},light={1,.8,.35},
	spark={{1,1,.9},{1,.85,.35},{1,.55,.1}},
	fire={{1,1,.85},{1,.8,.3},{.9,.45,.08},{.15,.08,.02}},
	ember={{1,.95,.7},{1,.7,.2},{.4,.2,.04}},
	smoke={{.2,.16,.08},{.06,.05,.04}}}

-- orthonormal frame turned by yaw a and tilt b (for tumbling bars and bills)
function GFX.tumble(R,F,U,a,b)
	local e1=R*math.cos(a)+F*math.sin(a)
	local e2=F*math.cos(a)-R*math.sin(a)
	return e1,e2*math.cos(b)+U*math.sin(b),U*math.cos(b)-e2*math.sin(b)
end

-- a dollar bill: pale border, green face, darker centre oval; e1 = long side, e2 = short side
function GFX.moneyBill(x,c,e1,e2,n,w,h,a)
	local S=x.S
	local sh=(.45+.55*math.abs(Vec3.dot(n,x.ld)))*GFX.K*.55
	local sd=(Vec3.dot(n,GFX.cp-c)>0) and 1 or -1
	local lift=n*(sd*.4*S)
	local function quad(cc,hw,hh,col)
		local p1,p2,p3,p4=cc-e1*hw-e2*hh,cc+e1*hw-e2*hh,cc+e1*hw+e2*hh,cc-e1*hw+e2*hh
		local lc=LinearColor.new(col[1]*sh,col[2]*sh,col[3]*sh,a)
		WorldDraw.drawTriangle(p1,p2,p3,lc,0)
		WorldDraw.drawTriangle(p1,p3,p4,lc,0)
	end
	quad(c,w,h,{.78,.88,.68})
	quad(c+lift,w*.88,h*.78,{.3,.58,.28})
	GFX.ellipse(c+lift*2,e1*(h*.55),e2*(h*.55),LinearColor.new(.15*sh,.36*sh,.14*sh,a))
	for k=-1,1,2 do
		GFX.ellipse(c+lift*2+e1*(k*w*.68),e1*(h*.22),e2*(h*.22),LinearColor.new(.6*sh,.78*sh,.5*sh,a))
	end
end

-- a reel symbol in the plane of ax/ay: 1 = 7, 2 = $, 3 = BAR, 4 = cherries
function GFX.slotSymbol(x,c,kind,ax,ay,u,a)
	local k=GFX.K
	if kind==1 then
		GFX.memeText(c,"7",ax,ay,u,u*.55,LinearColor.new(k*1.1,.08*k,.05*k,a))
	elseif kind==2 then
		local gc=LinearColor.new(.15*k,.85*k,.25*k,a)
		GFX.memeText(c,"S",ax,ay,u,u*.55,gc)
		GFX.beam(c+ay*(-4*u),c+ay*(4*u),u*.4,gc)
	elseif kind==3 then
		local bc=LinearColor.new(.02,.02,.03,a)
		GFX.beam(c-ax*(8*u)+ay*(2.2*u),c+ax*(8*u)+ay*(2.2*u),u*.5,bc)
		GFX.beam(c-ax*(8*u)-ay*(2.2*u),c+ax*(8*u)-ay*(2.2*u),u*.5,bc)
		GFX.memeText(c,"BAR",ax,ay,u*.5,u*.3,bc)
	else
		local rc=LinearColor.new(k*.9,.05*k,.08*k,a)
		GFX.flatDisc(c+ax*(-1.6*u)+ay*(-1.2*u),ax,ay,1.7*u,rc)
		GFX.flatDisc(c+ax*(1.6*u)+ay*(-1.6*u),ax,ay,1.7*u,rc)
		local st=LinearColor.new(.1*k,.5*k,.1*k,a)
		GFX.beam(c+ax*(-1.6*u)+ay*(-.2*u),c+ay*(3*u),u*.25,st)
		GFX.beam(c+ax*(1.6*u)+ay*(-.6*u),c+ay*(3*u),u*.25,st)
	end
end

GFX_DEFS[29]={
	duration=function() return JACKPOT_TIMING.total end,
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.mc=x.base+x.f*(40*S)
		x.bars={}
		x.bills={}
		x.reelOff={GFX.rand(0,4),GFX.rand(0,4),GFX.rand(0,4)}
		GFX.flashAt(x,x.base+x.u*(60*S),260*S,{1,.9,.6},.3)
		GFX.shock(x,x.base+x.u*(4*S),x.r,x.f,480*S,14*S,GFX_GOLD,.7)
		GFX.addShake(8*S)
		MoneyFX.sound("rise")
	end,
	update=function(x,age,d)
		local S,TM=x.S,JACKPOT_TIMING
		local U=x.u
		local R=GFX.flatRight(x)
		local Fv=GFX.cp-x.mc
		local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
		local k=GFX.K
		local kk=k*.55
		local a=1-goalFxSmooth((age-(TM.total-.45))/.45)
		local gold=GFX_GOLD
		local red={.78,.05,.06}

		-- THE MACHINE (until it bursts)
		if age<TM.boom then
			local rise=goalFxEaseOut(math.clamp(age/TM.rise,0,1))
			local shakeM=0
			if age>TM.jackpot then shakeM=math.sin(age*60)*4*S*goalFxSmooth((age-TM.jackpot)/.5) end
			local mc=x.mc-U*((1-rise)*520*S)+R*shakeM
			-- cabinet, trim, base
			GFX.drawBox(x,mc+U*(210*S),R*(180*S),U*(150*S),F*(80*S),red,kk,1)
			GFX.drawBox(x,mc+U*(30*S),R*(195*S),U*(30*S),F*(92*S),gold,kk*1.2,1)
			GFX.drawBox(x,mc+U*(362*S),R*(192*S),U*(8*S),F*(88*S),gold,kk*1.3,1)
			-- marquee with JACKPOT lettering
			local mq=mc+U*(430*S)
			GFX.drawBox(x,mq,R*(185*S),U*(60*S),F*(75*S),{.06,.08,.3},kk,1)
			local front=F*(76*S)
			GFX.memeText(mq+front+U*(4*S),"JACKPOT",R,U,7*S,2.4*S,LinearColor.new(k*1.1,k*.8,k*.2,1))
			-- chasing bulbs round the marquee
			local nb=22
			local wild=age>TM.jackpot
			for i=0,nb-1 do
				local t=i/nb
				local p
				if t<.35 then p=mq+front+R*((-180+t/.35*360)*S)+U*(54*S)
				elseif t<.5 then p=mq+front+R*(180*S)+U*((54-(t-.35)/.15*108)*S)
				elseif t<.85 then p=mq+front+R*((180-(t-.5)/.35*360)*S)+U*(-54*S)
				else p=mq+front+R*(-180*S)+U*((-54+(t-.85)/.15*108)*S) end
				local on
				if wild then on=(math.floor(age*16)+i)%2==0 else on=(i+math.floor(age*10))%3==0 end
				if on then GFX.glow(p+F*(2*S),12*S,1,.85,.4,1,0,.8) else GFX.glow(p+F*(2*S),5*S,.6,.4,.1,.6,0,.2) end
			end
			-- reel panel and three reels
			local rp=mc+U*(245*S)+F*(81*S)
			GFX.drawBox(x,rp,R*(160*S),U*(78*S),F*(2*S),{.05,.05,.06},kk,1)
			for i=1,3 do
				local wc=rp+R*((i-2)*102*S)+F*(3*S)
				GFX.drawBox(x,wc,R*(44*S),U*(64*S),F*(1*S),{.95,.95,.92},kk*1.2,1)
				local face=wc+F*(1.5*S)
				local ts=TM.stop[i]
				if age<TM.lever+.1 then
					GFX.slotSymbol(x,face,1+(i%4),R,U,6*S,1)
				elseif age<ts then
					-- spinning: symbols scroll down with motion streaks
					local pos=(age-TM.lever)*16+x.reelOff[i]
					local fr=pos%1
					local n0=math.floor(pos)
					for j=0,1 do
						local y=(fr-j)*110*S
						if math.abs(y)<42*S then
							GFX.slotSymbol(x,face+U*y,1+((n0+j)%4),R,U*1.35,5*S,.7)
						end
					end
					for j=-1,1 do
						local sx=face+R*(j*22*S)+F*(.5*S)
						GFX.beam(sx-U*(56*S),sx+U*(56*S),1.2*S,LinearColor.new(.4*k,.4*k,.4*k,.35))
					end
				else
					local t=age-ts
					local bob=math.sin(t*30)*math.exp(-t*9)*14*S
					GFX.slotSymbol(x,face+U*bob,2,R,U,6.5*S,1)
					if age>TM.jackpot then
						local pk=.5+.5*math.sin(age*20)
						GFX.ring(face+F*(1*S),R,U,52*S,3*S,24,.3,1,.4,pk)
					end
				end
				if GFX.once(x,"stop"..i,ts) then
					MoneyFX.sound("stop")
					GFX.flashAt(x,face,90*S,{1,.95,.7},.1)
					GFX.addShake(4*S)
				end
			end
			-- lever: slams down then springs back
			local lv=0
			if age>TM.lever-.12 and age<TM.lever then lv=(age-(TM.lever-.12))/.12
			elseif age>=TM.lever then lv=math.max(0,1-(age-TM.lever)/.4) end
			local ang=lv*1.9
			local lb=mc+R*(196*S)+U*(230*S)
			GFX.drawBox(x,lb,R*(14*S),U*(26*S),F*(26*S),gold,kk*1.2,1)
			local tip=lb+R*(12*S)+(U*math.cos(ang)+F*math.sin(ang))*(170*S)
			GFX.tube(x,{lb+R*(12*S),tip},{6*S,6*S},8,{.75,.75,.8},kk*1.2)
			GFX.drawSphere(x,tip,22*S,{.9,.05,.05},kk*1.2,1,6,10,.4)
			-- coin tray
			local tray=mc+U*(85*S)+F*(95*S)
			GFX.drawBox(x,tray,R*(110*S),U*(14*S),F*(22*S),gold,kk*1.1,1)
			-- the coin fountain after the jackpot
			if age>TM.jackpot then
				for i=1,GFX.rate(x,"coins",160) do
					local dir=(U*1.2+F*GFX.rand(.4,1)+R*GFX.rand(-.6,.6)):getSafeNormal()
					local sz=GFX.rand(7,11)*S
					GFX.add({kind=4,p=tray+U*(10*S)+R*(GFX.rand(-90,90)*S),v=dir*(GFX.rand(400,750)*S),life=GFX.rand(1.2,1.8),
						s0=sz,s1=sz,ramp={{1,.85,.35},{1,.7,.15}},grav=900*S,drag=.4,spin=GFX.rand(8,16),op=1,emis=1,
						fin=.001,fp=.4})
				end
			end
		end
		if GFX.once(x,"lever",TM.lever) then
			MoneyFX.sound("lever")
			MoneyFX.sound("spin")
		end

		-- JACKPOT!
		if GFX.once(x,"jackpot",TM.jackpot) then
			MoneyFX.sound("jackpot")
			local mc=x.mc+U*(300*S)
			GFX.flashAt(x,mc,420*S,{1,.92,.6},.3)
			GFX.shock(x,mc,R,U,520*S,10*S,GFX_GOLD,.6)
			GFX.light(x,mc,{1,.8,.35},40000,2600*S,.02,.5,.6)
			GFX.addShake(10*S)
		end
		if age>TM.jackpot and age<TM.boom+1.2 then
			local t=age-TM.jackpot
			local pop=math.min(GFX.backOut(math.clamp(t/.25,0,1)),1.15)
			local ta=a*(1-goalFxSmooth((age-(TM.boom+.9))/.3))
			local tc=x.mc+U*((620+math.sin(t*5)*12)*S)+F*(140*S)
			local wob=math.sin(t*9)*.06
			local ax=R*math.cos(wob)+U*math.sin(wob)
			local ay=U*math.cos(wob)-R*math.sin(wob)
			local gk=k*(1.1+.3*math.sin(t*14))
			GFX.memeText(tc-ay*(2*S)+F*(-1*S),"JACKPOT!",ax,ay,15*S*pop,6*S*pop,LinearColor.new(.25*k,.1*k,0,ta))
			GFX.memeText(tc,"JACKPOT!",ax,ay,15*S*pop,4.2*S*pop,LinearColor.new(gk,gk*.78,gk*.2,ta))
			for i=1,GFX.rate(x,"jpSpark",40) do
				GFX.add({kind=2,p=tc+R*(GFX.rand(-300,300)*S*pop)+U*(GFX.rand(-50,50)*S),v=GFX.rdir(x)*(80*S),life=.5,
					s0=4*S,s1=.5*S,ramp={{1,1,.9},{1,.8,.3}},drag=1,st=.03})
			end
		end

		-- BOOM: the machine bursts into gold bars, coins and money
		if GFX.once(x,"boom",TM.boom) then
			MoneyFX.sound("boom")
			MoneyFX.sound("rain")
			local c=x.mc+U*(230*S)
			GFX.blast(x,c,GFX_PAL_GOLD,1.5)
			GFX.flashAt(x,c,600*S,{1,.95,.75},.35)
			GFX.shock(x,x.base+U*(4*S),x.r,x.f,900*S,24*S,GFX_GOLD,1.1)
			GFX.light(x,c,{1,.8,.35},90000,3600*S,.02,.3,.9)
			GFX.addShake(26*S)
			-- cabinet chunks
			for i=1,GFX.n(x,50) do
				local dir=(GFX.rdir(x,.8)+U*.5):getSafeNormal()
				local sz=GFX.rand(12,26)*S
				GFX.add({kind=4,p=c+GFX.rdir(x)*(120*S),v=dir*(GFX.rand(500,1200)*S),life=GFX.rand(1.4,2),s0=sz,s1=sz*.8,
					ramp={(i%3==0) and {1,.75,.2} or {.78,.06,.06}},grav=900*S,drag=.6,spin=GFX.rand(4,10),op=1,emis=.5,fin=.001,fp=.4})
			end
			-- a storm of coins
			for i=1,GFX.n(x,160) do
				local dir=(GFX.rdir(x,.8)+U*.8):getSafeNormal()
				local sz=GFX.rand(7,12)*S
				GFX.add({kind=4,p=c+GFX.rdir(x)*(60*S),v=dir*(GFX.rand(600,1500)*S),life=GFX.rand(1.8,2.6),s0=sz,s1=sz,
					ramp={{1,.88,.4},{1,.7,.15}},grav=800*S,drag=.9,spin=GFX.rand(8,18),op=1,emis=1,fin=.001,fp=.5})
			end
			-- tumbling 3D gold bars
			for i=1,({4,6,8,10})[x.qi] do
				local dir=(GFX.rdir(x,.7)+U*1.1):getSafeNormal()
				x.bars[i]={p=c+GFX.rdir(x)*(60*S),v=dir*(GFX.rand(500,900)*S),a=GFX.rand(0,6.28),b=GFX.rand(0,6.28),
					wa=GFX.rand(-8,8),wb=GFX.rand(-8,8)}
			end
			-- bills blown out of the machine
			for i=1,GFX.n(x,36) do
				local dir=(GFX.rdir(x,.8)+U*1.3):getSafeNormal()
				x.bills[#x.bills+1]={p=c+GFX.rdir(x)*(80*S),v=dir*(GFX.rand(400,1000)*S),a=GFX.rand(0,6.28),b=GFX.rand(0,6.28),
					wa=GFX.rand(-3,3),wb=GFX.rand(-6,6),ph=GFX.rand(0,6.28),t0=age}
			end
		end

		-- money raining down over the goal
		if age>TM.boom+.15 and age<TM.rainEnd then
			for i=1,GFX.rate(x,"rain",30*x.q+8) do
				local p=x.base+R*(GFX.rand(-650,650)*S)+x.f*(GFX.rand(-150,250)*S)+U*(GFX.rand(650,850)*S)
				x.bills[#x.bills+1]={p=p,v=U*(-GFX.rand(80,160)*S),a=GFX.rand(0,6.28),b=GFX.rand(0,6.28),
					wa=GFX.rand(-3,3),wb=GFX.rand(-6,6),ph=GFX.rand(0,6.28),t0=age}
			end
		end

		-- physics + drawing: gold bars bounce on the floor, bills flutter down
		local floorH=Vec3.dot(x.base,U)
		for bi,b in ipairs(x.bars) do
			b.v=b.v-U*(1100*S*d)
			b.p=b.p+b.v*d
			b.a=b.a+b.wa*d
			b.b=b.b+b.wb*d
			local h=Vec3.dot(b.p,U)-floorH
			if h<12*S and Vec3.dot(b.v,U)<0 then
				b.p=b.p+U*(12*S-h)
				b.v=(b.v-U*(2*Vec3.dot(b.v,U)))*.45
				b.wa=b.wa*.6
				b.wb=b.wb*.6
			end
			local e1,e2,e3=GFX.tumble(R,F,U,b.a,b.b)
			GFX.drawBox(x,b.p,e1*(34*S),e2*(15*S),e3*(11*S),gold,kk*1.4,a)
			if (math.floor(age*6)+bi)%5==0 then GFX.glow(b.p+e3*(12*S),14*S,1,.95,.7,.8*a,age,.9) end
		end
		local keep={}
		for _,m in ipairs(x.bills) do
			local life=age-m.t0
			-- light paper: heavy drag, gentle gravity, side-to-side sway
			m.v=m.v*math.max(0,1-2.6*d)-U*(380*S*d)+R*(math.sin(age*3+m.ph)*160*S*d)
			m.p=m.p+m.v*d
			m.a=m.a+m.wa*d
			m.b=m.b+m.wb*d+math.sin(age*5+m.ph)*2*d
			local h=Vec3.dot(m.p,U)-floorH
			if h<2*S then m.p=m.p+U*(2*S-h); m.v=Vec3.zeroVector; m.wa=0; m.wb=0 end
			if life<3.2 then
				local e1,e2,e3=GFX.tumble(R,F,U,m.a,m.b)
				GFX.moneyBill(x,m.p,e1,e2,e3,26*S,12*S,a*(1-goalFxSmooth((life-2.8)/.4)))
				keep[#keep+1]=m
			end
		end
		x.bills=keep
	end,
}

-- 30: PAPARAZZI -------------------------------------------------------------------------------
-- The goalie who just got scored on becomes the most famous person in the arena. A red carpet
-- rolls out of the goal straight under them, gold stanchions pop up with sagging velvet ropes,
-- two spotlights find them and a gold name tag floats over their head. A pack of 3D
-- photographers behind the ropes start snapping: flashbulbs pop and light up the scene, faster
-- and faster, while a REC viewfinder locks onto the goalie. Then one giant flash... and a polaroid
-- of the shocked goalie flies up over the goal, captioned with their name: CAUGHT IN 4K.
-- No sound API, so there is only a hook:  PaparazziFX.onSound = function(event) ... end
--   events: "carpet", "ropes", "spot", "flash", "snap"
PAPARAZZI_TIMING={
	carpet=.15,    -- the carpet starts unrolling
	carpetEnd=.85, -- ...fully out
	ropes=.6,      -- stanchions pop up
	spot=.9,       -- spotlights land on the goalie
	shoot=1.05,    -- the photographers start
	rec=1.3,       -- viewfinder locks on
	snap=3.75,     -- the giant flash + polaroid
	total=5.8,
}
PaparazziFX={onSound=nil}
function PaparazziFX.sound(ev)
	if PaparazziFX.onSound then pcall(PaparazziFX.onSound,ev) end
end

-- a name in capitals the GFX_HAND font can draw
function GFX.fontName(nm,maxLen,fallback)
	nm=string.upper(tostring(nm or ""))
	local clean=""
	for i=1,#nm do
		local ch=string.sub(nm,i,i)
		if GFX_HAND[ch] or ch==" " then clean=clean..ch end
	end
	if #clean==0 then clean=fallback end
	return string.sub(clean,1,maxLen)
end

-- one photographer: legs, jacket, head with a cap, arms up holding a camera at their face, aimed
-- along dir. flash 0..1 lights the flashgun. Returns the flashgun position.
function GFX.paparazzo(x,feet,dir,U,lean,col,flash,kk)
	local S=x.S
	local side=Vec3.cross(U,dir):getSafeNormal()
	local hip=feet+U*(45*S)
	for sd=-1,1,2 do GFX.tube(x,{hip+side*(sd*8*S),feet+side*(sd*10*S)},{6*S,5*S},5,{.12,.12,.15},kk) end
	local chest=hip+U*(30*S)+dir*(lean*S)
	GFX.drawBox(x,chest,side*(16*S),dir*(10*S),U*(24*S),col,kk,1)
	local head=chest+U*(38*S)+dir*(lean*.5*S)
	GFX.drawSphere(x,head,12*S,{.85,.65,.5},kk,1,5,8,.1)
	GFX.drawBox(x,head+U*(9*S),side*(12*S),dir*(12*S),U*(4*S),{.1,.1,.12},kk,1)
	-- the camera in front of the face
	local cam=head+dir*(20*S)
	GFX.drawBox(x,cam,side*(13*S),dir*(7*S),U*(9*S),{.06,.06,.07},kk,1)
	GFX.tube(x,{cam+dir*(6*S),cam+dir*(18*S)},{6*S,6.5*S},8,{.1,.1,.12},kk)
	GFX.flatDisc(cam+dir*(18.5*S),side,U,5*S,LinearColor.new(.05,.12*GFX.K,.25*GFX.K,1))
	local gun=cam+U*(17*S)
	GFX.drawBox(x,gun,side*(7*S),dir*(5*S),U*(7*S),{.15,.15,.17},kk,1)
	-- arms up to the camera
	for sd=-1,1,2 do
		GFX.tube(x,{chest+side*(sd*16*S)+U*(16*S),cam+side*(sd*12*S)-U*(4*S)},{4.5*S,4*S},5,col,kk)
	end
	if flash>.01 then
		local fp=gun+dir*(6*S)
		GFX.glow(fp,70*S*flash,1,1,1,flash,0,1)
		GFX.star(fp+dir*(1*S),110*S*flash,10*S*flash,x.age*3,LinearColor.new(GFX.K*1.3*flash,GFX.K*1.3*flash,GFX.K*1.3*flash,flash))
	end
	return gun
end

GFX_DEFS[30]={
	duration=function() return PAPARAZZI_TIMING.total end,
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		-- find the goalie: the conceding team's player nearest the goal that was scored on
		x.goalie=nil
		local gname=nil
		pcall(function()
			local a=selectedArena
			local conceding=(goalFx.goal==a.home.goal) and a.home or a.away
			local best=math.huge
			for _,p in ipairs(conceding.players) do
				local dd=dist(p.root.position,goalFx.goal.position)
				if dd<best then best=dd; x.goalie=p end
			end
			if x.goalie and best>900 then x.goalie=nil end
			if x.goalie then gname=x.goalie.playerName end
		end)
		x.gname=GFX.fontName(gname,12,"THE GOALIE")
		x.paps={}
		local cols={{.2,.2,.25},{.35,.1,.1},{.12,.18,.32},{.25,.22,.15},{.15,.15,.15}}
		local n=({4,6,8,8})[x.qi]
		for i=1,n do
			local sd=(i%2==0) and 1 or -1
			local row=math.floor((i-1)/2)
			x.paps[i]={sd=sd,along=170+row*120+GFX.rand(-20,20),out=210+GFX.rand(0,60),col=cols[1+(i%#cols)],
				next=PAPARAZZI_TIMING.shoot+GFX.rand(0,.5),fl=-9,ph=GFX.rand(0,6)}
		end
		GFX.flashAt(x,x.base+x.u*(60*S),240*S,{1,.9,.85},.3)
		GFX.shock(x,x.base+x.u*(4*S),x.r,x.f,420*S,12*S,{1,.2,.25},.7)
		GFX.addShake(6*S)
	end,
	update=function(x,age,d)
		local S,TM=x.S,PAPARAZZI_TIMING
		local U=x.u
		local R=GFX.flatRight(x)
		local Fv=GFX.cp-x.base
		local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
		local k=GFX.K
		local kk=k*.55
		local a=1-goalFxSmooth((age-(TM.total-.45))/.45)
		-- where the goalie stands (refreshed; the goal centre if nobody is there)
		local gp=x.base+F*(40*S)
		local gHead=gp+U*(150*S)
		if x.goalie and selectedArena then
			local g=nil
			for _,p in ipairs(selectedArena.players) do
				if p.playerId==x.goalie.playerId then g=p; break end
			end
			if g then
				x.goalie=g
				local rel=g.root.position-x.base
				gp=x.base+R*Vec3.dot(rel,R)+F*Vec3.dot(rel,F)
				gHead=g.head.position
			end
		end
		local fl=x.base+U*(1.5*S)
		local start=fl+R*Vec3.dot(gp-x.base,R)+F*Vec3.dot(gp-x.base,F)-F*(60*S)

		-- the red carpet unrolling toward the camera, a roll at its leading edge
		local CL,CW=760*S,75*S
		local un=goalFxSmooth((age-TM.carpet)/(TM.carpetEnd-TM.carpet))
		if un>0 and a>.01 then
			local e=start+F*(CL*un)
			local q1,q2,q3,q4=start-R*CW,start+R*CW,e+R*CW,e-R*CW
			local rk=k*.5
			local cc=LinearColor.new(.75*rk,.03*rk,.05*rk,a)
			WorldDraw.drawTriangle(q1,q2,q3,cc,0)
			WorldDraw.drawTriangle(q1,q3,q4,cc,0)
			local trim=LinearColor.new(k*.9,k*.65,k*.15,a)
			GFX.beam(q1+U*(.5*S),q4+U*(.5*S),2.5*S,trim)
			GFX.beam(q2+U*(.5*S),q3+U*(.5*S),2.5*S,trim)
			if un<1 then
				local rr=(30*(1-un)+6)*S
				GFX.tube(x,{e-R*CW+U*rr,e+R*CW+U*rr},{rr,rr},10,{.72,.03,.05},kk)
			end
		end
		if GFX.once(x,"carpet",TM.carpet) then PaparazziFX.sound("carpet") end

		-- stanchions and velvet ropes along both sides
		if age>TM.ropes and a>.01 then
			local pu=goalFxEaseOut(math.clamp((age-TM.ropes)/.25,0,1))
			for sd=-1,1,2 do
				local prevTop=nil
				for j=0,3 do
					local base=start+F*((120+j*190)*S)+R*(sd*(CW+30*S))
					local top=base+U*(85*S*pu)
					GFX.tube(x,{base,top},{4*S,3.5*S},6,GFX_GOLD,kk*1.3)
					GFX.drawSphere(x,top,7*S,GFX_GOLD,kk*1.4,1,4,6,.6)
					GFX.flatDisc(base+U*(1*S),x.r,x.f,14*S,LinearColor.new(k*.6,k*.45,k*.1,a))
					if prevTop and pu>.9 then
						local last=prevTop
						for s=1,6 do
							local t=s/6
							local p=prevTop+(top-prevTop)*t-U*(math.sin(t*math.pi)*22*S)
							GFX.beam(last,p,3*S,LinearColor.new(.6*k*.6,.02,.05*k*.6,a))
							last=p
						end
					end
					prevTop=top
				end
			end
		end
		if GFX.once(x,"ropes",TM.ropes) then PaparazziFX.sound("ropes") end

		-- spotlights on the goalie and a gold name tag
		if age>TM.spot and a>.01 then
			local sk=goalFxSmooth((age-TM.spot)/.2)*a
			for sd=-1,1,2 do
				local src=gp+R*(sd*500*S)+U*(700*S)-F*(150*S)
				GFX.beam(src,gp,60*S,LinearColor.new(k*.25*sk,k*.22*sk,k*.15*sk,.12*sk))
				GFX.beam(src,gp,18*S,LinearColor.new(k*.5*sk,k*.47*sk,k*.35*sk,.25*sk))
				GFX.glow(src,30*S,1,.95,.8,sk,0,.9)
			end
			GFX.flatDisc(gp+U*(2*S),x.r,x.f,110*S,LinearColor.new(k*.45*sk,k*.42*sk,k*.3*sk,.35*sk))
			GFX.ring(gp+U*(3*S),x.r,x.f,110*S,4*S,32,1,.9,.6,.7*sk)
			-- name tag over their head with a little arrow
			local tag=gHead+U*((70+math.sin(age*3)*6)*S)
			local tu=5*S
			local w=#x.gname*5.2*tu*.5+14*S
			local toCam=(GFX.cp-tag):getSafeNormal()
			local bg=LinearColor.new(.05*sk,.03*sk,.01*sk,.85*sk)
			WorldDraw.drawTriangle(tag-R*w-U*(20*S),tag+R*w-U*(20*S),tag+R*w+U*(20*S),bg,0)
			WorldDraw.drawTriangle(tag-R*w-U*(20*S),tag+R*w+U*(20*S),tag-R*w+U*(20*S),bg,0)
			WorldDraw.drawTriangle(tag-R*(12*S)-U*(20*S),tag+R*(12*S)-U*(20*S),tag-U*(36*S),bg,0)
			local gk=k*1.1*sk
			local gl=LinearColor.new(gk,gk*.78,gk*.2,sk)
			GFX.beam(tag-R*w-U*(20*S),tag+R*w-U*(20*S),1.5*S,gl)
			GFX.beam(tag-R*w+U*(20*S),tag+R*w+U*(20*S),1.5*S,gl)
			GFX.memeText(tag+toCam*(1*S),x.gname,R,U,tu,tu*.32,gl)
		end
		if GFX.once(x,"spot",TM.spot) then PaparazziFX.sound("spot") end

		-- the photographers: frenzy builds until the big snap
		local frenzy=math.clamp((age-TM.shoot)/(TM.snap-TM.shoot),0,1)
		if age>TM.ropes and a>.01 then
			local pu=goalFxEaseOut(math.clamp((age-TM.ropes-.1)/.3,0,1))
			for i,pp in ipairs(x.paps) do
				local feet=start+F*(pp.along*S)+R*(pp.sd*pp.out*S)-U*((1-pu)*200*S)
				local aim=gHead-(feet+U*(110*S))
				local dir=(aim-U*Vec3.dot(aim,U)):getSafeNormal()
				if age>TM.shoot and age<TM.snap+.1 and age>=pp.next then
					pp.fl=age
					pp.next=age+GFX.rand(.25,.75)*(1-.75*frenzy)
					if GFX.rand()<.35 then GFX.light(x,feet+U*(130*S),{1,1,1},25000,1400*S,.005,.02,.08) end
					PaparazziFX.sound("flash")
				end
				local flash=math.max(0,1-(age-pp.fl)/.12)
				local lean=6+math.sin(age*6+pp.ph)*4+frenzy*6
				GFX.paparazzo(x,feet,dir,U,lean,pp.col,flash,kk)
				-- a soft cone of the flash reaching the goalie
				if flash>.3 then GFX.beam(feet+U*(125*S),gHead,25*S*flash,LinearColor.new(k*.3*flash,k*.3*flash,k*.3*flash,.15*flash)) end
			end
			-- the goalie gets lit up by every flash
			local lit=0
			for _,pp in ipairs(x.paps) do lit=math.max(lit,1-(age-pp.fl)/.12) end
			if lit>0 then GFX.glow(gHead,90*S*lit,1,1,1,.6*lit,0,1) end
		end

		-- REC viewfinder locked on the goalie
		if age>TM.rec and age<TM.snap then
			local vk=goalFxEaseOut(math.clamp((age-TM.rec)/.2,0,1))*a
			local c=gHead-U*(40*S)
			local hw,hh=(160+(1-vk)*120)*S,(130+(1-vk)*90)*S
			local wl=LinearColor.new(k*.95,k*.95,k*.95,vk)
			local L=40*S
			for sx=-1,1,2 do
				for sy=-1,1,2 do
					local cn=c+R*(sx*hw)+U*(sy*hh)
					GFX.beam(cn,cn-R*(sx*L),2.5*S,wl)
					GFX.beam(cn,cn-U*(sy*L),2.5*S,wl)
				end
			end
			GFX.beam(c-R*(14*S),c+R*(14*S),1.2*S,wl)
			GFX.beam(c-U*(14*S),c+U*(14*S),1.2*S,wl)
			if math.floor(age*3)%2==0 then
				GFX.flatDisc(c-R*(hw-24*S)+U*(hh-22*S),R,U,8*S,LinearColor.new(k*1.1,.05,.05,vk))
			end
			GFX.memeText(c-R*(hw-62*S)+U*(hh-22*S),"REC",R,U,3.4*S,1.2*S,wl)
			GFX.memeText(c+R*(hw-50*S)+U*(hh-22*S),"4K",R,U,3.4*S,1.2*S,wl)
		end

		-- SNAP: one giant flash and a polaroid of the shocked goalie flies up over the goal
		if GFX.once(x,"snap",TM.snap) then
			PaparazziFX.sound("snap")
			GFX.flashAt(x,gHead,900*S,{1,1,1},.45)
			GFX.light(x,gHead,{1,1,1},120000,4000*S,.005,.05,.4)
			GFX.addShake(14*S)
			for i=1,GFX.n(x,60) do
				local dir=GFX.rdir(x,.8):getSafeNormal()
				GFX.add({kind=2,p=gHead,v=dir*(GFX.rand(500,1200)*S),life=GFX.rand(.4,.8),s0=4*S,s1=.5*S,
					ramp={{1,1,1},{1,.9,.7}},drag=2,st=.05})
			end
		end
		if age>TM.snap then
			local t=age-TM.snap
			local pop=math.min(GFX.backOut(math.clamp(t/.35,0,1)),1.1)
			local from=gHead
			local to=x.base+U*(430*S)+F*(160*S)
			local m=goalFxEaseOut(math.clamp(t/.45,0,1))
			local pc=from+(to-from)*m+U*(math.sin(t*2.2)*8*S)
			local rot=.12*math.sin(t*1.7)-.06
			local ax=R*math.cos(rot)+U*math.sin(rot)
			local ay=U*math.cos(rot)-R*math.sin(rot)
			local toCam=(GFX.cp-pc):getSafeNormal()
			local W,H=190*S*pop,225*S*pop
			local function quad(c,hw,hh,lc)
				WorldDraw.drawTriangle(c-ax*hw-ay*hh,c+ax*hw-ay*hh,c+ax*hw+ay*hh,lc,0)
				WorldDraw.drawTriangle(c-ax*hw-ay*hh,c+ax*hw+ay*hh,c-ax*hw+ay*hh,lc,0)
			end
			local wk=k*.95
			quad(pc,W,H,LinearColor.new(wk,wk,wk*.95,a))
			-- the photo develops from white to the picture
			local dev=math.clamp(t/.8,0,1)
			local ph=pc+ay*(32*S*pop)+toCam*(1*S)
			local pw,phh=160*S*pop,150*S*pop
			quad(ph,pw,phh,LinearColor.new(wk*(1-dev)+.08*k*dev,wk*(1-dev)+.12*k*dev,wk*(1-dev)+.25*k*dev,a))
			if dev>.4 then
				local da=a*(dev-.4)/.6
				local fg=ph+toCam*(1*S)
				-- spotlight glow behind, the goalie's shocked face and shoulders
				GFX.ellipse(fg-ay*(60*S*pop),ax*(110*S*pop),ay*(70*S*pop),LinearColor.new(.15*k*da,.1*k*da,.05*k*da,da))
				GFX.ellipse(fg-ay*(95*S*pop)+toCam*(.5*S),ax*(85*S*pop),ay*(55*S*pop),LinearColor.new(.05,.05,.07,da))
				local face=fg+ay*(20*S*pop)+toCam*(1*S)
				GFX.ellipse(face,ax*(55*S*pop),ay*(62*S*pop),LinearColor.new(.85*kk,.65*kk,.5*kk,da))
				local blk=LinearColor.new(.02,.02,.02,da)
				local wht=LinearColor.new(k,k,k,da)
				for sd=-1,1,2 do
					GFX.ellipse(face+ax*(sd*20*S*pop)+ay*(14*S*pop)+toCam*(.5*S),ax*(13*S*pop),ay*(15*S*pop),wht)
					GFX.ellipse(face+ax*(sd*20*S*pop)+ay*(14*S*pop)+toCam*(1*S),ax*(5*S*pop),ay*(5*S*pop),blk)
					GFX.beam(face+ax*(sd*10*S*pop)+ay*(38*S*pop)+toCam*(1*S),face+ax*(sd*32*S*pop)+ay*(44*S*pop)+toCam*(1*S),2.5*S*pop,blk)
				end
				GFX.ellipse(face-ay*(26*S*pop)+toCam*(.5*S),ax*(13*S*pop),ay*(17*S*pop),blk)
			end
			-- caption: the goalie's name, and the stamp above
			local cap=pc-ay*(H-35*S*pop)+toCam*(1*S)
			GFX.memeText(cap,x.gname,ax,ay,5*S*pop,1.6*S*pop,LinearColor.new(.03,.03,.04,a))
			local st=math.clamp((t-.5)/.12,0,1)
			if st>0 then
				local sk=1+.8*(1-st)
				local rk=k*1.15
				GFX.memeText(pc+ay*(H+50*S)+toCam*(2*S),"CAUGHT IN 4K",ax,ay,9*S*sk,3*S*sk,LinearColor.new(rk,.08*rk,.06*rk,a*st))
				if GFX.once(x,"stamp",TM.snap+.62) then GFX.addShake(8*S) end
			end
		end
	end,
}

-- 31: BUSTED (Special) --------------------------------------------------------------------------
-- The goalie who let it in gets "arrested". Sirens: red and blue strobes wash over the goal as
-- three black-and-white police cruisers come screaming in, drift round the goalie in a ring
-- leaving tyre smoke, and skid to a stop pointing at them, light bars flashing. A helicopter
-- hovers overhead with its spotlight locked on the goalie. "FREEZE!" ... "HANDS UP!" A giant pair
-- of handcuffs drops onto them with a clink, yellow police tape snaps tight between the cars, and a
-- huge BUSTED! stamp slams down.
-- No sound API, so there is only a hook:  BustedFX.onSound = function(event) ... end
--   events: "siren", "skid", "freeze", "cuffs", "busted"
BUSTED_TIMING={
	cars=.15,      -- cruisers come in
	stop=1.35,     -- ...and skid to a stop
	heli=.9,       -- helicopter spotlight
	freeze=1.5,    -- "FREEZE!"
	hands=2.15,    -- "HANDS UP!"
	cuffs=2.7,     -- handcuffs land
	tape=3.0,      -- police tape snaps tight
	busted=3.25,   -- BUSTED! stamp
	total=5.6,
}
BustedFX={onSound=nil}
function BustedFX.sound(ev)
	if BustedFX.onSound then pcall(BustedFX.onSound,ev) end
end

-- the conceding team's player nearest the goal that was scored on (nil if nobody's near)
function GFX.findGoalie()
	local found=nil
	pcall(function()
		local a=selectedArena
		local conceding=(goalFx.goal==a.home.goal) and a.home or a.away
		local best=math.huge
		for _,p in ipairs(conceding.players) do
			local dd=dist(p.root.position,goalFx.goal.position)
			if dd<best then best=dd; found=p end
		end
		if best>900 then found=nil end
	end)
	return found
end

-- a black-and-white police cruiser. T = the way it faces, F = its side, light = strobe phase
function GFX.policeCar(x,c,T,U,F,wheelAng,light,kk)
	local S=x.S
	local white,black,glass,grey={.92,.92,.95},{.04,.04,.05},{.05,.07,.1},{.4,.4,.42}
	local function B(t,f,u,ht,hf,hu,col,k2)
		GFX.drawBox(x,c+T*(t*S)+F*(f*S)+U*(u*S),T*(ht*S),F*(hf*S),U*(hu*S),col,kk*(k2 or 1),1)
	end
	B(0,0,45,170,72,22,white)              -- doors (white middle)
	B(125,0,52,48,73,20,black)             -- black hood end
	B(-125,0,52,48,73,20,black)            -- black boot end
	B(-5,0,95,85,66,26,white)              -- cabin
	B(-5,0,98,86,67,14,glass)              -- windows
	B(178,0,40,6,74,10,grey)               -- bumpers
	B(-178,0,40,6,74,10,grey)
	-- light bar on the roof: red one side, blue the other, alternating
	local on1=(math.floor(light*8)%2==0)
	B(-5,0,126,14,52,5,black)
	for sd=-1,1,2 do
		local isRed=(sd<0)
		local lit=(isRed==on1)
		local col=isRed and {1,.08,.06} or {.1,.3,1}
		local p=c+T*(-5*S)+F*(sd*28*S)+U*(132*S)
		GFX.drawBox(x,p,T*(10*S),F*(22*S),U*(5*S),col,lit and kk*2.2 or kk*.5,1)
		if lit then GFX.glow(p,70*S,col[1],col[2],col[3],.9,0,.7) end
	end
	-- POLICE on the doors
	GFX.memeText(c+F*(73.5*S)+U*(48*S),"POLICE",T,U,4.5*S,1.6*S,LinearColor.new(.02,.02,.03,1))
	-- wheels
	for _,wt in ipairs({110,-110}) do
		for sd=-1,1,2 do
			local w=c+T*(wt*S)+F*(sd*70*S)+U*(26*S)
			GFX.tube(x,{w-F*(11*S),w+F*(11*S)},{26*S,26*S},10,black,kk)
			if sd>0 then
				local face=w+F*(11.5*S)
				GFX.flatDisc(face,T,U,13*S,LinearColor.new(.55*kk,.55*kk,.58*kk,1))
				for sp=0,2 do
					local ang=wheelAng+sp*2.094
					WorldDraw.drawLine(face+F*(1*S),face+F*(1*S)+(T*math.cos(ang)+U*math.sin(ang))*(12*S),.1,.1,.1,2,0)
				end
			end
		end
	end
	-- headlights
	for sd=-1,1,2 do GFX.glow(c+T*(178*S)+F*(sd*50*S)+U*(55*S),12*S,1,.97,.85,.9,0,.8) end
end

GFX_DEFS[31]={
	duration=function() return BUSTED_TIMING.total end,
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.goalie=GFX.findGoalie()
		x.cars={}
		for i=1,3 do
			x.cars[i]={th=(i-1)*2.094+.6,spin=(i%2==0) and 1 or -1}
		end
		GFX.flashAt(x,x.base+x.u*(60*S),240*S,{1,.2,.2},.2)
		GFX.shock(x,x.base+x.u*(4*S),x.r,x.f,420*S,12*S,{.2,.4,1},.6)
		GFX.addShake(6*S)
		BustedFX.sound("siren")
	end,
	update=function(x,age,d)
		local S,TM=x.S,BUSTED_TIMING
		local U=x.u
		local R=GFX.flatRight(x)
		local Fv=GFX.cp-x.base
		local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
		local k=GFX.K
		local kk=k*.55
		local a=1-goalFxSmooth((age-(TM.total-.45))/.45)
		-- where the goalie is
		local gp=x.base+F*(40*S)
		local gHead=gp+U*(150*S)
		if x.goalie and selectedArena then
			for _,p in ipairs(selectedArena.players) do
				if p.playerId==x.goalie.playerId then
					local rel=p.root.position-x.base
					gp=x.base+R*Vec3.dot(rel,R)+F*Vec3.dot(rel,F)
					gHead=p.head.position
				end
			end
		end
		local strobe=age*1.2
		-- red / blue washes over the scene
		if a>.01 then
			local on1=(math.floor(strobe*8)%2==0)
			local wc=on1 and {1,.1,.08} or {.1,.3,1}
			GFX.flatDisc(gp+U*(1.5*S),x.r,x.f,520*S,LinearColor.new(wc[1]*k*.12*a,wc[2]*k*.12*a,wc[3]*k*.12*a,.25*a))
			if GFX.once(x,"lightR",.05) then x.lr=GFX.light(x,gp+U*(200*S)+R*(-200*S),{1,.1,.08},20000,2200*S,.02,TM.total,.3) end
			if GFX.once(x,"lightB",.05) then x.lb=GFX.light(x,gp+U*(200*S)+R*(200*S),{.1,.3,1},20000,2200*S,.02,TM.total,.3) end
			-- strobe the two lights by switching their peak (the light ticker applies it)
			if x.lr then x.lr.peak=on1 and 20000*a or 0 end
			if x.lb then x.lb.peak=on1 and 0 or 20000*a end
		end

		-- the cruisers drift in round the goalie and stop pointing at them
		local m=goalFxSmooth((age-TM.cars)/(TM.stop-TM.cars))
		local radius=(330+(1-m)*700)*S
		for i,car in ipairs(x.cars) do
			local th=car.th+car.spin*(1-m)*2.6
			local dirOut=x.r*math.cos(th)+x.f*math.sin(th)
			local pos=gp+dirOut*radius
			-- heading: along the circle while driving, swinging to face the goalie as it stops
			local tang=(x.f*math.cos(th)-x.r*math.sin(th))*car.spin
			local face=dirOut*-1
			local T=(tang*(1-m)+face*m):getSafeNormal()
			local Fs=Vec3.cross(U,T):getSafeNormal()
			if age>TM.cars-.05 and a>.01 then
				GFX.policeCar(x,pos,T,U,Fs,-(1-m)*40,strobe+i*.3,kk)
				if m<.98 and age>TM.cars then
					for j=1,GFX.rate(x,"smoke"..i,35) do
						GFX.add({kind=3,p=pos-T*(110*S)+Fs*(GFX.rand(-70,70)*S)+U*(15*S),v=U*(GFX.rand(30,80)*S)+GFX.rdir(x)*(40*S),
							life=GFX.rand(.9,1.4),s0=25*S,s1=GFX.rand(70,110)*S,ramp={{.7,.7,.72},{.35,.35,.37}},op=.35,fin=.05,drag=1.4,
							spin=GFX.rand(-1,1)})
					end
				end
			end
			car.pos=pos
			car.T=T
		end
		if GFX.once(x,"skid",TM.stop-.25) then BustedFX.sound("skid") end
		if GFX.once(x,"stopped",TM.stop) then GFX.addShake(8*S) end

		-- the helicopter and its spotlight
		if age>TM.heli and a>.01 then
			local hk=goalFxSmooth((age-TM.heli)/.3)*a
			local hp=gp+U*(850*S)-F*(250*S)+R*(math.sin(age*.8)*60*S)
			GFX.beam(hp,gp,90*S*hk,LinearColor.new(k*.35*hk,k*.34*hk,k*.3*hk,.12*hk))
			GFX.beam(hp,gp,30*S*hk,LinearColor.new(k*.6*hk,k*.58*hk,k*.5*hk,.22*hk))
			GFX.flatDisc(gp+U*(2*S),x.r,x.f,95*S,LinearColor.new(k*.5*hk,k*.48*hk,k*.4*hk,.4*hk))
			GFX.drawBox(x,hp,R*(60*S),F*(28*S),U*(26*S),{.08,.08,.1},kk,1)
			GFX.tube(x,{hp-R*(50*S),hp-R*(150*S)},{9*S,4*S},6,{.08,.08,.1},kk)
			for b=0,1 do
				local ang=age*25+b*1.5708
				local bd=R*math.cos(ang)+F*math.sin(ang)
				GFX.beam(hp+U*(32*S)-bd*(150*S),hp+U*(32*S)+bd*(150*S),3*S,LinearColor.new(.05,.05,.06,.6*hk))
			end
			GFX.glow(hp-U*(28*S),20*S,1,1,.9,hk,0,1)
		end

		-- the megaphone lines from the lead car
		local lead=x.cars[1].pos or gp
		local lines={{t=TM.freeze,d=.6,text="FREEZE!"},{t=TM.hands,d=.6,text="HANDS UP!"}}
		for i,ln in ipairs(lines) do
			if age>=ln.t and age<ln.t+ln.d then
				if GFX.once(x,"say"..i,ln.t) then BustedFX.sound("freeze") end
				local pop=math.min(GFX.backOut((age-ln.t)/.12),1.15)
				local ba=a*(1-goalFxSmooth((age-(ln.t+ln.d-.08))/.08))
				GFX.memeBubble(x,lead+U*(260*S),ln.text,lead+U*(140*S),pop*1.2,ba)
			end
		end

		-- handcuffs drop onto the goalie
		if age>TM.cuffs-.25 and a>.01 then
			local t=math.clamp((age-(TM.cuffs-.25))/.25,0,1)
			local cc=gHead-U*(70*S)+F*(40*S)+U*((1-t*t)*500*S)
			local ck=k*.75
			for sd=-1,1,2 do
				local rc=cc+R*(sd*32*S)
				GFX.ring(rc,R,U,24*S,5*S,20,.75,.75,.8,a)
				GFX.ring(rc+F*(1*S),R,U,24*S,1.5*S,20,1,1,1,.5*a)
			end
			for j=0,3 do
				local p=cc+R*((-10+j*6.6)*S)-U*(math.sin(j/3*math.pi)*6*S)
				GFX.ring(p,R,U,4*S,1.6*S,8,.7*ck/k,.7*ck/k,.75*ck/k,a)
			end
			if t>=1 and GFX.once(x,"cuffs",TM.cuffs) then
				BustedFX.sound("cuffs")
				GFX.flashAt(x,cc,120*S,{.9,.95,1},.12)
				for j=1,GFX.n(x,18) do
					GFX.add({kind=2,p=cc,v=GFX.rdir(x)*(GFX.rand(200,500)*S),life=.4,s0=3*S,s1=.5*S,ramp={{1,1,1},{.7,.75,.8}},
						drag=2,st=.03})
				end
			end
		end

		-- police tape snaps tight between the cars
		if age>TM.tape and a>.01 then
			local sn=goalFxEaseOut(math.clamp((age-TM.tape)/.15,0,1))
			for i=1,3 do
				local c1,c2=x.cars[i],x.cars[(i%3)+1]
				if c1.pos and c2.pos then
					local p1,p2=c1.pos+U*(90*S),c2.pos+U*(90*S)
					local mid=(p1+p2)*.5-U*((1-sn)*60*S)
					local yk=k*.95
					local yl=LinearColor.new(yk,yk*.82,.05*yk,a)
					GFX.beam(p1,mid,9*S,yl)
					GFX.beam(mid,p2,9*S,yl)
					if sn>.9 then
						local dirT=(p2-p1):getSafeNormal()
						local up=Vec3.cross(dirT,(GFX.cp-mid):getSafeNormal()):getSafeNormal()
						if Vec3.dot(up,U)<0 then up=up*-1 end
						if Vec3.dot(dirT,R)<0 then dirT=dirT*-1 end
						GFX.memeText(mid+(GFX.cp-mid):getSafeNormal()*(1*S),"POLICE LINE",dirT,up,2.4*S,.9*S,LinearColor.new(.02,.02,.02,a))
					end
				end
			end
		end

		-- BUSTED!
		if age>TM.busted then
			local t=age-TM.busted
			local sk=1+1.4*(1-goalFxEaseOut(math.clamp(t/.13,0,1)))
			local ba=a
			local cen=gp+U*(420*S)+F*(220*S)
			local tl=.14
			local ax=R*math.cos(tl)+U*math.sin(tl)
			local ay=U*math.cos(tl)-R*math.sin(tl)
			local rk=k*1.15
			local red=LinearColor.new(rk,.06*rk,.05*rk,ba)
			local w,h=300*S*sk,78*S*sk
			local q1,q2,q3,q4=cen-ax*w-ay*h,cen+ax*w-ay*h,cen+ax*w+ay*h,cen-ax*w+ay*h
			GFX.beam(q1,q2,7*S*sk,red)
			GFX.beam(q2,q3,7*S*sk,red)
			GFX.beam(q3,q4,7*S*sk,red)
			GFX.beam(q4,q1,7*S*sk,red)
			GFX.memeText(cen,"BUSTED!",ax,ay,15*S*sk,4.6*S*sk,red)
			if GFX.once(x,"busted",TM.busted+.13) then
				BustedFX.sound("busted")
				GFX.addShake(16*S)
				GFX.flashAt(x,cen,300*S,{1,.3,.3},.15)
			end
		end
	end,
}

-- 32: BULLSEYE ----------------------------------------------------------------------------------
-- A giant 3D archery target (straw boss, five coloured rings, a wooden tripod) rises up over the
-- goal. Three huge arrows come whistling in from behind the camera: the first thunks into the
-- red, the second hits dead centre... and the third splits the second straight down the middle.
-- BULLSEYE! The rings ripple, golden light rays burst out of the centre, shockwaves and confetti
-- fly, and then the whole target bursts apart into tumbling shards of every ring colour.
-- Each hit pops a score over the target. No sound API, so there is only a hook:
--   BullseyeFX.onSound = function(event) ... end   -- "rise", "whoosh", "thunk", "split", "bullseye", "burst"
BULLSEYE_TIMING={
	rise=.45,
	shots={{t0=.55,t1=.8},{t0=1.05,t1=1.3},{t0=1.65,t1=1.9}},  -- arrow flights (launch, hit)
	bullseye=2.0,
	burst=3.45,
	total=5.2,
}
BullseyeFX={onSound=nil}
function BullseyeFX.sound(ev)
	if BullseyeFX.onSound then pcall(BullseyeFX.onSound,ev) end
end
GFX_TARGET_RINGS={{1,1,1},{.08,.08,.1},{.15,.45,1},{1,.12,.1},{1,.8,.15}}   -- outside to centre

-- an arrow with its tip at `tip`, pointing along dir. wob bends the tail sideways (quiver)
function GFX.arrow(x,tip,dir,S,col,kk,wob)
	local side=Vec3.cross(dir,x.u)
	if side:length()<.05 then side=x.r end
	side=side:getSafeNormal()
	local up=Vec3.cross(side,dir):getSafeNormal()
	local tail=tip-dir*(300*S)+side*(wob or 0)
	local neck=tip-dir*(34*S)
	GFX.tube(x,{neck,tip},{9*S,.5*S},8,{.75,.75,.8},kk*1.3)
	GFX.tube(x,{tail,neck},{3.5*S,3.5*S},6,{.55,.35,.15},kk)
	-- three fletching vanes
	for v=0,2 do
		local ang=v*2.094
		local out=side*math.cos(ang)+up*math.sin(ang)
		local a1,a2=tail+(neck-tail):getSafeNormal()*(10*S),tail+(neck-tail):getSafeNormal()*(70*S)
		local lc=LinearColor.new(col[1]*kk,col[2]*kk,col[3]*kk,1)
		WorldDraw.drawTriangle(a1,a2,a1+out*(22*S),lc,0)
		WorldDraw.drawTriangle(a2,a1+out*(22*S),a2+out*(8*S),lc,0)
	end
end

GFX_DEFS[32]={
	duration=function() return BULLSEYE_TIMING.total end,
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.tc0=x.base+x.u*(280*S)
		x.tcol=GFX.teamColor(true)
		-- where each arrow lands, relative to the centre (R, U offsets)
		x.hits={{70,-50},{0,0},{0,0}}
		x.score={"8","10","10"}
		x.from={}
		for i=1,3 do x.from[i]={sx=({-1,1,0})[i]*500,sy=({250,350,420})[i]} end
		BullseyeFX.sound("rise")
		GFX.flashAt(x,x.base+x.u*(60*S),200*S,{1,.9,.6},.25)
		GFX.shock(x,x.base+x.u*(4*S),x.r,x.f,420*S,12*S,{1,.8,.3},.6)
	end,
	update=function(x,age,d)
		local S,TM=x.S,BULLSEYE_TIMING
		local U=x.u
		local R=GFX.flatRight(x)
		local Fv=GFX.cp-x.tc0
		local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
		local k=GFX.K
		local kk=k*.55
		local a=1-goalFxSmooth((age-(TM.total-.4))/.4)
		local rise=goalFxEaseOut(math.clamp(age/TM.rise,0,1))
		-- the target shakes a little on every hit
		local jolt=0
		for i,sh in ipairs(TM.shots) do
			if age>sh.t1 then jolt=jolt+math.sin((age-sh.t1)*45)*math.exp(-(age-sh.t1)*10)*6*S end
		end
		local tc=x.tc0-U*((1-rise)*600*S)-F*(jolt)
		local RAD=250*S
		local burst=age>=TM.burst

		if not burst and a>.01 then
			-- straw boss (a thick disc) and tripod legs
			GFX.tube(x,{tc-F*(40*S),tc-F*(2*S)},{RAD+10*S,RAD+10*S},28,{.75,.6,.32},kk)
			for _,lg in ipairs({{-1,0},{1,0},{0,-1}}) do
				local foot=tc+R*(lg[1]*260*S)-F*((lg[2]==0) and 40 or 260)*S-U*(Vec3.dot(tc-x.base,U))
				GFX.tube(x,{tc-F*(45*S)+R*(lg[1]*80*S),foot},{8*S,8*S},6,{.4,.25,.1},kk)
			end
			-- the rings (they ripple outward after the bullseye)
			local rip=0
			if age>TM.bullseye then rip=math.sin((age-TM.bullseye)*14)*math.exp(-(age-TM.bullseye)*3) end
			for ri,col in ipairs(GFX_TARGET_RINGS) do
				local rr=RAD*(1-(ri-1)/5)*(1+rip*.04*ri)
				local lk=kk*1.3
				if ri==5 and age>TM.bullseye then lk=lk*(1.5+.5*math.sin(age*20)) end
				GFX.flatDisc(tc+F*((ri*.6)*S),R,U,rr,LinearColor.new(col[1]*lk,col[2]*lk,col[3]*lk,1))
			end
			GFX.ring(tc+F*(4*S),R,U,RAD,2*S,48,.1,.1,.1,1)
		end

		-- the arrows
		for i,sh in ipairs(TM.shots) do
			local hit=tc+R*(x.hits[i][1]*S)+U*(x.hits[i][2]*S)
			local start=x.tc0+F*(1700*S)+R*(x.from[i].sx*S)+U*(x.from[i].sy*S)
			local split=(i==2 and age>TM.shots[3].t1)
			if age>=sh.t0 and not burst and not split and a>.01 then
				local tip,dir,wob
				if age<sh.t1 then
					local t=(age-sh.t0)/(sh.t1-sh.t0)
					local arc=math.sin(t*math.pi)*80*S
					tip=start+(hit-start)*t+U*arc
					dir=(hit-start):getSafeNormal()
					wob=0
					for j=1,GFX.rate(x,"trail"..i,80) do
						GFX.add({kind=2,p=tip-dir*(300*S),v=GFX.rdir(x)*(40*S),life=.3,s0=3*S,s1=.5*S,
							ramp={{1,1,1},x.tcol},drag=2,st=.03})
					end
				else
					dir=(hit-start):getSafeNormal()
					tip=hit-dir*(25*S)
					local t=age-sh.t1
					wob=math.sin(t*55)*math.exp(-t*7)*14*S
				end
				GFX.arrow(x,tip,dir,S,(i==3) and {1,.8,.2} or x.tcol,kk*1.2,wob)
			end
			if GFX.once(x,"whoosh"..i,sh.t0) then BullseyeFX.sound("whoosh") end
			if GFX.once(x,"hit"..i,sh.t1) then
				BullseyeFX.sound((i==3) and "split" or "thunk")
				GFX.flashAt(x,hit,(i==3) and 260*S or 140*S,{1,.95,.75},.12)
				GFX.shock(x,hit+F*(5*S),R,U,(i==3) and 300*S or 160*S,6*S,{1,.85,.4},.4)
				GFX.addShake((i==3) and 12*S or 6*S)
				for j=1,GFX.n(x,(i==3) and 40 or 16) do
					local dv=(F+GFX.rdir(x)*.8):getSafeNormal()
					local sz=GFX.rand(3,7)*S
					GFX.add({kind=4,p=hit+F*(6*S),v=dv*(GFX.rand(200,600)*S),life=GFX.rand(.6,1),s0=sz,s1=sz*.6,
						ramp={(i==3) and {.55,.35,.15} or {.8,.65,.35}},grav=700*S,drag=.8,spin=GFX.rand(5,12),op=1,emis=.4,fin=.001,fp=.4})
				end
				x.pops=x.pops or {}
				x.pops[#x.pops+1]={t0=age,p=hit+F*(20*S),txt=(i==3) and "SPLIT!" or x.score[i]}
			end
		end

		-- score pops floating up off the target
		for _,pp in ipairs(x.pops or {}) do
			local t=age-pp.t0
			if t<1.1 and a>.01 then
				local pk=math.min(GFX.backOut(math.clamp(t/.15,0,1)),1.1)
				local pa=a*(1-goalFxSmooth((t-.8)/.3))
				local gk=k*1.1
				GFX.memeText(pp.p+U*((40+t*120)*S),pp.txt,R,U,8*S*pk,2.8*S*pk,LinearColor.new(gk,gk*.85,gk*.3,pa))
			end
		end

		-- BULLSEYE!
		if age>TM.bullseye and not burst and a>.01 then
			local t=age-TM.bullseye
			local rk=goalFxSmooth(t/.2)
			-- golden rays spinning out of the centre
			for j=0,11 do
				local ang=j/12*6.2832+t*.8
				local dir=R*math.cos(ang)+U*math.sin(ang)
				local len=(420+math.sin(t*6+j)*80)*S*rk
				GFX.beam(tc+F*(6*S),tc+F*(6*S)+dir*len,(16+(j%2)*10)*S*rk,LinearColor.new(k*.5,k*.4,k*.1,.25*rk))
			end
			GFX.glow(tc+F*(8*S),120*S*rk,1,.85,.35,rk,t,1)
			local pop=math.min(GFX.backOut(math.clamp(t/.25,0,1)),1.15)
			local gk=k*(1.1+.25*math.sin(t*14))
			local txc=tc+U*(RAD+110*S)+F*(30*S)
			GFX.memeText(txc-U*(3*S)-F*(1*S),"BULLSEYE!",R,U,14*S*pop,6*S*pop,LinearColor.new(.3*k,.12*k,0,1))
			GFX.memeText(txc,"BULLSEYE!",R,U,14*S*pop,4*S*pop,LinearColor.new(gk,gk*.8,gk*.2,1))
		end
		if GFX.once(x,"bullseye",TM.bullseye) then
			BullseyeFX.sound("bullseye")
			GFX.flashAt(x,tc,500*S,{1,.92,.6},.3)
			GFX.shock(x,tc+F*(8*S),R,U,700*S,14*S,{1,.8,.3},.8)
			GFX.shock(x,x.base+U*(4*S),x.r,x.f,700*S,14*S,x.tcol,.9)
			GFX.light(x,tc+F*(60*S),{1,.85,.45},60000,3000*S,.02,.6,.6)
			GFX.addShake(14*S)
			for j=1,GFX.n(x,100) do
				local dir=(F*.6+GFX.rdir(x,.6)):getSafeNormal()
				local sz=GFX.rand(6,10)*S
				GFX.add({kind=4,quad=true,p=tc+F*(10*S),v=dir*(GFX.rand(600,1300)*S),life=GFX.rand(1.8,2.6),s0=sz,s1=sz,
					ramp={GFX_FW_COLS[1+(j%#GFX_FW_COLS)]},grav=380*S,drag=2.2,spin=GFX.rand(6,14),op=.95,emis=.9,fin=.001,fp=.5})
			end
		end

		-- the target bursts apart
		if GFX.once(x,"burst",TM.burst) then
			BullseyeFX.sound("burst")
			GFX.blast(x,tc,GFX_PAL_GOLD,1.3)
			GFX.addShake(20*S)
			for ri,col in ipairs(GFX_TARGET_RINGS) do
				local r0,r1=RAD*(1-ri/5),RAD*(1-(ri-1)/5)
				for j=1,GFX.n(x,24) do
					local th=GFX.rand(0,6.2832)
					local rr=GFX.rand(r0,r1)
					local p=tc+(R*math.cos(th)+U*math.sin(th))*rr
					local dv=((p-tc):getSafeNormal()+F*.7+GFX.rdir(x)*.3):getSafeNormal()
					local sz=GFX.rand(14,26)*S
					GFX.add({kind=4,p=p,v=dv*(GFX.rand(500,1100)*S),life=GFX.rand(1.4,2),s0=sz,s1=sz*.8,ramp={col},
						grav=800*S,drag=.6,spin=GFX.rand(3,9),op=1,emis=.7,fin=.001,fp=.4})
				end
			end
		end
	end,
}

-- 33: LIGHT SHOW --------------------------------------------------------------------------------
-- A concert laser show, timed to a 128 BPM beat. Two truss towers rise either side of the goal
-- with moving-head lasers on them, and stage haze rolls across the floor.
--   1. Fans of laser beams in the team colour and white sweep across the goal on the beat,
--      with bright dots where they hit the floor.
--   2. The lasers cross into a strobing X-grid that cycles through the rainbow every beat.
--   3. A mirror ball drops in over the goal and spins; the lasers hit it and it throws dozens of
--      thin rotating beams and sparkles everywhere.
--   4. Finale: every laser snaps onto the goal, a white-hot point swells... and blows into a
--      rainbow blast with confetti and fireworks.
-- No sound API, so there is only a hook:  LightShowFX.onSound = function(event) ... end
--   events: "beat", "drop", "ball", "finale"
LIGHTSHOW_TIMING={
	towers=.35,    -- towers up
	fan=.35,       -- phase 1
	grid=1.75,     -- phase 2
	ball=3.0,      -- phase 3
	converge=4.15, -- phase 4: lasers lock on
	boom=4.6,      -- ...and blow
	total=6.2,
	bpm=128,
}
LightShowFX={onSound=nil}
function LightShowFX.sound(ev)
	if LightShowFX.onSound then pcall(LightShowFX.onSound,ev) end
end
GFX_RAINBOW={{1,.1,.1},{1,.55,.05},{1,1,.1},{.1,1,.25},{.1,.6,1},{.55,.15,1},{1,.15,.8}}

-- a laser: faint wide glow + bright core, and a dot where it ends
function GFX.laser(p,q,w,col,a,dot)
	local k=GFX.K
	GFX.beam(p,q,w*5,LinearColor.new(col[1]*k*.35*a,col[2]*k*.35*a,col[3]*k*.35*a,.18*a))
	GFX.beam(p,q,w,LinearColor.new((col[1]*.6+.4)*k*1.2*a,(col[2]*.6+.4)*k*1.2*a,(col[3]*.6+.4)*k*1.2*a,a))
	if dot then GFX.glow(q,w*9,col[1],col[2],col[3],a,0,.9) end
end

GFX_DEFS[33]={
	duration=function() return LIGHTSHOW_TIMING.total end,
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.tc=GFX.teamColor(true)
		x.c=x.base+x.f*(60*S)
		GFX.flashAt(x,x.base+x.u*(60*S),220*S,GFX.mixW(x.tc,.5),.25)
		GFX.shock(x,x.base+x.u*(4*S),x.r,x.f,420*S,12*S,x.tc,.6)
	end,
	update=function(x,age,d)
		local S,TM=x.S,LIGHTSHOW_TIMING
		local U=x.u
		local R=GFX.flatRight(x)
		local Fv=GFX.cp-x.c
		local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
		local k=GFX.K
		local kk=k*.5
		local a=1-goalFxSmooth((age-(TM.total-.5))/.5)
		local c=x.c
		local fl=c+U*(2*S)
		local beatLen=60/TM.bpm
		local beat=age/beatLen
		local onBeat=1-(beat%1)                 -- 1 on the beat, falling to 0
		local bi=math.floor(beat)
		if GFX.once(x,"beat"..bi,bi*beatLen) and age<TM.converge then
			LightShowFX.sound("beat")
			if age>TM.grid then GFX.flashAt(x,c+U*(300*S),300*S,GFX_RAINBOW[1+bi%7],.06) end
		end
		local tc=x.tc
		local white={1,1,1}

		-- stage haze rolling over the floor
		if age<TM.total-.6 then
			for i=1,GFX.rate(x,"haze",14) do
				GFX.add({kind=3,p=c+R*(GFX.rand(-600,600)*S)+F*(GFX.rand(-200,200)*S)+U*(20*S),v=R*(GFX.rand(-40,40)*S),
					life=GFX.rand(2,3),s0=80*S,s1=GFX.rand(160,220)*S,ramp={{.35,.35,.4},{.2,.2,.25}},op=.18,fin=.2,fp=1,drag=.3})
			end
		end

		-- truss towers with lights (rise up first)
		local up=goalFxEaseOut(math.clamp(age/TM.towers,0,1))
		local heads={}
		for sd=-1,1,2 do
			local base=c+R*(sd*560*S)-U*((1-up)*700*S)
			local H=620*S
			if a>.01 then
				for cx=-1,1,2 do
					for cz=-1,1,2 do
						local leg=base+R*(cx*22*S)+F*(cz*22*S)
						GFX.tube(x,{leg,leg+U*H},{3*S,3*S},5,{.6,.6,.65},kk*1.2)
					end
				end
				for j=1,6 do
					local y=j/6*H
					GFX.beam(base+R*(-22*S)+U*(y-H/6),base+R*(22*S)+U*y,1.5*S,LinearColor.new(.4*kk,.4*kk,.42*kk,a))
				end
			end
			for hj=1,2 do
				local hp=base+U*(H*(hj==1 and 1 or .55))+F*(30*S)-R*(sd*20*S)
				GFX.drawBox(x,hp,R*(16*S),F*(16*S),U*(14*S),{.08,.08,.1},kk,a)
				heads[#heads+1]={p=hp,sd=sd,j=hj}
			end
		end

		-- phase 1: fans sweeping on the beat
		if age>TM.fan and age<TM.grid and a>.01 then
			local pa=goalFxSmooth((age-TM.fan)/.2)
			for hi,h in ipairs(heads) do
				local sweep=math.sin(age*2.1+hi)*.9
				for b=-2,2 do
					local ang=sweep+b*.22
					local hitp=fl+R*((-h.sd*250+math.sin(ang)*420)*S)+F*(math.cos(ang*1.7)*220*S)
					local col=((b+hi)%2==0) and tc or white
					GFX.laser(h.p,hitp,2.2*S,col,pa*(.55+.45*onBeat),true)
				end
			end
		end

		-- phase 2: a strobing X-grid cycling the rainbow every beat
		if age>TM.grid and age<TM.ball+.2 and a>.01 then
			local pa=goalFxSmooth((age-TM.grid)/.15)*(1-goalFxSmooth((age-TM.ball)/.2))
			local col=GFX_RAINBOW[1+bi%7]
			local strobe=(math.floor(age*16)%2==0) and 1 or .35
			for hi,h in ipairs(heads) do
				for b=0,5 do
					local tgt=c+R*((-h.sd*(-500+b*200))*S)+U*((40+((b+bi)%3)*120)*S)+F*(260*S)
					GFX.laser(h.p,tgt,2*S,col,pa*strobe,false)
				end
			end
			-- a laser sheet scanning across the floor
			local sx=math.sin(age*5)*500*S
			GFX.laser(heads[1].p,fl+R*sx-F*(200*S),3*S,white,pa,true)
			GFX.laser(heads[3].p,fl+R*sx+F*(200*S),3*S,white,pa,true)
		end
		if GFX.once(x,"drop",TM.grid) then LightShowFX.sound("drop"); GFX.addShake(6*S) end

		-- phase 3: the mirror ball
		if age>TM.ball-.3 and age<TM.boom then
			local t=age-(TM.ball-.3)
			local drop=goalFxEaseOut(math.clamp(t/.4,0,1))
			local bc=c+U*((700-drop*330)*S)
			GFX.beam(bc,bc+U*(500*S),1.5*S,LinearColor.new(.3*kk,.3*kk,.3*kk,a))
			GFX.drawSphere(x,bc,55*S,{.75,.78,.85},kk*1.3,a,8,14,.9)
			-- mirror tiles glinting as it spins
			for j=0,23 do
				local th=j/24*6.2832+age*2.5
				local ph=(j%4-1.5)*.45
				local n=R*(math.cos(th)*math.cos(ph))+F*(math.sin(th)*math.cos(ph))+U*math.sin(ph)
				if Vec3.dot(n,(GFX.cp-bc):getSafeNormal())>.1 and (j+math.floor(age*12))%3==0 then
					GFX.glow(bc+n*(56*S),9*S,1,1,1,a,0,1)
				end
			end
			if age>TM.ball then
				local pa=goalFxSmooth((age-TM.ball)/.2)*a
				-- the towers' lasers hit the ball
				for hi,h in ipairs(heads) do GFX.laser(h.p,bc,2*S,(hi%2==0) and tc or white,pa*.8,false) end
				-- and it throws beams everywhere
				for j=0,19 do
					local th=j/20*6.2832+age*1.6
					local el=-.15-(j%4)*.18
					local dir=(R*math.cos(th)+F*math.sin(th))*math.cos(el)+U*math.sin(el)
					local col=GFX_RAINBOW[1+j%7]
					GFX.laser(bc+dir*(56*S),bc+dir*(900*S),1.2*S,col,pa*.6,false)
				end
				-- sparkles on the floor
				for i=1,GFX.rate(x,"spark",60) do
					local th=GFX.rand(0,6.2832)
					GFX.add({kind=1,p=fl+(x.r*math.cos(th)+x.f*math.sin(th))*(GFX.rand(100,600)*S),v=Vec3.zeroVector,life=.25,
						s0=10*S,s1=2*S,ramp={{1,1,1},GFX_RAINBOW[1+i%7]},fin=.01,fp=.2})
				end
			end
		end
		if GFX.once(x,"ball",TM.ball) then LightShowFX.sound("ball") end

		-- phase 4: everything locks on to the goal and blows
		if age>TM.converge and age<TM.boom then
			local t=(age-TM.converge)/(TM.boom-TM.converge)
			local core=c+U*(150*S)
			for hi,h in ipairs(heads) do
				GFX.laser(h.p,core,(2+t*4)*S,(hi%2==0) and tc or white,a,false)
			end
			GFX.glow(core,(40+t*260)*S,1,1,1,1,age*3,1)
			GFX.addShake(t*6*S)
		end
		if GFX.once(x,"boom",TM.boom) then
			LightShowFX.sound("finale")
			local core=c+U*(150*S)
			GFX.blast(x,core,GFX.teamPal(tc),1.6)
			GFX.flashAt(x,core,700*S,{1,1,1},.35)
			GFX.shock(x,fl+U*(2*S),x.r,x.f,900*S,24*S,tc,1.1)
			GFX.addShake(24*S)
			for j=1,GFX.n(x,140) do
				local dir=(GFX.rdir(x,.8)+U*.9):getSafeNormal()
				local sz=GFX.rand(6,10)*S
				GFX.add({kind=4,quad=true,p=core,v=dir*(GFX.rand(700,1500)*S),life=GFX.rand(2,2.8),s0=sz,s1=sz,
					ramp={GFX_RAINBOW[1+(j%7)]},grav=380*S,drag=2.3,spin=GFX.rand(6,14),op=.95,emis=.9,fin=.001,fp=.5})
			end
			for i=1,({3,4,5,6})[x.qi] do
				x.shells=x.shells or {}
				x.shells[i]={t=TM.boom+.15+i*.12,pos=c+R*(GFX.rand(-450,450)*S)+U*(GFX.rand(380,560)*S),kind=i%6}
			end
		end
		for i,sh in ipairs(x.shells or {}) do
			if GFX.once(x,"shell"..i,sh.t) then GFX.shell(x,sh.pos,sh.kind,GFX_RAINBOW[1+i%7],1) end
		end
	end,
}

-- 34: ROCKET LAUNCH -----------------------------------------------------------------------------
-- A 3D rocket rises out of the goal on a gantry-less pad. Vents hiss, the engine ignites and the
-- whole floor shakes in a rolling wall of smoke; it climbs slowly, then fast on a pillar of fire,
-- and bursts high overhead into a sky full of fireworks in the scoring team's colour.
ROCKET_TIMING={rise=.6,ignite=1.1,liftoff=1.7,burst=3.2,total=5.4}

GFX_DEFS[34]={
	duration=function() return ROCKET_TIMING.total end,
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.tc=GFX.teamColor(true)
		x.pad=x.base+x.f*(60*S)
		GFX.flashAt(x,x.base+x.u*(60*S),220*S,GFX.mixW(x.tc,.5),.25)
		GFX.shock(x,x.base+x.u*(4*S),x.r,x.f,420*S,12*S,x.tc,.6)
	end,
	update=function(x,age,d)
		local S,TM=x.S,ROCKET_TIMING
		local U=x.u
		local kk=GFX.K*.55
		local a=1-goalFxSmooth((age-(TM.total-.4))/.4)
		local h=0
		if age<TM.rise then h=(goalFxEaseOut(age/TM.rise)-1)*420*S
		elseif age>TM.liftoff then local t=age-TM.liftoff; h=t*t*t*220*S+t*60*S end
		local shake=(age>TM.ignite and age<TM.liftoff) and math.sin(age*70)*2*S or 0
		local base=x.pad+U*h+x.r*shake
		if age<TM.burst then
			-- body, nose, stripes, fins, window
			GFX.tube(x,{base+U*(40*S),base+U*(150*S),base+U*(290*S)},{38*S,44*S,38*S},14,{.92,.92,.95},kk*1.2)
			GFX.tube(x,{base+U*(290*S),base+U*(345*S),base+U*(385*S)},{38*S,22*S,1*S},14,x.tc,kk*1.3)
			GFX.tube(x,{base+U*(110*S),base+U*(128*S)},{45*S,45*S},14,x.tc,kk*1.3)
			GFX.tube(x,{base+U*(14*S),base+U*(40*S)},{28*S,36*S},12,{.2,.2,.23},kk)
			for i=0,3 do
				local th=i*1.5708+.78
				local o=x.r*math.cos(th)+x.f*math.sin(th)
				local lc=LinearColor.new(x.tc[1]*kk,x.tc[2]*kk,x.tc[3]*kk,1)
				WorldDraw.drawTriangle(base+U*(110*S)+o*(38*S),base+U*(35*S)+o*(38*S),base+U*(10*S)+o*(85*S),lc,0)
			end
			local Fv=GFX.cp-base
			local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
			local win=base+U*(225*S)+F*(41*S)
			GFX.ellipse(win,GFX.flatRight(x)*(17*S),U*(17*S),LinearColor.new(.75,.75,.8,1))
			GFX.ellipse(win+F*(1*S),GFX.flatRight(x)*(12*S),U*(12*S),LinearColor.new(.1*GFX.K,.35*GFX.K,.7*GFX.K,1))
		end
		-- vents before ignition
		if age>TM.rise and age<TM.ignite then
			for i=1,GFX.rate(x,"vent",40) do
				local sd=(i%2==0) and 1 or -1
				GFX.add({kind=3,p=base+U*(70*S),v=x.r*(sd*GFX.rand(120,240)*S),life=.6,s0=8*S,s1=35*S,
					ramp={{.95,.95,1},{.6,.6,.65}},op=.5,fin=.05,drag=1.5})
			end
		end
		if GFX.once(x,"ignite",TM.ignite) then
			GFX.light(x,x.pad,{1,.65,.25},50000,2800*S,.05,TM.burst-TM.ignite,.3,true)
			GFX.shock(x,x.pad+U*(4*S),x.r,x.f,600*S,16*S,{1,.7,.3},.8)
		end
		if age>TM.ignite and age<TM.burst then
			local nozzle=base+U*(14*S)
			GFX.glow(nozzle-U*(30*S),70*S,1,.75,.3,1,age*4,.9)
			for i=1,GFX.rate(x,"flame",200) do
				GFX.add({kind=1,p=nozzle+GFX.rdir(x)*(10*S),v=U*(-GFX.rand(700,1200)*S)+GFX.rdir(x)*(70*S),life=GFX.rand(.25,.5),
					s0=20*S,s1=55*S,ramp=GFX_PAL_FIRE.fire,drag=1,fin=.03,fp=1.3,spin=GFX.rand(-2,2)})
			end
			for i=1,GFX.rate(x,"smoke",age<TM.liftoff+.4 and 60 or 25) do
				local th=GFX.rand(0,6.2832)
				local out=x.r*math.cos(th)+x.f*math.sin(th)
				local p=(age<TM.liftoff+.4) and (x.pad+U*(15*S)) or nozzle
				GFX.add({kind=3,p=p,v=out*(GFX.rand(300,650)*S),life=GFX.rand(1.2,2),s0=50*S,s1=GFX.rand(160,240)*S,
					ramp={{.8,.78,.75},{.4,.39,.38}},op=.45,fin=.05,drag=1.6,spin=GFX.rand(-1,1)})
			end
			GFX.addShake(((age<TM.liftoff+.6) and 5 or 2)*S*d*20)
		end
		if GFX.once(x,"burst",TM.burst) then
			local c=base+U*(200*S)
			x.bc=c
			GFX.flashAt(x,c,500*S,{1,1,1},.3)
			GFX.blast(x,c,GFX.teamPal(x.tc),1.4)
			GFX.addShake(14*S)
			x.shells={}
			for i=1,({3,4,6,7})[x.qi] do
				x.shells[i]={t=TM.burst+.1+i*.13,pos=x.base+x.r*(GFX.rand(-450,450)*S)+U*(GFX.rand(350,620)*S)+x.f*(GFX.rand(0,140)*S),kind=i%6}
			end
		end
		for i,sh in ipairs(x.shells or {}) do
			if GFX.once(x,"shell"..i,sh.t) then
				GFX.shell(x,sh.pos,sh.kind,(i%2==0) and x.tc or GFX_FW_COLS[1+i%#GFX_FW_COLS],1)
			end
		end
	end,
}

-- 35: UFO ABDUCTION (Special) -------------------------------------------------------------------
-- The arena lights dim to a green glow as a chrome flying saucer slides in over the goal, its rim
-- lights chasing. It locks on and drops a shimmering tractor beam. A cartoon cow floats up it,
-- spinning and kicking, gets sucked inside... the saucer wobbles, gives a little victory spin and
-- warps away in a streak and a burst of green light.
UFO_TIMING={arrive=.9,beam=1.1,cow=1.4,gone=3.5,warp=3.8,total=5.2}

GFX_DEFS[35]={
	duration=function() return UFO_TIMING.total end,
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.c=x.base+x.f*(60*S)
		GFX.flashAt(x,x.base+x.u*(60*S),200*S,{.5,1,.6},.25)
		GFX.shock(x,x.base+x.u*(4*S),x.r,x.f,380*S,10*S,{.4,1,.5},.6)
	end,
	update=function(x,age,d)
		local S,TM=x.S,UFO_TIMING
		local U=x.u
		local R=GFX.flatRight(x)
		local Fv=GFX.cp-x.c
		local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
		local k=GFX.K
		local kk=k*.55
		local gap=x.c+U*(430*S)
		local pos
		if age<TM.arrive then
			pos=gap+R*((1-goalFxEaseOut(age/TM.arrive))*1400*S)+U*((1-goalFxEaseOut(age/TM.arrive))*300*S)
		elseif age<TM.warp then
			pos=gap+U*(math.sin(age*3)*10*S)+R*(math.sin(age*2)*14*S)
		else
			local t=age-TM.warp
			pos=gap+U*(t*t*9000*S)
		end
		if age<TM.warp+.25 then
			-- saucer: wide lens, dome, rim lights
			GFX.tube(x,{pos-R*(0*S)+U*(-22*S),pos+U*(-8*S),pos+U*(6*S),pos+U*(18*S)},{70*S,185*S,185*S,70*S},22,{.75,.78,.82},kk*1.4,{.5,1,.6})
			GFX.drawSphere(x,pos+U*(26*S),62*S,{.35,.9,.65},kk*1.2,.75,6,12,.9)
			for i=0,13 do
				local th=i/14*6.2832+age*2
				local p=pos+(x.r*math.cos(th)+x.f*math.sin(th))*(188*S)
				if (i+math.floor(age*10))%2==0 then GFX.glow(p,16*S,.4,1,.5,1,0,.9)
				else GFX.glow(p,7*S,1,.8,.2,.9,0,.6) end
			end
		end
		if GFX.once(x,"glow",TM.arrive) then GFX.light(x,x.c+U*(100*S),{.35,1,.45},35000,2400*S,.1,TM.warp-TM.arrive,.3) end
		-- tractor beam
		if age>TM.beam and age<TM.gone+.1 then
			local ba=goalFxSmooth((age-TM.beam)/.2)*(1-goalFxSmooth((age-TM.gone+.2)/.3))
			local fl=x.c+U*(3*S)
			for j=1,3 do
				GFX.beam(pos-U*(20*S),fl,(35+j*45)*S,LinearColor.new(.2*k*ba,.8*k*ba,.35*k*ba,.1*ba))
			end
			GFX.flatDisc(fl,x.r,x.f,170*S,LinearColor.new(.2*k*ba,.8*k*ba,.35*k*ba,.3*ba))
			for j=0,3 do
				local f=(age*.9+j/4)%1
				local rr=(155-f*90)*S
				GFX.ring(fl+(pos-fl)*f,x.r,x.f,rr,3*S,28,.5,1,.6,ba*(1-f*.5))
			end
			for i=1,GFX.rate(x,"motes",70) do
				local th=GFX.rand(0,6.2832)
				GFX.add({kind=2,p=fl+(x.r*math.cos(th)+x.f*math.sin(th))*(GFX.rand(10,140)*S),v=U*(GFX.rand(300,520)*S),
					life=.8,s0=3*S,s1=1*S,ramp={{.8,1,.85},{.3,1,.45}},st=.04,fin=.1})
			end
		end
		-- the cow floats up, spinning and kicking
		if age>TM.cow and age<TM.gone then
			local t=(age-TM.cow)/(TM.gone-TM.cow)
			local c=x.c+U*(60*S)+(pos-x.c-U*(60*S))*(t*t*(3-2*t))
			local sz=1-goalFxSmooth((t-.85)/.15)*.8
			local ang=age*2.2
			local T=R*math.cos(ang)+U*math.sin(ang)
			local V=U*math.cos(ang)-R*math.sin(ang)
			local white,black,pink={.95,.95,.93},{.06,.06,.07},{1,.65,.7}
			local Q=S*sz
			GFX.drawBox(x,c,T*(48*Q),F*(26*Q),V*(26*Q),white,kk*1.3,1)
			GFX.drawBox(x,c+T*(-14*Q)+F*(26.5*Q)+V*(8*Q),T*(14*Q),F*(1*Q),V*(11*Q),black,kk,1)
			GFX.drawBox(x,c+T*(24*Q)+F*(26.5*Q)+V*(-8*Q),T*(10*Q),F*(1*Q),V*(9*Q),black,kk,1)
			local hd=c+T*(62*Q)+V*(16*Q)
			GFX.drawBox(x,hd,T*(18*Q),F*(17*Q),V*(17*Q),white,kk*1.3,1)
			GFX.drawBox(x,hd+T*(14*Q)+V*(-8*Q),T*(9*Q),F*(14*Q),V*(8*Q),pink,kk*1.2,1)
			for sd=-1,1,2 do
				GFX.glow(hd+F*(sd*10*Q)+T*(18.5*Q)+V*(7*Q),3*Q,0,0,0,1,0,0)
				GFX.tube(x,{hd+F*(sd*14*Q)+V*(15*Q),hd+F*(sd*24*Q)+V*(29*Q)},{3*Q,1*Q},5,{.85,.8,.65},kk)
			end
			for lx=-1,1,2 do
				for lz=-1,1,2 do
					local kick=math.sin(age*14+lx+lz*2)*12*Q
					local top=c+T*(lx*34*Q)+F*(lz*18*Q)-V*(22*Q)
					GFX.tube(x,{top,top-V*(36*Q)+T*kick},{7*Q,6*Q},6,white,kk*1.2)
				end
			end
		end
		if GFX.once(x,"gulp",TM.gone) then
			GFX.flashAt(x,pos,160*S,{.5,1,.6},.15)
			GFX.addShake(6*S)
		end
		if GFX.once(x,"warp",TM.warp) then
			GFX.flashAt(x,gap,560*S,{.7,1,.8},.3)
			GFX.shock(x,gap,x.r,x.f,800*S,16*S,{.4,1,.5},.9)
			GFX.blast(x,gap,GFX.teamPal({.35,1,.45}),1.2)
			GFX.addShake(16*S)
		end
	end,
}

-- 36: SANTA'S SLEIGH RUN (Christmas special) -----------------------------------------------------
-- Santa's sleigh and three reindeer sweep across over the goal trailing gold sparkles and drop a
-- huge present. It slams down and rattles, then blows up into fireworks and HO HO HO! while the
-- sleigh comes back the other way, high overhead.
SLEIGH_TIMING={drop=1.2,land=2.1,burst=3,back=3.3,total=5.8}

-- T = the way it flies. A shaded sleigh with Santa and his sack, then reindeer ahead on reins.
function GFX.xmasSleigh(x,pos,T,age,Q)
	local U=x.u
	local kk=GFX.K*.55
	local Fv=GFX.cp-pos
	local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
	local gold,red,brown={1,.78,.25},{.85,.06,.08},{.42,.26,.13}
	GFX.drawBox(x,pos,T*(62*Q),F*(30*Q),U*(24*Q),red,kk*1.3,1)
	GFX.drawBox(x,pos+T*(52*Q)+U*(26*Q),T*(10*Q),F*(30*Q),U*(14*Q),red,kk*1.3,1)
	for sd=-1,1,2 do
		local o=F*(sd*26*Q)-U*(38*Q)
		GFX.tube(x,{pos+o-T*(66*Q),pos+o+T*(60*Q),pos+o+T*(84*Q)+U*(20*Q)},{3*Q,3*Q,2*Q},5,gold,kk*1.4)
		GFX.tube(x,{pos+o+U*(4*Q),pos+o+U*(16*Q)},{2.5*Q,2.5*Q},4,gold,kk*1.4)
	end
	-- the sack behind, Santa in front of it
	GFX.drawSphere(x,pos-T*(36*Q)+U*(44*Q),30*Q,{.2,.5,.2},kk*1.1,1,5,8)
	local sb=pos+T*(14*Q)+U*(40*Q)
	GFX.drawSphere(x,sb,26*Q,red,kk*1.3,1,6,10,.3)
	GFX.drawSphere(x,sb+U*(32*Q),15*Q,{1,.75,.62},kk*1.5,1,5,8)
	GFX.drawSphere(x,sb+U*(22*Q)+T*(10*Q),13*Q,{1,1,1},kk*1.8,1,5,8)
	GFX.tube(x,{sb+U*(42*Q),sb+U*(56*Q)-T*(4*Q),sb+U*(66*Q)-T*(22*Q)},{15*Q,9*Q,2*Q},8,red,kk*1.3)
	GFX.drawSphere(x,sb+U*(64*Q)-T*(24*Q),5*Q,{1,1,1},kk*1.8,1,3,6)
	local gk=GFX.K*.8
	for i=1,3 do
		local c=pos+T*((75+i*105)*Q)+U*((14+math.sin(age*9+i)*7)*Q)
		GFX.drawBox(x,c,T*(34*Q),F*(12*Q),U*(14*Q),brown,kk*1.2,1)
		local hd=c+T*(44*Q)+U*(26*Q)
		GFX.tube(x,{c+T*(26*Q)+U*(6*Q),hd},{9*Q,7*Q},6,brown,kk*1.2)
		GFX.drawBox(x,hd+T*(6*Q),T*(14*Q),F*(7*Q),U*(7*Q),brown,kk*1.2,1)
		for sd=-1,1,2 do
			local at=hd+U*(6*Q)+F*(sd*5*Q)
			GFX.tube(x,{at,at+U*(16*Q)+F*(sd*8*Q),at+U*(26*Q)+F*(sd*4*Q)-T*(8*Q)},{2*Q,1.5*Q,.8*Q},4,{.8,.7,.5},kk*1.2)
			for ly=-1,1,2 do
				local kick=math.sin(age*12+i+ly)*12*Q
				local top=c+T*(ly*24*Q)+F*(sd*8*Q)-U*(12*Q)
				GFX.tube(x,{top,top-U*(26*Q)+T*kick},{4*Q,3*Q},5,brown,kk*1.2)
			end
		end
		WorldDraw.drawLine(c-T*(30*Q),i==1 and pos+T*(60*Q)+U*(10*Q) or c-T*(70*Q),gk,.7*gk,.25*gk,1.5,0)
		if i==3 then GFX.glow(hd+T*(21*Q),11*Q,1,.1,.08,1,0,.8) end
	end
end

GFX_DEFS[36]={
	duration=function() return SLEIGH_TIMING.total end,
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.c=x.base+x.f*(60*S)
		x.tc=GFX.teamColor(true)
		GFX.flashAt(x,x.base+x.u*(60*S),200*S,{1,.85,.5},.25)
		GFX.shock(x,x.base+x.u*(4*S),x.r,x.f,360*S,10*S,{1,.85,.5},.6)
	end,
	update=function(x,age,d)
		local S,TM=x.S,SLEIGH_TIMING
		local U=x.u
		local R=GFX.flatRight(x)
		local kk=GFX.K*.55
		local k=GFX.K
		if age<TM.total-.8 then GFX.snowfall(x,35) end
		-- first pass: right over the goal at the drop
		local function trail(pos)
			for i=1,GFX.rate(x,"sltrail",70) do
				GFX.add({kind=1,p=pos-R*(GFX.rand(-60,60)*S)+U*(GFX.rand(-40,20)*S),v=U*(-GFX.rand(30,90)*S),
					life=GFX.rand(.6,1.1),s0=GFX.rand(5,9)*S,s1=2*S,ramp={{1,.9,.5},{1,.7,.25}},fin=.1,tw=8})
			end
		end
		local passT=1.3*2
		if age<passT then
			local t=age/passT
			local pos=x.c+U*((560+math.sin(t*3.1416)*90)*S)+R*((.5-t)*3400*S)
			GFX.xmasSleigh(x,pos,R*-1,age,S)
			trail(pos)
			x.dropAt=(age<TM.drop) and pos or x.dropAt
		end
		-- the present falls, lands with a bounce, then rattles
		if age>=TM.drop and age<TM.burst then
			local top=x.dropAt or (x.c+U*(560*S))
			local floor=x.c+U*(70*S)
			local c
			if age<TM.land then
				local t=(age-TM.drop)/(TM.land-TM.drop)
				c=top+(floor-top)*(t*t)
			else
				local t=age-TM.land
				c=floor+U*(math.abs(math.sin(t*9))*math.exp(-t*5)*70*S)
			end
			local charge=goalFxSmooth((age-TM.land)/(TM.burst-TM.land))
			c=c+R*(math.sin(age*50)*charge*7*S)
			local B=70*S
			GFX.drawBox(x,c,x.r*B,x.f*B,U*B,{.1,.55,.2},kk*1.3,1)
			GFX.drawBox(x,c,x.r*(B*.2),x.f*(B*1.02),U*(B*1.02),{1,.78,.25},kk*1.4,1)
			GFX.drawBox(x,c,x.r*(B*1.02),x.f*(B*.2),U*(B*1.02),{1,.78,.25},kk*1.4,1)
			for sd=-1,1,2 do
				GFX.drawSphere(x,c+U*(B+14*S)+R*(sd*20*S),16*S,{1,.78,.25},kk*1.4,1,4,8,.6)
			end
			if charge>0 then GFX.glow(c+U*B,110*S*charge,1,.85,.45,.7*charge,age*3,.6) end
		end
		if GFX.once(x,"land",TM.land) then
			GFX.shock(x,x.c+U*(4*S),x.r,x.f,620*S,14*S,{1,1,1},.6)
			GFX.addShake(12*S)
			for i=1,GFX.n(x,40) do
				local th=GFX.rand(0,6.2832)
				GFX.add({kind=3,p=x.c+U*(10*S),v=(x.r*math.cos(th)+x.f*math.sin(th))*(GFX.rand(250,600)*S),life=GFX.rand(.7,1.2),
					s0=25*S,s1=90*S,ramp={{1,1,1},{.85,.9,1}},op=.5,fin=.05,drag=2})
			end
		end
		if GFX.once(x,"burst",TM.burst) then
			local c=x.c+U*(90*S)
			GFX.flashAt(x,c,560*S,{1,1,1},.3)
			GFX.blast(x,c,GFX_PAL_XMAS,1.6)
			GFX.addShake(18*S)
			GFX.light(x,c,{1,.8,.45},50000,2600*S,.03,.5,.9)
			local cols={{.1,.9,.25},{1,.15,.12},{1,.8,.25},{1,1,1}}
			for i=1,GFX.n(x,80) do
				local col=cols[1+i%4]
				GFX.add({kind=4,quad=true,p=c,v=GFX.rdir(x)*(GFX.rand(300,950)*S)+U*(250*S),life=GFX.rand(1.2,2.2),s0=GFX.rand(8,16)*S,s1=6*S,
					ramp={col,col},grav=420*S,drag=.8,spin=GFX.rand(4,10),fin=.02})
			end
			x.shells={}
			for i=1,({2,3,5,6})[x.qi] do
				x.shells[i]={t=TM.burst+.15+i*.18,pos=x.base+x.r*(GFX.rand(-480,480)*S)+U*(GFX.rand(380,650)*S),col=cols[1+i%4],kind=i%6}
			end
		end
		for i,sh in ipairs(x.shells or {}) do
			if GFX.once(x,"sh"..i,sh.t) then GFX.shell(x,sh.pos,sh.kind,sh.col,1) end
		end
		-- HO HO HO! and the sleigh coming back
		if age>TM.burst then
			local t=age-TM.burst
			local fade=1-goalFxSmooth((age-(TM.total-.7))/.6)
			local pop=1+.8*(1-goalFxEaseOut(math.min(t/.2,1)))
			local at=x.c+U*(330*S)
			local tu=15*S*pop
			local toCam=(GFX.cp-at):getSafeNormal()
			GFX.memeText(at-toCam*2,"HO HO HO!",GFX.bR,GFX.bU,tu,tu*.6,LinearColor.new(.02,.02,.03,fade))
			GFX.memeText(at,"HO HO HO!",GFX.bR,GFX.bU,tu,tu*.32,LinearColor.new(k,.12*k,.1*k,fade))
		end
		if age>TM.back and age<TM.total-.2 then
			local t=(age-TM.back)/(TM.total-.2-TM.back)
			local pos=x.c+U*((800+t*260)*S)+R*((t-.5)*3600*S)
			GFX.xmasSleigh(x,pos,R,age,S*.7)
			trail(pos)
		end
	end,
}

-- 37: THE NAUGHTY LIST (Christmas special) -------------------------------------------------------
-- A parchment scroll lowers over the goal and rolls open. The conceding goalie's name is written on
-- it, then a red NAUGHTY! stamp slams down and lumps of coal rain on the goal, finally catching
-- light and going up in a fireball along with the list.
NAUGHTY_TIMING={lower=.7,open=1.5,write=2.5,stamp=2.8,coal=3.1,boom=4.7,total=6}

GFX_DEFS[37]={
	duration=function() return NAUGHTY_TIMING.total end,
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.c=x.base+x.f*(60*S)
		local g=GFX.findGoalie()
		x.nm=GFX.fontName(g and g.playerName,10,"THE GOALIE")
		x.coal={}
		for i=1,({10,16,24,32})[x.qi] do
			local th=GFX.rand(0,6.2832)
			local rr=GFX.rand(20,480)*S
			x.coal[i]={t=NAUGHTY_TIMING.coal+GFX.rand(0,1.3),off=x.r*(math.cos(th)*rr)+x.f*(math.sin(th)*rr*.5),
				s=GFX.rand(12,26)*S,spin=GFX.rand(3,8),a=GFX.rand(0,6.28)}
		end
		GFX.shock(x,x.base+x.u*(4*S),x.r,x.f,320*S,8*S,{1,.25,.2},.5)
	end,
	update=function(x,age,d)
		local S,TM=x.S,NAUGHTY_TIMING
		local U=x.u
		local R=GFX.flatRight(x)
		local Fv=GFX.cp-x.c
		local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
		local kk=GFX.K*.55
		local k=GFX.K
		local rest=x.c+U*(340*S)
		if age<TM.boom then
			local drop=(1-goalFxEaseOut(math.min(age/TM.lower,1)))*900*S
			local c=rest+U*drop
			local W=260*S
			local H=(10+goalFxEaseOut(math.clamp((age-TM.lower)/(TM.open-TM.lower),0,1))*170)*S
			local rocky=math.sin(age*2)*4*S
			c=c+R*rocky
			GFX.drawBox(x,c,R*W,F*(2*S),U*H,{.93,.84,.62},kk*1.5,1)
			for sd=-1,1,2 do
				local ry=c+U*(sd*H)
				GFX.tube(x,{ry-R*(W+22*S),ry+R*(W+22*S)},{15*S,15*S},10,{.8,.68,.45},kk*1.4)
				GFX.tube(x,{ry-R*(W+34*S),ry-R*(W+20*S)},{7*S,7*S},6,{.8,.1,.1},kk*1.3)
				GFX.tube(x,{ry+R*(W+20*S),ry+R*(W+34*S)},{7*S,7*S},6,{.8,.1,.1},kk*1.3)
			end
			if age>TM.open-.2 then
				local front=c+F*(5*S)
				local ink=LinearColor.new(.08,.05,.03,1)
				GFX.memeText(front+U*(112*S),"NAUGHTY LIST",R,U,7*S,2*S,LinearColor.new(.55,.04,.04,1))
				-- other names as scribbles, then the goalie's name writes itself in
				for ln=0,2 do
					local y=front+U*((62-ln*128)*S)
					if ln~=1 then
						for j=0,6 do
							local px=-190+j*62
							local a=y+R*(px*S)+U*(goalFxNoise(j+ln*9)*8*S)
							GFX.beam(a,a+R*(46*S)+U*((goalFxNoise(j+ln)-.5)*12*S),1.2*S,ink)
						end
					end
				end
				local w=goalFxSmooth((age-TM.open)/(TM.write-TM.open))
				local n=math.floor(#x.nm*w+.5)
				if n>0 then
					local full=#x.nm
					local tu=math.min(9,86/full)*S
					local xoff=-(full-n)*5.2*tu*.5
					GFX.memeText(front+U*(-2*S)+R*xoff,string.sub(x.nm,1,n),R,U,tu,2.4*S,LinearColor.new(.1,.05,.03,1))
				end
			end
			if age>=TM.stamp then
				local t=age-TM.stamp
				local sc=1+2.2*(1-goalFxEaseOut(math.min(t/.14,1)))
				local ang=.16
				local ax=R*math.cos(ang)+U*math.sin(ang)
				local ay=U*math.cos(ang)-R*math.sin(ang)
				local tu=11*S*sc
				GFX.memeText(c+F*(8*S)+U*(-70*S),"NAUGHTY!",ax,ay,tu,3.6*S*sc,LinearColor.new(k*.95,.06*k,.05*k,1))
			end
		end
		if GFX.once(x,"stamp",TM.stamp+.14) then
			GFX.addShake(14*S)
			GFX.flashAt(x,rest+F*(10*S),300*S,{1,.3,.2},.15)
		end
		-- coal rain: falls, thumps on the floor with a puff of soot, then sits there glowing
		local dark={.07,.07,.08}
		for i,cl in ipairs(x.coal) do
			if age>cl.t and age<TM.boom then
				local t=age-cl.t
				local h=850*S-t*t*1500*S
				local grounded=h<=cl.s
				if grounded and not cl.hit then
					cl.hit=true
					for j=1,2 do
						GFX.add({kind=3,p=x.c+cl.off+U*(cl.s),v=GFX.rdir(x)*(120*S)+U*(60*S),life=.7,s0=12*S,s1=45*S,
							ramp={{.15,.15,.16},{.08,.08,.09}},op=.5,fin=.05,drag=2})
					end
				end
				local p=x.c+cl.off+U*(grounded and cl.s or h)
				local ang=grounded and cl.a or (cl.a+t*cl.spin)
				local ax=(R*math.cos(ang)+U*math.sin(ang))*cl.s
				local ay=(U*math.cos(ang)-R*math.sin(ang))*(cl.s*.8)
				GFX.drawBox(x,p,ax,F*(cl.s*.8),ay,dark,kk*1.2,1)
				local heat=goalFxSmooth((age-(TM.boom-.8))/.8)
				if heat>0 then GFX.glow(p,cl.s*2.4,1,.35,.08,heat,age,.5) end
			end
		end
		if GFX.once(x,"boom",TM.boom) then
			GFX.flashAt(x,x.c+U*(120*S),620*S,{1,.8,.5},.3)
			GFX.blast(x,x.c+U*(120*S),GFX_PAL_FIRE,1.6)
			GFX.addShake(20*S)
			GFX.light(x,x.c,{1,.5,.15},55000,2600*S,.03,.3,.9)
			for i=1,GFX.n(x,70) do
				GFX.add({kind=4,quad=true,p=rest+R*(GFX.rand(-250,250)*S)+U*(GFX.rand(-170,170)*S),v=GFX.rdir(x)*(GFX.rand(120,520)*S),
					life=GFX.rand(1,1.8),s0=GFX.rand(8,15)*S,s1=3*S,ramp={{.93,.84,.62},{.2,.1,.05}},grav=60*S,drag=1,spin=GFX.rand(3,9),fin=.02})
			end
			for i=1,GFX.n(x,50) do
				GFX.add({kind=4,p=x.c+U*(20*S),v=GFX.rdir(x)*(GFX.rand(300,900)*S)+U*(350*S),life=GFX.rand(.9,1.5),s0=GFX.rand(8,16)*S,s1=6*S,
					ramp={dark,dark},grav=800*S,spin=GFX.rand(4,10),fin=.02,emis=.3})
			end
		end
	end,
}

-- 38: CANDY CANE CRACKER (Christmas) -------------------------------------------------------------
-- A ring of striped candy canes grows out of the floor, whirls round faster and faster, leans in,
-- and snaps into a burst of red and white pieces.
function GFX.candyCane(x,foot,out,h,kk,lean)
	local U=x.u
	local Q=h/300
	local up=(U+out*(-lean)):getSafeNormal()
	local pts={}
	local seg=8
	for i=0,seg do pts[#pts+1]=foot+up*(h*i/seg) end
	local top=foot+up*h
	for i=1,5 do
		local th=i/5*3.1416
		pts[#pts+1]=top+up*(math.sin(th)*48*Q)+out*((1-math.cos(th))*48*Q)
	end
	for i=1,#pts-1 do
		local col=(i%2==0) and {.95,.95,.95} or {.9,.06,.08}
		GFX.tube(x,{pts[i],pts[i+1]},{17*Q,17*Q},7,col,kk*1.4)
	end
end

GFX_DEFS[38]={
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.c=x.base+x.f*(60*S)
		x.TX=.62*x.D
		x.nc=({6,8,10,12})[x.qi]
		GFX.shock(x,x.c+x.u*(4*S),x.r,x.f,420*S,10*S,{1,.25,.25},.6)
	end,
	update=function(x,age,d)
		local S,TX=x.S,x.TX
		local U=x.u
		local kk=GFX.K*.55
		if age<.95*x.D then GFX.snowfall(x,25) end
		if age<TX then
			local grow=goalFxEaseOut(math.min(age/(.3*x.D),1))
			local charge=goalFxSmooth((age-.3*x.D)/(TX-.3*x.D))
			x.ang=(x.ang or 0)+d*(.6+charge*9)
			local rad=(330-charge*130)*S
			for i=1,x.nc do
				local th=x.ang+i/x.nc*6.2832
				local out=x.r*math.cos(th)+x.f*math.sin(th)
				GFX.candyCane(x,x.c+out*rad,out*-1,300*S*grow,kk,charge*.35)
			end
			GFX.glow(x.c+U*(200*S),150*S*charge,1,.5,.45,.6*charge,age*3,.6)
			if charge>.4 then GFX.addShake(charge*3*S*d*20) end
		end
		if GFX.once(x,"crack",TX) then
			local c=x.c+U*(190*S)
			GFX.flashAt(x,c,480*S,{1,1,1},.25)
			GFX.blast(x,c,GFX_PAL_XMAS,1.3)
			GFX.shock(x,x.c+U*(4*S),x.r,x.f,800*S,14*S,{1,.3,.3},.8)
			GFX.addShake(14*S)
			for i=1,GFX.n(x,110) do
				local col=(i%2==0) and {.95,.95,.95} or {.9,.06,.08}
				GFX.add({kind=4,quad=true,p=c+GFX.rdir(x)*(GFX.rand(20,160)*S),v=GFX.rdir(x)*(GFX.rand(300,950)*S)+U*(160*S),
					life=GFX.rand(.9,1.6),s0=GFX.rand(10,20)*S,s1=7*S,ramp={col,col},grav=620*S,drag=.6,spin=GFX.rand(5,12),fin=.02})
			end
		end
	end,
}

-- 39: SNOW GLOBE (Christmas) ---------------------------------------------------------------------
-- A giant snow globe with a little tree inside rises over the goal. It shakes, the snow whirls up,
-- the glass cracks, and it shatters in a burst of ice and snow.
GFX_DEFS[39]={
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.c=x.base+x.f*(60*S)
		x.TX=.62*x.D
		GFX.shock(x,x.c+x.u*(4*S),x.r,x.f,380*S,10*S,{.7,.9,1},.6)
	end,
	update=function(x,age,d)
		local S,TX=x.S,x.TX
		local U=x.u
		local kk=GFX.K*.55
		local k=GFX.K
		local rad=230*S
		if age>=TX and age<.95*x.D then GFX.snowfall(x,60) end
		if age<TX then
			local rise=goalFxEaseOut(math.min(age/(.25*x.D),1))
			local charge=goalFxSmooth((age-.25*x.D)/(TX-.25*x.D))
			local c=x.c+U*((rad+36*S)-(1-rise)*520*S)+x.r*(math.sin(age*34)*charge*9*S)+x.f*(math.cos(age*29)*charge*6*S)
			x.gc=c
			-- base with a gold band, then the tree, the snow and the glass in front of them
			local bs=c-U*(rad*.92)
			GFX.tube(x,{bs-U*(36*S),bs},{rad*.86,rad*.72},24,{.25,.09,.06},kk*1.3)
			GFX.ring(bs-U*(16*S),x.r,x.f,rad*.8,5*S,36,1,.8,.3,.9)
			local fl=bs+U*(2*S)
			GFX.flatDisc(fl,x.r,x.f,rad*.72,LinearColor.new(.85*k*.5,.9*k*.5,.95*k*.5,1))
			GFX.tube(x,{fl,fl+U*(32*S)},{10*S,10*S},8,{.4,.25,.12},kk)
			GFX.drawCone(x,fl+U*(26*S),110*S,76*S,12,{.08,.42,.16},kk)
			GFX.drawCone(x,fl+U*(80*S),95*S,58*S,12,{.1,.48,.18},kk)
			GFX.drawCone(x,fl+U*(128*S),80*S,38*S,10,{.12,.52,.2},kk)
			GFX.glow(fl+U*(212*S),13*S,1,.85,.3,1,age*2,.9)
			local nf=({18,28,40,55})[x.qi]
			for i=1,nf do
				local sd=i*3.7
				local th=goalFxNoise(sd)*6.2832+age*(.4+charge*5)
				local rr=goalFxNoise(sd+1)*rad*.82
				local hh=(goalFxNoise(sd+2)*1.7-.85)*rad*(.5+charge*.5)+math.sin(age*(1+charge*3)+sd)*22*S
				GFX.glow(c+(x.r*math.cos(th)+x.f*math.sin(th))*rr+U*hh,4.5*S,1,1,1,.9,0,.8)
			end
			GFX.drawSphere(x,c,rad,{.6,.82,1},kk*.8,.16,8,16,1.1)
			-- cracks spreading as it charges
			if charge>.45 then
				local ck=k*(charge-.3)*1.8
				local view=(GFX.cp-c):getSafeNormal()
				for ci=1,7 do
					local seed=ci*11.3
					local tt=goalFxNoise(seed)*6.2832
					local ll=(goalFxNoise(seed+1)-.5)*1.3
					local prev=nil
					for j=0,6 do
						local a2=tt+j*.14*(goalFxNoise(seed+j)-.4)*charge*2.5
						local b2=ll+(goalFxNoise(seed+j*2)-.5)*.6*j/6*charge
						local dir=((x.r*math.cos(a2)+x.f*math.sin(a2))*math.cos(b2)+U*math.sin(b2)):getSafeNormal()
						local q=c+dir*(rad*1.01)
						if prev and Vec3.dot(dir,view)>0 then WorldDraw.drawLine(prev,q,ck,ck,ck,2,0) end
						prev=q
					end
				end
				GFX.addShake(charge*2.5*S*d*20)
			end
		end
		if GFX.once(x,"shatter",TX) then
			local c=x.gc or (x.c+U*(rad))
			GFX.flashAt(x,c,520*S,{.9,.97,1},.25)
			GFX.blast(x,c,GFX_PAL_XMAS,1.2)
			GFX.shock(x,x.c+U*(4*S),x.r,x.f,760*S,14*S,{.7,.9,1},.8)
			GFX.addShake(14*S)
			GFX.light(x,c,{.65,.85,1},45000,2300*S,.03,.25,.8)
			for i=1,GFX.n(x,90) do
				local dir=GFX.rdir(x):getSafeNormal()
				GFX.add({kind=4,p=c+dir*rad,v=dir*(GFX.rand(280,850)*S)+U*(90*S),life=GFX.rand(.9,1.6),s0=GFX.rand(12,30)*S,s1=8*S,
					ramp={{.85,.95,1},{.55,.8,1}},grav=620*S,spin=GFX.rand(4,11),fin=.02,emis=1})
			end
			for i=1,GFX.n(x,70) do
				GFX.add({kind=1,p=c+GFX.rdir(x)*(GFX.rand(10,200)*S),v=GFX.rdir(x)*(GFX.rand(150,520)*S),life=GFX.rand(1,2),s0=GFX.rand(5,8)*S,s1=3*S,
					ramp={{1,1,1},{.85,.92,1}},grav=90*S,drag=1.4,tw=5,fin=.08})
			end
		end
	end,
}

-- 40: XENO (Esports Teams) -------------------------------------------------------------------
-- Team Xeno's logo celebration, copying the preview gif the team sent. A tiny pale logo
-- spins up at the goal and swells as a ring bursts out of it while its colour floods in; it settles
-- upright facing the camera at about 1 s, keeps slowly growing with its base over the floor while
-- white four-point sparkles twinkle on it, then breaks up into slivers and is gone by 3.6 s.
-- GFX_TEAMLOGO is the logo traced from that gif: a palette plus rectangles, each packed as 9 hex
-- characters (colour, x, y, width, height on a w by h grid).
-- No sound API, so there is only a hook:  TeamLogoFX.onSound = function(event) ... end
--   events: "pop", "settle", "dissolve"
TEAMLOGO_TIMING={
	ring=.27,      -- the ring bursts out
	settle=.85,    -- full size for the first time
	spin=.95,      -- the spin has stopped
	ringEnd=1.4,   -- the ring has faded
	sparkle=1.1,   -- sparkles start
	dissolve=3.0,  -- starts breaking up
	total=3.6,
	width=390,     -- logo width when it settles (times Size)
}
TeamLogoFX={onSound=nil}
function TeamLogoFX.sound(ev)
	if TeamLogoFX.onSound then pcall(TeamLogoFX.onSound,ev) end
end
GFX_TEAMLOGO={w=130,h=114,pal={{0.858,0.198,0.959},{0.896,0.140,0.978},{0.957,0.271,0.979},{0.694,0.235,0.877},{0.240,0.011,0.451},{0.654,0.054,0.925},{0.491,0.051,0.802},{0.912,0.501,0.964}},data=[[
35b01030145f01010146101020155602020135802050145d02040167602020137902070155303050135803040145c030301070030201
67203040137603020137a03030147d03020147803020254f04080145704050166704070106e040501673040201475040101676040101
37704010154d05070145405070166205030166605050106b05070147205060154b060701452060a0165e06070106606090146f060601
365050103645070201548070901451070c0165d07020155f07060106607050146b07060164308040104708010154808070144f080c01
55b080b0106608020146808060164209030134509010154609070144d090c01559090c014650906013400a01010410a01015420a0901
44b0a0b015560a0b014610a070163c0b020133e0b010153f0b0a014490b08015510b0d0145e0b080163a0c040153e0c0a014480c0701
54f0c0c0145b0c08016380d030133b0d020153d0d09014460d040154a0d0e014580d08016350e02016380e01013390e010153a0e0b01
4450e03015480e0e014560e08013370e01026340f03015380f0a016420f01014430f02015450f0f014540f080166e0f09013770f0401
632100401536100a01640100201542100c0134e10020145010090136910010166a100701771100401675100101476100101377100101
478100201631110301534110b0163f110101540110c0134c11030144f11090166111060176711010136811040156c110401370110101
77111030147411050162f12030134a12020144c12090165d12080156512010176612020156812080147012060153212180262d130401
13113010144a130b01655130101659130901562130b0146d13060162c14030112f140301532141701449140b0165414090155d140101
75e14010155f140c0146b14060162b15030112e150401532151501447150a0165115010145215010165315050135815020165a150101
55b150d0146815060162a16020112c160701533160201135160301538160d01445160b01650160701557160101358160101559160d01
46616060162717030112a170f01539170901442170e0165017040155417110146517040162618030112918110153a180601440181001
35018010155118120166318010146418040162519020122719010112819120153a19040143e19100134e19010154f191101460190601
5251a01012261a02011281a130153b1a020143d1a0e0154b1a140145f1a04016221b01015231b02017251b01012261b01011271b0901
2301b02011321b090143b1b0c013471b01014481b01013491b010154a1b130145d1b05016211c02017231c02012251c03011281c0601
22e1c04011321c080143a1c0b013451c03015481c140145c1c04016201d02017221d02012241d05011291d040122d1d06011331d0501
4381d0c013441d02015461d150145b1d050161f1e02017211e02012231e070112a1e010122b1e09011341e03014371e0b013421e0101
5431e180145b1e040205f1e020271f1f03012221f12014341f0c015401f1b0151d20020171f200201221201201433200c0153f201b01
05f20030145a20050251c21020171e21020122021120143221090103b21030153e211c0105f21020176121020131d22010171e220101
21f22120143122090103a22050153f22190145822070176222010151b22020271d23020121f231101730230101431230701038230701
53f231601455230a0176223020105f22030351a24020171c24020121e24120173024020143224050103724060153d241601453240c01
76224030251925020171b25020121d25110142e25070103525060153b25110104c25010154d250301450250e0151926010121c261001
42c26070103326060153926100104926040144d26110176226040166626010105e25040371a26020251827020121c270f0142b270701
032270601538270f0104727040144b27130176227050171928020121b280f0142a280601130280301033280301536280e01044280301
44728160176228030126528010176628010151728020205d28050271929010121a290e0142829070112f290501034290201536290c01
0422904014462917017622902012642903015162a02017182a01012192a0e014272a070112e2a07015362a0a010402a02014422a1a01
05c2a05012632a04017672a01010352a01023612a02025162b01017172b01012182b0e014262b070112d2b08015362b050103b2b0501
4402b1b0105b2b06012632b03017662b03012172c0e014252c070112c2c08010342c03015372c040103b2c030143e2c1d0105b2c0701
3632c01012642c03017672c01013682c01015152c02026622c01022172d0d014242d070112b2d09010342d02011362d01010372d0501
43c2d1e012632d060105a2d08022162e0d016232e01014242e05012292e030112c2e07010332e080143b2e1f012622e07015142e0202
7162f01012172f0c014232f05012282f050112d2f07010342f03011372f020143b2f1e010592f09010392f02022622f06027682f0102
715300101216300c0142230050122730060112d300c0143b301d01058300a01369300101215310c0142131050122631060112c310e01
43a311d01057310a01361310201613300203263310502215320b0142032050122532060112b320f0143a321c01056320a01360320301
768310203214330b0141f33050122433060112a33100143a331b01055330b0136033020126233060161333010241e340501223340601
129340f01438341c01054340c01360340101261340601767340301222350601128350e01436351d01053350d01460350201214340a03
41e350402262350602768350202222360501127360d01434361e0105236010155336030105636090161235020345f360302214370901
41d370401221370501126370c01432371f0155137060105737080166a330106262370702769370102213380901221380401125380c01
431381e0154f38090105838060145e38030106138010161238010241c38040272038010221339080171b390101221390301124390a01
42e391f0154d390c0105939040145d3904010613902026113a020171f3a01011203a09012293a020112b3a020142d3a1e0104b3a0201
54d3a0d0145c3a05012633906037133a01022143a070241b3a040205a3a020211f3b09012283b020142a3b1f015493b010104a3b0101
54b3b0f0145c3b04010603b03016123b010211e3c09012273c02014293c1e015473c12010593c020145b3c05010603c04012133c0802
41b3c03022643c05026113d020101e3d010111f3d07012263d02014283d1d015453d130145a3d050105f3d05016693902060583d0202
1223e03012253e02014273e1c016433e01015443e140145a3e040105e3e07012653e01010663e01012673e02016123e01023133e0102
2143e060241a3e030271d3e010201e3e04021223f02012243f02014263f1c015433f14010573f01014583f060105e3f09017673f0201
3693f01016423f010221440050171940010101d400501222400301425401d0154340120135740010145840050105d400a01767400101
36840020161240020271c40010205540020221d410101221410301424411e0154241130145741050105c410c0136841010141a400203
01e41030221c420201221420201423421f0154242120105442010126742010166842010121441060361342010245542060205b420c02
31b43010121c430101220430201422431f0154143120105343010135443010166743030101d430302220440101421442001541441101
05244010135344010145444060105a440c0166644030141a43010361344020221544050221b44020201d450401421451e0153f451301
452450701059450d01614460101215460701420461c0163c46010153d461301650460101451460701058460e0166645020301c460402
61447020121647030131947010121a470201420471a0163a47040153e47120145047080155847030105b470b01615480101216480601
01c48030141f481901638480801540480f0144f48080155748060105d48080166548020161549020121749040141f491601335490101
636490d01543490a0144d49090155649070105d49070166449020101b49040241f4a0f0132e4a010142f4a01013304a02016324a1201
5444a070144b4a0a015554a0a016164a020205f4a04026634a020241e4b0f0172d4b010132e4b04016324b13015454b050144a4b0901
3534b01015544b0b012184a03036174c010141e4c0c0132a4c02016304c15015454c03014484c0a013524c01015534c0c0105f4c0301
6624c030172c4c04026184d01012194d020141e4d0b013294d03016304d16014464d0a013504d02015524d0d0105f4d02026614d0302
41e4e08015264e01016274e060162f4e16014454e0a0134f4e02015514e0d0135e4e010101b4b03056194e02025234f03016264f0701
62f4f14014434f0b0134e4f02015504f0d0135d4f03014604f030172d4e020341e4f050201c50020152350020162550080162f501301
442500a0134c50020164e50020155050020165250010155350090135c50030145f50040161a50020221c51010162551090172e510101
62f51100143f510c0134b51010164c51070155351080135b51030145e51040141d51050261b52020162552170143c520d01349520201
64b52070155252080135a52030145d52040152251030361c53020141e53040162553150143a530d01347530201649530801551530801
05953010135a53020145c53040161c54030141f540201521540301624541401438540e0134654020164854060154e540a01058540301
65b54010145c54030161b55030141e55010161f550101520550401624551101435550f0134455020164655060154c550a01356550301
05955010165a55010145b55030161a56050151f560401623561001433560f0134256020164456070154b560a01355560401659560101
45a56030141857030161b57020121d57010151e570501623570e01431571001641570801354570401458570401549570b02419580201
31b58010151c580701623580c0142f58100163f580a0135458020175658010145758040161758020261459020131959020151b590701
62259070142959140133d59010163e590901353590301456590401416590102547590c026125a04015175a01013185a01015195a0b01
6245a01014255a01016265a02014285a130163b5a0c016535a01013545a01014555a040160f5b05013145b01015155b0d014225b1501
3375b030163a5b0c015465b0b016515b03014545b040160e5c03017115c02015135c080131b5c010151c5c020131e5c010161f5c0101
4205c16013365c02016385c0d015455c0c016515c01014525c050160c5d020170e5d04015125d06013185d060141e5d16010345d0101
6355d13015485d08014505d06014095e010100a5e020170c5e05015115e06013175e01014185e020131a5e010141b5e16016315e1601
5475e080144f5e05014055f01013065f03014095f030170c5f020100e5f010140f5f200162f5f16015455f080144d5f0701403600301
30660020140860130141e600e0122c60010132d60010162e600e0143c60010163d60070154460070144b600701403610c01410610201
41e610c0122a61020162c610f0143b61020163d61080154561040144961080141d620a01227620201629620f0143862030163b620b01
54662020144862070141e63060132463010152563040162963090153263010163363020143563040163963050143e63010163f630701
44663070161b63030241964020141e64030132164010152264060162864060152e640401432640501637640d01444640701617650101
41865040161c65010131d65020151f65090162865030152b65040142f650601635650d0144265070161466050141966020151b660101
31c66020151e660d0162b66010142c660701633660d01440660701610670601316670301519670f01428670801630670e0143e670701
60d680601313680501518680b01423680c0162f680c0143b68080160b69040130f690a0151969050141e690f0162d690b01438690801
6096a030130c6a0c014186a130162b6a0a014356a09017066b040160a6b020130c6b09016156b02014176b11013286b01016296b0901
4326b09014046c02017066c03016096c030140c6c1a013266c02016286c08014306c09014036d05016096d020140b6d090141d6d0801
3256d01016266d070142d6d090141d6e020161f6e03014226e02016246e04014286e080141b6f030131e6f010141f6f01016206f0201
4226f0b0161a70020141c700e01
]]}

-- GFX.drawTeamLogo: the traced logo as flat camera-facing rectangles. c = centre, ax/ay = unit
-- axes of the logo, W = width. pale 0..1 washes it toward pale pink, dis 0..1 breaks it into
-- slivers (each rectangle thins away at its own moment).
function GFX.teamLogoRects()
	local L=GFX_TEAMLOGO
	if L.rects then return L.rects end
	local rects={}
	local data=string.gsub(L.data,"%s","")
	local G,H=L.w,L.h
	local n=0
	for c,xx,yy,ww,hh in string.gmatch(data,"(%x)(%x%x)(%x%x)(%x%x)(%x%x)") do
		local px,py,pw,ph=tonumber(xx,16),tonumber(yy,16),tonumber(ww,16),tonumber(hh,16)
		n=n+1
		rects[n]={c=tonumber(c,16)+1,
			x=(px+pw*.5)/G-.5,y=(H*.5-(py+ph*.5))/G,      -- centre, in logo widths
			hw=pw*.5/G,hh=ph*.5/G,
			h=(n*.618034)%1}
	end
	L.rects=rects
	return rects
end

function GFX.drawTeamLogo(c,ax,ay,W,pale,bright,dis)
	local k=GFX.K*bright
	local lcs={}
	for i,p in ipairs(GFX_TEAMLOGO.pal) do
		lcs[i]=LinearColor.new((p[1]+(.95-p[1])*pale)*k,(p[2]+(.8-p[2])*pale)*k,(p[3]+(1-p[3])*pale)*k,1)
	end
	local cx,cy,cz=c.x,c.y,c.z
	local ux,uy,uz=ax.x*W,ax.y*W,ax.z*W
	local vx,vy,vz=ay.x*W,ay.y*W,ay.z*W
	local draw=WorldDraw.drawTriangle
	for _,r in ipairs(GFX.teamLogoRects()) do
		local t=0
		if dis>0 then t=math.clamp((dis-r.h*.55)/.45,0,1) end
		if t<1 then
			local hw,hh=r.hw*(1-t*t),r.hh*(1-t)
			local x0,x1,y0,y1=r.x-hw,r.x+hw,r.y-hh,r.y+hh
			local a=Vec3.new(cx+ux*x0+vx*y0,cy+uy*x0+vy*y0,cz+uz*x0+vz*y0)
			local b=Vec3.new(cx+ux*x1+vx*y0,cy+uy*x1+vy*y0,cz+uz*x1+vz*y0)
			local d=Vec3.new(cx+ux*x1+vx*y1,cy+uy*x1+vy*y1,cz+uz*x1+vz*y1)
			local e=Vec3.new(cx+ux*x0+vx*y1,cy+uy*x0+vy*y1,cz+uz*x0+vz*y1)
			local lc=lcs[r.c]
			draw(a,b,d,lc,0)
			draw(a,d,e,lc,0)
		end
	end
end

GFX_DEFS[40]={
	duration=function() return TEAMLOGO_TIMING.total end,
	init=function(x)
		local S=x.S
		x.ld=(x.u*.6+x.f*.7+x.r*.3):getSafeNormal()
		x.sc=x.base+x.f*(100*S)
		x.sp={}
		for i=1,GFX.n(x,16) do
			local th=GFX.rand(0,6.2832)
			local rr=math.sqrt(GFX.rand(0,1))*.62
			x.sp[i]={lx=math.cos(th)*rr,ly=math.sin(th)*rr*.82,t0=GFX.rand(0,1.2),per=GFX.rand(.55,1.1),sz=GFX.rand(10,26)}
		end
	end,
	update=function(x,age,d)
		local S,TM=x.S,TEAMLOGO_TIMING
		local U=x.u
		local R=GFX.flatRight(x)
		local Fv=GFX.cp-x.sc
		local F=(Fv-U*Vec3.dot(Fv,U)):getSafeNormal()
		local WS=TM.width*S
		-- size: flies up from nothing, then keeps growing slowly until it breaks up
		local grow
		if age<TM.settle then grow=(age/TM.settle)^1.6
		else grow=1+(age-TM.settle)*.4 end
		local W=WS*grow
		local m=goalFxSmooth(age/TM.settle)
		-- starts at the middle of the goal; once settled its bottom edge stays just over the floor
		local c=x.sc+F*(40*S)+U*((70*S)*(1-m)+(W*GFX_TEAMLOGO.h/GFX_TEAMLOGO.w*.5+10*S)*m)
		-- faces the camera; spins in about 1.4 turns and settles upright
		local toCam=(GFX.cp-c):getSafeNormal()
		local up=U-toCam*Vec3.dot(U,toCam)
		if up:length()<.05 then up=U end
		up=up:getSafeNormal()
		local right=Vec3.cross(up,toCam):getSafeNormal()
		if Vec3.dot(right,R)<0 then right=right*-1 end
		local ang=-9*(1-goalFxEaseOut(age/TM.spin))
		local ca,sa=math.cos(ang),math.sin(ang)
		local ax=right*ca+up*sa
		local ay=up*ca-right*sa
		local dis=math.clamp((age-TM.dissolve)/(TM.total-.05-TM.dissolve),0,1)

		-- soft magenta glow behind it so it stands out against a bright arena
		if dis<1 then GFX.glow(c-toCam*(6*S),W*.75,.7,.12,1,.3*(1-dis)*math.min(1,m*2),0,.2) end
		if age>.04 and dis<1 then
			local pale=1-goalFxSmooth((age-.35)/.6)
			GFX.drawTeamLogo(c,ax,ay,W,pale,.85,dis)
		end

		-- the ring that bursts out as it pops
		if age>TM.ring and age<TM.ringEnd then
			local rt=age-TM.ring
			local rad=.9*WS*(1-math.exp(-rt*3.6))
			local ra=1-goalFxSmooth((age-.7)/(TM.ringEnd-.7))
			GFX.ring(c+toCam*(3*S),right,up,rad,(1.5+3.5*ra)*S,48,1,.72,1,ra)
		end
		if GFX.once(x,"pop",TM.ring) then
			TeamLogoFX.sound("pop")
			GFX.flashAt(x,c,170*S,{.95,.6,1},.2)
			GFX.light(x,c,{.8,.2,1},30000,2400*S,.1,TM.dissolve-TM.ring,.5)
			GFX.addShake(6*S)
			for i=1,GFX.n(x,50) do
				local dir=GFX.rdir(x,.6):getSafeNormal()
				GFX.add({kind=2,p=c,v=dir*(GFX.rand(400,1000)*S),life=GFX.rand(.35,.7),s0=3*S,s1=.5*S,
					ramp={{1,1,1},{.95,.45,1},{.55,.1,.95}},drag=2.4,st=.04})
			end
		end
		if GFX.once(x,"settle",TM.settle) then TeamLogoFX.sound("settle") end

		-- four-point sparkles twinkling on and around it
		if age>TM.sparkle and dis<1 then
			local fade=goalFxSmooth((age-TM.sparkle)/.25)*(1-dis)
			local k=GFX.K*1.2
			for _,sp in ipairs(x.sp) do
				local ph=((age+sp.t0)/sp.per)%1
				local tw=math.sin(ph*math.pi)
				tw=tw*tw*fade
				if tw>.03 then
					local p=c+toCam*(5*S)+right*(sp.lx*W)+up*(sp.ly*W)
					local s=sp.sz*S*(.5+.5*tw)
					local lc=LinearColor.new(k*tw,k*tw,k*tw,tw)
					GFX.beam(p-right*s,p+right*s,1.1*S,lc)
					GFX.beam(p-up*s,p+up*s,1.1*S,lc)
				end
			end
		end
		if GFX.once(x,"dissolve",TM.dissolve) then TeamLogoFX.sound("dissolve") end
	end,
}

-- run control ------------------------------------------------------------------------------------
-- Shuffle: one pick per celebration, never the same one twice in a row. favOnly picks only from
-- the favorites (all of them if none are starred).
function goalFxShufflePick(favOnly)
	if goalFx.shuffleStamp~=goalFx.startTime then
		goalFx.shuffleStamp=goalFx.startTime
		local pool={}
		for i=1,#GFX_DEFS do
			if not favOnly or GoalFxIsFav(i) then pool[#pool+1]=i end
		end
		if #pool==0 then for i=1,#GFX_DEFS do pool[i]=i end end
		local n=#pool
		local at=1+math.floor(goalFxNoise(goalFx.startTime*7.31+1.7)*n)%n
		if pool[at]==goalFx.shufflePick and n>1 then at=(at%n)+1 end
		goalFx.shufflePick=pool[at]
	end
	return goalFx.shufflePick
end

function GFX.stop()
	-- let an effect undo anything it changed outside the engine (post-process, etc.)
	local run=GFX.run
	if run and run.def and run.def.cleanup then pcall(run.def.cleanup,run) end
	for _,L in ipairs(GFX.lights) do
		pcall(function() L.h:destroy() end)
	end
	GFX.lights={}
	GFX.parts={}
	GFX.run=nil
	GFX.stamp=nil
	GFX.shakeAmt=0
end

function GFX.start(c,u,r,toward)
	GFX.stop()
	GFX.stamp=goalFx.startTime
	GFX.rs=1+math.floor(goalFxNoise(goalFx.startTime*3.17+.5)*2147480000)
	local qi=math.clamp(math.floor(config.goalFxQuality or 3),1,4)
	GFX.cap=GFX_CAPS[qi]
	local anchor,dirR=goalFxAnchor(c,u,r)
	local typ=math.floor(goalFx.typeOverride or config.goalFxType or GOALFX_SHUFFLE)
	if typ<1 or typ>#GOAL_FX_TYPES then typ=GOALFX_SHUFFLE end
	if typ==GOALFX_SHUFFLE then typ=goalFxShufflePick(false)
	elseif typ==GOALFX_SHUFFLE_FAV then typ=goalFxShufflePick(true) end
	local def=GFX_DEFS[typ] or GFX_DEFS[1]
	-- effects with their own fixed timeline (Death Note) say how long they last themselves
	local D=def.duration and def.duration() or math.clamp(config.goalFxDuration or 3.6,1,8)
	local x={typ=typ,def=def,D=D,S=math.clamp(config.goalFxSize or 1,.3,3),
		q=GFX_QMUL[qi],qi=qi,ts=math.clamp(D/3.6,.7,1.5),
		-- the Height setting lifts the whole effect (floor-based parts too), not just its centre,
		-- so the explosion and the goal camera move together
		o=anchor,c=c,u=u,r=dirR,f=toward,
		base=goalFxFloorBase(c,u,dirR)+toward*30+u*((config.goalFxTextOffsetY or 110)-110),
		age=0,last=0,d=0,acc={},fired={},fx={}}
	GFX.run=x
	GFX.camera()
	if x.def.init then x.def.init(x) end
end

function GFX.camera()
	GFX.K=math.clamp(config.goalFxGlow or 1.6,.3,4)
	GFX.cp=camPos
	pcall(function()
		GFX.bR=camRot:getRightVector()
		GFX.bU=camRot:getUpVector()
	end)
end

function GFX.frame(x,age)
	x.d=math.clamp(age-x.last,0,.1)
	x.last=age
	x.age=age
	GFX.camera()
	GFX.shakeAmt=(GFX.shakeAmt or 0)*math.exp(-6*x.d)
	x.def.update(x,age,x.d)
	GFX.drawTimed(x)
	GFX.sim(x,x.d)
	GFX.lightsTick(x,age)
end

function drawGoalFxRaw()
	if not WorldDraw or not goalFx.active or not (config.goalFxEnabled or goalFx.preview) then
		if GFX.run then GFX.stop() end
		return
	end
	local c,u,r,toward=goalFxFrame()
	if not c then
		GFX.stop()
		return
	end
	if not GFX.run or GFX.stamp~=goalFx.startTime then GFX.start(c,u,r,toward) end
	local x=GFX.run
	local age=totalTime-goalFx.startTime
	-- keep going after the timeline ends until the last particles have faded
	if age>=x.D and (#GFX.parts==0 or age>=x.D+2.5) then
		GFX.stop()
		if goalFx.preview and config.goalFxTestLoop then
			goalFx.startTime=totalTime
		else
			goalFx.active=false
		end
		return
	end
	GFX.frame(x,age)
end

-- =====================================================================================
-- GOAL CLIPS
-- A script cannot press hotkeys, reach the network or record video. So each wanted goal bumps
-- clipEventId and saves the config file, and the PicklerClipCompanion program (outside the game)
-- watches that file and asks OBS / Medal to save the clip. Separately, the game's own replay
-- recorder can be split at every goal (no trimming and no folder choice: the API has neither).
-- =====================================================================================
clipState={arena=nil,init=false,lastStamp=0,lastTeam="",lastTime=-999,rec=false,stopAt=nil,nextTry=0,recCount=0}

function PicklerClipSendEvent(team)
	config.clipEventId=(config.clipEventId or 0)+1
	config.clipEventTeam=team
	saveConfig()
end

function PicklerClipReplayAllowed()
	local ok,res=pcall(function() return Settings.getLuauReplayControlAllowed() end)
	return ok and res==true
end

function PicklerClipStopReplay()
	local ok,res=pcall(function() return Replay.stopRecording() end)
	if ok and res then clipState.recCount=clipState.recCount+1 end
	clipState.rec=false
	clipState.stopAt=nil
end

-- records while a round runs; a goal (or the round ending) closes the file a few seconds later
function PicklerClipReplayTick()
	local S=clipState
	if not config.clipRecordReplays or readLocation~=0 or not PicklerClipReplayAllowed() then
		if S.rec then PicklerClipStopReplay() end
		return
	end
	local running=selectedArena and selectedArena.isActive
	if S.rec and S.stopAt and totalTime>=S.stopAt then PicklerClipStopReplay() end
	if S.rec and not running and not S.stopAt then S.stopAt=totalTime+(config.clipPostSeconds or 5) end
	if running and not S.rec and totalTime>=S.nextTry then
		S.nextTry=totalTime+2
		local ok,res=pcall(function() return Replay.startRecording() end)
		S.rec=ok and res==true
	end
end

function updateAutoClip()
	PicklerClipReplayTick()
	if not selectedArena then return end
	if clipState.arena~=selectedArena then
		clipState.arena=selectedArena
		clipState.init=false
	end
	local stamp=selectedArena.goalScoredTime or 0
	if not clipState.init then
		clipState.init=true
		clipState.lastStamp=stamp
		return
	end
	if stamp>clipState.lastStamp and selectedArena.goalScoredGoal then
		clipState.lastStamp=stamp
		-- the ball went into the DEFENDING team's goal, so the other team scored
		local g=selectedArena.goalScoredGoal
		local team=nil
		if g==selectedArena.away.goal then team="HOME"
		elseif g==selectedArena.home.goal then team="AWAY" end
		local want=(team=="HOME" and config.clipHomeGoals) or (team=="AWAY" and config.clipAwayGoals)
		if want then
			config.clipCount=(config.clipCount or 0)+1
			clipState.lastTeam=team
			clipState.lastTime=totalTime
			PicklerClipSendEvent(team)
			if clipState.rec and not clipState.stopAt then
				clipState.stopAt=totalTime+(config.clipPostSeconds or 5)
			end
		end
	end
end

-- Flash softening (Allow bright flashes off) now happens inside the v2 engine itself.
-- On an error the celebration is stopped so its lights don't get left behind in the arena.
function drawGoalFx()
	if not WorldDraw then return end
	local ok,err=pcall(drawGoalFxRaw)
	if not ok then
		-- kept until the next TEST: the frame-by-frame script error clears itself straight away
		local nm=GFX.run and GOAL_FX_TYPES[GFX.run.typ] or "?"
		GFX_LAST_ERROR=tostring(nm)..": "..tostring(err)
		goalFx.active=false
		GFX.stop()
		error(err,0)
	end
end

local KF_INTERP = {LINEAR=1, EASE_IN_OUT=2, SMOOTH_STEP=3, CATMULL_ROM=4, EASE_IN=5, EASE_OUT=6, SMOOTH_FLOW=7, SMOOTH_SPLINE=8}
local KF_INTERP_NAMES = {"Linear", "Ease In/Out", "Smooth Step", "Catmull-Rom", "Ease In", "Ease Out", "Smooth Flow", "Smooth Spline"}

local kfState = {
	enabled       = false,
	keyframes     = {},
	selectedIdx   = 0,
	isPlaying     = false,
	playbackTime  = 0,
	totalDuration = 10,
	freeCamPos    = Vec3.new(0, 0, 500),
	freeCamYaw    = 0,
	freeCamPitch  = -30,
	freeCamFOV    = 90,
	freeCamRoll   = 0,
	freeCamLook   = Vec3.new(0, 0, 0),
	gravityChaser = nil,
	revision      = 0,
}

local KF_PITCH_LIMIT = 89.9

function kfGravityUp()
	local ok, g = pcall(function() return gravity.upRotation end)
	if ok and g then return g end
	return Quat.identity
end

function kfGravityStrength()
	local ok, s = pcall(function() return gravity.strength end)
	if ok and s then return s end
	return 1
end

function kfProjectOntoPlane(v, n)
	return v - n * Vec3.dot(v, n)
end

function kfXor(a, b) return (a or b) and not (a and b) end

function kfFreeCamWorldRot()
	if not kfState.gravityChaser then kfState.gravityChaser = kfGravityUp() end
	local ok, r = pcall(function()
		return kfState.gravityChaser * Quat.fromEuler(kfState.freeCamRoll, kfState.freeCamPitch, kfState.freeCamYaw)
	end)
	if ok and r then return r end
	return camRot
end

function kfDecomposeToFreeCam(rot, reset)
	if reset or not kfState.gravityChaser then kfState.gravityChaser = kfGravityUp() end
	local ok, e = pcall(function()
		return (kfState.gravityChaser:inverse() * rot):euler()
	end)
	if not ok or not e then return end
	kfState.freeCamRoll  = e.x
	kfState.freeCamPitch = math.clamp(e.y, -KF_PITCH_LIMIT, KF_PITCH_LIMIT)
	kfState.freeCamYaw   = e.z
end

local function easeLinear(t) return t end

local function easeInOut(t)
	if t < 0.5 then return 2 * t * t end
	return 1 - ((-2 * t + 2) ^ 2) / 2
end

local function easeSmoothStep(t)
	return t * t * (3 - 2 * t)
end

local function easeIn(t)
	return t * t * t
end

local function easeOut(t)
	return 1 - (1 - t) ^ 3
end

local function getEaseFunc(mode)
	if mode == KF_INTERP.EASE_IN_OUT  then return easeInOut   end
	if mode == KF_INTERP.SMOOTH_STEP  then return easeSmoothStep end
	if mode == KF_INTERP.EASE_IN      then return easeIn      end
	if mode == KF_INTERP.EASE_OUT     then return easeOut     end
	return easeLinear
end

local KF_RAMP_DEFAULT = {0.40, 0.00, 0.00, 1.00}

local KF_RAMP_PRESETS = {
	{name = "Smooth (0.4,0,0,1)", x1 = 0.40, y1 = 0.00, x2 = 0.00, y2 = 1.00},
	{name = "Ease In/Out",        x1 = 0.42, y1 = 0.00, x2 = 0.58, y2 = 1.00},
	{name = "Ease In (slow start)",x1 = 0.42, y1 = 0.00, x2 = 1.00, y2 = 1.00},
	{name = "Ease Out (slow end)", x1 = 0.00, y1 = 0.00, x2 = 0.58, y2 = 1.00},
	{name = "Strong In",          x1 = 0.80, y1 = 0.00, x2 = 1.00, y2 = 1.00},
	{name = "Strong Out",         x1 = 0.00, y1 = 0.00, x2 = 0.20, y2 = 1.00},
	{name = "Ramp 80-20 (fast>slow)", x1 = 0.10, y1 = 0.60, x2 = 0.30, y2 = 1.00},
	{name = "Ramp 20-80 (slow>fast)", x1 = 0.70, y1 = 0.00, x2 = 0.90, y2 = 0.40},
	{name = "Snap (hold then jump)",  x1 = 0.90, y1 = 0.00, x2 = 0.10, y2 = 1.00},
	{name = "Anticipate",         x1 = 0.36, y1 = -0.30, x2 = 0.66, y2 = 1.00},
	{name = "Overshoot",          x1 = 0.34, y1 = 0.00, x2 = 0.64, y2 = 1.30},
	{name = "Linear (off-curve)",  x1 = 0.33, y1 = 0.33, x2 = 0.67, y2 = 0.67},
}

function kfBezCoord(a1, a2, u)
	return (((1 - 3*a2 + 3*a1)*u + (3*a2 - 6*a1))*u + 3*a1)*u
end

function kfBezSlope(a1, a2, u)
	return 3*(1 - 3*a2 + 3*a1)*u*u + 2*(3*a2 - 6*a1)*u + 3*a1
end

function kfRampEval(ramp, x)
	if not ramp then return x end
	x = math.clamp(x, 0, 1)
	if x <= 0 then return 0 end
	if x >= 1 then return 1 end
	local x1 = math.clamp(ramp[1] or 0, 0, 1)
	local y1 = ramp[2] or 0
	local x2 = math.clamp(ramp[3] or 1, 0, 1)
	local y2 = ramp[4] or 1

	local u = x
	for _ = 1, 8 do
		local err = kfBezCoord(x1, x2, u) - x
		if math.abs(err) < 1e-5 then
			return kfBezCoord(y1, y2, u)
		end
		local s = kfBezSlope(x1, x2, u)
		if math.abs(s) < 1e-6 then break end
		u = math.clamp(u - err / s, 0, 1)
	end

	local lo, hi = 0, 1
	u = x
	for _ = 1, 24 do
		local cx = kfBezCoord(x1, x2, u)
		if math.abs(cx - x) < 1e-5 then break end
		if cx < x then lo = u else hi = u end
		u = (lo + hi) * 0.5
	end
	return kfBezCoord(y1, y2, u)
end

function kfSegmentRamp(a)
	if a and a.rampEnabled and a.ramp then return a.ramp end
	return nil
end

local KF_SPARK_BLOCKS = {"▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"}
function kfRampSparkline(ramp, cols)
	cols = cols or 26
	local out = {}
	for i = 0, cols - 1 do
		local x = (cols == 1) and 0 or (i / (cols - 1))
		local y = kfRampEval(ramp, x)
		local lvl = math.floor(math.clamp(y, 0, 1) * 7 + 0.5) + 1
		out[#out + 1] = KF_SPARK_BLOCKS[math.clamp(lvl, 1, 8)]
	end
	return table.concat(out)
end

local function catmullRomF(p0, p1, p2, p3, t, tension)
	tension = tension or 0.5
	local t2 = t * t
	local t3 = t2 * t
	local s  = (1 - tension) / 2
	local a  = -s*p0 + (2-s)*p1 + (s-2)*p2 + s*p3
	local b  = 2*s*p0 + (s-3)*p1 + (3-2*s)*p2 - s*p3
	local c  = -s*p0 + s*p2
	local d  = p1
	return a*t3 + b*t2 + c*t + d
end

local function catmullRomVec(p0, p1, p2, p3, t, tension)
	return Vec3.new(
		catmullRomF(p0.x, p1.x, p2.x, p3.x, t, tension),
		catmullRomF(p0.y, p1.y, p2.y, p3.y, t, tension),
		catmullRomF(p0.z, p1.z, p2.z, p3.z, t, tension))
end

local function safeSlerp(a, b, t)
	if quatDot(a, b) < 0 then b = quatNeg(b) end
	return Quat.slerp(a, b, math.clamp(t, 0, 1))
end

function kfComputeTangents()
	local kfs = kfState.keyframes
	local n = #kfs
	if n == 0 then return end
	local tension = math.min(config.kfTension or 0.5, 0.999)
	for i = 1, n do
		local k = kfs[i]
		if n == 1 then
			k.posTan = Vec3.zeroVector
			k.fovTan = 0
		elseif i == 1 then
			local dt = kfs[2].time - k.time
			k.posTan = (kfs[2].pos - k.pos) / dt
			k.fovTan = (kfs[2].fov - k.fov) / dt
		elseif i == n then
			local dt = k.time - kfs[n-1].time
			k.posTan = (k.pos - kfs[n-1].pos) / dt
			k.fovTan = (k.fov - kfs[n-1].fov) / dt
		else
			local dt = kfs[i+1].time - kfs[i-1].time
			k.posTan = (kfs[i+1].pos - kfs[i-1].pos) / dt
			k.fovTan = (kfs[i+1].fov - kfs[i-1].fov) / dt
		end
		k.posTan = k.posTan * (1 - tension)
		k.fovTan = k.fovTan * (1 - tension)
	end
end

local function hermiteF(p0, p1, m0, m1, s)
	local s2 = s * s
	local s3 = s2 * s
	return (2*s3 - 3*s2 + 1)*p0 + (s3 - 2*s2 + s)*m0 + (-2*s3 + 3*s2)*p1 + (s3 - s2)*m1
end

local function smoothFlowPos(t, idxA, idxB, localT)
	local kfs = kfState.keyframes
	local a, b = kfs[idxA], kfs[idxB]
	local h = b.time - a.time
	if h < 1e-6 then return a.pos end
	local m0 = a.posTan * h
	local m1 = b.posTan * h
	return Vec3.new(
		hermiteF(a.pos.x, b.pos.x, m0.x, m1.x, localT),
		hermiteF(a.pos.y, b.pos.y, m0.y, m1.y, localT),
		hermiteF(a.pos.z, b.pos.z, m0.z, m1.z, localT))
end

local function smoothFlowFOV(t, idxA, idxB, localT)
	local kfs = kfState.keyframes
	local a, b = kfs[idxA], kfs[idxB]
	local h = b.time - a.time
	if h < 1e-6 then return a.fov end
	local m0 = a.fovTan * h
	local m1 = b.fovTan * h
	return hermiteF(a.fov, b.fov, m0, m1, localT)
end

local function quatScale(q, s) return Quat.new(q.x*s, q.y*s, q.z*s, q.w*s) end
local function quatAddRaw(a, b) return Quat.new(a.x+b.x, a.y+b.y, a.z+b.z, a.w+b.w) end

local function quatLog(q)
	local v = math.sqrt(q.x*q.x + q.y*q.y + q.z*q.z)
	if v < 1e-8 then return Quat.new(0, 0, 0, 0) end
	local theta = math.atan2(v, q.w)
	local k = theta / v
	return Quat.new(q.x*k, q.y*k, q.z*k, 0)
end

local function quatExp(p)
	local v = math.sqrt(p.x*p.x + p.y*p.y + p.z*p.z)
	if v < 1e-8 then return Quat.new(0, 0, 0, 1) end
	local s = math.sin(v) / v
	return Quat.new(p.x*s, p.y*s, p.z*s, math.cos(v))
end

local function squadIntermediate(qPrev, qi, qNext)
	local qiInv   = qi:inverse()
	local logNext = quatLog(qiInv * qNext)
	local logPrev = quatLog(qiInv * qPrev)
	local inner   = quatScale(quatAddRaw(logNext, logPrev), -0.25)
	return qi * quatExp(inner)
end

local function squad(q0, q1, s0, s1, u)
	u = math.clamp(u, 0, 1)
	local a = safeSlerp(q0, q1, u)
	local b = safeSlerp(s0, s1, u)
	return safeSlerp(a, b, 2 * u * (1 - u))
end

local function buildNaturalSpline1D(xs, ys)
	local m = #xs
	if m < 2 then return nil end
	local seg = m - 1

	local h = {}
	for i = 1, seg do
		local dx = xs[i+1] - xs[i]
		h[i] = (dx > 1e-9) and dx or 1e-9
	end

	local alpha = {}
	for i = 2, seg do
		alpha[i] = (3 / h[i]) * (ys[i+1] - ys[i]) - (3 / h[i-1]) * (ys[i] - ys[i-1])
	end

	local l, mu, z = {}, {}, {}
	l[1], mu[1], z[1] = 1, 0, 0
	for i = 2, seg do
		l[i] = 2 * (xs[i+1] - xs[i-1]) - h[i-1] * mu[i-1]
		if math.abs(l[i]) < 1e-12 then l[i] = 1e-12 end
		mu[i] = h[i] / l[i]
		z[i]  = (alpha[i] - h[i-1] * z[i-1]) / l[i]
	end
	l[m], z[m] = 1, 0

	local c = {}
	c[m] = 0
	for j = seg, 1, -1 do
		c[j] = z[j] - mu[j] * c[j+1]
	end

	local segs = {}
	for j = 1, seg do
		local a = ys[j]
		local b = (ys[j+1] - ys[j]) / h[j] - h[j] * (c[j+1] + 2 * c[j]) / 3
		local d = (c[j+1] - c[j]) / (3 * h[j])
		segs[j] = {a = a, b = b, c = c[j], d = d, x = xs[j], xEnd = xs[j+1]}
	end
	return segs
end

local function evalSpline1D(segs, t)
	if not segs then return 0 end
	local n = #segs
	local t0, t1 = segs[1].x, segs[n].xEnd
	if t < t0 then t = t0 elseif t > t1 then t = t1 end
	local lo, hi = 1, n
	while lo < hi do
		local mid = math.floor((lo + hi + 1) / 2)
		if segs[mid].x <= t then lo = mid else hi = mid - 1 end
	end
	local s  = segs[lo]
	local dx = t - s.x
	return ((s.d * dx + s.c) * dx + s.b) * dx + s.a
end

local kfSplineCache = {builtRevision = -1, segsPos = nil, segsFov = nil, rotSeq = nil, rotCtl = nil}

function kfBuildSpline()
	local kfs = kfState.keyframes
	local n = #kfs
	if n < 2 then
		kfSplineCache.segsPos = nil; kfSplineCache.segsFov = nil
		kfSplineCache.rotSeq  = nil; kfSplineCache.rotCtl  = nil
		kfSplineCache.builtRevision = kfState.revision
		return
	end
	if kfSplineCache.builtRevision == kfState.revision then return end
	kfSplineCache.builtRevision = kfState.revision

	local t, vx, vy, vz, vfov = {}, {}, {}, {}, {}
	for i = 1, n do
		t[i]    = kfs[i].time
		vx[i]   = kfs[i].pos.x
		vy[i]   = kfs[i].pos.y
		vz[i]   = kfs[i].pos.z
		vfov[i] = kfs[i].fov
	end

	kfSplineCache.segsPos = {
		x = buildNaturalSpline1D(t, vx),
		y = buildNaturalSpline1D(t, vy),
		z = buildNaturalSpline1D(t, vz),
	}
	kfSplineCache.segsFov = buildNaturalSpline1D(t, vfov)

	local rotSeq = {}
	rotSeq[1] = kfs[1].rot
	for i = 2, n do
		local q = kfs[i].rot
		if quatDot(rotSeq[i-1], q) < 0 then q = quatNeg(q) end
		rotSeq[i] = q
	end
	local ctl = {}
	ctl[1] = rotSeq[1]
	ctl[n] = rotSeq[n]
	for i = 2, n - 1 do
		ctl[i] = squadIntermediate(rotSeq[i-1], rotSeq[i], rotSeq[i+1])
	end
	kfSplineCache.rotSeq = rotSeq
	kfSplineCache.rotCtl = ctl
end

function kfSmoothSplinePos(t)
	kfBuildSpline()
	local sp = kfSplineCache.segsPos
	if not sp then
		local k = kfState.keyframes[1]
		return k and k.pos or Vec3.zeroVector
	end
	return Vec3.new(
		evalSpline1D(sp.x, t),
		evalSpline1D(sp.y, t),
		evalSpline1D(sp.z, t))
end

function kfSmoothSplineFov(t)
	kfBuildSpline()
	local sf = kfSplineCache.segsFov
	if not sf then
		local k = kfState.keyframes[1]
		return k and k.fov or 90
	end
	local f = evalSpline1D(sf, t)
	if f < 1 then f = 1 elseif f > 179 then f = 179 end
	return f
end

function kfSmoothSplineRot(idxA, idxB, u)
	kfBuildSpline()
	local c = kfSplineCache
	local kfs = kfState.keyframes
	if not (c.rotSeq and c.rotCtl and c.rotSeq[idxA] and c.rotSeq[idxB]) then
		return safeSlerp(kfs[idxA].rot, kfs[idxB].rot, u)
	end
	return squad(c.rotSeq[idxA], c.rotSeq[idxB], c.rotCtl[idxA], c.rotCtl[idxB], u)
end

function kfSort()
	table.sort(kfState.keyframes, function(a, b) return a.time < b.time end)
	kfComputeTangents()
	kfState.revision = kfState.revision + 1
end

function kfSnap(t)
	if config.kfSnapEnabled then
		local step = config.kfSnapStep or 1.0
		if step > 0 then t = math.floor(t / step + 0.5) * step end
	end
	if t < 0 then t = 0 end
	return t
end

function kfCaptureTransform()
	if config.kfUseFreeCam then
		local rot = kfFreeCamWorldRot()
		return kfState.freeCamPos, rot, kfState.freeCamFOV,
			kfState.freeCamYaw, kfState.freeCamPitch, kfState.freeCamRoll
	end
	local e = camRot:euler()
	return camPos, camRot, camFOV, e.z, e.y, e.x
end

function kfReplayTimeNow()
	if readLocation > 0 then
		local r = Replay.getByIndex(readLocation)
		if r then
			local ok, ct = pcall(function() return r:getCurrentTime() end)
			if ok and ct then return ct end
		end
	end
	return 0
end

function kfAdd()
	local pos, rot, fov, yaw, pitch, roll = kfCaptureTransform()
	local kf = {
		time       = kfState.playbackTime,
		replayTime = kfReplayTimeNow(),
		pos        = Vec3.new(pos.x, pos.y, pos.z),
		yaw        = yaw,
		pitch      = pitch,
		roll       = roll,
		fov        = fov,
		rot        = rot,
		rampEnabled = false,
		ramp        = {KF_RAMP_DEFAULT[1], KF_RAMP_DEFAULT[2],
		               KF_RAMP_DEFAULT[3], KF_RAMP_DEFAULT[4]},
	}
	kfState.keyframes[#kfState.keyframes + 1] = kf
	kfSort()
	for i, k in ipairs(kfState.keyframes) do
		if k == kf then kfState.selectedIdx = i; break end
	end
end

function kfDelete(idx)
	if idx < 1 or idx > #kfState.keyframes then return end
	table.remove(kfState.keyframes, idx)
	if kfState.selectedIdx == idx then
		kfState.selectedIdx = math.min(idx, #kfState.keyframes)
	elseif kfState.selectedIdx > idx then
		kfState.selectedIdx = kfState.selectedIdx - 1
	end
	kfSort()
end

function kfUpdateSelected()
	local idx = kfState.selectedIdx
	if idx < 1 or idx > #kfState.keyframes then return end
	local kf = kfState.keyframes[idx]
	local pos, rot, fov, yaw, pitch, roll = kfCaptureTransform()
	kf.pos   = Vec3.new(pos.x, pos.y, pos.z)
	kf.yaw   = yaw
	kf.pitch = pitch
	kf.roll  = roll
	kf.fov   = fov
	kf.rot   = rot
	kf.replayTime = kfReplayTimeNow()
	kfSort()
	for i, k in ipairs(kfState.keyframes) do
		if k == kf then kfState.selectedIdx = i; break end
	end
end

function kfGoTo(idx)
	if idx < 1 or idx > #kfState.keyframes then return end
	local kf = kfState.keyframes[idx]
	kfState.freeCamPos   = Vec3.new(kf.pos.x, kf.pos.y, kf.pos.z)
	kfState.freeCamFOV   = kf.fov
	kfState.playbackTime = kf.time
	kfState.selectedIdx  = idx
	camRot = kf.rot
	kfDecomposeToFreeCam(kf.rot, true)
	if readLocation > 0 then
		local r = Replay.getByIndex(readLocation)
		if r then pcall(function() r:setCurrentTime(kf.replayTime) end) end
	end
end

function kfFindSegment(t)
	local kfs = kfState.keyframes
	local n = #kfs
	if n == 0 then return 0, 0, 0 end
	if n == 1 then return 1, 1, 0 end
	if t <= kfs[1].time then return 1, 1, 0 end
	if t >= kfs[n].time then return n, n, 0 end
	for i = 1, n - 1 do
		if t >= kfs[i].time and t <= kfs[i+1].time then
			local seg = kfs[i+1].time - kfs[i].time
			local localT = seg > 0.0001 and ((t - kfs[i].time) / seg) or 0
			return i, i + 1, localT
		end
	end
	return n, n, 0
end

function kfInterpolate(t)
	local kfs = kfState.keyframes
	local n = #kfs
	if n == 0 then return nil end
	if n == 1 then return kfs[1] end

	local idxA, idxB, localT = kfFindSegment(t)
	if idxA == idxB then return kfs[idxA] end

	local a, b = kfs[idxA], kfs[idxB]
	local mode = config.kfInterpMode or KF_INTERP.LINEAR

	local ramp   = kfSegmentRamp(a)
	local warped = ramp and kfRampEval(ramp, localT) or nil
	local h      = b.time - a.time
	local sampT  = warped and (a.time + warped * h) or t
	local segT   = warped or localT

	local rtT = (mode == KF_INTERP.CATMULL_ROM or mode == KF_INTERP.SMOOTH_FLOW or mode == KF_INTERP.SMOOTH_SPLINE)
		and segT or (warped or getEaseFunc(mode)(localT))
	local replayTime = a.replayTime + (b.replayTime - a.replayTime) * math.clamp(rtT, 0, 1)

	if mode == KF_INTERP.SMOOTH_FLOW then
		local pos = smoothFlowPos(sampT, idxA, idxB, segT)
		local fov = smoothFlowFOV(sampT, idxA, idxB, segT)
		local rot = safeSlerp(a.rot, b.rot, segT)
		return {pos=pos, rot=rot, fov=fov, replayTime=replayTime}
	end

	if mode == KF_INTERP.SMOOTH_SPLINE then
		local pos = kfSmoothSplinePos(sampT)
		local fov = kfSmoothSplineFov(sampT)
		local rot = kfSmoothSplineRot(idxA, idxB, math.clamp(segT, 0, 1))
		return {pos=pos, rot=rot, fov=fov, replayTime=replayTime}
	end

	if mode == KF_INTERP.CATMULL_ROM then
		local i0 = math.max(1, idxA - 1)
		local i3 = math.min(n, idxB + 1)
		local p0, p1, p2, p3 = kfs[i0], kfs[idxA], kfs[idxB], kfs[i3]
		local tension = config.kfTension or 0.5
		local pos = catmullRomVec(p0.pos, p1.pos, p2.pos, p3.pos, segT, tension)
		local fov = catmullRomF(p0.fov, p1.fov, p2.fov, p3.fov, segT, tension)
		local rot = safeSlerp(p1.rot, p2.rot, segT)
		return {pos=pos, rot=rot, fov=fov, replayTime=replayTime}
	end

	local et  = warped or getEaseFunc(mode)(localT)
	local pos = Vec3.lerp(a.pos, b.pos, et)
	local rot = safeSlerp(a.rot, b.rot, math.clamp(et, 0, 1))
	local fov = a.fov + (b.fov - a.fov) * et
	return {pos=pos, rot=rot, fov=fov, replayTime=replayTime}
end

function kfSyncFreeCamFromRot(rot)
	kfDecomposeToFreeCam(rot, false)
end

function kfSyncReplayTime()
	if not (config.kfLinkReplay and readLocation > 0 and kfState.enabled) then return end
	local r = Replay.getByIndex(readLocation)
	if not r then return end
	if kfState.isPlaying then return end
	local result = kfInterpolate(kfState.playbackTime)
	if result and result.replayTime then
		pcall(function() r:setCurrentTime(result.replayTime) end)
	end
end

local function keyHeld(k) return k ~= nil and Input.getKey(k) end
local function keyDown(k) return k ~= nil and Input.getKeyDown(k) end

local function freeCamTick(d)
	if not kfState.gravityChaser then kfState.gravityChaser = kfGravityUp() end

	local rotSpeed         = config.kfFreeCamRotSpeed or 180
	local mouseSensitivity = config.kfMouseSensitivity or 3.6
	local minFov           = config.kfMinFOV or 10
	local maxFov           = config.kfMaxFOV or 160

	local altHeld = keyHeld(Input.Key.LeftAlt) or keyHeld(Input.Key.RightAlt)
	local rmb     = keyHeld(Input.Key.RightMouseButton)
	local rollGp  = keyHeld(Input.Gamepad.DPad_Left) or keyHeld(Input.Gamepad.DPad_Right)

	local forward = camRot:getForwardVector()
	local right   = camRot:getRightVector()
	local up      = camRot:getUpVector()
	local gUp     = kfState.gravityChaser:getUpVector()
	local gForward = kfProjectOntoPlane(forward, gUp):getSafeNormal()
	local useLocalAxes = kfXor(config.kfLocalMoveAxes, altHeld)

	local speed   = config.kfFreeCamSpeed or 1600
	local minS    = config.kfMinMoveSpeed or 50
	local maxS    = config.kfMaxMoveSpeed or 6000
	local rate    = config.kfSpeedAdjustRate or 2.0
	if keyHeld(Input.Key.LeftShift) or keyHeld(Input.Key.RightShift) or keyHeld(Input.Gamepad.RightShoulder) then
		speed = speed * (1 + rate * d)
	elseif keyHeld(Input.Key.LeftControl) or keyHeld(Input.Gamepad.LeftShoulder) then
		speed = speed * (1 - rate * d)
	end
	speed = math.clamp(speed, minS, maxS)
	config.kfFreeCamSpeed = speed

	local fov = kfState.freeCamFOV
	local okW, w = pcall(function() return Input.getAnalog(Input.Key.MouseWheelAxis) end)
	if okW and w then fov = fov - w * (config.kfZoomSpeedMouse or 5.0) end
	if keyHeld(Input.Key.PageUp)   or keyHeld(Input.Gamepad.DPad_Up)   then fov = fov - (config.kfZoomSpeedKey or 60) * d end
	if keyHeld(Input.Key.PageDown) or keyHeld(Input.Gamepad.DPad_Down) then fov = fov + (config.kfZoomSpeedKey or 60) * d end
	fov = math.clamp(fov, minFov, maxFov)
	kfState.freeCamFOV = fov

	local fovMult        = config.kfFovRotSpeedMult or 2.0
	local adjustedRot    = fovMult * (fov - 90) / 90 + rotSpeed
	local adjustedMouse  = fovMult * (fov - 90) / 90 + mouseSensitivity
	local lookSmoothness = config.kfLookSmoothness or 0.0
	local adjustedLookSmoothness = 1 - (1 - lookSmoothness) ^ 3

	local input = Vec3.zeroVector
	if keyHeld(Input.Key.W) then input = input + (useLocalAxes and forward or gForward) end
	if keyHeld(Input.Key.S) then input = input - (useLocalAxes and forward or gForward) end
	if keyHeld(Input.Key.D) then input = input + right end
	if keyHeld(Input.Key.A) then input = input - right end
	if keyHeld(Input.Key.E) or keyHeld(Input.Key.R) then input = input + (useLocalAxes and up or gUp) end
	if keyHeld(Input.Key.Q) or keyHeld(Input.Key.F) then input = input - (useLocalAxes and up or gUp) end
	input = input + right   * Input.getAnalog(Input.Gamepad.LeftX)
	input = input + (useLocalAxes and forward or gForward) * Input.getAnalog(Input.Gamepad.LeftY)
	input = input + (useLocalAxes and up or gUp) * Input.getAnalog(Input.Gamepad.RightTriggerAxis)
	input = input - (useLocalAxes and up or gUp) * Input.getAnalog(Input.Gamepad.LeftTriggerAxis)

	local lookDelta = Vec3.new(0, 0, 0)
	local mouse = Input.getMouseDelta()
	if mouse and mouse.x then
		if rmb then
			lookDelta.x = lookDelta.x + mouse.x * mouseSensitivity / 2.0
		else
			lookDelta.z = lookDelta.z + mouse.x * adjustedMouse
			lookDelta.y = lookDelta.y + mouse.y * adjustedMouse
		end
	end
	if keyHeld(Input.Key.Right) then lookDelta.z = lookDelta.z + adjustedRot * d end
	if keyHeld(Input.Key.Left)  then lookDelta.z = lookDelta.z - adjustedRot * d end
	if keyHeld(Input.Key.Up)    then lookDelta.y = lookDelta.y + adjustedRot * d end
	if keyHeld(Input.Key.Down)  then lookDelta.y = lookDelta.y - adjustedRot * d end
	if keyHeld(Input.Key.Z)     then lookDelta.x = lookDelta.x - adjustedRot * d * 0.5 end
	if keyHeld(Input.Key.X)     then lookDelta.x = lookDelta.x + adjustedRot * d * 0.5 end
	if keyHeld(Input.Gamepad.DPad_Right) then lookDelta.x = lookDelta.x + (config.kfFreeCamRotSpeed or 180) * d / 2 end
	if keyHeld(Input.Gamepad.DPad_Left)  then lookDelta.x = lookDelta.x - (config.kfFreeCamRotSpeed or 180) * d / 2 end
	lookDelta.z = lookDelta.z + Input.getAnalog(Input.Gamepad.RightX) * adjustedRot * d
	lookDelta.y = lookDelta.y + Input.getAnalog(Input.Gamepad.RightY) * adjustedRot * d

	local rollAngle = -kfState.freeCamRoll * math.pi / 180.0
	local rollAdjusted = Vec3.new(
		lookDelta.x,
		lookDelta.y * math.cos(rollAngle) + lookDelta.z * math.sin(rollAngle),
		lookDelta.z * math.cos(rollAngle) - lookDelta.y * math.sin(rollAngle))
	kfState.freeCamLook = kfState.freeCamLook + rollAdjusted
	local nextLookDiff = kfState.freeCamLook * math.min((1 - adjustedLookSmoothness) * d * 60, 1)

	if config.kfAlignToGravity then
		local target = kfGravityUp()
		if kfState.gravityChaser ~= target and kfGravityStrength() ~= 0 then
			local inputTotal  = nextLookDiff:length()
			local chaseT      = (inputTotal * (config.kfGravityChaseSpeed or 3) + (config.kfGravitySlowChase or 0.4)) * d
			local nextChaser  = Quat.slerp(kfState.gravityChaser, target, math.clamp(chaseT, 0, 1))
			local ok, nextRot = pcall(function()
				return nextChaser:inverse() * Quat.fromXZ(forward, nextChaser:rotateVector(Vec3.new(0, 0, 1)))
			end)
			if ok and nextRot then
				local e = nextRot:euler()
				kfState.freeCamPitch = e.y
				kfState.freeCamYaw   = e.z
			end
			kfState.gravityChaser = nextChaser
		end
	end

	if keyDown(Input.Key.SpaceBar) or keyDown(Input.Key.Space) or keyDown(Input.Gamepad.FaceButtonBottom) then
		kfState.gravityChaser = kfGravityUp()
		kfState.freeCamRoll   = 0
		kfState.freeCamLook.x = 0
	end

	kfState.freeCamRoll  = kfState.freeCamRoll  + nextLookDiff.x
	kfState.freeCamPitch = kfState.freeCamPitch + nextLookDiff.y
	kfState.freeCamYaw   = kfState.freeCamYaw   + nextLookDiff.z
	kfState.freeCamLook  = kfState.freeCamLook  - nextLookDiff
	kfState.freeCamPitch = math.clamp(kfState.freeCamPitch, -KF_PITCH_LIMIT, KF_PITCH_LIMIT)

	if Input.getKeyUp(Input.Key.RightMouseButton) or (rollGp == false and kfState.lastRollGp) then
		if (math.abs(kfState.freeCamRoll) % 360) <= (config.kfRollResetTol or 5) then
			kfState.freeCamRoll   = 0
			kfState.freeCamLook.x = 0
		end
	end
	kfState.lastRollGp = rollGp

	kfState.freeCamPos = kfState.freeCamPos + input * speed * d
	camPos    = kfState.freeCamPos
	camRot    = kfFreeCamWorldRot()
	camPosVel = Vec3.zeroVector
	targetFOV = kfState.freeCamFOV
	camBehavior = "FREECAM"
	camera.hideNearestHead = false
end

function kfPlaybackTick(d)
	local kfs = kfState.keyframes
	if #kfs < 2 then
		kfState.isPlaying = false
		return false
	end

	local speedMul = config.kfSpeedMultiplier or 1.0
	kfState.playbackTime = kfState.playbackTime + d * speedMul

	local tMin = kfs[1].time
	local tMax = kfs[#kfs].time

	if kfState.playbackTime > tMax then
		if config.kfLooping then
			kfState.playbackTime = tMin
		else
			kfState.playbackTime = tMax
			kfState.isPlaying = false
		end
	end

	local result = kfInterpolate(kfState.playbackTime)
	if not result then return false end

	camPos    = result.pos
	camRot    = result.rot
	targetFOV = result.fov
	camPosVel = Vec3.zeroVector
	camera.hideNearestHead = false
	camBehavior = "KEYFRAME_PLAY"

	if readLocation > 0 and result.replayTime then
		local r = Replay.getByIndex(readLocation)
		if r then pcall(function() r:setCurrentTime(result.replayTime) end) end
	end

	kfState.freeCamPos = result.pos
	kfSyncFreeCamFromRot(result.rot)
	kfState.freeCamFOV = result.fov

	return true
end

local function keyframeCam(d)
	if kfState.isPlaying then
		return kfPlaybackTick(d)
	end
	freeCamTick(d)
	return true
end

local function casterFreecamTick(d)
	local rotSpeed         = config.kfFreeCamRotSpeed or 180
	local mouseSensitivity = config.kfMouseSensitivity or 3.6
	local up = selectedArena and selectedArena.up or Vec3.new(0, 0, 1)

	local minS = config.kfMinMoveSpeed   or 50
	local maxS = config.kfMaxMoveSpeed   or 6000
	local rate = config.kfSpeedAdjustRate or 2.0
	local spd  = caster.speed or (config.kfFreeCamSpeed or 1600)
	if keyHeld(Input.Key.LeftShift) or keyHeld(Input.Key.RightShift)
		or keyHeld(Input.Gamepad.RightShoulder) then
		spd = spd * (1 + rate * d)
	elseif keyHeld(Input.Key.LeftControl) or keyHeld(Input.Key.RightControl)
		or keyHeld(Input.Gamepad.LeftShoulder) then
		spd = spd * (1 - rate * d)
	end
	caster.speed = math.clamp(spd, minS, maxS)

	local forward = camRot:getForwardVector()
	local right   = camRot:getRightVector()

	local input = Vec3.zeroVector
	if keyHeld(Input.Key.W) then input = input + forward end
	if keyHeld(Input.Key.S) then input = input - forward end
	if keyHeld(Input.Key.D) then input = input + right end
	if keyHeld(Input.Key.A) then input = input - right end
	if keyHeld(Input.Key.E) then input = input + up end
	if keyHeld(Input.Key.Q) then input = input - up end
	input = input + right   * Input.getAnalog(Input.Gamepad.LeftX)
	input = input + forward * Input.getAnalog(Input.Gamepad.LeftY)
	input = input + up * Input.getAnalog(Input.Gamepad.RightTriggerAxis)
	input = input - up * Input.getAnalog(Input.Gamepad.LeftTriggerAxis)

	caster.pos = caster.pos + input * caster.speed * d

	if caster.lookAtBall and selectedArena and selectedArena.ball then
		local ballPos = smoothBallPos
		local toBall  = ballPos - caster.pos
		if toBall:length() > 1 then
			local tgtRot = safeFromXZ(toBall:getSafeNormal(), up, camRot)
			camRot = dampQ(camRot, tgtRot, 10, d)
		end
		local e = camRot:euler()
		caster.pitch = math.clamp(e.y, -89, 89)
		caster.yaw   = e.z
		camBehavior = "CASTER_FREECAM_BALL"
	else
		local lookYaw, lookPitch = 0, 0
		local mouse = Input.getMouseDelta()
		if mouse and mouse.x then
			lookYaw   = lookYaw   + mouse.x * mouseSensitivity
			lookPitch = lookPitch + mouse.y * mouseSensitivity
		end
		if keyHeld(Input.Key.Right) then lookYaw   = lookYaw   + rotSpeed * d end
		if keyHeld(Input.Key.Left)  then lookYaw   = lookYaw   - rotSpeed * d end
		if keyHeld(Input.Key.Up)    then lookPitch = lookPitch + rotSpeed * d end
		if keyHeld(Input.Key.Down)  then lookPitch = lookPitch - rotSpeed * d end
		lookYaw   = lookYaw   + Input.getAnalog(Input.Gamepad.RightX) * rotSpeed * d
		lookPitch = lookPitch + Input.getAnalog(Input.Gamepad.RightY) * rotSpeed * d

		if caster.axisLock then lookPitch = 0 end

		caster.yaw   = caster.yaw + lookYaw
		caster.pitch = math.clamp(caster.pitch + lookPitch, -89, 89)
		camRot = Quat.fromEuler(0, caster.pitch, caster.yaw)
		camBehavior = caster.axisLock and "CASTER_FREECAM_LOCKED" or "CASTER_FREECAM"
	end

	camPos    = caster.pos
	camPosVel = Vec3.zeroVector
	targetFOV = caster.fov
	camera.hideNearestHead = false
end

local replay = {
	list          = {},
	selectedIndex = 0,
	arenaName     = "",
	homePlayers   = {},
	awayPlayers   = {},
	ballPos       = nil,
	isPlaying     = false,
	duration      = 0,
	currentTime   = 0,
}

local function resetGoalState()
	goalCelebration.isActive = false
	goalCelebration.goal = nil
	if selectedArena then
		selectedArena.goalScoredTime = 0
		selectedArena.goalScoredTeam = -1
		selectedArena.goalScoredGoal = nil
	end
end

local function refreshReplayFrame()
	if readLocation > 0 and readLocation <= #replay.list then
		local r = Replay.getByIndex(readLocation)
		if r then
			local okF, frame = pcall(function() return getFrame(readLocation) end)
			if okF and frame then
				local home, away = {}, {}
				if frame.players then
					for _, p in ipairs(frame.players) do
						if p.teamIndex == TI.Home and p.playerName and p.playerName ~= "" then
							home[#home+1] = p.playerName
						elseif p.teamIndex == TI.Away and p.playerName and p.playerName ~= "" then
							away[#away+1] = p.playerName
						end
					end
				end
				replay.homePlayers = home
				replay.awayPlayers = away
				if frame.balls then
					for i in pairs(frame.balls) do
						replay.ballPos = frame.balls[i].transform.position; break
					end
				end
			end
			local okD, dur = pcall(function() return r:getDuration() end)
			replay.duration = (okD and dur) or 0
			local okT, ct  = pcall(function() return r:getCurrentTime() end)
			local newTime = (okT and ct) or 0
			if replay.currentTime > newTime then resetGoalState() end
			replay.currentTime = newTime
			local okP, playing = pcall(function() return r:getIsPlaying() end)
			replay.isPlaying = (okP and playing) or false
		end
	else
		replay.homePlayers = {}
		replay.awayPlayers = {}
		replay.ballPos     = nil
		replay.isPlaying   = false
	end
end

local function updateReplayState()
	local ok, list = pcall(Replay.listLoaded)
	if not ok or not list then replay.list = {}; return end
	local oldListLen = #replay.list
	replay.list = list
	if #replay.list ~= oldListLen or (readLocation > 0 and readLocation <= #replay.list and Replay.getByIndex(readLocation) ~= replay.lastReplay) then
		resetGoalState()
	end
	refreshReplayFrame()
end

local function Input_decode(str)
	local kb = {}; if not str or str == "" then return kb end
	for fe in str:gmatch("{(.-:{.-}})}") do
		local key, content = fe:match("(.-):{(.*)}")
		if not key or not content then continue end
		local entry = {modifiers={}}
		entry.primary = Input.Key[content:match('primary:"([^"]+)"')]
			or Input.Gamepad[content:match('primary:"([^"]+)"')]
		for mod in (content:match("modifiers:{(.-)}") or ""):gmatch('"([^"]+)"') do
			local mk = Input.Key[mod] or Input.Gamepad[mod]
			if mk then table.insert(entry.modifiers, mk) end
		end
		kb[key] = entry
	end
	return kb
end

local function Input_bind(name, b)
	return {name=name, hotkey=b and b.primary or Input.Key.F1, modifiers=b and b.modifiers or {}}
end

local function Input_pressed(key)
	if not key or not key.hotkey then return false end
	if key.modifiers then
		for _, k in ipairs(key.modifiers) do
			if not Input.getKeyDown(k) and not Input.getKey(k) then return false end
		end
	end
	return Input.getKeyDown(key.hotkey)
end

local defKB = {
	mode1     = {primary=Input.Key.One,   modifiers={}},
	mode3     = {primary=Input.Key.Three, modifiers={}},
	mode4     = {primary=Input.Key.Seven, modifiers={}},
	mode5     = {primary=Input.Key.Eight, modifiers={}},
	mode6     = {primary=Input.Key.Nine,  modifiers={}},
	nextP     = {primary=Input.Key.D,     modifiers={}},
	prevP     = {primary=Input.Key.A,     modifiers={}},
	lock      = {primary=Input.Key.L,     modifiers={}},
	arena     = {primary=Input.Key.Enter, modifiers={}},
	nxtA      = {primary=Input.Key.E,     modifiers={}},
	prvA      = {primary=Input.Key.Q,     modifiers={}},
	toggleGui = {primary=Input.Key.Tab,   modifiers={}},
	kfAdd     = {primary=Input.Key.K,     modifiers={}},
}
local defGP = {
	nxtP ={primary=Input.Gamepad.RightShoulder, modifiers={}},
	prvP ={primary=Input.Gamepad.LeftShoulder,  modifiers={}},
	arena={primary=Input.Gamepad.Special_Right, modifiers={}},
	nxtA ={primary=Input.Gamepad.DPad_Right,    modifiers={}},
	prvA ={primary=Input.Gamepad.DPad_Left,     modifiers={}},
}

local kbB = Input_decode(config.keyboardKeybinds); if dictSize(kbB) == 0 then kbB = defKB end
local gpB = Input_decode(config.gamepadKeybinds);  if dictSize(gpB) == 0 then gpB = defGP end
local KB, GP = {}, {}
for k, v in pairs(defKB) do KB[k] = Input_bind(k, kbB[k] or v) end
for k, v in pairs(defGP) do GP[k] = Input_bind(k, gpB[k] or v) end

local function refresh(target)
	if not target or not selectedArena then return nil end
	for _, p in ipairs(selectedArena.players) do
		if p.playerId == target.playerId then return p end
	end
	return nil
end

local function smoothDirStable(cur, tgt, spd, d)
	local dot = Vec3.dot(cur, tgt)
	if dot < -0.999 then return tgt end
	local result = dampV(cur, tgt, spd, d)
	if result:length() > 0.001 then return result:getSafeNormal() end
	return tgt
end

-- Rate-limited direction smoothing (anti-whip). Used by BROADCAST so the
-- camera can never snap round the wrong way during fast passing.
local function smoothDirLimited(cur, tgt, spd, maxRate, d)
	local stepped = dampV(cur, tgt, spd, d)
	if stepped:length() > 0.001 then
		stepped = stepped:getSafeNormal()
	else
		stepped = tgt
	end
	if maxRate and maxRate > 0 then
		local maxStep = maxRate * d
		local dot = math.clamp(Vec3.dot(cur, stepped), -1, 1)
		local ang = math.acos(dot)
		if ang > maxStep and ang > 1e-5 then
			local t = maxStep / ang
			local v = cur * (1 - t) + stepped * t
			if v:length() > 0.001 then return v:getSafeNormal() end
		end
	end
	return stepped
end

local function spdToTime(spd) return 1 / math.max(spd, 0.05) end

local function applyCamPos(target, smoothTime, d)
	if config.useSpringSmoothing then
		local out, v = smoothDampVec(camPos, target, camPosVel, smoothTime, d)
		camPosVel = v
		return out
	end
	return dampV(camPos, target, 1 / math.max(smoothTime, 0.001), d)
end

local function findSafePosition(focusPoint, idealPos, up, right)
	local hit = camera:castRay(focusPoint, idealPos)
	if hit and hit.successful then
		local hitDist  = dist(focusPoint, hit.position)
		local safeDist = math.max(hitDist - config.bcCeilingBuffer, config.bcMinCamDist)
		return focusPoint + (idealPos - focusPoint):getSafeNormal() * safeDist
	end
	return idealPos
end

local function computeFollowPitch(target, up, currentPitch, d)
	local s = config.verticalCameraSmooth or 6
	if not config.verticalCameraEnabled or not target or not target.head then
		return damp(currentPitch, 0, s, d)
	end
	local headFwd  = target.head.rotation:getForwardVector()
	local maxRad   = math.rad(config.verticalCameraMaxAngle or 60)
	local rawPitch = math.asin(math.clamp(Vec3.dot(headFwd, up), -1, 1))
	rawPitch = math.clamp(rawPitch, -maxRad, maxRad)
	return damp(currentPitch, rawPitch, s, d)
end

local function applyPitch(flatDir, pitch, up)
	if math.abs(pitch) < 1e-4 then return flatDir end
	local v = flatDir * math.cos(pitch) + up * math.sin(pitch)
	if v:length() < 0.001 then return flatDir end
	return v:getSafeNormal()
end

local stats = {
	players          = {},
	lastToucher      = nil,
	lastToucherTeam  = {[TI.Home] = nil, [TI.Away] = nil},
	lastGoalTime     = -1,
}

local gameHistory = {}
local historyIndex = -1

local function copyStatsSnapshot()
	local copy = {}
	for name, s in pairs(stats.players) do
		copy[name] = {
			team = s.team,
			ballTime = s.ballTime,
			goals = s.goals,
		}
	end
	return copy
end

local function archiveCurrentGame()
	if not selectedArena then return end
	local hasData = false
	for _, s in pairs(stats.players) do
		if s.goals > 0 or s.ballTime > 0 then hasData = true; break end
	end
	if not hasData then return end
	local entry = {
		timestamp = totalTime,
		arenaName = selectedArena.name,
		homeScore = selectedArena.home.score,
		awayScore = selectedArena.away.score,
		players = copyStatsSnapshot(),
	}
	gameHistory[#gameHistory + 1] = entry
	historyIndex = -1
end

local function statsReset()
	stats.players      = {}
	stats.lastToucher  = nil
	stats.lastToucherTeam[TI.Home] = nil
	stats.lastToucherTeam[TI.Away] = nil
	stats.lastGoalTime = -1
end

local function onRoundEnd()
	if selectedArena and selectedArena.wasActive and not selectedArena.isActive then
		archiveCurrentGame()
		statsReset()
	end
end

local function statsGet(name, team)
	local s = stats.players[name]
	if not s then
		s = {team = team or -1, ballTime = 0, goals = 0}
		stats.players[name] = s
	end
	if team ~= nil and team ~= TI.None then s.team = team end
	return s
end

local function statsUpdate(d)
	local arena = selectedArena
	if not arena then return end

	for _, p in ipairs(arena.players) do
		local s = statsGet(p.playerName, p.teamIndex)
		if not s.team or s.team ~= p.teamIndex then s.team = p.teamIndex end
	end

	if possession.player and possession.timer > 0 then
		local p = possession.player
		local s = statsGet(p.playerName, p.teamIndex)
		s.ballTime = s.ballTime + d
		stats.lastToucher = p.playerName
	end

	if arena.goalScoredTime > 0 and arena.goalScoredTime ~= stats.lastGoalTime then
		stats.lastGoalTime = arena.goalScoredTime
		local scoringTeam = arena.goalScoredTeam
		local scorerName = stats.lastToucherTeam[scoringTeam]
		if scorerName then
			local s = statsGet(scorerName)
			if s.team == scoringTeam then
				s.goals = s.goals + 1
			end
		end
	end
end

-- name of whoever scored for `team` (last player on that team to have the ball), for goal FX
function PicklerScorerName(team)
	return stats.lastToucherTeam[team] or stats.lastToucher
end

local function ordinal(n)
	local suffix = "th"
	local tens = n % 100
	if tens < 11 or tens > 13 then
		local ones = n % 10
		if     ones == 1 then suffix = "st"
		elseif ones == 2 then suffix = "nd"
		elseif ones == 3 then suffix = "rd" end
	end
	return tostring(n) .. suffix
end

local function getSortedPlayersFromSnapshot(snapshotPlayers, arenaPlayers)
	local players = {}
	if not arenaPlayers then return players end
	local seen = {}
	for _, ap in ipairs(arenaPlayers) do
		local name = ap.playerName
		if name and name ~= "" and not seen[name] then
			seen[name] = true
			local s = snapshotPlayers and snapshotPlayers[name] or nil
			players[#players + 1] = {
				name     = name,
				team     = ap.teamIndex,
				goals    = (s and s.goals) or 0,
				ballTime = (s and s.ballTime) or 0,
			}
		end
	end
	table.sort(players, function(a, b)
		if a.goals ~= b.goals then return a.goals > b.goals end
		return a.ballTime > b.ballTime
	end)
	return players
end

local function getSortedPlayers()
	if historyIndex >= 0 and historyIndex <= #gameHistory then
		local hist = gameHistory[historyIndex + 1]
		if hist and selectedArena and selectedArena.name == hist.arenaName then
			return getSortedPlayersFromSnapshot(hist.players, selectedArena.players)
		else
			historyIndex = -1
		end
	end
	local players = {}
	if not selectedArena then return players end
	local seen = {}
	for _, ap in ipairs(selectedArena.players) do
		local name = ap.playerName
		if name and name ~= "" and not seen[name] then
			seen[name] = true
			local s = stats.players[name]
			players[#players + 1] = {
				name     = name,
				team     = ap.teamIndex,
				goals    = (s and s.goals) or 0,
				ballTime = (s and s.ballTime) or 0,
			}
		end
	end
	table.sort(players, function(a, b)
		if a.goals ~= b.goals then return a.goals > b.goals end
		return a.ballTime > b.ballTime
	end)
	return players
end

local function drawStatsHudContent()
	local sorted = getSortedPlayers()
	if #sorted == 0 then
		Gui.text("  (no players in arena)")
		return
	end
	Gui.text("  LEADERBOARD")
	for i, p in ipairs(sorted) do
		local teamTag = p.team == TI.Home and "[H] "
		            or  p.team == TI.Away and "[A] "
		            or  "[?] "
		Gui.text(string.format("  %-4s %s%s  -  %d goals  /  %.1fs",
			ordinal(i), teamTag, p.name, p.goals, p.ballTime))
	end
end

local function drawLeanIndicators()
	if not WorldDraw then return end
	if not config.showLeanIndicators then return end
	if not selectedArena then return end

	local arenaUp    = selectedArena.up
	local lineLength = config.leanLineLength or 30
	local sideOffset = config.leanSideOffset or 35
	local thickness  = config.leanLineThickness or 4
	local maxRad     = math.rad(math.max(5, config.leanMaxAngle or 45))

	local function gradeColor(amount)
		local r = math.clamp(amount * 2, 0, 1)
		local g = math.clamp(2 - amount * 2, 0, 1)
		return r, g, 0
	end

	for _, p in ipairs(selectedArena.players) do
		if p.head and p.head.position then
			local headPos = p.head.position
			local forward = p.head.rotation:getForwardVector()
			if forward:length() < 0.1 then forward = p.root.rotation:getForwardVector() end
			forward = flattenDir(forward, arenaUp) or selectedArena.forward

			local right = Vec3.cross(arenaUp, forward):getSafeNormal()
			local left  = -right

			local leanDot   = math.clamp(Vec3.dot(p.head.rotation:getLeftVector(), arenaUp), -1, 1)
			local leanAngle = math.asin(leanDot)
			local ratio     = math.clamp(math.abs(leanAngle) / maxRad, 0, 1)

			local leftAmount  = (leanAngle > 0) and ratio or 0
			local rightAmount = (leanAngle < 0) and ratio or 0

			local leftLen  = lineLength * (0.5 + 0.5 * leftAmount)
			local rightLen = lineLength * (0.5 + 0.5 * rightAmount)

			local rL, gL = gradeColor(leftAmount)
			local leftPos = headPos + left * sideOffset
			WorldDraw.drawLine(leftPos + arenaUp * 10, leftPos + arenaUp * (10 + leftLen),
				rL, gL, 0, thickness, 0)

			local rR, gR = gradeColor(rightAmount)
			local rightPos = headPos + right * sideOffset
			WorldDraw.drawLine(rightPos + arenaUp * 10, rightPos + arenaUp * (10 + rightLen),
				rR, gR, 0, thickness, 0)
		end
	end
end

-- ============================================================

local function buildArenas()
	local r = {}
	for _, gm in ipairs(SpectatorGamemodes.listGamemodes()) do
		local id = gm:getSlotId(); local typ = classifyArena(id)
		if typ then
			local p = presets[typ]
			r[id:gsub("TKB","")] = Arena.new(gm, readLocation, p[1],p[2],p[3],p[4],p[5],p[6],p[7])
		end
	end
	return r
end

local function selectArena(a)
	if not a then return end
	if selectedArena and selectedArena.name and a.name ~= selectedArena.name then
		curTarget = nil; possession.player = nil
		smoothBallPos = a.center; smoothBallVel = Vec3.zeroVector
		lockedDir = a.forward; smoothDir = a.forward; dirInitialized = false
		ballStationaryTimer = 0; isBallStationary = false
		playerFollow.targetPlayer    = nil
		playerFollow.isFollowing     = false
		playerFollow.smoothDir       = a.forward
		playerFollow.dirInitialized  = false
		playerFollow.smoothPitch     = 0
		goalCelebration.isActive = false
		kickoff.active = false; kickoff.angle = 0
		bcSmoothPitch = 0
		bcLeadSmooth  = 0
		bcCrowdSmooth = 0
		bcGoalSmooth  = 0
		bcGoalLastPos = nil
		autoFollow.smoothPitch = 0
		statsReset()
		resetBallTrail()
		historyIndex = -1
		caster.freecamActive = false
		caster.axisLock      = false
	end
	selectedArena = a
	for i, k in ipairs(arenaKeys) do if k == a.name then arenaIdx = i; break end end
end

local function cycleArena(dir)
	if not arenas or #arenaKeys == 0 then return end
	arenaIdx = ((arenaIdx - 1 + dir) % #arenaKeys) + 1
	local k = arenaKeys[arenaIdx]
	if k and arenas[k] then selectArena(arenas[k]) end
end

local function setReadLocation(loc)
	if readLocation == loc then return end
	readLocation = loc
	curTarget         = nil
	possession.player = nil
	possession.timer  = 0
	statsReset()
	historyIndex = -1
	caster.freecamActive = false
end

local function rebuildServerPlayerList()
	allServerPlayers = {}
	if not arenas then return end
	local seen, sorted = {}, {}
	for k in pairs(arenas) do sorted[#sorted+1] = k end
	table.sort(sorted)
	for _, aKey in ipairs(sorted) do
		local a = arenas[aKey]
		if a and a.players then
			for _, p in ipairs(a.players) do
				if not seen[p.playerName] then
					seen[p.playerName] = true
					allServerPlayers[#allServerPlayers+1] = {
						player=p, arena=a, arenaName=a.name, teamIndex=p.teamIndex,
					}
				end
			end
		end
	end
end

local function scanForAutoFollowTarget()
	if not arenas or not autoFollow.enabled then
		autoFollow.foundPlayer=nil; autoFollow.foundArena=nil
		autoFollow.isInArena=false; autoFollow.isActive=false; return
	end
	local targetName = autoFollow.targetName
	for _, a in pairs(arenas) do
		for _, p in ipairs(a.players) do
			if p.playerName == targetName then
				autoFollow.foundPlayer=p; autoFollow.foundArena=a
				autoFollow.isInArena=true; autoFollow.isActive=true
				if not selectedArena or selectedArena.name ~= a.name then selectArena(a) end
				return
			end
		end
	end
	local frame = getFrame(readLocation)
	if frame and frame.players then
		for _, p in ipairs(frame.players) do
			if p.playerName == targetName then
				autoFollow.foundPlayer=p; autoFollow.foundArena=nil
				autoFollow.isInArena=false; autoFollow.isActive=true; return
			end
		end
	end
	autoFollow.foundPlayer=nil; autoFollow.foundArena=nil
	autoFollow.isInArena=false; autoFollow.isActive=false
end

local function autoFollowFreeCam(d)
	local p = autoFollow.foundPlayer; if not p then return false end
	local up = p.root.rotation:getUpVector()
	local forward = p.root.rotation:getForwardVector()
	local anchor = Vec3.lerp(p.root.position, p.head.position, 0.4)

	local flatForward = flattenDir(forward, up) or forward
	if not autoFollow.dirInitialized then
		autoFollow.smoothDir = flatForward; autoFollow.dirInitialized = true
	end
	autoFollow.smoothDir = smoothDirStable(autoFollow.smoothDir, flatForward, 2.5, d)

	autoFollow.smoothPitch = computeFollowPitch(p, up, autoFollow.smoothPitch or 0, d)
	local pitchedDir = applyPitch(autoFollow.smoothDir, autoFollow.smoothPitch, up)

	local behindDir = pitchedDir * -1
	local idealPos  = anchor + behindDir * config.autoFollowDist + up * config.autoFollowHeight
	local hit = camera:castRay(anchor, idealPos)
	if hit and hit.successful then
		local safeDist = math.max(dist(anchor, hit.position) - 30, 150)
		idealPos = anchor + (idealPos - anchor):getSafeNormal() * safeDist
	end
	local lookDir = ((anchor + pitchedDir * 80) - idealPos):getSafeNormal()
	local tgtRot  = safeFromXZ(lookDir, up, camRot)
	camPos = applyCamPos(idealPos, spdToTime(config.autoFollowPosSmooth), d)
	camRot = dampQ(camRot, tgtRot, config.autoFollowRotSmooth, d)
	targetFOV = config.autoFollowFOV
	camera.hideNearestHead = false
	camBehavior = "AUTOFOLLOW:FREE"
	return true
end

local function updatePossession(players, bp, d)
	if not selectedArena or not selectedArena.ball then
		possession.player=nil; possession.timer=0; return
	end
	local cd, cp = math.huge, nil
	for _, p in ipairs(players) do
		local root = p.root; local hp = p.head.position
		local lp = root.rotation:rotateVector(p.leftHand.position)  + root.position
		local rp = root.rotation:rotateVector(p.rightHand.position) + root.position
		local dd = math.min(dist(bp, hp), dist(bp, lp), dist(bp, rp))
		if dd < cd then cd = dd; cp = p end
	end
	if cd < 130 and cp then
		if possession.player and possession.player.playerId == cp.playerId then
			possession.timer = possession.timer + d
		else
			possession.player = cp
			possession.timer  = 0
			possession.team   = cp.teamIndex
			stats.lastToucherTeam[cp.teamIndex] = cp.playerName
		end
	else
		possession.timer = math.max(0, possession.timer - d * 2)
		if possession.timer <= 0 then
			possession.player = nil
			possession.team   = -1
		end
	end
end

local function updateBallSmooth(d)
	if not selectedArena then return end
	local rawPos, rawVel
	if selectedArena.ball then
		rawPos = selectedArena.ball.transform.position
		rawVel = selectedArena.ball.velocity or Vec3.zeroVector
	else
		rawPos = smoothBallPos; rawVel = smoothBallVel
	end
	smoothBallPos = dampV(smoothBallPos, rawPos, 12, d)
	smoothBallVel = dampV(smoothBallVel, rawVel,  8, d)
	local ballSpeed = smoothBallVel:length()
	if ballSpeed < config.bcBallStationaryThreshold then
		ballStationaryTimer = ballStationaryTimer + d
		isBallStationary    = ballStationaryTimer >= config.bcBallIdleTime
	else
		ballStationaryTimer = 0; isBallStationary = false
	end
end

local function updateGoalCelebration(d)
	if not selectedArena or not config.bcGoalCamEnabled then goalCelebration.isActive=false; return end
	local timeSinceGoal = totalTime - selectedArena.goalScoredTime
	if timeSinceGoal < config.bcGoalCelebrationTime and selectedArena.goalScoredGoal then
		if not goalCelebration.isActive then
			goalCelebration.isActive  = true
			goalCelebration.startTime = totalTime
			goalCelebration.goal      = selectedArena.goalScoredGoal
		end
	else
		goalCelebration.isActive = false
	end
end

local function ensureTarget()
	if curTarget then curTarget = refresh(curTarget) end
	if not curTarget and selectedArena and #selectedArena.players > 0 then
		curIdx = 1; curTarget = selectedArena.players[1]
	end
	return curTarget ~= nil
end

-- =====================================================================================
-- PLAYER VIEWS: first person and third person, adapted from dennssen's Follow+ (credited).
-- With Follow+ installed the camera is handed to it each frame, the way Plutus' autocaster does,
-- and always released with followCamera(nil) when the view ends so every other camera keeps
-- working. Without it, first person is a built-in copy of Follow+'s firstPerson(), and third
-- person is Pickler's own chase camera.
-- =====================================================================================
PICKLER_FOLLOW={cam=nil,tick=nil,tried=false,active=false,wasActive=false}

function PicklerFollowInit()
	local F=PICKLER_FOLLOW
	if not F.tried then
		F.tried=true
		pcall(function()
			F.cam=getCameraById("dennssen.followpluss")
			if F.cam then
				sendMessage(F.cam,{getMainProcessCallback=function(fn) F.tick=fn end})
			end
		end)
	end
	return F.cam~=nil and F.tick~=nil
end

function PicklerFollowHandOff(player,cameraMode,fov,d)
	local F=PICKLER_FOLLOW
	if config.followEngine==2 or not player or not PicklerFollowInit() then return false end
	local ok=pcall(function()
		sendMessage(F.cam,{readLocation=readLocation,showNameTags=true,muteSelf=false,isBallOutlineEnabled=false,
			targetPlayer=player,cameraFOV=fov,cameraMode=cameraMode,radius=config.followRadius or 20,threshold=5,
			positionSmoothing=config.followPosSmooth or .1,cameraPositionOffset=Vec3.zeroVector,
			cameraRotationOffset=Quat.identity,gestureControls=false,autoBall=false,autoGoalCam=false,showQuests=false,
			autoRecordReplays=false,mouseSensitivity=1,controllerSensitivity=1,controllerDeadzone=.1})
		F.tick(d,camera)
		camera:followCamera(F.cam)
		camera.hideNearestHead=cameraMode==1   -- first person sits inside the player's head, so hide it
		camPos=camera.position
		camRot=camera.rotation
	end)
	if not ok then return false end
	camPosVel=Vec3.zeroVector
	targetFOV=fov
	camFOV=fov
	modeBlend.active=false
	F.active=true
	return true
end

-- once a frame after the camera modes: hand the camera back as soon as no mode is using Follow+
function PicklerFollowEnd()
	local F=PICKLER_FOLLOW
	if F.wasActive and not F.active then
		pcall(function() camera:followCamera(nil) end)
		pcall(function()
			camPos=F.cam:getSmoothedPosition()
			camRot=F.cam:getSmoothedRotation()
		end)
		camera.hideNearestHead=false
	end
	F.wasActive=F.active
end

-- Follow+'s firstPerson(): exactly at the head (the 0.01 stops the mic being muffled), head hidden
function PicklerBuiltInFirstPerson(player,fov,d)
	local rot=player.head.rotation
	camPos=player.head.position+rot:rotateVector(Vec3.new(.01,0,0))
	camPosVel=Vec3.zeroVector
	modeBlend.active=false
	camRot=dampQ(camRot,rot,18,d)
	targetFOV=fov
	camera.hideNearestHead=true
end

-- PLAYER tab views. Returns false to let the normal chase camera (playerFollowCam) run.
function PicklerPlayerViewTick(d)
	if not selectedArena or not playerFollow.enabled then return false end
	local view=config.pfView or 1
	local style=config.pfThirdStyle or 1
	if view==1 and style==1 then return false end
	local target=nil
	for _,p in ipairs(selectedArena.players) do
		if p.playerName==playerFollow.targetName then target=p; break end
	end
	if not target or not target.head or not target.root then return false end
	playerFollow.targetPlayer=target
	playerFollow.isFollowing=true
	if view==2 then
		local fov=config.firstPersonFOV or 110
		if not PicklerFollowHandOff(target,1,fov,d) then PicklerBuiltInFirstPerson(target,fov,d) end
		camBehavior="PLAYER_FP"
		return true
	end
	-- Follow+'s third person modes: 2 head rotation, 3 velocity, 4 face the ball
	if PicklerFollowHandOff(target,style,config.tpFOV or 90,d) then
		camBehavior="PLAYER_TP"
		return true
	end
	return false
end

-- switch view with a short ease so it doesn't read as a hard cut
function PicklerSetPlayerView(view)
	if (config.pfView or 1)==view then return end
	config.pfView=view
	modeBlend.active=true
	modeBlend.t=0
	modeBlend.dur=math.max(config.camBlendDuration or .4,0)
	modeBlend.pos=camPos
	modeBlend.rot=camRot
	modeBlend.fov=camFOV
	camPosVel=Vec3.zeroVector
end

local function fpCam(d)
	if not ensureTarget() then return false end
	local p = curTarget
	if not p or not p.head then return false end
	if PicklerFollowHandOff(p, 1, config.firstPersonFOV or 110, d) then
		camBehavior = "FP"
		return true
	end
	local rot = p.head.rotation
	camPos = p.head.position + rot:rotateVector(Vec3.new(0.01, 0, 0))
	camPosVel = Vec3.zeroVector
	camRot = dampQ(camRot, rot, 22, d)
	targetFOV = config.firstPersonFOV
	camera.hideNearestHead = true
	camBehavior = "FP"
	return true
end

-- =====================================================================================
-- YUKI CAMERA (camera style 3): an automatic sideline dolly camera, ported from Yuki's
-- sideline cam script. It slides along the side of the arena at the ball's length position,
-- stays a set height above the ball, looks at the ball (with a little lead), zooms so the ball
-- stays the same size on screen, switches sides when the ball crosses over, pulls in at the
-- endzones, and uses a fixed corner camera while the ball is in the 4v4 sewer.
-- Distances are the 4v4 values and are scaled to the arena size from the goal distance.
-- =====================================================================================
YUKI_STATE={side=1,sewerTimer=0,sewerPos=nil,inSewer=false,lastT=nil,snapNext=false,postFx=false}

-- Yuki's camera look (low bloom, slightly darker exposure), only while the Yuki camera is in use.
-- Resets the post-process once when it stops, so other mods' settings aren't stomped every frame.
function yukiPostFxTick()
	local want=config.yukiPostFx and (config.camProfile or 1)==3 and PicklerCasterMode=="caster"
	if want then
		pcall(function()
			postProcessSettings.bloomIntensity=0.01
			postProcessSettings.autoExposureBias=-0.001
		end)
		YUKI_STATE.postFx=true
	elseif YUKI_STATE.postFx then
		pcall(function() postProcessSettings:reset() end)
		YUKI_STATE.postFx=false
	end
end

function yukiCam(d)
	local arena=selectedArena
	if not arena then return false end
	camera.hideNearestHead=false
	camBehavior="YUKI"
	local ball=arena.ball
	if not ball then return true end
	local S=YUKI_STATE
	local u=arena.up:getSafeNormal()
	-- The goals sit along the arena's local Y axis (arena.right), so that is the field LENGTH.
	-- Width is the other horizontal axis, built the same way as the original Yuki script
	-- (length x up). Origin is the arena transform, like the original, not the box center.
	local fwd=arena.right:getSafeNormal()
	local rgt=fwd:cross(u):getSafeNormal()
	local origin=arena.transform.position
	local ballPos=ball.transform.position
	local ballVel=ball.velocity or Vec3.zeroVector

	local gd=4050
	if arena.home.goal and arena.home.goal.position then gd=dist(arena.home.goal.position,origin) end
	local k=math.clamp(gd/4050,.5,2.5)

	local rel=ballPos-origin
	local bw=Vec3.dot(rel,rgt)
	local bl=Vec3.dot(rel,fwd)
	local bh=Vec3.dot(rel,u)

	local inSewer=false
	if config.yukiSewerCam~=false and k>.85 and k<1.15 then
		inSewer=(math.abs(bw)<=850 and math.abs(bl)<=1096 and bh<=147)
	end
	local snap=(inSewer~=S.inSewer)
	S.inSewer=inSewer
	-- cut straight to the sideline when Yuki takes over (or a manual side switch), instead of
	-- flying across the arena from wherever the last camera was
	if not S.lastT or totalTime-S.lastT>.3 or S.snapNext then snap=true end
	S.lastT=totalTime
	S.snapNext=false

	local dollyPos
	if inSewer then
		S.sewerTimer=math.max(0,S.sewerTimer-d)
		local best,bd=nil,-1
		for _,sx in ipairs({1,-1}) do
			for _,sy in ipairs({1,-1}) do
				local p=origin+rgt*(842.255*sx)+fwd*(487.982*sy)+u*133.541
				local dd=dist(ballPos,p)
				if dd>bd then bd=dd; best=p end
			end
		end
		if not S.sewerPos then S.sewerPos=best end
		if S.sewerTimer<=0 and dist(best,S.sewerPos)>.1 then
			S.sewerPos=best
			S.sewerTimer=3.0
		end
		dollyPos=S.sewerPos
	else
		-- switch to the other sideline when the ball crosses over
		if config.yukiAutoSwitch~=false then
			local sw=(config.yukiSwitchWidth or 1000)*k
			if (S.side==1 and bw<-sw) or (S.side==-1 and bw>sw) then
				S.side=-S.side
				if config.yukiInstantSwitch~=false then snap=true end
			end
		end
		local sl=(config.yukiRailLength or 4000)*k
		local hookX,hookY=0,0
		if config.yukiHookEnabled~=false then
			-- endzone hook: past the quarter line the camera pulls back (Y) and in toward the middle (X)
			local q=sl/2
			local ab=math.abs(bl)
			if ab>q then
				local past=ab-q
				hookY=(config.yukiHookY or 1.4)*1e-4*past*past/k
				hookX=(config.yukiHookX or 0)*1e-4*past*past/k
			end
		end
		local ySign=(bl>=0) and 1 or -1
		local dw=S.side*((config.yukiSideDist or 2093)*k-hookX)
		local dl=math.clamp(bl,-sl,sl)-hookY*ySign
		local riser=0
		if config.yukiRiser then riser=.5e-4*bl*bl/k end   -- Yuki's endzone riser: climb near the goals
		local dh=math.clamp(bh+(config.yukiHeightOffset or 200)+riser,-85,(config.yukiMaxHeight or 1329)*math.max(k,1))
		dollyPos=origin+rgt*dw+fwd*dl+u*dh

		-- never let the camera sink into the floor
		local hit=nil
		pcall(function()
			local startAbs=Vec3.dot(origin+u*463.697,u)
			local curAbs=Vec3.dot(dollyPos,u)
			local rayStart=dollyPos+u*(startAbs-curAbs)
			hit=camera:castRay(rayStart,dollyPos-u*5000)
		end)
		if hit and hit.successful then
			local minSafe=Vec3.dot(hit.position+u*10,u)
			local cur=Vec3.dot(dollyPos,u)
			if cur<minSafe then dollyPos=dollyPos+u*(minSafe-cur) end
		end
	end

	-- aim at the ball with a little lead (a plain look when cutting)
	local rotS=config.yukiRotSmooth or .3
	local aimPoint=ballPos
	if rotS>0 and not snap then aimPoint=ballPos+ballVel*.45 end
	local lookDir=(aimPoint-dollyPos):getSafeNormal()
	local tgtRot=safeFromXZ(lookDir,u,camRot)

	-- auto zoom: keep the ball a steady size on screen
	local fov=config.yukiFOV or 60
	if config.yukiZoomEnabled~=false then
		local dd=dist(ballPos,camPos)
		if dd>1 then
			local frac=math.clamp(config.yukiZoomSize or .035,.001,.95)
			fov=math.clamp(math.deg(2*math.atan(40/(frac*dd))),1,170)
		end
	end

	if snap then
		camPos=dollyPos
		camRot=tgtRot
	else
		camPos=dampV(camPos,dollyPos,1/math.max(config.yukiPosSmooth or .3,.02),d)
		camRot=dampQ(camRot,tgtRot,1/math.max(rotS,.02),d)
	end
	camFOV=damp(camFOV,fov,1/math.max(config.yukiFovSmooth or .05,.02),d)
	targetFOV=camFOV
	return true
end

-- =====================================================================================
-- PLUTUS CAMERA (camera style 1): ported from Plutus' autocaster ("Plutus worst autocaster EU").
-- Orbits round to sit behind the ball's direction of travel, pulls back and up with ball speed
-- and with how spread out the players are, tightens up near a goal, and pushes itself out of
-- walls and away from players that would block the view. The orbit runs in the arena's own
-- plane, so it also works on the tilted arenas (the original used world X/Y).
-- =====================================================================================
PLUTUS_STATE={init=false,arena=nil,lastT=-1,sbp=Vec3.zeroVector,sbv=Vec3.zeroVector,orbit=0,orbitVel=0,
	dist=220,height=120,colOff=Vec3.zeroVector,colVel=Vec3.zeroVector,rayOff=Vec3.zeroVector,rayVel=Vec3.zeroVector}

function plutusReset()
	local S=PLUTUS_STATE
	S.init=false
	S.colOff,S.colVel,S.rayOff,S.rayVel=Vec3.zeroVector,Vec3.zeroVector,Vec3.zeroVector,Vec3.zeroVector
end

-- ray cast that never throws; returns the hit only when it hit something
function plutusRay(a,b)
	local ok,hit=pcall(function() return camera:castRay(a,b) end)
	if ok and hit and hit.successful then return hit end
	return nil
end

-- springs the camera off nearby walls and keeps the ball in line of sight
function plutusAvoidCollision(desiredPos,lookTarget,up,dt)
	local S=PLUTUS_STATE
	if not config.plCollision then
		S.colOff=dampV(S.colOff,Vec3.zeroVector,15,dt)
		S.colVel=Vec3.zeroVector
		return desiredPos+S.colOff
	end
	local strength=config.plCollisionStrength or 1
	local avoidRadius=config.plCollisionRadius or 80
	local camToTarget=(lookTarget-desiredPos):getSafeNormal()
	local worldUp=up:getSafeNormal()
	local right=Vec3.cross(camToTarget,worldUp):getSafeNormal()
	if right:length()<.01 then right=Vec3.new(1,0,0) end
	local upPerp=Vec3.cross(right,camToTarget):getSafeNormal()
	local dirs={right,right*-1,upPerp,upPerp*-1,
		(right+upPerp):getSafeNormal(),(right-upPerp):getSafeNormal(),
		(upPerp-right):getSafeNormal(),((right+upPerp)*-1):getSafeNormal(),
		worldUp,worldUp*-1,camToTarget,camToTarget*-1,
		(right*.5+worldUp):getSafeNormal(),(worldUp-right*.5):getSafeNormal()}
	local total=Vec3.zeroVector
	local anyHit=false
	for _,dir in ipairs(dirs) do
		local hit=plutusRay(desiredPos,desiredPos+dir*avoidRadius)
		if hit then
			local dd=dist(desiredPos,hit.position)
			if dd<avoidRadius then
				anyHit=true
				local t=1-math.clamp(dd/avoidRadius,0,1)
				total=total+hit.normal:getSafeNormal()*(t*t*t*avoidRadius*3.5*strength)
			end
		end
	end
	local los=plutusRay(lookTarget+worldUp*12,desiredPos)
	if los then
		local dHit=dist(lookTarget,los.position)
		local dCam=dist(lookTarget,desiredPos)
		if dHit<dCam-8 then
			total=total+(lookTarget-desiredPos):getSafeNormal()*((dCam-dHit+40)*strength*2.5)
			anyHit=true
		end
	end
	local target=Vec3.zeroVector
	if anyHit then
		target=total
		local maxOff=avoidRadius*strength*1.5
		if target:length()>maxOff then target=target:getSafeNormal()*maxOff end
	end
	local kS=anyHit and 30*strength or 0
	local kD=anyHit and 6 or 18
	S.colVel=S.colVel+(target-S.colOff)*(kS*dt)
	S.colVel=S.colVel*math.max(0,1-kD*dt)
	S.colOff=S.colOff+S.colVel*dt
	if not anyHit then
		S.colOff=dampV(S.colOff,Vec3.zeroVector,10,dt)
		S.colVel=dampV(S.colVel,Vec3.zeroVector,10,dt)
	end
	local finalPos=desiredPos+S.colOff
	local fh=plutusRay(lookTarget+worldUp*8,finalPos)
	if fh then
		local dFH=dist(lookTarget,fh.position)
		if dFH<dist(lookTarget,finalPos)-5 then
			finalPos=lookTarget+(finalPos-lookTarget):getSafeNormal()*math.max(dFH-15,10)
			S.colOff=finalPos-desiredPos
			S.colVel=Vec3.zeroVector
		end
	end
	return finalPos
end

-- lifts (or drops) the camera when something blocks its view of the nearest player or the ball
function plutusPlayerRay(desiredPos,playerPos,ballPos,worldUp,dt)
	local S=PLUTUS_STATE
	if not config.plPlayerRay then
		S.rayOff=dampV(S.rayOff,Vec3.zeroVector,12,dt)
		S.rayVel=Vec3.zeroVector
		return desiredPos+S.rayOff
	end
	local strength=config.plPlayerRayStrength or 1.2
	local upOff=config.plPlayerRayUp or 25
	local targets={}
	if playerPos then
		targets[#targets+1]=playerPos
		targets[#targets+1]=playerPos-worldUp*20
	end
	if ballPos then targets[#targets+1]=ballPos end
	local total=Vec3.zeroVector
	local anyHit=false
	for _,tgt in ipairs(targets) do
		local main=plutusRay(desiredPos,tgt)
		if main then
			local dCam=dist(desiredPos,tgt)
			local dHit=dist(desiredPos,main.position)
			if dHit<dCam-10 then
				anyHit=true
				local nrm=main.normal:getSafeNormal()
				local overStart,overEnd=desiredPos+worldUp*upOff,tgt+worldUp*upOff
				local over=plutusRay(overStart,overEnd)
				local overClear=(not over) or dist(overStart,over.position)>dist(overStart,overEnd)-5
				local underStart,underEnd=desiredPos-worldUp*(upOff*.5),tgt-worldUp*(upOff*.5)
				local under=plutusRay(underStart,underEnd)
				local underClear=(not under) or dist(underStart,under.position)>dist(underStart,underEnd)-5
				local pushDir
				if overClear and (Vec3.dot(nrm,worldUp)>=-.1 or not underClear) then
					pushDir=worldUp
				elseif underClear then
					pushDir=worldUp*-1
				else
					pushDir=(nrm+worldUp*.5):getSafeNormal()
				end
				local t=math.clamp((dCam-dHit)/math.max(dCam,1),0,1)
				total=total+pushDir*(t*t*upOff*4*strength)
			end
		end
		local back=plutusRay(tgt,desiredPos)
		if back then
			local dTotal=dist(tgt,desiredPos)
			local dBack=dist(tgt,back.position)
			if dBack<dTotal-10 then
				anyHit=true
				local pushDir=(Vec3.dot(back.normal:getSafeNormal(),worldUp)>=0) and worldUp or worldUp*-1
				local t=math.clamp(1-dBack/math.max(dTotal,1),0,1)
				total=total+pushDir*(t*t*upOff*3*strength)
			end
		end
	end
	local maxOff=upOff*strength*2.5
	if total:length()>maxOff then total=total:getSafeNormal()*maxOff end
	local kS=anyHit and 22*strength or 0
	local kD=anyHit and 5 or 14
	S.rayVel=S.rayVel+(total-S.rayOff)*(kS*dt)
	S.rayVel=S.rayVel*math.max(0,1-kD*dt)
	S.rayOff=S.rayOff+S.rayVel*dt
	if not anyHit then
		S.rayOff=dampV(S.rayOff,Vec3.zeroVector,9,dt)
		S.rayVel=dampV(S.rayVel,Vec3.zeroVector,9,dt)
	end
	return desiredPos+S.rayOff
end

function plutusCam(d)
	local arena=selectedArena
	if not arena then return false end
	-- left on through a dribble: switching it off and on each frame would show the head
	if not (PLUTUS_STATE.dribbling and config.plDribbleFP~=false) then camera.hideNearestHead=false end
	camBehavior="PLUTUS"
	local ball=arena.ball
	if not ball then return true end
	local S=PLUTUS_STATE
	local up=arena.up:getSafeNormal()
	local af=arena.forward:getSafeNormal()
	local ar=arena.right:getSafeNormal()
	local bp=ball.transform.position
	local bv=ball.velocity or Vec3.zeroVector
	-- (re)start cleanly on a new arena or after another camera has been running
	if S.arena~=arena or totalTime-S.lastT>.5 then S.init=false end
	S.arena=arena
	S.lastT=totalTime
	if not S.init then
		S.init=true
		S.sbp,S.sbv=bp,bv
		S.dist,S.height=config.plDistBase or 220,config.plHeightBase or 120
		-- start the orbit on the camera's current side of the ball so it doesn't swing round
		local rel=camPos-bp
		S.orbit=math.atan2(Vec3.dot(rel,ar),Vec3.dot(rel,af))
		S.orbitVel=0
	end
	S.sbp=dampV(S.sbp,bp,12,d)
	S.sbv=dampV(S.sbv,bv,8,d)
	local spd=S.sbv:length()
	local lookTarget=S.sbp+S.sbv:getSafeNormal()*math.min(spd*(config.plLead or .4)*.15,150)

	-- orbit round toward the spot behind where the ball is heading
	local dir=(spd<80) and ar or S.sbv
	local fx,fy=Vec3.dot(dir,af),Vec3.dot(dir,ar)
	if math.abs(fx)+math.abs(fy)<.001 then fx,fy=1,0 end
	local ad=math.atan2(fy,fx)+math.pi-S.orbit
	while ad>math.pi do ad=ad-2*math.pi end
	while ad< -math.pi do ad=ad+2*math.pi end
	S.orbitVel=damp(S.orbitVel,ad*(config.plOrbitBias or .6)*2,4,d)
	S.orbit=S.orbit+S.orbitVel*d

	-- distance and height: further and higher with ball speed and player spread,
	-- closer and higher right by a goal
	local td,th=config.plDistBase or 220,config.plHeightBase or 120
	local sf=math.clamp(bv:length()/1500,0,1)
	td=td+sf*(config.plDistSpeedBonus or 120)
	th=th+sf*(config.plHeightSpeedBonus or 60)
	local players=arena.players
	local nearHead,nearD=nil,math.huge
	if #players>0 then
		local tot=0
		for _,p in ipairs(players) do
			local dd=dist(p.root.position,bp)
			tot=tot+dd
			if dd<nearD then nearD=dd; nearHead=p.head.position end
		end
		local spread=math.clamp(tot/#players/1000,0,1)
		td=td+spread*(config.plDistSpreadBonus or 80)
		th=th+spread*(config.plHeightSpreadBonus or 45)
	end
	local gd=math.min(dist(bp,arena.home.goal.position),dist(bp,arena.away.goal.position))
	if gd<400 then
		local gf=1-gd/400
		td=td-gf*(config.plDistGoalPenalty or 60)
		th=th+gf*(config.plHeightGoalBonus or 30)
	end
	td=math.clamp(td,0,config.plDistMax or 1500)
	th=math.clamp(th,0,config.plHeightMax or 1000)
	S.dist=damp(S.dist,td,3,d)
	S.height=damp(S.height,th,3,d)

	local rawPos=lookTarget+(af*math.cos(S.orbit)+ar*math.sin(S.orbit))*S.dist+up*S.height
	local autoPos=plutusPlayerRay(plutusAvoidCollision(rawPos,lookTarget,up,d),nearHead,lookTarget,up,d)
	local tgtRot=safeFromXZ((lookTarget+up*10-autoPos):getSafeNormal(),up,camRot)
	local sm=config.plSmooth or 8

	-- First person on dribble, with the timing and exit rules of Plutus' script: held = a head or
	-- hand within 27 of the ball, or nearest within 70; leaves once someone else is nearest and the
	-- ball is 200 away, or 100 away and flying off. Head look goes through Follow+ like the PLAYER
	-- tab's first person.
	local function nearestTo(maxD)
		local cd,cp=maxD,nil
		for _,p in ipairs(players) do
			local root=p.root
			local lp=root.rotation:rotateVector(p.leftHand.position)+root.position
			local rp=root.rotation:rotateVector(p.rightHand.position)+root.position
			local dd=math.min(dist(bp,p.head.position),dist(bp,lp),dist(bp,rp))
			if dd<cd then cd=dd; cp=p end
		end
		return cp
	end
	local near=nearestTo(70)
	if near then
		if S.drib and S.drib.playerId==near.playerId then S.dribT=(S.dribT or 0)+d
		else S.drib=near; S.dribT=0 end
	else
		S.dribT=math.max(0,(S.dribT or 0)-d*4)
		if S.dribT<=0 then S.drib=nil end
	end
	if S.drib and S.dribT>=(config.plDribbleHold or 1) then S.dribbling=true
	elseif (S.dribT or 0)<.2 then S.dribbling=false end
	if S.dribbling and S.drib and config.plDribbleFP~=false then
		local dr=refresh(S.drib)
		if dr then
			local ballDist=dist(dr.root.position,bp)
			local leaving=false
			if not (near and near.playerId==dr.playerId) then
				if ballDist>200 then leaving=true
				elseif ballDist>100 and bv:length()>500 and Vec3.dot(bv:getSafeNormal(),(bp-dr.root.position):getSafeNormal())>.5 then leaving=true end
			end
			if leaving then
				S.dribbling=false
				S.dribT=0
			else
				local fov=config.plFirstPersonFOV or 110
				local look=config.plDribbleLook or 1
				camBehavior="PLUTUS_FP"
				local rot=dr.head.rotation
				if look==2 then rot=dr.root.rotation
				elseif look==3 then
					local tb=(bp-dr.head.position):getSafeNormal()
					if tb:length()>.01 then rot=Quat.fromXZ(tb,dr.root.rotation:getUpVector()) end
				end
				camPos=dr.head.position
				camPosVel=Vec3.zeroVector
				camRot=dampQ(camRot,rot,18,d)
				targetFOV=fov
				camera.hideNearestHead=true
				return true
			end
		end
	end
	camera.hideNearestHead=false
	camPos=dampV(camPos,autoPos,sm,d)
	camRot=dampQ(camRot,tgtRot,sm*1.2,d)
	targetFOV=math.clamp((config.plBaseFOV or 90)+math.clamp(spd/2000,0,1)*15,65,120)
	return true
end

-- =====================================================================================
-- SNOWMAN CAMERA (camera style 4): ported from Snowman's CastCam (by Snoowman & nikita.26).
-- Auto mode: while someone has the ball the camera sits behind and above them looking at their
-- head; otherwise it chases from behind the ball's direction of travel, looking a little ahead.
-- Ball mode always chases the ball; Player mode stays on the ball carrier when there is one.
-- Added over the original: the chase direction is smoothed so bounces don't whip the camera
-- round, rotation is damped, the carrier is held for a short buffer after contact (like the
-- original), and the camera is kept out of walls.
-- =====================================================================================
SNOWMAN_STATE={holder=nil,since=99,dir=nil,lastT=-1}

function snowmanCam(d)
	local arena=selectedArena
	if not arena then return false end
	camera.hideNearestHead=false
	camBehavior="SNOWMAN"
	local ball=arena.ball
	if not ball then return true end
	local S=SNOWMAN_STATE
	local up=arena.up:getSafeNormal()
	local bp=ball.transform.position
	local vel=ball.velocity or Vec3.zeroVector
	local cd,ch=config.snDist or 300,config.snHeight or 200
	local snap=totalTime-S.lastT>.5
	S.lastT=totalTime
	-- who has the ball (kept for a short buffer after the last contact)
	if possession.player and possession.timer>0 then
		S.holder=possession.player
		S.since=0
	else
		S.since=S.since+d
		if S.since>(config.snBuffer or .3) then S.holder=nil end
	end
	local mode=config.snMode or 1
	local holder=(mode~=2) and S.holder and refresh(S.holder) or nil
	local pos,look
	if holder then
		local fwd=holder.root.rotation:getForwardVector()
		fwd=(fwd-up*Vec3.dot(fwd,up)):getSafeNormal()
		pos=holder.root.position-fwd*cd+up*ch
		look=holder.head.position
	else
		local flat=vel-up*Vec3.dot(vel,up)
		local want=(flat:length()>10) and flat:getSafeNormal() or (S.dir or arena.right:getSafeNormal())
		if not S.dir or snap then S.dir=want end
		S.dir=dampV(S.dir,want,config.snDirSmooth or 4,d):getSafeNormal()
		pos=bp-S.dir*cd+up*ch
		look=bp+S.dir*(cd*.3)
	end
	pos=findSafePosition(look,pos,up,arena.right)
	local tgtRot=safeFromXZ((look-pos):getSafeNormal(),up,camRot)
	local sm=config.snSmooth or 6
	if snap then
		camPos,camRot=pos,tgtRot
	else
		camPos=dampV(camPos,pos,sm,d)
		camRot=dampQ(camRot,tgtRot,sm*1.6,d)
	end
	targetFOV=config.snFOV or 90
	return true
end

local function dynCam(d)
	if not selectedArena then return false end
	if (config.camProfile or 1)==3 then return yukiCam(d) end
	if (config.camProfile or 1)==1 then return plutusCam(d) end
	if (config.camProfile or 1)==4 then return snowmanCam(d) end
	if goalCelebration.isActive and goalCelebration.goal then
		local goal = goalCelebration.goal
		local u    = selectedArena.up
		local goalFwd  = goal.rotation:getForwardVector()
		local idealPos = goal.position + goalFwd * config.bcGoalCamDist + u * config.bcGoalCamHeight
		local lookDir  = (goal.position - camPos):getSafeNormal()
		local tgtRot   = safeFromXZ(lookDir, u, camRot)
		camPos = applyCamPos(idealPos, spdToTime(2), d)
		camRot = dampQ(camRot, tgtRot, 3, d)
		targetFOV = config.bcFOV
		camera.hideNearestHead = false
		camBehavior = "GOAL_CELEBRATION"
		return true
	end
	local arena = selectedArena
	local u, rgt = arena.up, arena.right

	if config.bcKickoffOrbitEnabled and selectedArena.ball and not goalCelebration.isActive then
		local ballPos  = selectedArena.ball.transform.position
		local toCentre = dist(ballPos, arena.center)
		if isBallStationary and toCentre <= (config.bcKickoffCenterDist or 350) then
			if not kickoff.active then
				kickoff.active = true
				local rel = camPos - ballPos
				kickoff.angle = math.deg(math.atan2(Vec3.dot(rel, arena.forward), Vec3.dot(rel, rgt)))
			end
			kickoff.angle = kickoff.angle + (config.bcKickoffOrbitSpeed or 20) * d
			local a    = math.rad(kickoff.angle)
			local dirH = rgt * math.cos(a) + arena.forward * math.sin(a)
			local idealPos = ballPos + dirH * (config.bcKickoffRadius or 450) + u * (config.bcKickoffHeight or 160)
			idealPos = findSafePosition(ballPos, idealPos, u, rgt)
			local lookDir = (ballPos - idealPos):getSafeNormal()
			local tgtRot  = safeFromXZ(lookDir, u, camRot)
			camPos = applyCamPos(idealPos, spdToTime(config.bcPosSmooth), d)
			camRot = dampQ(camRot, tgtRot, config.bcRotSmooth, d)
			targetFOV = config.bcKickoffFOV or config.bcFOV
			camera.hideNearestHead = false
			camBehavior = "KICKOFF_ORBIT"
			return true
		else
			kickoff.active = false
		end
	end

	local newDir         = nil
	local pitchPlayer    = nil
	local trackBallPitch = false
	if possession.player and possession.timer > 0.1 then
		local cp2 = refresh(possession.player)
		if cp2 then
			local flatHead = flattenDir(cp2.head.rotation:getForwardVector(), u)
			if flatHead then newDir = flatHead; camBehavior = "CARRY"; pitchPlayer = cp2 end
		end
	end
	if not newDir and smoothBallVel:length() > config.bcBallStationaryThreshold then
		local flatVel = flattenDir(smoothBallVel, u)
		if flatVel then newDir = flatVel; camBehavior = "TRACK"; trackBallPitch = true end
	end

	-- Camera profile: 1 = Plutus (no crowd awareness), 2 = Zepy (crowd + goal awareness).
	local zepy = (config.camProfile or 1) == 2
	local crowdRaw = 0
	if zepy then
		local crowdRadius = config.bcCrowdRadius or 650
		local crowdCount  = 0
		for _, p in ipairs(arena.players) do
			if p.root and dist(smoothBallPos, p.root.position) <= crowdRadius then
				crowdCount = crowdCount + 1
			end
		end
		local crowdThresh = config.bcCrowdThreshold or 4
		local crowdFull   = math.max(config.bcCrowdFull or 4, 1)
		crowdRaw = math.clamp((crowdCount - crowdThresh) / crowdFull, 0, 1)
	end
	-- Always damped (0 in Plutus) so switching profiles eases instead of popping.
	bcCrowdSmooth = damp(bcCrowdSmooth, crowdRaw, 2.5, d)

	if newDir then
		local chaseSpeed = config.bcDirSmooth * (1 - bcCrowdSmooth)
		lockedDir = smoothDirLimited(lockedDir, newDir,
			chaseSpeed, config.bcMaxDirChangeRate, d)
		dirInitialized = true
	else
		if not dirInitialized then lockedDir = arena.forward; dirInitialized = true end
	end
	if zepy and bcCrowdSmooth > 0.5 then
		camBehavior = "CROWD"
	elseif not newDir and camBehavior ~= "STATIC" then
		camBehavior = "IDLE"
	end
	smoothDir = smoothDirLimited(smoothDir, lockedDir,
		config.bcDirSmooth, config.bcMaxDirChangeRate, d)

	-- Existing lead behavior retained, without crowd-based suppression.
	local leadDot = config.bcLeadDot or 0.6
	local alignLead = 1
	if newDir then
		local alignDot = math.clamp(Vec3.dot(smoothDir, newDir), -1, 1)
		alignLead = math.clamp((alignDot - leadDot) / math.max(1 - leadDot, 0.01), 0, 1)
	end
	local leadTarget = alignLead * (1 - bcCrowdSmooth)
	if isBallStationary then leadTarget = 0 end
	bcLeadSmooth = damp(bcLeadSmooth, leadTarget, 4, d)

	local pitchTarget = 0
	if config.verticalCameraEnabled then
		local maxRad = math.rad(config.verticalCameraMaxAngle or 60)
		if pitchPlayer and pitchPlayer.head then
			local hf  = pitchPlayer.head.rotation:getForwardVector()
			local raw = math.asin(math.clamp(Vec3.dot(hf, u), -1, 1))
			pitchTarget = math.clamp(raw, -maxRad, maxRad)
		elseif trackBallPitch then
			local vN  = smoothBallVel:getSafeNormal()
			local raw = math.asin(math.clamp(Vec3.dot(vN, u), -1, 1))
			pitchTarget = math.clamp(raw, -maxRad, maxRad)
		end
	end
	bcSmoothPitch = damp(bcSmoothPitch, pitchTarget, config.verticalCameraSmooth or 6, d)

	local focusPoint    = smoothBallPos
	local pitchedSmooth = applyPitch(smoothDir, bcSmoothPitch, u)
	local behindDir     = pitchedSmooth * -1

	local distMul  = 1 + bcCrowdSmooth * (config.bcCrowdStepBack or 0.6)   -- Zepy profile pull-back (1 in Plutus)
	local idealPos = focusPoint + behindDir * (config.bcDist * distMul) + u * config.bcHeight
	idealPos = findSafePosition(focusPoint, idealPos, u, rgt)

	-- Lead amount is continuous: at lead=0 we look straight at the ball, at
	-- lead=1 we look fully ahead of it, and every value between eases.
	local lookTarget = focusPoint + pitchedSmooth * (100 * bcLeadSmooth)

	-- Zepy profile: ease the look target toward a goal as the ball nears its mouth.
	local goalLookBias = zepy and (config.bcGoalLookBias or 0.5) or 0
	local goalTarget   = 0
	local biasGoalPos  = nil
	if goalLookBias > 0 then
		local proxRange = math.max(config.bcGoalProximity or 1200, 1)
		local bestScore = 0
		for _, g in ipairs({arena.home.goal, arena.away.goal}) do
			if g and g.position then
				local gd     = dist(g.position, smoothBallPos)
				local near01 = math.clamp((proxRange - gd) / proxRange, 0, 1)
				local score  = near01 * near01
				if score > bestScore then bestScore = score; biasGoalPos = g.position end
			end
		end
		goalTarget = bestScore
	end
	if biasGoalPos then bcGoalLastPos = biasGoalPos end
	bcGoalSmooth = damp(bcGoalSmooth, goalTarget, 1.2, d)
	if bcGoalLastPos and bcGoalSmooth > 0.001 then
		lookTarget = Vec3.lerp(lookTarget, bcGoalLastPos, bcGoalSmooth * goalLookBias)
	end


	local lookDir = (lookTarget - idealPos):getSafeNormal()
	local tgtRot  = safeFromXZ(lookDir, u, camRot)
	camPos = applyCamPos(idealPos, spdToTime(config.bcPosSmooth), d)
	camRot = dampQ(camRot, tgtRot,   config.bcRotSmooth, d)
	local speedFOV = 0
	if config.bcSpeedFOVEnabled then
		speedFOV = math.clamp(smoothBallVel:length() / 1500, 0, 1) * config.bcSpeedFOVMax
	end
	targetFOV = config.bcFOV + speedFOV
	camera.hideNearestHead = false
	return true
end

local function playerFollowCam(d)
	if not selectedArena then return false end
	if not playerFollow.enabled then return dynCam(d) end
	local target = nil
	for _, p in ipairs(selectedArena.players) do
		if p.playerName == playerFollow.targetName then target = p; break end
	end
	if not target then
		playerFollow.targetPlayer    = nil
		playerFollow.isFollowing     = false
		playerFollow.dirInitialized  = false
		camBehavior = "PFOLLOW:WAITING"
		return dynCam(d)
	end
	if not target.root or not target.head then return dynCam(d) end
	playerFollow.targetPlayer = target
	playerFollow.isFollowing  = true
	local arena = selectedArena
	local u     = arena.up
	local anchor = Vec3.lerp(target.root.position, target.head.position, 0.5)
	local rootFwd = target.root.rotation:getForwardVector()
	local flatFwd = flattenDir(rootFwd, u) or arena.forward
	if not playerFollow.dirInitialized then
		playerFollow.smoothDir      = flatFwd
		playerFollow.dirInitialized = true
	end
	playerFollow.smoothDir = smoothDirStable(
		playerFollow.smoothDir, flatFwd, config.tpDirSmooth, d)
	playerFollow.smoothPitch = computeFollowPitch(
		target, u, playerFollow.smoothPitch, d)
	local pitchedFwd = applyPitch(playerFollow.smoothDir, playerFollow.smoothPitch, u)
	local behindDir = pitchedFwd * -1
	local idealPos  = anchor + behindDir * config.tpDist + u * config.tpHeight
	idealPos = findSafePosition(anchor, idealPos, u, arena.right)
	local lookDir = (anchor - idealPos):getSafeNormal()
	local tgtRot  = safeFromXZ(lookDir, u, camRot)
	camPos = applyCamPos(idealPos, spdToTime(config.tpSmooth), d)
	camRot = dampQ(camRot, tgtRot,   config.tpRotSmooth, d)
	targetFOV = config.tpFOV
	camera.hideNearestHead = false
	camBehavior = "PFOLLOW"
	return true
end

local function casterCam(d)
	if not caster.freecamActive then
		local ok = dynCam(d)
		caster.pos = camPos
		caster.fov = camFOV
		return ok
	else
		casterFreecamTick(d)
		return true
	end
end

local function handleInput()
	if Input_pressed(KB.toggleGui) then
		showGui = not showGui
		config.showGui = showGui
	end

	local function switchMode(newMode)
		if prevMode == Mode.FP and newMode ~= Mode.FP then saveConfig() end
		prevMode = curMode
		curMode  = newMode
		if curMode == Mode.CASTER then
			caster.freecamActive = false
		end
	end

	if Input_pressed(KB.mode1) then
		switchMode(Mode.FP)
		if selectedArena and #selectedArena.players > 0 and not curTarget then
			curIdx = 1; curTarget = selectedArena.players[1]
		end
	end
	if Input_pressed(KB.mode3) then switchMode(Mode.DYN) end
	if Input_pressed(KB.mode4) then
		switchMode(Mode.PFOLLOW)
		playerFollow.dirInitialized = false
	end
	if Input_pressed(KB.mode5) then
		switchMode(Mode.KEYFRAME)
		kfState.enabled = true
	end
	if Input_pressed(KB.mode6) then
		switchMode(Mode.CASTER)
	end
	if Input_pressed(KB.lock) then isLocked = not isLocked end
	-- V: swap first / third person on the Player camera
	if curMode == Mode.PFOLLOW and keyDown(Input.Key.V) then
		PicklerSetPlayerView(((config.pfView or 1) == 2) and 1 or 2)
	end

	if curMode == Mode.KEYFRAME and kfState.enabled and not kfState.isPlaying then
		if Input_pressed(KB.kfAdd) then kfAdd() end
	end

	if curMode == Mode.CASTER then
		if Input.getKeyDown(Input.Key.F) then
			caster.freecamActive = not caster.freecamActive
			if caster.freecamActive then
				caster.pos = camPos
				caster.fov = camFOV
				local e = camRot:euler()
				caster.pitch = math.clamp(e.y, -89, 89)
				caster.yaw   = e.z
			end
		end
		if caster.freecamActive and Input.getKeyDown(Input.Key.G) then
			caster.axisLock = not caster.axisLock
		end
	end

	local freeCamActive = (curMode == Mode.KEYFRAME and config.kfUseFreeCam)

	if not freeCamActive and curMode ~= Mode.KEYFRAME and curMode ~= Mode.CASTER and selectedArena and #selectedArena.players > 0 then
		if curMode == Mode.PFOLLOW then
			local function cycleFollowPlayer(dir)
				local players = selectedArena.players
				local idx = nil
				for i, p in ipairs(players) do
					if p.playerName == playerFollow.targetName then idx = i; break end
				end
				if not idx then idx = 1 end
				idx = ((idx - 1 + dir) % #players) + 1
				playerFollow.targetName       = players[idx].playerName
				config.playerFollowTargetName = players[idx].playerName
				playerFollow.enabled          = true
				config.playerFollowEnabled    = true
				playerFollow.dirInitialized   = false
			end
			if Input_pressed(KB.nextP) or Input_pressed(GP.nxtP) then cycleFollowPlayer(1)  end
			if Input_pressed(KB.prevP) or Input_pressed(GP.prvP) then cycleFollowPlayer(-1) end
		elseif curMode ~= Mode.DYN then
			local n = #selectedArena.players
			if Input_pressed(KB.nextP) or Input_pressed(GP.nxtP) then
				curIdx = curIdx % n + 1
				curTarget = selectedArena.players[curIdx]
				isLocked = true
			end
			if Input_pressed(KB.prevP) or Input_pressed(GP.prvP) then
				curIdx = (curIdx - 2) % n + 1
				curTarget = selectedArena.players[curIdx]
				isLocked = true
			end
		end
	end

	if not autoFollow.enabled and not freeCamActive and curMode ~= Mode.CASTER then
		if Input_pressed(KB.nxtA) or Input_pressed(GP.nxtA) then cycleArena(1)  end
		if Input_pressed(KB.prvA) or Input_pressed(GP.prvA) then cycleArena(-1) end
		if Input_pressed(KB.arena) or Input_pressed(GP.arena) then
			if arenas then
				local best, bd = nil, math.huge
				for _, a in pairs(arenas) do
					local dd = dist(camera.position, a.transform.position)
					if dd < bd then bd = dd; best = a end
				end
				if best then selectArena(best) end
			end
		end
	end
end

local function tabHeader(key, label)
	local isOpen = config.guiTabOpen[key]
	local arrow = isOpen and "v " or "> "
	if Gui.button(arrow .. label .. "##tab_" .. key) then
		config.guiTabOpen[key] = not isOpen
	end
	return config.guiTabOpen[key]
end

local function selectPlayerForSpectate(info)
	if info.arena then selectArena(info.arena) end
	local arenaPlayers = (selectedArena and selectedArena.players) or {}
	for i, ap in ipairs(arenaPlayers) do
		if ap.playerName == info.player.playerName then
			curIdx    = i
			curTarget = ap
			isLocked  = true
			return
		end
	end
end

local function selectPlayerForFollow(info)
	playerFollow.targetName       = info.player.playerName
	playerFollow.enabled          = true
	playerFollow.dirInitialized   = false
	config.playerFollowTargetName = info.player.playerName
	config.playerFollowEnabled    = true
	autoFollow.enabled            = false
	autoFollow.isActive           = false
	config.autoFollowEnabled      = false
	if info.arena then selectArena(info.arena) end
end

local function drawArenaPlayerPicker(modeKey, prefixId)
	if #allServerPlayers == 0 then
		Gui.text("  (no players detected in any arena yet)")
		return
	end
	local highlightName
	if modeKey == "follow" then
		highlightName = playerFollow.targetName
	else
		highlightName = curTarget and curTarget.playerName or nil
	end
	local arenaOrder, byArena = {}, {}
	for _, info in ipairs(allServerPlayers) do
		local aName = info.arenaName or "Unknown"
		if not byArena[aName] then
			byArena[aName] = {}; arenaOrder[#arenaOrder+1] = aName
		end
		byArena[aName][#byArena[aName]+1] = info
	end
	for _, aName in ipairs(arenaOrder) do
		local liveTag = (arenas and arenas[aName] and arenas[aName].isActive) and "  [LIVE]" or ""
		Gui.text("  ── " .. aName .. liveTag .. " ──")
		for _, info in ipairs(byArena[aName]) do
			local p        = info.player
			local isActive = (highlightName == p.playerName)
			local teamTag  = info.teamIndex==TI.Home and "[H] "
			              or info.teamIndex==TI.Away and "[A] "
			              or "[?] "
			local prefix   = isActive and ">> " or "   "
			local suffix   = isActive and " <<" or ""
			local btnId    = "##" .. prefixId .. "_" .. p.playerName
			if Gui.button(prefix .. teamTag .. p.playerName .. suffix .. btnId) then
				if modeKey == "follow" then
					selectPlayerForFollow(info)
				else
					selectPlayerForSpectate(info)
				end
			end
		end
		Gui.newLine()
	end
end

local function uiCheck(label, key)
	config[key] = Gui.checkbox(label, config[key] and true or false)
end

local function uiSlider(label, key, lo, hi)
	config[key] = Gui.sliderFloat(label, config[key] or lo, lo, hi)
end

local function uiInterpCombo()
	local cur = config.kfInterpMode or KF_INTERP.LINEAR
	local preview = KF_INTERP_NAMES[cur] or "Linear"
	if Gui.beginCombo("Interpolation##kfInterp", preview) then
		for i, name in ipairs(KF_INTERP_NAMES) do
			if Gui.selectable(name .. "##kfi" .. i, i == cur) then
				config.kfInterpMode = i
			end
		end
		Gui.endCombo()
	end
end

local function uiSpeedRampEditor()
	Gui.text("-- Speed Ramp (per keyframe) --")
	local kfs = kfState.keyframes
	local idx = kfState.selectedIdx

	if idx < 1 or idx > #kfs then
		Gui.text("  Select a keyframe to edit its ramp.")
		return
	end
	if idx >= #kfs then
		Gui.text("  Last keyframe has no outgoing segment;")
		Gui.text("  select an earlier keyframe to ramp it.")
		return
	end

	local kf = kfs[idx]
	if not kf.ramp then
		kf.ramp = {KF_RAMP_DEFAULT[1], KF_RAMP_DEFAULT[2],
		           KF_RAMP_DEFAULT[3], KF_RAMP_DEFAULT[4]}
	end

	Gui.text(string.format("  Segment: keyframe %d -> %d  (%.2fs -> %.2fs)",
		idx, idx + 1, kf.time, kfs[idx + 1].time))

	kf.rampEnabled = Gui.checkbox(
		string.format("Ramp this segment##kfRampEn%d", idx),
		kf.rampEnabled and true or false)

	if not kf.rampEnabled then
		Gui.text("  (off - segment uses the normal easing)")
		return
	end

	if Gui.beginCombo("Preset##kfRampPreset", "apply a preset...") then
		for i, p in ipairs(KF_RAMP_PRESETS) do
			if Gui.selectable(p.name .. "##kfRampP" .. i, false) then
				kf.ramp[1], kf.ramp[2] = p.x1, p.y1
				kf.ramp[3], kf.ramp[4] = p.x2, p.y2
			end
		end
		Gui.endCombo()
	end

	kf.ramp[1] = math.clamp(
		Gui.sliderFloat("Handle 1 X##kfRampX1", kf.ramp[1] or 0.40, 0, 1), 0, 1)
	kf.ramp[2] = Gui.sliderFloat("Handle 1 Y##kfRampY1", kf.ramp[2] or 0.00, -0.5, 1.5)
	kf.ramp[3] = math.clamp(
		Gui.sliderFloat("Handle 2 X##kfRampX2", kf.ramp[3] or 0.00, 0, 1), 0, 1)
	kf.ramp[4] = Gui.sliderFloat("Handle 2 Y##kfRampY2", kf.ramp[4] or 1.00, -0.5, 1.5)

	Gui.text("  " .. kfRampSparkline(kf.ramp, 26))
	Gui.text(string.format("  bezier: %.2f, %.2f, %.2f, %.2f",
		kf.ramp[1], kf.ramp[2], kf.ramp[3], kf.ramp[4]))

	if Gui.button("Reset curve##kfRampReset") then
		kf.ramp[1], kf.ramp[2] = KF_RAMP_DEFAULT[1], KF_RAMP_DEFAULT[2]
		kf.ramp[3], kf.ramp[4] = KF_RAMP_DEFAULT[3], KF_RAMP_DEFAULT[4]
	end
	Gui.sameLine()
	if Gui.button("Disable##kfRampOff") then
		kf.rampEnabled = false
	end
end

local function drawKeyframeStrip()
	local kfs = kfState.keyframes
	if #kfs == 0 then
		Gui.text("  (no keyframes yet)")
		return
	end
	for i, kf in ipairs(kfs) do
		local sel   = (i == kfState.selectedIdx)
		local mark  = (kf.rampEnabled and i < #kfs) and "~" or ""
		local label = string.format("%s%d%s:%.2fs%s##kfjump_%d",
			sel and "[" or " ", i, mark, kf.time, sel and "]" or " ", i)
		if Gui.button(label) then kfGoTo(i) end
		if i < #kfs then Gui.sameLine() end
	end
	Gui.newLine()
end

PicklerCasterPage = "info"
PicklerCasterMode = "caster"
PicklerCasterSaveText = ""

PicklerCaster_ARENA_SLOTS = {
	{"Alpha 1","alpha",1},{"Alpha 2","alpha",2},{"Alpha 3","alpha",3},
	{"Beta 1","beta",1},{"Beta 2","beta",2},{"Beta 3","beta",3},
	{"Gamma 1","gamma",1},{"Gamma 2","gamma",2},{"Gamma 3","gamma",3},
}

function PicklerCasterFindArena(group, number)
	if not arenas then return nil end
	group=string.lower(group)
	for key,a in pairs(arenas) do
		local n=string.lower(tostring(key))
		local digits=string.match(n, group.."[^0-9]*(%d+)")
		if digits and tonumber(digits)==number then return a end
	end
	return nil
end

function PicklerCasterArenaLabel(a)
	if not a then return "Select arena" end
	local n=string.lower(tostring(a.name or ""))
	for _,slot in ipairs(PicklerCaster_ARENA_SLOTS) do
		local digits=string.match(n, slot[2].."[^0-9]*(%d+)")
		if digits and tonumber(digits)==slot[3] then return slot[1] end
	end
	return tostring(a.name or "Select arena")
end

function PicklerCasterArenaPicker()
	local preview=PicklerCasterArenaLabel(selectedArena)
	if Gui.beginCombo("Arena##PicklerCasterArena",preview) then
		for i,slot in ipairs(PicklerCaster_ARENA_SLOTS) do
			local a=PicklerCasterFindArena(slot[2],slot[3])
			if Gui.selectable(slot[1].."##PicklerCasterArena"..i,a~=nil and selectedArena==a) then
				if a then selectArena(a) end
			end
		end
		Gui.endCombo()
	end
end

function PicklerCasterSave()
	local ok,err=pcall(function() saveConfig() end)
	if ok then PicklerCasterSaveText="SAVED" else PicklerCasterSaveText="SAVE FAILED: "..tostring(err) end
end

-- Goal celebration free cam ------------------------------------------------------------
-- Uses the Caster free cam (same controls as pressing F in Caster mode) and parks it in front
-- of the celebration text, looking straight at it.
function goalFxOpenFreeCam()
	if not selectedArena then return end
	if not goalFx.goal then goalFx.goal=selectedArena.away.goal end
	local c,u,r,toward=goalFxFrame()
	if not c then return end
	local anchor=goalFxAnchor(c,u,r)
	-- same framing as the automatic goal camera, so a preview looks like a real goal
	local dist=math.clamp(config.goalFxFreeCamDist or 750,100,2500)
	local pos=anchor+toward*dist+u*(config.goalFxCamHeight or 60)
	local look=((anchor+u*40)-pos):getSafeNormal()
	-- remember everything this changes, so EXIT FREE CAM puts the casting camera back exactly
	if not goalFx.freeSnap then
		goalFx.freeSnap={pos=camPos,rot=camRot,fov=camFOV,target=targetFOV,cPos=caster.pos,cPitch=caster.pitch,
			cYaw=caster.yaw,cFov=caster.fov,cBall=caster.lookAtBall,cLock=caster.axisLock,
			cActive=caster.freecamActive,mode=curMode,uiMode=PicklerCasterMode}
	end
	-- the free cam rebuilds its rotation from world pitch and yaw with no roll, so measure them
	-- against world up: measuring against the arena's up put a tilt in the view on rotated arenas
	local e=safeFromXZ(look,Vec3.new(0,0,1),camRot):euler()
	caster.pos=pos
	caster.pitch=math.clamp(e.y,-89,89)
	caster.yaw=e.z
	caster.fov=math.clamp(config.goalFxCamFOV or 100,60,130)
	caster.lookAtBall=false
	caster.axisLock=false
	camRot=Quat.fromEuler(0,caster.pitch,caster.yaw)
	if curMode~=Mode.CASTER then
		prevMode=curMode
		curMode=Mode.CASTER
	end
	caster.freecamActive=true
	PicklerCasterMode="caster"
end

function goalFxCloseFreeCam()
	local s=goalFx.freeSnap
	if not s then
		caster.freecamActive=false
		return
	end
	goalFx.freeSnap=nil
	caster.pos,caster.pitch,caster.yaw,caster.fov=s.cPos,s.cPitch,s.cYaw,s.cFov
	caster.lookAtBall,caster.axisLock,caster.freecamActive=s.cBall,s.cLock,s.cActive
	prevMode=curMode
	curMode=s.mode
	PicklerCasterMode=s.uiMode
	camPos,camRot,camFOV,targetFOV=s.pos,s.rot,s.fov,s.target
	camPosVel=Vec3.zeroVector
end

-- =====================================================================================
-- UI (v2): simple by default, with every old setting still available under "Show advanced
-- options". Tabs: HOME, CASTER, PLAYER, EFFECTS, CREDITS.
-- =====================================================================================

-- Clicking a camera style always drops you into the automatic caster camera (out of free cam,
-- player cam or keyframes) so the switch is visible straight away.
function PicklerEnterCaster()
	PicklerCasterMode="caster"
	curMode=Mode.DYN
	caster.freecamActive=false
end

-- The Plutus orbit camera (values from Plutus' autocaster). Clicking PLUTUS loads exactly these.
PICKLER_PLUTUS_PRESET={
	plBaseFOV=90,plSmooth=8,plDistBase=220,plHeightBase=120,
	plDistMax=1500,plHeightMax=1000,
	plDistSpeedBonus=120,plHeightSpeedBonus=60,
	plDistSpreadBonus=80,plHeightSpreadBonus=45,
	plDistGoalPenalty=60,plHeightGoalBonus=30,
	plOrbitBias=.6,plLead=.4,
	plCollision=true,plCollisionStrength=1.0,plCollisionRadius=80,
	plPlayerRay=true,plPlayerRayStrength=1.2,plPlayerRayUp=25,
}

function PicklerApplyPlutusPreset()
	for key,val in pairs(PICKLER_PLUTUS_PRESET) do config[key]=val end
	config.camProfile=1
	plutusReset()
	PicklerEnterCaster()
end

-- The Zepy camera look (values from the original Zepy script). Clicking ZEPY loads exactly these.
PICKLER_ZEPY_PRESET={
	bcDist=190,bcHeight=115,bcFOV=125,
	bcPosSmooth=40,bcRotSmooth=10,bcDirSmooth=5,
	bcMaxDirChangeRate=2.5,bcFOVSmooth=3.0,
	bcSpeedFOVEnabled=true,bcSpeedFOVMax=15,
	bcCrowdRadius=650,bcCrowdThreshold=4,bcCrowdFull=4,bcCrowdStepBack=0.6,
	bcLeadDot=0.6,bcLookAhead=0.060,
	bcIntelligentMode=true,
	bcGoalProximity=1200,bcGoalLookBias=0.5,
	bcMinPlayerDist=180,bcMinWallDist=100,
	bcCeilingBuffer=30,bcCollisionProbeRadius=80,bcMinCamDist=200,
	bcBallStationaryThreshold=50,bcBallIdleTime=0.5,
	bcGoalCelebrationTime=3.0,bcGoalCamDist=500,bcGoalCamHeight=200,
	bcKickoffOrbitEnabled=true,bcKickoffOrbitSpeed=20,
	bcKickoffRadius=450,bcKickoffHeight=160,bcKickoffCenterDist=350,bcKickoffFOV=95,
	useSpringSmoothing=true,camBlendDuration=0.40,
	verticalCameraEnabled=false,verticalCameraMaxAngle=60,verticalCameraSmooth=6,
}

function PicklerApplyZepyPreset()
	for key,val in pairs(PICKLER_ZEPY_PRESET) do config[key]=val end
	config.camProfile=2
	PicklerEnterCaster()
end

-- The Yuki sideline camera look (values from the original Yuki SIDEARES script).
-- Clicking YUKI loads exactly these and puts the camera back on the first sideline.
PICKLER_YUKI_PRESET={
	yukiSideDist=2093,yukiSwitchWidth=1000,yukiHeightOffset=200,
	yukiAutoSwitch=true,yukiInstantSwitch=true,yukiSewerCam=true,
	yukiHookEnabled=true,yukiHookY=1.4,yukiHookX=0,
	yukiRiser=false,yukiRailLength=4000,yukiMaxHeight=1329,
	yukiZoomEnabled=true,yukiZoomSize=0.035,yukiFOV=60,
	yukiPosSmooth=0.3,yukiRotSmooth=0.3,yukiFovSmooth=0.05,
	yukiTrailSeconds=0.15,yukiTrailThick=25,yukiTrailGlow=1.5,
}

function PicklerApplyYukiPreset()
	for key,val in pairs(PICKLER_YUKI_PRESET) do config[key]=val end
	config.camProfile=3
	YUKI_STATE.side=1
	YUKI_STATE.sewerTimer=0
	YUKI_STATE.sewerPos=nil
	YUKI_STATE.inSewer=false
	YUKI_STATE.lastT=nil
	PicklerEnterCaster()
end

-- The Snowman casting camera (values from Snowman's CastCam). Clicking SNOWMAN loads these.
PICKLER_SNOWMAN_PRESET={snMode=1,snDist=300,snHeight=200,snSmooth=6,snDirSmooth=4,snFOV=90,snBuffer=.3}

function PicklerApplySnowmanPreset()
	for key,val in pairs(PICKLER_SNOWMAN_PRESET) do config[key]=val end
	config.camProfile=4
	SNOWMAN_STATE.lastT=-1
	SNOWMAN_STATE.holder=nil
	PicklerEnterCaster()
end

function PicklerSnowmanUi()
	PicklerUiHeader("SNOWMAN CASTING CAMERA")
	PicklerUiHint("Follows the ball carrier from behind, or chases the ball when it's loose.")
	local names={"AUTO","BALL","PLAYER"}
	local tips={"Carrier when someone has the ball, otherwise the ball","Always chase the ball",
		"Stay on the ball carrier (ball when nobody has it)"}
	for i,nm in ipairs(names) do
		if i>1 then Gui.sameLine() end
		local cur=config.snMode or 1
		local ok,res=pcall(function()
			if cur==i then return Gui.buttonColored(PicklerAccent(.85),nm.."##vxSnM"..i) end
			return Gui.button(nm.."##vxSnM"..i)
		end)
		if ok and res then config.snMode=i end
		PicklerUiTip(tips[i])
	end
	PicklerUiHeader("FRAMING")
	uiSlider("How far back##vxSnDist","snDist",0,600)
	uiSlider("How high##vxSnH","snHeight",-100,400)
	uiSlider("Field of view##vxSnFov","snFOV",50,130)
	PicklerUiHeader("SMOOTHING")
	uiSlider("Camera smoothness (lower = smoother)##vxSnSm","snSmooth",.5,15)
	uiSlider("Turn smoothness (lower = smoother)##vxSnDS","snDirSmooth",.5,15)
	uiSlider("Keep the carrier for (seconds)##vxSnBuf","snBuffer",0,1.5)
end

function PicklerCamLabel()
	local m=string.upper(PicklerCasterMode or "caster")
	if m=="CASTER" then
		return "CASTER  ("..PicklerProfileName()..")"
	end
	return m
end

function PicklerClipUi()
	PicklerUiHeader("WHICH GOALS")
	uiCheck("Clip HOME team goals##vxClipHome","clipHomeGoals")
	Gui.sameLine()
	uiCheck("Clip AWAY team goals##vxClipAway","clipAwayGoals")
	local st="Off"
	if config.clipHomeGoals and config.clipAwayGoals then st="All goals"
	elseif config.clipHomeGoals then st="Home goals only"
	elseif config.clipAwayGoals then st="Away goals only" end
	Gui.text("Clipping: "..st.."   |   Goals so far: "..tostring(config.clipCount or 0))
	local ago=totalTime-clipState.lastTime
	if ago<600 then
		PicklerUiHint("Last goal: "..clipState.lastTeam.." ("..string.format("%.0f",ago).."s ago)")
	end
	if Gui.button("RESET COUNTER##vxClipReset") then config.clipCount=0; saveConfig() end
	PicklerUiHint("Only the arena you have selected is watched. If HOME and AWAY look swapped, tick the other box.")

	PicklerUiHeader("VIDEO CLIPS (OBS or Medal)")
	config.clipPostSeconds=Gui.sliderFloat("Keep this long after the goal (s)##vxClipPost",config.clipPostSeconds or 5,0,20)
	PicklerUiHint("Footage before the goal = the buffer length you set in OBS or Medal, minus this.")
	PicklerUiHint("The save folder is also set in OBS or Medal: they do the recording.")
	if Gui.button("SEND TEST CLIP##vxClipTest") then PicklerClipSendEvent("TEST") end
	PicklerUiTip("Asks the companion to save a clip right now, to check your setup")
	PicklerUiHint("Clip signals sent: "..tostring(config.clipEventId or 0))
	PicklerUiHint("A game script can't reach OBS or Medal, so a small companion program does it.")
	PicklerUiHint("Run A2\\PicklerClipCompanion\\Start-Companion.bat next to the game.")
	PicklerUiHint("Its window shows if it's connected: this menu can't see that.")
	if Gui.collapsingHeader("OBS setup##vxClipObs") then
		Gui.indent()
		PicklerUiHint("1. Settings > Output > Replay Buffer: enable it, set the length (e.g. 30 s)")
		PicklerUiHint("2. Settings > Output > Recording: choose the folder clips save to")
		PicklerUiHint("3. Tools > WebSocket Server Settings: enable it, copy the password")
		PicklerUiHint("4. Put the password in companion-settings.json, run the companion")
		PicklerUiHint("5. Press SEND TEST CLIP above and check the folder")
		Gui.unindent()
	end
	if Gui.collapsingHeader("Medal setup##vxClipMedal") then
		Gui.indent()
		PicklerUiHint("Hotkey (no key needed): set method to hotkey and enter your Medal clip key.")
		PicklerUiHint("API: Medal issues a public key on request. Set method to medal and paste it.")
		PicklerUiHint("Both Medal routes are untested: use SEND TEST CLIP to check them.")
		Gui.unindent()
	end

	PicklerUiHeader("GAME REPLAYS (built in, no extra software)")
	uiCheck("Record a game replay, split at each goal##vxClipRec","clipRecordReplays")
	if not PicklerClipReplayAllowed() then
		PicklerUiColorText(LinearColor.new(1,.6,.3,1),"The game's settings aren't allowing scripts to record replays.")
	elseif clipState.rec then
		PicklerUiColorText(LinearColor.new(1,.35,.3,1),"RECORDING   (saved this session: "..clipState.recCount..")")
	else
		PicklerUiHint("Not recording   (saved this session: "..clipState.recCount..")")
	end
	PicklerUiHint("Runs from the last goal or round start to just after this goal.")
	PicklerUiHint("These are replays you re-watch in game, not videos. The game picks the folder.")
end

function PicklerProfileName()
	local p=config.camProfile or 1
	if p==2 then return "ZEPY" elseif p==3 then return "YUKI" elseif p==4 then return "SNOWMAN" end
	return "PLUTUS"
end

function PicklerYukiUi()
	PicklerUiHeader("YUKI SIDELINE CAMERA")
	PicklerUiHint("Slides along the sideline and follows the ball. Zooms by itself")
	PicklerUiHint("so the ball stays the same size on screen.")
	PicklerUiHeader("POSITION")
	uiSlider("Distance from the middle##vxYkSide","yukiSideDist",800,2900)
	uiSlider("Height above the ball##vxYkH","yukiHeightOffset",0,600)
	uiCheck("Switch sides when the ball crosses over##vxYkAuto","yukiAutoSwitch")
	if config.yukiAutoSwitch then
		uiSlider("Switch distance##vxYkSw","yukiSwitchWidth",300,2000)
		uiCheck("Cut instantly when it switches##vxYkInst","yukiInstantSwitch")
	end
	if Gui.button("SWITCH SIDELINE##vxYkSwitch") then
		YUKI_STATE.side=-YUKI_STATE.side
		YUKI_STATE.snapNext=true
	end
	uiCheck("Use the sewer camera when the ball is in the sewer##vxYkSewer","yukiSewerCam")
	PicklerUiHeader("ENDZONES")
	uiCheck("Riser (camera climbs near the goals)##vxYkRiser","yukiRiser")
	PicklerUiHint("(helps keep the ball from hiding behind the Bridge and Nest)")
	uiCheck("Inward hook at the endzones##vxYkHook","yukiHookEnabled")
	if config.yukiHookEnabled then
		uiSlider("How much it pulls back##vxYkHookY","yukiHookY",0,4)
		uiSlider("How much it moves inward##vxYkHookX","yukiHookX",0,10)
	end
	uiSlider("Dolly rail length##vxYkRail","yukiRailLength",200,5000)
	uiSlider("Max camera height##vxYkMaxH","yukiMaxHeight",300,1329)
	PicklerUiHeader("LOOK")
	uiCheck("Yuki's camera look (low bloom, low exposure)##vxYkPost","yukiPostFx")
	PicklerUiHeader("ZOOM")
	uiCheck("Auto zoom (keeps the ball the same size)##vxYkZoom","yukiZoomEnabled")
	if config.yukiZoomEnabled then
		uiSlider("Ball size on screen##vxYkZs","yukiZoomSize",.01,.12)
	else
		uiSlider("Field of view##vxYkFov","yukiFOV",20,120)
	end
	PicklerUiHeader("SMOOTHING (seconds, lower = snappier)")
	uiSlider("Camera movement##vxYkPos","yukiPosSmooth",0,1.5)
	uiSlider("Camera turning##vxYkRot","yukiRotSmooth",0,1.5)
	uiSlider("Zoom##vxYkFovS","yukiFovSmooth",0,1)
end

function PicklerPlutusUi()
	PicklerUiHeader("PLUTUS ORBIT CAMERA")
	PicklerUiHint("Swings round behind the ball, pulls back when play is fast or")
	PicklerUiHint("spread out, and dodges walls and players blocking the view.")
	PicklerUiHeader("FRAMING")
	uiSlider("How far back##vxPlDist","plDistBase",80,600)
	uiSlider("How high##vxPlH","plHeightBase",0,400)
	uiSlider("Field of view##vxPlFov","plBaseFOV",60,120)
	uiSlider("Smoothness (lower = smoother)##vxPlSm","plSmooth",1,20)
	uiSlider("How fast it swings behind the ball##vxPlOrb","plOrbitBias",0,2)
	uiSlider("Look ahead of the ball##vxPlLead","plLead",0,1.5)
	PicklerUiHeader("PULL BACK")
	uiSlider("Extra distance when the ball is fast##vxPlSpdD","plDistSpeedBonus",0,400)
	uiSlider("Extra height when the ball is fast##vxPlSpdH","plHeightSpeedBonus",0,300)
	uiSlider("Extra distance when players spread out##vxPlSprD","plDistSpreadBonus",0,300)
	uiSlider("Extra height when players spread out##vxPlSprH","plHeightSpreadBonus",0,300)
	PicklerUiHeader("AVOIDANCE")
	uiCheck("Push off walls##vxPlCol","plCollision")
	if config.plCollision then uiSlider("Wall push strength##vxPlColS","plCollisionStrength",.2,3) end
	uiCheck("Lift over players blocking the view##vxPlRay","plPlayerRay")
	if config.plPlayerRay then uiSlider("Lift strength##vxPlRayS","plPlayerRayStrength",.2,3) end
	PicklerUiHeader("FIRST PERSON")
	uiCheck("FP on Dribble##vxPlFP","plDribbleFP")
	PicklerUiTip("Jumps into the eyes of whoever is holding the ball")
	if config.plDribbleFP~=false then
		uiSlider("FP FOV##vxPlFPF","plFirstPersonFOV",60,170)
		uiSlider("Dribble Hold (seconds)##vxPlFPH","plDribbleHold",.3,3)
		local looks={"Head (recommended)","Body Forward","Ball Direction"}
		local cur=config.plDribbleLook or 1
		if Gui.beginCombo("Dribble Look##vxPlLk",looks[cur] or looks[1]) then
			for i,nm in ipairs(looks) do
				if Gui.selectable(nm.."##vxPlLk"..i,cur==i) then config.plDribbleLook=i end
			end
			Gui.endCombo()
		end
	end
end

-- =====================================================================================
-- UI LOOK: a coloured, pulsing title with the creator's name, a live status bar, icon tabs
-- with the active one highlighted, line headers, dimmed hints, tooltips, and a choice of
-- accent colour. Every newer Gui call is wrapped so the menu still works if one is missing.
-- =====================================================================================
PICKLER_VERSION="3.0"
PICKLER_CREATOR="Pickler"          -- your name: shown in the title bar and on the CREDITS page
PICKLER_ACCENTS={
	{"Pickle Green",{.45,1,.35}},{"Ice Blue",{.35,.8,1}},{"Hot Pink",{1,.4,.75}},
	{"Gold",{1,.8,.25}},{"Royal Purple",{.75,.5,1}},{"Blood Red",{1,.25,.2}},
}

function PicklerIcon(name)
	local ok,ic=pcall(function() return Icon[name] end)
	if ok and type(ic)=="string" then return ic.." " end
	return ""
end

-- accent colour, k = brightness
function PicklerAccent(k)
	local a=PICKLER_ACCENTS[math.clamp(math.floor(config.uiAccent or 1),1,#PICKLER_ACCENTS)][2]
	k=k or 1
	return LinearColor.new(a[1]*k,a[2]*k,a[3]*k,1)
end

function PicklerUiColorText(col,txt)
	local ok=pcall(function() Gui.textColored(col,txt) end)
	if not ok then Gui.text(txt) end
end

function PicklerUiTip(txt)
	pcall(function() Gui.setItemTooltip(txt) end)
end

function PicklerUiHeader(title)
	Gui.newLine()
	local ok=pcall(function() Gui.separatorText(title) end)
	if not ok then Gui.text("=== "..title.." "..string.rep("=",math.max(2,32-#title))) end
end

function PicklerUiHint(text)
	local ok=pcall(function() Gui.textDisabled("   "..text) end)
	if not ok then Gui.text("   "..text) end
end

-- the top of the menu: title, creator, and a live status line
function PicklerUiTitle()
	local pulse=.8+.2*math.sin(totalTime*2.5)
	PicklerUiColorText(PicklerAccent(pulse),PicklerIcon("Crown").." P I C K L E R   C A S T I N G   v"..PICKLER_VERSION)
	Gui.sameLine()
	PicklerUiHint("by "..PICKLER_CREATOR)
	local arena=selectedArena and selectedArena.name or "no arena"
	local line=PicklerIcon("Video")..PicklerCamLabel().."     "..PicklerIcon("LocationArrow")..arena
	if selectedArena then
		line=line..string.format("     %d - %d",selectedArena.home.score or 0,selectedArena.away.score or 0)
	end
	Gui.text(line)
	-- frame rate in green / yellow / red, then what's switched on
	local fps=(dt and dt>0) and math.floor(1/dt+.5) or 0
	local fc=(fps>=60) and LinearColor.new(.4,1,.4,1) or ((fps>=30) and LinearColor.new(1,.85,.3,1) or LinearColor.new(1,.35,.3,1))
	if config.uiAdvanced then PicklerUiColorText(fc,fps.." fps") end
	local bits={}
	if goalFx.active then bits[#bits+1]=PicklerIcon("Play").."goal FX playing" end
	if config.shEnabled then bits[#bits+1]="shader: "..(PICKLER_SHADER_NAMES[config.shPreset or 1] or "custom") end
	if (config.audioMode or 0)==1 then bits[#bits+1]="voice: all muted"
	elseif (config.audioMode or 0)==2 then bits[#bits+1]="voice: arena only" end
	if #bits>0 then
		PicklerUiHint(table.concat(bits,"   |   "))
	end
end

-- =====================================================================================
-- PRESETS: save your whole setup into a slot, load it back later, give each slot a name.
-- A slot stores every number / on-off / text setting as one string inside the config, so it
-- is saved to disk together with your normal settings.
-- =====================================================================================
PICKLER_PRESET_COUNT=6
PICKLER_PRESET_NAMES={"Match Day","Chill","Hype","Clean","Pickler","Night Game","Stream","Training",
	"Replay","Highlights","Finals","Casual","Smooth","Fast","Cinematic","Favorite","Backup","Test","Spicy","Zen"}
PicklerPresetStatus=""

function PicklerPresetEsc(sv)
	sv=sv:gsub("%%","%%25")
	sv=sv:gsub("|","%%7C")
	sv=sv:gsub("=","%%3D")
	return sv
end

function PicklerPresetUnesc(sv)
	sv=sv:gsub("%%7C","|")
	sv=sv:gsub("%%3D","=")
	sv=sv:gsub("%%25","%%")
	return sv
end

function PicklerPresetSnapshot()
	local parts={}
	for k,v in pairs(config) do
		if type(k)=="string" and k:sub(1,6)~="preset" and k~="version" and k~="clipCount" then
			local tv=type(v)
			if tv=="number" then parts[#parts+1]=k.."=n:"..tostring(v)
			elseif tv=="boolean" then parts[#parts+1]=k.."=b:"..(v and "1" or "0")
			elseif tv=="string" then parts[#parts+1]=k.."=s:"..PicklerPresetEsc(v) end
		end
	end
	table.sort(parts)
	return table.concat(parts,"|")
end

function PicklerPresetApply(data)
	local n=0
	for item in string.gmatch(data,"[^|]+") do
		local eq=item:find("=",1,true)
		if eq then
			local k=item:sub(1,eq-1)
			local t=item:sub(eq+1,eq+1)
			local val=item:sub(eq+3)
			local cur=config[k]
			if cur~=nil and k:sub(1,6)~="preset" and k~="version" then
				if t=="n" and type(cur)=="number" then
					local x=tonumber(val)
					if x then config[k]=x; n=n+1 end
				elseif t=="b" and type(cur)=="boolean" then
					config[k]=(val=="1"); n=n+1
				elseif t=="s" and type(cur)=="string" then
					config[k]=PicklerPresetUnesc(val); n=n+1
				end
			end
		end
	end
	return n
end

function PicklerPresetsUi()
	PicklerUiHeader("MY PRESETS")
	PicklerUiHint("A preset remembers your whole setup: camera, trail,")
	PicklerUiHint("celebrations, everything. Make a few and swap any time.")
	local sel=math.clamp(math.floor(config.presetSel or 1),1,PICKLER_PRESET_COUNT)
	local function label(i)
		local nm=config["presetName"..i] or ("Preset "..i)
		local empty=((config["presetData"..i] or "")=="") and "  (empty)" or ""
		return i..")  "..nm..empty
	end
	if Gui.beginCombo("Slot##vxPresetSlot",label(sel)) then
		for i=1,PICKLER_PRESET_COUNT do
			if Gui.selectable(label(i).."##vxPSlot"..i,sel==i) then config.presetSel=i; sel=i end
		end
		Gui.endCombo()
	end
	Gui.newLine()
	if Gui.button("SAVE MY SETUP HERE##vxPSave") then
		config["presetData"..sel]=PicklerPresetSnapshot()
		saveConfig()
		PicklerPresetStatus="Saved your setup to slot "..sel
	end
	if Gui.button("LOAD THIS SLOT##vxPLoad") then
		local data=config["presetData"..sel] or ""
		if data=="" then
			PicklerPresetStatus="Slot "..sel.." is empty - save something into it first"
		else
			local n=PicklerPresetApply(data)
			saveConfig()
			PicklerPresetStatus="Loaded slot "..sel.." ("..n.." settings applied)"
		end
	end
	Gui.sameLine()
	if Gui.button("CLEAR THIS SLOT##vxPClear") then
		config["presetData"..sel]=""
		config["presetName"..sel]="Preset "..sel
		saveConfig()
		PicklerPresetStatus="Cleared slot "..sel
	end
	if PicklerPresetStatus~="" then Gui.text(PicklerPresetStatus) end
	PicklerUiHint("Loading replaces your current settings, so save first if")
	PicklerUiHint("you want to keep them.")

	PicklerUiHeader("NAME THIS PRESET")
	local hasInput=false
	pcall(function() hasInput=(Gui.inputText~=nil) end)
	local typed=false
	if hasInput then
		local ok,res=pcall(function() return Gui.inputText("Name##vxPName",config["presetName"..sel] or "") end)
		if ok and type(res)=="string" then
			config["presetName"..sel]=res:sub(1,24)
			typed=true
		end
	end
	if not typed then
		if Gui.beginCombo("Pick a name##vxPNames",config["presetName"..sel] or ("Preset "..sel)) then
			for ni,nm in ipairs(PICKLER_PRESET_NAMES) do
				if Gui.selectable(nm.."##vxPN"..ni,(config["presetName"..sel]==nm)) then config["presetName"..sel]=nm end
			end
			Gui.endCombo()
		end
	end
	if Gui.button("RESET NAME##vxPNameReset") then config["presetName"..sel]="Preset "..sel end
	PicklerUiSave()
end

-- tab button; the active tab is wrapped in > <
-- tab button with an icon; the open tab is drawn in the accent colour
function PicklerUiTab(label,page,id,icon,tip)
	local txt=PicklerIcon(icon or "")..label
	local clicked=false
	if PicklerCasterPage==page then
		local ok,res=pcall(function() return Gui.buttonColored(PicklerAccent(.85),txt.."##"..id) end)
		if ok then clicked=res else clicked=Gui.button(">"..txt.."<##"..id) end
	else
		clicked=Gui.button(txt.."##"..id)
	end
	if tip then PicklerUiTip(tip) end
	return clicked
end

PicklerSaveTime=-99

function PicklerUiSave()
	Gui.newLine()
	local ok,res=pcall(function() return Gui.buttonColored(LinearColor.new(.2,.65,.3,1),PicklerIcon("Save").."SAVE SETTINGS##vxSave") end)
	local clicked=false
	if ok then clicked=res else clicked=Gui.button("SAVE SETTINGS##vxSave") end
	if clicked then
		PicklerCasterSave()
		PicklerSaveTime=totalTime
	end
	PicklerUiTip("Saves every setting so it's the same next time you load the script")
	if PicklerCasterSaveText~="" and totalTime-PicklerSaveTime<3 then
		Gui.sameLine()
		local good=PicklerCasterSaveText=="SAVED"
		PicklerUiColorText(good and LinearColor.new(.4,1,.4,1) or LinearColor.new(1,.35,.3,1),
			(good and PicklerIcon("Check") or "")..PicklerCasterSaveText)
	end
end

-- play a goal celebration at the goal (optionally a specific type) and fly the camera there
function PicklerPlayGoalFx(typeOverride)
	GFX_LAST_ERROR=nil
	goalFx.freeFrame=nil
	goalFx.active=true
	goalFx.preview=true
	goalFx.typeOverride=typeOverride
	goalFx.startTime=totalTime
	-- no arena, or its goal hasn't loaded: goalFxFrame plays it in front of the camera instead
	goalFx.goal=selectedArena and selectedArena.away.goal or nil
	if goalFx.goal and not goalFx.goal.position then goalFx.goal=nil end
	goalFx.scorerName=config.deathNoteTestName   -- previews write this name in the Death Note
	-- The preview camera is a separate pseudo-mode (see goalFxPreviewCamWanted): the active casting
	-- camera, its mode and the free cam are never touched. Only remember the view to come back to.
	if not goalFx.previewSnap then
		goalFx.previewSnap={pos=camPos,rot=camRot,fov=camFOV,target=targetFOV}
	end
end

function PicklerStopPreview()
	if goalFx.active and goalFx.preview then
		goalFx.active=false
		GFX.stop()
	end
end

function goalFxPreviewCamWanted()
	if not config.goalFxTestFreeCam then return false end
	if not goalFx.active or not goalFx.preview or not goalFx.goal or not selectedArena then return false end
	if curMode==Mode.KEYFRAME and kfState.isPlaying then return false end
	return true
end

-- =====================================================================================
-- QUALITY TAB: in-game "shaders" (the game's own post-processing) and overall quality
-- Shader values live in config (sh*). While shaders are on they are pushed to the game every
-- frame (so other effects that tweak post-process for a moment hand back to them); when they
-- are switched off the game gets its own defaults back once.
-- =====================================================================================
PICKLER_SHADER_NAMES={"Game default (off)","Broadcast Clean","Esports Sharp","Cinematic","Vivid Pop",
	"Moody Night","Dreamy Glow","Retro Lens"}
PICKLER_SHADERS={
	{off=true},
	{bloom=.35,thr=-1,exp=0,vig=.2,chroma=0,motion=0,dof=false},
	{bloom=.1,thr=-1,exp=.1,vig=0,chroma=0,motion=0,dof=false},
	{bloom=.8,thr=-1,exp=-.2,vig=.55,chroma=.3,motion=.35,dof=true,fstop=2.8},
	{bloom=1.2,thr=-1,exp=.3,vig=.25,chroma=0,motion=0,dof=false},
	{bloom=.9,thr=-1,exp=-.9,vig=.85,chroma=.2,motion=.2,dof=false},
	{bloom=3,thr=-1,exp=.1,vig=.4,chroma=.6,motion=.3,dof=true,fstop=4},
	{bloom=.6,thr=-1,exp=0,vig=1,chroma=2.5,motion=0,dof=false},
}
PicklerShaderOn=false

function PicklerApplyShaderPreset(i)
	config.shPreset=i
	local p=PICKLER_SHADERS[i]
	if not p or p.off then
		config.shEnabled=false
		return
	end
	config.shEnabled=true
	config.shBloom,config.shBloomThreshold,config.shExposure=p.bloom,p.thr,p.exp
	config.shVignette,config.shChroma,config.shMotion=p.vig,p.chroma,p.motion
	config.shDof=p.dof
	if p.fstop then config.shDofFstop=p.fstop end
end

function PicklerShaderTick()
	if config.shEnabled then
		pcall(function()
			local pp=postProcessSettings
			pp.bloomIntensity=config.shBloom or .675
			pp.bloomThreshold=config.shBloomThreshold or -1
			pp.autoExposureBias=config.shExposure or 0
			pp.vignetteIntensity=config.shVignette or .4
			pp.chromaticAberrationIntensity=config.shChroma or 0
			pp.motionBlurAmount=config.shMotion or 0
			if config.shDof then
				-- auto focus: on the goal while a goal explosion plays, otherwise on the ball
				local dist=config.shDofDist or 1000
				if config.shDofAuto~=false then
					if goalFx.active and goalFx.goal then
						dist=(goalFx.goal.position-camPos):length()
					elseif selectedArena and selectedArena.ball then
						dist=(selectedArena.ball.transform.position-camPos):length()
					end
				end
				pp.depthOfFieldFocalDistance=math.max(dist,10)
				pp.depthOfFieldFstop=config.shDofFstop or 2.8
				pp.depthOfFieldSensorWidth=config.shDofSensor or 24.576
			else
				pp.depthOfFieldFocalDistance=0
			end
		end)
		PicklerShaderOn=true
	elseif PicklerShaderOn then
		pcall(function() postProcessSettings:reset() end)
		PicklerShaderOn=false
	end
end

-- one click sets everything to suit the PC: 1 Potato .. 5 Ultra
PICKLER_QUALITY_NAMES={"Potato","Low","Medium","High","Ultra"}

function PicklerApplyQuality(i)
	config.qualityPreset=i
	config.goalFxQuality=({1,1,2,3,4})[i]
	config.goalFxLights=i>=3
	config.goalFxShake=i>=2
	config.kickoffFxEnabled=i>=2
	config.yukiTrailSeconds=({.08,.12,.15,.15,.2})[i]
	config.goalFxGlow=({1.2,1.4,1.6,1.6,1.8})[i]
	if i<=2 then
		-- depth of field and motion blur are the most expensive post effects
		config.shDof=false
		config.shMotion=0
	end
end

function PicklerQualityUi(adv)
	PicklerUiHeader("OVERALL QUALITY")
	PicklerUiHint("One click sets everything below. Lower = smoother if the game stutters.")
	for i,name in ipairs(PICKLER_QUALITY_NAMES) do
		if i>1 then Gui.sameLine() end
		local shown=(config.qualityPreset==i) and (">"..name.."<") or name
		if Gui.button(shown.."##vxQ"..i) then PicklerApplyQuality(i) end
	end

	PicklerUiHeader("GOAL EXPLOSIONS")
	config.goalFxQuality=math.clamp(math.floor(config.goalFxQuality or 3),1,4)
	if Gui.beginCombo("Particle quality##vxGoalQ",GFX_QUALITY_NAMES[config.goalFxQuality]) then
		for i,name in ipairs(GFX_QUALITY_NAMES) do
			if Gui.selectable(name.."##vxGoalQ"..i,config.goalFxQuality==i) then config.goalFxQuality=i end
		end
		Gui.endCombo()
	end
	uiSlider("Glow brightness##vxGoalGlow","goalFxGlow",.5,3)
	uiCheck("Light up the arena with real lights##vxGoalLights","goalFxLights")
	uiCheck("Camera shake on big hits##vxGoalShake","goalFxShake")
	uiCheck("Kickoff explosion##vxQKick","kickoffFxEnabled")
	Gui.text(string.format("Particles right now: %d / %d    Lights: %d",#GFX.parts,GFX.cap or 0,#GFX.lights))

	PicklerUiHeader("BALL TRAIL")
	uiSlider("Trail length (seconds)##vxQTrailLen","yukiTrailSeconds",.05,.6)
	uiSlider("Trail thickness##vxQTrailThick","yukiTrailThick",4,40)

	PicklerUiHeader("IN-GAME SHADERS")
	PicklerUiHint("Uses the game's own post-processing. 'Game default' turns it off.")
	local cur=math.clamp(math.floor(config.shPreset or 1),1,#PICKLER_SHADER_NAMES)
	if Gui.beginCombo("Shader preset##vxShPreset",PICKLER_SHADER_NAMES[cur]) then
		for i,name in ipairs(PICKLER_SHADER_NAMES) do
			if Gui.selectable(name.."##vxSh"..i,cur==i) then PicklerApplyShaderPreset(i) end
		end
		Gui.endCombo()
	end
	if config.shEnabled then
		PicklerUiHint("(pick a preset, then fine-tune it here)")
		uiSlider("Bloom (glow)##vxShBloom","shBloom",0,5)
		uiSlider("Brightness (exposure)##vxShExp","shExposure",-3,3)
		uiSlider("Vignette (dark edges)##vxShVig","shVignette",0,1)
		uiSlider("Lens colour fringe##vxShCA","shChroma",0,5)
		uiSlider("Motion blur##vxShMB","shMotion",0,1)
		uiCheck("Depth of field (blurry background)##vxShDof","shDof")
		if config.shDof then
			uiSlider("Blur strength (lower = blurrier)##vxShF","shDofFstop",1.2,16)
			uiCheck("Auto focus on the ball##vxShAF","shDofAuto")
			if not config.shDofAuto then uiSlider("Focus distance##vxShFD","shDofDist",100,6000) end
		end
		if adv then
			uiSlider("Bloom threshold##vxShThr","shBloomThreshold",-1,8)
			uiSlider("Camera sensor width##vxShSW","shDofSensor",5,50)
		end
		if Gui.button("BACK TO GAME DEFAULT##vxShOff") then PicklerApplyShaderPreset(1) end
	end
	if config.yukiPostFx and (config.camProfile or 1)==3 then
		PicklerUiHint("Note: 'Yuki's camera look' is on, so it sets bloom and brightness")
		PicklerUiHint("while the Yuki camera is in use.")
	end
end

-- =====================================================================================
-- AUDIO TAB: voice chat. The game only lets scripts mute/unmute players' voice chat
-- (Settings.mutePlayerByName); the announcer, game sounds and volume can't be changed from a
-- script. A mode can be kept applied so players who join later get muted too.
-- audioMode: 0 = leave alone, 1 = everyone muted, 2 = only the selected arena can be heard
-- =====================================================================================
PicklerAudio={muted={},lastApply=-99,modeApplied=0}

function PicklerMute(name,mute)
	if not name or name=="" then return false end
	local ok,res=pcall(function() return Settings.mutePlayerByName(name,mute) end)
	if ok then PicklerAudio.muted[name]=mute and true or nil end
	return ok and res
end

-- players on the live server (replays have no voice chat); skips players whose name hasn't loaded
function PicklerLivePlayers()
	local list={}
	pcall(function()
		for _,p in ipairs(getGameData().players) do
			if p.playerName and p.playerName~="" and p.playerName~=tostring(p.playerId) then list[#list+1]=p end
		end
	end)
	return list
end

function PicklerArenaNames()
	local set={}
	if selectedArena then
		for _,p in ipairs(selectedArena.players) do
			if p.playerName then set[p.playerName]=true end
		end
	end
	return set
end

function PicklerMuteAll(mute)
	for _,p in ipairs(PicklerLivePlayers()) do PicklerMute(p.playerName,mute) end
end

function PicklerAudioTick()
	local mode=config.audioMode or 0
	if mode==0 then
		if PicklerAudio.modeApplied~=0 then
			-- a mode was just switched off: give everyone their voice back
			PicklerMuteAll(false)
			PicklerAudio.modeApplied=0
		end
		return
	end
	-- re-apply every 2 s so people who join (or move arena) are handled too
	if totalTime-PicklerAudio.lastApply<2 and PicklerAudio.modeApplied==mode then return end
	PicklerAudio.lastApply=totalTime
	PicklerAudio.modeApplied=mode
	local arena=(mode==2) and PicklerArenaNames() or nil
	for _,p in ipairs(PicklerLivePlayers()) do
		local want=true
		if arena and arena[p.playerName] then want=false end
		if (PicklerAudio.muted[p.playerName] or false)~=want then PicklerMute(p.playerName,want) end
	end
end

function PicklerAudioUi()
	PicklerUiHeader("VOICE CHAT")
	PicklerUiHint("Mute players' voice chat while you cast. (Live only: replays have no voice.)")
	local mode=config.audioMode or 0
	local function modeBtn(label,m,id)
		local shown=(mode==m) and (">"..label.."<") or label
		if Gui.button(shown.."##"..id) then
			config.audioMode=m
			PicklerAudio.lastApply=-99
		end
	end
	modeBtn("NORMAL",0,"vxAuNone")
	Gui.sameLine()
	modeBtn("MUTE EVERYONE",1,"vxAuAll")
	Gui.sameLine()
	modeBtn("ONLY HEAR THIS ARENA",2,"vxAuArena")
	if mode==1 then PicklerUiHint("Everyone is muted, including people who join later.")
	elseif mode==2 then PicklerUiHint("Only players in the arena you're casting can be heard.")
	else PicklerUiHint("Nothing is changed automatically.") end

	PicklerUiHeader("ONE-OFF")
	if Gui.button("MUTE THIS ARENA##vxAuMuteArena") then
		for name in pairs(PicklerArenaNames()) do PicklerMute(name,true) end
	end
	Gui.sameLine()
	if Gui.button("UNMUTE EVERYONE##vxAuUnmuteAll") then
		config.audioMode=0
		PicklerAudio.modeApplied=0
		PicklerMuteAll(false)
	end

	PicklerUiHeader("PLAYERS")
	local list=PicklerLivePlayers()
	if #list==0 then
		Gui.text("(no live players found)")
	else
		local inArena=PicklerArenaNames()
		for i,p in ipairs(list) do
			local muted=PicklerAudio.muted[p.playerName]
			local tag=inArena[p.playerName] and "  [arena]" or ""
			if Gui.button((muted and "UNMUTE" or "MUTE").."##vxAuP"..i) then PicklerMute(p.playerName,not muted) end
			Gui.sameLine()
			Gui.text((muted and "(muted) " or "")..p.playerName..tag)
		end
		if mode~=0 then PicklerUiHint("(the mode above will re-apply itself every couple of seconds)") end
	end

	PicklerUiHeader("ANNOUNCER AND GAME SOUND")
	PicklerUiHint("No known script control for the announcer, game sounds or volume yet.")
	PicklerUiHint("Use the game's own audio settings for those for now.")
	if config.uiAdvanced then
		PicklerUiHeader("ADVANCED: FIND AUDIO CONTROLS")
		PicklerUiHint("Lists everything the game's Settings object offers, plus anything named")
		PicklerUiHint("like audio / sound / volume / announcer. If an announcer or volume control")
		PicklerUiHint("exists it will show up here (and in the log), so it can be hooked up.")
		if Gui.button(PicklerIcon("Search").."SCAN FOR AUDIO CONTROLS##vxAuScan") then PicklerAudioScan() end
		local res=PicklerAudio.scan
		if res then
			if #res==0 then
				Gui.text("Nothing found: the game doesn't expose any audio controls to scripts.")
			else
				Gui.text(#res.." found (also printed to the log):")
				for _,s in ipairs(res) do
					local hit=PicklerAudio.scanHits[s]
					if hit then PicklerUiColorText(PicklerAccent(1),"  "..s) else PicklerUiHint(s) end
				end
			end
		end
	end
end

-- looks for any audio controls the game might expose to scripts; anything audio-sounding is
-- highlighted. Read-only: it only lists names, it never calls them.
function PicklerAudioScan()
	local found,seen,hits={},{},{}
	local function add(s)
		if seen[s] then return end
		seen[s]=true
		found[#found+1]=s
		local n=string.lower(s)
		if string.find(n,"audio") or string.find(n,"sound") or string.find(n,"volume") or string.find(n,"announc")
			or string.find(n,"mute") or string.find(n,"voice") or string.find(n,"sfx") or string.find(n,"music") then
			hits[s]=true
		end
	end
	local function scanTable(prefix,t)
		pcall(function()
			for k,v in pairs(t) do add(prefix..tostring(k).."  ("..type(v)..")") end
		end)
	end
	-- the Settings object itself, and what its metatable exposes
	scanTable("Settings.",Settings)
	pcall(function()
		local mt=getmetatable(Settings)
		if type(mt)=="table" and type(mt.__index)=="table" then scanTable("Settings.",mt.__index) end
	end)
	-- any global whose name sounds like audio
	pcall(function()
		for k,v in pairs(getfenv and getfenv(0) or _G) do
			local n=string.lower(tostring(k))
			if string.find(n,"audio") or string.find(n,"sound") or string.find(n,"volume") or string.find(n,"announc") then
				add(tostring(k).."  ("..type(v)..")")
				if type(v)=="table" then scanTable(tostring(k)..".",v) end
			end
		end
	end)
	-- the one audio call we already know about, so the list is never misleadingly empty
	pcall(function()
		if Settings.mutePlayerByName then add("Settings.mutePlayerByName  (function)") end
	end)
	table.sort(found)
	PicklerAudio.scan=found
	PicklerAudio.scanHits=hits
	for _,s in ipairs(found) do print("[Pickler audio scan] "..s) end
end

-- EFFECTS tab pages -----------------------------------------------------------------------
function PicklerFxExplosionsPage(adv)
	uiCheck("Play a celebration when a goal is scored##vxGoalEn","goalFxEnabled")
	PicklerUiHeader("CHOOSE AN EXPLOSION")
	PicklerGoalFxBrowser()
	Gui.newLine()
	if Gui.collapsingHeader("Goal camera##vxFxHCam") then
		Gui.indent()
		uiCheck("Move the camera in front of the goal on a score##vxGoalAC","goalFxAutoCam")
		uiCheck("Show TEST previews from the goal camera##vxGoalFCT","goalFxTestFreeCam")
		PicklerUiTip("Your casting camera is left alone and comes back exactly as it was when the preview ends")
		uiSlider("Distance (further = see more)##vxGoalCamD","goalFxFreeCamDist",300,2000)
		uiSlider("Height##vxGoalCamH","goalFxCamHeight",-100,500)
		uiSlider("Zoom (higher = wider)##vxGoalCamF","goalFxCamFOV",60,130)
		Gui.unindent()
	end
	if Gui.collapsingHeader("Position and timing##vxFxHPos") then
		Gui.indent()
		uiSlider("Size##vxGoalSize","goalFxSize",.6,1.7)
		uiSlider("Move left / right##vxGoalOX","goalFxTextOffsetX",-300,300)
		uiSlider("Height##vxGoalOY","goalFxTextOffsetY",-100,400)
		if Gui.button("RESET POSITION##vxGoalPosReset") then
			config.goalFxTextOffsetX=0
			config.goalFxTextOffsetY=110
			config.goalFxSize=1
		end
		uiSlider("How long it lasts##vxGoalDur","goalFxDuration",2,6)
		PicklerUiHint("Particle quality, glow, lights and camera shake are in the QUALITY tab.")
		Gui.unindent()
	end
	if Gui.collapsingHeader("Death Note##vxFxHDn") then
		Gui.indent()
		PicklerUiHint("Writes the scorer's name, about 5 s. 'Size' scales it; 'How long it lasts' doesn't apply.")
		pcall(function()
			local res=Gui.inputText("Name to write when testing##vxDnName",config.deathNoteTestName or "")
			if type(res)=="string" then config.deathNoteTestName=res:sub(1,24) end
		end)
		uiCheck("Dim the scene + vignette while it plays##vxDnDim","deathNoteDim")
		if Gui.button("PLAY DEATH NOTE##vxDnPlay") then PicklerPlayGoalFx(GFX_DEATHNOTE) end
		Gui.unindent()
	end
	if Gui.collapsingHeader("Preview tools##vxFxHTools") then
		Gui.indent()
		uiCheck("Loop the preview##vxGoalLoop","goalFxTestLoop")
		uiCheck("Allow bright flashes##vxGoalFlash","goalFxFlash")
		PicklerUiTip("Off = flashes are softened so nothing blinds the screen")
		if Gui.button("FREE CAM AT GOAL##vxGoalFC") then goalFxOpenFreeCam() end
		Gui.sameLine()
		if Gui.button("EXIT FREE CAM##vxGoalFCX") then goalFxCloseFreeCam() end
		PicklerUiHint("Free cam: WASD move, Q/E down/up, arrows look, Shift/Ctrl speed")
		if adv then
			Gui.newLine()
			Gui.text("Play any celebration without changing your pick:")
			for i,name in ipairs(GOAL_FX_TYPES) do
				if Gui.button("PLAY: "..name.."##vxGoalPlay"..i) then PicklerPlayGoalFx(i) end
			end
		end
		Gui.unindent()
	end
	if adv and Gui.collapsingHeader("Celebration color mix##vxFxHCol") then
		Gui.indent()
		uiSlider("Red##vxGoalR","goalFxColorR",0,1)
		uiSlider("Green##vxGoalG","goalFxColorG",0,1)
		uiSlider("Blue##vxGoalB","goalFxColorB",0,1)
		Gui.unindent()
	end
end

function PicklerFxTrailsPage()
	uiCheck("Show a trail behind the ball##vxTrailEn","ballTrailEnabled")
	if not config.ballTrailEnabled then return end
	-- two sections with the same themes: Pixelated (Yuki's line trail) and Beam (glowing ribbon)
	local mode=math.floor(config.ballTrailMode or 1)
	local cur=math.floor(config.ballTrailStyle or 1)
	local preview=((mode==2) and "Beam: " or "Pixelated: ")..(BALL_TRAIL_STYLES[cur] or BALL_TRAIL_STYLES[1])
	if Gui.beginCombo("Trail style##vxTrailTheme",preview) then
		for sec=1,2 do
			local title=(sec==1) and "Pixelated Trails" or "Beam Trails"
			local ok=pcall(function() Gui.separatorText(title) end)
			if not ok then Gui.text("[ "..title.." ]") end
			for i,name in ipairs(BALL_TRAIL_STYLES) do
				if Gui.selectable(name.."##vxTrail"..sec.."_"..i,mode==sec and cur==i) then
					config.ballTrailStyle=i
					config.ballTrailMode=sec
					resetBallTrail()
				end
			end
		end
		Gui.endCombo()
	end
	uiSlider("Trail length (seconds)##vxYtLen","yukiTrailSeconds",.05,.6)
	uiSlider("Trail thickness##vxYtThick","yukiTrailThick",4,40)
	if math.floor(config.ballTrailMode or 1)==2 then
		uiSlider("Beam width##vxYtBeamW","yukiBeamWidth",.2,2)
	end
	uiSlider("Brightness##vxYtGlow","yukiTrailGlow",.5,3)
	PicklerUiHint("Pixelated = Yuki's line trail, Beam = a smooth glowing ribbon. Same themes in both.")
	if math.floor(config.ballTrailStyle or 1)==1 then
		PicklerUiHint("Yuki Classic follows the team that last had the ball (red/yellow otherwise).")
	end
end

function PicklerFxKickoffPage()
	PicklerUiHeader("CAMERA")
	uiSlider("Move camera back##vxKickBack","kickCamBack",0,1200)
	PicklerUiTip("Eases the camera back while the ball waits in the middle, on any camera style. 0 = off")
	PicklerUiHeader("COUNTDOWN")
	uiCheck("Show a countdown when the ball is in the middle##vxKickCnt","kickCountEnabled")
	PicklerUiTip("Uses the game's own kickoff timer")
	if config.kickCountEnabled~=false then
		uiCheck("Show the numbers and GO!##vxKickNum","kickCountNumbers")
		uiCheck("Show the ring on the floor##vxKickRing","kickCountRing")
		uiSlider("Start counting from (seconds)##vxKickFrom","kickCountFrom",1,10)
		uiSlider("Number height##vxKickH","kickCountHeight",60,500)
	end
	PicklerUiHeader("GO BURST")
	uiCheck("Play a burst when the ball goes live##vxKickEn","kickoffFxEnabled")
	uiSlider("Burst length (seconds)##vxKickDur","kickoffFxDuration",.5,4)
	PicklerUiHeader("LOOK")
	uiSlider("Size##vxKickSize","kickoffFxSize",.4,2.5)
	local cur=math.floor(config.kickFxColor or 1)
	if Gui.beginCombo("Colour##vxKickCol",(PICKLER_KICK_COLORS[cur] or PICKLER_KICK_COLORS[1])[1]) then
		for i,e in ipairs(PICKLER_KICK_COLORS) do
			if Gui.selectable(e[1].."##vxKickCol"..i,cur==i) then config.kickFxColor=i end
		end
		Gui.endCombo()
	end
	Gui.newLine()
	if Gui.button("TEST COUNTDOWN##vxKickTest") then PicklerKickTest() end
end

-- PLAYER tab: first / third person
function PicklerPlayerViewUi(adv)
	PicklerUiHeader("VIEW")
	local view=config.pfView or 1
	local function viewBtn(label,v,id)
		local ok,res=pcall(function()
			if view==v then return Gui.buttonColored(PicklerAccent(.85),label.."##"..id) end
			return Gui.button(label.."##"..id)
		end)
		if ok and res then PicklerSetPlayerView(v) end
	end
	viewBtn("THIRD PERSON",1,"vxViewTP")
	Gui.sameLine()
	viewBtn("FIRST PERSON",2,"vxViewFP")
	PicklerUiHint("Press V to swap.")
	local hasFollow=PicklerFollowInit()
	if adv then
		if hasFollow then
			PicklerUiColorText(LinearColor.new(.4,1,.5,1),"Follow+ found")
		else
			PicklerUiColorText(LinearColor.new(1,.65,.35,1),"Follow+ not found: using the built-in camera")
		end
		local engines={"Follow+ when installed","Always built-in"}
		local eng=config.followEngine or 1
		if Gui.beginCombo("Camera engine##vxViewEng",engines[eng] or engines[1]) then
			for i,nm in ipairs(engines) do
				if Gui.selectable(nm.."##vxViewEng"..i,eng==i) then config.followEngine=i end
			end
			Gui.endCombo()
		end
	end
	local usesFollow=hasFollow and (config.followEngine or 1)==1
	if view==2 then
		uiSlider("First person field of view##vxViewFov","firstPersonFOV",60,170)
		if adv and selectedArena then
			-- the head nearest the camera should be the followed player, at about 0
			local list={}
			for _,p in ipairs(selectedArena.players) do
				list[#list+1]={n=tostring(p.playerName),d=dist(p.head.position,camPos)}
			end
			table.sort(list,function(a,b) return a.d<b.d end)
			local txt="Nearest heads:"
			for i=1,math.min(2,#list) do txt=txt.."  "..list[i].n.." "..math.floor(list[i].d) end
			PicklerUiHint(txt)
		end
		return
	end
	local styles={"Chase","Behind their head","Along their movement","Facing the ball"}
	local style=config.pfThirdStyle or 1
	if Gui.beginCombo("Third person style##vxViewStyle",styles[style] or styles[1]) then
		for i,nm in ipairs(styles) do
			if Gui.selectable(nm.."##vxViewStyle"..i,style==i) then config.pfThirdStyle=i end
		end
		Gui.endCombo()
	end
	if style>1 then
		if usesFollow then
			uiSlider("Distance##vxViewRad","followRadius",0,100)
			uiSlider("Position smoothing##vxViewPos","followPosSmooth",0,1)
			uiSlider("Field of view##vxViewTpFov","tpFOV",60,140)
		else
			PicklerUiHint("These styles need Follow+. Using Pickler chase instead.")
		end
	end
	if style==1 or not usesFollow then
		PicklerUiHeader("FRAMING")
		uiSlider("How far back##vxTpDist","tpDist",50,600)
		uiSlider("How high##vxTpHeight","tpHeight",0,400)
		uiSlider("Field of view##vxTpFov","tpFOV",60,140)
		if adv then
			PicklerUiHeader("SMOOTHING")
			uiSlider("Position smoothing##vxTpPos","tpSmooth",1,40)
			uiSlider("Rotation smoothing##vxTpRot","tpRotSmooth",1,40)
			uiSlider("Direction smoothing##vxTpDir","tpDirSmooth",1,40)
		end
	end
end

-- MENU HELPERS ------------------------------------------------------------------------------
-- a button that lights up in the accent colour when it's the current choice
function PicklerChoiceBtn(label,on,id,tip)
	local ok,res=pcall(function()
		if on then return Gui.buttonColored(PicklerAccent(.85),label.."##"..id) end
		return Gui.button(label.."##"..id)
	end)
	if tip then PicklerUiTip(tip) end
	return ok and res
end

function PicklerUseAutoCam()
	PicklerEnterCaster()
end

function PicklerUsePlayerCam()
	PicklerCasterMode="player"
	caster.freecamActive=false
	curMode=Mode.PFOLLOW
	playerFollow.enabled=true
	config.playerFollowEnabled=true
end

function PicklerUseFreeCam()
	PicklerCasterMode="caster"
	local e=camRot:euler()
	caster.pos=camPos
	caster.fov=camFOV
	caster.pitch=math.clamp(e.y,-89,89)
	caster.yaw=e.z
	curMode=Mode.CASTER
	caster.freecamActive=true
end

-- which of the three camera choices is on: "auto", "player" or "free"
function PicklerCamChoice()
	if curMode==Mode.PFOLLOW then return "player" end
	if curMode==Mode.CASTER and caster.freecamActive then return "free" end
	return "auto"
end

-- one line of the START checklist: a tick, what it is, what's chosen, and a button to change it
function PicklerStartStep(n,done,title,detail,btn,id,page)
	local col=done and LinearColor.new(.4,1,.5,1) or LinearColor.new(1,.75,.3,1)
	PicklerUiColorText(col,(done and "[OK]  " or "[ ! ]  ")..n..". "..title)
	if btn then
		Gui.sameLine()
		if Gui.smallButton(btn.."##"..id) then PicklerCasterPage=page end
	end
	PicklerUiHint(detail)
	Gui.spacing()
end

function PicklerQuickSetup(kind)
	if kind=="rec" then
		PicklerApplyPlutusPreset()
		config.goalFxEnabled=true
		config.goalFxAutoCam=true
		config.goalFxType=GOALFX_SHUFFLE
		config.ballTrailEnabled=true
		config.ballTrailMode=2
	elseif kind=="clean" then
		PicklerApplyZepyPreset()
		config.goalFxEnabled=false
		config.goalFxAutoCam=false
		config.ballTrailEnabled=false
	elseif kind=="low" then
		config.goalFxQuality=1
		config.goalFxLights=false
		config.ballTrailMode=1
	else
		config.goalFxFlash=false
		config.goalFxShake=false
	end
	pcall(saveConfig)
end

PICKLER_STYLE_INFO={
	"Swings around behind the ball. A good all-rounder: start with this one.",
	"TV-style. Backs off when players crowd together and looks toward the goals.",
	"Runs along the sideline and zooms to keep the ball the same size.",
	"Sits behind whoever has the ball, and chases the ball when it's loose.",
}

function onGui()
	PicklerUiTitle()

	if PicklerChoiceBtn(PicklerIcon("Home").."START",PicklerCasterPage=="info","vxInfo","Set everything up in a few steps") then PicklerCasterPage="info" end
	Gui.sameLine()
	if PicklerChoiceBtn(PicklerIcon("Video").."CAMERA",PicklerCasterPage=="camera","vxCamera","Choose how the camera moves") then PicklerCasterPage="camera" end
	Gui.sameLine()
	if PicklerChoiceBtn(PicklerIcon("Lightbulb").."EFFECTS",PicklerCasterPage=="studio","vxStudio","Goal explosions and ball trails") then PicklerCasterPage="studio" end
	Gui.sameLine()
	if PicklerChoiceBtn(PicklerIcon("Play").."CLIPS",PicklerCasterPage=="clips","vxClips","Save a clip of every goal") then PicklerCasterPage="clips" end
	Gui.sameLine()
	if PicklerChoiceBtn(PicklerIcon("Cog").."SETTINGS",PicklerCasterPage=="setup","vxSetup","Graphics, voice chat, presets and credits") then PicklerCasterPage="setup" end
	Gui.separator()

	-- a script error stops the camera updating, so say so instead of failing silently
	if lastTickError then
		PicklerUiColorText(LinearColor.new(1,.4,.35,1),"Script error: "..tostring(lastTickError))
	end

	-- settings save themselves, so nobody loses them by forgetting a button
	if totalTime-(PicklerAutoSaveT or 0)>20 then
		PicklerAutoSaveT=totalTime
		pcall(saveConfig)
	end

	local adv=config.uiAdvanced

	-- SETTINGS has its own row of pages
	local setupPage=nil
	if PicklerCasterPage=="setup" then
		setupPage=PicklerSetupPage or "quality"
		for si,sp in ipairs({{"quality","GRAPHICS"},{"audio","VOICE CHAT"},{"presets","PRESETS"},{"credits","CREDITS"}}) do
			if si>1 then Gui.sameLine() end
			if PicklerChoiceBtn(sp[2],setupPage==sp[1],"vxSetup"..si) then
				PicklerSetupPage=sp[1]
				setupPage=sp[1]
			end
		end
		config.uiAdvanced=Gui.checkbox("Show expert settings everywhere##vxAdv",config.uiAdvanced and true or false)
		adv=config.uiAdvanced
	end

	-- START ------------------------------------------------------------------------
	if PicklerCasterPage=="info" then
		PicklerUiHeader("GET SET UP")
		PicklerStartStep(1,selectedArena~=nil,"Pick an arena","The match you want to watch.")
		PicklerCasterArenaPicker()
		Gui.spacing()
		local choice=PicklerCamChoice()
		local camText="Automatic camera: "..PicklerProfileName()
		if choice=="player" then camText="Following "..tostring(playerFollow.targetName or "nobody yet")
		elseif choice=="free" then camText="Free camera: you fly it" end
		PicklerStartStep(2,true,"Camera",camText,"CHANGE","vxStartCam","camera")
		local cur=math.floor(config.goalFxType or GOALFX_SHUFFLE)
		PicklerStartStep(3,config.goalFxEnabled and true or false,"Goal explosion",
			config.goalFxEnabled and (GOAL_FX_TYPES[cur] or "?") or "Off","CHANGE","vxStartFx","studio")
		local want=config.clipHomeGoals or config.clipAwayGoals
		PicklerStartStep(4,want and true or false,"Goal clips (optional)",
			want and "On. Open OBS and the companion program when you cast." or "Off","SET UP","vxStartClip","clips")
		PicklerUiHint("That's it. Your settings save automatically.")

		PicklerUiHeader("ONE-CLICK SETUPS")
		if Gui.button("RECOMMENDED##vxQsRec") then PicklerQuickSetup("rec") end
		PicklerUiTip("Plutus camera, beam trail, a random explosion every goal")
		Gui.sameLine()
		if Gui.button("CLEAN BROADCAST##vxQsClean") then PicklerQuickSetup("clean") end
		PicklerUiTip("Zepy TV camera, no explosions and no goal camera: just the match")
		Gui.sameLine()
		if Gui.button("LOW-END PC##vxQsLow") then PicklerQuickSetup("low") end
		PicklerUiTip("Lowest effect quality and no real lights, for a smoother frame rate")
		Gui.sameLine()
		if Gui.button("EASY ON THE EYES##vxQsEyes") then PicklerQuickSetup("eyes") end
		PicklerUiTip("Softens bright flashes and turns off camera shake")

		PicklerUiHeader("KEYS")
		PicklerUiHint("Tab   hide or show this menu")
		PicklerUiHint("V     first / third person, when following a player")
		PicklerUiHint("Hover over anything in this menu to see what it does.")

	-- CAMERA -----------------------------------------------------------------------
	elseif PicklerCasterPage=="camera" then
		PicklerUiHeader("ARENA")
		PicklerCasterArenaPicker()

		PicklerUiHeader("HOW SHOULD THE CAMERA MOVE?")
		local choice=PicklerCamChoice()
		if PicklerChoiceBtn("AUTOMATIC",choice=="auto","vxCamAuto","Follows the play for you") then PicklerUseAutoCam() end
		Gui.sameLine()
		if PicklerChoiceBtn("FOLLOW A PLAYER",choice=="player","vxCamPlayer","Stays on one player") then PicklerUsePlayerCam() end
		Gui.sameLine()
		if PicklerChoiceBtn("FREE CAMERA",choice=="free","vxCamFree","Fly it yourself") then PicklerUseFreeCam() end
		choice=PicklerCamChoice()

		if choice=="auto" then
			PicklerUiHeader("STYLE")
			local prof=config.camProfile or 1
			if PicklerChoiceBtn("PLUTUS",prof==1,"vxProfPlutus",PICKLER_STYLE_INFO[1]) then PicklerApplyPlutusPreset() end
			Gui.sameLine()
			if PicklerChoiceBtn("ZEPY",prof==2,"vxProfZepy",PICKLER_STYLE_INFO[2]) then PicklerApplyZepyPreset() end
			Gui.sameLine()
			if PicklerChoiceBtn("YUKI",prof==3,"vxProfYuki",PICKLER_STYLE_INFO[3]) then PicklerApplyYukiPreset() end
			Gui.sameLine()
			if PicklerChoiceBtn("SNOWMAN",prof==4,"vxProfSnow",PICKLER_STYLE_INFO[4]) then PicklerApplySnowmanPreset() end
			prof=config.camProfile or 1
			PicklerUiHint(PICKLER_STYLE_INFO[prof] or "")
			Gui.newLine()
			if Gui.collapsingHeader("Fine-tune this camera (optional)##vxCamTune") then
				Gui.indent()
				config.uiAdvanced=Gui.checkbox("Show expert settings##vxAdvCam",config.uiAdvanced and true or false)
				adv=config.uiAdvanced
				if prof==3 then
					PicklerYukiUi()
				elseif prof==4 then
					PicklerSnowmanUi()
				elseif prof==1 then
					PicklerPlutusUi()
				else
					uiSlider("How far back##vxBcDist","bcDist",50,600)
					uiSlider("How high##vxBcHeight","bcHeight",0,500)
					uiSlider("Field of view##vxBcFov","bcFOV",60,150)
					uiCheck("Orbit the ball at kickoff##vxBcKick","bcKickoffOrbitEnabled")
					uiCheck("Swing to the goal after a score##vxBcGoalCam","bcGoalCamEnabled")
					if adv then
						PicklerUiHeader("SMOOTHING AND MOTION")
						uiSlider("Position smoothing##vxBcPos","bcPosSmooth",1,40)
						uiSlider("Rotation smoothing##vxBcRot","bcRotSmooth",1,40)
						uiSlider("Direction smoothing##vxBcDir","bcDirSmooth",1,40)
						uiCheck("Speed FOV##vxBcSpd","bcSpeedFOVEnabled")
						if config.bcSpeedFOVEnabled then
							uiSlider("Speed FOV max##vxBcSpdMax","bcSpeedFOVMax",0,40)
						end
						uiSlider("Max turn rate##vxBcTurn","bcMaxDirChangeRate",.3,6)
						uiSlider("Lead alignment##vxBcLead","bcLeadDot",0,1)

						PicklerUiHeader("ZEPY CROWD AND GOAL AWARENESS")
						uiSlider("Crowd radius##vxZCrR","bcCrowdRadius",200,2000)
						uiSlider("Crowd threshold##vxZCrT","bcCrowdThreshold",2,8)
						uiSlider("Crowd full##vxZCrF","bcCrowdFull",1,8)
						uiSlider("Crowd step-back##vxZCrS","bcCrowdStepBack",0,2)
						uiSlider("Goal look bias##vxZGLB","bcGoalLookBias",0,1)
						uiSlider("Goal proximity##vxZGP","bcGoalProximity",400,3000)

						if config.bcKickoffOrbitEnabled then
							PicklerUiHeader("KICKOFF ORBIT")
							uiSlider("Orbit speed##vxBcKickSpd","bcKickoffOrbitSpeed",0,90)
							uiSlider("Orbit height##vxBcKickH","bcKickoffHeight",0,400)
						end

						PicklerUiHeader("VERTICAL TRACKING")
						uiCheck("Enabled##vxBcVert","verticalCameraEnabled")
						if config.verticalCameraEnabled then
							uiSlider("Max angle##vxBcVertA","verticalCameraMaxAngle",0,89)
							uiSlider("Smoothing##vxBcVertS","verticalCameraSmooth",1,30)
						end

						PicklerUiHeader("LEADERBOARD")
						if config.showLeaderboard then
							if Gui.button("HIDE LEADERBOARD##vxLb") then config.showLeaderboard=false end
						else
							if Gui.button("SHOW LEADERBOARD##vxLb") then config.showLeaderboard=true end
						end
						if config.showLeaderboard then drawStatsHudContent() end
					end
				end
				Gui.unindent()
			end

		elseif choice=="player" then
			PicklerUiHeader("WHO TO FOLLOW")
			local preview=playerFollow.targetName
			if preview==nil or preview=="" then preview="Click to choose a player" end
			if Gui.beginCombo("##vxPlayerList",preview) then
				if #allServerPlayers==0 then
					Gui.text("(no players detected yet)")
				else
					for i,info in ipairs(allServerPlayers) do
						local label=info.player.playerName
						if info.arenaName then label=label.."  ["..info.arenaName.."]" end
						if Gui.selectable(label.."##vxPick"..i,
							info.player.playerName==playerFollow.targetName) then
							-- ORIGINAL ZEPY selection path. This switches to the player's arena
							-- before the untouched Zepy playerFollowCam runs.
							selectPlayerForFollow(info)
							PicklerCasterMode="player"
							curMode=Mode.PFOLLOW
						end
					end
				end
				Gui.endCombo()
			end
			PicklerPlayerViewUi(adv)

		else
			PicklerUiHeader("FREE CAMERA CONTROLS")
			PicklerUiHint("W A S D   move")
			PicklerUiHint("Q / E     down / up")
			PicklerUiHint("Mouse or arrow keys   look")
			PicklerUiHint("Shift / Ctrl   faster / slower")
			PicklerUiHint("F   leaves the free camera")
		end

	-- EFFECTS ----------------------------------------------------------------------
	elseif PicklerCasterPage=="studio" then
		Gui.beginTabBar("##vxFxPages")
		if Gui.beginTabItem("EXPLOSIONS##vxFxP1") then
			PicklerFxExplosionsPage(adv)
			Gui.endTabItem()
		end
		if Gui.beginTabItem("BALL TRAILS##vxFxP2") then
			PicklerFxTrailsPage()
			Gui.endTabItem()
		end
		if Gui.beginTabItem("KICKOFF##vxFxP3") then
			PicklerFxKickoffPage()
			Gui.endTabItem()
		end
		Gui.endTabBar()
		PicklerUiSave()

	-- CLIPS ------------------------------------------------------------------------
	elseif PicklerCasterPage=="clips" then
		PicklerClipUi()
		PicklerUiSave()

	-- QUALITY ----------------------------------------------------------------------
	elseif setupPage=="quality" then
		PicklerQualityUi(adv)
		PicklerUiSave()

	-- AUDIO ------------------------------------------------------------------------
	elseif setupPage=="audio" then
		PicklerAudioUi()
		PicklerUiSave()

	-- PRESETS ----------------------------------------------------------------------
	elseif setupPage=="presets" then
		PicklerPresetsUi()

	-- CREDITS ----------------------------------------------------------------------
	elseif setupPage=="credits" then
		PicklerUiHeader("CREDITS")
		PicklerUiColorText(PicklerAccent(.8+.2*math.sin(totalTime*2.5)),PicklerIcon("Crown").." Made by "..PICKLER_CREATOR)
		PicklerUiHint("Pickler Casting v"..PICKLER_VERSION)
		Gui.newLine()
		Gui.text("Camera styles built from scripts by:")
		PicklerUiHint("Plutus   -  the Plutus orbit camera")
		PicklerUiHint("Zepy     -  the Zepy broadcast camera")
		PicklerUiHint("Yuki & Mozzy  -  the Yuki sideline camera and trail")
		PicklerUiHint("Snowman (Snoowman & nikita.26)  -  the Snowman casting camera")
		PicklerUiHint("dennssen  -  Follow+, used for first and third person")

		PicklerUiHeader("WHAT'S INSIDE")
		PicklerUiHint(PicklerIcon("Video").."4 caster camera styles + player cam + free cam")
		PicklerUiHint(PicklerIcon("Lightbulb")..(GOALFX_SHUFFLE-1).." goal explosions + Shuffle")
		PicklerUiHint(PicklerIcon("Shapes")..#YUKI_TRAIL_THEMES.." Yuki-style ball trails")
		PicklerUiHint(PicklerIcon("Cog").."Quality presets and in-game shaders")
		PicklerUiHint(PicklerIcon("Users").."Voice chat controls")
		PicklerUiHint(PicklerIcon("FolderOpen").."Presets, auto clip counter, leaderboard")

		PicklerUiHeader("MENU COLOUR")
		for i,ac in ipairs(PICKLER_ACCENTS) do
			if i>1 and (i-1)%3~=0 then Gui.sameLine() end
			local c=ac[2]
			local ok,res=pcall(function()
				return Gui.buttonColored(LinearColor.new(c[1]*.8,c[2]*.8,c[3]*.8,1),
					(((config.uiAccent or 1)==i) and PicklerIcon("Check") or "")..ac[1].."##vxAcc"..i)
			end)
			local clicked=false
			if ok then clicked=res else clicked=Gui.button(ac[1].."##vxAcc"..i) end
			if clicked then config.uiAccent=i end
		end
		PicklerUiSave()
	end
end

function kfvizDraw()
	if not WorldDraw then return end
	if not (config.kfShowPath and curMode == Mode.KEYFRAME and kfState.enabled) then
		return
	end
	local kfs = kfState.keyframes
	local n = #kfs
	if n == 0 then return end

	local thickness = config.kfLineThickness or 8
	local markSize  = config.kfMarkerSize or 40

	if n >= 2 then
		local perSeg = math.max(2, math.floor(config.kfPathSamples or 16))
		local total  = perSeg * (n - 1)
		local t0, t1 = kfs[1].time, kfs[n].time
		local span   = t1 - t0
		local prev   = kfs[1].pos
		for i = 1, total do
			local t = t0 + span * (i / total)
			local r = kfInterpolate(t)
			if r and r.pos then
				WorldDraw.drawLine(prev, r.pos,
					1.00, 0.35, 0.10, thickness, 0)
				prev = r.pos
			end
		end
	end

	for i, kf in ipairs(kfs) do
		local r,g,b = (i == kfState.selectedIdx) and {1.00, 0.80, 0.10} or {0.10, 0.70, 1.00}
		local s = (i == kfState.selectedIdx) and (markSize * 1.4) or markSize
		WorldDraw.drawPoint(kf.pos, r, g, b, s, 0)
	end
end

local camInit = false
local function ensureCamInit()
	if camInit then return end
	camInit = true
	pcall(function() camera.positionSmoothing     = 0 end)
	pcall(function() camera.rotationSmoothing     = 0 end)
	pcall(function() camera.fieldOfViewSmoothing  = 0 end)
end

local function refreshArenas()
	local okC, gms = pcall(function() return SpectatorGamemodes.listGamemodes() end)
	local count = (okC and gms) and #gms or 0
	if not arenas or count ~= cachedGMCount then
		cachedGMCount = count
		arenas = buildArenas()
		arenaKeys = {}
		for k in pairs(arenas) do arenaKeys[#arenaKeys + 1] = k end
		table.sort(arenaKeys)
		if not selectedArena and arenaKeys[1] then
			selectArena(arenas[arenaKeys[1]])
		end
	end
end

-- Goal celebration camera: on a real goal, park the camera in front of the goal looking at the
-- celebration for as long as it plays, then the normal camera mode eases back in (the mode-blend
-- code smooths both transitions). Skipped in First Person, Keyframe, and Caster free cam.
function goalFxAutoCamWanted()
	if not config.goalFxAutoCam or not config.goalFxEnabled then return false end
	if not goalFx.active or goalFx.preview or not goalFx.goal or not selectedArena then return false end
	if curMode == Mode.FP or curMode == Mode.KEYFRAME then return false end
	if curMode == Mode.CASTER and caster.freecamActive then return false end
	return true
end

function goalFxAutoCamTick(d)
	local c,u,r,toward=goalFxFrame()
	if not c then return false end
	local anchor=goalFxAnchor(c,u,r)
	local distance=math.clamp(config.goalFxFreeCamDist or 750,150,2500)
	local ideal=anchor+toward*distance+u*(config.goalFxCamHeight or 60)
	ideal=findSafePosition(anchor,ideal,u,selectedArena.right)
	local lookDir=((anchor+u*40)-ideal):getSafeNormal()
	local tgtRot=safeFromXZ(lookDir,u,camRot)
	camPos=applyCamPos(ideal,spdToTime(5),d)
	camRot=dampQ(camRot,tgtRot,7,d)
	targetFOV=math.clamp(config.goalFxCamFOV or 100,60,130)
	camera.hideNearestHead=false
	camBehavior="GOAL_FX"
	return true
end

-- Kickoff pull-back: an offset added only when the camera is written, never to camPos, because the
-- camera styles damp from camPos and would otherwise keep pulling further back every frame.
PICKLER_KICK_PULL=0

function PicklerKickPull(d,allowed)
	local want=0
	local a=selectedArena
	local ball=a and a.ball
	local back=config.kickCamBack or 400
	if allowed and ball and back>0 and not goalFx.active then
		local rel=ball.transform.position-a.center
		local up=a.up:getSafeNormal()
		local flat=rel-up*Vec3.dot(rel,up)
		local vel=ball.velocity or Vec3.zeroVector
		if flat:length()<=(config.bcKickoffCenterDist or 350) and vel:length()<40 then want=1 end
	end
	PICKLER_KICK_PULL=damp(PICKLER_KICK_PULL,want,want==1 and 2.5 or 4,d)
	if PICKLER_KICK_PULL<.005 or not a or not ball then return Vec3.zeroVector end
	local ideal=camPos-camRot:getForwardVector()*(back*PICKLER_KICK_PULL)
	return findSafePosition(ball.transform.position,ideal,a.up:getSafeNormal(),a.right:getSafeNormal())-camPos
end

-- KICKOFF COUNTDOWN AND GO BURST -------------------------------------------------------------
-- Reads the game's own kickoff timer (getGamemodeData(slot).secondaryTimeSeconds). That timer also
-- runs mid-round, so the countdown only shows while the ball is actually in the middle. A number
-- pops over the ball each second with a ring on the floor draining around it, then GO! with two
-- clean shockwaves and streaks along the floor.
kickFx={active=false,startTime=0,pos=nil,counting=false,left=nil,testEnd=nil,prevRunning=false,lastGo=-100}
PICKLER_KICK_COLORS={{"Gold",{1,.78,.25}},{"Ice",{.55,.85,1}},{"Green",{.35,1,.45}},{"Red",{1,.25,.2}},{"Purple",{.75,.4,1}},{"White",{1,1,1}}}

function resetKickFx()
	kickFx.active=false
	kickFx.pos=nil
	kickFx.counting=false
	kickFx.left=nil
	kickFx.testEnd=nil
	kickFx.prevRunning=false
	kickFx.lastGo=-100
end

function PicklerKickColor()
	local e=PICKLER_KICK_COLORS[math.floor(config.kickFxColor or 1)] or PICKLER_KICK_COLORS[1]
	return e[2]
end

function startKickFx(pos)
	kickFx.active=true
	kickFx.startTime=totalTime
	kickFx.pos=Vec3.new(pos.x,pos.y,pos.z)
	kickFx.lastGo=totalTime
end

-- a made-up countdown for the menu's TEST button
function PicklerKickTest()
	kickFx.testEnd=totalTime+math.clamp(config.kickCountFrom or 5,1,10)
end

function PicklerKickTimer(a)
	local timer=nil
	pcall(function()
		local v=SpectatorGamemodes.getGamemodeData(a.slotId).secondaryTimeSeconds
		if type(v)=="number" and v==v and v>0 and v<3600 then timer=v end
	end)
	return timer
end

function updateKickoffFxTrigger()
	local a=selectedArena
	if not a then
		kickFx.active=false
		kickFx.counting=false
		return
	end
	local ball=a.ball
	local pos=ball and ball.transform.position or a.center
	local timer=PicklerKickTimer(a)
	if kickFx.testEnd then
		timer=kickFx.testEnd-totalTime
		if timer<=0 then timer=nil; kickFx.testEnd=nil end
	elseif ball then
		-- in the middle = close to the centre across the floor (the kickoff spot can sit higher)
		local rel=pos-a.center
		local up=a.up:getSafeNormal()
		local flat=rel-up*Vec3.dot(rel,up)
		if flat:length()>(config.bcKickoffCenterDist or 350) then timer=nil end
	end
	local wasCounting=kickFx.counting
	kickFx.counting=timer~=nil
	kickFx.left=timer
	kickFx.pos=kickFx.pos or Vec3.new(pos.x,pos.y,pos.z)
	if timer then kickFx.pos=Vec3.new(pos.x,pos.y,pos.z) end
	local running=a.isActive
	local go=wasCounting and not timer
	if running and not kickFx.prevRunning and not wasCounting then go=true end   -- a round with no countdown
	kickFx.prevRunning=running
	if go and config.kickoffFxEnabled and totalTime-kickFx.lastGo>2 then startKickFx(kickFx.pos) end
end

function drawKickoffFx()
	if not WorldDraw or not selectedArena then return end
	if goalFx.active and not goalFx.preview then return end
	local a=selectedArena
	GFX.camera()
	local u=a.up:getSafeNormal()
	local r=a.right:getSafeNormal()
	local f=a.forward:getSafeNormal()
	local size=math.clamp(config.kickoffFxSize or 1,.4,2.5)
	local col=PicklerKickColor()
	local k=GFX.K

	-- the countdown
	if kickFx.counting and kickFx.left and config.kickCountEnabled~=false
		and kickFx.left<=math.clamp(config.kickCountFrom or 5,1,10)+.02 then
		local left=kickFx.left
		local n=math.ceil(left)
		local frac=n-left                -- 0 as this number appears, 1 as it ends
		local c=kickFx.pos
		if config.kickCountRing~=false then
			local fl=c+u*2
			local rad=120*size
			GFX.ring(fl,r,f,rad,1.5*size,48,col[1],col[2],col[3],.35)
			GFX.arc(fl+u*.5,r,f,rad,5*size,0,(1-frac)*6.2832,40,col[1],col[2],col[3],1)
			local p=goalFxEaseOut(frac)
			GFX.ring(fl,r,f,rad+p*90*size,2*size,48,col[1],col[2],col[3],.6*(1-p))
		end
		if config.kickCountNumbers~=false then
			local pop=1+.55*(1-goalFxEaseOut(math.min(frac/.22,1)))
			local fade=1-goalFxSmooth((frac-.8)/.2)
			local tc=col
			if n==1 then tc={1,.25,.2} elseif n==2 then tc={1,.6,.2} end
			local at=c+u*(math.clamp(config.kickCountHeight or 170,60,500)*size)
			local tu=11*size*pop
			local toCam=(GFX.cp-at):getSafeNormal()
			GFX.memeText(at-toCam*1,tostring(n),GFX.bR,GFX.bU,tu,tu*.62,LinearColor.new(.02,.02,.03,fade))
			GFX.memeText(at,tostring(n),GFX.bR,GFX.bU,tu,tu*.34,LinearColor.new(tc[1]*k,tc[2]*k,tc[3]*k,fade))
		end
	end

	-- GO!
	if not kickFx.active or not kickFx.pos then return end
	local age=totalTime-kickFx.startTime
	local D=math.clamp(config.kickoffFxDuration or 1.6,.4,5)
	if age>=D then kickFx.active=false return end
	local t=age/D
	local c=kickFx.pos
	local fade=1-goalFxSmooth((t-.55)/.45)
	for w=0,1 do
		local lp=math.clamp(t*1.5-w*.18,0,1)
		if lp>0 and lp<1 then
			GFX.ring(c+u*2,r,f,(60+620*goalFxEaseOut(lp))*size,(8-w*3)*size*(1-lp)+1,56,col[1],col[2],col[3],1-lp)
		end
	end
	-- streaks racing out along the floor
	local sp=goalFxEaseOut(math.min(t*1.4,1))
	for i=1,20 do
		local th=(i+goalFxNoise(i*3.7)*.6)/20*6.2832
		local dir=r*math.cos(th)+f*math.sin(th)
		local reach=(260+goalFxNoise(i*1.3)*300)*size
		local head=c+u*3+dir*(reach*sp)
		local tail=c+u*3+dir*(reach*sp*.6)
		local sk=k*fade
		GFX.beam(tail,head,2.5*size*fade,LinearColor.new(col[1]*sk,col[2]*sk,col[3]*sk,fade))
	end
	if config.kickCountNumbers~=false then
		local pop=1+.7*(1-goalFxEaseOut(math.min(t/.15,1)))
		local at=c+u*(math.clamp(config.kickCountHeight or 170,60,500)*size)
		local tu=13*size*pop
		local toCam=(GFX.cp-at):getSafeNormal()
		GFX.memeText(at-toCam*1,"GO!",GFX.bR,GFX.bU,tu,tu*.62,LinearColor.new(.02,.02,.03,fade))
		GFX.memeText(at,"GO!",GFX.bR,GFX.bU,tu,tu*.34,LinearColor.new(.35*k,k,.45*k,fade))
	end
end

-- =====================================================================================
-- YUKI TRAIL (every ball trail theme): ported from Yuki's sideline cam script.
-- A short, time-based trail made of line segments that get thicker towards the ball, with the
-- colour fading from a tail colour to a head colour. The colours are Yuki's originals: they
-- follow the team that last had the ball (Pixel Punks, Samurai, Excelsior, Predators, Ceres Cobs)
-- and fall back to Yuki's red head / yellow tail for any other team.
-- =====================================================================================
YUKI_TRAIL={pts={},arena=nil,team=nil}
-- {head colour, tail colour}
YUKI_TRAIL_COL={
	default  ={{1,1/255,0},{1,247/255,47/255}},
	pixel    ={{1,0,.894},{.6,0,0}},
	samurai  ={{0,40/255,93/255},{0,.5,.7}},
	excelsior={{.4,0,.6},{.05,.02,.08}},
	predator ={{.86,.08,.24},{.75,.75,.75}},
	ceres    ={{.2,.8,0},{1,.95,0}},
}

function yukiTrailColors(teamName)
	local t=teamName and string.lower(teamName) or ""
	local c=YUKI_TRAIL_COL
	local pair=c.default
	if string.find(t,"pixel") then pair=c.pixel
	elseif string.find(t,"samurai") then pair=c.samurai
	elseif string.find(t,"excelsior") then pair=c.excelsior
	elseif string.find(t,"predator") then pair=c.predator
	elseif string.find(t,"ceres") or string.find(t,"cob") then pair=c.ceres end
	return pair[1],pair[2]
end

-- hue 0..1 to a fully saturated rgb colour
function yukiHsv(h)
	local i=math.floor(h*6)
	local f=h*6-i
	i=i%6
	if i==0 then return 1,f,0 elseif i==1 then return 1-f,1,0 elseif i==2 then return 0,1,f
	elseif i==3 then return 0,1-f,1 elseif i==4 then return f,0,1 end
	return 1,0,1-f
end

-- colour of the team that last had the ball in this arena, brightened so it glows
function yukiTeamColor()
	local col={1,.5,.1}
	pcall(function()
		local a=selectedArena
		local team=(YUKI_TRAIL.teamIdx==TI.Away) and a.away or a.home
		local c=team.color
		local r,g,b=c.R or c.r,c.G or c.g,c.B or c.b
		local m=math.max(r,g,b)
		if m>.01 then col={r/m,g/m,b/m} end
	end)
	return col
end

-- Makes a trail colour vivid: lifts it to full brightness (so dark tail stops don't go muddy),
-- pushes the saturation up, then lets it dim gently toward the tail (hf 1 at the ball, 0 at the
-- end). Near-white colours stay white.
function yukiVivid(r,g,b,hf)
	local m=math.max(r,g,b)
	if m<.001 then return r,g,b end
	r,g,b=r/m,g/m,b/m
	local mean=(r+g+b)/3
	local sat=1.35
	r=math.clamp(mean+(r-mean)*sat,0,1)
	g=math.clamp(mean+(g-mean)*sat,0,1)
	b=math.clamp(mean+(b-mean)*sat,0,1)
	local k=.6+.4*hf
	return r*k,g*k,b*k
end

-- colour of a trail point; w = 0 at the ball, 1 at the end of the tail, age = point's age (s)
function yukiTrailSample(theme,headC,tailC,w,age)
	if theme.anim=="rainbow" then return yukiHsv((totalTime*.6+w*.8)%1) end
	if theme.anim=="stripes" then
		local c=theme.stops[(math.floor(age*(theme.stripeRate or 28))%#theme.stops)+1]
		local k=1-w*.5
		return c[1]*k,c[2]*k,c[3]*k
	end
	if headC then
		return headC[1]+(tailC[1]-headC[1])*w,headC[2]+(tailC[2]-headC[2])*w,headC[3]+(tailC[3]-headC[3])*w
	end
	return GFX.ramp(theme.stops,w)
end

function drawYukiTrail(style)
	local theme=YUKI_TRAIL_THEMES[style or 1] or YUKI_TRAIL_THEMES[1]
	local arena=selectedArena
	local ball=arena and arena.ball
	if YUKI_TRAIL.arena~=arena then YUKI_TRAIL.arena=arena; YUKI_TRAIL.pts={}; YUKI_TRAIL.team=nil end
	if not ball then YUKI_TRAIL.pts={} return end

	-- remember the team of whoever last had the ball
	local pp=possession and possession.player
	if possession and (possession.team==TI.Home or possession.team==TI.Away) then YUKI_TRAIL.teamIdx=possession.team end
	if pp then
		pcall(function()
			local n=pp.playerColor.teamName
			if n then YUKI_TRAIL.team=n end
		end)
	end

	local sec=math.clamp(config.yukiTrailSeconds or .15,.03,1)
	local maxT=math.clamp(config.yukiTrailThick or 25,2,50)
	local glow=config.yukiTrailGlow or 1.5
	local pts=YUKI_TRAIL.pts
	local bp=ball.transform.position
	pts[#pts+1]={p=Vec3.new(bp.x,bp.y,bp.z),t=totalTime}

	-- drop points older than the trail length
	local cutoff=totalTime-sec
	local first=1
	while first<=#pts and pts[first].t<cutoff do first=first+1 end
	if first>1 then
		local keep={}
		for i=first,#pts do keep[#keep+1]=pts[i] end
		pts=keep
		YUKI_TRAIL.pts=pts
	end

	local headOff=1
	if #pts<headOff+2 then return end
	local cHead=pts[#pts-headOff]
	local fHead=math.clamp((totalTime-cHead.t)/sec,0,1)
	local fTail=math.clamp((totalTime-pts[2].t)/sec,0,1)
	local range=fTail-fHead
	if range<1e-6 then range=1e-6 end
	local headC,tailC=nil,nil
	if theme.team then
		headC,tailC=yukiTrailColors(YUKI_TRAIL.team)
	elseif theme.teamColor then
		local c=yukiTeamColor()
		headC,tailC={c[1]+(1-c[1])*.35,c[2]+(1-c[2])*.35,c[3]+(1-c[3])*.35},{c[1]*.35,c[2]*.35,c[3]*.35}
	end

	local beamMode=(math.floor(config.ballTrailMode or 1)==2)
	local strip=beamMode and {} or nil
	for i=2,#pts-headOff do
		local a1=pts[i-1]
		local c1=pts[i]
		local fo=math.clamp((totalTime-c1.t)/sec,0,1)
		local hf=1-math.clamp((fo-fHead)/range,0,1)
		local thick=1+(maxT-1)*(hf*hf)
		local r,g,b=yukiTrailSample(theme,headC,tailC,1-hf,totalTime-c1.t)
		r,g,b=yukiVivid(r,g,b,hf)
		local k=glow
		if theme.anim=="flicker" then
			k=k*(.75+.25*math.sin(totalTime*45+i*1.9))
		elseif theme.anim=="pulse" then
			k=k*(.7+.3*math.sin(totalTime*7-i*.5))
		elseif theme.anim=="shimmer" and (i+math.floor(totalTime*24))%6==0 then
			r,g,b=r+(1-r)*.6,g+(1-g)*.6,b+(1-b)*.6
		end
		if beamMode then
			if #strip==0 then strip[1]={p=a1.p,r=r,g=g,b=b,k=k,w=thick,hf=hf} end
			strip[#strip+1]={p=c1.p,r=r,g=g,b=b,k=k,w=thick,hf=hf}
		else
			WorldDraw.drawLine(a1.p,c1.p,r*k,g*k,b*k,thick,1e-4)
		end
	end
	if beamMode and #strip>=2 then yukiBeamTrail(strip,bp) end
end

-- BEAM TRAILS: the same themes drawn as a smooth glowing ribbon instead of lines. A camera-facing
-- strip (each joint turned to face the camera so there are no gaps), in three layers: a wide soft
-- halo, the coloured body and a thin bright core, all tapering and fading toward the tail.
-- Only the trail itself is drawn (nothing floats around the ball). pts run tail -> head.
function yukiBeamTrail(pts,ballPos)
	local cam=camPos
	local n=#pts
	local sides={}
	for j=1,n do
		local a=pts[math.max(1,j-1)].p
		local b=pts[math.min(n,j+1)].p
		local tg=b-a
		local side=Vec3.cross(tg,cam-pts[j].p)
		if side:length()<1e-4 then side=Vec3.new(0,0,1) end
		sides[j]=side:getSafeNormal()
	end
	local scale=math.clamp(config.yukiBeamWidth or .6,.2,2)
	-- a slim halo (no blob at the ball), a solid coloured body, and a core that stays tinted
	local layers={{w=1.55,c=.5,al=.3,core=0},{w=1,c=1.1,al=.95,core=0},{w=.3,c=1.35,al=1,core=.4}}
	for _,L in ipairs(layers) do
		for j=1,n-1 do
			local p0,p1=pts[j],pts[j+1]
			local w0=p0.w*scale*L.w*math.max(.15,p0.hf)
			local w1=p1.w*scale*L.w*math.max(.15,p1.hf)
			local r=p1.r+(1-p1.r)*L.core
			local g=p1.g+(1-p1.g)*L.core
			local b=p1.b+(1-p1.b)*L.core
			local kk=p1.k*L.c
			local al=L.al*math.min(1,.25+p1.hf)
			local lc=LinearColor.new(r*kk,g*kk,b*kk,al)
			local A0,A1=p0.p+sides[j]*w0,p0.p-sides[j]*w0
			local B0,B1=p1.p+sides[j+1]*w1,p1.p-sides[j+1]*w1
			WorldDraw.drawTriangle(A0,A1,B1,lc,0)
			WorldDraw.drawTriangle(A0,B1,B0,lc,0)
		end
	end
end


local function tickInner(d)
	dt = d
	totalTime = totalTime + d
	ensureCamInit()
	if WorldDraw then pcall(function() WorldDraw.clear() end) end

	_frameCache  = {}
	_loadedCount = nil

	refreshArenas()

	if arenas then
		if selectedArena then selectedArena:tick(totalTime, readLocation) end
		if (totalTime - lastFullArenaTick) >= fullArenaTickInterval then
			lastFullArenaTick = totalTime
			for _, a in pairs(arenas) do
				if a ~= selectedArena then a:tick(totalTime, readLocation) end
			end
			rebuildServerPlayerList()
		end
	end

	if selectedArena then
		onRoundEnd()
	end

	updateGoalFxTrigger()
	updateAutoClip()

	if autoFollow.enabled and (totalTime - autoFollow.lastScanTime) >= autoFollow.scanInterval then
		autoFollow.lastScanTime = totalTime
		scanForAutoFollowTarget()
	elseif not autoFollow.enabled then
		autoFollow.isActive = false
	end

	updateBallSmooth(d)
	updateBallTrail(d)
	if selectedArena and selectedArena.ball then
		updatePossession(selectedArena.players, selectedArena.ball.transform.position, d)
	end
	updateGoalCelebration(d)
	updateKickoffFxTrigger()

	statsUpdate(d)

	handleInput()

	-- Work out which camera mode is effectively active this frame.
	-- Auto-follow's free cam overrides the chosen mode, so treat it as
	-- its own pseudo-mode for the purposes of detecting a switch.
	local effMode = curMode
	if autoFollow.enabled and autoFollow.isActive and not autoFollow.isInArena then
		effMode = -100
	end
	-- a preview that just ended: put the casting camera back exactly where it was
	if goalFx.previewSnap and not goalFxPreviewCamWanted() then
		local s = goalFx.previewSnap
		goalFx.previewSnap = nil
		camPos, camRot, camFOV, targetFOV = s.pos, s.rot, s.fov, s.target
		camPosVel = Vec3.zeroVector
	end
	if goalFxAutoCamWanted() or goalFxPreviewCamWanted() then effMode = -200 end

	-- On any change of effective mode, snapshot the current camera and
	-- start a short ease from that snapshot to the new mode's live output,
	-- so switching never reads as a hard cut. Velocity is cleared so the
	-- new mode's spring doesn't inherit the previous mode's motion.
	if lastAppliedMode ~= nil and lastAppliedMode ~= effMode then
		modeBlend.active = true
		modeBlend.t      = 0
		modeBlend.dur    = math.max(config.camBlendDuration or 0.40, 0.0)
		modeBlend.pos    = camPos
		modeBlend.rot    = camRot
		modeBlend.fov    = camFOV
		camPosVel = Vec3.zeroVector
		camFOVVel = 0
	end
	lastAppliedMode = effMode

	PICKLER_FOLLOW.active = false   -- set again by PicklerFollowHandOff if a mode uses Follow+ this frame
	if effMode == -200 then
		goalFxAutoCamTick(d)
	elseif effMode == -100 then
		autoFollowFreeCam(d)
	elseif curMode == Mode.FP then
		fpCam(d)
	elseif curMode == Mode.DYN then
		dynCam(d)
	elseif curMode == Mode.PFOLLOW then
		if not PicklerPlayerViewTick(d) then playerFollowCam(d) end
	elseif curMode == Mode.KEYFRAME then
		kfState.enabled = true
		if kfState.isPlaying then
			kfPlaybackTick(d)
		elseif config.kfUseFreeCam then
			freeCamTick(d)
		else
			dynCam(d)
		end
	elseif curMode == Mode.CASTER then
		casterCam(d)
	else
		dynCam(d)
	end

	-- Ease across mode changes so switches don't visibly cut. e=0 shows
	-- the pre-switch camera exactly; e=1 shows the new mode's live output.
	if modeBlend.active and modeBlend.dur > 0 then
		modeBlend.t = modeBlend.t + d
		local a = math.clamp(modeBlend.t / modeBlend.dur, 0, 1)
		local e = a * a * (3 - 2 * a)   -- smoothstep ease
		camPos    = Vec3.lerp(modeBlend.pos, camPos, e)
		camRot    = safeSlerp(modeBlend.rot, camRot, e)
		targetFOV = modeBlend.fov + (targetFOV - modeBlend.fov) * e
		if a >= 1 then modeBlend.active = false end
	elseif modeBlend.active then
		modeBlend.active = false
	end


	camFOV = damp(camFOV, targetFOV, config.bcFOVSmooth or 6, d)
	PicklerFollowEnd()

	-- while Follow+ has the camera it is driving it, so nothing is written here
	if not PICKLER_FOLLOW.active then
		pcall(function()
			local kickBack = PicklerKickPull(d, effMode==curMode and (curMode==Mode.CASTER or curMode==Mode.DYN))
			camera.position     = camPos + GFX.shakeVec() + kickBack   -- goal explosion camera shake (0 when idle)
			camera.rotation     = camRot
			camera.fieldOfView  = camFOV
		end)
	end

	PicklerShaderTick()   -- before the Yuki look and goal effects, so they can override it briefly
	yukiPostFxTick()
	PicklerAudioTick()
	kfvizDraw()
	drawGoalFx()
	drawKickoffFx()
	drawBallTrail()
	drawLeanIndicators()
end

function tick(d)
	d = d or dt or (1 / 60)
	-- Clamp the timestep so a single frame hitch can't produce a large,
	-- visible jump in any of the framerate-independent dampers.
	if d > 0.1 then d = 0.1 end
	local ok, err = pcall(function() tickInner(d) end)
	if not ok then
		lastTickError = err
	else
		lastTickError = nil
	end
end

function onTransitionBegin()
	resetGoalState()
	possession.player = nil
	possession.timer  = 0
	arenas        = nil
	selectedArena = nil
	cachedGMCount = -1
	dirInitialized   = false
	kickoff.active   = false
	lastFullArenaTick = -1
	statsReset()
	resetBallTrail()
	resetGoalFx()
	resetKickFx()
	gameHistory = {}
	historyIndex = -1
	caster.freecamActive = false
	caster.axisLock      = false
	greenScreen.selected = {}
	modeBlend.active = false
	lastAppliedMode  = nil
	camInit = false   -- turn engine smoothing back off after a camera switch
	pcall(function() camera:followCamera(nil) end)
	PICKLER_FOLLOW.active = false
	PICKLER_FOLLOW.wasActive = false
end

function main()
	pcall(function() camera:followCamera(nil) end)   -- release any camera hand-off left over from an older version
	PicklerFollowInit()
	showGui = config.showGui ~= false
	PicklerCasterPage="info"
	PicklerCasterMode="caster"
	curMode=Mode.DYN

	if (config.ballTrailThickness or 0)<8 then config.ballTrailThickness=10 end
	if (config.ballTrailParticleRate or 0)<.70 then config.ballTrailParticleRate=.86 end
	if (config.ballTrailParticleSize or 0)<8 then config.ballTrailParticleSize=9 end

	refreshArenas()
end
