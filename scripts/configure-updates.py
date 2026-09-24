"""Apply checked-in release metadata without shell/XML interpolation."""
import base64
import json
from pathlib import Path
import plistlib
import re
import sys
from urllib.parse import urlparse

root = Path(__file__).resolve().parents[1]
config = json.loads((root / "config/updates.json").read_text())
assert re.fullmatch(r"\d+\.\d+\.\d+", config["version"]), "Expected major.minor.patch version"
assert re.fullmatch(r"[1-9]\d*", config["build"]), "Expected positive build number"
assert len(base64.b64decode(config["publicKey"], validate=True)) == 32, "Invalid public key"
url = urlparse(config["feedURL"])
assert url.scheme == "https" and url.hostname and not url.username, "Expected HTTPS feed URL"
path = Path(sys.argv[1])
with path.open("rb") as file:
    info = plistlib.load(file)
info.update({
    "CFBundleShortVersionString": config["version"],
    "CFBundleVersion": config["build"],
    "SUFeedURL": config["feedURL"],
    "SUPublicEDKey": config["publicKey"],
    "SUEnableAutomaticChecks": True,
    "SUAutomaticallyUpdate": False,
    "SUAllowsAutomaticUpdates": False,
    "SUSendProfileInfo": False,
    "SUVerifyUpdateBeforeExtraction": True,
})
with path.open("wb") as file:
    plistlib.dump(info, file)
