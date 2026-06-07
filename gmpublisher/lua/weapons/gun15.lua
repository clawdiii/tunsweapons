-- Мощный дробовик для Garry's Mod, основанный на gun1.lua

SWEP.PrintName = "Ba-12 Shotgun"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — выстрел. Присядьте для большей кучности."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 8
SWEP.Primary.DefaultClip = 32
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "Buckshot"
SWEP.Primary.Delay = 0.85
SWEP.Primary.Damage = 13
SWEP.Primary.Recoil = 2.3
SWEP.Primary.NumShots = 7
SWEP.Primary.Spread = 0.045 -- базовый минимальный разброс
SWEP.Primary.MaxSpread = 0.11
SWEP.Primary.SpreadIncrease = 0.014 -- насколько разброс увеличивается за выстрел
SWEP.Primary.SpreadRecovery = 0.035 -- скорость восстановления разброса в секунду
SWEP.Primary.Force = 8

SWEP.CrouchSpreadMul = 0.48 -- уменьшение разброса при приседании

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 7
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 2
SWEP.SlotPos = 5

SWEP.ViewModel = "models/weapons/cstrike/c_shot_xm1014.mdl"
SWEP.WorldModel = "models/weapons/w_shot_xm1014.mdl"
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("shotgun")
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

    -- Увеличиваем разброс при каждом выстреле (учитываем максимум с учетом приседания)
    local maxSpread = self:GetModifiedMaxSpread()
    self.CurrentSpread = math.min(
        (self.CurrentSpread or self.Primary.Spread) + self.Primary.SpreadIncrease, 
        maxSpread
    )
    self.LastFireTime = CurTime()

    self:EmitSound("Weapon_XM1014.Single")
    self:ShootBullet(self.Primary.Damage, self.Primary.NumShots, self:GetModifiedSpread())
    self:TakePrimaryAmmo(1)

    -- Сильнее трясём экран (отдача выше)
    -- self.Owner:ViewPunch(Angle(-self.Primary.Recoil, 0, 0))
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
    bullet.TracerName = "Tracer"
    bullet.Force = self.Primary.Force
    bullet.Damage = damage
    bullet.AmmoType = self.Primary.Ammo

    self.Owner:FireBullets(bullet)
    self:ShootEffects()
end

function SWEP:Reload()
    self:DefaultReload(ACT_SHOTGUN_RELOAD_FINISH)
    timer.Simple(self.Owner:GetViewModel():SequenceDuration(), function()
        if IsValid(self) then
            self.CurrentSpread = self.Primary.Spread -- сбросить разброс при перезарядке
        end
    end)
end

function SWEP:SecondaryAttack()
    -- Нет вторичной атаки
end
