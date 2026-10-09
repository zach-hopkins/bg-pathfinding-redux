local checks=0
local function check(v,msg) checks=checks+1;assert(v,msg) end
for _,profile in ipairs({'bg2ee-2.6.6.0','bg2ee-steam-2.7.3.0','bgee-steam-2.6.6.0','bgee-steam-2.7.3.0'}) do
 local source=assert(io.open('bg-redux-movement/runtime/profiles/'..profile..'.lua')):read('*a')
 local function embedded(name,finish,bindings)
  local start=assert(source:find('local '..name,1,true))
  local stop=assert(source:find(finish,start,true))
  return assert(loadstring((bindings or '')..source:sub(start,stop-1)..'\nreturn '..name:match('^[%w_]+')))()
 end
 local fragment=assert(io.open('tests/fixtures/bg_redux_enemy_cooperation.lua')):read('*a')
 check(source:find(fragment,1,true),'shared enemy policy matches shipped source')
 test_enemy=embedded('enemy_policy=','local overlap_escape')
 test_escape=embedded('overlap_escape=','local pass_policy','local enemy_policy=test_enemy\n')
 local bindings='local enemy_policy=test_enemy\nlocal overlap_escape=test_escape\n'
 local pass=embedded('pass_policy =','-- Embedded by build_mrip_prototype',bindings)
 local attack=embedded('attack_policy=','local attack_reservations',bindings)
 local function actor(id,ea,x,y)
  return {id=id,ea=ea,x=x or 168,y=y or 126,personal=3,painted=1,removed=0,
   category=0,party=ea==2,state=0,base_state=0,action=3,busy=0,bump=0}
 end
 local m=actor(1,255,120,126);m.painted=0;m.removed=1
 local a=actor(2,255)
 local function passes(cell)
  return pass.evaluate({mover=m,actors={m,a},party={},width=30,height=30,x=10,y=10,cell=cell or 16})
 end
 MRIP_AttackSpacingEnabled=true;MRIP_EnemyPrototypeEnabled=false
 check(not passes(),'default off retains enemy blocking')
 MRIP_EnemyPrototypeEnabled=true
 check(passes(),'matching hostile EA passes through')
 MRIP_AttackSpacingEnabled=false;check(not passes(),'spacing off disables cooperation')
 MRIP_AttackSpacingEnabled=true
 for _,ea in ipairs({2,30,128,200}) do
  a.ea=ea;check(not passes(),'other allegiance still blocks')
 end
 a.ea=255
 local t=actor(99,2,328,186)
 local enemies={};local actors={t}
 for id=1,6 do enemies[id]=actor(id,255,424,186);actors[#actors+1]=enemies[id] end
 local world={width=40,height=30,actors=actors,range=2,target=t,reservations={},enemy=true,
  clock=function() return 1000 end,started=1000}
 world.read=function(x,y)
  local raw=0
  for _,b in ipairs(actors) do if attack.footprint(b,x,y) then raw=raw+16 end end
  return raw
 end
 local selected={}
 for _,e in ipairs(enemies) do
  world.mover=e
  local point=assert(attack.choose(world),'enemy approach destination absent')
  check(not selected[point.y*40+point.x],'enemy attackers choose separate available positions')
  check(not attack.footprint(t,point.x,point.y),'enemy endpoint outside party target body')
  selected[point.y*40+point.x]=true;world.reservations[#world.reservations+1]=point
  world.previous=point
  local retained,reason=attack.choose(world)
  check(retained.x==point.x and retained.y==point.y and reason=='retained','stable enemy position retained')
  world.previous=nil
 end
 world.clock=function() return 1005 end
 local point,reason=attack.choose(world)
 check(not point and reason=='enemy-search-budget','slow enemy search falls back')
 world.mover=enemies[1];world.mover.x=360
 point,reason=attack.choose(world)
 check(point and reason=='selected-partial','budgeted search retains a proven reachable attack point')
 check(not attack.footprint(t,point.x,point.y),'partial search still excludes target footprint')
 check(attack.cell(world,point.x,point.y),'partial search destination is legal')
 world.read=function() return 1 end
 point=attack.choose(world)
 check(not point,'partial search does not manufacture a point through terrain')
 -- Execute the actual maintenance function with non-portrait actor identities.
 local fake_area={ptr=200}
 local sprites={}
 for id=1,2 do
  local s={ptr=100+id,m_pArea=fake_area,m_typeAI={m_EnemyAlly=255},m_curAction={m_actionID=3}}
  s.getPersonalSpace=function() return 3 end;sprites[id]=s
 end
 EEex_UDToPtr=function(s) return s.ptr end
 EEex_Sprite_GetInPortrait=function() return nil end
 EEex_Write32=function() end
 EEex_GameObject_Get=function(id) return sprites[id] end
 EEex_GameObject_IsSprite=function() return true end
 EEex_CastUD=function(s) return s end
 enemy_cleanup_fixture={reservations={[1]={owner=101,area=200,updated=1000}},
  failed={[2]={owner=102,area=200}},idle={}}
 local start=assert(source:find('local function movement_party(',1,true))
 local stop=assert(source:find('function MRIP_MovementAction(',start,true))
 local maintenance=assert(loadstring('local enemy_policy=test_enemy\nlocal buffer=0\nlocal maintenance_clock\n'
  ..'local attack_policy={ally=function(ea) return ea>=2 and ea<=30 end}\nlocal attack_actions={[3]=true}\n'
  ..'local attack_reservations,attack_failed_approaches,movement_idle=enemy_cleanup_fixture.reservations,enemy_cleanup_fixture.failed,enemy_cleanup_fixture.idle\n'
  ..source:sub(start,stop-1)..'\nreturn movement_party'))()
 maintenance(1000)
 check(enemy_cleanup_fixture.reservations[1]~=nil,'enemy reservation survives portrait maintenance')
 check(enemy_cleanup_fixture.failed[2]~=nil,'enemy native handoff survives portrait maintenance')
 enemy_cleanup_fixture.reservations[1].enemy_ea=255;sprites[1].m_curAction.m_actionID=83
 maintenance(1100)
 check(enemy_cleanup_fixture.reservations[1]~=nil,'actual maintenance retains reservation through brief SmallWait')
 sprites[1].m_curAction.m_actionID=0
 maintenance(1200)
 check(enemy_cleanup_fixture.reservations[1]~=nil,'actual maintenance retains reservation through brief idle')
 sprites[1].ptr=999;sprites[2].m_typeAI.m_EnemyAlly=128
 maintenance(1300)
 check(enemy_cleanup_fixture.reservations[1]==nil,'reused enemy identity pruned')
 check(enemy_cleanup_fixture.failed[2]==nil,'changed allegiance clears native handoff')
 for _,size in ipairs({1,2,4,7}) do
  a.personal=size;check(not test_enemy.friend(m,a),'other size not eligible')
 end
 a.personal=3
 m.attack_target=a.id;check(not passes(),'own attack target remains blocking')
 m.attack_target=nil;a.attack_target=m.id;check(not passes(),'known reverse attack target remains blocking')
 a.attack_target=nil
 check(not passes(17) and not passes(144),'static bits and closed door retained')
 check(not passes(32),'unknown occupancy stays blocking')
 test_enemy.observe(1,100,200,2,1000)
 check(test_enemy.bind(m,100,200,1001).attack_target==2,'observed target bound to actor identity')
 m.attack_target=nil;test_enemy.bind(m,101,200,1002)
 check(m.attack_target==nil,'reused identity does not inherit target')
 test_enemy.observe(1,100,200,2,1000);test_enemy.bind(m,100,200,3000)
 check(m.attack_target==nil,'expired target observations cleared')
 local q={mover=m,actors={m,a},width=30,height=30,read=function() return 16 end}
 check(attack.cell(q,10,10),'own side legal for approach selection')
 a.ea=2;check(not attack.cell(q,10,10),'opposing party excluded from enemy approach')
 a.ea=128;check(not attack.cell(q,10,10),'neutral excluded from enemy approach')
 a.ea=255
 -- Compile the full file as well as the extracted policies; do not execute hooks here.
 check(loadstring(source)~=nil,'full runtime compiles')
 check(source:find('MRIP_EnemyPrototypeEnabled=false',1,true),'prototype defaults off on launch')
 MRIP_EnemyPrototypeEnabled=false
end
print('Enemy cooperation: '..checks..' assertions across four actual runtime profiles')
