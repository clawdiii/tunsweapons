-- Touhou Weapon: Admin-only weapon that shoots bullet spirals
-- Version 1.3 addition

SWEP.PrintName = "Touhou Weapon"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — стрелять спиралью пуль. ПКМ — усиленная вертикальная спираль."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 0.1
SWEP.Primary.Damage = 25
SWEP.Primary.Force = 8
SWEP.Primary.NumShots = 1

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Delay = 0.15

SWEP.Weight = 5
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.Slot = 2
SWEP.SlotPos = 5

SWEP.ViewModel = "models/weapons/cstrike/c_rif_sg552.mdl"
SWEP.WorldModel = "models/weapons/w_rif_sg552.mdl"
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("ar2")
end

function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsAdmin() then return end

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    if SERVER then
        self:ShootSpiral(owner, false)
    end

    self:EmitSound("weapons/physcannon/energy_singularity1.wav", 85, 120)
    self:ShootEffects()
end

function SWEP:SecondaryAttack()
    if not IsFirstTimePredicted() then return end
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsAdmin() then return end

    self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)

    if SERVER then
        self:ShootSpiral(owner, true)
    end

    self:EmitSound("weapons/physcannon/energy_singularity2.wav", 90, 140)
    self:ShootEffects()
end

function SWEP:ShootSpiral(owner, vertical)
    local shootPos = owner:GetShootPos()
    local aimVec = owner:GetAimVector()
    local spiralRings = vertical and 3 or 2
    local bulletsPerRing = vertical and 36 or 24
    local radiusStart = 5
    local radiusEnd = vertical and 120 or 80
    local spiralSpeed = vertical and -30 or -20

    for ring = 0, spiralRings do
        local ringRadius = radiusStart + (radiusEnd - radiusStart) * (ring / spiralRings)

        for i = 0, bulletsPerRing - 1 do
            local angle = (360 / bulletsPerRing) * i
            local timeOffset = ring * 0.08 + i * 0.005

            timer.Simple(timeOffset, function()
                if not IsValid(self) or not IsValid(owner) then return end

                local dir = aimVec
                if vertical then
                    local right = owner:GetRight()
                    local up = owner:GetUp()
                    dir = right * math.cos(math.rad(angle)) + up * math.sin(math.rad(angle) * spiralSpeed / 360) + aimVec
                    dir:Normalize()
                else
                    local right = aimVec:Angle():Right()
                    local up = aimVec:Angle():Up()
                    dir = right * math.cos(math.rad(angle)) * (ringRadius / radiusEnd) + up * math.sin(math.rad(angle)) * (ringRadius / radiusEnd) + aimVec
                    dir:Normalize()
                end

                local bullet = {
                    Num = 1,
                    Src = shootPos,
                    Dir = dir,
                    Spread = Vector(0, 0, 0),
                    Tracer = 1,
                    TracerName = "AirboatGunTracer",
                    Force = self.Primary.Force,
                    Damage = self.Primary.Damage,
                    AmmoType = "none"
                }

                owner:FireBullets(bullet)
            end)
        end
    end
end

function SWEP:Reload()
end

function SWEP:ShootBullet()
end