#!/usr/bin/env python3
"""Throwaway qa boards on the Convex dev deployment for the gate tests.

  python3 .revyl/scripts/qa_board.py create
      Makes a shared board owned by an invented qa- guest, adds three notes for the
      pipeline to place (tonight, this weekend, someday), and prints JSON with the
      invite code, board id, board name, guest id and each note's client id.
  python3 .revyl/scripts/qa_board.py pin <boardId> <clientId> [true|false]
      Pins or unpins a drop as the other person, for gate-two-phone-live.
  python3 .revyl/scripts/qa_board.py list <boardId>
      Prints the board's drops with title, zone, pinned and previousZone.

Only public functions are called, and never as a seed- person.
"""
import json
import sys
import time
import urllib.request
import uuid

DEPLOYMENT = "https://adorable-coyote-696.convex.cloud"
NOTES = ["tacos at la taqueria tonight at 8pm", "picnic this saturday", "learn to surf someday"]


def call(kind, path, args):
    request = urllib.request.Request(
        f"{DEPLOYMENT}/api/{kind}",
        data=json.dumps({"path": path, "args": args, "format": "json"}).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        body = json.load(response)
    if body.get("status") != "success":
        sys.exit(f"{path} failed: {body.get('errorMessage')}")
    return body["value"]


def create():
    tag = uuid.uuid4().hex[:6]
    person = f"qa-{tag}"
    board = call("mutation", "boards:create", {
        "personId": person, "boardId": f"qa-{tag}-board", "name": f"qa {tag}", "personName": "qa guest",
    })
    drops = {}
    for words in NOTES:
        client = str(uuid.uuid4()).upper()
        call("mutation", "drops:submit", {
            "boardId": board["boardId"], "personId": person, "clientId": client, "kind": "text", "text": words,
            "url": None, "imageIds": None, "capturedAt": time.time() * 1000, "utcOffsetMinutes": -480,
            "latitude": None, "longitude": None, "hints": None,
        })
        drops[words] = client
    print(json.dumps({"code": board["inviteCode"], "boardId": board["boardId"], "name": board["name"],
                      "personId": person, "drops": drops}, indent=2))


def show(board_id):
    for drop in call("query", "drops:list", {"boardId": board_id}):
        title = (drop.get("extraction") or {}).get("title") or drop.get("text") or drop.get("url")
        print(json.dumps({"clientId": drop.get("clientId"), "title": title, "zone": drop.get("zone"),
                          "pinned": drop.get("pinned"), "previousZone": drop.get("previousZone")}))


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "create":
        create()
    elif command == "pin" and len(sys.argv) >= 4:
        pinned = len(sys.argv) < 5 or sys.argv[4] != "false"
        call("mutation", "drops:setPinned", {"boardId": sys.argv[2], "clientId": sys.argv[3], "pinned": pinned})
    elif command == "list" and len(sys.argv) == 3:
        show(sys.argv[2])
    else:
        sys.exit(__doc__)
