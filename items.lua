-- items.lua (Vanilla 1.12 / Turtle / Lua 5.0 safe)
-- pfQuest(enUS), pfQuest-turtle(enUS-turtle) + data/items_koKR.lua 사용
-- 제목 아래 한 줄 koKR 삽입. 삽입 시 tt.__TKOR_ITEM_DONE = true 로 마킹 (spell 중복 방지).

TooltipKOR = TooltipKOR or {}
TooltipKOR.Items = TooltipKOR.Items or {}
local M = TooltipKOR.Items

-- koKR 로컬 데이터(필수)
local KO = TooltipKOR_Items_koKR or {}

-- ========= 공통 유틸 =========
local function GetTooltipTitleText(tt)
  local name = tt and tt:GetName() or "GameTooltip"
  local left1 = (getglobal and getglobal(name.."TextLeft1")) or (_G and _G[name.."TextLeft1"])
  if left1 and left1.GetText then return left1:GetText() end
end

local function norm(s)
  if not s then return s end
  s = string.gsub(s, "|c%x%x%x%x%x%x%x%x","")
  s = string.gsub(s, "|r","")
  s = string.gsub(s, "^%s+","")
  s = string.gsub(s, "%s+$","")
  return s
end

-- 추가: 비교용 정규화(주입 결정 게이트 전용, 기존 파이프라인에는 영향 없음)
local NBSP = string.char(160)
local function normalize_key(s)
  if not s then return s end
  s = norm(s)
  s = string.gsub(s, NBSP, " ")
  s = string.gsub(s, "%s+", " ")
  s = string.lower(s)
  return s
end
local function is_ascii_only(s)
  if not s or s=="" then return true end
  for i=1, string.len(s) do if string.byte(s,i) > 127 then return false end end
  return true
end

-- Lua 5.0 호환 길이
local function t_len(t)
  if type(table)=="table" and table.getn then return table.getn(t) end
  local n=0; for i,_ in ipairs(t) do n=i end; return n
end

-- === 툴팁 크기 자동 확장 ===
local function TKOR_RefreshTooltipSize(tt)
  if not (tt and tt.GetName and tt.NumLines) then return end
  local name = tt:GetName() or "GameTooltip"
  local n    = tt:NumLines() or 0
  local maxw = 0
  for i=1, n do
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
-- =============================

-- "제목 아래 1줄" 삽입
local function InsertNameBelowTitle(tt, localizedName)
  if not tt or not localizedName or localizedName == "" then return end
  local function HasLine(tt2, text)
    local tn = tt2:GetName() or "GameTooltip"
    local n = tt2.NumLines and tt2:NumLines() or 0
    for i=1, n do
      local left = (getglobal and getglobal(tn.."TextLeft"..i)) or (_G and _G[tn.."TextLeft"..i])
      if left and left.GetText and left:GetText() == text then return true end
    end
  end
  if HasLine(tt, localizedName) then
    tt.__TKOR_ITEM_DONE = true
    return
  end

  local name = tt:GetName() or "GameTooltip"
  local total = tt.NumLines and tt:NumLines() or 0
  local function grab(fs)
    if fs and fs.IsShown and fs:IsShown() then
      local t = fs:GetText()
      if t and t ~= "" then
        local r,g,b = 1,1,1; if fs.GetTextColor then r,g,b = fs:GetTextColor() end
        return t,r,g,b
      end
    end
  end
  local lines = {}
  for i=1, total do
    local li = (getglobal and getglobal(name.."TextLeft"..i)) or (_G and _G[name.."TextLeft"..i])
    local ri = (getglobal and getglobal(name.."TextRight"..i)) or (_G and _G[name.."TextRight"..i])
    local ltxt,lr,lg,lb = grab(li)
    local rtxt,rr,rg,rb = grab(ri)
    if ltxt or rtxt then
      table.insert(lines, {l=ltxt, lr=lr, lg=lg, lb=lb, r=rtxt, rr=rr, rg=rg, rb=rb})
    end
  end
  if lines[1] and lines[1].l == localizedName then
    tt.__TKOR_ITEM_DONE = true
    return
  end
  if tt.ClearLines then tt:ClearLines() end
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
  if tt.AddLine then tt:AddLine(localizedName, 1,1,1, true) end
  for i=2, t_len(lines) do
    local e = lines[i]
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
  TKOR_RefreshTooltipSize(tt)  -- << 자동 확장
  tt.__TKOR_ITEM_DONE = true
end

-- 스킵 규칙
local function ShouldSkipInjection(tt)
  if not tt then return true end
  local tname = tt:GetName() or ""
  
  -- 비교 툴팁은 스킵 (EQCompare 포함)
  if tname == "ShoppingTooltip1" or
     tname == "ShoppingTooltip2" or
     tname == "EQCompareTooltip1" or
     tname == "EQCompareTooltip2" then
      return true
  end
  
  local owner = tt.GetOwner and tt:GetOwner()
  local oname  = owner and owner.GetName and owner:GetName() or ""
  if oname and oname ~= "" then
    if string.find(oname, "^Character") or
       string.find(oname, "^PaperDoll") or
       string.find(oname, "^Inspect")   or
       string.find(oname, "^DressUp") then
      return true
    end
  end
  return false
end

-- pfDB 역인덱스
local REV = nil
local function build_rev()
  if REV then return end
  REV = {}
  local function add_src(tbl)
    if not tbl then return end
    for id,name in pairs(tbl) do
      if type(id)=="number" and type(name)=="string" then
        name = norm(name)
        if name ~= "" and not REV[name] then REV[name]=id end
      end
    end
  end
  if pfDB and pfDB.items then
    add_src(pfDB.items.enUS)
    add_src(pfDB.items["enUS-turtle"])
  end
end

local function getKO(id)
  if not id then return nil end
  if KO[id] and KO[id] ~= "" then return KO[id] end
  if pfDB and pfDB.items and pfDB.items.koKR and pfDB.items.koKR[id] then
    return pfDB.items.koKR[id]
  end
  return nil
end

-- enUS / enUS-turtle 조회(게이트에서 사용)
local function getEN(id)
  return (pfDB and pfDB.items and pfDB.items.enUS and pfDB.items.enUS[id]) or nil
end
local function getTN(id)
  if not pfDB then return nil end
  local t1 = pfDB.items and pfDB.items["enUS-turtle"] and pfDB.items["enUS-turtle"][id]
  if t1 then return t1 end
  local t2 = pfDB["items-turtle"] and pfDB["items-turtle"].enUS and pfDB["items-turtle"].enUS[id]
  return t2
end

-- ★ 주입 여부/내용 선택 게이트: EN ↔ TN 비교 후 KO 결정
local function TKOR_ItemPickKO(id, title)
  local KOtext = getKO(id); if not KOtext or KOtext=="" then return nil end
  local EN = getEN(id); local TN = getTN(id)
  local nEN    = EN     and normalize_key(EN)     or nil
  local nTN    = TN     and normalize_key(TN)     or nil
  local nKO    =            normalize_key(KOtext)
  local nTITLE =            normalize_key(title or "")

  -- 터틀 변경: TN 있고 EN과 다르거나, EN 없음 & TN만 있음 → 주입 금지
  if TN and ((nEN and nTN and nTN ~= nEN) or (not EN and nTN)) then
    return nil
  end

  -- KO 유효성: 영문/동일문자열은 주입 금지
  if is_ascii_only(KOtext) then return nil end
  if (nEN and nKO == nEN) or (nTN and nKO == nTN) or (nKO == nTITLE) then
    return nil
  end

  return KOtext
end

local function parse_itemid_from_link(link)
  if type(link)~="string" then return nil end
  local _,_,id = string.find(link, "Hitem:(%d+)")
  if not id then _,_,id = string.find(link, "^item:(%d+)") end
  return id and tonumber(id) or nil
end

-- ★★★ 핵심: 주입 전 “무엇을 주입할지/할지 말지”만 게이트로 결정. 나머지 파이프라인은 그대로.
local function InjectItemByLinkOrTitle(tt, linkOpt)
  if ShouldSkipInjection(tt) then return end
  if type(linkOpt)=="string" and string.sub(linkOpt,1,6)=="spell:" then return end

  local title_now = GetTooltipTitleText(tt) or ""

  -- 1) 링크에 ID가 있으면 ID기반으로 결정
  local id = parse_itemid_from_link(linkOpt or "")
  if id then
    local ko = TKOR_ItemPickKO(id, title_now)
    if ko then InsertNameBelowTitle(tt, ko) end
    return
  end

  -- 2) 링크가 없으면 제목→ID 역검색 후 결정(기존 REV 그대로 사용)
  build_rev()
  local en = norm(title_now)
  if not en or en=="" then return end
  local rid = REV[en]
  if rid then
    local ko = TKOR_ItemPickKO(rid, title_now)
    if ko then InsertNameBelowTitle(tt, ko) end
  end
end

-- ========= 후킹 유틸 =========
local function HookMethod(tt, methodName, post)
  local orig = tt and tt[methodName]
  if type(orig) ~= "function" then return end
  tt[methodName] = function(self, a1, a2, a3, a4)
    local r1,r2,r3,r4 = orig(self, a1,a2,a3,a4)
    post(self, a1,a2,a3,a4)
    return r1,r2,r3,r4
  end
end

-- ========= 핵심: 액션바 아이템 지원 =========
-- pending 슬롯 기록 → OnUpdate 드라이버가 안전 시점에 주입 시도
local function TryInjectFromActionSlot(tt)
  local slot = tt.__TKOR_pending_actionslot
  if not slot then return end
  if tt.__TKOR_ITEM_DONE then return end
  if ShouldSkipInjection(tt) then return end

  -- 1) 정석: GetActionInfo
  local atype, id = (type(GetActionInfo)=="function") and GetActionInfo(slot)
  if atype == "item" and id then
    local title_now = GetTooltipTitleText(tt) or ""
    local ko = TKOR_ItemPickKO(id, title_now)
    if ko then InsertNameBelowTitle(tt, ko) end
    return
  end

  -- 2) 지연: 툴팁에서 직접 링크 뽑기
  if tt.GetItem then
    local _, link = tt:GetItem()
    if link then
      InjectItemByLinkOrTitle(tt, link)
      return
    end
  end

  -- 3) 최후: 제목 역인덱스
  build_rev()
  local en = norm(GetTooltipTitleText(tt))
  if en and en ~= "" then
    local rid = REV[en]
    if rid then
      local title_now = GetTooltipTitleText(tt) or ""
      local ko = TKOR_ItemPickKO(rid, title_now)
      if ko then InsertNameBelowTitle(tt, ko) end
    end
  end
end

local function InstallHooksForTooltip(tt)
  if not tt or tt._TKOR_items_installed then return end
  tt._TKOR_items_installed = true

  -- 새 오너/클리어 시 플래그 리셋 (액션바 pending 포함)
  do
    local orig = tt.SetOwner
    if type(orig) == "function" then
      tt.SetOwner = function(self, a1, a2, a3, a4)
        self.__TKOR_ITEM_DONE  = nil
        self.__TKOR_SPELL_DONE = nil
        self.__TKOR_pending_actionslot = nil
        self.__TKOR_last_title = nil
        return orig(self, a1, a2, a3, a4)
      end
    end
  end
  HookMethod(tt, "ClearLines", function(self)
    self.__TKOR_ITEM_DONE  = nil
    self.__TKOR_SPELL_DONE = nil
    self.__TKOR_pending_actionslot = nil
    self.__TKOR_last_title = nil
  end)

  -- ★ 액션바: SetAction 후킹 (슬롯 기록 + 즉시 1회 시도)
  HookMethod(tt, "SetAction", function(self, slot)
    self.__TKOR_ITEM_DONE = nil
    self.__TKOR_pending_actionslot = slot
    pcall(TryInjectFromActionSlot, self)
  end)

  -- 1) 하이퍼링크(아이템)
  HookMethod(tt, "SetHyperlink", function(self, link)
    if type(link)=="string" and string.find(link, "item:") then
      InjectItemByLinkOrTitle(self, link)
    end
  end)

  -- 2) 가방/은행
  HookMethod(tt, "SetBagItem", function(self, bag, slot)
    local link = (type(GetContainerItemLink)=="function") and GetContainerItemLink(bag, slot)
    InjectItemByLinkOrTitle(self, link)
  end)

  -- 3) 인벤/장비/은행 슬롯
  HookMethod(tt, "SetInventoryItem", function(self, unit, slot)
    local link = (type(GetInventoryItemLink)=="function") and GetInventoryItemLink(unit, slot)
    InjectItemByLinkOrTitle(self, link)
  end)

  -- 4) 상인
  HookMethod(tt, "SetMerchantItem", function(self, index)
    local link = (type(GetMerchantItemLink)=="function") and GetMerchantItemLink(index)
    InjectItemByLinkOrTitle(self, link)
  end)

  -- 5) 경매
  HookMethod(tt, "SetAuctionItem", function(self, listType, index)
    local link = (type(GetAuctionItemLink)=="function") and GetAuctionItemLink(listType, index)
    InjectItemByLinkOrTitle(self, link)
  end)

  -- 6) 퀘스트 보상/로그
  HookMethod(tt, "SetQuestItem", function(self, qType, index)
    InjectItemByLinkOrTitle(self, nil)
  end)
  HookMethod(tt, "SetQuestLogItem", function(self, qType, index)
    InjectItemByLinkOrTitle(self, nil)
  end)

  -- 7) 우편함(받은/보내는)
  HookMethod(tt, "SetInboxItem", function(self, index, attachment)
    local link
    if type(GetInboxItemLink)=="function" then
      if attachment ~= nil then link = GetInboxItemLink(index, attachment) end
      if not link then link = GetInboxItemLink(index) end
    end
    InjectItemByLinkOrTitle(self, link)
  end)
  HookMethod(tt, "SetSendMailItem", function(self, index)
    local link = (type(GetSendMailItemLink)=="function") and GetSendMailItemLink(index)
    if not link and type(GetSendMailItem)=="function" then
      local name = GetSendMailItem(index)
      if type(name)=="string" and name~="" then link = name end
    end
    InjectItemByLinkOrTitle(self, link)
  end)

  -- 8) 거래창(양쪽)
  HookMethod(tt, "SetTradePlayerItem", function(self, idx)
    local link = (type(GetTradePlayerItemLink)=="function") and GetTradePlayerItemLink(idx)
    if not link and type(GetTradePlayerItemInfo)=="function" then
      local nm = GetTradePlayerItemInfo(idx); if type(nm)=="string" and nm~="" then link = nm end
    end
    InjectItemByLinkOrTitle(self, link)
  end)
  HookMethod(tt, "SetTradeTargetItem", function(self, idx)
    local link = (type(GetTradeTargetItemLink)=="function") and GetTradeTargetItemLink(idx)
    if not link and type(GetTradeTargetItemInfo)=="function" then
      local nm = GetTradeTargetItemInfo(idx); if type(nm)=="string" and nm~="" then link = nm end
    end
    InjectItemByLinkOrTitle(self, link)
  end)
end

-- 기본 툴팁들에 설치
InstallHooksForTooltip(GameTooltip)
-- 채팅 링크 툴팁(ItemRefTooltip)에도 동일 주입
if ItemRefTooltip then InstallHooksForTooltip(ItemRefTooltip) end

-- 이미 만들어진 프레임을 1회 스캔
local function IsTooltipFrame(f)
  if not f or not f.GetObjectType or not f.GetName then return end
  if f:GetObjectType() ~= "GameTooltip" then return end
  local n = f:GetName()
  if not n or n == "" then return end
  if (getglobal and getglobal(n.."TextLeft1")) or (_G and _G[n.."TextLeft1"]) then return true end
end
if EnumerateFrames then
  local f = EnumerateFrames()
  while f do
    if IsTooltipFrame(f) then InstallHooksForTooltip(f) end
    f = EnumerateFrames(f)
  end
end

-- 이후 생성될 GameTooltip에도 자동 설치
if type(CreateFrame) == "function" then
  local Orig_CreateFrame = CreateFrame
  CreateFrame = function(frameType, name, parent, template)
    local f = Orig_CreateFrame(frameType, name, parent, template)
    if frameType == "GameTooltip" then InstallHooksForTooltip(f) end
    return f
  end
end

-- === 액션바용 드라이버(20Hz) ===
-- SetAction 직후 GetItem()이 nil인 프레임을 보완하기 위한 지연 재주입
local TKOR_Item_Driver = CreateFrame("Frame")
local __acc = 0
TKOR_Item_Driver:SetScript("OnUpdate", function()
  local elapsed = arg1 or 0
  __acc = __acc + (elapsed or 0)
  if __acc < 0.05 then return end  -- 20Hz
  __acc = 0

  local tip = GameTooltip
  if not (tip and tip.IsShown and tip:IsShown()) then return end

  -- 제목이 바뀌면 재시도 허용
  local title = GetTooltipTitleText(tip)
  if title ~= tip.__TKOR_last_title then
    tip.__TKOR_last_title = title
    tip.__TKOR_ITEM_DONE = nil
  end

  if not tip.__TKOR_ITEM_DONE then
    if tip.__TKOR_pending_actionslot then
      pcall(TryInjectFromActionSlot, tip)
    else
      -- 다른 출처에서도 링크가 늦게 들어오는 케이스 보정
      if tip.GetItem then
        local _, link = tip:GetItem()
        if link then InjectItemByLinkOrTitle(tip, link) end
      end
    end
  end
end)



-- === /itemto : koKR -> enUS 이름 출력 (공백 무시 검색) ===
-- 기존 /itemto 블록을 이 코드로 교체하세요. 권장 위치: 파일 맨 하단(드라이버 뒤)

-- koKR 텍스트 -> 아이템ID 역인덱스 (공백 제거 키)
local REV_KO_NS = nil

-- 공백 제거 정규화 (색코드 제거, trim, NBSP 처리 → 모든 공백 삭제)
local function norm_ko_nospace(s)
  if not s then return "" end
  s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
  s = string.gsub(s, "|r", "")
  s = string.gsub(s, string.char(160), " ") -- NBSP -> space
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  s = string.gsub(s, "%s+", "")            -- ★ 모든 공백 제거
  if string.lower then s = string.lower(s) end
  return s
end

local function build_rev_ko_nospace()
  if REV_KO_NS then return end
  REV_KO_NS = {}
  local function add_src(tbl)
    if not tbl then return end
    for id, name in pairs(tbl) do
      if type(id)=="number" and type(name)=="string" then
        local k = norm_ko_nospace(name)
        if k ~= "" and not REV_KO_NS[k] then
          REV_KO_NS[k] = id
        end
      end
    end
  end
  -- 1) 로컬 KO 테이블
  add_src(TooltipKOR_Items_koKR or KO)
  -- 2) pfDB koKR 병합(보조 소스)
  if pfDB and pfDB.items and pfDB.items.koKR then
    add_src(pfDB.items.koKR)
  end
end

-- enUS 우선, 없으면 turtle enUS
local function getENorTN(id)
  local en = getEN and getEN(id) or nil
  if en and en ~= "" then return en end
  local tn = getTN and getTN(id) or nil
  return tn
end

SLASH_ITEMTO1 = "/itemto"
SLASH_ITEMTO2 = "/검색"

SlashCmdList["ITEMTO"] = function(msg)
  if not msg then return end
  msg = string.gsub(msg, "^%s+", "")
  msg = string.gsub(msg, "%s+$", "")
  if msg == "" then return end

  build_rev_ko_nospace()
  local key = norm_ko_nospace(msg)   -- ★ 입력도 공백 무시
  local id  = REV_KO_NS[key]
  if not id then return end

  local en = getENorTN(id)
  if en and en ~= "" and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(en)  -- 오직 영어 이름만 출력
  end
end

