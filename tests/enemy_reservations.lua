local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
for _,profile in ipairs({'bg2ee-2.6.6.0','bg2ee-steam-2.7.3.0','bgee-steam-2.6.6.0','bgee-steam-2.7.3.0'}) do
 local source=assert(io.open('bg-redux-movement/runtime/profiles/'..profile..'.lua')):read('*a')
 local function embedded(name,finish,bindings)
  local start=assert(source:find('local '..name,1,true))
  local stop=assert(source:find(finish,start,true))
  return assert(loadstring((bindings or '')..source:sub(start,stop-1)..'\nreturn '..name:match('^[%w_]+')))()
 end
 reservation_enemy=embedded('enemy_policy=','local overlap_escape')
 local policy=embedded('attack_policy=','local attack_reservations','local enemy_policy=reservation_enemy\n')
 MRIP_EnemyPrototypeEnabled=true;MRIP_AttackSpacingEnabled=true
 local e={ea=255,personal=3,action=134,attack_target=99}
 local r={enemy_ea=255,updated=1000,target=99}
 check(reservation_enemy.hold(e,r,1100),'active attack preserves reservation')
 e.action=83;check(reservation_enemy.hold(e,r,1599),'brief wait preserves reservation')
 check(not reservation_enemy.hold(e,r,1601),'long wait releases reservation')
 e.action=0;check(reservation_enemy.hold(e,r,1400),'brief idle preserves reservation')
 e.action=23;check(not reservation_enemy.hold(e,r,1100),'ordinary movement releases reservation')
 e.action=134;e.ea=200;check(not reservation_enemy.hold(e,r,1100),'allegiance change releases reservation')
 e.ea=255;e.attack_target=88;check(not reservation_enemy.hold(e,r,1100),'target change releases reservation')
 e.attack_target=99;check(not reservation_enemy.hold(e,r,2501),'stale reservation cannot persist')
 check(reservation_enemy.wait(1,100,200,99,300,1000),'initial contention starts wait')
 check(reservation_enemy.wait_recent(1,100,200,99,300,1099),'recent wait skips expensive requery')
 check(not reservation_enemy.wait_recent(1,100,200,99,300,1100),'wait rechecks available positions')
 check(reservation_enemy.wait(1,100,200,99,300,1500),'retry preserves original wait deadline')
 check(not reservation_enemy.wait(1,100,200,99,300,1600),'wait expires at 600 ms')
 check(not reservation_enemy.wait(1,100,200,99,300,3000),'expired engagement cannot restart wait')
 check(not reservation_enemy.wait_active(1,100,201,99,300,1100),'wrong area cannot inherit wait')
 check(not reservation_enemy.wait_active(1,101,200,99,300,1100),'reused actor cannot inherit wait')
 check(not reservation_enemy.wait_active(1,100,200,99,301,1100),'reused target cannot inherit wait')
 check(not reservation_enemy.wait_active(1,100,200,99,300,999),'clock rollback cancels active wait')
 check(not reservation_enemy.wait_active(1,100,200,99,300,nil),'unavailable clock cannot enforce wait')
 reservation_enemy.cancel_wait(1)
 check(reservation_enemy.wait(1,100,200,99,300,3000),'explicit release allows new contention episode')
 reservation_enemy.reset()
 local function actor(id,ea,x,y)
  return {id=id,ea=ea,x=x*16+8,y=y*12+6,personal=3,category=0,painted=1,removed=0,action=134}
 end
 local target=actor(99,2,9,9);local movers={};local actors={target}
 for id=1,5 do movers[id]=actor(id,255,14,9);actors[#actors+1]=movers[id] end
 local q={actors=actors,target=target,width=20,height=20,range=2,reservations={},enemy=true,
  clock=function() return 1000 end,started=1000}
 q.read=function(x,y)
  local raw=0;for _,a in ipairs(actors) do if policy.footprint(a,x,y) then raw=raw+16 end end;return raw
 end
 for _,m in ipairs(movers) do
  q.mover=m;local p=assert(policy.choose(q),'free enemy destination absent')
  for _,claimed in ipairs(q.reservations) do
   local dx,dy=p.x-claimed.x,p.y-claimed.y
   check(dx*dx+dy*dy>=4,'enemy endpoint reuses reserved personal frontage')
  end
  p.claim=true;q.reservations[#q.reservations+1]=p
 end
 -- Fully reserved reachable frontage waits, while ordinary party preference stays permissive.
 q.reservations={}
 for y=6,12 do for x=6,12 do q.reservations[#q.reservations+1]={x=x,y=y,claim=true} end end
 local p,why=policy.choose(q)
 check(not p and why=='enemy-slots-reserved','reserved reachable frontage produces contention reason')
 q.enemy=false;for _,m in ipairs(movers) do m.ea=2 end;target.ea=255
 check(policy.choose(q)~=nil,'party attack positions retain permissive compression')
 q.enemy=true;for _,m in ipairs(movers) do m.ea=255 end;target.ea=2;q.read=function() return 1 end
 p,why=policy.choose(q)
 check(not p and why~='enemy-slots-reserved','wall failure does not create a reservation wait')
 -- Exercise actual hook-facing wrappers: waiting sends the current point through
 -- the existing approach hook, expires, and cannot capture a different target.
 local area={ptr=200}
 local mover={m_id=1,ptr=100,m_pArea=area,m_pos={x=424,y=186},m_typeAI={m_EnemyAlly=255},m_curAction={m_actionID=134}}
 mover.getPersonalSpace=function() return 3 end
 local victim={m_id=99,ptr=300,m_pArea=area,m_pos={x=328,y=186}}
 victim.getPersonalSpace=function() return 3 end
 EEex_UDToPtr=function(o) return o.ptr end
 EEex_GameObject_IsSprite=function() return true end;EEex_CastUD=function(o) return o end
 local start=assert(source:find('function MRIP_AttackPosition(',1,true))
 local stop=assert(source:find('-- Attack overwrites its reach register',start,true))
 reservation_clock=1000
 reservation_wrapped_cache={}
 assert(loadstring('local enemy_policy=reservation_enemy\nlocal attack_policy={ally=function(ea)return ea>=2 and ea<=30 end}\n'
  ..'local attack_reservations=reservation_wrapped_cache\nlocal attack_actions={[134]=true}\nlocal function clock() return reservation_clock end\n'
  .."local function attack_select() return false,'enemy-query-budget' end\n"
  ..'local function movement_ready() return clock() end\nlocal function attack_diagnose() end\nlocal function log() end\n'
  ..source:sub(start,stop-1)))()
 check(reservation_enemy.wait(1,100,200,99,300,1000),'wrapper wait begins')
 local point={};reservation_clock=1100
 check(MRIP_AttackPosition(mover,victim,2,point),'active wait survives query budget fallback')
 check(point.x==424 and point.y==186,'wait uses current position, no push or teleport')
 check(MRIP_AttackContinue(mover,victim,2),'active wait reaches existing native approach branch')
 reservation_clock=1600
 check(not MRIP_AttackPosition(mover,victim,2,point),'expired wait permits native movement')
 check(not MRIP_AttackContinue(mover,victim,2),'expired wait permits native attack')
 reservation_clock=1100;victim.ptr=301
 check(not MRIP_AttackContinue(mover,victim,2),'different target identity bypasses wait')
 reservation_enemy.reset();victim.ptr=300
 EEex_ReadPtr=function() return 0 end
 reservation_wrapped_cache[1]={owner=100,target=99,target_ptr=300,area=200,x=22,y=15,updated=1000,enemy_ea=255}
 reservation_clock=1500
 check(not MRIP_AttackContinue(mover,victim,2),'standing attacker uses native in-range stop')
 check(reservation_wrapped_cache[1].updated==1500,'standing attacker refreshes its exclusive slot')
 reservation_clock=2800;MRIP_AttackContinue(mover,victim,2)
 check(reservation_wrapped_cache[1].updated==2800,'continuing attacks preserve slot beyond initial expiry')
 mover.m_typeAI.m_EnemyAlly=200;reservation_clock=2900;MRIP_AttackContinue(mover,victim,2)
 check(reservation_wrapped_cache[1].updated==2800,'changed enemy allegiance cannot refresh old slot')
 mover.m_typeAI.m_EnemyAlly=255
 MRIP_EnemyPrototypeEnabled=false;victim.ptr=300
 check(not MRIP_AttackContinue(mover,victim,2),'prototype off bypasses wait')
 reservation_enemy.reset()
end
print('Enemy reservations: '..checks..' actual policy/wrapper assertions across four profiles')
