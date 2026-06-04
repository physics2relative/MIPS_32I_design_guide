# 13. Custom `abs` instruction 설계 가이드

> 기준: `abs rd, rs`는 표준 MIPS integer instruction이 아니라 과제 요구사항을 위한 프로젝트 custom R-type instruction입니다.

## 1. Encoding

| 필드 | 값 | 설명 |
|---|---|---|
| opcode | `000000` | R-type/SPECIAL |
| rs | source register | 절댓값을 계산할 입력 |
| rt | `00000` 권장 | 사용하지 않음 |
| rd | destination register | 결과 write-back 대상 |
| shamt | `00000` | 사용하지 않음 |
| funct | `101100` / `0x2C` | 프로젝트 custom ABS |

## 2. 동작

```text
if R[rs][31] == 1: R[rd] <- ~R[rs] + 1
else:              R[rd] <- R[rs]
```

`0x8000_0000`은 2의 보수에서 양수 표현이 없으므로 결과가 다시 `0x8000_0000`입니다. 현재 CPU에는 overflow exception/trap 경로가 없으므로 이 wrap-around 동작을 명세로 둡니다.

## 3. Control 신호

| 신호 | 값 | 이유 |
|---|---|---|
| RegWEn | `1` | rd에 결과 저장 |
| DestSel | `DEST_RD(01)` | R-type destination |
| ASel | `A_RS(00)` | rs 값을 ALU A로 사용 |
| BSel | `B_ZERO(100)` | B는 사용하지 않지만 안정화 |
| ImmSel | `IMM_SIGN16(00)` | don't-care safe default |
| ALUSel | `ALU_ABS(1011)` | ABS 연산 선택 |
| WBSel | `WB_ALU(01)` | ALU 결과 write-back |
| WdLen | `MEM_NONE(11)` | memory 미사용 |
| MemRW | `MEM_IDLE(00)` | memory 미사용 |
| Branch/Jump | `0/0` | 순차 실행 |
| JumpSel | `0` | don't-care safe default |
| RsUsed/RtUsed | `1/0` | pipeline hazard에서 rs만 source |

## 4. Logisim에서 바꿔야 할 부분

1. **Instruction Splitter**: 기존 `opcode/rs/rt/rd/shamt/funct` 분리는 그대로 사용합니다. 새 wire는 필요 없습니다.
2. **Control Unit**:
   - `opcode==000000` AND `funct==101100` comparator를 추가합니다.
   - ROM 방식이면 `Project/ROM/control_unit_opcode_funct_rom.hex`를 최신 파일로 다시 load합니다. 주소는 `{opcode,funct}=0x02C`입니다.
   - `ALUSel=1011`, `RegWEn=1`, `DestSel=RD`, `ASel=RS`, `BSel=ZERO`, `WBSel=ALU`로 나오는지 probe합니다.
3. **ALU**:
   - 최종 ALU result MUX에 `ALUSel=1011` input을 추가합니다.
   - `A[31]`로 `A`와 `~A + 1` 중 선택하는 ABS path를 추가합니다.
   - B 입력은 ABS에서 사용하지 않으므로 0으로 들어오게 두면 waveform/debug가 쉽습니다.
4. **Pipeline Hazard Unit**:
   - `RsUsed=1`, `RtUsed=0`로 취급합니다. rt field가 instruction 안에 있어도 source register가 아닙니다.

## 5. 필수 테스트

| A(rs) | 예상 결과 |
|---:|---:|
| `0x0000_0000` | `0x0000_0000` |
| `0x0000_0001` | `0x0000_0001` |
| `0xFFFF_FFFF` | `0x0000_0001` |
| `0xFFFF_FFFE` | `0x0000_0002` |
| `0x7FFF_FFFF` | `0x7FFF_FFFF` |
| `0x8000_0000` | `0x8000_0000` |
| `0x8000_0001` | `0x7FFF_FFFF` |
