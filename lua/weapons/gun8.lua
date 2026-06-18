-- Оружие: "Два в одном" — мощный отпрыжок с убийством

SWEP.PrintName = "Truncher"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ выбрасывает вас назад и убивает"
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "None"
SWEP.Primary.Delay = 2

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

SWEP.Slot = 2
SWEP.SlotPos = 4

SWEP.ViewModel = "models/weapons/c_arms_citizen.mdl"
SWEP.WorldModel = "models/weapons/w_irifle.mdl"
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("pistol")
end

function SWEP:PrimaryAttack()
    if (not IsValid(self.Owner)) or (not self.Owner:IsPlayer()) then return end
    if self:GetNextPrimaryFire() > CurTime() then return end

    -- При выстреле: мощно отбрасываем игрока назад
    local ply = self.Owner
    local backVel = -ply:GetAimVector() * 9000
    backVel.z = 1700 -- чуть выше чтобы эффектнее

    -- Отбрасываем игрока
    ply:SetVelocity(backVel)

    -- Спавним звуки (можно поменять)
    ply:EmitSound("physics/body/body_medium_impact_hard"..math.random(1,6)..".wav", 80, 100)
    self:EmitSound("weapons/physcannon/energy_bounce"..math.random(1,2)..".wav", 70, 110)

    -- Убиваем игрока через небольшую задержку, чтобы был эффект полета
    timer.Simple(0.70, function()
        if IsValid(ply) and ply:Alive() then
            local dmginfo = DamageInfo()
            dmginfo:SetAttacker(ply)
            dmginfo:SetInflictor(self)
            dmginfo:SetDamage(9999)
            dmginfo:SetDamageType(DMG_GENERIC)
            ply:TakeDamageInfo(dmginfo)
        end
    end)

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:SecondaryAttack()
    -- Нет вторичной атаки
end
