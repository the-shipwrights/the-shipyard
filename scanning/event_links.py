"""Participant links and terminal QR codes for submitted boats."""

import os
from urllib.parse import quote

import qrcode


def boat_page_url(boat_id: str, public_base_url: str | None = None) -> str:
    """Build the participant URL using the event URL when one is configured."""
    base_url = public_base_url or os.getenv(
        "SHIPYARD_PUBLIC_URL",
        "http://localhost:5173",
    )
    return f"{base_url.rstrip('/')}/boat/{quote(boat_id.upper(), safe='')}"


def print_boat_qr(url: str) -> None:
    """Print a scannable QR code using the terminal's block characters."""
<<<<<<< Updated upstream
=======
    print("QR code: ")
>>>>>>> Stashed changes
    code = qrcode.QRCode(border=2, error_correction=qrcode.constants.ERROR_CORRECT_M)
    code.add_data(url)
    code.make(fit=True)
    code.print_ascii(invert=True)
