# tv_gen: HDL용 packed mem 생성기

`tools/tv_gen`은 기존 Logisim 검증 벡터를 HDL testbench에서 읽기 쉬운 `vectors.mem`으로 포장하는 어댑터입니다.

## 원칙

- 원본 기준 데이터는 `test_vectors/generated/<block>/vectors.csv`와 포트별 `*.hex` 파일입니다.
- `tools/tv_gen`은 golden 값을 새로 계산하지 않습니다.
- 기존 CSV/HEX는 수정하지 않고, 같은 블록 디렉터리에 `vectors.mem`만 추가로 생성합니다.
- Verilog testbench는 `$readmemh`로 `vectors.mem`을 읽고, MSB부터 정의된 필드 순서대로 unpack합니다.

## 생성 명령

```sh
python3 tools/tv_gen/generate_all.py --root . --block all
python3 tools/tv_gen/generate_all.py --root . --block register_file
python3 tools/tv_gen/generate_all.py --root . --block alu
```

## packed mem 형식

각 줄은 하나의 테스트 케이스입니다. 줄 내부는 여러 입력/기대값 필드를 하나의 큰 hex word로 이어 붙인 값입니다.
필드 순서와 bit 폭은 `tools/tv_gen/mem_pack.py`의 `SCHEMAS` 및 `REGISTER_FILE_SCHEMA`가 기준입니다.

예를 들어 ALU는 다음 순서로 pack됩니다.

```text
{ ALUSel_bin[3:0], A[31:0], B[31:0], Expected[31:0] }
```

`*_bin.hex`처럼 이름에 `bin`이 들어간 파일도 Logisim `v2.0 raw` 파일에서는 hex 숫자로 저장됩니다. 예를 들어 4-bit ALUSel의 10은 `A`로 저장되므로, tv_gen은 모든 포트별 `.hex` 파일을 hex로 파싱합니다.

## testvector_generators와의 관계

- `tools/testvector_generators`는 CSV/포트별 HEX를 만드는 원래 golden generator 계층입니다.
- `tools/tv_gen`은 이미 생성된 CSV/HEX를 HDL용 `.mem`으로 변환하는 후처리 계층입니다.
- 따라서 HDL 시뮬레이션만 놓고 보면 현재는 `tools/tv_gen`이 직접 사용됩니다.
- 새 golden case를 추가하거나 CSV/HEX 자체를 다시 만들려면 `tools/testvector_generators`를 복구/정비해서 사용해야 합니다.
