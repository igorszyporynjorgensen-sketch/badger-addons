local ADDON_NAME, ns = ...

-- Skeleton options schema. The real tree (Skin, Raids, Display, Estimator, Abilities, Simulation) is
-- built by the config work order (WO-009); this scaffold registers just a General node plus the shared
-- AceDB profile manager, so the window opens and the plumbing (BadgerConfigUI + AceDB) is proven end to
-- end.
function ns.buildOptions(addon)
    local options = {
        type = "group",
        name = "Badger TTK",
        args = {
            general = {
                type = "group",
                name = "General",
                order = 1,
                args = {
                    about = {
                        type = "description",
                        name = "Time-to-kill and optimal cooldown timing. (Scaffold — options land in later updates.)",
                        order = 1,
                    },
                    enabled = {
                        type = "toggle",
                        name = "Enabled",
                        order = 2,
                        get = function()
                            return addon.db.profile.enabled
                        end,
                        set = function(_, value)
                            addon.db.profile.enabled = value
                        end,
                    },
                },
            },
            profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(addon.db),
        },
    }
    options.args.profiles.order = -1

    LibStub("BadgerConfigUI-1.0"):Register(ADDON_NAME, options, {
        title = "Badger TTK",
        banner = { title = "Badger TTK", subtitle = "Time-to-kill and optimal cooldown timing" },
        blizzard = true,
        status = "Reopen with /bttk or /badgerttk",
    })
end
