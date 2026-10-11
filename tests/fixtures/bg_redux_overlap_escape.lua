-- Escape an existing neutral/enemy overlap; never admit entry from outside.
-- Search cells are 16x12 world pixels. Permission lasts only while the mover
-- remains inside that blocker, and each non-root step must increase distance.
local P={}
function P.ally(ea) return ea>=2 and ea<=30 end
function P.footprint(a,x,y)
    local r=math.max(0,math.floor((a.personal-1)/2))
    local dx,dy=math.abs(x-math.floor(a.x/16)),math.abs(y-math.floor(a.y/12))
    return dx<=r and dy<=r and dx+dy<=math.floor(a.personal/2)+1
end
-- Combat ally escape is granted once at the collision transition, never from
-- an overlap first discovered while walking. The original footprint bounds it.
function P.combat_grant(m,a)
    local g=m and m.combat_escape and m.combat_escape[a.id]
    return g and g.owner==a.owner and g.area==a.area and m.area==g.area
        and P.footprint(g,math.floor(m.x/16),math.floor(m.y/12)) and g
end
function P.capture(actors)
    local grants,count={},0
    for _,m in ipairs(actors) do
        if P.ally(m.ea) and m.personal==3 then
            local pairs={}
            for _,a in ipairs(actors) do
                if a.id~=m.id and a.area==m.area and P.ally(a.ea)
                    and P.footprint(a,math.floor(m.x/16),math.floor(m.y/12)) then
                    count=count+1;assert(count<=4096,'combat overlap grant limit')
                    pairs[a.id]={id=a.id,owner=a.owner,area=a.area,x=a.x,y=a.y,personal=a.personal}
                end
            end
            if next(pairs) then grants[m.id]={owner=m.owner,area=m.area,pairs=pairs} end
        end
    end
    return grants,count
end
function P.bind(grants,m)
    local r=grants[m.id]
    if not r then return nil end
    if r.owner~=m.owner or r.area~=m.area or not P.ally(m.ea) or m.personal~=3 then grants[m.id]=nil;return nil end
    for id,g in pairs(r.pairs) do
        if not P.footprint(g,math.floor(m.x/16),math.floor(m.y/12)) then r.pairs[id]=nil end
    end
    if not next(r.pairs) then grants[m.id]=nil;return nil end
    return r.pairs
end
function P.overlapping(m,a)
    return m and m.id~=a.id and P.ally(m.ea) and m.personal==3
        and (a.ea==128 or a.ea>=200 and a.ea<=255 or m.combat_blocked and P.ally(a.ea) and P.combat_grant(m,a))
        and a.personal>=1 and a.personal<=255 and a.x>=0 and a.y>=0
        and P.footprint(a,math.floor(m.x/16),math.floor(m.y/12))
end
function P.outward(m,a,x,y)
    if not P.overlapping(m,a) then return false end
    local mx,my=math.floor(m.x/16),math.floor(m.y/12)
    if x==mx and y==my then return true end -- the path search's root cell
    local anchor=m.combat_blocked and P.ally(a.ea) and P.combat_grant(m,a) or a
    local ax,ay=math.floor(anchor.x/16),math.floor(anchor.y/12)
    local dx,dy=mx-ax,my-ay
    local nx,ny=x-ax,y-ay
    return nx*nx+ny*ny>dx*dx+dy*dy and (x-mx)*dx+(y-my)*dy>=0
end
function P.cell(q,x,y)
    if x<0 or y<0 or x>=q.width or y>=q.height then return false end
    local raw=q.read(x,y)
    if raw<0 or raw>255 or raw>=128 or raw%2~=0 then return false end
    local low,high=0,0
    for _,a in ipairs(q.actors) do
        local inside=P.footprint(a,x,y)
        if inside and not (q.mover and a.id==q.mover.id or (not q.mover or not q.mover.combat_blocked and P.ally(q.mover.ea)) and P.ally(a.ea))
            and not enemy_policy.friend(q.mover,a) and not P.outward(q.mover,a,x,y) then return false end
        if a.painted==1 and a.removed==0 then
            if inside then
                if a.category==0 then high=high+1 else low=low+1 end
            end
        elseif a.painted~=0 or a.removed~=1 then return false end
    end
    return low<8 and high<8 and low==math.floor(raw/2)%8 and high==math.floor(raw/16)%8
end
return P
