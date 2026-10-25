#!/usr/bin/env python3
"""Uploads textures/*.png to Roblox and writes their ids into src/ThroneRoomBuilder.luau.

Uses the Open Cloud Assets API (Python standard library only). You need an API key from
the Creator Dashboard (Open Cloud > API Keys) with the Assets API's read and write
permissions, and the id of the user or group that will own the images.

    python3 tools/upload_textures.py --api-key KEY --user-id 12345
    python3 tools/upload_textures.py --api-key KEY --group-id 67890
    python3 tools/upload_textures.py --dry-run          # list what would be uploaded

The key can also come from the ROBLOX_API_KEY environment variable. Ids are saved after
each upload, so an interrupted run picks up where it stopped; --force uploads again.

Open Cloud uploads images as Decals. Textures need the image inside the decal, so the
script asks the asset delivery API for it and writes rbxassetid://<image id>. If that
lookup isn't allowed for your key, it writes the bare decal id instead, and the builder
looks the image up itself when you run it in Studio.
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEXTURES = ROOT / "textures"
BUILDER = ROOT / "src" / "ThroneRoomBuilder.luau"
API = os.environ.get("ROBLOX_APIS", "https://apis.roblox.com")


def request(method, url, key, body=None, headers=None, retries=5):
    headers = dict(headers or {})
    headers["x-api-key"] = key
    for attempt in range(retries):
        req = urllib.request.Request(url, data=body, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return resp.read()
        except urllib.error.HTTPError as err:
            if err.code == 429 or err.code >= 500:
                wait = float(err.headers.get("Retry-After") or 2 ** attempt)
                print(f"    {err.code} from Roblox, retrying in {wait:.0f}s")
                time.sleep(wait)
                continue
            detail = err.read().decode("utf-8", "replace")
            raise RuntimeError(f"{method} {url} failed with {err.code}: {detail}") from None
    raise RuntimeError(f"{method} {url} kept failing; try again later")


def multipart(fields, file_field, filename, content, content_type):
    boundary = uuid.uuid4().hex
    parts = []
    for name, value in fields.items():
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
    parts.append(
        f'--{boundary}\r\nContent-Disposition: form-data; name="{file_field}"; filename="{filename}"\r\n'
        f"Content-Type: {content_type}\r\n\r\n".encode()
        + content
        + b"\r\n"
    )
    parts.append(f"--{boundary}--\r\n".encode())
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def upload(path, key, creator):
    meta = {
        "assetType": "Decal",
        "displayName": f"ThroneRoom {path.stem}",
        "description": "Texture for the Asgore's throne room build.",
        "creationContext": {"creator": creator},
    }
    body, ctype = multipart({"request": json.dumps(meta)}, "fileContent", path.name, path.read_bytes(), "image/png")
    op = json.loads(request("POST", f"{API}/assets/v1/assets", key, body, {"Content-Type": ctype}))
    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(1.5)
        op = json.loads(request("GET", f"{API}/assets/v1/{op['path']}", key))
    if not op.get("done"):
        raise RuntimeError(f"{path.name}: Roblox is still processing the upload; run the script again later")
    if "error" in op:
        raise RuntimeError(f"{path.name}: {op['error']}")
    return str(op["response"]["assetId"])


def image_inside(decal_id, key):
    """The image id inside an uploaded decal, or None if it can't be looked up."""
    try:
        info = json.loads(request("GET", f"{API}/asset-delivery-api/v1/assetId/{decal_id}", key, retries=2))
        with urllib.request.urlopen(info["location"], timeout=60) as resp:
            content = resp.read().decode("latin-1")
    except (RuntimeError, KeyError, urllib.error.URLError, ValueError):
        return None
    match = re.search(r"(?:asset/\?id=|rbxassetid://)(\d+)", content)
    return match.group(1) if match else None


def read_ids():
    text = BUILDER.read_text()
    block = re.search(r"-- BEGIN TEXTURE IDS\n(.*?)-- END TEXTURE IDS", text, re.S)
    if not block:
        sys.exit(f"Couldn't find the TEXTURE_IDS block in {BUILDER}")
    return dict(re.findall(r'^\t(\w+) = "([^"]*)",$', block.group(1), re.M))


def write_id(name, value):
    text = BUILDER.read_text()
    pattern = re.compile(rf'^(\t{re.escape(name)} = )"[^"]*",$', re.M)
    if not pattern.search(text):
        sys.exit(f"{name} isn't in the TEXTURE_IDS block of {BUILDER}")
    BUILDER.write_text(pattern.sub(lambda m: f'{m.group(1)}"{value}",', text, count=1))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--api-key", default=os.environ.get("ROBLOX_API_KEY"))
    owner = parser.add_mutually_exclusive_group()
    owner.add_argument("--user-id")
    owner.add_argument("--group-id")
    parser.add_argument("--force", action="store_true", help="upload textures that already have ids")
    parser.add_argument("--dry-run", action="store_true", help="only list what would be uploaded")
    parser.add_argument("names", nargs="*", help="texture names (default: all of textures/)")
    args = parser.parse_args()

    ids = read_ids()
    names = args.names or sorted(p.stem for p in TEXTURES.glob("*.png"))
    todo = [n for n in names if args.force or not ids.get(n)]
    missing = [n for n in todo if n not in ids]
    if missing:
        sys.exit("Not in the builder's TEXTURE_IDS: " + ", ".join(missing))
    print(f"{len(todo)} of {len(names)} textures to upload")
    if args.dry_run or not todo:
        for n in todo:
            print("  " + n)
        return
    if not args.api_key or not (args.user_id or args.group_id):
        sys.exit("Give --api-key (or ROBLOX_API_KEY) and --user-id or --group-id")
    creator = {"userId": str(args.user_id)} if args.user_id else {"groupId": str(args.group_id)}

    unresolved = 0
    for n in todo:
        print(f"  {n}: uploading", flush=True)
        decal = upload(TEXTURES / f"{n}.png", args.api_key, creator)
        image = image_inside(decal, args.api_key)
        if image:
            write_id(n, f"rbxassetid://{image}")
            print(f"  {n}: image {image}")
        else:
            write_id(n, decal)
            unresolved += 1
            print(f"  {n}: decal {decal} (Studio will look up its image)")
    print(f"Saved the ids in {BUILDER.relative_to(ROOT)}.")
    if unresolved:
        print("Some ids are decals; build in Studio's command bar so they can be looked up.")


if __name__ == "__main__":
    main()
