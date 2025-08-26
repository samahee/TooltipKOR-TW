--[[--------------------------------------------------------------------
TooltipKOR - spell.lua 메모

- SetAction 경로에서 spell 은 GetActionInfo/ GetMacroSpell 로 ID/이름을 안정 취득.
- items 모듈과 중복 방지: self.__TKOR_ITEM_DONE 가 true 면 spell 쪽 주입은 스킵.
- 플래그는 SetOwner / ClearLines 에서 항상 초기화.

---------------------------------------------------------------------]]

-- spell.lua - TooltipKOR (Vanilla 1.12.1, method-specific hooks + Mail + CreateFrame hook, no watcher)
-- 제목(첫 줄) 바로 아래(두 번째 줄)에 '한글 이름'(라벨 없음) 1줄 삽입
-- Lua 5.0 호환: '#' / '...' 미사용, string.find 캡처 사용

------------------------------------------------------------
-- 데이터 테이블 (다른 파일에서 로드됨)
-- STENGB_DB: [SpellID] = "Name_enGB" (여기서는 한글)
-- STENGB_ALIAS: [표시명(enGB/필요 시 enUS)] = 대표 SpellID
------------------------------------------------------------
local enGB  = STENGB_DB or {}
local alias = STENGB_ALIAS or {}

local ADDON_PREFIX = "[TooltipKOR] "
local DEBUG = false

local function dprint(msg)
  if DEBUG and DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. tostring(msg))
  end
end

------------------------------------------------------------
-- 유틸: 제목 텍스트 얻기
------------------------------------------------------------
local function GetTooltipTitleText(tt)
    local name = tt and tt:GetName() or "GameTooltip"
    local left1 = _G[name .. "TextLeft1"]
    if left1 and left1:GetText() then
        return left1:GetText()
    end
end

------------------------------------------------------------
-- 유틸: SpellLink에서 ID
------------------------------------------------------------
local function TryGetSpellIDFromLink(index, bookType)
    if type(GetSpellLink) == "function" then
        local link = GetSpellLink(index, bookType)
        if link then
            local _, _, id = string.find(link, "Hspell:(%d+)")
            if id then return tonumber(id) end
        end
    end
end

------------------------------------------------------------
-- 유틸: 아이템 링크/제목에서 연결 스펠 찾기
------------------------------------------------------------
local function SpellIDFromItemLink(linkOrTitle)
    if not linkOrTitle or linkOrTitle == "" then return end
    if type(GetItemSpell) == "function" then
        local sname, srank = GetItemSpell(linkOrTitle)
        if type(sname) == "string" and sname ~= "" then
            local base = string.gsub(sname, "%s*%b()", "")   -- 괄호(Rank) 제거
            base = string.gsub(base, "^%s*(.-)%s*$", "%1")
            return alias[base] or alias[sname]
        end
    end
end

-- Tooltip 본문에서 [SpellName] 등 찾기 (보조)
local function SpellIDFromTooltipBody(tt)
    local tname = tt:GetName() or "GameTooltip"
    local n = tt:NumLines() or 0
    local i = 1
    while i <= n do
        local left = _G[tname .. "TextLeft" .. i]
        if left and left:IsShown() then
            local txt = left:GetText()
            if txt and txt ~= "" then
                local _, _, inside = string.find(txt, "%[(.-)%]")
                if inside and alias[inside] then return alias[inside] end
                local base = string.gsub(txt, "%s*%b()", "")
                base = string.gsub(base, "^%s*(.-)%s*$", "%1")
                if alias[base] then return alias[base] end
                if alias[txt] then return alias[txt] end
            end
        end
        i = i + 1
    end
end

-- 제목 텍스트에서 SpellID 유추 (enUS 포함 시 alias에 있어야 함)
local function SpellIDFromTitle(title)
    if not title or title == "" then return end
    local key = string.gsub(title, "^%s*(.-)%s*$", "%1")
    local base = string.gsub(key, "%s*%b()", "")
    base = string.gsub(base, "^%s*(.-)%s*$", "%1")
    return alias[key] or alias[base]
end

------------------------------------------------------------
-- (중요) 주입 스킵 판단:
--  - 비교툴팁(ShoppingTooltip1/2): 원본 유지
--  - 캐릭터창/인스펙트/드레스업: 원본 유지
--  - ★ 은행/가방/상인/경매/우편/액션바 등은 주입 허용
------------------------------------------------------------
local function ShouldSkipInjection(tt)
    if not tt then return true end
    local tname = tt:GetName() or ""
    -- dprint("DEBUG: Tooltip GetName() = " .. tname)  -- 디버깅용 출력 추가

    -- 비교툴팁은 아예 스킵 (EQCompare 포함)
    if tname == "ShoppingTooltip1" or
       tname == "ShoppingTooltip2" or
       tname == "ItemRefTooltip"   or
       tname == "EQCompareTooltip1" or
       tname == "EQCompareTooltip2" then
        return true
    end

    -- 소유자 프레임으로 캐릭터/인스펙트/드레스업만 스킵
    local owner = tt.GetOwner and tt:GetOwner()
    local oname = owner and owner.GetName and owner:GetName() or ""
    if oname and oname ~= "" then
        -- dprint("DEBUG: Tooltip Owner Name = " .. oname)  -- 추가 디버깅용 출력
        if string.find(oname, "^Character") or
           string.find(oname, "^PaperDoll") or
           string.find(oname, "^Inspect")   or
           string.find(oname, "^DressUp") then
            return true
        end
    end

    return false
end

------------------------------------------------------------
-- 한글 이름 줄을 '제목 바로 아래'에 삽입 (우측 열 보존)
------------------------------------------------------------
-- ★ 컬러 인자(r,g,b) 추가: 기본은 흰색, 버프 훅에서만 파란색을 넘겨줌
local function InsertNameBelowTitle(tt, localizedName, r, g, b)
    if not tt or not localizedName or localizedName == "" then return end

    local function HasLine(tt2, text)
        local tn = tt2:GetName() or "GameTooltip"
        local n = tt2:NumLines() or 0
        local i = 1
        while i <= n do
            local left = _G[tn .. "TextLeft" .. i]
            if left then
                local t = left:GetText()
                if t and t == text then return true end
            end
            i = i + 1
        end
    end
    if HasLine(tt, localizedName) then return end

    local name = tt:GetName() or "GameTooltip"
    local total = tt:NumLines() or 0

    local function grab(fs)
        if fs and fs:IsShown() then
            local t = fs:GetText()
            if t and t ~= "" then
                local rr, gg, bb = fs:GetTextColor()
                return t, rr, gg, bb
            end
        end
    end

    local lines = {}
    local i = 1
    while i <= total do
        local li = _G[name .. "TextLeft" .. i]
        local ri = _G[name .. "TextRight" .. i]
        local ltxt, lr, lg, lb = grab(li)
        local rtxt, rr, rg, rb = grab(ri)
        if ltxt or rtxt then
            table.insert(lines, {l=ltxt, lr=lr, lg=lg, lb=lb, r=rtxt, rr=rr, rg=rg, rb=rb})
        end
        i = i + 1
    end

    if lines[1] and lines[1].l == localizedName then return end

    tt:ClearLines()

    if lines[1] then
        if lines[1].l and lines[1].r and tt.AddDoubleLine then
            tt:AddDoubleLine(lines[1].l, lines[1].r,
                             lines[1].lr or 1, lines[1].lg or 1, lines[1].lb or 1,
                             lines[1].rr or 1, lines[1].rg or 1, lines[1].rb or 1)
        elseif lines[1].l then
            tt:AddLine(lines[1].l, lines[1].lr or 1, lines[1].lg or 1, lines[1].lb or 1, true)
        elseif lines[1].r and tt.AddDoubleLine then
            tt:AddDoubleLine("", lines[1].r, 1, 1, 1,
                             lines[1].rr or 1, lines[1].rg or 1, lines[1].rb or 1)
        end
    end

    -- ★ 여기서 컬러 사용 (기본 흰색)
    tt:AddLine(localizedName, r or 1, g or 1, b or 1, true)
    tt.__TKOR_SPELL_DONE = true

    local count = table.getn(lines)
    i = 2
    while i <= count do
        local e = lines[i]
        if e then
            if e.l and e.r and tt.AddDoubleLine then
                tt:AddDoubleLine(e.l, e.r,
                                 e.lr or 1, e.lg or 1, e.lb or 1,
                                 e.rr or 1, e.rg or 1, e.rb or 1)
            elseif e.l then
                tt:AddLine(e.l, e.lr or 1, e.lg or 1, e.lb or 1, true)
            elseif e.r and tt.AddDoubleLine then
                tt:AddDoubleLine("", e.r, 1, 1, 1,
                                 e.rr or 1, e.rg or 1, e.rb or 1)
            end
        end
        i = i + 1
    end

    tt:Show()
end

-- ★ 색상 전달을 위해 시그니처 확장
local function InjectBySpellID(tt, spellID, r, g, b)
    if not spellID then return end
    local nameK = enGB[spellID]
    if nameK and nameK ~= "" then
        InsertNameBelowTitle(tt, nameK, r, g, b)
    end
end

-- ★ 색상 전달을 위해 시그니처 확장
local function InjectByTitleOrBody(tt, r, g, b)
    local title = GetTooltipTitleText(tt)
    local sid = SpellIDFromTitle(title)
    if not sid then sid = SpellIDFromTooltipBody(tt) end
    InjectBySpellID(tt, sid, r, g, b)
end

------------------------------------------------------------
-- 메서드별 훅(한 프레임용)을 설치하는 유틸
--  * 원본(orig)의 반환값을 반드시 보존하여 리턴한다! (중요)
------------------------------------------------------------
local function HookMethod(tt, methodName, post)  -- post(self, a1, a2, a3, a4)
    if not tt or not methodName or not post then return end
    local orig = tt[methodName]
    if type(orig) ~= "function" then return end
    tt[methodName] = function(self, a1, a2, a3, a4)
        -- 원본 실행 및 반환값 보존
        local r1, r2, r3, r4 = orig(self, a1, a2, a3, a4)
        -- 툴팁이 채워진 후에 후처리(한글 주입)
        post(self, a1, a2, a3, a4)
        -- 원본 반환값 그대로 반환
        return r1, r2, r3, r4
    end
end

local function InstallHooksForTooltip(tt)
    if not tt or tt._STK_installed then return end
    tt._STK_installed = true

    -- Reset flags on new owner / clear
    do
      local orig = tt.SetOwner
      if type(orig) == "function" then
        tt.SetOwner = function(self, a1,a2,a3,a4)
          self.__TKOR_ITEM_DONE  = nil
          self.__TKOR_SPELL_DONE = nil
          return orig(self, a1,a2,a3,a4)
        end
      end
    end
    HookMethod(tt, "ClearLines", function(self)
      self.__TKOR_ITEM_DONE  = nil
      self.__TKOR_SPELL_DONE = nil
    end)

    -- 1) Spellbook
    HookMethod(tt, "SetSpell", function(self, index, bookType)
        if ShouldSkipInjection(self) then return end
        local sid = TryGetSpellIDFromLink(index, bookType)
        if not sid then sid = SpellIDFromTitle(GetTooltipTitleText(self)) end
        InjectBySpellID(self, sid)
    end)

    -- 2) Action Bar
    HookMethod(tt, "SetAction", function(self, slot)
        if ShouldSkipInjection(self) then return end
        local sid
        if type(GetActionInfo) == "function" then
            local aType, id, subType = GetActionInfo(slot)
            if aType == "spell" and id then
                sid = TryGetSpellIDFromLink(id, subType)
            elseif aType == "macro" and id and type(GetMacroSpell) == "function" then
                local v = GetMacroSpell(id)
                if type(v) == "number" then sid = v
                elseif type(v) == "string" then sid = alias[v] end
            end
        end
        if not sid then InjectByTitleOrBody(self) else InjectBySpellID(self, sid) end
    end)

    -- 3) Trainer
    HookMethod(tt, "SetTrainerService", function(self, index)
        if ShouldSkipInjection(self) then return end
        local sid
        if type(GetTrainerServiceInfo) == "function" then
            local nameTxt = GetTrainerServiceInfo(index)
            if type(nameTxt) == "string" then sid = alias[nameTxt] end
        end
        if not sid then InjectByTitleOrBody(self) else InjectBySpellID(self, sid) end
    end)

    -- 4) Bag / Container
    HookMethod(tt, "SetBagItem", function(self, bag, slot)
        if ShouldSkipInjection(self) then return end
        local sid
        if type(GetContainerItemLink) == "function" then
            local link = GetContainerItemLink(bag, slot)
            sid = SpellIDFromItemLink(link)
        end
        if not sid then sid = SpellIDFromTooltipBody(self) end
        if not sid then sid = SpellIDFromTitle(GetTooltipTitleText(self)) end
        InjectBySpellID(self, sid)
    end)

    -- 5) Inventory
    HookMethod(tt, "SetInventoryItem", function(self, unit, slot)
        if ShouldSkipInjection(self) then return end
        local sid
        if type(GetInventoryItemLink) == "function" then
            local link = GetInventoryItemLink(unit, slot)
            sid = SpellIDFromItemLink(link)
        end
        if not sid then sid = SpellIDFromTooltipBody(self) end
        if not sid then sid = SpellIDFromTitle(GetTooltipTitleText(self)) end
        InjectBySpellID(self, sid)
    end)

    -- 6) Merchant
    HookMethod(tt, "SetMerchantItem", function(self, index)
        if ShouldSkipInjection(self) then return end
        local sid
        if type(GetMerchantItemLink) == "function" then
            local link = GetMerchantItemLink(index)
            sid = SpellIDFromItemLink(link)
        end
        if not sid then sid = SpellIDFromTooltipBody(self) end
        if not sid then sid = SpellIDFromTitle(GetTooltipTitleText(self)) end
        InjectBySpellID(self, sid)
    end)

    -- 7) Auction
    HookMethod(tt, "SetAuctionItem", function(self, listType, index)
        if ShouldSkipInjection(self) then return end
        local sid
        if type(GetAuctionItemLink) == "function" then
            local link = GetAuctionItemLink(listType, index)
            sid = SpellIDFromItemLink(link)
        end
        if not sid then sid = SpellIDFromTooltipBody(self) end
        if not sid then sid = SpellIDFromTitle(GetTooltipTitleText(self)) end
        InjectBySpellID(self, sid)
    end)

    -- 8) Quest 보상/로그
    HookMethod(tt, "SetQuestItem", function(self, qType, index)
        if ShouldSkipInjection(self) then return end
        local sid = SpellIDFromTooltipBody(self) or SpellIDFromTitle(GetTooltipTitleText(self))
        InjectBySpellID(self, sid)
    end)
    HookMethod(tt, "SetQuestLogItem", function(self, qType, index)
        if ShouldSkipInjection(self) then return end
        local sid = SpellIDFromTooltipBody(self) or SpellIDFromTitle(GetTooltipTitleText(self))
        InjectBySpellID(self, sid)
    end)

    -- 9) TradeSkill/Professions
    HookMethod(tt, "SetTradeSkillItem", function(self, skill, index)
        if ShouldSkipInjection(self) then return end
        local sid = SpellIDFromTooltipBody(self) or SpellIDFromTitle(GetTooltipTitleText(self))
        InjectBySpellID(self, sid)
    end)

    -- 10) Hyperlink
    HookMethod(tt, "SetHyperlink", function(self, link)
        if ShouldSkipInjection(self) then return end
        local sid
        local _, _, id = string.find(link or "", "Hspell:(%d+)")
        if id then sid = tonumber(id) end
        if not sid then sid = SpellIDFromItemLink(link) end
        if not sid then InjectByTitleOrBody(self) else InjectBySpellID(self, sid) end
    end)

    -- 11) Mailbox — Inbox
    HookMethod(tt, "SetInboxItem", function(self, index, attachment)
        if ShouldSkipInjection(self) then return end
        local sid
        if type(GetInboxItemLink) == "function" then
            local link
            if attachment ~= nil then
                link = GetInboxItemLink(index, attachment)
            end
            if not link then link = GetInboxItemLink(index) end
            if link then sid = SpellIDFromItemLink(link) end
        end
        if not sid then sid = SpellIDFromTooltipBody(self) end
        if not sid then sid = SpellIDFromTitle(GetTooltipTitleText(self)) end
        InjectBySpellID(self, sid)
    end)

    -- 12) Mailbox — SendMail
    HookMethod(tt, "SetSendMailItem", function(self, index)
        if ShouldSkipInjection(self) then return end
        local sid
        if type(GetSendMailItem) == "function" and type(GetItemSpell) == "function" then
            local itemName = GetSendMailItem(index)
            if type(itemName) == "string" and itemName ~= "" then
                sid = SpellIDFromItemLink(itemName)
            end
        end
        if not sid and type(GetSendMailItemLink) == "function" then
            local link2 = GetSendMailItemLink(index)
            if link2 then sid = SpellIDFromItemLink(link2) end
        end
        if not sid then sid = SpellIDFromTooltipBody(self) end
        if not sid then sid = SpellIDFromTitle(GetTooltipTitleText(self)) end
        InjectBySpellID(self, sid)
    end)

    -- 13-1) Shapeshift / Stance / Aura / Aspect / Stealth
    HookMethod(tt, "SetShapeshift", function(self, index)
        if ShouldSkipInjection(self) then return end
        local sid
        if type(GetShapeshiftFormInfo) == "function" then
            local _, name = GetShapeshiftFormInfo(index)
            if type(name) == "string" and name ~= "" then
                sid = alias[name]
            end
        end
        if not sid then InjectByTitleOrBody(self) else InjectBySpellID(self, sid) end
    end)

    -- 13-2) Pet Action Bar
    HookMethod(tt, "SetPetAction", function(self, index)
        if ShouldSkipInjection(self) then return end
        local sid
        if type(GetPetActionInfo) == "function" then
            local name, _, isToken = GetPetActionInfo(index)
            if isToken and type(getglobal) == "function" then
                name = getglobal(name)
            end
            if type(name) == "string" and name ~= "" then
                sid = alias[name]
            end
        end
        if not sid then InjectByTitleOrBody(self) else InjectBySpellID(self, sid) end
    end)

    -- 13-3) Minimap Tracking
    HookMethod(tt, "SetTracking", function(self, index)
        if ShouldSkipInjection(self) then return end
        local sid
        if type(GetTrackingInfo) == "function" then
            local name, _, _, _, spellID = GetTrackingInfo(index)
            if type(spellID) == "number" then
                sid = spellID
            elseif type(name) == "string" and name ~= "" then
                sid = alias[name]
            end
        end
        if not sid then InjectByTitleOrBody(self) else InjectBySpellID(self, sid) end
    end)

    -- 14) Trade (유저간 거래창) - 플레이어/상대 아이템 (추가)
    HookMethod(tt, "SetTradePlayerItem", function(self, index)
        if ShouldSkipInjection(self) then return end
        if self.__TKOR_ITEM_DONE then return end
        local sid
        local link
        if type(GetTradePlayerItemLink) == "function" then
            link = GetTradePlayerItemLink(index)
        end
        if (not link or link == "") and type(GetTradePlayerItemInfo) == "function" then
            local name = GetTradePlayerItemInfo(index)
            if type(name) == "string" and name ~= "" then
                link = name
            end
        end
        if link then
            sid = SpellIDFromItemLink(link)
        end
        if not sid then sid = SpellIDFromTooltipBody(self) end
        if not sid then sid = SpellIDFromTitle(GetTooltipTitleText(self)) end
        InjectBySpellID(self, sid)
    end)

    HookMethod(tt, "SetTradeTargetItem", function(self, index)
        if ShouldSkipInjection(self) then return end
        if self.__TKOR_ITEM_DONE then return end
        local sid
        local link
        if type(GetTradeTargetItemLink) == "function" then
            link = GetTradeTargetItemLink(index)
        end
        if (not link or link == "") and type(GetTradeTargetItemInfo) == "function" then
            local name = GetTradeTargetItemInfo(index)
            if type(name) == "string" and name ~= "" then
                link = name
            end
        end
        if link then
            sid = SpellIDFromItemLink(link)
        end
        if not sid then sid = SpellIDFromTooltipBody(self) end
        if not sid then sid = SpellIDFromTitle(GetTooltipTitleText(self)) end
        InjectBySpellID(self, sid)
    end)
    
    -- ★ Buff / Unit Buff / Debuff: 파란색으로 주입 (0.25, 0.75, 1.0)
    -- 6) Buff (플레이어 버프 프레임)
    if tt.SetPlayerBuff then
        HookMethod(tt, "SetPlayerBuff", function(self, index)
            if self.__TKOR_ITEM_DONE then return end
            InjectByTitleOrBody(self, 0.25, 0.75, 1.0)
        end)
    end

    -- 7) Unit Buff / Debuff (클라이언트가 제공하는 경우만)
    if tt.SetUnitBuff then
        HookMethod(tt, "SetUnitBuff", function(self, unit, index)
            if self.__TKOR_ITEM_DONE then return end
            InjectByTitleOrBody(self, 0.25, 0.75, 1.0)
        end)
    end

    if tt.SetUnitDebuff then
        HookMethod(tt, "SetUnitDebuff", function(self, unit, index)
            if self.__TKOR_ITEM_DONE then return end
            InjectByTitleOrBody(self, 0.25, 0.75, 1.0)
        end)
    end

end

------------------------------------------------------------
-- 기본 툴팁들에 설치
------------------------------------------------------------
InstallHooksForTooltip(GameTooltip)
-- 비교툴팁은 원본 유지: 설치 안 함
-- if ShoppingTooltip1 then InstallHooksForTooltip(ShoppingTooltip1) end
-- if ShoppingTooltip2 then InstallHooksForTooltip(ShoppingTooltip2) end
if ItemRefTooltip  then InstallHooksForTooltip(ItemRefTooltip)  end

------------------------------------------------------------
-- 이미 만들어진 프레임을 1회 스캔해 설치 (워처/폴링 아님)
------------------------------------------------------------
local function IsTooltipFrame(f)
    if not f or not f.GetObjectType or not f.GetName then return end
    if f:GetObjectType() ~= "GameTooltip" then return end
    local n = f:GetName()
    if not n or n == "" then return end
    if _G[n .. "TextLeft1"] then
        return true
    end
end

if EnumerateFrames then
    local f = EnumerateFrames()
    while f do
        if IsTooltipFrame(f) then
            InstallHooksForTooltip(f)
        end
        f = EnumerateFrames(f)
    end
end

-- Tooltip 본문에서 [SpellName] 등 찾기 (보조) - 안전 가드 버전
local function SpellIDFromTooltipBody(tt)
    if not tt or not tt.GetName or not tt.NumLines then return end
    local tname = tt:GetName() or "GameTooltip"
    local n = tt:NumLines() or 0
    local i = 1
    while i <= n do
        local left = (getglobal and getglobal(tname.."TextLeft"..i)) or (_G and _G[tname.."TextLeft"..i])
        if left and left.IsShown and left:IsShown() then
            local txt = left:GetText()
            if txt and txt ~= "" then
                local _, _, inside = string.find(txt, "%[(.-)%]")
                if inside and alias[inside] then return alias[inside] end
                local base = string.gsub(txt, "%s*%b()", "")
                base = string.gsub(base, "^%s*(.-)%s*$", "%1")
                if alias[base] then return alias[base] end
                if alias[txt]  then return alias[txt]  end
            end
        end
        i = i + 1
    end
end

------------------------------------------------------------
-- 이후 생성될 모든 GameTooltip 프레임에 자동 설치 (CreateFrame 후킹)
------------------------------------------------------------
if type(CreateFrame) == "function" then
    local Orig_CreateFrame = CreateFrame
    CreateFrame = function(frameType, name, parent, template)
        local f = Orig_CreateFrame(frameType, name, parent, template)
        if frameType == "GameTooltip" then
            InstallHooksForTooltip(f)
        end
        return f
    end
end

