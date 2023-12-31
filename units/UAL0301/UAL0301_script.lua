-----------------------------------------------------------------
-- File     :  /cdimage/units/UAL0301/UAL0301_script.lua
-- Author(s):  Jessica St. Croix
-- Summary  :  Aeon Sub Commander Script
-- Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
-----------------------------------------------------------------
---@alias AeonSCUEnhancementBuffType
---| "SCUBUILDRATE"
---| "SCUREGENRATE"

---@alias AeonSCUEnhancementBuffName          # BuffType
---| "AeonSCUBuildRate"                       # SCUBUILDRATE
---| "AeonSCURegenRate"                       # SCUREGENRATE

local CommandUnit = import("/lua/defaultunits.lua").CommandUnit
local AWeapons = import("/lua/aeonweapons.lua")
local ADFReactonCannon = AWeapons.ADFReactonCannon
local SCUDeathWeapon = import("/lua/sim/defaultweapons.lua").SCUDeathWeapon
local EffectUtil = import("/lua/effectutilities.lua")
local Buff = import("/lua/sim/buff.lua")

---@class UAL0301 : CommandUnit
UAL0301 = ClassUnit(CommandUnit) {
    Weapons = {
        RightReactonCannon = ClassWeapon(ADFReactonCannon) {},
        DeathWeapon = ClassWeapon(SCUDeathWeapon) {},
    },

    __init = function(self)
        CommandUnit.__init(self, 'RightReactonCannon')
    end,

    OnStopBuild = function(self, unitBeingBuilt)
        CommandUnit.OnStopBuild(self, unitBeingBuilt)
        self:BuildManipulatorSetEnabled(false)
        self.BuildArmManipulator:SetPrecedence(0)
        self:SetWeaponEnabledByLabel('RightReactonCannon', true)
        self:GetWeaponManipulatorByLabel('RightReactonCannon'):SetHeadingPitch(self.BuildArmManipulator:GetHeadingPitch())
        self.UnitBeingBuilt = nil
        self.UnitBuildOrder = nil
        self.BuildingUnit = false
    end,

    OnCreate = function(self)
        CommandUnit.OnCreate(self)
        self:SetCapturable(false)
        self:HideBone('Turbine', true)
        self:SetupBuildBones()
    end,

    CreateBuildEffects = function(self, unitBeingBuilt, order)
        EffectUtil.CreateAeonCommanderBuildingEffects(self, unitBeingBuilt, self.BuildEffectBones, self.BuildEffectsBag)
    end,

    CreateEnhancement = function(self, enh)
        CommandUnit.CreateEnhancement(self, enh)
        local bp = self.Blueprint.Enhancements[enh]
        if not bp then return end
        -- Teleporter
        if enh == 'Teleporter' then
            self:AddCommandCap('RULEUCC_Teleport')
        elseif enh == 'TeleporterRemove' then
            self:RemoveCommandCap('RULEUCC_Teleport')
        -- Shields
        elseif enh == 'Shield' then
            self:AddToggleCap('RULEUTC_ShieldToggle')
            self:SetEnergyMaintenanceConsumptionOverride(bp.MaintenanceConsumptionPerSecondEnergy or 0)
            self:SetMaintenanceConsumptionActive()
            self:CreateShield(bp)
        elseif enh == 'ShieldRemove' then
            self:DestroyShield()
            self:SetMaintenanceConsumptionInactive()
            self:RemoveToggleCap('RULEUTC_ShieldToggle')
        elseif enh == 'ShieldHeavy' then
            self:AddToggleCap('RULEUTC_ShieldToggle')
            self:CreateShield(bp)
            self:SetEnergyMaintenanceConsumptionOverride(bp.MaintenanceConsumptionPerSecondEnergy or 0)
            self:SetMaintenanceConsumptionActive()
        elseif enh == 'ShieldHeavyRemove' then
            self:DestroyShield()
            self:SetMaintenanceConsumptionInactive()
            self:RemoveToggleCap('RULEUTC_ShieldToggle')
            -- ResourceAllocation
        elseif enh == 'ResourceAllocation' then
            local bpEcon = self.Blueprint.Economy
            if not bp then return end
            self:SetProductionPerSecondEnergy((bp.ProductionPerSecondEnergy + bpEcon.ProductionPerSecondEnergy) or 0)
            self:SetProductionPerSecondMass((bp.ProductionPerSecondMass + bpEcon.ProductionPerSecondMass) or 0)
        elseif enh == 'ResourceAllocationRemove' then
            local bpEcon = self.Blueprint.Economy
            self:SetProductionPerSecondEnergy(bpEcon.ProductionPerSecondEnergy or 0)
            self:SetProductionPerSecondMass(bpEcon.ProductionPerSecondMass or 0)
            -- Engineering Focus Module
        elseif enh == 'EngineeringFocusingModule' then
            self:AddCommandCap('RULEUCC_Sacrifice')
            if not Buffs['AeonSCUBuildRate'] then
                BuffBlueprint {
                    Name = 'AeonSCUBuildRate',
                    DisplayName = 'AeonSCUBuildRate',
                    BuffType = 'SCUBUILDRATE',
                    Stacks = 'REPLACE',
                    Duration = -1,
                    Affects = {
                        BuildRate = {
                            Add = bp.NewBuildRate - self.Blueprint.Economy.BuildRate,
                            Mult = 1,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'AeonSCUBuildRate')
        elseif enh == 'EngineeringFocusingModuleRemove' then
            self:RemoveCommandCap('RULEUCC_Sacrifice')
            if Buff.HasBuff(self, 'AeonSCUBuildRate') then
                Buff.RemoveBuff(self, 'AeonSCUBuildRate')
            end
            -- SystemIntegrityCompensator
        elseif enh == 'SystemIntegrityCompensator' then
            local name = 'AeonSCURegenRate'
            if not Buffs[name] then
                BuffBlueprint {
                    Name = name,
                    DisplayName = name,
                    BuffType = 'SCUREGENRATE',
                    Stacks = 'REPLACE',
                    Duration = -1,
                    Affects = {
                        Regen = {
                            Add = bp.NewRegenRate - self.Blueprint.Defense.RegenRate,
                            Mult = 1,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, name)
        elseif enh == 'SystemIntegrityCompensatorRemove' then
            if Buff.HasBuff(self, 'AeonSCURegenRate') then
                Buff.RemoveBuff(self, 'AeonSCURegenRate')
            end
            -- StabilitySupressant
        elseif enh == 'StabilitySuppressant' then
            local wep = self:GetWeaponByLabel('RightReactonCannon')
            wep:AddDamageMod(bp.NewDamageMod or 0)
            wep:AddDamageRadiusMod(bp.NewDamageRadiusMod or 0)
            wep:ChangeMaxRadius(bp.NewMaxRadius or 44)
        elseif enh == 'StabilitySuppressantRemove' then
            local wep = self:GetWeaponByLabel('RightReactonCannon')
            wep:AddDamageMod(-self.Blueprint.Enhancements['RightReactonCannon'].NewDamageMod)
            wep:AddDamageRadiusMod(bp.NewDamageRadiusMod or 0)
            wep:ChangeMaxRadius(bp.NewMaxRadius or 25)
        end
    end,
}

TypeClass = UAL0301