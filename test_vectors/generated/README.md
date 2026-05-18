# Generated block-level golden vectors

이 디렉터리는 `tools/testvector_generators/generate_all.py`가 생성한 산출물입니다. 기존 `test_vectors/ALU_testvector`, `test_vectors/Register_file`, `test_vectors/Register_file_full`은 덮어쓰지 않습니다.

검증 재현:

```bash
python3 tools/testvector_generators/generate_all.py --check --out test_vectors/generated
```

각 block 디렉터리 산출물은 두 종류만 둡니다.

- `vectors.csv`: 사람이 검토하는 정본 로그입니다. 모든 column과 설명용 field를 여기에서 확인합니다.
- `<signal>.hex`: Logisim ROM에 import하기 쉬운 `v2.0 raw` hex memory image입니다. 실제 ROM 입력/expected 비교에 필요한 신호만 생성합니다.

중복을 줄이기 위해 per-column `.txt`, metadata `.hex`, `_bin` 없는 alias 파일은 생성하지 않습니다. 예를 들어 ALU control ROM은 CSV column 이름 그대로 `ALUSel_bin.hex`를 사용합니다.

Logisim ROM import 시 `.hex` 파일을 쓰고, ROM의 Data Bits 폭은 대상 signal 폭과 맞춥니다. 예: `A.hex`/`B.hex`/`Expected.hex`는 32-bit, `ALUSel_bin.hex`는 4-bit입니다.
