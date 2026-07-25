local _, ns = ...

-- The static Classic-Era (Vanilla 1.15) raid registry — the show-gating CONFIG surface (WO-022): which
-- raids/encounters the bars may appear on. DATA only (no WoW API). Ordered by release; each raid lists its
-- encounters at the in-game encounter granularity (multi-boss fights like the Bug Trio / Twin Emperors are
-- one encounter). Encounter ids are globally unique so they can key db.profile.raids storage safely.
-- Entry: { id, name, encounters = { { id, name }, … } }. Live gating enforcement + boss icons are later WOs.

ns.RaidTable = {
    {
        id = "mc",
        name = "Molten Core",
        encounters = {
            { id = "lucifron", name = "Lucifron" },
            { id = "magmadar", name = "Magmadar" },
            { id = "gehennas", name = "Gehennas" },
            { id = "garr", name = "Garr" },
            { id = "baron_geddon", name = "Baron Geddon" },
            { id = "shazzrah", name = "Shazzrah" },
            { id = "sulfuron", name = "Sulfuron Harbinger" },
            { id = "golemagg", name = "Golemagg the Incinerator" },
            { id = "majordomo", name = "Majordomo Executus" },
            { id = "ragnaros", name = "Ragnaros" },
        },
    },
    {
        id = "onyxia",
        name = "Onyxia's Lair",
        encounters = {
            { id = "onyxia", name = "Onyxia" },
        },
    },
    {
        id = "bwl",
        name = "Blackwing Lair",
        encounters = {
            { id = "razorgore", name = "Razorgore the Untamed" },
            { id = "vaelastrasz", name = "Vaelastrasz the Corrupt" },
            { id = "broodlord", name = "Broodlord Lashlayer" },
            { id = "firemaw", name = "Firemaw" },
            { id = "ebonroc", name = "Ebonroc" },
            { id = "flamegor", name = "Flamegor" },
            { id = "chromaggus", name = "Chromaggus" },
            { id = "nefarian", name = "Nefarian" },
        },
    },
    {
        id = "zg",
        name = "Zul'Gurub",
        encounters = {
            { id = "venoxis", name = "High Priest Venoxis" },
            { id = "jeklik", name = "High Priestess Jeklik" },
            { id = "marli", name = "High Priestess Mar'li" },
            { id = "mandokir", name = "Bloodlord Mandokir" },
            { id = "gahzranka", name = "Gahz'ranka" },
            { id = "thekal", name = "High Priest Thekal" },
            { id = "arlokk", name = "High Priestess Arlokk" },
            { id = "jindo", name = "Jin'do the Hexxer" },
            { id = "hakkar", name = "Hakkar" },
        },
    },
    {
        id = "aq20",
        name = "Ruins of Ahn'Qiraj",
        encounters = {
            { id = "kurinnaxx", name = "Kurinnaxx" },
            { id = "rajaxx", name = "General Rajaxx" },
            { id = "moam", name = "Moam" },
            { id = "buru", name = "Buru the Gorger" },
            { id = "ayamiss", name = "Ayamiss the Hunter" },
            { id = "ossirian", name = "Ossirian the Unscarred" },
        },
    },
    {
        id = "aq40",
        name = "Temple of Ahn'Qiraj",
        encounters = {
            { id = "skeram", name = "The Prophet Skeram" },
            { id = "bug_trio", name = "Bug Trio" },
            { id = "sartura", name = "Battleguard Sartura" },
            { id = "fankriss", name = "Fankriss the Unyielding" },
            { id = "viscidus", name = "Viscidus" },
            { id = "huhuran", name = "Princess Huhuran" },
            { id = "twin_emperors", name = "Twin Emperors" },
            { id = "ouro", name = "Ouro" },
            { id = "cthun", name = "C'Thun" },
        },
    },
    {
        id = "world",
        name = "World Bosses",
        encounters = {
            { id = "azuregos", name = "Azuregos" },
            { id = "kazzak", name = "Lord Kazzak" },
            { id = "ysondre", name = "Ysondre" },
            { id = "lethon", name = "Lethon" },
            { id = "emeriss", name = "Emeriss" },
            { id = "taerar", name = "Taerar" },
        },
    },
}
