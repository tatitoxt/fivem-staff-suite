-- tests/test_sha256.lua — vectores NIST conocidos.
local sha = require("core.sha256")
local T = {}

function T.test_empty()
  assert(sha.hex("") == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "empty vector")
end

function T.test_abc()
  assert(sha.hex("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "abc vector")
end

function T.test_two_blocks()
  -- vector de 2 bloques (448 bits)
  assert(sha.hex("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")
    == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1", "two-block vector")
end

function T.test_long()
  -- un millón de 'a' (vector NIST) — verifica padding multi-bloque
  assert(sha.hex(string.rep("a", 1000000))
    == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0", "million-a vector")
end

return T
