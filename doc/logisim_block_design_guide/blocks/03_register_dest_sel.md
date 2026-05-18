# Register / Dest Sel

## 역할

Register block은 32개 32-bit general-purpose register를 읽고 씁니다. Dest Sel은 instruction 형식에 따라 write destination register를 `rt`, `rd`, `$31`, none 중에서 선택합니다.

## 입력

| 입력 | 폭 | 출처 | 설명 |
|---|---:|---|---|
| `Addr_rs` | 5 | Inst Split `rs` | read port 1 주소 |
| `Addr_rt` | 5 | Inst Split `rt` | read port 2 주소 |
| `Addr_WR` / `WriteReg` | 5 | Dest Sel | write 주소 |
| `Data_WR` | 32 | WB selector | write-back data |
| `RegWEn` | 1 | Control Unit | register write enable |
| `clk` | 1 | top level | write clock |
| `DestSel` | 2 | Control Unit | destination 선택 |

## 출력

| 출력 | 폭 | 목적지 | 설명 |
|---|---:|---|---|
| `Data_rs` | 32 | A Selector, Branch Comp, Jump Sel | `rs` 값 |
| `Data_rt` | 32 | B Selector, Branch Comp, Data Memory | `rt` 값 |
| `WriteReg` | 5 | Register write address | Dest Sel 결과 |

## Logisim 설계 가이드

1. Register file은 read 2-port, write 1-port 구조로 만듭니다.
2. `RegWEn=1`이고 `WriteReg != 0`일 때만 write되게 합니다. `$zero`는 항상 0이어야 합니다.
3. Dest Sel mux 입력 순서는 명세서와 맞춥니다: `00=rt`, `01=rd`, `10=$31`, `11=none`.
4. `DEST_NONE`은 write가 없어야 하므로 `RegWEn=0`과 함께 사용합니다. 방어적으로 `Addr_WR=0`에 묶어도 됩니다.
5. `jal`은 `$31`, `jalr`은 `rd`, I-type ALU/load/lui는 `rt`, R-type은 `rd`를 선택합니다.

## 검증 포인트

- R-type `add`가 `rd`에 씁니다.
- `addi/lw/lui`가 `rt`에 씁니다.
- `jal`이 `$31`에 `PC+4`를 씁니다.
- `sw/beq/bne/j/jr`에서 register write가 발생하지 않습니다.
- `$zero`에 write를 시도해도 `$zero`는 0입니다.

## 흔한 실수

- `jalr` destination을 `$31`로 고정하는 실수. 명세서에서는 `jalr`이 `rd`를 사용합니다.
- `rt`가 source인지 destination인지 instruction별로 구분하지 않는 실수.
- write clock edge와 PC update edge의 순서를 의도 없이 섞는 실수.

## Caveat / 주의사항

단일 사이클에서는 forwarding이 없으므로 같은 instruction 안의 read/write 충돌은 없습니다. 파이프라인에서는 WB-to-ID bypass 또는 register file write/read timing 정책을 별도로 정해야 합니다.

## 파이프라인 확장 시 메모

단일 사이클에서 read port와 Dest Sel은 조합 경로이고, register write는 clock edge에서 확정됩니다. 파이프라인으로 확장할 때는 WB stage write timing, WB-to-ID bypass, `RsUsed/RtUsed` 기반 hazard 판단을 별도로 검토해야 합니다.
