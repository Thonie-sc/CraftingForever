-- Leveling guides for the 1.12 professions.
--
-- Gathering steps list the materials to farm and recommended zones per faction
-- (area IDs, see Data/Zones.lua); the route planner turns them into loops.
-- Crafting steps list the recipe, roughly how many crafts it takes and the
-- reagents per craft. Reagents left out (mats = nil) are filled in from the real
-- recipe data the first time you open that profession window in game, which
-- also overrides the reagents below if the server differs.
--
-- Step fields: from, to, text, [mats], [zones = { A = {...}, H = {...} }],
--              [craft], [n], [mats = { {"Reagent", countPerCraft}, ... }],
--              [A], [H] (faction specific notes)

local CF = CraftingForever

CF.TRAINER_RANKS = {
  { skill = 50, cap = 75, rank = "Journeyman", level = 10 },
  { skill = 125, cap = 150, rank = "Expert", level = 20 },
  { skill = 200, cap = 225, rank = "Artisan", level = 35 },
}

CF.Guides = {
  ---------------------------------------------------------------------------
  mining = {
    title = "Mining", kind = "gather",
    steps = {
      { from = 1, to = 65, mats = { "copper" },
        zones = { A = { 12, 1, 141, 148, 40 }, H = { 14, 215, 85, 17, 130 } },
        text = "Mine Copper Veins. Smelt the ore into Copper Bars if you also craft." },
      { from = 65, to = 125, mats = { "tin", "silver", "copper" },
        zones = { A = { 44, 11, 148, 331 }, H = { 17, 267, 406, 331 } },
        text = "Mine Tin Veins (Silver and Copper on the way). Train Journeyman at 50." },
      { from = 125, to = 175, mats = { "iron", "gold", "tin" },
        zones = { A = { 45, 36, 33, 400, 405 }, H = { 45, 36, 33, 400, 405 } },
        text = "Mine Iron Deposits, Gold Veins share the spawns. Train Expert at 125." },
      { from = 175, to = 245, mats = { "mithril", "truesilver", "iron" },
        zones = { A = { 47, 3, 440, 51, 357 }, H = { 47, 3, 440, 51, 405 } },
        text = "Mine Mithril Deposits; Truesilver appears on the same spawns. Train Artisan at 200." },
      { from = 245, to = 300, mats = { "thorium", "truesilver", "mithril" },
        zones = { A = { 490, 618, 46, 1377, 139, 16 }, H = { 490, 618, 46, 1377, 139, 16 } },
        text = "Mine Small and Rich Thorium Veins." },
    },
  },
  ---------------------------------------------------------------------------
  herbalism = {
    title = "Herbalism", kind = "gather",
    steps = {
      { from = 1, to = 50, mats = { "peacebloom", "silverleaf", "earthroot" },
        zones = { A = { 12, 1, 141 }, H = { 14, 215, 85 } },
        text = "Pick Peacebloom and Silverleaf; Earthroot from 15." },
      { from = 50, to = 100, mats = { "mageroyal", "briarthorn", "earthroot" },
        zones = { A = { 40, 148, 38 }, H = { 17, 130 } },
        text = "Pick Mageroyal and Briarthorn. Train Journeyman at 50." },
      { from = 100, to = 150, mats = { "bruiseweed", "kingsblood", "steelbloom", "stranglekelp" },
        zones = { A = { 11, 267, 331, 10 }, H = { 406, 331, 267, 17 } },
        text = "Bruiseweed, Wild Steelbloom and Kingsblood. Train Expert at 125." },
      { from = 150, to = 205, mats = { "liferoot", "fadeleaf", "goldthorn", "khadgar" },
        zones = { A = { 33, 45, 15 }, H = { 33, 45, 15 } },
        text = "Liferoot, Fadeleaf, Goldthorn and Khadgar's Whisker. Train Artisan at 200." },
      { from = 205, to = 235, mats = { "firebloom", "purplelotus", "sungrass", "khadgar" },
        zones = { A = { 440, 51, 357, 47 }, H = { 440, 51, 357, 47 } },
        text = "Firebloom and Purple Lotus, Sungrass from 230." },
      { from = 235, to = 270, mats = { "sungrass", "gromsblood", "sansam", "blindweed" },
        zones = { A = { 357, 47, 16, 8 }, H = { 357, 47, 16, 8 } },
        text = "Sungrass and Golden Sansam; Blindweed in Swamp of Sorrows." },
      { from = 270, to = 300, mats = { "dreamfoil", "silversage", "plaguebloom", "icecap" },
        zones = { A = { 490, 16, 139, 28, 618 }, H = { 490, 16, 139, 28, 618 } },
        text = "Dreamfoil, Mountain Silversage, Plaguebloom and Icecap." },
    },
  },
  ---------------------------------------------------------------------------
  skinning = {
    title = "Skinning", kind = "gather",
    steps = {
      { from = 1, to = 75, mats = { "lightleather", "ruinedscraps" },
        zones = { A = { 12, 1, 141, 40, 148, 38 }, H = { 14, 215, 85, 17, 130 } },
        text = "Skin every beast you kill; level 1-17 beasts give Light Leather." },
      { from = 75, to = 150, mats = { "lightleather", "mediumleather" },
        zones = { A = { 44, 11, 10, 148, 331 }, H = { 17, 406, 267, 331 } },
        text = "Level 15-30 beasts. Train Journeyman at 50, Expert at 125." },
      { from = 150, to = 200, mats = { "mediumleather", "heavyleather" },
        zones = { A = { 33, 45, 405, 15, 400 }, H = { 33, 45, 405, 15, 400 } },
        text = "Level 30-40 beasts. Train Artisan at 200." },
      { from = 200, to = 250, mats = { "heavyleather", "thickleather" },
        zones = { A = { 357, 440, 47, 33 }, H = { 357, 440, 47, 33 } },
        text = "Level 40-50 beasts." },
      { from = 250, to = 300, mats = { "thickleather", "ruggedleather" },
        zones = { A = { 490, 618, 46, 361, 1377 }, H = { 490, 618, 46, 361, 1377 } },
        text = "Level 50-60 beasts; Un'Goro devilsaurs give Devilsaur Leather." },
    },
  },
  ---------------------------------------------------------------------------
  alchemy = {
    title = "Alchemy", kind = "craft",
    steps = {
      { from = 1, to = 60, craft = "Minor Healing Potion", n = 65,
        mats = { { "Peacebloom", 1 }, { "Silverleaf", 1 }, { "Empty Vial", 1 } } },
      { from = 60, to = 110, craft = "Lesser Healing Potion", n = 55,
        mats = { { "Minor Healing Potion", 1 }, { "Briarthorn", 1 } },
        text = "Train Journeyman at 50." },
      { from = 110, to = 140, craft = "Healing Potion", n = 35,
        mats = { { "Bruiseweed", 1 }, { "Briarthorn", 1 }, { "Leaded Vial", 1 } } },
      { from = 140, to = 155, craft = "Lesser Mana Potion", n = 15,
        mats = { { "Mageroyal", 1 }, { "Stranglekelp", 1 }, { "Empty Vial", 1 } },
        text = "Train Expert at 125." },
      { from = 155, to = 185, craft = "Greater Healing Potion", n = 35,
        mats = { { "Liferoot", 1 }, { "Kingsblood", 1 }, { "Leaded Vial", 1 } } },
      { from = 185, to = 210, craft = "Elixir of Agility", n = 30,
        mats = { { "Stranglekelp", 1 }, { "Goldthorn", 1 }, { "Leaded Vial", 1 } },
        A = "Artisan trainer: Kylanna Windwhisper, Feathermoon Stronghold (Feralas).",
        H = "Artisan trainer: Rogvar, Stonard (Swamp of Sorrows)." },
      { from = 210, to = 215, craft = "Elixir of Greater Defense", n = 5,
        mats = { { "Wild Steelbloom", 1 }, { "Goldthorn", 1 }, { "Leaded Vial", 1 } } },
      { from = 215, to = 230, craft = "Superior Healing Potion", n = 15,
        mats = { { "Sungrass", 1 }, { "Khadgar's Whisker", 1 }, { "Crystal Vial", 1 } } },
      { from = 230, to = 250, craft = "Elixir of Detect Undead", n = 20,
        mats = { { "Arthas' Tears", 1 }, { "Crystal Vial", 1 } } },
      { from = 250, to = 265, craft = "Elixir of Greater Agility", n = 15,
        mats = { { "Sungrass", 1 }, { "Goldthorn", 1 }, { "Crystal Vial", 1 } } },
      { from = 265, to = 285, craft = "Superior Mana Potion", n = 25,
        mats = { { "Sungrass", 2 }, { "Blindweed", 2 }, { "Crystal Vial", 1 } } },
      { from = 285, to = 300, craft = "Major Healing Potion", n = 20,
        mats = { { "Golden Sansam", 2 }, { "Mountain Silversage", 1 }, { "Crystal Vial", 1 } } },
    },
  },
  ---------------------------------------------------------------------------
  blacksmithing = {
    title = "Blacksmithing", kind = "craft",
    steps = {
      { from = 1, to = 25, craft = "Rough Sharpening Stone", n = 30, mats = { { "Rough Stone", 1 } } },
      { from = 25, to = 45, craft = "Rough Grinding Stone", n = 25, mats = { { "Rough Stone", 2 } } },
      { from = 45, to = 75, craft = "Copper Chain Belt", n = 35, mats = { { "Copper Bar", 6 } },
        text = "Train Journeyman at 50." },
      { from = 75, to = 80, craft = "Coarse Grinding Stone", n = 5, mats = { { "Coarse Stone", 2 } } },
      { from = 80, to = 100, craft = "Runed Copper Belt", n = 20, mats = { { "Copper Bar", 10 } } },
      { from = 100, to = 105, craft = "Silver Rod", n = 5,
        mats = { { "Silver Bar", 1 }, { "Rough Grinding Stone", 2 } } },
      { from = 105, to = 125, craft = "Rough Bronze Leggings", n = 25, mats = { { "Bronze Bar", 6 } } },
      { from = 125, to = 150, craft = "Heavy Grinding Stone", n = 30, mats = { { "Heavy Stone", 3 } },
        text = "Train Expert at 125." },
      { from = 150, to = 155, craft = "Golden Rod", n = 5,
        mats = { { "Gold Bar", 1 }, { "Coarse Grinding Stone", 2 } } },
      { from = 155, to = 165, craft = "Green Iron Leggings", n = 10,
        mats = { { "Iron Bar", 8 }, { "Heavy Grinding Stone", 1 }, { "Green Dye", 1 } } },
      { from = 165, to = 185, craft = "Green Iron Bracers", n = 20,
        mats = { { "Iron Bar", 6 }, { "Green Dye", 1 } } },
      { from = 185, to = 200, craft = "Golden Scale Bracers", n = 15,
        mats = { { "Steel Bar", 5 }, { "Heavy Grinding Stone", 2 } } },
      { from = 200, to = 210, craft = "Solid Grinding Stone", n = 10, mats = { { "Solid Stone", 4 } },
        text = "Train Artisan at 200 (Brikk Keencraft, Booty Bay)." },
      { from = 210, to = 235, craft = "Mithril Scale Bracers", n = 25, mats = { { "Mithril Bar", 8 } } },
      { from = 235, to = 250, craft = "Mithril Coif", n = 15,
        mats = { { "Mithril Bar", 10 }, { "Mageweave Cloth", 6 } } },
      { from = 250, to = 260, craft = "Dense Sharpening Stone", n = 10, mats = { { "Dense Stone", 1 } } },
      { from = 260, to = 280, craft = "Thorium Bracers", n = 25 },
      { from = 280, to = 300, craft = "Thorium Boots", n = 20,
        text = "Any Thorium recipe that is still yellow works." },
    },
  },
  ---------------------------------------------------------------------------
  leatherworking = {
    title = "Leatherworking", kind = "craft",
    steps = {
      { from = 1, to = 35, craft = "Light Armor Kit", n = 40, mats = { { "Light Leather", 1 } } },
      { from = 35, to = 55, craft = "Cured Light Hide", n = 20, mats = { { "Light Hide", 1 }, { "Salt", 1 } } },
      { from = 55, to = 85, craft = "Embossed Leather Gloves", n = 35,
        mats = { { "Light Leather", 3 }, { "Coarse Thread", 2 } },
        text = "Train Journeyman at 50." },
      { from = 85, to = 100, craft = "Fine Leather Belt", n = 15,
        mats = { { "Light Leather", 6 }, { "Coarse Thread", 2 } } },
      { from = 100, to = 120, craft = "Cured Medium Hide", n = 20,
        mats = { { "Medium Hide", 1 }, { "Salt", 1 } } },
      { from = 120, to = 150, craft = "Medium Armor Kit", n = 30 ,
        text = "Train Expert at 125." },
      { from = 150, to = 160, craft = "Cured Heavy Hide", n = 10 },
      { from = 160, to = 170, craft = "Heavy Armor Kit", n = 10 },
      { from = 170, to = 190, craft = "Barbaric Shoulders", n = 20 },
      { from = 190, to = 200, craft = "Dusky Leather Leggings", n = 10 },
      { from = 200, to = 220, craft = "Nightscape Headband", n = 20, text = "Train Artisan at 200." },
      { from = 220, to = 250, craft = "Nightscape Pants", n = 30 },
      { from = 250, to = 260, craft = "Thick Armor Kit", n = 10 },
      { from = 260, to = 300, craft = "Rugged Armor Kit", n = 45,
        text = "Switch to a yellow Rugged Leather pattern when the kit turns green." },
    },
  },
  ---------------------------------------------------------------------------
  tailoring = {
    title = "Tailoring", kind = "craft",
    steps = {
      { from = 1, to = 45, craft = "Bolt of Linen Cloth", n = 50, mats = { { "Linen Cloth", 2 } } },
      { from = 45, to = 70, craft = "Heavy Linen Gloves", n = 25,
        text = "Train Journeyman at 50." },
      { from = 70, to = 75, craft = "Reinforced Linen Cape", n = 5 },
      { from = 75, to = 105, craft = "Bolt of Woolen Cloth", n = 40, mats = { { "Wool Cloth", 3 } } },
      { from = 105, to = 125, craft = "Double-stitched Woolen Shoulders", n = 20 },
      { from = 125, to = 145, craft = "Bolt of Silk Cloth", n = 25, mats = { { "Silk Cloth", 4 } },
        text = "Train Expert at 125." },
      { from = 145, to = 160, craft = "Azure Silk Hood", n = 15 },
      { from = 160, to = 175, craft = "Silk Headband", n = 15 },
      { from = 175, to = 185, craft = "Bolt of Mageweave", n = 15, mats = { { "Mageweave Cloth", 5 } } },
      { from = 185, to = 205, craft = "Crimson Silk Vest", n = 20,
        text = "Train Artisan at 200." },
      { from = 205, to = 215, craft = "Crimson Silk Pantaloons", n = 10 },
      { from = 215, to = 230, craft = "Black Mageweave Gloves", n = 15 },
      { from = 230, to = 250, craft = "Black Mageweave Headband", n = 20 },
      { from = 250, to = 260, craft = "Bolt of Runecloth", n = 15, mats = { { "Runecloth", 5 } } },
      { from = 260, to = 280, craft = "Runecloth Belt", n = 20 },
      { from = 280, to = 300, craft = "Runecloth Gloves", n = 20 },
    },
  },
  ---------------------------------------------------------------------------
  engineering = {
    title = "Engineering", kind = "craft",
    steps = {
      { from = 1, to = 30, craft = "Rough Blasting Powder", n = 35, mats = { { "Rough Stone", 1 } } },
      { from = 30, to = 50, craft = "Handful of Copper Bolts", n = 25, mats = { { "Copper Bar", 1 } } },
      { from = 50, to = 51, craft = "Arclight Spanner", n = 1, mats = { { "Copper Bar", 6 } },
        text = "Train Journeyman at 50." },
      { from = 51, to = 65, craft = "Copper Tube", n = 15, mats = { { "Copper Bar", 2 }, { "Weak Flux", 1 } } },
      { from = 65, to = 75, craft = "Rough Copper Bomb", n = 10 },
      { from = 75, to = 90, craft = "Coarse Blasting Powder", n = 20, mats = { { "Coarse Stone", 1 } } },
      { from = 90, to = 100, craft = "Coarse Dynamite", n = 10 },
      { from = 100, to = 105, craft = "Silver Contact", n = 5, mats = { { "Silver Bar", 1 } } },
      { from = 105, to = 125, craft = "Bronze Tube", n = 20, mats = { { "Bronze Bar", 2 }, { "Weak Flux", 1 } } },
      { from = 125, to = 150, craft = "Heavy Blasting Powder", n = 30, mats = { { "Heavy Stone", 1 } },
        text = "Train Expert at 125." },
      { from = 150, to = 175, craft = "Whirring Bronze Gizmo", n = 25 },
      { from = 175, to = 195, craft = "Solid Blasting Powder", n = 25, mats = { { "Solid Stone", 2 } } },
      { from = 195, to = 215, craft = "Mithril Tube", n = 20, mats = { { "Mithril Bar", 3 } },
        text = "Train Artisan at 200." },
      { from = 215, to = 235, craft = "Unstable Trigger", n = 20 },
      { from = 235, to = 250, craft = "Mithril Casing", n = 15 },
      { from = 250, to = 260, craft = "Dense Blasting Powder", n = 10, mats = { { "Dense Stone", 2 } } },
      { from = 260, to = 285, craft = "Thorium Widget", n = 30 },
      { from = 285, to = 300, craft = "Thorium Tube", n = 15 },
    },
  },
  ---------------------------------------------------------------------------
  enchanting = {
    title = "Enchanting", kind = "craft",
    steps = {
      { from = 1, to = 2, craft = "Runed Copper Rod", n = 1,
        text = "Buy a Copper Rod from the trainer's supply vendor." },
      { from = 2, to = 75, craft = "Enchant Bracer - Minor Health", n = 80, mats = { { "Strange Dust", 1 } } },
      { from = 75, to = 85, craft = "Enchant Bracer - Minor Deflection", n = 10,
        text = "Train Journeyman at 50." },
      { from = 85, to = 100, craft = "Enchant Bracer - Minor Stamina", n = 15, mats = { { "Strange Dust", 3 } } },
      { from = 100, to = 101, craft = "Runed Silver Rod", n = 1 },
      { from = 101, to = 110, craft = "Greater Magic Wand", n = 10 },
      { from = 110, to = 135, craft = "Enchant Cloak - Minor Agility", n = 25 },
      { from = 135, to = 155, craft = "Enchant Bracer - Lesser Stamina", n = 20,
        text = "Train Expert at 125." },
      { from = 155, to = 165, craft = "Runed Golden Rod", n = 1 },
      { from = 165, to = 185, craft = "Enchant Bracer - Lesser Strength", n = 20 },
      { from = 185, to = 200, craft = "Enchant Bracer - Strength", n = 15 },
      { from = 200, to = 220, craft = "Enchant Cloak - Greater Defense", n = 20,
        text = "Train Artisan at 200." },
      { from = 220, to = 240, craft = "Enchant Gloves - Agility", n = 20 },
      { from = 240, to = 250, craft = "Enchant Bracer - Greater Strength", n = 10 },
      { from = 250, to = 270, craft = "Enchant Bracer - Greater Intellect", n = 20 },
      { from = 270, to = 290, craft = "Enchant Shield - Greater Stamina", n = 20 },
      { from = 290, to = 300, craft = "Enchant Cloak - Superior Defense", n = 10 },
    },
  },
  ---------------------------------------------------------------------------
  firstaid = {
    title = "First Aid", kind = "craft",
    steps = {
      { from = 1, to = 40, craft = "Linen Bandage", n = 45, mats = { { "Linen Cloth", 1 } } },
      { from = 40, to = 80, craft = "Heavy Linen Bandage", n = 45, mats = { { "Linen Cloth", 2 } },
        text = "Train Journeyman at 50." },
      { from = 80, to = 115, craft = "Wool Bandage", n = 40, mats = { { "Wool Cloth", 1 } } },
      { from = 115, to = 150, craft = "Heavy Wool Bandage", n = 40, mats = { { "Wool Cloth", 2 } },
        A = "At 125 buy Expert First Aid - Under Wraps from Deneb Walker, Stromgarde (Arathi Highlands).",
        H = "At 125 buy Expert First Aid - Under Wraps from Balai Lok'Wein, Brackenwall Village (Dustwallow Marsh)." },
      { from = 150, to = 180, craft = "Silk Bandage", n = 35, mats = { { "Silk Cloth", 1 } } },
      { from = 180, to = 210, craft = "Heavy Silk Bandage", n = 35, mats = { { "Silk Cloth", 2 } } },
      { from = 210, to = 240, craft = "Mageweave Bandage", n = 35, mats = { { "Mageweave Cloth", 1 } } },
      { from = 240, to = 260, craft = "Heavy Mageweave Bandage", n = 25, mats = { { "Mageweave Cloth", 2 } },
        A = "At 225 do the Triage quest in Theramore (Dustwallow Marsh) for Artisan.",
        H = "At 225 do the Triage quest in Hammerfall (Arathi Highlands) for Artisan." },
      { from = 260, to = 290, craft = "Runecloth Bandage", n = 35, mats = { { "Runecloth", 1 } } },
      { from = 290, to = 300, craft = "Heavy Runecloth Bandage", n = 10, mats = { { "Runecloth", 2 } } },
    },
  },
}

-- display order in the guide tab
CF.GUIDE_ORDER = {
  "mining", "herbalism", "skinning", "alchemy", "blacksmithing", "leatherworking",
  "tailoring", "engineering", "enchanting", "firstaid",
}

-- Step of a guide for the given skill rank (the last step once maxed).
function CF.GuideStep(key, rank)
  local g = CF.Guides[key]
  if not g then return nil end
  local steps = g.steps
  for i = 1, table.getn(steps) do
    if rank < steps[i].to then return steps[i], i end
  end
  return steps[table.getn(steps)], table.getn(steps)
end

-- Reagents for a crafting step: real recipe data when known, else the guide's.
function CF.StepReagents(step)
  if step.craft and CF.db and CF.db.recipes[step.craft] then
    return CF.db.recipes[step.craft], true
  end
  return step.mats, false
end

-- Next trainer rank needed, if the skill is at its current cap.
function CF.TrainerHint(key)
  local p = CF.profs[key]
  if not p or p.rank < p.max or p.max >= 300 then return nil end
  for i = 1, table.getn(CF.TRAINER_RANKS) do
    local t = CF.TRAINER_RANKS[i]
    if p.max < t.cap then
      return string.format("Skill capped at %d: train %s (requires level %d).", p.max, t.rank, t.level)
    end
  end
end
