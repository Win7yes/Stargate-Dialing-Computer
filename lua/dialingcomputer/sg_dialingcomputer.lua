//Lua Dialing Computer

AddCSLuaFile("dialingcomputer/sg_dialingcomputer.lua")

local ENT = {}

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Dialing Computer"
ENT.Spawnable = true
ENT.Category = "Win7yes"

function ENT:SetupDataTables()
	self:NetworkVar("Entity",0,"Stargate")
	self:NetworkVar("String",0,"DialingSymbol")
	self:NetworkVar("String",1,"RingSymbol")
	self:NetworkVar("String",2,"DialingAddress")
	self:NetworkVar("Bool",0,"GateOpen")
	self:NetworkVar("Bool",1,"Dialing")
	self:NetworkVar("Bool",2,"Inbound")
	self:NetworkVar("Bool",3,"Fast")
	self:NetworkVar("Bool",4,"Active")
	self:NetworkVar("Bool",5,"KeyboardActive")
	self:NetworkVar("Bool",6,"IrisClosed")
end

if SERVER then

	function ENT:ClosestGate(tbl,pos,filter)
		if isentity(pos) then pos=pos:LocalToWorld(pos:OBBCenter()) end
		local dist,near=999999
		for k,v in next,tbl do
			local d = v:GetPos():DistToSqr(pos)
			if d<dist then
				dist=d
				near=v
			end
		end
		return near,math.sqrt(dist)
	end

	function ENT:SpawnFunction( ply, tr, ClassName )

		if ( !tr.Hit ) then return end

		local SpawnPos = tr.HitPos + tr.HitNormal - Vector(0,0,0.5)
		local SpawnAng = ply:EyeAngles()
		SpawnAng.p = 0
		SpawnAng.y = SpawnAng.y + 180

		local ent = ents.Create( ClassName )
		ent:SetCreator( ply )
		ent:SetPos( SpawnPos )
		ent:SetAngles( SpawnAng )
		ent:Spawn()
		ent:Activate()

		ent:DropToFloor()

		return ent

	end

	function ENT:Initialize()
		if self.keyboard then
			self.keyboard:Remove()
			self.keyboard = nil
		end
		self:SetModel("models/props/cs_office/computer_monitor.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		local phys = self:GetPhysicsObject()
		if (phys:IsValid()) then
			phys:Wake()
		end
		phys:EnableMotion(false)
		util.AddNetworkString("dc_AddressRequest"..self:EntIndex())
		util.AddNetworkString("dc_ComenceDial"..self:EntIndex())
		util.AddNetworkString("dc_ChangeAddress"..self:EntIndex())
		util.AddNetworkString("dc_ClearAddress"..self:EntIndex())
		util.AddNetworkString("dc_NewGate"..self:EntIndex())
		util.AddNetworkString("dc_DisconnectGate"..self:EntIndex())
		util.AddNetworkString("dc_ToggleIris"..self:EntIndex())
		util.AddNetworkString("dc_AddHistory"..self:EntIndex())
		self.locking = false
		self.lastsymbol = ""
		self:FindNewGate()

		self.keyboard = ents.Create("win7_dialingcomp_keyboard")
		self.keyboard:SetPos(self:LocalToWorld(Vector(13,0,0)))
		self.keyboard:SetAngles(self:GetAngles())
		self.keyboard:Spawn()
		self.keyboard:SetDPC(self)
		self.keyboard.dpc = self
		self.keyboard:SetCreator(self:GetCreator())
		self.keyboard:GetPhysicsObject():EnableMotion(false)
		self.GateTries = 0
	end

	function ENT:FindNewGate()
		local candidates = {}
		for k,v in pairs(ents.FindByClass("stargate_*")) do
			if v.IsStargate then
				if v:GetClass() == "stargate_orlin" or v:GetClass() == "stargate_tollan" or v:GetClass() == "stargate_iris" or v:GetClass() == "stargate_supergate" then
					continue
				else
					table.insert(candidates,v)
				end
			end
		end
		local chosen = self:ClosestGate(candidates,self)
		if chosen == nil then
			self:SetStargate(chosen)
		else
			self.stargate = chosen
			self:SetStargate(self.stargate)
		end
	end

	function ENT:Use(ply)
		if not IsValid(self.stargate) then return end
		local addrtable = {}
		for k,v in pairs(self.stargate:GetAllGates()) do
			local data = {
				{
				["Address"] = v:GetGateAddress(),
				["Group"] = v:GetGateGroup(),
				["Private"] = v:GetPrivate(),
				["Local"] = v:GetLocale(),
				["Class"] = v:GetClass(),
				["Name"] = v:GetGateName(),
				}
			}
			table.Add(addrtable,data)
		end
		net.Start("dc_AddressRequest"..self:EntIndex())
			net.WriteTable(addrtable)
		net.Send(ply)
	end
	function ENT:Think()
		if not self.GetStargate then return end
		if not IsValid(self.stargate) or self.stargate.IsStargate ~= true then return end
		if self:GetGateOpen() ~= self.stargate.IsOpen then
			self:SetGateOpen(self.stargate.IsOpen)
		end
		net.Receive("dc_ComenceDial"..self:EntIndex(),function()
			self.stargate:DialGate(net.ReadString(),net.ReadBool())
		end)
		net.Receive("dc_ChangeAddress"..self:EntIndex(),function()
			if not self.SetDialingAddress then return end
			self:SetDialingAddress(net.ReadString())
		end)
		net.Receive("dc_NewGate"..self:EntIndex(),function()
			self:FindNewGate()
		end)
		net.Receive("dc_DisconnectGate"..self:EntIndex(),function()
			if self:GetDialing() then
				self.stargate:AbortDialling()
			elseif self:GetGateOpen() then
				self.stargate:Disconnect()
			end
		end)
		net.Receive("dc_ToggleIris"..self:EntIndex(),function()
			if not IsValid(self.stargate:GetIris()) then return end
			self.stargate:GetIris():Toggle(true)
		end)

		if IsValid(self.stargate:GetIris()) and self:GetIrisClosed() ~= self.stargate:GetIris().IsActivated then
			self:SetIrisClosed(self.stargate:GetIris().IsActivated)
		end
		if self:GetDialingSymbol() ~= self:GetStargate().DiallingSymbol then
			if not self:GetStargate():GetClass() == "stargate_atlantis" then
				self:SetDialingSymbol(self:GetStargate().DiallingSymbol)
			end
		end
		if self:GetRingSymbol() ~= self:GetStargate().RingSymbol then
			if not self:GetStargate():GetClass() == "stargate_atlantis" then
				self:SetRingSymbol(self:GetStargate().RingSymbol)
			end
		end
		if self:GetActive() ~= self.stargate.Active then
			self:SetActive(self.stargate.Active)
			if self:GetActive() == false then
				if self:GetIrisClosed() then
					self.stargate:GetIris():Toggle(true)
				end
				net.Start("dc_ClearAddress"..self:EntIndex())
				net.Broadcast()
			end
		end
		if self.stargate.Active and self:GetDialingSymbol() == self:GetRingSymbol() and not self.locking then
			if not string.find(self:GetDialingAddress(),self:GetDialingSymbol()) then
				//print("penis")
				if not tobool(self.stargate.Dialling) then return end
				self.locking = true
				self.lastsymbol = self:GetDialingSymbol()
				//print(self.lastsymbol)
				self:EmitSound("alexalx/glebqip/dp_locking.wav")
			end
		end
		if string.find(self:GetDialingAddress(),self.lastsymbol) and self.locking then
			//if not self.stargate.IsOpen then
				self.locking = false
				self:EmitSound("alexalx/glebqip/dp_locked.wav")
				timer.Simple(0.6,function()
					self:EmitSound("alexalx/glebqip/dp_encoded.wav")
				end)
				if self.lastsymbol == "#" then
					//self:EmitSound("alexalx/glebqip/dp_locked.wav")
					timer.Simple(0.6,function()
						self:EmitSound("alexalx/glebqip/lock1.wav")
					end)
					//self.locking = false
				end
			//end
		end

		if self:GetDialing() ~= tobool(self.stargate.Dialling) then
			self:SetDialing(tobool(self.stargate.Dialling))
			if self:GetDialing() == true and not self:GetGateOpen() then
				local address = table.concat(self.stargate.DialledAddress,"",1,#self.stargate.DialledAddress-1)
				if address == "" then return end
				net.Start("dc_AddHistory"..self:EntIndex())
				net.WriteString(address)
				net.Broadcast()
			end
		end
		if not self:GetStargate().Dialling and self.locking then
			self.locking = false
			//self:SetDialingAddress("")
		end
		if self:GetInbound() ~= tobool(self.stargate:GetWire("Inbound",nil,true)) then
			self:SetInbound(tobool(self.stargate:GetWire("Inbound",nil,true)))
			if self:GetInbound() and not self:GetIrisClosed() then
				if not IsValid(self.stargate:GetIris()) then return end
				self.stargate:GetIris():Toggle(true)
			end
		end
	end

	function ENT:OnRemove()
		self.keyboard:Remove()
		self.keyboard = nil
	end

end

if CLIENT then
	local detailcolor = Color(0,153,184)
	local white = Color(255,255,255)
	function ENT:GetRingAng()
		return self:GetStargate():GetRingAng() or 0
	end

	function ENT:DetermineFont()
		if self:GetStargate():GetClass() == "stargate_sg1" or self:GetStargate():GetClass() == "stargate_movie" then
			self.font = "dc_glyphs_sg1"
			self.font2 = "dc_encodedglyph_sg1"
		elseif self:GetStargate():GetClass() == "stargate_atlantis" then
			self.font = "dc_glyphs_atl"
			self.font2 = "dc_encodedglyph_atl"
			self:GetStargate().GetRingAng = function(self) return 0 end
		elseif self:GetStargate():GetClass() == "stargate_universe" then
			self.font = "stargate_address_glyphs_u"
			self.font2 = "stargate_address_glyphs_u"
		end
	end

	function ENT:Initialize()
		if self.GetStargate then
			self.stargate = self:GetStargate()
		end
		if IsValid(self:GetStargate()) or self:GetStargate().IsStargate then
			self:DetermineFont()
		end
		function draw.OutlinedBox(x,y,w,h,thick,col)
			surface.SetDrawColor(col)
			for i=0, thick - 1 do
				surface.DrawOutlinedRect( x + i, y + i, w - i * 2, h - i * 2 )
			end
		end

		function draw.OutlinedBoxFilled( x, y, w, h, thickness, clr, fillclr )
			surface.SetDrawColor( fillclr )
			surface.DrawRect(x,y,w,h)
			surface.SetDrawColor( clr )
			for i=0, thickness - 1 do
				surface.DrawOutlinedRect( x + i, y + i, w - i * 2, h - i * 2 )
			end
		end
		function surface.DrawTexturedRectRotatedPoint( x, y, w, h, rot, x0, y0 )

			local c = math.cos( math.rad( rot ) )
			local s = math.sin( math.rad( rot ) )

			local newx = y0 * s - x0 * c
			local newy = y0 * c + x0 * s

			surface.DrawTexturedRectRotated( x + newx, y + newy, w, h, rot )

		end
		self.gatering = Material("sgdialingcomp/gatering.png")
		self.gateouter = Material("sgdialingcomp/gateouter.png")
		self.chevronoff = Material("sgdialingcomp/gatechevronoff.png")
		self.chevronon = Material("sgdialingcomp/gatechevronon.png")
		self.eventhorizon = Material("sgdialingcomp/eventhorizon.png")
		self.iristex = Material("sgdialingcomp/iris_alt.png")
		self.csize = 0
		self.lock = false
		self.locking = false
		self.lastsymbol = ""
		self.w = 21*10
		self.h = 15.6*10
		self.lockchevow = self.w/5
		self.lockchevoh = self.h/3.7
		self.lcw = self.w/5
		self.lch = self.h/3.7
		self.addrtable = {}
		self.dialhist = {}
	end

	function ENT:EncodeChevron()
		self.locking = true
		local endbig = CurTime()+1.5
		local thinkfunc = function()
			if CurTime() < endbig then
				self.csize = self.csize + 0.005
				self.lcw = self.lcw + 1
				self.lch = self.lch + 1

				if self.csize > 0.1 then
					self.csize = 0.1
				end
				if self.lch > self.lockchevoh then
					self.lch = self.lockchevoh
				end
				if self.lcw > self.lockchevow then
					self.lcw = self.lockchevow
				end
			else
				hook.Remove("Think","ChevronEncode"..self:EntIndex())
			end
		end
		hook.Add("Think","ChevronEncode"..self:EntIndex(),thinkfunc)
	end

	function ENT:LockChevron()
		self.locking = false
		local chevronpos = {
			{w = self.w/1.18,h = 0}
		}
		local endsmall = CurTime()+1.5
		local thinkfunc = function()
			if CurTime() < endsmall then
				self.csize = self.csize - 0.009
				if self.csize < 0.025 then
					self.csize = 0.025
					self.locking = false
				end
			else
				hook.Remove("Think","ChevronLock"..self:EntIndex())
			end
		end
		hook.Add("Think","ChevronLock"..self:EntIndex(),thinkfunc)
	end

	function ENT:Draw()
		self:DrawModel()
		local w = 21*10
		local h = 15.6*10
		if not scripted_ents.Get("stargate_sg1") then
			cam.Start3D2D( self:LocalToWorld(Vector(3.3,-10.5,24.5)), self:LocalToWorldAngles(Angle(0,90,90)), 0.1 )
				draw.OutlinedBoxFilled(0,0,w,h,2,Color(0, 84, 255),Color(0, 84, 255))
				draw.DrawText("CAP NOT INSTALLED","Trebuchet24",w/2,h/2.5,Color(255,255,255),TEXT_ALIGN_CENTER)
				draw.DrawText("THIS ADDON REQUIRES CARTERS ADDON PACK","HudHintTextSmall",w/2,h/1.8,Color(255,255,255),TEXT_ALIGN_CENTER)
			cam.End3D2D()
			return
		end
		if not IsValid(self:GetStargate()) or self:GetStargate().IsStargate ~= true or not self.GetStargate then
			cam.Start3D2D( self:LocalToWorld(Vector(3.3,-10.5,24.5)), self:LocalToWorldAngles(Angle(0,90,90)), 0.1 )
				draw.OutlinedBoxFilled(0,0,w,h,2,detailcolor,Color(20,20,20))
				draw.DrawText("NO GATE FOUND","Trebuchet24",w/2,h/2.5,Color(255,50,50),TEXT_ALIGN_CENTER)
				draw.DrawText("PRESS ["..input.LookupBinding("+use"):upper().."] ON THE KEYBOARD TO FIND A GATE","HudHintTextSmall",w/2,h/1.8,Color(255,50,50),TEXT_ALIGN_CENTER)
			cam.End3D2D()
			return
		end
		local lockchevow = w/5
		local lockchevoh = h/3.7
		local daddress = self:GetDialingAddress()
		if not IsValid(self:GetStargate()) then return end
		cam.Start3D2D( self:LocalToWorld(Vector(3.3,-10.5,24.5)), self:LocalToWorldAngles(Angle(0,90,90)), 0.1 )
			surface.SetDrawColor( Color( 0, 0, 0, 255 ) )
			draw.OutlinedBoxFilled(0,0,w,h,2,detailcolor,Color(20,20,20))
			//draw.DrawText(daddress,"stargate_address_glyphs_concept",w/2,h/2,Color(255,255,255),TEXT_ALIGN_CENTER)
			if self:GetInbound() then
				draw.RoundedBox(0,w/1.18,0,32,21*7,Color(200,50,50))
				if daddress[8] ~= "" then
					draw.RoundedBox(0,w/1.43,0,32,22,Color(200,50,50))
				end
				if daddress[9] ~= "" then
					draw.RoundedBox(0,w/1.43,21,32,22,Color(200,50,50))
				end
			end
			draw.OutlinedBox(w/1.18,0,32,22,1,detailcolor)
			draw.OutlinedBox(w/1.18,21,32,22,1,detailcolor)
			draw.OutlinedBox(w/1.18,21*2,32,22,1,detailcolor)
			draw.OutlinedBox(w/1.18,21*3,32,22,1,detailcolor)
			draw.OutlinedBox(w/1.18,21*4,32,22,1,detailcolor)
			draw.OutlinedBox(w/1.18,21*5,32,22,1,detailcolor)
			draw.OutlinedBox(w/1.18,21*6,32,22,1,detailcolor)
			if daddress[7] ~= "#" and daddress[7] ~= "" then
				draw.OutlinedBox(w/1.43,0,32,22,1,detailcolor)
			end
			if daddress[8] ~= "#" and daddress[8] ~= "" then
				draw.OutlinedBox(w/1.43,21,32,22,1,detailcolor)
			end
			if not self:GetInbound() then
				draw.DrawText(daddress[1],self.font,w/1.15,2.5,white,TEXT_ALIGN_LEFT)
				draw.DrawText(daddress[2],self.font,w/1.15,22.5,white,TEXT_ALIGN_LEFT)
				draw.DrawText(daddress[3],self.font,w/1.15,22.5*2,white,TEXT_ALIGN_LEFT)
				draw.DrawText(daddress[4],self.font,w/1.15,21.5*3,white,TEXT_ALIGN_LEFT)
				draw.DrawText(daddress[5],self.font,w/1.15,21.5*4,white,TEXT_ALIGN_LEFT)
				draw.DrawText(daddress[6],self.font,w/1.15,21.5*5,white,TEXT_ALIGN_LEFT)
				draw.DrawText(daddress[7],self.font,w/1.15,21.2*6,white,TEXT_ALIGN_LEFT)
				draw.DrawText(daddress[8],self.font,w/1.38,4,white,TEXT_ALIGN_LEFT)
				draw.DrawText(daddress[9],self.font,w/1.38,25,white,TEXT_ALIGN_LEFT)
			end

			draw.OutlinedBox(w/7,h/80,115,25,1,detailcolor)
			draw.DrawText("Stargate Dialing Computer","HudHintTextSmall",w/6.5,h/40,white,TEXT_ALIGN_LEFT)
			draw.DrawText(self:GetStargate():GetGateName(),"HudHintTextSmall",w/6.5,h/12,white,TEXT_ALIGN_LEFT)

			if self:GetGateOpen() then
				draw.DrawText("WORMHOLE OPEN","Trebuchet16",w/5,h/1.3,white,TEXT_ALIGN_LEFT)
				surface.SetMaterial(self.eventhorizon)
				surface.DrawTexturedRect(w/3.8,h/3.8,80,80)
			end

			if self:GetIrisClosed() then
				surface.SetDrawColor(Color(255,255,255,self:GetGateOpen() and 70 or 255))
				surface.SetMaterial(self.iristex)
				surface.DrawTexturedRect(w/3.8,h/3.8,80,80)
			end

			if self:GetDialing() then
				draw.DrawText("DIALING...","Trebuchet16",w/5,h/1.3,white,TEXT_ALIGN_LEFT)
			end
			if self:GetInbound() then
				draw.DrawText("OFFWORLD ACTIVATION","Default",w/5,h/1.15,Color(255,50,50),TEXT_ALIGN_LEFT)
			end
			if not self:GetGateOpen() and not self:GetDialing() then
				draw.DrawText("IDLE","Trebuchet16",w/5,h/1.3,white,TEXT_ALIGN_LEFT)
			end
			draw.OutlinedBox(w/5,h/3.7,w/2,h/2,1,detailcolor)
			draw.RoundedBox(0,w/5,h/3.7,5,5,detailcolor)
			draw.RoundedBox(0,w/1.48,h/3.7,5,5,detailcolor)
			draw.RoundedBox(0,w/1.48,h/1.36,5,5,detailcolor)
			draw.RoundedBox(0,w/5,h/1.36,5,5,detailcolor)
			surface.SetMaterial(self.gateouter)
			surface.DrawTexturedRect(w/3.8,h/3.8,80,80)
			local ang = self:GetRingAng()
			surface.SetDrawColor(white)
			surface.SetMaterial(self.gatering)
			surface.DrawTexturedRectRotatedPoint(w/2.2,h/1.92,80,80,ang+5,0,0)
			if string.find(daddress,"#") or daddress[9] ~= "" then surface.SetMaterial(self.chevronon) else surface.SetMaterial(self.chevronoff) end
			surface.DrawTexturedRect(w/3.8,h/3.8,80,80)
			if daddress[6] ~= "" then surface.SetMaterial(self.chevronon) else surface.SetMaterial(self.chevronoff) end
			surface.DrawTexturedRectRotated(w/2.2,h/1.92,80,80,40)
			if daddress[5] ~= "" then surface.SetMaterial(self.chevronon) else surface.SetMaterial(self.chevronoff) end
			surface.DrawTexturedRectRotated(w/2.2,h/1.92,80,80,40*2)
			if daddress[4] ~= "" then surface.SetMaterial(self.chevronon) else surface.SetMaterial(self.chevronoff) end
			surface.DrawTexturedRectRotated(w/2.2,h/1.92,80,80,40*3)
			if daddress[8] ~= "#" and daddress[8] ~= "" then surface.SetMaterial(self.chevronon) else surface.SetMaterial(self.chevronoff) end
			surface.DrawTexturedRectRotated(w/2.2,h/1.92,80,80,40*4)
			if daddress[1] ~= "" then surface.SetMaterial(self.chevronon) else surface.SetMaterial(self.chevronoff) end
			surface.DrawTexturedRectRotated(w/2.2,h/1.92,80,80,-40)
			if daddress[2] ~= "" then surface.SetMaterial(self.chevronon) else surface.SetMaterial(self.chevronoff) end
			surface.DrawTexturedRectRotated(w/2.2,h/1.92,80,80,-40*2)
			if daddress[3] ~= "" then surface.SetMaterial(self.chevronon) else surface.SetMaterial(self.chevronoff) end
			surface.DrawTexturedRectRotated(w/2.2,h/1.92,80,80,-40*3)
			if daddress[7] ~= "#" and daddress[7] ~= "" then surface.SetMaterial(self.chevronon) else surface.SetMaterial(self.chevronoff) end
			surface.DrawTexturedRectRotated(w/2.2,h/1.92,80,80,-40*4)

		cam.End3D2D()

		//Locked Symbol
		if self:GetDialingSymbol() == self:GetRingSymbol() and self:GetDialing() and self:GetDialingSymbol() ~= "" then
			cam.Start3D2D(self:LocalToWorld(Vector(3.3,-10.5,24.5)), self:LocalToWorldAngles(Angle(0,90,90)), self.csize)
				draw.OutlinedBox(w/5,h/3.7,w/2,h/2,1,detailcolor)
				draw.DrawText(self:GetDialingSymbol(),self.font2,w/2.2,h/2.5,white,TEXT_ALIGN_CENTER)
			cam.End3D2D()
		end
	end

	function ENT:OpenHistory()
		local frame = vgui.Create("DFrame")
		frame:SetSize(750,500)
		frame:Center()
		frame:MakePopup()
		frame:SetTitle("")
		frame.Paint = function(frame,w,h)
			draw.OutlinedBoxFilled(0,0,w,h,3,detailcolor,Color(0,0,0))
			draw.DrawText("Stargate Dialing Computer","Trebuchet24",150,20,white,TEXT_ALIGN_CENTER)
			draw.DrawText(self:GetStargate():GetGateName(),"Trebuchet24",60,40,white,TEXT_ALIGN_LEFT)
		end

		self:CreateMenuBar(frame)

		local clearbtn = vgui.Create("DButton",frame)
		clearbtn:SetText("Clear History")
		clearbtn:SetPos(60,62)
		clearbtn:SetWide(80)

		local addresslist = vgui.Create("DListView",frame)
		addresslist:Dock(FILL)
		addresslist:DockMargin(10,65,10,50)
		addresslist.Paint = function(self,w,h)
			draw.OutlinedBoxFilled(0,0,w,h,5,detailcolor,Color(0,0,0))
		end
		addresslist:AddColumn("Glyphs")
		addresslist:AddColumn("Address")
		addresslist:AddColumn("Inbound?")
		addresslist.OnRowSelected = function(index)
			if index == addresslist:GetSelectedLine() then return end
			surface.PlaySound("buttons/button15.wav")
		end
		addresslist.RefreshItems = function(addresslist)
			addresslist:Clear()
			for k,v in pairs(self.dialhist) do
				local addr = v["a"]
				local inb = v["inb"]
				local item = addresslist:AddLine(addr,addr,inb and "Yes" or "No")
				item.address = addr
				item.Columns[1]:SetTextColor(white)
				item.Columns[2]:SetTextColor(white)
				item.Columns[3]:SetTextColor(white)
				item.Columns[1]:SetFont(self.font)
			end
		end

		addresslist:RefreshItems()

		addresslist.Think = function(addresslist)
			if #addresslist:GetLines() ~= #self.dialhist then
				addresslist:RefreshItems()
			end
		end

		addresslist.DoDoubleClick = function(list,lineid,linepanel)
			surface.PlaySound("buttons/button6.wav")
			self:RequestDial(linepanel.address)
		end

		clearbtn.DoClick = function(btn)
			table.Empty(self.dialhist)
			addresslist:Clear()
		end

	end

	function ENT:OpenGUI()
		local frame = vgui.Create("DFrame")
		frame:SetSize(750,500)
		frame:Center()
		frame:MakePopup()
		frame:SetTitle("")
		frame.Paint = function(frame,w,h)
			draw.OutlinedBoxFilled(0,0,w,h,3,detailcolor,Color(0,0,0))
			draw.DrawText("Stargate Dialing Computer","Trebuchet24",150,20,white,TEXT_ALIGN_CENTER)
			draw.DrawText(self:GetStargate():GetGateName(),"Trebuchet24",60,40,white,TEXT_ALIGN_LEFT)
		end

		self:CreateMenuBar(frame,true)

		local addresslist = vgui.Create("DListView",frame)
		addresslist:Dock(FILL)
		addresslist:DockMargin(10,100,10,50)
		addresslist.Paint = function(self,w,h)
			draw.OutlinedBoxFilled(0,0,w,h,5,detailcolor,Color(0,0,0))
		end
		addresslist:SetDataHeight(100)
		addresslist:SetHideHeaders(true)
		addresslist:AddColumn("Address")
		addresslist.OnRowSelected = function(index)
			if index == addresslist:GetSelectedLine() then return end
			surface.PlaySound("buttons/button15.wav")
		end
		for k,v in pairs(self.addrtable) do
			local address = v["Address"]
			if address == self:GetStargate():GetGateAddress() then continue end
			if v["Class"] == "stargate_orlin" then continue end
			if v["Private"] then continue end
			local group = v["Group"]
			local islocal = v["Local"]
			if islocal and group ~= self:GetStargate():GetGateGroup() then continue end
			if self:GetStargate():GetLocale() and group ~= self:GetStargate():GetGateGroup() then continue end
			local name = v["Name"]
			local item = addresslist:AddLine("")
			item.stargate = v
			//item.Columns[1]:SetFont(self.font)
			item.Columns[1]:SetTextColor(white)
			item.Paint = function(item,w,h)
				local col = Color(0,0,0)
				if item:IsHovered() then
					col = Color(50,50,50)
				else
					col = Color(0,0,0)
				end
				draw.OutlinedBoxFilled(0,0,w,h,2,Color(225,185,0),col)
				draw.OutlinedBox(20,(h/5)-(70/10),70,70,2,detailcolor)
				draw.DrawText(address[1],self.font2,55,(h/3)-(70/10),white,TEXT_ALIGN_CENTER)
				for k,v in pairs(address:ToTable()) do
					if k ~= 1 then
						draw.OutlinedBox(20*(4*k)-60,(h/5)-(70/10),70,70,2,detailcolor)
						draw.DrawText(v,self.font2,55*(k*1.45)-25,(h/3)-(70/10),white,TEXT_ALIGN_CENTER)
					end
				end
				draw.DrawText(name,"Trebuchet24",500,(h/5),white)
				if group ~= self:GetStargate():GetGateGroup() then
					draw.DrawText("Left out symbols:","Trebuchet16",500,(h/2.4),white)
					if self:GetStargate():GetClass() == "stargate_universe" then
						if item.stargate["Class"] == "stargate_universe" then
							draw.DrawText(group[1],self.font,500,(h/1.7),white)
						else
							draw.DrawText(group,self.font,500,(h/1.7),white)
						end
					elseif #group == 2 then
						draw.DrawText(group[1],self.font,500,(h/1.7),white)
					elseif #group == 3 then
						draw.DrawText(group,self.font,500,(h/1.7),white)
					end
				end
			end
		end
		local fastcheck = vgui.Create("DCheckBoxLabel",frame)
		fastcheck:SetPos(60,62)
		fastcheck:SetText("Fast Dial")
		fastcheck:SetChecked(self:GetFast())
		fastcheck.OnChange = function(fc,newvalue)
			if not fc then return end
			self:SetFast(newvalue)
		end

		addresslist.DoDoubleClick = function(list,lineid,linepanel)
			surface.PlaySound("buttons/button6.wav")
			local requestedgate = linepanel.stargate
			local address = requestedgate["Address"]
			local group = requestedgate["Group"]
			if group ~= self:GetStargate():GetGateGroup() then
				if self:GetStargate():GetClass() == "stargate_universe" then
					if requestedgate["Class"] == "stargate_universe" then
						address = address..group[1]
					else
						address = address..group
					end
				elseif #group == 2 then
					address = address..group[1]
				elseif #group == 3 then
					address = address..group
				end
			end
			if not string.find(address,"#") and #address ~= 9 then
				address = address.."#"
			end
			self:RequestDial(address)
		end
	end

	function ENT:CreateMenuBar(frame,isaddrlist,ply)
		local mbar = vgui.Create("DMenuBar",frame)
		mbar:DockMargin(-2,-26,31,0)
		mbar:SetTall(20)
		mbar.Paint = function(mbar,w,h)
			draw.OutlinedBoxFilled(0,0,w,h,1,detailcolor,Color(0,0,0))
		end

		local gatem = mbar:AddMenu( "Gate" )
		gatem:AddOption( "Re-link Computer", function() net.Start("dc_NewGate"..self:EntIndex()) net.SendToServer() end ):SetIcon( "icon16/link.png" )
		gatem:AddOption( "Dial Random Gate", function() self:RequestDial("*") end ):SetIcon( "icon16/transmit.png" )
		gatem:AddOption("Disconnect Gate", function() net.Start("dc_DisconnectGate"..self:EntIndex()) net.SendToServer() end):SetIcon("icon16/disconnect.png")

		local irism = mbar:AddMenu("Iris")
		irism:AddOption("Toggle",function() net.Start("dc_ToggleIris"..self:EntIndex()) net.SendToServer() end):SetIcon("icon16/shield.png")

		local cmenu = mbar:AddMenu("Computer")
		if not isaddrlist then
			cmenu:AddOption("Address List",function() self:OpenGUI() frame:Close() end):SetIcon("icon16/application_view_detail.png")
		else
			cmenu:AddOption("Dial History",function() self:OpenHistory() frame:Close() end):SetIcon("icon16/application_view_detail.png")
		end

		cmenu:AddOption("Settings",function() Derma_Message("Settings Menu isn't implemented yet","Sorry","OK") end):SetIcon("icon16/cog.png")

	end

	function ENT:RequestDial(address)
		if address == "*" then
			local gates = table.Copy(self.addrtable)
			for k,v in pairs(gates) do
				if v["Local"] and v["Group"] ~= self:GetStargate():GetGateGroup() then
					table.RemoveByValue(gates,v)
				end
				if self:GetStargate():GetLocale() and v["Group"] ~= self:GetStargate():GetGateGroup() then
					table.RemoveByValue(gates,v)
				end
				if v["Address"] == self:GetStargate():GetGateAddress() then
					table.RemoveByValue(gates,v)
				end
			end
			local randgate = table.Random(gates)
			address = randgate["Address"]
			local group = randgate["Group"]
			if group ~= self:GetStargate():GetGateGroup() then
				if self:GetStargate():GetClass() == "stargate_universe" then
					if randgate["Class"] == "stargate_universe" then
						address = address
					else
						address = address..group
					end
				elseif #group == 2 then
					address = address..group[1]
				elseif #group == 3 then
					address = address..group
				end
			end
			if not string.find(address,"#") and #address ~= 9 then
				address = address.."#"
			end
		end
		net.Start("dc_ComenceDial"..self:EntIndex())
		net.WriteString(address)
		net.WriteBool(self:GetFast())
		net.SendToServer()
	end

	function ENT:Think()
		net.Receive("dc_AddressRequest"..self:EntIndex(),function(len,ply)
			/*Derma_StringRequest("Dialing Computer","Input Dial Address","",function(txt)
				net.Start("dc_ComenceDial"..self:EntIndex())
				net.WriteString(string.upper(txt).."#")
				net.SendToServer(ply)
			end,nil,"Dial")*/
			self.addrtable = net.ReadTable()
			self:OpenGUI()
		end)
		if not IsValid(self:GetStargate()) or self:GetStargate().IsStargate ~= true then return end
		local daddress = self:GetStargate():GetDialledAddress()
		if daddress ~= self:GetDialingAddress() then
			if self:GetKeyboardActive() then return end
			if not IsValid(self:GetStargate()) or self:GetStargate().IsStargate ~= true then return end
			net.Start("dc_ChangeAddress"..self:EntIndex())
			net.WriteString(daddress)
			net.SendToServer()
		end
		if IsValid(self.stargate) and self.stargate ~= self:GetStargate() then
			self.stargate = self:GetStargate()
			self:DetermineFont()
		end
		if self:GetDialing() and self:GetDialingSymbol() == self:GetRingSymbol() and not self.locking then
			if not string.find(daddress,self:GetDialingSymbol()) then
				self.lastsymbol = self:GetDialingSymbol()
				self:EncodeChevron()
			end
		end
		if string.find(self:GetDialingAddress(),self.lastsymbol) and self.locking then
			self:LockChevron()
		end
		net.Receive("dc_ClearAddress"..self:EntIndex(),function()
			if not self.GetStargate then return end
			if not IsValid(self:GetStargate()) or self:GetStargate().IsStargate ~= true then return end
			self:GetStargate():SetNetworkedString("DialledAddress","")
			self:SetDialingAddress("")
		end)
		net.Receive("dc_AddHistory"..self:EntIndex(),function()
			if not self.GetStargate then return end
			if not IsValid(self:GetStargate()) or self:GetStargate().IsStargate ~= true then return end
			local addr = net.ReadString()
			timer.Simple(1,function()
				table.insert(self.dialhist,{["a"] = addr, ["inb"] = self:GetInbound()})
			end)
		end)

	end
end

scripted_ents.Register(ENT,"win7_dialingcomp")
