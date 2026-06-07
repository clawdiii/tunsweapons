SWEP.PrintName = "Killer"
SWEP.Author = "GPT"
SWEP.Instructions = "Наведите прицел на NPC и нажмите на него, чтобы мгновенно его убить."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 90
SWEP.Primary.DefaultClip = 360
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Delay = 0.2

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 5
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 2
SWEP.SlotPos = 1

SWEP.ViewModel = ""
SWEP.WorldModel = ""
SWEP.UseHands = true

function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end
    if not IsValid(self.Owner) then return end

    local tr = self.Owner:GetEyeTrace()
    local ent = tr.Entity

    if IsValid(ent) and ent:IsNPC() and tr.HitPos:DistToSqr(self.Owner:GetShootPos()) < 1000000 then
        ent:TakeDamage(ent:Health() + 100, self.Owner, self)
    end

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:SecondaryAttack()
    -- Нет вторичной атаки
end
