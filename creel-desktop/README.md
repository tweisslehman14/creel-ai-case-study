# Creel desktop journal

For a fresh clone, launch the core journal from this directory with Python 3.11 or later:

```sh
python3 server.py
```

Open the local address printed by the server. Core import, journal review, and manual transcript entry require no pip packages. Imported originals remain unchanged. Generated facts are proposals linked to exact source text; reviewing a fact remains necessary because a valid quote does not prove the model interpreted it correctly. The app computes source offsets from an exact, unique quote when model offsets are missing or wrong. Repeated quotations require valid explicit offsets; fuzzy matches are rejected.

On the Mac used to build the case study, double-click **Start Creel.command** (or run `./"Start Creel.command"`) to use the separately installed local Llama and Whisper tools. Open **http://127.0.0.1:8767** and keep the terminal/service open. Those local model files and tools are not included in this repository and run only when processing is explicitly requested.

## Optional local AI setup

AI processing is off by default. Nothing is downloaded automatically. The application must receive an explicit **enable AI** request before invoking a provider. Configuration status reports installed/configured prerequisites; it does not prove a model server is running.

For extraction, run your locally installed Ollama service and configure an already installed model before starting the desktop server:

```sh
export CREEL_OLLAMA_MODEL='your-installed-model'
python3 server.py
```

`CREEL_OLLAMA_URL` defaults to `http://127.0.0.1:11434`. Only loopback HTTP addresses are permitted; redirects and environment proxies are disabled. The adapter uses Ollama's documented [chat endpoint](https://docs.ollama.com/api/chat) with JSON output and streaming disabled. No tool definitions or execution capabilities are supplied to the model. Only note text, effective transcripts, and event kind enter extraction; GPS metadata, photos, trip metadata, and original audio are excluded. A location explicitly spoken or typed in a note is still part of that text.

For audio transcription, optionally configure an installed **whisper.cpp** CLI and local model file:

```sh
export CREEL_WHISPER_EXECUTABLE='/absolute/path/to/whisper-cli'
export CREEL_WHISPER_MODEL='/absolute/path/to/local-model.bin'
```

Local ffmpeg must also be on PATH. The adapter converts selected audio to mono 16 kHz WAV in a temporary directory, invokes the configured executable using an argument array, and retains the resulting raw transcript. Executable/model paths are server configuration and cannot be supplied by a browser request. No shell commands from journal content are executed. Installation and model downloads are separate, user-controlled steps.

When transcription is unavailable, add a **manual transcript**. This remains labeled manual and is never presented as AI output. Human transcript corrections feed subsequent extraction while the original transcript remains available. Audio parts are processed separately and identified by attachment; unchanged transcripts can be reused using their attachment ID and content hash. No timestamp segments are invented when the local CLI only returns plain text.

## Validation

```sh
python3 -m unittest discover -s tests -v
```

Provider tests use mocks and make no inference calls. They cover opt-in behavior, exact quote validation, malformed output, deterministic fact IDs/deduplication, multipart transcript reuse, human corrections, restricted payloads, loopback enforcement, and rejection of unsupported catch counts. Provider configuration alone is not an end-to-end AI validation claim.

## Verified local audio setup — September 17, 2026

On this Mac, Homebrew whisper.cpp **1.9.4** is installed at `/opt/homebrew/bin/whisper-cli`. The English model is downloaded at `models/ggml-base.en.bin` (about 142 MiB, excluded from Git). Its SHA-256 is `a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002`. It came from the [upstream project's documented model host](https://huggingface.co/ggerganov/whisper.cpp/tree/main), using the format and conversion instructions in [whisper.cpp's quick start](https://github.com/ggml-org/whisper.cpp#quick-start).

From this directory, start with the tested local providers configured:

```sh
export CREEL_WHISPER_EXECUTABLE=/opt/homebrew/bin/whisper-cli
export CREEL_WHISPER_MODEL="$PWD/models/ggml-base.en.bin"
export CREEL_OLLAMA_MODEL=llama3.1:8b
python3 server.py
```

An actual synthetic speech test passed through the application's ffmpeg and whisper.cpp adapter. Input speech: “Caught a rainbow trout on an elk hair caddis.” Raw output: “caught a rainbow trout on an elk hair caddis.” Processing returned `processed`, with no errors. This confirms local adapter operation with generated clean speech; river noise, fishing terminology, long recordings, and real phone audio still require validation. The model file and local tool installation are machine setup, not bundled into a portable app installer.

## Using it with the phone app

1. Export a trip from Creel on the phone and save/transfer its `.fishing-trip.zip` to this Mac.
2. Click **Import a trip**; review the validated preview and add it to the journal.
3. Open a moment. Play original audio, view the photo, or read the original note. Add desktop notes or a manual transcript without changing the source.
4. For audio, choose **Transcribe audio**, then **Find useful details**. For text, go directly to **Find useful details**. Keep/correct or dismiss suggestions.
5. Search your journal and use **Keep a copy** to save a desktop backup somewhere beyond this Mac. Newer phone exports retain your desktop review.

Data lives in `data/` beside this README by default; override with `--data-dir /path/to/library`. Backups restore into an empty library only. To test restoration without changing your journal, start another instance with a fresh data folder and a different `--port`. Do not delete the active data folder without a verified backup.

Current expanded package/backup limit is 250 MB. A desktop archive includes original phone archives as well as media/history, so its size may exceed an individual trip package. No permanent delete/purge UI is included.

## Sample trips and verified results

`samples/` contains four synthetic packages made by the real Swift phone exporter, including one computer-generated voice sample. Import them only if you want clearly labeled demonstration records. The production library starts empty.

[Validation](VALIDATION.md) records 38 passing tests, browser checks, actual local transcription/extraction, the ZIP transfer and restored-library check, and remaining field limitations.
