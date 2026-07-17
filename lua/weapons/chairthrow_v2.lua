SWEP.PrintName = "ChairThrow V2"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ чтобы выстрелить самонаводящимся стулом"
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 3
SWEP.Primary.DefaultClip = 9
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Delay = 1
SWEP.Primary.Damage = 9999 -- ваншот
SWEP.Primary.Recoil = 5
SWEP.Primary.NumShots = 1
SWEP.Primary.Spread = 0
SWEP.Primary.MaxSpread = 0
SWEP.Primary.SpreadIncrease = 0
SWEP.Primary.SpreadRecovery = 0
SWEP.Primary.Force = 100

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 10
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 2
SWEP.SlotPos = 2

SWEP.ViewModel = "models/weapons/c_superphyscannon.mdl"
SWEP.WorldModel = "models/weapons/w_physics.mdl"
SWEP.UseHands = true

-- Настройки самонаведения (ponytail: knobs, крути под геймплей)
SWEP.HomingSpeed = 3000   -- скорость полёта стула
SWEP.HomingRange = 4000   -- дальность поиска цели
SWEP.HomingRate = 0.05    -- как часто пересчитывать курс (сек)

function SWEP:Initialize()
    self:SetHoldType("shotgun")
end

-- Ближайший живой игрок/NPC к точке pos (не владелец)
local function findTarget(pos, owner, range)
    local best, bestDist = nil, range * range
    for _, e in ipairs(ents.GetAll()) do
        if e ~= owner and (e:IsPlayer() or e:IsNPC()) and e:Health() > 0 then
            local d = e:GetPos():DistToSqr(pos)
            if d < bestDist then best, bestDist = e, d end
        end
    end
    return best
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end

    self:EmitSound("ambient/tools/physcannon_claws_clamp1.wav", 80, 90)
    if SERVER then
        local ply = self:GetOwner()
        local src = ply:GetShootPos()
        local dir = ply:GetAimVector()

        local ent = ents.Create("prop_physics")
        if not IsValid(ent) then return end
        ent:SetModel("models/props_c17/FurnitureChair001a.mdl")
        ent:SetPos(src + dir * 16)
        ent:SetAngles(dir:Angle())
        ent:Spawn()
        ent:SetOwner(ply)

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableGravity(false)
            phys:SetVelocity(dir * self.HomingSpeed)
        end

        -- Самонаведение: пересчитываем курс на ближайшую цель
        local swep = self
        timer.Create("chairhome_" .. ent:EntIndex(), self.HomingRate, 0, function()
            if not IsValid(ent) then timer.Remove("chairhome_" .. ent:EntIndex()) return end
            local p = ent:GetPhysicsObject()
            if not IsValid(p) then return end
            local tgt = findTarget(ent:GetPos(), ply, swep.HomingRange)
            if not tgt then return end
            local aim = (tgt:WorldSpaceCenter() - ent:GetPos()):GetNormalized()
            p:SetVelocity(aim * swep.HomingSpeed)
        end)

        -- Убивать всех, кого заденет стул
        ent:AddCallback("PhysicsCollide", function(chair, data)
            local hitEnt = data.HitEntity
            if IsValid(hitEnt) and (hitEnt:IsPlayer() or hitEnt:IsNPC()) then
                local dmg = DamageInfo()
                dmg:SetAttacker(ply)
                dmg:SetInflictor(swep)
                dmg:SetDamage(swep.Primary.Damage)
                dmg:SetDamageType(DMG_CRUSH)
                hitEnt:TakeDamageInfo(dmg)
                if hitEnt:IsPlayer() and hitEnt:Health() <= 0 then
                    chair:EmitSound("physics/wood/wood_furniture_break2.wav", 90, 90)
                end
            end
            timer.Remove("chairhome_" .. chair:EntIndex())
            chair:Remove()
        end)

        timer.Simple(8, function()
            if IsValid(ent) then
                timer.Remove("chairhome_" .. ent:EntIndex())
                ent:Remove()
            end
        end)
    end

    self:ShootEffects()
    self:TakePrimaryAmmo(1)

    local owner = self:GetOwner()
    if IsValid(owner) then
        owner:ViewPunch(Angle(-self.Primary.Recoil, 0, 0))
    end

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:Reload()
    self:DefaultReload(ACT_VM_RELOAD)
end

function SWEP:SecondaryAttack()
end
