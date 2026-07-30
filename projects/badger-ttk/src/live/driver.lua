local _, ns = ...

-- The live driver — real combat → the display. The `assembleEntries` + `gate` helpers are PURE (plain
-- inputs, no WoW API) so they unit-test off-client; the sampling / event / aura-cooldown reads are the
-- untestable edge. Reuses ns.Estimator / ns.RenderModel / ns.Abilities / ns.AbilityTable — no new math.

local Estimator = ns.Estimator
local RenderModel = ns.RenderModel
local Abilities = ns.Abilities
local AbilityTable = ns.AbilityTable

local LiveDriver = {}

-- Per-entry config: enabled (default true), offset (default 0).
local function entryConfig(config, id)
    local c = config[id]
    return (not c or c.enabled ~= false), (c and c.offset) or 0
end

-- PURE: build the render-model entries. Include an enabled entry when it is available (owned / equipped /
-- in bags) OR its buff is active (the override). Active → draining (remaining); else planned (offset/D/C).
-- `states[id] = { auraRemaining, usable }`.
function LiveDriver.assembleEntries(entries, config, character, states)
    local out = {}
    for i = 1, #entries do
        local e = entries[i]
        local enabled, offset = entryConfig(config, e.id)
        local available = Abilities.available(e, character)
        local state = Abilities.deriveState(e, states[e.id] or {})
        if enabled and (available or state.active) then
            local entry = {
                id = e.id,
                name = e.name,
                duration = e.duration,
                cooldown = e.cooldown,
                offset = offset,
            }
            if state.active then
                entry.active = true
                entry.remaining = state.remaining
            end
            out[#out + 1] = entry
        end
    end
    return out
end

-- PURE: should the bars show? `settings` = the enable/Behavior profile; `context` = { hasTarget, inCombat,
-- hostile, dead, ttk }; `wasShown` = the display's current shown-state.
-- `showAnyTarget` bypasses the hostile + minTTK gates (testing). Crucially, **minTTK qualifies only the
-- FIRST appearance** ("is this fight worth showing for?") — once shown, the bars STAY as long as the base
-- gate holds, even as the noisy estimate dips below minTTK. That kills the show/hide flicker AND keeps the
-- bars up through the endgame (where `ttk` is naturally small but the "fire now" signal matters most).
function LiveDriver.gate(settings, context, wasShown)
    if not (settings.enabled and context.hasTarget) then
        return false
    end
    if settings.hideOnTargetDead and context.dead then
        return false
    end
    if settings.inCombatOnly and not context.inCombat then
        return false
    end
    if not settings.showAnyTarget and settings.requireHostile and not context.hostile then
        return false
    end
    if not wasShown and not settings.showAnyTarget then
        -- Initial qualification: don't start showing until the estimate reaches minTTK.
        if not (context.ttk and context.ttk >= settings.minTTK) then
            return false
        end
        -- ...and until the estimate is confident enough (WO-056). The Behavior slider existed but was
        -- never consumed; with evidence-based confidence it now gates honestly. Sticky like minTTK —
        -- once shown, a mid-fight confidence dip never hides the bars. No conf info → no gate.
        local minConf = settings.minConfidenceToShow
        if minConf and minConf > 0 and context.conf and context.conf < minConf then
            return false
        end
    end
    return true
end

-- PURE: should the UTILITY bars show (vs. the main TTK bar only)? They show in a raid encounter always, and
-- elsewhere only when the human opts in — outside a raid they're noise on a random mob. `context.inRaidEncounter`
-- is the edge's encounter/worldboss read.
function LiveDriver.showUtility(settings, context)
    return (context.inRaidEncounter or settings.showUtilityOutsideRaid) and true or false
end

-- PURE: which learned rhythm profile (if any) applies to the current target (WO-069). Three conditions:
-- a live encounter id, a profile learned for it (ns.Rhythms), and the target being the encounter's BOSS —
-- boss/skull level (UnitLevel −1) — never an add: injecting Lucifron's shape into a Flamewaker's
-- estimator would be wrong.
function LiveDriver.rhythmFor(rhythms, encounterID, targetLevel)
    if rhythms and encounterID and targetLevel == -1 then
        return rhythms[encounterID]
    end
    return nil
end

-- ===== the client edge (untestable off-client; delegates all decisions to the pure helpers above) =====

local frame -- event + ticker frame
local est -- per-target estimator
local lastGUID
local shown = false -- sticky per-target show-state (feeds the gate's minTTK initial-qualify); reset on
-- a target change so each new target must re-qualify.
local encounterActive = false -- true between ENCOUNTER_START and ENCOUNTER_END (instance raid encounters)
local currentEncounterID -- ENCOUNTER_START's id while an encounter is live (nil outside one); keys ns.Rhythms
local estHasRhythm = false -- whether the live estimator was built with a rhythm profile (one-shot upgrade)
local estEncounterUpgraded = false -- whether the one-shot encounter-live rebuild has fired (picks up the
-- rhythm AND the encounter-keyed history prior once ENCOUNTER_START supplies the id; one-shot so it never
-- discards mid-fight evidence). true from birth if the encounter was already live at target acquisition.
-- Kill-history tracking for the current target (WO-025): its NPC id + the player level at engage. The
-- fight-start reference is set at FIRST DAMAGE (not target acquisition) so idle-before-combat doesn't
-- inflate the recorded rate (WO-027); `prevHealth` detects that first drop. Reset on target change.
local curKey, curLevel, fightStartT, fightStartH, recorded, prevHealth
-- The D-012 history identity for the current fight — ("encounter", encounterID) for an instanced boss,
-- else ("creature", npcId). Resolved at ENGAGE (first damage), when the encounter id is already live, so
-- the ENCOUNTER_END race can't drop it before the kill records. Stashed/restored with the retarget state.
local recSpace, recId
-- Retarget continuity (WO-061): swapping to an add and back used to REBUILD the estimator and re-run
-- the initial minTTK/confidence qualification — a multi-second bar blackout per swap-back, and near the
-- end of a fight the bars never re-qualified at all. Recently-tracked targets stash their whole tracking
-- state and resume on swap-back; entries expire after RETARGET_MEMORY seconds.
local RETARGET_MEMORY = 90
-- [guid] = { est, estHasRhythm, shown, curKey, curLevel, fightStartT, fightStartH, recorded, recSpace, recId, t }
local recent = {}

-- The target's NPC id (string) from its GUID — only Creatures/Vehicles; players/pets aren't recorded.
local function npcIdFromGUID(guid)
    if not guid then
        return nil
    end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" or kind == "Vehicle" then
        return id
    end
    return nil
end

-- Live group snapshot for a kill record (D-012): size (1 solo · party · raid, INCLUDING the player) and
-- per-CLASS counts. GetNumGroupMembers() includes the player; raidN tokens include the player, partyN do
-- not — so recount from raidN in a raid, and add the player to partyN otherwise.
local function scanGroup()
    local n = GetNumGroupMembers() or 0
    local comp = {}
    if n <= 1 then
        local _, class = UnitClass("player")
        if class then
            comp[class] = 1
        end
        return 1, comp
    end
    if IsInRaid() then
        for i = 1, n do
            local _, class = UnitClass("raid" .. i)
            if class then
                comp[class] = (comp[class] or 0) + 1
            end
        end
    else
        local _, class = UnitClass("player")
        if class then
            comp[class] = 1
        end
        for i = 1, n - 1 do
            local _, c = UnitClass("party" .. i)
            if c then
                comp[c] = (comp[c] or 0) + 1
            end
        end
    end
    return n, comp
end

-- The D-012 history identity of the CURRENT target: an instanced boss (a live encounter + a boss/skull
-- level target, -1) keys on the encounterID — exactly what a Warcraft-Logs import keys on; everything else
-- keys on the creature id from the GUID. Returns (space, id) or nil.
local function historyKey()
    if currentEncounterID and UnitLevel("target") == -1 then
        return "encounter", currentEncounterID
    elseif curKey then
        return "creature", curKey
    end
    return nil
end

local character = { knownSpells = {}, equippedTrinkets = {}, bagCounts = {} }
local nameIndex -- buff name → entry (for aura matching)
local accum = 0
local INTERVAL = 0.15
local suspended = false -- pushed true by the display while a sim preview owns the container

-- The display commands this directly the instant a preview is toggled (see Display.showPreview/playSim),
-- so the driver never has to read db.profile on a tick to know a preview is up. Belt-and-suspenders: the
-- update() guard ALSO checks the db flags, so a real target is never blocked even if this desynced.
function LiveDriver.setSuspended(v)
    suspended = v and true or false
end

-- One construction path for the live estimator, so the new-target build and the at-pull rhythm upgrade
-- can never drift apart in which opts they pass.
local function buildEst(p, prior, rhythm)
    return Estimator.new({
        reactivity = p.reactivity,
        executeThreshold = p.executeThreshold,
        executeModifier = p.executeModifier,
        priorRate = prior,
        rhythm = rhythm,
    })
end

local function historyPrior(p)
    if not p.useHistory then
        return nil
    end
    local space, id = historyKey()
    if not space then
        return nil
    end
    local size = GetNumGroupMembers() or 0
    if size < 1 then
        size = 1
    end
    return ns.History.rate(ns.addon.db.global.history, space, id, { size = size })
end

local function rescan()
    character = Abilities.scanCharacter()
    if not nameIndex then
        nameIndex = {}
        for i = 1, #AbilityTable do
            nameIndex[AbilityTable[i].name] = AbilityTable[i]
        end
    end
end

-- Active-buff remaining per entry: scan the player's buffs by name (heuristic — refine with buff
-- spellIDs, the reference doc's open verification item).
local function readStates()
    local states = {}
    for i = 1, 40 do
        local name, _, _, _, _, expires = UnitAura("player", i, "HELPFUL")
        if not name then
            break
        end
        local e = nameIndex[name]
        if e then
            states[e.id] =
                { auraRemaining = (expires and expires > 0) and (expires - GetTime()) or 0 }
        end
    end
    return states
end

local function update()
    local p = ns.addon.db.profile
    -- A sim preview (static or dynamic playback) owns the display; don't clobber/hide it. `suspended` is
    -- the display's explicit command; the db flags are the backstop (see LiveDriver.setSuspended).
    if suspended or p.simStatic or p.simPlaying then
        return
    end
    -- Master switch off: halt ALL observation (no estimator sampling, no kill-history recording) and hide —
    -- not just the show/hide gate below, which would still let update() keep writing db.global.history while
    -- the addon is "off" (audit #5). Mirror the no-target reset.
    if not p.enabled then
        est, lastGUID, shown, estHasRhythm, estEncounterUpgraded = nil, nil, false, false, false
        curKey, recorded, fightStartT, prevHealth = nil, false, nil, nil
        recSpace, recId = nil, nil
        ns.Display.hide()
        return
    end
    if not UnitExists("target") then
        est, lastGUID, shown, estHasRhythm, estEncounterUpgraded = nil, nil, false, false, false
        curKey, recorded, fightStartT, prevHealth = nil, false, nil, nil
        recSpace, recId = nil, nil
        ns.Display.hide()
        return
    end
    local maxhp = UnitHealthMax("target")
    local h = (maxhp > 0) and (UnitHealth("target") / maxhp) or 1
    local dead = UnitIsDeadOrGhost("target")
    local guid = UnitGUID("target")
    if guid ~= lastGUID then
        local now = GetTime()
        if lastGUID and est then
            -- Stash the outgoing target's tracking state for a possible swap-back.
            recent[lastGUID] = {
                est = est,
                estHasRhythm = estHasRhythm,
                estEncounterUpgraded = estEncounterUpgraded,
                shown = shown,
                curKey = curKey,
                curLevel = curLevel,
                fightStartT = fightStartT,
                fightStartH = fightStartH,
                recorded = recorded,
                recSpace = recSpace,
                recId = recId,
                t = now,
            }
        end
        for g, stash in pairs(recent) do
            if now - stash.t > RETARGET_MEMORY then
                recent[g] = nil
            end
        end
        lastGUID = guid
        local back = recent[guid]
        if back then
            -- Swap-back: resume the fight instead of restarting it (WO-061). Drop the estimator's
            -- sample reference via the public hold so the away-gap can never read as a rate; damage
            -- dealt while untargeted simply goes unobserved.
            recent[guid] = nil
            est, shown = back.est, back.shown
            estHasRhythm = back.estHasRhythm or false
            estEncounterUpgraded = back.estEncounterUpgraded or false
            curKey, curLevel = back.curKey, back.curLevel
            fightStartT, fightStartH, recorded = back.fightStartT, back.fightStartH, back.recorded
            recSpace, recId = back.recSpace, back.recId
            prevHealth = h
            est:sample(0, 0, false)
        else
            shown = false -- a new target must re-qualify (minTTK + confidence) before showing
            -- Kill-history: key this target by NPC id + the player's level; look up the recorded prior
            -- (if any). The fight clock starts at FIRST DAMAGE (below) — idle must not count.
            curKey = npcIdFromGUID(guid)
            curLevel = UnitLevel("player")
            fightStartT, fightStartH, recorded, prevHealth = nil, nil, false, h
            recSpace, recId = nil, nil -- resolved at engage (first damage), below
            local rhythm = LiveDriver.rhythmFor(ns.Rhythms, currentEncounterID, UnitLevel("target"))
            est = buildEst(p, historyPrior(p), rhythm)
            estHasRhythm = rhythm ~= nil
            -- If the encounter was already live at acquisition (targeted mid-encounter), historyPrior()
            -- already resolved the encounter prior, so no upgrade is owed — mark it done. Only a boss
            -- targeted BEFORE its pull (id not yet live) leaves this false, to upgrade when it fires.
            estEncounterUpgraded = currentEncounterID ~= nil
        end
    end
    -- Encounter-live one-shot upgrade (WO-069 rhythm + WO-072 history): a boss is usually targeted BEFORE
    -- the pull, so its estimator is built before ENCOUNTER_START can supply the encounter id. The moment a
    -- live encounter + a boss-level (-1) target line up, rebuild ONCE — picking up the learned rhythm (if
    -- any) AND the encounter-keyed history prior (historyPrior() now resolves to the encounter space). The
    -- pull just started, so at most a tick or two of pre-damage evidence is repaid for a whole fight of
    -- anticipation; the one-shot flag means a profile/prior is never torn down mid-fight. Also promote the
    -- record identity, closing the window where a pre-ENCOUNTER_START first-damage tick keyed the kill on
    -- the creature space (recSpace/recId are only read at death, so this is lossless).
    if est and not estEncounterUpgraded and currentEncounterID and UnitLevel("target") == -1 then
        local rhythm = LiveDriver.rhythmFor(ns.Rhythms, currentEncounterID, UnitLevel("target"))
        est = buildEst(p, historyPrior(p), rhythm)
        estHasRhythm = rhythm ~= nil
        estEncounterUpgraded = true
        if recSpace ~= "encounter" then
            recSpace, recId = "encounter", currentEncounterID
        end
    end
    -- Start the recording clock at the first observed health drop (the real fight), with the health just
    -- before it as the reference. Resolve the D-012 history identity HERE — the pull has started, so a
    -- raid boss's encounter id is live (unlike at target acquisition) and the ENCOUNTER_END race is moot.
    if not dead and fightStartT == nil and prevHealth and h < prevHealth then
        fightStartT, fightStartH = GetTime(), prevHealth
        recSpace, recId = historyKey()
    end
    prevHealth = h
    est:sample(GetTime(), h, not dead)
    -- Record the kill once, when this tracked target dies, as a D-012 per-kill record (WO-072). The rate is
    -- the average health-loss over the actual damaging window (stable, unlike the EWMA); `dur` normalizes it
    -- to seconds-from-full-health so a partial-window observation and a full WCL kill share one shape. The
    -- roster/encounter fields make a locally recorded kill blend with a future web-log import. Skip
    -- zero-duration kills, and kills whose identity never resolved (an untracked target).
    if dead and not recorded and p.recordHistory and recSpace and fightStartT then
        local duration = GetTime() - fightStartT
        if duration > 0 and fightStartH and fightStartH > 0 then
            local rate = fightStartH / duration -- health fraction per second, over the damaging window
            local size, comp = scanGroup()
            ns.History.record(ns.addon.db.global.history, recSpace, recId, {
                name = UnitName("target") or "?",
                level = curLevel,
                dur = 1 / rate, -- seconds to kill from full health (schema stores `dur`; rate = 1/dur)
                size = size,
                comp = comp,
                diff = "normal", -- Classic Era: single difficulty
                src = "local",
                when = time(),
            })
        end
        recorded = true
    end
    local ttk, conf = est:ttk()

    local context = {
        conf = conf,
        hasTarget = true,
        inCombat = InCombatLockdown(),
        hostile = UnitCanAttack("player", "target"),
        dead = dead,
        ttk = ttk,
        -- A raid boss = an active encounter (instances) OR a worldboss-classified target (open world).
        inRaidEncounter = encounterActive or (UnitClassification("target") == "worldboss"),
    }
    -- Sticky: pass the current show-state so minTTK only gates the FIRST appearance (no flicker).
    shown = LiveDriver.gate(p, context, shown)
    if not shown then
        ns.Display.hide()
        return
    end

    -- Utility bars only where they matter: in a raid encounter, or when the human opts to show them anywhere.
    local entries = LiveDriver.showUtility(p, context)
            and LiveDriver.assembleEntries(AbilityTable, p.abilities, character, readStates())
        or {}
    ns.Display.render(RenderModel.build(ttk or 0, entries), h)
end

function LiveDriver.start()
    if frame then
        return
    end
    rescan()
    frame = CreateFrame("Frame")
    frame:SetScript("OnUpdate", function(_, elapsed)
        accum = accum + elapsed
        if accum >= INTERVAL then
            accum = 0
            update()
        end
    end)
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("BAG_UPDATE")
    frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    frame:RegisterEvent("ENCOUNTER_START")
    frame:RegisterEvent("ENCOUNTER_END")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "ENCOUNTER_START" then
            encounterActive = true
            -- First arg: the encounter's DungeonEncounterID — keys ns.Rhythms (WO-069). The rhythm
            -- upgrade itself happens in update(), where the target/estimator context lives.
            currentEncounterID = ...
        elseif event == "ENCOUNTER_END" then
            encounterActive = false
            currentEncounterID = nil
        elseif event ~= "PLAYER_TARGET_CHANGED" then
            rescan()
        end
        update()
    end)
end

ns.LiveDriver = LiveDriver
