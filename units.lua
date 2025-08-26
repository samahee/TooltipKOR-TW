-- units.lua (Vanilla 1.12.1 / Lua 5.0 safe)
-- pfQuest(enUS), pfQuest-turtle(enUS-turtle), pfDB.units["koKR"]
-- "NPC" 툴팁(플레이어/펫 제외) 제목 아래에 한글 1줄 삽입

TooltipKOR = TooltipKOR or {}
TooltipKOR.Units = TooltipKOR.Units or {}
if TooltipKOR.Units.__installed then return end
TooltipKOR.Units.__installed = true

-- =============== 공통 유틸 ===============
local NBSP = string.char(160)

local function strip_color(s)
  s = string.gsub(s or "", "|c%x%x%x%x%x%x%x%x", "")
  s = string.gsub(s, "|r", "")
  return s
end
local function trim(s)
  s = string.gsub(s or "", "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  return s
end
local function normalize_key(s)
  if type(s) ~= "string" then return s end
  s = strip_color(s)
  -- NBSP → space
  s = string.gsub(s, NBSP, " ")
  -- 약간의 전각/문자 변형 흡수
  s = string.gsub(s, "’", "'"); s = string.gsub(s, "‘", "'")
  s = string.gsub(s, "“", "\""); s = string.gsub(s, "”", "\"")
  s = string.gsub(s, "–", "-");  s = string.gsub(s, "—", "-")
  s = string.gsub(s, "[\r\n]", " ")
  s = string.gsub(s, "%s+", " ")
  s = trim(s)
  s = string.gsub(s, "^The%s+", "")
  s = string.gsub(s, "%s*%-%s*", "-")
  s = string.lower(s)
  return s
end

local function is_ascii_only(s)
  if not s or s=="" then return true end
  for i=1, string.len(s) do
    if string.byte(s, i) > 127 then return false end
  end
  return true
end

local function get_title_text(tt)
  if not tt or not tt.GetName then return end
  local name = tt:GetName() or "GameTooltip"
  local L1 = (getglobal and getglobal(name.."TextLeft1")) or (_G and _G[name.."TextLeft1"])
  if L1 and L1.GetText then return L1:GetText() end
end

-- === 안전 리사이즈 ===
local function TKOR_RefreshTooltipSize(tt)
  if not (tt and tt.GetName and tt.NumLines) then return end
  local name = tt:GetName() or "GameTooltip"
  local n    = tt:NumLines() or 0
  local maxw = 0
  for i = 1, n do
    local L = (getglobal and getglobal(name.."TextLeft"..i))  or (_G and _G[name.."TextLeft"..i])
    local R = (getglobal and getglobal(name.."TextRight"..i)) or (_G and _G[name.."TextRight"..i])
    if L and L.IsShown and L:IsShown() and L.GetStringWidth then
      local w = L:GetStringWidth() or 0; if w > maxw then maxw = w end
    end
    if R and R.IsShown and R:IsShown() and R.GetStringWidth then
      local w = R:GetStringWidth() or 0; if w > maxw then maxw = w end
    end
  end
  if tt.GetWidth and tt.SetWidth then
    local need = (maxw + 24)
    local cur  = tt:GetWidth() or 0
    if need > cur then tt:SetWidth(need) end
  end
  if tt.Show then
    if not tt.__TKOR_resizing then
      tt.__TKOR_resizing = true
      tt:Show()
      tt.__TKOR_resizing = nil
    end
  end
end

-- =============== 가드 ===============
local function is_item_tooltip(tt)
  if not (tt and tt.GetItem) then return false end
  local iname, link = tt:GetItem()
  if not link or link == "" then return false end
  local title = get_title_text(tt)
  if not title or title == "" then return false end
  local lname = string.match(link, "%[(.-)%]")
  return (lname and lname ~= "" and title == lname) or false
end

-- 1.12에는 GameTooltip:GetUnit()이 없으므로 'mouseover' 기반 판별
local function is_mouseover_unit_matching_title(tt)
  if not (UnitExists and UnitExists("mouseover") == 1) then return false end
  local title = get_title_text(tt)
  if not title or title == "" then return false end
  local uname = UnitName and UnitName("mouseover")
  if not uname or uname == "" then return false end
  return normalize_key(uname) == normalize_key(title)
end

local function is_player_or_pet(unit)
  unit = unit or "mouseover"
  if UnitExists and UnitExists(unit) == 1 then
    if UnitIsPlayer and UnitIsPlayer(unit) == 1 then return true end
    if UnitPlayerControlled and UnitPlayerControlled(unit) == 1 then return true end
  end
  return false
end

-- =============== 데이터 인덱스 ===============
local IDX_EXACT, IDX_NORM = nil, nil
local UNIT_KR = nil

local function put_exact(m, name, id)
  if not name or name=="" or not id then return end
  if not m[name] or id < m[name] then m[name] = id end
end
local function put_norm(m, name, id)
  local k = normalize_key(name)
  if not k or k=="" then return end
  if not m[k] or id < m[k] then m[k] = id end
end

local function build_indexes_once()
  if IDX_EXACT then return end
  IDX_EXACT, IDX_NORM = {}, {}
  UNIT_KR = (pfDB and pfDB["units"] and pfDB["units"]["koKR"]) or nil
  local en   = (pfDB and pfDB["units"] and pfDB["units"]["enUS"]) or nil
  local ent  = (pfDB and pfDB["units"] and pfDB["units"]["enUS-turtle"]) or nil
  local en2  = (pfDB and pfDB["units-turtle"] and pfDB["units-turtle"]["enUS"]) or nil

  local function scan(src)
    if type(src) ~= "table" then return end
    for id, name in pairs(src) do
      if type(name)=="string" and name~="" then
        put_exact(IDX_EXACT, name, id)
        put_norm(IDX_NORM,  name, id)
      end
    end
  end
  scan(en); scan(ent); scan(en2)
end

local function find_unit_id_by_title(title)
  if not title or title=="" then return end
  build_indexes_once()
  if not IDX_EXACT or not IDX_NORM then return end
  local id = IDX_EXACT[title]
  if id then return id end
  local k = normalize_key(title)
  if k and IDX_NORM[k] then return IDX_NORM[k] end
end

-- =============== pfQuest 값 접근 ===============
local function get_en_by_id(id)
  return (pfDB and pfDB["units"] and pfDB["units"]["enUS"] and pfDB["units"]["enUS"][id]) or nil
end
local function get_turtle_en_by_id(id)
  if not pfDB then return nil end
  local t1 = pfDB["units"] and pfDB["units"]["enUS-turtle"] and pfDB["units"]["enUS-turtle"][id]
  if t1 then return t1 end
  local t2 = pfDB["units-turtle"] and pfDB["units-turtle"]["enUS"] and pfDB["units-turtle"]["enUS"][id]
  return t2
end
local function get_ko_by_id(id)
  if not (UNIT_KR and id) then return end
  local v = UNIT_KR[id]
  if not v then return end
  if type(v)=="string" then
    if v ~= "" then return v end
  elseif type(v)=="table" then
    if v.name and v.name ~= "" then return v.name end
    if v[1]   and v[1]   ~= "" then return v[1]   end
  end
end

-- =============== ★ 주입 여부/내용 결정 게이트 ===============
local function TKOR_UnitPickKO(id, title)
  local EN = get_en_by_id(id)
  local TN = get_turtle_en_by_id(id)
  local KO = get_ko_by_id(id)
  if not KO or KO=="" then return nil end

  local nEN    = EN     and normalize_key(EN)     or nil
  local nTN    = TN     and normalize_key(TN)     or nil
  local nKO    =            normalize_key(KO)
  local nTITLE =            normalize_key(title or "")

  -- 터틀 변경이면 주입 금지 (TN 있고 EN과 다르거나, EN 없고 TN만 있는 경우)
  if TN and ((nEN and nTN and nTN ~= nEN) or (not EN and nTN)) then
    return nil
  end

  -- koKR 유효성: 영문/동일문자열은 주입 금지
  if is_ascii_only(KO) then return nil end
  if (nEN and nKO == nEN) or (nTN and nKO == nTN) or (nKO == nTITLE) then
    return nil
  end

  return KO
end

-- =============== 제목 아래 1줄 삽입 (기존 로직 유지, 흰색) ===============
local function insert_second_line(tt, text)
  if not tt or not text or text=="" then return end
  if not (tt.GetName and tt.NumLines and tt.AddLine and tt.ClearLines) then return end

  local name = tt:GetName() or "GameTooltip"
  local n    = tt:NumLines() or 0

  -- 중복 방지
  for i=1, n do
    local L = (getglobal and getglobal(name.."TextLeft"..i)) or (_G and _G[name.."TextLeft"..i])
    if L and L.GetText and normalize_key(L:GetText()) == normalize_key(text) then return end
  end

  local function grab(fs)
    if fs and fs.IsShown and fs:IsShown() and fs.GetText then
      local t = fs:GetText()
      if t and t ~= "" then
        local r,g,b = 1,1,1
        if fs.GetTextColor then r,g,b = fs:GetTextColor() end
        return t,r,g,b
      end
    end
  end

  local lines = {}
  for i=1, n do
    local Li = (getglobal and getglobal(name.."TextLeft"..i))  or (_G and _G[name.."TextLeft"..i])
    local Ri = (getglobal and getglobal(name.."TextRight"..i)) or (_G and _G[name.."TextRight"..i])
    local lt,lr,lg,lb = grab(Li)
    local rt,rr,rg,rb = grab(Ri)
    lines[i] = { l=lt, lr=lr, lg=lg, lb=lb, r=rt, rr=rr, rg=rg, rb=rb }
  end

  tt:ClearLines()

  if lines[1] then
    local e = lines[1]
    if e.l and e.r and tt.AddDoubleLine then
      tt:AddDoubleLine(e.l, e.r, e.lr or 1, e.lg or 1, e.lb or 1, e.rr or 1, e.rg or 1, e.rb or 1)
    elseif e.l then
      tt:AddLine(e.l, e.lr or 1, e.lg or 1, e.lb or 1, true)
    elseif e.r and tt.AddDoubleLine then
      tt:AddDoubleLine("", e.r, 1,1,1, e.rr or 1, e.rg or 1, e.rb or 1)
    end
  end

  -- 색 없이(기본 흰색) 추가
  tt:AddLine(strip_color(text), 1,1,1, true)

  for i=2, n do
    local e = lines[i]
    if e then
      if e.l and e.r and tt.AddDoubleLine then
        tt:AddDoubleLine(e.l, e.r, e.lr or 1, e.lg or 1, e.lb or 1, e.rr or 1, e.rg or 1, e.rb or 1)
      elseif e.l then
        tt:AddLine(e.l, e.lr or 1, e.lg or 1, e.lb or 1, true)
      elseif e.r and tt.AddDoubleLine then
        tt:AddDoubleLine("", e.r, 1,1,1, e.rr or 1, e.rg or 1, e.rb or 1)
      end
    end
  end

  -- 새로 추가: 크기 재계산
  TKOR_RefreshTooltipSize(tt)
end

-- =============== 주입 트리거 (기존 흐름 유지, 게이트만 교체) ===============
local function try_inject_unit_line(tt)
  if not tt or tt.__TKOR_unit_done then return end
  if is_item_tooltip(tt) == true then return end
  if not is_mouseover_unit_matching_title(tt) then return end
  if is_player_or_pet("mouseover") then return end

  local title = get_title_text(tt)
  if not title or title=="" then return end

  local uid = find_unit_id_by_title(title)
  if not uid then return end

  -- ★ 변경점: KO 선택을 게이트로 결정
  local ko = TKOR_UnitPickKO(uid, title)
  if not ko then return end

  insert_second_line(tt, ko)
  tt.__TKOR_unit_done = true
end

-- =============== OnShow/OnHide 래핑 (모듈 고유 체인 포인터) ===============
local function on_show(self)
  local frame = self or GameTooltip
  if not frame then return end
  local orig = frame.__TKOR_unit_prev_OnShow
  if type(orig) == "function" then pcall(orig, frame) end
  pcall(try_inject_unit_line, frame)
end

local function on_hide(self)
  local frame = self or GameTooltip
  if not frame then return end
  frame.__TKOR_unit_done = nil
  local orig = frame.__TKOR_unit_prev_OnHide
  if type(orig) == "function" then pcall(orig, frame) end
end

do
  local tip = GameTooltip
  if tip and tip.SetScript then
    local prevShow = tip.GetScript and tip:GetScript("OnShow")
    local prevHide = tip.GetScript and tip:GetScript("OnHide")
    tip.__TKOR_unit_prev_OnShow = prevShow
    tip.__TKOR_unit_prev_OnHide = prevHide
    tip:SetScript("OnShow", on_show)
    tip:SetScript("OnHide", on_hide)
  end
end

-- 이미 떠있는 툴팁 1회 보정
if GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown() then
  pcall(try_inject_unit_line, GameTooltip)
end
