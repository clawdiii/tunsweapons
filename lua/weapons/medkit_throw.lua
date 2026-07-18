SWEP.PrintName = "MedKit Throw"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — бросить аптечку. Подходит к ней для подбора."
SWEP.Category = "TUNS Swep"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 4
SWEP.Primary.DefaultClip = 4
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""
SWEP.Primary.Delay = 0.5

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 1
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 3
SWEP.SlotPos = 3

SWEP.ViewModel = "models/weapons/c_medkit.mdl"
SWEP.WorldModel = "models/weapons/w_medkit.mdl"
SWEP.ViewModelFOV = 54
SWEP.UseHands = true

SWEP.HealAmount = 50

if SERVER then
    -- item_healthkit — C++ энтити движка, у него нет Lua-колбэка OnPickedUp.
    -- Подбор ловим через PlayerCanPickupItem: если это наша брошенная аптечка
    -- и у игрока есть medkit_throw — пополняем заряд вместо нативного хила.
    hook.Add("PlayerCanPickupItem", "medkit_throw_refill", function(ply, item)
        if not IsValid(item) or not item.IsThrownMedkit then return end
        if item.NoPickupUntil and CurTime() < item.NoPickupUntil then return end
        local w = ply:GetWeapon("medkit_throw")
        if IsValid(w) then
            -- Пополняем заряд ДО нативного хила (не блокируем — игрок ещё и лечится)
            w:SetClip1(math.min(w:GetMaxClip1(), w:Clip1() + 1))
        end
    end)
end

function SWEP:Initialize()
    self:SetHoldType("shotgun")
end

function SWEP:PrimaryAttack()
    if self:Clip1() <= 0 then
        self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
        return
    end
    if SERVER then
        local ply = self:GetOwner()
        local src = ply:GetShootPos()
        local dir = ply:GetAimVector()

        -- item_healthkit — встроенный HL2 энтити аптечки
        local ent = ents.Create("item_healthkit")
        if not IsValid(ent) then return end
        ent:SetPos(src + dir * 32)
        ent:Spawn()
        ent:SetOwner(ply)
        ent.IsThrownMedkit = true -- метка для PlayerCanPickupItem
        ent.NoPickupUntil = CurTime() + 0.6 -- иммунитет, пока летит мимо игрока

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetVelocity(dir * 300)
        end

        timer.Simple(20, function()
            if IsValid(ent) then ent:Remove() end
        end)
    end

    self:ShootEffects()
    self:SetClip1(math.max(0, self:Clip1() - 1))
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:SecondaryAttack() end
function SWEP:Reload() end
