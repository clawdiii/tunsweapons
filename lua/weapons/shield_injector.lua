SWEP.PrintName = "Shield Injector"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — вживить щит. Пассивная регенерация +5 брони и +3 здоровья в секунду."
SWEP.Category = "TUNS Swep"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "None"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.Slot = 3
SWEP.SlotPos = 1

SWEP.ViewModel = "models/weapons/c_superphyscannon.mdl"
SWEP.WorldModel = "models/weapons/w_physics.mdl"
SWEP.UseHands = true

-- Настройки
SWEP.ArmorPerTick = 5   -- +брони за тик
SWEP.HealthPerTick = 3  -- +здоровья за тик
SWEP.MaxArmor = 100     -- макс броня
SWEP.MaxHealth = 100    -- макс здоровье

if SERVER then
    -- Не даём взять Shield Injector, если щит уже активен
    hook.Add("PlayerCanPickupWeapon", "shield_injector_block", function(ply, wep)
        if IsValid(wep) and wep:GetClass() == "shield_injector" and ply.ShieldActive then
            return false
        end
    end)
end

function SWEP:Initialize()
    self:SetHoldType("shotgun")
end

function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end
    local ply = self:GetOwner()
    if not IsValid(ply) then return end

    if ply.ShieldActive then return end

    if SERVER then
        local class = self:GetClass()
        ply.ShieldActive = true
        local timerName = "shield_regen_" .. ply:EntIndex()

        ply:ChatPrint("[Shield Injector] Щит активирован. +" .. self.ArmorPerTick .. " брони / +" .. self.HealthPerTick .. " здоровья в секунду.")

        local aPerTick = self.ArmorPerTick
        local hPerTick = self.HealthPerTick
        local maxArmor = self.MaxArmor
        local maxHealth = self.MaxHealth
        local interval = self.TickInterval or 1

        timer.Create(timerName, interval, 0, function()
            if not IsValid(ply) or not ply.ShieldActive then
                timer.Remove(timerName)
                return
            end

            local armorGain = math.min(aPerTick, math.max(0, maxArmor - ply:Armor()))
            local healthGain = math.min(hPerTick, math.max(0, maxHealth - ply:Health()))

            if armorGain > 0 then
                ply:SetArmor(ply:Armor() + armorGain)
            end
            if healthGain > 0 then
                ply:SetHealth(ply:Health() + healthGain)
            end
        end)

        local deathHook = "shield_death_" .. ply:EntIndex()
        hook.Add("DoPlayerDeath", deathHook, function(victim)
            if victim == ply then
                ply.ShieldActive = false
                timer.Remove(timerName)
                hook.Remove("DoPlayerDeath", deathHook)
            end
        end)

        -- Убираем инжектор из инвентаря после активации
        ply:StripWeapon(class)
    end
end

function SWEP:SecondaryAttack() end
function SWEP:Reload() end
function SWEP:Think() end

function SWEP:OnRemove()
    if not SERVER then return end
    local ply = self:GetOwner()
    if IsValid(ply) then
        ply.ShieldActive = false
        timer.Remove("shield_regen_" .. ply:EntIndex())
        hook.Remove("DoPlayerDeath", "shield_death_" .. ply:EntIndex())
    end
end

function SWEP:Holster()
    return true
end

function SWEP:OwnerChanged()
    local ply = self:GetOwner()
    if IsValid(ply) then
        ply.ShieldActive = false
        timer.Remove("shield_regen_" .. ply:EntIndex())
        hook.Remove("DoPlayerDeath", "shield_death_" .. ply:EntIndex())
    end
end

function SWEP:ShouldDropOnDie()
    return false
end
