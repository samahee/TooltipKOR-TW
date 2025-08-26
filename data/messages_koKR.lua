-- data/messages_koKR.lua
-- GlobalStrings의 특정 메시지에서 %s 부분만 koKR로 치환하기 위한 규칙표.
-- key: GlobalStrings 변수명(예: "ERR_LEARN_ABILITY_S")
-- type: "spell" | "item" | "map"  (치환 원본의 종류)
-- tpl : (선택) 출력 문장 템플릿. 없으면 클라이언트 기본(GlobalStrings[key])을 그대로 사용.
--       %s 자리에 한글 치환 결과가 들어갑니다.

TooltipKOR_ChatRules = {
  -- 예시 3개 (주인님이 계속 추가/수정하세요)
  ERR_LEARN_ABILITY_S = { type = "spell", tpl = "새로운 능력을 익혔습니다: %s" },
  ERR_AUCTION_WON_S = { type = "item",  tpl = "%s 경매에 낙찰되었습니다." },
  ERR_DEATHBIND_SUCCESS_S = { type = "map",   tpl = "이제부터 %s 여관에 머무릅니다." },
  ERR_AUCTION_SOLD_S  = { type = "item",   tpl = "경매에 올린 %s|1이;가; 판매되었습니다."},
  ERR_LEARN_RECIPE_S  = { type = "spell",   tpl = "새로운 제조 방법을 익혔습니다: %s"},
  ERR_LEARN_SPELL_S = { type = "spell",   tpl = "새로운 주문을 익혔습니다: %s"},
  ERR_PROFICIENCY_GAINED_S  = { type = "spell",   tpl = "전문 기술로 %s|1을;를; 배웠습니다."},
  ERR_SKILL_GAINED_S  = { type = "spell",   tpl = "기술을 습득했습니다: %s"},
  ERR_SKILL_UP_SIZE = { type = "spell",   tpl = "기술이 향상되었습니다: %s (%d)"},
  ERR_SPELL_ALREADY_KNOWN_S = { type = "spell",   tpl = "이미 습득했습니다: %s"},
  ERR_SPELL_UNLEARNED_S = { type = "spell",   tpl = "%s 습득을 취소했습니다."},
  CONFIRM_BINDER  = { type = "map",     tpl = "%s|1을;를; 새로운 귀환 장소로 설정하겠습니까?"},
  
  
  
  -- 아래처럼 계속 추가
  -- SOME_GLOBAL_STRING_NAME  = { type = "spell", tpl = "~~ %s ~~" },
}
