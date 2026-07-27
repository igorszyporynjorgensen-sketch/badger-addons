local ADDON_NAME, ns = ...

-- Builds the addon options schema and delegates registration to the shared BadgerConfigUI library
-- (AceConfig table, dialog default size, and the Blizzard panel stub). The two toggles live under a
-- `general` group so the native tree gains a left-nav node. Kept separate from core.lua so the options
-- schema is easy to find and grow.
function ns.buildOptions(addon)
    local options = {
        type = "group",
        name = "Badger Arena",
        args = {
            general = {
                type = "group",
                name = "General",
                order = 1,
                args = {
                    enabled = {
                        type = "toggle",
                        name = "Enabled",
                        order = 1,
                        get = function()
                            return addon.db.profile.enabled
                        end,
                        set = function(_, value)
                            addon.db.profile.enabled = value
                        end,
                    },
                    showDR = {
                        type = "toggle",
                        name = "Show diminishing returns",
                        order = 2,
                        get = function()
                            return addon.db.profile.showDR
                        end,
                        set = function(_, value)
                            addon.db.profile.showDR = value
                        end,
                    },
                },
            },
        },
    }

    LibStub("BadgerConfigUI-1.0"):Register(ADDON_NAME, options, {
        title = "Badger Arena",
        -- One global header above the tree (BadgerConfigUI-1.0 MINOR 6). No controls — arena has no preview.
        header = { title = "Badger Arena", subtitle = "Arena unit-frames and on-screen info" },
        blizzard = true,
        status = "Reopen with /badgerarena or /ba",
    })
end
