"""Generate reproducible QA artifacts alongside a .pptx file.

Produces:
  qa/libreoffice/deck.pdf  — LibreOffice conversion result
  qa/slides/slide-01.jpg  — per-slide renders (pdftoppm)
  qa/report.json           — versions, slide count, exit codes
"""

import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


def run_qa(pptx_path, dpi=150):
    pptx = Path(pptx_path).resolve()
    qa_dir = pptx.parent / "qa"
    lo_dir = qa_dir / "libreoffice"
    slides_dir = qa_dir / "slides"

    # Clear → recreate each run for reproducibility
    if qa_dir.exists():
        shutil.rmtree(qa_dir)
    lo_dir.mkdir(parents=True)
    slides_dir.mkdir(parents=True)

    # PDF conversion — explicit --outdir avoids CWD ambiguity
    from office.soffice import run_soffice
    lo_result = run_soffice(
        ["--headless", "--convert-to", "pdf", "--outdir", str(lo_dir), str(pptx)],
        capture_output=True,
    )
    pdf_path = lo_dir / (pptx.stem + ".pdf")

    # Slide renders
    poppler_result = subprocess.run(
        ["pdftoppm", "-jpeg", "-r", str(dpi), str(pdf_path), str(slides_dir / "slide")],
        capture_output=True,
    )

    slides = sorted(slides_dir.glob("*.jpg"))
    lo_ver = subprocess.run(["soffice", "--version"], capture_output=True, text=True)

    report = {
        "generated": datetime.now(timezone.utc).isoformat(),
        "pptx": str(pptx),
        "slide_count": len(slides),
        "conversion_exit_code": lo_result.returncode,
        "poppler_exit_code": poppler_result.returncode,
        "libreoffice_version": lo_ver.stdout.strip(),
        "resolution_dpi": dpi,
        "slides": [str(s) for s in slides],
    }
    (qa_dir / "report.json").write_text(json.dumps(report, indent=2))
    return report


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: uv run .claude/skills/pptx/scripts/qa.py output.pptx [dpi]", file=sys.stderr)
        sys.exit(1)
    r = run_qa(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 150)
    print(f"QA: {r['slide_count']} slides, exit {r['conversion_exit_code']} → {Path(sys.argv[1]).parent}/qa/")
