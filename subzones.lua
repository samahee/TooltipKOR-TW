-- subzones.lua (collect-only, Lua 5.0)
-- SavedVariables 에 서브존(영문) 수집 + /subzone 명령
-- 미니맵/라벨 치환 로직은 map.lua 로 이동 완료

TooltipKOR_SubzoneSV = TooltipKOR_SubzoneSV or {}  -- TOC: ## SavedVariables: TooltipKOR_SubzoneSV

-- 정규화 (색코드 제거/공백 정리/'The ' 제거/소문자)
local function strip_color(s) s = string.gsub(s or "", "|c%x%x%x%x%x%x%x%x",""); s = string.gsub(s,"|r",""); return s end
local function trim(s) s = string.gsub(s or "","^%s+",""); s = string.gsub(s,"%s+$",""); return s end
local function norm(s)
  if type(s)~="string" then return s end
  s = strip_color(s); s = string.gsub(s,"[\r\n]"," "); s = string.gsub(s,"%s+"," "); s = trim(s)
  s = string.gsub(s,"^The%s+",""); s = string.gsub(s,"%s*%-%s*","-"); s = string.lower(s); return s
end

local function save_seen(en_sub, en_zone, en_mz)
  local key = norm(en_sub ~= "" and en_sub or (en_mz ~= "" and en_mz or en_zone))
  if not key or key=="" then return end
  local rec = TooltipKOR_SubzoneSV[key]
  if not rec then
    TooltipKOR_SubzoneSV[key] = { sub=en_sub, zone=en_zone or "", mzone=en_mz or "", count=1 }
    DEFAULT_CHAT_FRAME:AddMessage(string.format("[TooltipKOR] 수집됨: %s  (zone=%s, minimap=%s)", en_sub, en_zone, en_mz))
  else
    rec.count = (rec.count or 0) + 1
    if rec.zone=="" and en_zone~="" then rec.zone=en_zone end
    if rec.mzone=="" and en_mz~="" then rec.mzone=en_mz end
    DEFAULT_CHAT_FRAME:AddMessage(string.format("[TooltipKOR] 이미 수집됨: %s", en_sub))
  end
  DEFAULT_CHAT_FRAME:AddMessage(string.format("[TooltipKOR] data/subzones_koKR.lua 에 추가: [\"%s\"] = \"여기에_한글\",", en_sub))
end

local function CollectCurrentSubzone()
  local zone    = (GetZoneText and GetZoneText()) or ""
  local sub     = (GetSubZoneText and GetSubZoneText()) or ""
  local minimap = (GetMinimapZoneText and GetMinimapZoneText()) or ""
  local target = sub; if target=="" then target=minimap end; if target=="" then target=zone end
  if target=="" then DEFAULT_CHAT_FRAME:AddMessage("[TooltipKOR] 현재 서브존을 알 수 없습니다."); return end
  save_seen(target, zone, minimap)
  local c=0; for _ in pairs(TooltipKOR_SubzoneSV) do c=c+1 end
  DEFAULT_CHAT_FRAME:AddMessage("[*] TKOR subzones="..c)
end

SLASH_TKOR_SUBZONE1 = "/subzone"
SlashCmdList["TKOR_SUBZONE"] = function(msg) CollectCurrentSubzone() end
