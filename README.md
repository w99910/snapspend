# SnapSpend

SnapSpend is a Flutter app for **offline receipt scanning**:

- **OCR** via Tesseract (`flutter_tesseract_ocr`)
- **Local LLM extraction** via llama.cpp FFI (Qwen2.5 GGUF) to turn OCR text into structured JSON
- **SQLite** storage (`sqflite`) + summary UI

## App flow

- **First run**: onboarding (`WelcomePage`)
- **Subsequent runs**: skips onboarding and starts at `ExpensesSummaryPage`

This is controlled by `shared_preferences` using the `onboarding_complete` flag.

## Model + performance notes

- The Qwen2.5 GGUF model is downloaded once, then **loaded once and reused** for subsequent generations (a long-lived background isolate owns the loaded model).
- Image preprocessing and OCR are run with background isolates where possible to avoid UI jank.

## Quick start

### Prerequisites

- Flutter SDK installed
- Android/iOS toolchain (depending on your target)

### Install dependencies

```bash
flutter pub get
```

### Run

```bash
flutter run
```

## License (Important)

This repository is **NOT open source**. See [`LICENSE`](LICENSE).

- **Non-commercial use only**
- **No redistribution**
- **All rights reserved** by the copyright holder

Third-party dependencies and assets included or referenced by this project are governed by their own licenses.
