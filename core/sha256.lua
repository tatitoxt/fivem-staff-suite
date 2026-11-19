-- core/sha256.lua — SHA-256 en Lua 5.4 puro (sin dependencias).
-- Agnóstico de plataforma (D019): usa operadores de bits nativos de Lua 5.4,
-- compatibles con el Lua de FiveM. Testeado contra vectores NIST.
local M = {}

local K = {
  0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
  0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
  0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
  0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
  0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
}

local MASK = 0xFFFFFFFF
local function rotr(x, n) return ((x >> n) | (x << (32 - n))) & MASK end

-- digest de una cadena de bytes -> hex string (64 chars)
function M.hex(data)
  local H = {0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
  local len = #data
  local bitlen = len * 8
  -- padding: 0x80, ceros, hasta 56 mod 64, luego longitud big-endian 64-bit
  data = data .. "\128"
  while (#data % 64) ~= 56 do data = data .. "\0" end
  -- longitud 64-bit big-endian (soporta hasta 2^53 por double, suficiente para logs)
  local hi = math.floor(bitlen / 0x100000000)
  local lo = bitlen % 0x100000000
  data = data .. string.char((hi >> 24) & 0xFF, (hi >> 16) & 0xFF, (hi >> 8) & 0xFF, hi & 0xFF,
                             (lo >> 24) & 0xFF, (lo >> 16) & 0xFF, (lo >> 8) & 0xFF, lo & 0xFF)

  for block = 1, #data, 64 do
    local W = {}
    for i = 0, 15 do
      local b1, b2, b3, b4 = data:byte(block + i*4, block + i*4 + 3)
      W[i] = ((b1 << 24) | (b2 << 16) | (b3 << 8) | b4) & MASK
    end
    for i = 16, 63 do
      local s0 = rotr(W[i-15],7) ~ rotr(W[i-15],18) ~ (W[i-15] >> 3)
      local s1 = rotr(W[i-2],17) ~ rotr(W[i-2],19) ~ (W[i-2] >> 10)
      W[i] = (W[i-16] + s0 + W[i-7] + s1) & MASK
    end
    local a,b,c,d,e,f,g,h = H[1],H[2],H[3],H[4],H[5],H[6],H[7],H[8]
    for i = 0, 63 do
      local S1 = rotr(e,6) ~ rotr(e,11) ~ rotr(e,25)
      local ch = (e & f) ~ ((~e) & g)
      local t1 = (h + S1 + ch + K[i+1] + W[i]) & MASK
      local S0 = rotr(a,2) ~ rotr(a,13) ~ rotr(a,22)
      local maj = (a & b) ~ (a & c) ~ (b & c)
      local t2 = (S0 + maj) & MASK
      h=g; g=f; f=e; e=(d+t1)&MASK; d=c; c=b; b=a; a=(t1+t2)&MASK
    end
    H[1]=(H[1]+a)&MASK; H[2]=(H[2]+b)&MASK; H[3]=(H[3]+c)&MASK; H[4]=(H[4]+d)&MASK
    H[5]=(H[5]+e)&MASK; H[6]=(H[6]+f)&MASK; H[7]=(H[7]+g)&MASK; H[8]=(H[8]+h)&MASK
  end
  return string.format("%08x%08x%08x%08x%08x%08x%08x%08x", H[1],H[2],H[3],H[4],H[5],H[6],H[7],H[8])
end

return M
