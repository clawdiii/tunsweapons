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
SWEP.ProximityRange = 100 -- дистанция ближнего взрыва

-- Режимы (переключение на R). ponytail: knobs, крути под геймплей
SWEP.Modes = {
    -- ПВО: только воздух, скорострел + ультра точность (самонаведение на цель)
    { name = "ПВО",           cooldown = 0.1, speed = 4500, airOnly = true,  homing = true },
    { name = "Обычный",       cooldown = 0.4, speed = 3000, airOnly = false },
    { name = "Скорострел",    cooldown = 0.1, speed = 3500, airOnly = false },
    { name = "Скорострел Max", cooldown = 0.1, speed = 3500, airOnly = false, homing = true },
}
SWEP.DefaultMode = 2     -- стартуем с «Обычный»

local CHAIR_MODEL = "models/props_c17/FurnitureChair001a.mdl"
local BARREL_MODEL = "models/props_c17/oildrum001_explosive.mdl"

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
    local AuraPropEnts = {} -- таблица пропов Aura для защиты владельца
    -- Создать один орбитальный стул
    function SWEP:SpawnOrbitChair()
        local ent = ents.Create("prop_physics")
        if not IsValid(ent) then return nil end
        local propIdx = self:GetNWInt("AuraPropModel", 0)
        ent:SetModel(propIdx == 1 and BARREL_MODEL or CHAIR_MODEL)
        ent:Spawn()
        ent:SetOwner(self:GetOwner())
        ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS) -- орбита не бьёт игроков
        ent:SetSolid(SOLID_NONE)            -- без коллизий: не толкается о стены/игроков, не ломается при движении
        ent:SetRenderMode(RENDERMODE_TRANSALPHA)
        ent:SetColor(Color(255, 255, 255, 30)) -- полупрозрачный — не мешает обзору
        ent:SetHealth(999999)                -- неуязвим для взрывов на орбите
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
                    -- В упоре (< 120 ед.) проверка LOS не нужна — цель точно видна
                    if d < 120 * 120 or not util.TraceLine({
                        start = src,
                        endpos = e:WorldSpaceCenter(),
                        filter = { ply, e, unpack(self.Chairs or {}) },
                    }).Hit then
                        best, bestDist = e, d
                    end
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
        chair:SetRenderMode(RENDERMODE_NORMAL)  -- возвращаем видимость
        chair:SetColor(Color(255, 255, 255, 255))
        chair:SetHealth(999999)             -- неуязвим для взрывов других бочек в полёте
        AuraPropEnts[chair:EntIndex()] = true
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
            local isBarrel = swep:GetNWInt("AuraPropModel", 0) == 1

            if IsTarget(hitEnt) and hitEnt ~= ply then
                local dmg = DamageInfo()
                dmg:SetAttacker(IsValid(ply) and ply or c)
                dmg:SetInflictor(c)
                dmg:SetDamage(swep.Damage)
                dmg:SetDamageType(DMG_CRUSH)
                hitEnt:TakeDamageInfo(dmg)
            end

            -- Barrel — взрыв при любом столкновении (кроме владельца)
            if isBarrel and hitEnt ~= ply then
                local exp = ents.Create("env_explosion")
                if IsValid(exp) then
                    exp:SetPos(c:GetPos())
                    exp:SetOwner(ply)
                    exp:Spawn()
                    exp:SetKeyValue("iMagnitude", "150")
                    exp:Fire("Explode", 0, 0)
                    exp:Remove()
                end
                util.BlastDamage(IsValid(ply) and ply or c, c, c:GetPos(), 256, 200)
                c:EmitSound("weapons/explode/explode_explosion_short.wav", 100, 100)
            elseif not isBarrel then
                c:EmitSound("physics/wood/wood_furniture_break2.wav", 90, 90)
            end

            timer.Remove(tname)
            AuraPropEnts[c:EntIndex()] = nil
            c:Remove()
        end)

        timer.Simple(6, function()
            timer.Remove(tname)
            if IsValid(chair) then
                AuraPropEnts[chair:EntIndex()] = nil
                chair:Remove()
            end
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

        -- Ближний взрыв — враг в упоре (< ProximityRange)
        self.NextBlast = self.NextBlast or 0
        if CurTime() >= self.NextBlast then
            local airOnly = self:CurMode().airOnly
            for _, e in ipairs(ents.GetAll()) do
                if e ~= ply and IsTarget(e) and (not airOnly or IsAirborne(e)) then
                    if e:WorldSpaceCenter():DistToSqr(ply:WorldSpaceCenter()) < self.ProximityRange * self.ProximityRange then
                        local dmg = DamageInfo()
                        dmg:SetAttacker(ply)
                        dmg:SetInflictor(self)
                        dmg:SetDamage(9999999)
                        dmg:SetDamageType(DMG_BLAST)
                        e:TakeDamageInfo(dmg)
                        local exp = ents.Create("env_explosion")
                        if IsValid(exp) then
                            exp:SetPos(e:WorldSpaceCenter())
                            exp:SetOwner(ply)
                            exp:Spawn()
                            exp:SetKeyValue("iMagnitude", "200")
                            exp:Fire("Explode", 0, 0)
                            exp:Remove()
                        end
                        self.NextBlast = CurTime() + 0.25
                        break
                    end
                end
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

    -- Переключение пропа (стул ↔ взрывная бочка) по клавише T
    function SWEP:ToggleProp()
        local cur = self:GetNWInt("AuraPropModel", 0)
        local next = (cur + 1) % 2
        self:SetNWInt("AuraPropModel", next)
        self:CleanupChairs()
        local name = next == 0 and "Стул" or "Взрывная бочка"
        local ply = self:GetOwner()
        if IsValid(ply) then ply:ChatPrint("[Aura] Проп: " .. name) end
        self:EmitSound("buttons/button14.wav", 75, 100)
    end

    function SWEP:Deploy()
        local ply = self:GetOwner()
        if IsValid(ply) then ply:GodEnable() end
        return true
    end

    function SWEP:Holster()
        self:CleanupChairs()
        local ply = self:GetOwner()
        if IsValid(ply) then ply:GodDisable() end
        return true
    end

    function SWEP:OnRemove()
        self:CleanupChairs()
        local ply = self:GetOwner()
        if IsValid(ply) then ply:GodDisable() end
    end

    function SWEP:OwnerChanged()
        self:CleanupChairs()
        local ply = self:GetOwner()
        if IsValid(ply) then ply:GodDisable() end
    end

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

    -- Отражение урона обратно атакующему
    local auraReflectLock = false
    hook.Add("EntityTakeDamage", "aura_reflect", function(target, dmg)
        if not IsValid(target) or not target:IsPlayer() then return end
        if auraReflectLock then return end -- защита от зеркальной петли

        local wep = target:GetActiveWeapon()

        -- Если игрок держит Aura — отражаем весь урон
        if IsValid(wep) and wep:GetClass() == "aura" then
            local attacker = dmg:GetAttacker()
            if IsValid(attacker) and attacker ~= target then
                auraReflectLock = true
                pcall(function()
                    local reflect = DamageInfo()
                    reflect:SetAttacker(target)
                    reflect:SetInflictor(wep)
                    reflect:SetDamage(dmg:GetDamage())
                    reflect:SetDamageType(dmg:GetDamageType())
                    attacker:TakeDamageInfo(reflect)
                end)
                auraReflectLock = false
            end
            return false -- безусловно блокируем оригинальный урон
        end

        -- Fallback: блокируем урон от своих пропов и взрывов от них
        local inf = dmg:GetInflictor()
        if IsValid(inf) and AuraPropEnts[inf:EntIndex()] and inf:GetOwner() == target then
            return false
        end
        -- env_explosion от своей бочки (inflictor — env_explosion, не в AuraPropEnts)
        if dmg:GetAttacker() == target and bit.band(dmg:GetDamageType(), DMG_BLAST) ~= 0 then
            return false
        end
    end)
end

-- Команда переключения пропа (с клиента уходит на сервер)
concommand.Add("aura_switchprop", function(ply, cmd, args)
    if not IsValid(ply) or not SERVER then return end
    local wep = ply:GetActiveWeapon()
    if IsValid(wep) and wep:GetClass() == "aura" then
        wep:ToggleProp()
    end
end)

function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack() end

if CLIENT then
    -- Отслеживание нажатия N для переключения пропа
    local aura_nDown = false
    hook.Add("Think", "aura_switch_prop", function()
        local nNow = input.IsKeyDown(KEY_N)
        if nNow and not aura_nDown then
            RunConsoleCommand("aura_switchprop")
        end
        aura_nDown = nNow
    end)
end
