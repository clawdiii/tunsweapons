-- Бластер-автомат на базе gun1.lua

SWEP.PrintName = "BL-900 Blaster"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — скорострельный плазменный выстрел. Присядьте для высокой точности."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 60
SWEP.Primary.DefaultClip = 240
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Delay = 0.06
SWEP.Primary.Damage = 21
SWEP.Primary.Recoil = 0.27 -- гипер мелкая отдача
SWEP.Primary.NumShots = 1
SWEP.Primary.Spread = 0.015 -- минимальный разброс (точнее чем АК)
SWEP.Primary.MaxSpread = 0.06
SWEP.Primary.SpreadIncrease = 0.004
SWEP.Primary.SpreadRecovery = 0.021
SWEP.Primary.Force = 40

SWEP.CrouchSpreadMul = 0.25 -- Очень точен при приседании

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 4
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 3
SWEP.SlotPos = 1

SWEP.ViewModel = "models/weapons/cstrike/c_rif_galil.mdl"
SWEP.WorldModel = "models/weapons/w_rif_galil.mdl"
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("ar2")
    self.CurrentSpread = self.Primary.Spread
    self.LastFireTime = 0
end

function SWEP:GetModifiedSpread()
    if IsValid(self.Owner) and self.Owner:Crouching() then
        return (self.CurrentSpread or self.Primary.Spread) * self.CrouchSpreadMul
    end
    return self.CurrentSpread or self.Primary.Spread
end

function SWEP:GetModifiedBaseSpread()
    if IsValid(self.Owner) and self.Owner:Crouching() then
        return self.Primary.Spread * self.CrouchSpreadMul
    end
    return self.Primary.Spread
end

function SWEP:GetModifiedMaxSpread()
    if IsValid(self.Owner) and self.Owner:Crouching() then
        return self.Primary.MaxSpread * self.CrouchSpreadMul
    end
    return self.Primary.MaxSpread
end

function SWEP:PrimaryAttack()
    if (not self:CanPrimaryAttack()) then return end

    local maxSpread = self:GetModifiedMaxSpread()
    self.CurrentSpread = math.min(
        (self.CurrentSpread or self.Primary.Spread) + self.Primary.SpreadIncrease, 
        maxSpread
    )
    self.LastFireTime = CurTime()

    -- Плазменный звук
    self:EmitSound("weapons/physcannon/superphys_launch1.wav", 85, math.random(147,155), 0.8)
    self:ShootBullet(self.Primary.Damage, self.Primary.NumShots, self:GetModifiedSpread())
    self:TakePrimaryAmmo(1)

    -- Гипер мелкая отдача есть!
    if IsValid(self.Owner) and self.Owner.ViewPunch then
        self.Owner:ViewPunch(Angle(-self.Primary.Recoil, 0, 0))
    end

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:Think()
    -- Постепенно восстанавливаем разброс, если не стреляем
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

function SWEP:ShootBullet(damage, num_bullets, aimcone)
    local bullet = {}
    bullet.Num = num_bullets
    bullet.Src = self.Owner:GetShootPos()
    bullet.Dir = self.Owner:GetAimVector()
    bullet.Spread = Vector(aimcone, aimcone, 0)
    bullet.Tracer = 1
    bullet.TracerName = "AirboatGunTracer" -- синий sci-fi трассер
    bullet.Force = self.Primary.Force
    bullet.Damage = damage
    bullet.AmmoType = self.Primary.Ammo

    self.Owner:FireBullets(bullet)
    self:ShootEffects()
end

function SWEP:Reload()
    self:DefaultReload(ACT_VM_RELOAD)
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

function SWEP:SecondaryAttack()
    -- Нет вторичной атаки
end

