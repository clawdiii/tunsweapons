SWEP.PrintName = "Aura"
SWEP.Author = "GPT"
SWEP.Instructions = "Стулья кружат вокруг тебя и сами ваншотят врагов"
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true
SWEP.AdminOnly = true -- admin оружие

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "None"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 10
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.Slot = 2
SWEP.SlotPos = 3

SWEP.ViewModel = "models/weapons/c_superphyscannon.mdl"
SWEP.WorldModel = "models/weapons/w_physics.mdl"
SWEP.UseHands = true

-- Настройки (ponytail: knobs, крути под геймплей)
SWEP.OrbitCount = 6      -- сколько стульев кружит
SWEP.OrbitRadius = 90    -- радиус орбиты
SWEP.OrbitHeight = 40    -- высота над ногами
SWEP.OrbitSpeed = 2      -- скорость вращения (рад/сек)
SWEP.SeekRange = 3000    -- дальность поиска цели
SWEP.Damage = 9999       -- ваншот

-- Режимы (переключение на R). ponytail: knobs, крути под геймплей
SWEP.Modes = {
    -- ПВО: только воздух, скорострел + ультра точность (самонаведение на цель)
    { name = "ПВО",        cooldown = 0.1, speed = 4500, airOnly = true,  homing = true },
    { name = "Обычный",    cooldown = 0.4, speed = 3000, airOnly = false },
    { name = "Скорострел", cooldown = 0.1, speed = 3500, airOnly = false },
}
SWEP.DefaultMode = 2     -- стартуем с «Обычный»

local CHAIR_MODEL = "models/props_c17/FurnitureChair001a.mdl"

-- Цель в воздухе? (нет земли/брашей под ней) — для режима ПВО
local function IsAirborne(e)
    local tr = util.TraceLine({
        start = e:GetPos(),
        endpos = e:GetPos() - Vector(0, 0, 30),
        filter = e,
        mask = MASK_SOLID_BRUSHONLY,
    })
    return not tr.Hit
end

-- Валидная живая цель: игрок, NPC или NextBot (DrGBase — это base_nextbot)
local function IsTarget(e)
    return IsValid(e) and (e:IsPlayer() or e:IsNPC() or e:IsNextBot()) and e:Health() > 0
end

-- Точка упреждения: куда лететь снаряду скорости speed из pos, чтобы попасть
-- в цель tgtPos, движущуюся со скоростью tgtVel. Прямой полёт (гравитация выкл),
-- поэтому это точное решение задачи перехвата: |D + V*t| = speed*t.
local function InterceptPoint(pos, speed, tgtPos, tgtVel)
    local D = tgtPos - pos
    local a = tgtVel:Dot(tgtVel) - speed * speed
    local b = 2 * D:Dot(tgtVel)
    local c = D:Dot(D)
    local t
    if math.abs(a) < 1e-6 then           -- скорости почти равны: линейное уравнение
        if math.abs(b) < 1e-6 then return tgtPos end
        t = -c / b
    else
        local disc = b * b - 4 * a * c
        if disc < 0 then return tgtPos end -- не догнать — целимся в текущую позицию
        local sq = math.sqrt(disc)
        local t1, t2 = (-b + sq) / (2 * a), (-b - sq) / (2 * a)
        t = math.min(t1, t2)
        if t < 0 then t = math.max(t1, t2) end
    end
    if not t or t < 0 then return tgtPos end
    return tgtPos + tgtVel * t
end

-- Только admin может достать
function SWEP:CanPrimaryAttack() return false end

function SWEP:Initialize()
    self:SetHoldType("shotgun")
    if SERVER then self:SetNWInt("AuraMode", self.DefaultMode) end
end

-- Текущий режим (работает в обоих realm'ах через NWInt)
function SWEP:CurMode()
    return self.Modes[self:GetNWInt("AuraMode", self.DefaultMode)] or self.Modes[self.DefaultMode]
end

if SERVER then
    -- Создать один орбитальный стул
    function SWEP:SpawnOrbitChair()
        local ent = ents.Create("prop_physics")
        if not IsValid(ent) then return nil end
        ent:SetModel(CHAIR_MODEL)
        ent:Spawn()
        ent:SetOwner(self:GetOwner())
        ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS) -- орбита не бьёт игроков
        ent:SetSolid(SOLID_NONE)            -- без коллизий: не толкается о стены/игроков, не ломается при движении
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableGravity(false)
            phys:EnableMotion(false)        -- заморожена: SetPos телепортит без дрейфа
        end
        return ent
    end

    function SWEP:EnsureOrbit()
        self.Chairs = self.Chairs or {}
        for i = #self.Chairs, 1, -1 do
            if not IsValid(self.Chairs[i]) then table.remove(self.Chairs, i) end
        end
        while #self.Chairs < self.OrbitCount do
            local c = self:SpawnOrbitChair()
            if not c then break end
            table.insert(self.Chairs, c)
        end
    end

    -- Ближайший видимый живой игрок/NPC (не владелец)
    function SWEP:FindTarget()
        local ply = self:GetOwner()
        if not IsValid(ply) then return nil end
        local src = ply:GetShootPos()
        local best, bestDist = nil, self.SeekRange * self.SeekRange
        local airOnly = self:CurMode().airOnly
        for _, e in ipairs(ents.GetAll()) do
            if e ~= ply and IsTarget(e) and (not airOnly or IsAirborne(e)) then
                local d = e:WorldSpaceCenter():DistToSqr(src)
                if d < bestDist then
                    local tr = util.TraceLine({
                        start = src,
                        endpos = e:WorldSpaceCenter(),
                        filter = { ply, e, unpack(self.Chairs or {}) },
                    })
                    if not tr.Hit then best, bestDist = e, d end
                end
            end
        end
        return best
    end

    -- Запустить один стул в цель (ваншот при попадании)
    function SWEP:LaunchAt(tgt)
        if #self.Chairs == 0 then return end
        local chair = table.remove(self.Chairs)
        if not IsValid(chair) then return end

        local ply = self:GetOwner()
        chair:SetCollisionGroup(COLLISION_GROUP_NONE)
        chair:SetSolid(SOLID_VPHYSICS)      -- включаем коллизии обратно для полёта
        local phys = chair:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(true)
            phys:Wake()
            phys:EnableGravity(false)
            local speed = self:CurMode().speed
            local aim = InterceptPoint(chair:GetPos(), speed, tgt:WorldSpaceCenter(), tgt:GetVelocity())
            phys:SetVelocity((aim - chair:GetPos()):GetNormalized() * speed)
        end
        chair:EmitSound("ambient/tools/physcannon_claws_clamp1.wav", 80, 90)

        -- Ультра точность (ПВО): каждые 0.05с пересчитываем перехват на цель
        local tname = "aura_home_" .. chair:EntIndex()
        if self:CurMode().homing then
            local speed = self:CurMode().speed
            timer.Create(tname, 0.05, 0, function()
                if not IsValid(chair) or not IsTarget(tgt) then timer.Remove(tname) return end
                local p = chair:GetPhysicsObject()
                if not IsValid(p) then return end
                local a = InterceptPoint(chair:GetPos(), speed, tgt:WorldSpaceCenter(), tgt:GetVelocity())
                p:SetVelocity((a - chair:GetPos()):GetNormalized() * speed)
            end)
        end

        local swep = self
        chair:AddCallback("PhysicsCollide", function(c, data)
            local hitEnt = data.HitEntity
            if IsTarget(hitEnt) then
                local dmg = DamageInfo()
                dmg:SetAttacker(IsValid(ply) and ply or c)
                dmg:SetInflictor(c)
                dmg:SetDamage(swep.Damage)
                dmg:SetDamageType(DMG_CRUSH)
                hitEnt:TakeDamageInfo(dmg)
                c:EmitSound("physics/wood/wood_furniture_break2.wav", 90, 90)
            end
            timer.Remove(tname)
            c:Remove()
        end)

        timer.Simple(6, function()
            timer.Remove(tname)
            if IsValid(chair) then chair:Remove() end
        end)
    end

    function SWEP:Think()
        local ply = self:GetOwner()
        if not IsValid(ply) or not ply:IsAdmin() then return end

        self:EnsureOrbit()

        -- Крутим орбиту вокруг игрока
        local center = ply:GetPos() + Vector(0, 0, self.OrbitHeight)
        local t = CurTime() * self.OrbitSpeed
        local n = #self.Chairs
        for i, c in ipairs(self.Chairs) do
            if IsValid(c) then
                local a = t + (i / n) * math.pi * 2
                local pos = center + Vector(math.cos(a), math.sin(a), 0) * self.OrbitRadius
                c:SetPos(pos)
                c:SetAngles(Angle(0, math.deg(a), 0))
            end
        end

        -- Ищем цель и запускаем стул
        self.NextLaunch = self.NextLaunch or 0
        if CurTime() >= self.NextLaunch then
            local tgt = self:FindTarget()
            if tgt then
                self:LaunchAt(tgt)
                self.NextLaunch = CurTime() + self:CurMode().cooldown
            end
        end
    end

    -- Убрать стулья когда оружие спрятано/удалено
    function SWEP:CleanupChairs()
        for _, c in ipairs(self.Chairs or {}) do
            if IsValid(c) then c:Remove() end
        end
        self.Chairs = {}
    end

    function SWEP:Holster() self:CleanupChairs() return true end
    function SWEP:OnRemove() self:CleanupChairs() end
    function SWEP:OwnerChanged() self:CleanupChairs() end

    -- Переключение режима на R (с дебаунсом, т.к. Reload зовётся каждый тик удержания)
    function SWEP:Reload()
        self.NextModeSwitch = self.NextModeSwitch or 0
        if CurTime() < self.NextModeSwitch then return end
        self.NextModeSwitch = CurTime() + 0.35

        local idx = self:GetNWInt("AuraMode", self.DefaultMode) % #self.Modes + 1
        self:SetNWInt("AuraMode", idx)
        self:EmitSound("buttons/button14.wav", 75, 100)
        local ply = self:GetOwner()
        if IsValid(ply) then ply:ChatPrint("[Aura] Режим: " .. self.Modes[idx].name) end
    end
end

function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack() end
