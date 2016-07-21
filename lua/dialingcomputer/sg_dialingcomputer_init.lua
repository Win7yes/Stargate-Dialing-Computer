//Dialing Computer Init
if CLIENT then
	local glyphfont = {
		font = "Stargate Address Glyphs Concept",
		size = 18,
		weight = size,
		antialias = true,
	}
	local encodedglyph = {
		font = "Stargate Address Glyphs Concept",
		size = 40,
		weight = size,
		antialias = true
	}

	surface.CreateFont("dc_glyphs_sg1",glyphfont)
	surface.CreateFont("dc_encodedglyph_sg1",encodedglyph)
	local glyphfont_atl = {
		font = "Stargate Address Glyphs Atl",
		size = 18,
		weight = size,
		antialias = true,
	}
	local encodedglyph_atl = {
		font = "Stargate Address Glyphs Atl",
		size = 40,
		weight = size,
		antialias = true
	}

	surface.CreateFont("dc_glyphs_atl",glyphfont_atl)
	surface.CreateFont("dc_encodedglyph_atl",encodedglyph_atl)
	local glyphfont_sgu = {
		font = "Stargate Address Glyphs U",
		size = 18,
		weight = size,
		antialias = true,
	}
	local encodedglyph_sgu = {
		font = "Stargate Address Glyphs U",
		size = 40,
		weight = size,
		antialias = true
	}

	surface.CreateFont("dc_glyphs_sgu",glyphfont_sgu)
	surface.CreateFont("dc_encodedglyph_sgu",encodedglyph_sgu)
else
	return
end