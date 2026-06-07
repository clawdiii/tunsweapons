-- Defuse Kit на базе модели SLAM
-- Совместим с твоим скриптом C4

SWEP.PrintName = "Defuse Kit"
SWEP.Author = "GPT"
SWEP.Instructions = "Зажмите ЛКМ на C4, чтобы разминировать."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

-- Использование моделей SLAM
SWEP.ViewModel = "models/weapons/v_slam.mdl"
SWEP.WorldModel = "models/weapons/w_slam.mdl"
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Slot = 5
SWEP.SlotPos = 1

-- Настройки
SWEP.DefuseTime = 5 -- Время разминирования
SWEP.DefuseDistance = 80 

function SWEP:SetupDataTables()
    self:NetworkVar("Float", 0, "DefuseProgress")
    self:NetworkVar("Bool", 1, "IsDefusing")
end

function SWEP:Initialize()
    self:SetHoldType("slam")
end

-- Убираем стандартную атаку (бросок)
function SWEP:PrimaryAttack()
    return false
end

function SWEP:SecondaryAttack()
    return false
end

function SWEP:Deploy()
    self:SendWeaponAnim(ACT_VM_DRAW)
    return true
end

function SWEP:Think()
    if CLIENT then return end

    local ply = self:GetOwner()
    if not IsValid(ply) then return end

    if ply:KeyDown(IN_ATTACK) then
        local tr = ply:GetEyeTrace()
        local ent = tr.Entity

        -- Проверка: смотрим на C4 (модель w_c4.mdl из твоего скрипта)
        if IsValid(ent) and ent:GetModel() == "models/weapons/w_c4.mdl" and tr.HitPos:Distance(ply:GetShootPos()) < self.DefuseDistance then
            
            if not self:GetIsDefusing() then
                -- Начало разминирования
                self:SetIsDefusing(true)
                self:SetDefuseProgress(CurTime() + self.DefuseTime)
                
                -- Проигрываем анимацию "нажатия кнопок" на SLAM
                self:SendWeaponAnim(ACT_SLAM_DETONATOR_DETONATE)
                
                ply:EmitSound("weapons/c4/c4_disarmstart.wav", 75, 100, 1, CHAN_ITEM)
                -- Если звука нет, запасной:
                -- ply:EmitSound("buttons/combine_button1.wav", 75, 100)
            end

            -- Завершение разминирования
            if CurTime() >= self:GetDefuseProgress() then
                self:DoDefuse(ent)
            end
        else
            self:ResetDefuse()
        end
    else
        if self:GetIsDefusing() then
            self:ResetDefuse()
        end
    end
end

function SWEP:ResetDefuse()
    if self:GetIsDefusing() then
        self:SetIsDefusing(false)
        self:SetDefuseProgress(0)
        self:SendWeaponAnim(ACT_VM_IDLE) -- Возвращаем в покой
    end
end

function SWEP:DoDefuse(ent)
    local ply = self:GetOwner()
    
    -- Звуки и эффекты успеха
    ply:EmitSound("weapons/c4/c4_disarm.wav", 75, 100)
    -- Запасной: ply:EmitSound("buttons/button9.wav", 75, 100)

    if IsValid(ent) then
        -- Создаем эффект искр на месте бомбы
        local effect = EffectData()
        effect:SetOrigin(ent:GetPos())
        util.Effect("ManhackSparks", effect)
        
        ent:Remove() -- Удаление бомбы останавливает таймер
    end

    PrintMessage(HUD_PRINTCENTER, "БОМБА ОБЕЗВРЕЖЕНА")
    self:ResetDefuse()
end

-- HUD
if CLIENT then
    function SWEP:DrawHUD()
        if not self:GetIsDefusing() then return end

        local endTime = self:GetDefuseProgress()
        local startTime = endTime - self.DefuseTime
        local fraction = math.Clamp((CurTime() - startTime) / self.DefuseTime, 0, 1)

        local w, h = 300, 25
        local x, y = (ScrW() - w) / 2, (ScrH() - h) / 2 + 150

        -- Рамка
        surface.SetDrawColor(0, 0, 0, 200)
        surface.DrawRect(x, y, w, h)

        -- Прогресс (Зеленый/Голубой)
        surface.SetDrawColor(50, 255, 50, 255)
        surface.DrawRect(x + 2, y + 2, (w - 4) * fraction, h - 4)

        -- Текст
        draw.SimpleText("РАЗМИНИРОВАНИЕ", "Trebuchet24", ScrW()/2, y - 25, color_white, TEXT_ALIGN_CENTER)
    end
    
    -- Скрываем стандартный прицел, так как это инструмент
    function SWEP:DoDrawCrosshair(x, y)
        return true 
    end
end