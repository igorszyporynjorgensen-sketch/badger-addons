local _, ns = ...

-- Pure sim driver: replay a scripted scenario through the WO-010 engine to produce the render model the
-- display draws — no live target, no frames. Also ships a frozen static preview for styling. Composes
-- ns.Estimator + ns.RenderModel + ns.SimScenario; adds no estimation/geometry math of its own. (Loaded
-- after the engine + scenario, so these upvalues are populated.)

local Estimator = ns.Estimator
local RenderModel = ns.RenderModel
local Scenario = ns.SimScenario

local Sim = {}

-- Replay `scenario` up to time `t`: feed samples (honouring immune windows) into a fresh estimator, then
-- assemble each pop's planned/active state and build the render model. Returns (renderModel, ttk).
function Sim.run(scenario, t)
    local est = Estimator.new(scenario.estimatorOpts or { reactivity = 0.5 })
    local samples = scenario.samples
    for i = 1, #samples do
        local s = samples[i]
        if s.t > t then
            break
        end
        est:sample(s.t, s.h, not Scenario.inImmune(scenario.immune, s.t))
    end
    local ttk = est:ttk()

    local entries = {}
    local pops = scenario.pops
    for i = 1, #pops do
        local p = pops[i]
        local entry =
            { id = p.id, duration = p.duration, cooldown = p.cooldown, offset = p.offset or 0 }
        if t >= p.at and t < p.at + p.duration then
            entry.active = true
            entry.remaining = (p.at + p.duration) - t
        end
        entries[#entries + 1] = entry
    end

    return RenderModel.build(ttk or 0, entries), ttk
end

-- A frozen, representative render model for styling: a planned pop-line plus active bars that fit,
-- over-cover, and fall short. The dimmed not-usable / immune-paused visuals are display-side (WO #5).
function Sim.staticPreview()
    local entries = {
        { id = "planned", duration = 20, cooldown = 180, offset = 0 },
        { id = "fits", active = true, remaining = 30, offset = 0 },
        { id = "over", active = true, remaining = 45, offset = 0 },
        { id = "short", active = true, remaining = 12, offset = 0 },
    }
    return RenderModel.build(30, entries)
end

ns.Sim = Sim
