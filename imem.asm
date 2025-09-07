# imem.asm — View of imem.hex with assembly annotation (not for runtime)

00500093    # ADDI  x1,  x0, 5          ; init: x1 = 5
00300113    # ADDI  x2,  x0, 3          ; init: x2 = 3

002081b3    # ADD   x3,  x1, x2         ; x3 = 8
00800813    # ADDI  x16, x0, 8          ; expected = 8
01018463    # BEQ   x3,  x16, +8        ; pass → skip next; fail → fall-through
001f8f93    # ADDI  x31, x31, 1         ; fail counter++

40208233    # SUB   x4,  x1, x2         ; x4 = 2
00200813    # ADDI  x16, x0, 2          ; expected = 2
01020463    # BEQ   x4,  x16, +8
001f8f93    # ADDI  x31, x31, 1

001122b3    # SLT   x5,  x2, x1         ; 3 < 5 (signed) → 1
00100813    # ADDI  x16, x0, 1
01028463    # BEQ   x5,  x16, +8
001f8f93    # ADDI  x31, x31, 1

0020b333    # SLTU  x6,  x1, x2         ; 5 < 3 (unsigned)? → 0
00000813    # ADDI  x16, x0, 0
01030463    # BEQ   x6,  x16, +8
001f8f93    # ADDI  x31, x31, 1

0020c3b3    # XOR   x7,  x1, x2         ; 5 ^ 3 = 6
00600813    # ADDI  x16, x0, 6
01038463    # BEQ   x7,  x16, +8
001f8f93    # ADDI  x31, x31, 1

0020e433    # OR    x8,  x1, x2         ; 5 | 3 = 7
00700813    # ADDI  x16, x0, 7
01040463    # BEQ   x8,  x16, +8
001f8f93    # ADDI  x31, x31, 1

0020f4b3    # AND   x9,  x1, x2         ; 5 & 3 = 1
00100813    # ADDI  x16, x0, 1
01048463    # BEQ   x9,  x16, +8
001f8f93    # ADDI  x31, x31, 1

00209533    # SLL   x10, x1, x2         ; 5 << 3 = 0x28
02800813    # ADDI  x16, x0, 0x28
01050463    # BEQ   x10, x16, +8
001f8f93    # ADDI  x31, x31, 1

0020d5b3    # SRL   x11, x1, x2         ; 5 >> 3 (logical) = 0
00000813    # ADDI  x16, x0, 0
01058463    # BEQ   x11, x16, +8
001f8f93    # ADDI  x31, x31, 1

ffc00693    # ADDI  x13, x0, -4         ; x13 = 0xFFFF_FFFC
00100713    # ADDI  x14, x0, 1          ; x14 = 1
40e6d633    # SRA   x12, x13, x14       ; -4 >>> 1 (arith) = -2
ffe00813    # ADDI  x16, x0, -2
01060463    # BEQ   x12, x16, +8
001f8f93    # ADDI  x31, x31, 1

10000a13    # ADDI  x20, x0, 0x100      ; DMEM base = 0x100
003a2023    # SW    x3,  0(x20)         ; MEM[0x100] = 8
000a2783    # LW    x15, 0(x20)         ; x15 = MEM[0x100]
00378463    # BEQ   x15, x3, +8         ; pass → skip; fail → x31++
001f8f93    # ADDI  x31, x31, 1

# --- JAL / JALR block (control-flow & link check) ---
010000ef    # JAL   x1, +16             ; jump to block B (pc+16), x1 = return (pc+4)
00000013    # NOP                       ; would execute only if JAL failed
001f8f93    # ADDI  x31, x31, 1         ; fail path if JAL not taken
00000013    # NOP

01408093    # B: ADDI x1, x1, 20        ; adjust RA → A+24 (after this block)
00008067    #     JALR x0, x1, 0        ; return to A+24

00100073    # EBREAK                    ; end of test (TB halts)
