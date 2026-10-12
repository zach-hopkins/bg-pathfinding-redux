-- Execute the shipped combat helper and collision policies for all four profiles.
local checks=0
local function check(v,msg) checks=checks+1;assert(v,msg) end
local profiles={'bg2ee-2.6.6.0','bg2ee-steam-2.7.3.0','bgee-steam-2.6.6.0','bgee-steam-2.7.3.0'}
local fragment=assert(io.open('tests/fixtures/bg_redux_combat.lua')):read('*a')
for _,profile in ipairs(profiles) do
 local source=assert(io.open('bg-redux-movement/runtime/profiles/'..profile..'.lua')):read('*a')
 check(source:find(fragment,1,true),'combat fixture mismatch')
 local areas,clock,writes,reads={},1000,{},0
 local world={m_gameTime=1000}

 local esc=assert(loadstring("local enemy_policy={friend=function()return false end}\n"..assert(io.open('tests/fixtures/bg_redux_overlap_escape.lua')):read('*a')))()
 local env={MRIP_OutOfCombatOnly=false,clock=function()return clock end,log=function()end,feedback=function()end,
  EEex_Write32=function(p,v)writes[p]=v end,EEex_UDToPtr=function(a)return a.ptr end}
 env.overlap_escape=esc;env.CAIObjectType={ANYONE={}}
 env.EEex_GameObject_Get=function()return nil end
 env.EEex_EngineGlobal_CBaldurChitin={m_pObjectGame={ptr=777,m_worldTime=world,m_gameAreas={get=function(_,slot)reads=reads+1;return areas[slot] end}}}
 env._G=env;setmetatable(env,{__index=_G})
 local c=assert(loadstring(fragment..'\ncombat_state=123\nreturn combat_refresh,allied_combat_blocked,combat_escape_for'))
 setfenv(c,env);local refresh,blocked,grants_for=c()
 local function clear_delay() for i=1,46 do world.m_gameTime=world.m_gameTime+1;refresh(true) end end
 local ally={m_typeAI={m_EnemyAlly=2}};local enemy={m_typeAI={m_EnemyAlly=255}}
 check(not refresh(true) and reads==0 and writes[123]==0,'default-off touches combat state')
 env.MRIP_ToggleCombatOnly();check(env.MRIP_OutOfCombatOnly and not refresh(true),'toggle into peaceful area')
 for slot=0,11 do
  areas[slot]={ptr=slot+1,m_nBattleSongCounter=-45,m_nDamageCounter=0,forAllOfTypeInRange=function()end}
 end
 check(not refresh(true),'negative inactive battle timer counts as combat')
 for slot=0,11 do
  areas[slot].m_nBattleSongCounter=1;check(refresh(true) and writes[123]==1,'loaded area combat omitted')
  check(blocked(ally) and not blocked(enemy),'enemy cooperation condition changed')
  areas[slot].m_nBattleSongCounter=0;areas[slot].m_nDamageCounter=1
  check(refresh(true),'recent damage omitted');areas[slot].m_nDamageCounter=0
 end
 clear_delay();check(not refresh(true) and writes[123]==0,'native cooldown plus delay did not clear')
 env.dialogue=true;env.cutscene=true;env.can_save=false;check(not refresh(true),'generic save restriction treated as combat')
 areas[0].m_nBattleSongCounter=1;clock=1100;check(refresh(false),'combat start not polled')
 areas[0].m_nBattleSongCounter=0;clock=1120;check(refresh(false),'50ms cache not bounded')
 clock=1150;check(refresh(false),'clear delay missing');clear_delay();check(not refresh(true),'clear delay did not expire')

 -- Real-time pauses cannot consume the game-time clear interval.
 areas[0].m_nBattleSongCounter=1;refresh(true)
 areas[0].m_nBattleSongCounter=0;refresh(true)
 clock=clock+60000;check(refresh(true),'pause consumed combat clear delay')
 for i=1,44 do world.m_gameTime=world.m_gameTime+1;check(refresh(true),'clear delay expired early') end
 world.m_gameTime=world.m_gameTime+1;check(not refresh(true),'three-second clear interval did not expire')
 -- A fresh battle/damage pulse resets the clear interval without recapturing.
 areas[0].m_nDamageCounter=1;refresh(true);areas[0].m_nDamageCounter=0;refresh(true)
 world.m_gameTime=world.m_gameTime+30;check(refresh(true),'time skip cleared combat')
 world.m_gameTime=world.m_gameTime+14;check(refresh(true),'time skip retained earlier clear credit')
 areas[0].m_nDamageCounter=1;refresh(true);areas[0].m_nDamageCounter=0;refresh(true)
 world.m_gameTime=world.m_gameTime+14;refresh(true)
 world.m_gameTime=world.m_gameTime-200;check(refresh(true),'time rewind cleared combat')
 for i=1,44 do world.m_gameTime=world.m_gameTime+1;check(refresh(true),'rewind retained clear credit') end
 world.m_gameTime=world.m_gameTime+1;check(not refresh(true),'rewind recovery did not expire')
 env.EEex_EngineGlobal_CBaldurChitin=nil;check(refresh(true),'unavailable timer should retain allied collision')
 env.MRIP_ToggleCombatOnly();check(not env.MRIP_OutOfCombatOnly and writes[123]==0,'OFF did not restore normal passage')
 local objects={}
 local area=areas[0];area.m_nBattleSongCounter=0
 local function sprite(id,x)
  local t={ptr=id*100,m_id=id,m_pArea=area,m_pos={x=x,y=126},m_typeAI={m_EnemyAlly=2}}
  t.getPersonalSpace=function()return 3 end;objects[id]=t;return t
 end
 local a,b,later=sprite(1,168),sprite(2,168),sprite(3,400)
 local scans=0
 area.forAllOfTypeInRange=function(_,x,y,kind,r,fn,los,ns)
  check(los==0 and ns==0,'combat capture applied LOS');scans=scans+1
  for _,o in pairs(objects)do fn(o)end
 end
 env.EEex_GameObject_IsSprite=function()return true end
 env.EEex_CastUD=function(o)return o end
 env.EEex_GameObject_Get=function(id)return objects[id]end
 env.EEex_EngineGlobal_CBaldurChitin={m_pObjectGame={ptr=777,m_worldTime=world,m_gameAreas={get=function(_,slot)return slot==0 and area or nil end}}}
 env.MRIP_ToggleCombatOnly();area.m_nBattleSongCounter=1;refresh(true)
 local m={id=1,owner=100,area=area.ptr,ea=2,x=168,y=126,personal=3}
 check(grants_for(m) and grants_for(m)[2] and not grants_for(m)[3],'transition capture incorrect')
 later.m_pos.x=168;refresh(true)
 check(not grants_for(m)[3] and scans==1,'walking encounter minted fresh escape')
 b.m_pos.x=400;refresh(true);check(not grants_for(m),'actual separation retained grant')
 b.m_pos.x=168;refresh(true);check(not grants_for(m),'re-overlap renewed grant')
 env.MRIP_ToggleCombatOnly();env.MRIP_ToggleCombatOnly()
 check(grants_for(m),'new activation did not capture current stack')
 a.m_pos.x=400;b.m_pos.x=400;m.x=400;refresh(true)
 check(not grants_for(m),'paired movement transported grant')
 a.m_pos.x=168;b.m_pos.x=168;m.x=168;refresh(true)
 check(not grants_for(m),'return to old position renewed grant')
 env.MRIP_ToggleCombatOnly()
 local function embedded(name,finish,bindings)
  local start=assert(source:find('local '..name,1,true));local stop=assert(source:find(finish,start,true))
  return assert(loadstring((bindings or '')..source:sub(start,stop-1)..'\nreturn '..name:match('^[%w_]+')))()
 end
 combat_enemy=embedded('enemy_policy=','local overlap_escape')
 combat_escape=embedded('overlap_escape=','local pass_policy','local enemy_policy=combat_enemy\n')
 local pass=embedded('pass_policy =','-- Embedded by build_mrip_prototype','local enemy_policy=combat_enemy\nlocal overlap_escape=combat_escape\n')
 local snap=embedded('snapshot_policy=','-- SearchThreadMain','local enemy_policy=combat_enemy\nlocal overlap_escape=combat_escape\n')
 local occupancy=embedded('attack_policy=','local attack_reservations','local enemy_policy=combat_enemy\n')
 local function actor(id,x) return {id=id,owner=id*100,area=1,ea=2,x=x,y=126,personal=3,category=0,painted=1,removed=0,party=true,state=0,base_state=0,action=23,busy=0,bump=0} end
 local m,b=actor(1,200),actor(2,168);m.painted=0;m.removed=1;m.combat_blocked=true
 local actors={m,b}
 local function raw(x,y)return combat_escape.footprint(b,x,y) and 16 or 0 end
 local function allowed(x,y,extra)return pass.evaluate({mover=m,actors=actors,party={m,b},width=30,height=30,x=x,y=y,cell=raw(x,y)+(extra or 0)})end
 check(not allowed(11,10),'combat mover entered ally footprint')
 m.combat_blocked=false;check(allowed(11,10),'normal allied passage changed')
 m.combat_blocked=true;m.x=168
 local grants=combat_escape.capture(actors);m.combat_escape=combat_escape.bind(grants,m)
 check(allowed(11,10),'exact existing ally overlap cannot escape')
 check(not allowed(11,10,128) and not allowed(11,10,1),'escape clears door/wall')
 local q={mover=m,width=30,height=30,actors=actors,read_live=raw,read_snapshot=raw}
 local patches=snap.plan(q,occupancy);check(patches and #patches==9,'private search cannot seed existing overlap escape')
 m.x=184;check(allowed(10,10),'captured combat overlap cannot take bounded inward step')
 patches=snap.plan(q,occupancy)
 for _,p in ipairs(patches)do check(combat_escape.outward(m,b,p.key%30,math.floor(p.key/30)),'private map leaves original combat grant region') end
 m.x=200;m.combat_escape=combat_escape.bind(grants,m);patches=snap.plan(q,occupancy);check(patches and #patches==0,'separated mover keeps escape grant')
 -- A newly encountered overlap must NEVER be renewed as an escape grant.
 m.x=168;check(not allowed(11,10),'combat crossing renewed escape after separation')
 local late=actor(3,168);actors[3]=late
 check(not allowed(11,10),'new combat overlap escaped without transition grant')
 actors[3]=nil
 -- Identity reuse, allegiance and area changes cannot inherit grants.
 grants=combat_escape.capture(actors);m.combat_escape=combat_escape.bind(grants,m)
 b.owner=999;check(not allowed(11,10),'reused blocker inherited escape');b.owner=200
 m.area=2;m.combat_escape=combat_escape.bind(grants,m);check(not m.combat_escape,'area transition retained escape');m.area=1
 -- Moving together cannot transport an initial escape grant across the map.
 grants=combat_escape.capture(actors);m.combat_escape=combat_escape.bind(grants,m)
 m.x=400;b.x=400;m.combat_escape=combat_escape.bind(grants,m)
 check(not allowed(25,11),'initial overlap grant traveled with moving pair')

 -- Opposing allies in a one-cell-wide corridor: each step used to move
 -- toward one blocker and away from the other, leaving both exits rejected.
 m.x=168;m.y=126;m.combat_blocked=true
 b.x=168;b.y=114
 local below=actor(3,168);below.y=138;actors[3]=below
 grants=combat_escape.capture(actors);m.combat_escape=combat_escape.bind(grants,m)
 local function crowded_raw(x,y)
  local n=0;for _,a in ipairs(actors)do if a.id~=m.id and combat_escape.footprint(a,x,y)then n=n+16 end end;return n
 end
 local function crowded(x,y,extra)
  return pass.evaluate({mover=m,actors=actors,party=actors,width=30,height=30,x=x,y=y,cell=crowded_raw(x,y)+(extra or 0)})
 end
 check(crowded(10,9) and crowded(10,11),'opposing captured allies deadlock corridor')
 check(not crowded(10,9,128) and not crowded(10,11,1),'crowded escape removed environment')
 local third=actor(4,168);third.y=114;actors[4]=third
 check(not crowded(10,9),'crowded escape removed new ally');actors[4]=nil
 third.ea=128;actors[4]=third;check(not crowded(10,9),'crowded escape removed neutral')
 third.ea=255;check(not crowded(10,9),'crowded escape removed enemy');actors[4]=nil
 q={mover=m,width=30,height=30,actors=actors,read_live=crowded_raw,read_snapshot=crowded_raw}
 patches=snap.plan(q,occupancy);check(patches and #patches>0,'crowded search failed')
 local opened={};for _,p in ipairs(patches)do opened[p.key]=p.after end
 check(opened[9*30+10]==0 and opened[11*30+10]==0,'private search still deadlocks opposing allies')
 m.y=90;m.combat_escape=combat_escape.bind(grants,m)
 m.y=126;check(not crowded(10,9),'departed cluster regranted passage')
 actors[3]=nil;m.y=126;b.y=126
 m.x=200;b.x=168;m.combat_escape=nil
 b.ea=128;check(not allowed(11,10),'neutral blocking changed')
 b.ea=255;check(not allowed(11,10),'enemy blocking changed')
 MRIP_AttackSpacingEnabled=true;MRIP_EnemyPrototypeEnabled=true;m.ea=255;m.combat_blocked=false
 check(allowed(11,10),'enemy cooperation disabled during combat')
 MRIP_EnemyPrototypeEnabled=false
 -- Native bodies contain a separate shared flag before both bypass decisions.
 local worker=source:sub(assert(source:find('local function worker_body',1,true)),assert(source:find('local function bump_body',1,true))-1)
 check(worker:find('cmp dword ptr [rax], 0',1,true) and worker:find('jne worker_deny',1,true),'worker bypass lacks combat guard')
 local bump=source:sub(assert(source:find('local function bump_body',1,true)),assert(source:find('local attack_policy',1,true))-1)
 check(bump:find('cmp dword ptr [rax], 0',1,true) and bump:find('jne bump_native',1,true),'bump bypass lacks combat guard')
end
combat_enemy=nil;combat_escape=nil
print('Combat-only option: '..checks..' assertions across four shipped profiles; timers, persistence integration, selective collision and outward escape')
