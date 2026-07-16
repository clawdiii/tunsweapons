-- M4A1: Assault rifle based on CS:Source M4A1 model
-- Version 1.3 addition

SWEP.PrintName = "M4A1"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — автоматический огонь. Присядьте для высокой точности. ПКМ — прицел."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 120
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Delay = 0.09
SWEP.Primary.Damage = 21
SWEP.Primary.Recoil = 1.2
SWEP.Primary.NumShots = 1
SWEP.Primary.Spread = 0.018
SWEP.Primary.MaxSpread = 0.055
SWEP.Primary.SpreadIncrease = 0.004
SWEP.Primary.SpreadRecovery = 0.025
SWEP.Primary.Force = 5

SWEP.CrouchSpreadMul = 0.33

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 5
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 2
SWEP.SlotPos = 9

SWEP.ViewModel = "models/weapons/cstrike/c_rif_m4a1.mdl"
SWEP.WorldModel = "models/weapons/w_rif_m4a1.mdl"
SWEP.UseHands = true

SWEP.IronSightPos = Vector(-2, -4, 1)
SWEP.IronSightAng = Angle(0, -2, 0)
SWEP.IronZoom = 50

function SWEP:Initialize()
    self:SetHoldType("ar2")
    self.CurrentSpread = self.Primary.Spread
    self.LastFireTime = 0
    self.IronSighting = false
end

function SWEP:GetModifiedSpread()
    local owner = self:GetOwner()
    if self.IronSighting then
        return self.Primary.Spread * 0.1
    end
    if IsValid(owner) and owner:Crouching() then
        return (self.CurrentSpread or self.Primary.Spread) * self.CrouchSpreadMul
    end
    return self.CurrentSpread or self.Primary.Spread
end

function SWEP:GetModifiedBaseSpread()
    if self.IronSighting then
        return self.Primary.Spread * 0.1
    end
    return self.Primary.Spread
end

function SWEP:GetModifiedMaxSpread()
    if self.IronSighting then
        return self.Primary.MaxSpread * 0.1
    end
    return self.Primary.MaxSpread
end

function SWEP:PrimaryAttack()
    if (not self:CanPrimaryAttack()) then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local maxSpread = self:GetModifiedMaxSpread()
    self.CurrentSpread = math.min(
        (self.CurrentSpread or self.Primary.Spread) + self.Primary.SpreadIncrease,
        maxSpread
    )
    self.LastFireTime = CurTime()

    self:EmitSound("Weapon_M4A1.Single")
    self:ShootBullet(self.Primary.Damage, self.Primary.NumShots, self:GetModifiedSpread())
    self:TakePrimaryAmmo(1)

    if owner.ViewPunch then
        owner:ViewPunch(Angle(-self.Primary.Recoil, 0, 0))
    end

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:SecondaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self.IronSighting = not self.IronSighting
    if self.IronSighting then
        owner:SetFOV(self.IronZoom, 0.2)
        self:EmitSound("weapons/zoom.wav", 75, 100)
    else
        owner:SetFOV(0, 0.2)
    end

    self:SetNextSecondaryFire(CurTime() + 0.3)
end

function SWEP:Think()
    if not self.LastFireTime then return end
    local baseSpread = self:GetModifiedBaseSpread()
    if (self.CurrentSpread or self.Primary.Spread) > baseSpread then
        self.CurrentSpread = math.max(
            baseSpread,
            (self.CurrentSpread or self.Primary.Spread) - self.Primary.SpreadRecovery * FrameTime()
        )
        self.LastFireTime = CurTime()
    end
end

function SWEP:ShootBullet(damage, num_shots, aimcone)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local bullet = {}
    bullet.Num = num_shots
    bullet.Src = owner:GetShootPos()
    bullet.Dir = owner:GetAimVector()
    bullet.Spread = Vector(aimcone, aimcone, 0)
    bullet.Tracer = 1
    bullet.TracerName = "Tracer"
    bullet.Force = self.Primary.Force
    bullet.Damage = damage
    bullet.AmmoType = self.Primary.Ammo

    owner:FireBullets(bullet)
    self:ShootEffects()
end

function SWEP:Reload()
    self:DefaultReload(ACT_VM_RELOAD)
    self.IronSighting = false
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    local vm = owner:GetViewModel()
    if not IsValid(vm) then return end
    timer.Simple(vm:SequenceDuration(), function()
        if IsValid(self) then
            self.CurrentSpread = self.Primary.Spread
        end
    end)
end

function SWEP:Holster()
    self.IronSighting = false
    local owner = self:GetOwner()
    if IsValid(owner) then
        owner:SetFOV(0, 0.1)
    end
    return true
end