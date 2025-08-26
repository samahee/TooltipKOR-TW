-- objects.lua — pfQuest Objects tooltip injection (WoW 1.12/Turtle)
-- 기존 파이프라인(유닛/아이템/스펠 가드, 라인 추가 방식, 훅)은 그대로 유지.
-- "주입 여부 결정 + 주입 문자열 선택"만 교체

TooltipKOR         = TooltipKOR or {}
TooltipKOR.Objects = TooltipKOR.Objects or {}
local O            = TooltipKOR.Objects

-- =========================================================
-- 공용 유틸
-- =========================================================
local NBSP = string.char(160)

local function strip_colors(s)
  if not s then return s end
  s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
  s = string.gsub(s, "|r", "")
  return s
end

-- 전각→ASCII (Lua 5.0에선 table 치환 불가 → 함수 사용)
local FW = {["："]=":",["；"]=";",["（"]="(",["）"]=")",["［"]="[",["］"]="]"}
local function norm_text(s)
  if not s or s=="" then return s end
  s = strip_colors(s)
  s = string.gsub(s, NBSP, " ")                   -- NBSP → space
  s = string.gsub(s, "[：；（）［］]", function(ch) return FW[ch] or ch end)
  s = string.gsub(s, "^%s+", ""); s = string.gsub(s, "%s+$", "")
  s = string.gsub(s, "%s+", " ")                  -- 다중 공백 축소
  s = string.lower(s)
  s = string.gsub(s, "^the%s+", "")
  return s
end
local function normalize_key(s) return norm_text(s) end

local function is_ascii_only(s)
  if not s or s=="" then return true end
  for i=1, string.len(s) do if string.byte(s,i) > 127 then return false end end
  return true
end

-- =========================================================
-- pfQuest 데이터 접근
-- =========================================================
-- koKR(오버레이 우선)
local function get_ko_by_id(id)
  if TooltipKOR_Objects_koKR and TooltipKOR_Objects_koKR[id] then
    return TooltipKOR_Objects_koKR[id]
  end
  if pfDB and pfDB.objects and pfDB.objects.koKR then
    return pfDB.objects.koKR[id]
  end
  return nil
end

-- enUS / enUS-turtle
local function get_en_by_id(id)
  return (pfDB and pfDB.objects and pfDB.objects.enUS and pfDB.objects.enUS[id]) or nil
end
local function get_turtle_en_by_id(id)
  if not pfDB then return nil end
  local t1 = pfDB.objects and pfDB.objects["enUS-turtle"] and pfDB.objects["enUS-turtle"][id]
  if t1 then return t1 end
  local t2 = pfDB["objects-turtle"] and pfDB["objects-turtle"].enUS and pfDB["objects-turtle"].enUS[id]
  return t2
end

-- 제목 → ID 역인덱스 (원본 로직 유지)
local EN_IDX, TN_IDX, IDX_BUILT = nil, nil, false
local function build_indices()
  if IDX_BUILT then return end
  EN_IDX, TN_IDX = {}, {}
  if pfDB and pfDB.objects then
    if pfDB.objects.enUS then
      for id,name in pairs(pfDB.objects.enUS) do
        if type(id)=="number" and type(name)=="string" and name~="" then
          EN_IDX[norm_text(name)] = id
        end
      end
    end
    if pfDB.objects["enUS-turtle"] then
      for id,name in pairs(pfDB.objects["enUS-turtle"]) do
        if type(id)=="number" and type(name)=="string" and name~="" then
          TN_IDX[norm_text(name)] = id
        end
      end
    end
    if pfDB["objects-turtle"] and pfDB["objects-turtle"].enUS then
      for id,name in pairs(pfDB["objects-turtle"].enUS) do
        if type(id)=="number" and type(name)=="string" and name~="" then
          TN_IDX[norm_text(name)] = id
        end
      end
    end
  end
  IDX_BUILT = true
end
local function find_object_id_by_title(title)
  if not title or title=="" then return nil end
  build_indices()
  local key = norm_text(title)
  return TN_IDX[key] or EN_IDX[key]
end

-- =========================================================
-- ★ 주입 여부 결정 + 주입 문자열 선택 (게이트)
--    정책: enUS↔enUS-turtle 다르면 스킵, koKR가 영문/동일문자열이면 스킵
-- =========================================================
local function TKOR_ObjectPickKO(id, title)
  local EN = get_en_by_id(id)
  local TN = get_turtle_en_by_id(id)
  local KO = get_ko_by_id(id)
  if not KO or KO=="" then return nil end

  local nEN    = EN     and normalize_key(EN)     or nil
  local nTN    = TN     and normalize_key(TN)     or nil
  local nKO    =            normalize_key(KO)
  local nTITLE =            normalize_key(title or "")

  -- 터틀 변경: TN 있고 (nTN ~= nEN) 또는 EN 없음 & TN 있음
  if TN and ((nEN and nTN and nTN ~= nEN) or (not EN and nTN)) then
    return nil
  end

  -- koKR 유효성
  if is_ascii_only(KO) then return nil end
  if (nEN and nKO == nEN) or (nTN and nKO == nTN) or (nKO == nTITLE) then
    return nil
  end

  return KO
end

-- =========================================================
-- 기존 파이프라인 (가드/라인추가 등) — 그대로 유지
-- =========================================================
local function get_title_text(tt)
  local name = tt and tt:GetName()
  if not name then return nil end
  local r = _G[name.."TextLeft1"]
  return r and r:GetText() or nil
end

local function is_item_tooltip(tt)
  if not tt or not tt.GetItem then return false end
  local _, link = tt:GetItem()
  return type(link)=="string" and string.find(link, "item:%d+")
end

-- 현재 프레임은 유닛 툴팁인가? (캐시 무시, 실제 mouseover만 사용) ★중요
local function is_current_unit_tooltip(tt)
  if not (UnitExists and UnitExists("mouseover") == 1) then return false end
  local title = get_title_text(tt)
  local uname = UnitName and UnitName("mouseover")
  if not title or title=="" or not uname or uname=="" then return false end
  return normalize_key(uname) == normalize_key(title)
end

-- 간단 스펠 타이틀 휴리스틱(있으면 제외)
local function looks_like_spell_title(title)
  if not title or title=="" then return false end
  if string.find(title, "%(Rank %d+%)") then return true end
  if string.find(title, "[Rr]ank%s*%d+") then return true end
  return false
end

-- “제목 바로 아래”에 한 줄 삽입 (pfQuest 색/우측열 보존) -  — Lua 5.0: table.getn 사용
local function insert_second_line(tt, text)
  if not tt or not text or text=="" then return end
  if not (tt.GetName and tt.NumLines and tt.AddLine and tt.ClearLines) then return end

  local name  = tt:GetName() or "GameTooltip"
  local total = tt:NumLines() or 0

  -- 중복 방지 (정규화 비교)
  local tgt = normalize_key(strip_colors(text))
  local i = 1
  while i <= total do
    local li = _G[name.."TextLeft"..i]
    local t  = li and li:GetText()
    if t and normalize_key(strip_colors(t)) == tgt then
      return
    end
    i = i + 1
  end

  -- 기존 라인 스냅샷: 좌/우 텍스트와 색상 보존
  local function grab(fs)
    if fs and fs.GetText then
      local t = fs:GetText()
      if t and t ~= "" then
        local r,g,b = fs:GetTextColor()
        return t,r,g,b
      end
    end
  end

  local lines = {}
  i = 1
  while i <= total do
    local li = _G[name.."TextLeft"..i]
    local ri = _G[name.."TextRight"..i]
    local ltxt, lr, lg, lb = grab(li)
    local rtxt, rr, rg, rb = grab(ri)
    if ltxt or rtxt then
      table.insert(lines, { l=ltxt, lr=lr, lg=lg, lb=lb, r=rtxt, rr=rr, rg=rg, rb=rb })
    end
    i = i + 1
  end

  -- 재구성: 1) 원래 1행 그대로  2) 한글 1줄  3) 나머지 라인 그대로
  tt:ClearLines()

  if lines[1] then
    if lines[1].l and lines[1].r and tt.AddDoubleLine then
      tt:AddDoubleLine(lines[1].l, lines[1].r,
        lines[1].lr or 1, lines[1].lg or 1, lines[1].lb or 1,
        lines[1].rr or 1, lines[1].rg or 1, lines[1].rb or 1)
    elseif lines[1].l then
      tt:AddLine(lines[1].l, lines[1].lr or 1, lines[1].lg or 1, lines[1].lb or 1, true)
    elseif lines[1].r and tt.AddDoubleLine then
      tt:AddDoubleLine("", lines[1].r, 1,1,1,
        lines[1].rr or 1, lines[1].rg or 1, lines[1].rb or 1)
    end
  end

  -- 제목 바로 아래 “한글 1줄” (흰색, 줄바꿈 허용)
  tt:AddLine(strip_colors(text), 1, 1, 1, true)

  local n = (table and table.getn and table.getn(lines)) or 0
  for idx = 2, n do
    local e = lines[idx]
    if e then
      if e.l and e.r and tt.AddDoubleLine then
        tt:AddDoubleLine(e.l, e.r,
          e.lr or 1, e.lg or 1, e.lb or 1,
          e.rr or 1, e.rg or 1, e.rb or 1)
      elseif e.l then
        tt:AddLine(e.l, e.lr or 1, e.lg or 1, e.lb or 1, true)
      elseif e.r and tt.AddDoubleLine then
        tt:AddDoubleLine("", e.r, 1,1,1,
          e.rr or 1, e.rg or 1, e.rb or 1)
      end
    end
  end

  -- 배경/폭 재계산 (원본 유틸 그대로 사용)
  if TKOR_RefreshTooltipSize then TKOR_RefreshTooltipSize(tt) end
  tt:Show()
end

-- 실제 주입 시도 (원본 흐름 유지, 단 “ko 선택”만 교체)
local function try_inject_object_line(tt)
  -- 유닛/아이템/스펠은 제외 (중요)
  if is_current_unit_tooltip(tt) then return end
  if is_item_tooltip(tt) then return end
  if tt.__TKOR_SPELL_DONE or tt.__TKOR_ITEM_DONE then return end
  
  local title = get_title_text(tt)
  if not title or title=="" then return end
  if looks_like_spell_title(title) then return end

  local oid = find_object_id_by_title(title)
  if not oid then return end

  -- ★ 변경점: koKR 선택을 게이트로 결정
  local ko = TKOR_ObjectPickKO(oid, title)
  if not ko then return end

  insert_second_line(tt, ko)
  tt.__TKOR_obj_done = true
end

-- 이 파일은 “결정 + 콘텐츠”만 바꿉니다. 훅 호출은 기존 프레임워크의 OnUpdate 등에서
-- try_inject_object_line(GameTooltip) 을 호출하는 구조를 그대로 사용하세요.
O.TryInjectObjectLine = try_inject_object_line

if not TKOR_ObjectTipDriver then
  local f = CreateFrame("Frame","TKOR_ObjectTipDriver")
  f:SetScript("OnUpdate", function()
    if GameTooltip and GameTooltip:IsVisible() then
      try_inject_object_line(GameTooltip)  -- 유닛/아이템/스펠 가드 내부에서 처리됨
    end
  end)
  TKOR_ObjectTipDriver = f
end

-- (호환용 엔트리포인트가 필요하면)
TooltipKOR = TooltipKOR or {}; TooltipKOR.Objects = TooltipKOR.Objects or {}
TooltipKOR.Objects.Process = try_inject_object_line

-- 디버그: /tkor_obj <제목>
SLASH_TKOROBJ1 = "/tkor_obj"
SlashCmdList["TKOROBJ"] = function(arg)
  local title = arg and arg ~= "" and arg or (GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText())
  if not title then DEFAULT_CHAT_FRAME:AddMessage("title?"); return end
  local id  = find_object_id_by_title(title)
  local en  = id and get_en_by_id(id) or "nil"
  local tn  = id and get_turtle_en_by_id(id) or "nil"
  local ko0 = id and get_ko_by_id(id) or "nil"
  local inj = (id and TKOR_ObjectPickKO(id, title)) or "nil"
  DEFAULT_CHAT_FRAME:AddMessage(string.format("id=%s  en=%s  tn=%s  ko=%s  → inject=%s",
    tostring(id), tostring(en), tostring(tn), tostring(ko0), tostring(inj)))
end

