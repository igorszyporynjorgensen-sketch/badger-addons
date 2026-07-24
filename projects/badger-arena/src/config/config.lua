local ADDON_NAME, ns = ...

-- Builds the AceConfig options table and registers both the Blizzard options panel entry and the
-- slash-opened dialog. Kept separate from core.lua so the options schema is easy to find and grow.
function ns.buildOptions(addon)
    local options = {
        type = "group",
        name = "Badger Arena",
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
    }

    LibStub("AceConfig-3.0"):RegisterOptionsTable(ADDON_NAME, options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDON_NAME, "Badger Arena")
end
