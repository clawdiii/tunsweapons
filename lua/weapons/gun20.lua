-- Gravity Hammer: Melee weapon — heavy swing + gravity slam shockwave

SWEP.PrintName = "Gravity Hammer"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — тяжёлый удар с отбрасыванием. ПКМ — гравитационный удар по земле (отбрасывает всех вокруг)."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "None"
SWEP.Primary.Delay = 0.7
SWEP.Primary.Damage = 75
SWEP.Primary.Force = 1200
SWEP.Primary.Range = 120
SWEP.Primary.Recoil = 6

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"
SWEP.Secondary.Delay = 4
SWEP.Secondary.Radius = 340
SWEP.Secondary.Force = 7000

SWEP.Weight = 6
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.Slot = 2
SWEP.SlotPos = 5

SWEP.ViewModel = "models/weapons/c_stunstick.mdl"
SWEP.WorldModel = "models/weapons/w_stunbaton.mdl"
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("melee")
end

-- Trace an arc in front of the player so the swing reliably connects.
function SWEP:TraceMelee(range)
    local owner = self:GetOwner()
    local shootPos = owner:GetShootPos()
    local aimDir = owner:GetAimVector()

    for i = 0, 8 do
        local ang = aimDir:Angle()
        ang:RotateAroundAxis(ang:Up(), math.Rand(-25, 25))
        ang:RotateAroundAxis(ang:Right(), math.Rand(-15, 15))
        local dir = ang:Forward()

        local tr = util.TraceLine({
            start = shootPos,
            endpos = shootPos + dir * range,
            filter = owner,
            mask = MASK_SHOT
        })

        if tr.Hit and IsValid(tr.Entity) then
            return tr
        end
    end

    -- Center trace as a fallback
    return util.TraceLine({
        start = shootPos,
        endpos = shootPos + aimDir * range,
        filter = owner,
        mask = MASK_SHOT
    })
end

function SWEP:DoImpactEffect(tr)
    local fx = EffectData()
    fx:SetOrigin(tr.HitPos)
    fx:SetStart(self:GetOwner():GetShootPos())
    fx:SetNormal(tr.HitNormal)
    fx:SetScale(1.5)
    util.Effect("cball_explode", fx, true, true)

    local fx2 = EffectData()
    fx2:SetOrigin(tr.HitPos)
    fx2:SetScale(1.5)
    util.Effect("StunstickImpact", fx2, true, true)
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self:EmitSound("weapons/stunstick/stunstick_swing1.wav", 100, 80)
    owner:ViewPunch(Angle(-self.Primary.Recoil, 0, 0))
    self:ShootEffects()

    if not SERVER then return end

    local tr = self:TraceMelee(self.Primary.Range)
    if not (tr.Hit and IsValid(tr.Entity)) then return end

    local ent = tr.Entity
    local dir = (tr.HitPos - owner:GetShootPos()):GetNormalized()

    local dmginfo = DamageInfo()
    dmginfo:SetDamage(self.Primary.Damage)
    dmginfo:SetAttacker(owner)
    dmginfo:SetInflictor(self)
    dmginfo:SetDamageType(DMG_CRUSH)
    dmginfo:SetDamageForce(dir * self.Primary.Force)
    ent:TakeDamageInfo(dmginfo)

    if ent:IsPlayer() or ent:IsNPC() then
        ent:SetVelocity(dir * self.Primary.Force)
    else
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:ApplyForceCenter(dir * self.Primary.Force * 12)
        end
    end

    self:DoImpactEffect(tr)
end

-- Gravity Slam: shockwave that launches everything around the player away.
function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self:EmitSound("ambient/explosions/explode_9.wav", 120, 60)
    self:ShootEffects()

    if owner:IsPlayer() then
        owner:ViewPunch(Angle(8, 0, math.Rand(-3, 3)))
    end

    if not SERVER then return end

    local center = owner:GetPos() + Vector(0, 0, 24)
    local radius = self.Secondary.Radius
    local force = self.Secondary.Force

    for _, ent in ipairs(ents.FindInSphere(center, radius)) do
        if ent ~= owner and (ent:IsPlayer() or ent:IsNPC()) then
            local toEnt = ent:GetPos() - center
            local dist = toEnt:Length()
            if dist >= 1 then
                local dir = toEnt:GetNormalized()
                local falloff = 1 - (dist / radius) -- stronger up close
                local push = force * falloff

                ent:SetVelocity(dir * push)

                local dmginfo = DamageInfo()
                dmginfo:SetDamage(40 * falloff)
                dmginfo:SetAttacker(owner)
                dmginfo:SetInflictor(self)
                dmginfo:SetDamageType(DMG_CRUSH)
                ent:TakeDamageInfo(dmginfo)
            end
        end
    end

    -- Visual shockwave ring
    local fx = EffectData()
    fx:SetOrigin(center)
    fx:SetScale(radius)
    fx:SetRadius(radius)
    util.Effect("ThumperDust", fx, true, true)
end
