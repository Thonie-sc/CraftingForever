-- Localization: UI strings (deDE, esES) and helpers that turn the english names
-- used throughout the data into the client's language via Data/Locale.lua.

local CF = CraftingForever

local locale = GetLocale()
if locale == "esMX" then locale = "esES" end
CF.locale = locale
CF.LDB = CraftingForever_LocaleDB[locale] or {}

-- CF.L["english text"] returns the translation, or the english text itself.
CF.L = setmetatable({}, { __index = function(_, k) return k end })

local T = {}

T.deDE = {
  ["Routes"] = "Routen",
  ["Leveling Guide"] = "Berufs-Anleitung",
  ["Select one or more materials on the left."] = "Wähle links ein oder mehrere Materialien.",
  ["Selected:"] = "Ausgewählt:",
  ["Select at least one material first."] = "Wähle zuerst mindestens ein Material.",
  ["Clear selection"] = "Auswahl löschen",
  ["Show gathered nodes"] = "Gesammelte Fundorte zeigen",
  ["Show route"] = "Route zeigen",
  ["Minimap icons"] = "Minikartensymbole",
  ["Find best routes"] = "Beste Routen finden",
  ["Hide high-level zones"] = "Hochstufige Gebiete ausblenden",
  ["Hide enemy territory"] = "Feindgebiet ausblenden",
  ["Mounted"] = "Beritten",
  ["Show on map"] = "Auf Karte zeigen",
  ["Clear route"] = "Route löschen",
  ["whole zone"] = "ganzes Gebiet",
  ["around %d, %d (%d yd radius)"] = "um %d, %d (Radius %d Yards)",
  ["~%d gathers/h, lap %s, %d stops"] = "~%d Sammelvorgänge/h, Runde %s, %d Stopps",
  ["Active: %s, ~%d gathers/h, lap %s."] = "Aktiv: %s, ~%d Sammelvorgänge/h, Runde %s.",
  ["No routes found. Try other materials or untick the zone filters."] =
    "Keine Routen gefunden. Wähle andere Materialien oder deaktiviere die Gebietsfilter.",
  ["Left-click: routes & guides"] = "Linksklick: Routen & Anleitungen",
  ["Right-click: toggle guide tracker"] = "Rechtsklick: Anleitungs-Tracker ein/aus",
  ["%s (level %d-%d)"] = "%s (Stufe %d-%d)",
  ["Route stop %d"] = "Routenpunkt %d",
  ["Gathered %d time(s)"] = "%d-mal gesammelt",
  ["Last:"] = "Zuletzt:",
  ["Route cleared."] = "Route gelöscht.",
  ["All gathered nodes have been removed."] = "Alle gesammelten Fundorte wurden entfernt.",
  ["/cf - toggle window, /cf routes, /cf guide, /cf tracker, /cf nearest (anvil/forge), /cf clear (route), /cf resetnodes"] =
    "/cf - Fenster ein/aus, /cf routes, /cf guide, /cf tracker, /cf nearest (Amboss/Schmiede), /cf clear (Route), /cf resetnodes",
  ["Show anvils & forges"] = "Ambosse & Schmieden zeigen",
  ["Anvil"] = "Amboss",
  ["Forge"] = "Schmiede",
  ["%s: %d yd (%.1f, %.1f)"] = "%s: %d Yards (%.1f, %.1f)",
  ["%s: none in this zone"] = "%s: keine in diesem Gebiet",
  ["%s: none discovered in this zone"] = "%s: noch keine in diesem Gebiet entdeckt",
  ["Adventure mode: only used ones"] = "Abenteuermodus: nur benutzte",
  ["Discovered: %s in %s (%.1f, %.1f)"] = "Entdeckt: %s in %s (%.1f, %.1f)",
  ["None of your professions uses anvils or forges."] = "Keiner deiner Berufe benötigt Ambosse oder Schmieden.",
  -- guide tab / tracker
  ["All guides"] = "Alle Anleitungen",
  ["Find route"] = "Route finden",
  ["(not learned)"] = "(nicht erlernt)",
  ["No supported profession found on this character. Tick \"All guides\" to browse."] =
    "Kein unterstützter Beruf bei diesem Charakter. Aktiviere \"Alle Anleitungen\" zum Stöbern.",
  ["Reagents unknown - open your profession window once to load them."] =
    "Reagenzien unbekannt - öffne einmal dein Berufsfenster, um sie zu laden.",
  ["* reagents from the guide; opening your profession window loads the real recipe. Counts are bag totals / needed."] =
    "* Reagenzien aus der Anleitung; das Berufsfenster lädt das echte Rezept. Zahlen: in Taschen / benötigt.",
  ["Route: %s, ~%d gathers/h. Open the world map to see it."] =
    "Route: %s, ~%d Sammelvorgänge/h. Öffne die Weltkarte, um sie zu sehen.",
  ["No route found for this step."] = "Keine Route für diesen Schritt gefunden.",
  ["No profession to level."] = "Kein Beruf zum Leveln.",
  ["(right-click for guide)"] = "(Rechtsklick für Anleitung)",
  ["Skill capped at %d: train %s (requires level %d)."] = "Fertigkeit bei %d am Limit: lerne %s (benötigt Stufe %d).",
  ["Skill capped at %d:"] = "Fertigkeit bei %d am Limit:",
  ["Journeyman"] = "Geselle",
  ["Expert"] = "Experte",
  ["Artisan"] = "Fachmann",
  -- guide notes
  ["Smelt the ore into bars if you also craft."] = "Schmelze das Erz zu Barren, wenn du auch herstellst.",
  ["{item:Silver Ore} shares spawn points with {item:Tin Ore}."] =
    "{item:Silver Ore} erscheint an denselben Fundorten wie {item:Tin Ore}.",
  ["{item:Gold Ore} shares spawn points with {item:Iron Ore}."] =
    "{item:Gold Ore} erscheint an denselben Fundorten wie {item:Iron Ore}.",
  ["{item:Truesilver Ore} shares spawn points with {item:Mithril Ore}."] =
    "{item:Truesilver Ore} erscheint an denselben Fundorten wie {item:Mithril Ore}.",
  ["Skin every beast you kill."] = "Häute jedes Wildtier, das du tötest.",
  ["Artisan trainer: {npc:Kylanna Windwhisper}, {place:Feathermoon Stronghold}."] =
    "Fachmann-Lehrer: {npc:Kylanna Windwhisper}, {place:Feathermoon Stronghold}.",
  ["Artisan trainer: {npc:Rogvar}, {place:Stonard}."] = "Fachmann-Lehrer: {npc:Rogvar}, {place:Stonard}.",
  ["Artisan trainer: {npc:Brikk Keencraft}, {place:Booty Bay}."] =
    "Fachmann-Lehrer: {npc:Brikk Keencraft}, {place:Booty Bay}.",
  ["Any recipe that is still yellow works."] = "Jedes Rezept, das noch gelb ist, funktioniert.",
  ["Switch to a yellow {item:Rugged Leather} pattern when the kit turns green."] =
    "Wechsle zu einem gelben Muster mit {item:Rugged Leather}, sobald das Set grün wird.",
  ["Buy a {item:Copper Rod} from the trade supplies vendor."] =
    "Kaufe eine {item:Copper Rod} beim Handwerkswarenhändler.",
  ["Buy {item:Expert First Aid - Under Wraps} from {npc:Deneb Walker}, {place:Stromgarde Keep}."] =
    "Kaufe {item:Expert First Aid - Under Wraps} bei {npc:Deneb Walker}, {place:Stromgarde Keep}.",
  ["Buy {item:Expert First Aid - Under Wraps} from {npc:Balai Lok'Wein}, {place:Brackenwall Village}."] =
    "Kaufe {item:Expert First Aid - Under Wraps} bei {npc:Balai Lok'Wein}, {place:Brackenwall Village}.",
  ["Complete the first aid quest in {place:Theramore Isle} for Artisan."] =
    "Schließe die Erste-Hilfe-Quest in {place:Theramore Isle} ab, um Fachmann zu werden.",
  ["Complete the first aid quest in {place:Hammerfall} for Artisan."] =
    "Schließe die Erste-Hilfe-Quest in {place:Hammerfall} ab, um Fachmann zu werden.",
  ["Learn Expert from the {item:Expert Cookbook}, sold by cooking supply vendors."] =
    "Experte lernst du aus dem {item:Expert Cookbook}, erhältlich bei Kochbedarfshändlern.",
  ["Artisan: complete the quest from {npc:Dirge Quikcleave}, {place:Gadgetzan}."] =
    "Fachmann: Schließe die Quest von {npc:Dirge Quikcleave} in {place:Gadgetzan} ab.",
  ["Fish the squid yourself, or switch to any recipe that is still yellow."] =
    "Angle den Tintenfisch selbst oder wechsle zu einem Rezept, das noch gelb ist.",
  ["Buy {item:Expert Fishing - The Bass and You} from {npc:Old Man Heming}, {place:Booty Bay}."] =
    "Kaufe {item:Expert Fishing - The Bass and You} bei {npc:Old Man Heming}, {place:Booty Bay}.",
  ["Artisan: complete the quest from {npc:Nat Pagle} in {place:Dustwallow Marsh}."] =
    "Fachmann: Schließe die Quest von {npc:Nat Pagle} in {place:Dustwallow Marsh} ab.",
  ["Fish in any water; pools are a bonus."] = "Angle in beliebigem Gewässer; Fischschwärme sind ein Bonus.",
}

T.esES = {
  ["Routes"] = "Rutas",
  ["Leveling Guide"] = "Guía de profesiones",
  ["Select one or more materials on the left."] = "Selecciona uno o más materiales a la izquierda.",
  ["Selected:"] = "Seleccionado:",
  ["Select at least one material first."] = "Selecciona primero al menos un material.",
  ["Clear selection"] = "Borrar selección",
  ["Show gathered nodes"] = "Mostrar nodos recolectados",
  ["Show route"] = "Mostrar ruta",
  ["Minimap icons"] = "Iconos en el minimapa",
  ["Find best routes"] = "Buscar mejores rutas",
  ["Hide high-level zones"] = "Ocultar zonas de nivel alto",
  ["Hide enemy territory"] = "Ocultar territorio enemigo",
  ["Mounted"] = "Con montura",
  ["Show on map"] = "Ver en el mapa",
  ["Clear route"] = "Borrar ruta",
  ["whole zone"] = "toda la zona",
  ["around %d, %d (%d yd radius)"] = "alrededor de %d, %d (radio de %d m)",
  ["~%d gathers/h, lap %s, %d stops"] = "~%d recolecciones/h, vuelta %s, %d paradas",
  ["Active: %s, ~%d gathers/h, lap %s."] = "Activa: %s, ~%d recolecciones/h, vuelta %s.",
  ["No routes found. Try other materials or untick the zone filters."] =
    "No se encontraron rutas. Prueba otros materiales o desmarca los filtros de zona.",
  ["Left-click: routes & guides"] = "Clic izquierdo: rutas y guías",
  ["Right-click: toggle guide tracker"] = "Clic derecho: mostrar/ocultar el seguimiento",
  ["%s (level %d-%d)"] = "%s (nivel %d-%d)",
  ["Route stop %d"] = "Parada %d de la ruta",
  ["Gathered %d time(s)"] = "Recolectado %d vez/veces",
  ["Last:"] = "Última vez:",
  ["Route cleared."] = "Ruta borrada.",
  ["All gathered nodes have been removed."] = "Se han borrado todos los nodos recolectados.",
  ["/cf - toggle window, /cf routes, /cf guide, /cf tracker, /cf nearest (anvil/forge), /cf clear (route), /cf resetnodes"] =
    "/cf - mostrar ventana, /cf routes, /cf guide, /cf tracker, /cf nearest (yunque/forja), /cf clear (ruta), /cf resetnodes",
  ["Show anvils & forges"] = "Mostrar yunques y forjas",
  ["Anvil"] = "Yunque",
  ["Forge"] = "Forja",
  ["%s: %d yd (%.1f, %.1f)"] = "%s: %d m (%.1f, %.1f)",
  ["%s: none in this zone"] = "%s: no hay en esta zona",
  ["%s: none discovered in this zone"] = "%s: aún no descubierto en esta zona",
  ["Adventure mode: only used ones"] = "Modo aventura: solo los usados",
  ["Discovered: %s in %s (%.1f, %.1f)"] = "Descubierto: %s en %s (%.1f, %.1f)",
  ["None of your professions uses anvils or forges."] = "Ninguna de tus profesiones usa yunques ni forjas.",
  -- guide tab / tracker
  ["All guides"] = "Todas las guías",
  ["Find route"] = "Buscar ruta",
  ["(not learned)"] = "(no aprendida)",
  ["No supported profession found on this character. Tick \"All guides\" to browse."] =
    "Este personaje no tiene profesiones compatibles. Marca \"Todas las guías\" para verlas.",
  ["Reagents unknown - open your profession window once to load them."] =
    "Componentes desconocidos: abre una vez la ventana de tu profesión para cargarlos.",
  ["* reagents from the guide; opening your profession window loads the real recipe. Counts are bag totals / needed."] =
    "* Componentes de la guía; la ventana de tu profesión carga la receta real. Cifras: en bolsas / necesarias.",
  ["Route: %s, ~%d gathers/h. Open the world map to see it."] =
    "Ruta: %s, ~%d recolecciones/h. Abre el mapa del mundo para verla.",
  ["No route found for this step."] = "No se encontró ruta para este paso.",
  ["No profession to level."] = "No hay profesiones que subir.",
  ["(right-click for guide)"] = "(clic derecho para la guía)",
  ["Skill capped at %d: train %s (requires level %d)."] = "Habilidad al máximo (%d): aprende %s (requiere nivel %d).",
  ["Skill capped at %d:"] = "Habilidad al máximo (%d):",
  ["Journeyman"] = "Oficial",
  ["Expert"] = "Experto",
  ["Artisan"] = "Artesano",
  -- guide notes
  ["Smelt the ore into bars if you also craft."] = "Funde el mineral en barras si también fabricas.",
  ["{item:Silver Ore} shares spawn points with {item:Tin Ore}."] =
    "{item:Silver Ore} aparece en los mismos puntos que {item:Tin Ore}.",
  ["{item:Gold Ore} shares spawn points with {item:Iron Ore}."] =
    "{item:Gold Ore} aparece en los mismos puntos que {item:Iron Ore}.",
  ["{item:Truesilver Ore} shares spawn points with {item:Mithril Ore}."] =
    "{item:Truesilver Ore} aparece en los mismos puntos que {item:Mithril Ore}.",
  ["Skin every beast you kill."] = "Desuella cada bestia que mates.",
  ["Artisan trainer: {npc:Kylanna Windwhisper}, {place:Feathermoon Stronghold}."] =
    "Instructor de artesano: {npc:Kylanna Windwhisper}, {place:Feathermoon Stronghold}.",
  ["Artisan trainer: {npc:Rogvar}, {place:Stonard}."] = "Instructor de artesano: {npc:Rogvar}, {place:Stonard}.",
  ["Artisan trainer: {npc:Brikk Keencraft}, {place:Booty Bay}."] =
    "Instructor de artesano: {npc:Brikk Keencraft}, {place:Booty Bay}.",
  ["Any recipe that is still yellow works."] = "Sirve cualquier receta que siga en amarillo.",
  ["Switch to a yellow {item:Rugged Leather} pattern when the kit turns green."] =
    "Cambia a un patrón amarillo de {item:Rugged Leather} cuando el kit se vuelva verde.",
  ["Buy a {item:Copper Rod} from the trade supplies vendor."] =
    "Compra una {item:Copper Rod} al proveedor de suministros de comercio.",
  ["Buy {item:Expert First Aid - Under Wraps} from {npc:Deneb Walker}, {place:Stromgarde Keep}."] =
    "Compra {item:Expert First Aid - Under Wraps} a {npc:Deneb Walker}, {place:Stromgarde Keep}.",
  ["Buy {item:Expert First Aid - Under Wraps} from {npc:Balai Lok'Wein}, {place:Brackenwall Village}."] =
    "Compra {item:Expert First Aid - Under Wraps} a {npc:Balai Lok'Wein}, {place:Brackenwall Village}.",
  ["Complete the first aid quest in {place:Theramore Isle} for Artisan."] =
    "Completa la misión de primeros auxilios en {place:Theramore Isle} para ser artesano.",
  ["Complete the first aid quest in {place:Hammerfall} for Artisan."] =
    "Completa la misión de primeros auxilios en {place:Hammerfall} para ser artesano.",
  ["Learn Expert from the {item:Expert Cookbook}, sold by cooking supply vendors."] =
    "Aprende experto con el {item:Expert Cookbook}, que venden los proveedores de cocina.",
  ["Artisan: complete the quest from {npc:Dirge Quikcleave}, {place:Gadgetzan}."] =
    "Artesano: completa la misión de {npc:Dirge Quikcleave} en {place:Gadgetzan}.",
  ["Fish the squid yourself, or switch to any recipe that is still yellow."] =
    "Pesca tú mismo el calamar o cambia a cualquier receta que siga en amarillo.",
  ["Buy {item:Expert Fishing - The Bass and You} from {npc:Old Man Heming}, {place:Booty Bay}."] =
    "Compra {item:Expert Fishing - The Bass and You} a {npc:Old Man Heming}, {place:Booty Bay}.",
  ["Artisan: complete the quest from {npc:Nat Pagle} in {place:Dustwallow Marsh}."] =
    "Artesano: completa la misión de {npc:Nat Pagle} en {place:Dustwallow Marsh}.",
  ["Fish in any water; pools are a bonus."] = "Pesca en cualquier agua; los bancos de peces son un extra.",
}

if T[locale] then
  for k, v in pairs(T[locale]) do rawset(CF.L, k, v) end
end
CF.TRANSLATIONS = T  -- for the test harness

-------------------------------------------------------------------------------
-- name helpers
-------------------------------------------------------------------------------

function CF.ItemNameByID(id, fallback)
  local items = CF.LDB.items
  return items and items[id] or fallback
end

-- english item name (as used in Data/Guides.lua) -> client language
function CF.ItemName(en)
  local id = CraftingForever_ItemIDs[en]
  return id and CF.ItemNameByID(id, en) or en
end

function CF.MobName(id)
  local loc = CF.LDB.mobs and CF.LDB.mobs[id]
  if loc then return loc end
  local mob = CraftingForever_SkinDB.mobs[id]
  return mob and mob[1] or "?"
end

local function token(kind, name)
  local s
  if kind == "item" then
    s = CF.ItemName(name)
  elseif kind == "npc" then
    s = CF.LDB.npcs and CF.LDB.npcs[name] or name
  elseif kind == "place" then
    s = CF.LDB.places and CF.LDB.places[name] or name
  else
    s = name
  end
  return s
end

-- Translate a guide note and replace its {item:..}/{npc:..}/{place:..} tokens.
function CF.T(text)
  local s = CF.L[text]
  s = string.gsub(s, "{(%a+):([^}]+)}", token)
  return s
end
