--!strict
-- Decodifica las texturas que lleva el plugin: base64 -> bytes del PNG -> píxeles RGBA (para un EditableImage).
-- Solo PNG de 8 bits RGBA sin entrelazar, que es como gen_plugin.py los guarda.

local Png = {}

-- ---------------------------------------------------------------- base64
local B64: { [number]: number } = {}
do
	local abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, #abc do
		B64[string.byte(abc, i)] = i - 1
	end
end

function Png.fromBase64(s: string): buffer
	s = string.gsub(s, "[^%w%+/=]", "")
	local pad = 0
	if string.sub(s, -2) == "==" then
		pad = 2
	elseif string.sub(s, -1) == "=" then
		pad = 1
	end
	local n = #s // 4 * 3 - pad
	local out = buffer.create(n)
	local o = 0
	for i = 1, #s, 4 do
		local a, b, c, d = string.byte(s, i, i + 3)
		local v = bit32.bor(bit32.lshift(B64[a], 18), bit32.lshift(B64[b], 12), bit32.lshift(B64[c] or 0, 6), B64[d] or 0)
		if o < n then
			buffer.writeu8(out, o, bit32.rshift(v, 16))
		end
		if o + 1 < n then
			buffer.writeu8(out, o + 1, bit32.band(bit32.rshift(v, 8), 255))
		end
		if o + 2 < n then
			buffer.writeu8(out, o + 2, bit32.band(v, 255))
		end
		o += 3
	end
	return out
end

-- ---------------------------------------------------------------- inflate (RFC 1951)
local LEN_BASE = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 }
local LEN_EXTRA = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 }
local DIST_BASE = { 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073,
	4097, 6145, 8193, 12289, 16385, 24577 }
local DIST_EXTRA = { 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 }
local CL_ORDER = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }

type Huff = { t: { number }, bits: number }

-- tabla de búsqueda directa: los siguientes `bits` bits (invertidos) -> símbolo * 16 + largo del código
local function huffman(lengths: { number }, n: number): Huff
	local count = table.create(16, 0)
	local maxLen = 0
	for i = 1, n do
		local l = lengths[i]
		if l > 0 then
			count[l] += 1
			if l > maxLen then
				maxLen = l
			end
		end
	end
	if maxLen == 0 then
		maxLen = 1
	end
	local nextCode = table.create(16, 0)
	local code = 0
	for bits = 1, 15 do
		code = bit32.lshift(code + (if bits > 1 then count[bits - 1] else 0), 1)
		nextCode[bits] = code
	end
	local size = bit32.lshift(1, maxLen)
	local t = table.create(size, 0)
	for sym = 0, n - 1 do
		local l = lengths[sym + 1]
		if l > 0 then
			local c = nextCode[l]
			nextCode[l] = c + 1
			local r = 0
			for _ = 1, l do
				r = bit32.bor(bit32.lshift(r, 1), bit32.band(c, 1))
				c = bit32.rshift(c, 1)
			end
			local step = bit32.lshift(1, l)
			local entry = sym * 16 + l
			for k = r, size - 1, step do
				t[k + 1] = entry
			end
		end
	end
	return { t = t, bits = maxLen }
end

local FIXED_LIT: Huff, FIXED_DIST: Huff
do
	local l = table.create(288, 0)
	for i = 1, 288 do
		local s = i - 1
		l[i] = if s < 144 then 8 elseif s < 256 then 9 elseif s < 280 then 7 else 8
	end
	FIXED_LIT = huffman(l, 288)
	FIXED_DIST = huffman(table.create(30, 5), 30)
end

-- src = datos deflate (desde `pos`); outSize = tamaño exacto de lo descomprimido
function Png.inflate(src: buffer, pos: number, outSize: number): buffer
	local out = buffer.create(outSize)
	local op = 0
	local srcLen = buffer.len(src)
	local bitbuf, bitcnt = 0, 0

	local function need(n: number)
		while bitcnt < n do
			local byte = if pos < srcLen then buffer.readu8(src, pos) else 0
			pos += 1
			bitbuf = bit32.bor(bitbuf, bit32.lshift(byte, bitcnt))
			bitcnt += 8
		end
	end
	local function bits(n: number): number
		if n == 0 then
			return 0
		end
		need(n)
		local v = bit32.band(bitbuf, bit32.lshift(1, n) - 1)
		bitbuf = bit32.rshift(bitbuf, n)
		bitcnt -= n
		return v
	end
	local function decode(h: Huff): number
		need(h.bits)
		local e = h.t[bit32.band(bitbuf, bit32.lshift(1, h.bits) - 1) + 1]
		local l = bit32.band(e, 15)
		if l == 0 then
			error("PNG dañado (código Huffman inválido)")
		end
		bitbuf = bit32.rshift(bitbuf, l)
		bitcnt -= l
		return bit32.rshift(e, 4)
	end

	local final = 0
	repeat
		final = bits(1)
		local kind = bits(2)
		if kind == 0 then
			-- bloque sin comprimir: se alinea al byte
			bits(bitcnt % 8)
			local len = bits(16)
			bits(16)
			for _ = 1, len do
				buffer.writeu8(out, op, bits(8))
				op += 1
			end
		else
			local lit: Huff, dist: Huff
			if kind == 1 then
				lit, dist = FIXED_LIT, FIXED_DIST
			elseif kind == 2 then
				local hlit, hdist, hclen = bits(5) + 257, bits(5) + 1, bits(4) + 4
				local cl = table.create(19, 0)
				for i = 1, hclen do
					cl[CL_ORDER[i] + 1] = bits(3)
				end
				local clh = huffman(cl, 19)
				local lens = table.create(hlit + hdist, 0)
				local i = 1
				while i <= hlit + hdist do
					local sym = decode(clh)
					if sym < 16 then
						lens[i] = sym
						i += 1
					else
						local rep, val = 0, 0
						if sym == 16 then
							rep, val = 3 + bits(2), lens[i - 1]
						elseif sym == 17 then
							rep = 3 + bits(3)
						else
							rep = 11 + bits(7)
						end
						for _ = 1, rep do
							lens[i] = val
							i += 1
						end
					end
				end
				lit = huffman(lens, hlit)
				dist = huffman(table.move(lens, hlit + 1, hlit + hdist, 1, table.create(hdist, 0)), hdist)
			else
				error("PNG dañado (tipo de bloque inválido)")
			end
			while true do
				local sym = decode(lit)
				if sym < 256 then
					buffer.writeu8(out, op, sym)
					op += 1
				elseif sym == 256 then
					break
				else
					local li = sym - 256
					local len = LEN_BASE[li] + bits(LEN_EXTRA[li])
					local di = decode(dist) + 1
					local d = DIST_BASE[di] + bits(DIST_EXTRA[di])
					if d > len then
						buffer.copy(out, op, out, op - d, len)
						op += len
					else
						for _ = 1, len do
							buffer.writeu8(out, op, buffer.readu8(out, op - d))
							op += 1
						end
					end
				end
			end
		end
	until final == 1
	return out
end

-- ---------------------------------------------------------------- PNG
local function be32(b: buffer, at: number): number
	return bit32.bor(bit32.lshift(buffer.readu8(b, at), 24), bit32.lshift(buffer.readu8(b, at + 1), 16),
		bit32.lshift(buffer.readu8(b, at + 2), 8), buffer.readu8(b, at + 3))
end

-- devuelve ancho, alto y los píxeles RGBA (fila por fila, de arriba abajo)
function Png.decode(png: buffer): (number, number, buffer)
	if buffer.len(png) < 8 or buffer.readu32(png, 0) ~= 0x474E5089 then
		error("no es un PNG")
	end
	local w, h = 0, 0
	local at = 8
	local idat: { buffer } = {}
	local total = 0
	while at + 8 <= buffer.len(png) do
		local len = be32(png, at)
		local kind = buffer.readstring(png, at + 4, 4)
		if kind == "IHDR" then
			w, h = be32(png, at + 8), be32(png, at + 12)
			local depth, color, interlace = buffer.readu8(png, at + 16), buffer.readu8(png, at + 17), buffer.readu8(png, at + 20)
			if depth ~= 8 or color ~= 6 or interlace ~= 0 then
				error("solo PNG RGBA de 8 bits sin entrelazar")
			end
		elseif kind == "IDAT" then
			local part = buffer.create(len)
			buffer.copy(part, 0, png, at + 8, len)
			table.insert(idat, part)
			total += len
		elseif kind == "IEND" then
			break
		end
		at += 12 + len
	end
	local z = buffer.create(total)
	local o = 0
	for _, part in idat do
		buffer.copy(z, o, part)
		o += buffer.len(part)
	end
	-- los datos zlib empiezan con 2 bytes de cabecera
	local stride = w * 4
	local raw = Png.inflate(z, 2, h * (stride + 1))
	local px = buffer.create(h * stride)
	for y = 0, h - 1 do
		local f = buffer.readu8(raw, y * (stride + 1))
		local src = y * (stride + 1) + 1
		local dst = y * stride
		local prev = dst - stride
		if f == 0 then
			buffer.copy(px, dst, raw, src, stride)
		else
			for i = 0, stride - 1 do
				local x = buffer.readu8(raw, src + i)
				local a = if i >= 4 then buffer.readu8(px, dst + i - 4) else 0
				local b = if y > 0 then buffer.readu8(px, prev + i) else 0
				local v
				if f == 1 then
					v = x + a
				elseif f == 2 then
					v = x + b
				elseif f == 3 then
					v = x + (a + b) // 2
				else
					local c = if y > 0 and i >= 4 then buffer.readu8(px, prev + i - 4) else 0
					local p = a + b - c
					local pa, pb, pc = math.abs(p - a), math.abs(p - b), math.abs(p - c)
					v = x + (if pa <= pb and pa <= pc then a elseif pb <= pc then b else c)
				end
				buffer.writeu8(px, dst + i, v % 256)
			end
		end
	end
	return w, h, px
end

return Png
