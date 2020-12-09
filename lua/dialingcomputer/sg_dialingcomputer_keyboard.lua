//Dialing Computer Keyboard

local ENT = {}

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Dialing Computer Keyboard"
ENT.Spawnable = false
ENT.Category = "Win7yes"

function ENT:SetupDataTables()
	self:NetworkVar("Entity",0,"DPC")
end

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/props_c17/computer01_keyboard.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		local phys = self:GetPhysicsObject()
		if (phys:IsValid()) then
			phys:Wake()
		end
	end

	function ENT:Use(ply)
		if IsValid(self:GetDPC()) then
			if not IsValid(self:GetDPC():GetStargate()) then
				self.dpc:FindNewGate()
			else

			end
		end
	end
end

scripted_ents.Register(ENT,"win7_dialingcomp_keyboard")