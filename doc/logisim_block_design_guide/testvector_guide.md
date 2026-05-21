# Block testvector 검증 가이드

> 기준: `doc/mips_functional_spec.md`, `doc/logisim_block_design_guide/blocks/*.md`, `tools/testvector_generators/`
>
> 목표: block별 golden 값을 손계산하지 않고 Python reference/generator로 산출한 뒤 Logisim 회로 출력과 비교합니다.

## 1. 기본 검증 구조

각 block test harness는 아래 구조를 기본으로 둡니다.

```text
Counter -> ROM address
             |
             v
        input vector ROM(s) ----> DUT block ----> RTL/Logisim output ----+
                                                                         |
Python golden output ROM ----------------------------------------------> Comparator (=)
                                                                         |
                                                                  NOT -> Error counter
```

1. 입력 vector는 ROM에 저장합니다.
2. counter가 ROM address를 0부터 마지막 vector까지 증가시킵니다.
3. 각 cycle에서 ROM 출력이 DUT block 입력으로 들어갑니다.
4. DUT 출력은 HEX decoder에 연결해 사람이 즉시 관찰할 수 있게 합니다.
5. 동시에 comparator가 DUT 출력과 golden ROM 출력을 비교합니다.
6. comparator의 `=` 출력이 1이면 pass입니다.
7. `=` 출력 뒤에 NOT gate를 붙이면 mismatch pulse가 됩니다.
8. mismatch pulse를 error counter enable에 연결해 error 횟수를 누적합니다.
9. 모든 vector를 투입한 뒤 error counter가 0이면 해당 block vector set은 pass입니다.

## 2. ROM 파일 구성 권장

- 사람은 `vectors.csv`만 봅니다. CSV가 전체 vector 정본입니다.
- Logisim ROM에는 `.hex`만 사용합니다.
- generator는 각 block 디렉터리에 다음 두 종류만 생성합니다.
  - `vectors.csv`: 전체 vector table
  - `<signal>.hex`: ROM 입력 또는 expected 비교에 필요한 신호만 담은 `v2.0 raw` memory image
- per-column `.txt`, metadata-only `.hex`, alias 중복 파일은 만들지 않습니다.
- Logisim ROM의 `Data Bits`는 파일이 담는 signal 폭과 맞춥니다. 예: `A.hex`, `B.hex`, `Expected.hex`는 32-bit, `ALUSel_bin.hex`는 4-bit, `opcode_bin.hex`는 6-bit입니다.
- counter width는 vector 개수 이상을 표현할 수 있게 잡습니다.
- 마지막 vector 이후에는 counter를 멈추거나 enable을 0으로 내려 error counter가 불필요하게 증가하지 않게 합니다.

## 3. Python golden generator 사용법

프로젝트 루트에서 실행합니다.

```bash
python3 -m py_compile tools/testvector_generators/*.py
python3 tools/testvector_generators/generate_all.py --out test_vectors/generated
python3 tools/testvector_generators/generate_all.py --check --out test_vectors/generated
```

- generator 코드는 `tools/testvector_generators/`에 있습니다.
- 생성된 golden 산출물은 `test_vectors/generated/<block>/`에 있습니다.
- 기존 `test_vectors/ALU_testvector/`, `test_vectors/Register_file/`, `test_vectors/Register_file_full/`는 덮어쓰지 않습니다.
- ALU/Register File도 새 generated 위치에 reference 산출물을 만들며, 기존 vector는 비교/보존 대상입니다.

## 4. Logisim ROM import 절차

1. `test_vectors/generated/<block>/<signal>.hex` 파일을 선택합니다.
2. Logisim ROM component의 `Data Bits`를 해당 signal 폭으로 설정합니다.
3. ROM content editor에서 import/load를 선택해 `.hex` 파일을 불러옵니다.
4. 같은 counter 출력을 모든 입력 ROM과 golden output ROM의 address에 연결합니다.
5. DUT 출력과 golden ROM 출력을 comparator에 연결합니다.
6. comparator `=` 출력은 pass, `NOT(=)` 출력은 error pulse로 사용합니다.

예: ALU block은 다음 ROM 조합을 기본으로 둡니다.

| ROM 파일 | Data Bits | 연결 |
|---|---:|---|
| `test_vectors/generated/alu/A.hex` | 32 | ALU `A` 입력 |
| `test_vectors/generated/alu/B.hex` | 32 | ALU `B` 입력 |
| `test_vectors/generated/alu/ALUSel_bin.hex` | 4 | ALU `ALUSel` 입력 |
| `test_vectors/generated/alu/Expected.hex` | 32 | comparator golden 입력 |

## 5. Block별 generated 산출물

| Block | Generated 위치 | 핵심 비교 출력 |
|---|---|---|
| ALU | `test_vectors/generated/alu/` | `ALUResult` |
| Register File / DestSel | `test_vectors/generated/register_file/` | `WriteReg`, `Data_rs`, `Data_rt`, write accept 여부 |
| Imm Generator | `test_vectors/generated/imm_generator/` | `ImmVal`, `BranchOff`, jump target reference |
| A/B Selectors | `test_vectors/generated/selectors/` | `ALU_A`, `ALU_B` |
| Control Unit | `test_vectors/generated/control_unit/` | instruction별 control bundle |
| Branch Comp | `test_vectors/generated/branch_comp/` | 1-bit `BrSel` 기준 `BranchTaken` 조건 |
| Jump Target Gen / Jump Sel | `test_vectors/generated/jump_target/` | `JumpImmTarget`, `SelectedJumpTarget` |
| Data Memory | `test_vectors/generated/data_memory/` | load `Data_RD`, store `ExpectedNewWord`, write enable |
| WB Selector | `test_vectors/generated/wb_selector/` | `Data_WR` |
| PCControl | `test_vectors/generated/pc_control/` | `PCSel`, `BranchTaken` |

## 6. Caveat

- Data Memory vector는 little-endian byte lane 기준으로 golden 값을 산출합니다. 회로에서 endian 주석을 반드시 맞춰야 합니다.
- Register File vector는 clock edge 이후 관찰 기준입니다. Logisim test harness에서 write edge와 read 관찰 시점을 분리합니다.
- Control Unit vector의 don't-care `funct` 입력은 ROM 로딩을 위해 `000000`으로 고정하고, CSV의 `funct_dontcare` column에 표시합니다.
- top-level CPU 통합 vector는 이번 범위가 아니며, block-level 검증 후 별도 pass에서 다룹니다.
