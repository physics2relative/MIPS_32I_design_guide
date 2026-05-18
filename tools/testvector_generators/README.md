# MIPS Logisim block golden generator

이 디렉터리는 block-level testvector golden 값을 생성하는 Python reference입니다.

## 실행

프로젝트 루트에서 실행합니다.

```bash
python3 -m py_compile tools/testvector_generators/*.py
python3 tools/testvector_generators/generate_all.py --out test_vectors/generated
python3 tools/testvector_generators/generate_all.py --check --out test_vectors/generated
```

## 산출물 원칙

산출물은 단순하게 두 종류만 둡니다.

- `vectors.csv`: 사람이 검토하는 정본 로그입니다. 전체 column, 설명용 field, caveat 확인은 CSV에서 합니다.
- `<signal>.hex`: Logisim ROM import용 `v2.0 raw` memory image입니다. 실제 ROM 입력/expected 비교에 필요한 신호만 생성합니다.

생성하지 않는 것:

- per-column `.txt`
- `case.hex`, `cycle.hex` 같은 metadata-only 파일
- `_bin` 없는 alias 중복 파일

예: ALU는 `A.hex`, `B.hex`, `ALUSel_bin.hex`, `Expected.hex`, `vectors.csv`만 생성합니다.

## 산출 위치

- `test_vectors/generated/alu/`
- `test_vectors/generated/register_file/`
- `test_vectors/generated/imm_generator/`
- `test_vectors/generated/selectors/`
- `test_vectors/generated/control_unit/`
- `test_vectors/generated/branch_comp/`
- `test_vectors/generated/jump_target/`
- `test_vectors/generated/data_memory/`
- `test_vectors/generated/wb_selector/`
- `test_vectors/generated/pc_control/`

기존 `test_vectors/ALU_testvector`, `test_vectors/Register_file`, `test_vectors/Register_file_full`는 수정하지 않습니다.

## 기준

- 모든 datapath 결과는 32-bit mask 기준입니다.
- `ALU_NOR`는 `~(A &#124; B)`를 계산한 뒤 32-bit로 mask합니다.
- Data Memory vector는 little-endian byte lane 기준입니다.
- Control Unit의 don't-care `funct` 입력은 Logisim ROM에 넣기 위해 `000000` safe value로 고정하고, CSV의 `funct_dontcare` column에 표시합니다.
