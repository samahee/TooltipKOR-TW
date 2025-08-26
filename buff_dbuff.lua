-- buff_dbuff.lua  (Vanilla 1.12 / Lua 5.0 호환)
-- 중앙 전투 텍스트/에러 텍스트에 표시되는 버프/디버프 "이름만" 한글로 치환.
-- "사라짐" 등 접미사는 그대로 둡니다.
-- 요구: spell_koKR.lua(STENGB_DB), spell_alias.lua(STENGB_ALIAS) 선로드

TooltipKOR = TooltipKOR or {}
TooltipKOR.Aura = TooltipKOR.Aura or {}
if TooltipKOR.Aura.__installed then return end
TooltipKOR.Aura.__installed = true

------------------------------------------------------------
-- 데이터
------------------------------------------------------------
local ENGB  = (getglobal and getglobal("STENGB_DB"))    or ( _G and _G["STENGB_DB"])    or STENGB_DB    or {}
local ALIAS = (getglobal and getglobal("STENGB_ALIAS")) or ( _G and _G["STENGB_ALIAS"]) or STENGB_ALIAS or {}

------------------------------------------------------------
-- 유틸
------------------------------------------------------------
local function strip_color(s)
  s = string.gsub(s or "", "|c%x%x%x%x%x%x%x%x", "")
  s = string.gsub(s, "|r", "")
  return s
end
local function trim(s)
  s = string.gsub(s or "", "^%s+", ""); s = string.gsub(s, "%s+$", ""); return s
end
local function normalize_key(s)
  if type(s) ~= "string" then return s end
  s = strip_color(s)
  s = string.gsub(s, "[\r\n]", " ")
  s = string.gsub(s, "%s+", " ")
  s = trim(s)
  s = string.gsub(s, "^The%s+", "")
  s = string.gsub(s, "%s*%-%s*", "-")
  return string.lower(s)
end

------------------------------------------------------------
-- 주문 한글 치환기
------------------------------------------------------------
local ALIAS_NORM
local function build_alias_norm_once()
  if ALIAS_NORM then return end
  ALIAS_NORM = {}
  for en, id in pairs(ALIAS) do
    if type(en)=="string" and type(id)=="number" then
      local n = normalize_key(en)
      if n ~= "" and not ALIAS_NORM[n] then ALIAS_NORM[n] = id end
    end
  end
end

local function KR_SPELL(name)
  if type(name) ~= "string" or name == "" then return name end
  local id = ALIAS[name]
  if not id then
    build_alias_norm_once()
    id = ALIAS_NORM and ALIAS_NORM[normalize_key(name)]
  end
  local ko = id and ENGB[id]
  return (ko and ko ~= "") and ko or name
end

------------------------------------------------------------
-- 메시지 재작성 (※ 전부 string.find 캡처 사용)
------------------------------------------------------------
local function rewrite_aura_message(text)
  if type(text) ~= "string" or text == "" then return text end

  -- <영문주문> 또는 <영문주문> + 꼬리말
  do
    local s,e,inner,tail = string.find(text, "^%s*%<([^>]+)%>(.*)$")
    if s then
      return "<" .. KR_SPELL(inner) .. ">" .. (tail or "")
    end
  end

  -- +버프 / -버프
  do
    local s,e,cap = string.find(text, "^%+(.*)$")
    if s then return "+" .. KR_SPELL(cap) end
  end
  do
    local s,e,cap = string.find(text, "^%-(.*)$")
    if s then return "-" .. KR_SPELL(cap) end
  end

  -- +버프 (시전자)
  do
    local s,e,cap,who = string.find(text, "^%+(.*)%s*%((.+)%)$")
    if s then return "+" .. KR_SPELL(cap) .. " (" .. who .. ")" end
  end

  -- 안전망: 영문 기본 포맷
  do
    local s,e,cap = string.find(text, "^(.*) fades$")
    if s then return "<" .. KR_SPELL(cap) .. "> fades" end
  end
  do
    local s,e,cap = string.find(text, "^(.*) fades from you$")
    if s then return "<" .. KR_SPELL(cap) .. "> fades from you" end
  end
  do
    local s,e,cap = string.find(text, "^(.*) is removed$")
    if s then return "<" .. KR_SPELL(cap) .. "> is removed" end
  end
  do
    local s,e,cap = string.find(text, "^(.*) is removed by .+$")
    if s then return "<" .. KR_SPELL(cap) .. "> is removed" end
  end

  return text
end

------------------------------------------------------------
-- 후킹 (함수 생성 시점에 맞춰 설치)
------------------------------------------------------------
-- (교체할 부분) CombatText_AddMessage 후킹
local function install_ct_hook_if_ready()
  if TooltipKOR.Aura.__ct_wrapped then return end
  local fn = (getglobal and getglobal("CombatText_AddMessage")) or (_G and _G["CombatText_AddMessage"])
  if type(fn) ~= "function" then return end
  local orig = fn

  -- 인자 개수가 버전에 따라 다를 수 있어, 여유 있게 9개까지 그대로 전달
  local function wrap(a, b, c, d, e, f, g, h, i)
    if type(a) == "string" then
      a = rewrite_aura_message(a)  -- 첫 번째 인자(메시지)만 한글 치환
    end
    return orig(a, b, c, d, e, f, g, h, i)
  end

  if setglobal then setglobal("CombatText_AddMessage", wrap) end
  if _G then _G["CombatText_AddMessage"] = wrap end
  TooltipKOR.Aura.__ct_wrapped = true
end

local function install_ui_err_hook_if_ready()
  if TooltipKOR.Aura.__err_wrapped then return end
  local f = (getglobal and getglobal("UIErrorsFrame")) or (_G and _G["UIErrorsFrame"])
  if not f or not f.AddMessage then return end
  local orig = f.AddMessage
  f.AddMessage = function(self, msg, r, g, b, id, holdTime)
    if type(msg) == "string" then msg = rewrite_aura_message(msg) end
    return orig(self, msg, r, g, b, id, holdTime)
  end
  TooltipKOR.Aura.__err_wrapped = true
end

-- 즉시 시도 + 이벤트/폴링 재시도
install_ct_hook_if_ready()
install_ui_err_hook_if_ready()

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("VARIABLES_LOADED")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == "Blizzard_CombatText" then
      install_ct_hook_if_ready()
    end
  else
    install_ct_hook_if_ready()
    install_ui_err_hook_if_ready()
  end
end)

-- 안전장치: 처음 5초간 폴링
local elapsed, limit = 0, 5
ev:SetScript("OnUpdate", function(_, dt)
  elapsed = elapsed + (dt or 0)
  if elapsed < limit then
    install_ct_hook_if_ready()
    install_ui_err_hook_if_ready()
  else
    ev:SetScript("OnUpdate", nil)
  end
end)
