# test_mips ROM files

이 폴더는 Logisim Instruction Memory/ROM에 바로 load할 수 있는 MIPS 테스트 프로그램을 담습니다.

## 파일

- `instruction_chain_abs_all.rom.hex`: Logisim `v2.0 raw` ROM image입니다. 이 파일을 ROM/RAM에 load하면 됩니다.
- `instruction_chain_abs_all.mem`: Verilog `$readmemh`용 header 없는 동일 instruction word 목록입니다.
- `instruction_chain_abs_all.asm`: 사람이 읽는 assembly와 각 instruction의 machine code listing입니다.
- `instruction_chain_abs_all_listing.csv`: CSV listing입니다.
- `expected_result.txt`: 최종 기대값입니다.

## 실행 조건

- PC reset: `0x0000_0000`
- no delay slot
- little-endian data memory
- custom `abs rd, rs`: `opcode=0`, `funct=0x2C`
- Register File 내부 same-cycle bypass 제거 권장

## 기대 결과

```text
$30 = 0x246E10BA
```

`HALT`는 마지막 instruction의 자기 자신으로 jump하는 무한 루프입니다.
