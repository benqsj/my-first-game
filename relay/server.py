"""Vepxis relay: lets games in different homes play together.

One game hosts a room and gets a short code; the others join with it. Every
game keeps one WebSocket open here and the relay passes the game's own
packets between them (binary frames: a 4-byte little-endian peer id — the
target going in, the sender coming out — a channel byte, a mode byte, then the
payload). The host is peer 1; joiners get random ids. Nothing of the game is
understood here: it only forwards.

    PORT=8080 python server.py          # ws://host:8080/ws, GET /health
"""
import asyncio
import http
import json
import os
import random
import string
import struct

from websockets.asyncio.server import serve

MAX_PLAYERS = 4
CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
rooms = {}  # code -> {"peers": {id: ws}, "proto": int}


def new_code():
    while True:
        code = "".join(random.choice(CODE_CHARS) for _ in range(5))
        if code not in rooms:
            return code


async def send_json(ws, data):
    try:
        await ws.send(json.dumps(data))
    except Exception:
        pass


async def handler(ws):
    room = None
    me = 0
    code = ""
    try:
        hello = json.loads(await asyncio.wait_for(ws.recv(), 15))
        op = hello.get("op")
        if op == "host":
            code = new_code()
            room = {"peers": {1: ws}, "proto": hello.get("proto")}
            rooms[code] = room
            me = 1
            await send_json(ws, {"op": "hosted", "code": code, "id": 1})
        elif op == "join":
            code = str(hello.get("code", "")).strip().upper()
            room = rooms.get(code)
            if room is None:
                await send_json(ws, {"op": "error", "why": "no_room"})
                return
            if len(room["peers"]) >= MAX_PLAYERS:
                await send_json(ws, {"op": "error", "why": "full"})
                return
            if room.get("proto") is not None and hello.get("proto") != room.get("proto"):
                await send_json(ws, {"op": "error", "why": "version"})
                return
            me = random.randint(2, 2**31 - 1)
            while me in room["peers"]:
                me = random.randint(2, 2**31 - 1)
            room["peers"][me] = ws
            await send_json(ws, {"op": "joined", "id": me, "code": code})
            await send_json(room["peers"][1], {"op": "peer_in", "id": me})
        else:
            await send_json(ws, {"op": "error", "why": "bad_hello"})
            return

        async for msg in ws:
            if isinstance(msg, str):
                try:
                    data = json.loads(msg)
                except ValueError:
                    continue
                if data.get("op") == "kick" and me == 1:
                    gone = room["peers"].get(int(data.get("id", 0)))
                    if gone is not None:
                        await gone.close()
                continue
            if len(msg) < 6:
                continue
            target = struct.unpack_from("<i", msg, 0)[0]
            out = struct.pack("<i", me) + msg[4:]
            peers = room["peers"]
            if target > 0:
                to = peers.get(target)
                if to is not None:
                    try:
                        await to.send(out)
                    except Exception:
                        pass
            else:
                for pid, to in list(peers.items()):
                    if pid == me or (target < 0 and pid == -target):
                        continue
                    try:
                        await to.send(out)
                    except Exception:
                        pass
    except Exception:
        pass
    finally:
        if room is not None and me:
            room["peers"].pop(me, None)
            if me == 1:
                # the host gone: the room with it
                for pid, to in list(room["peers"].items()):
                    await send_json(to, {"op": "closed"})
                    try:
                        await to.close()
                    except Exception:
                        pass
                rooms.pop(code, None)
            else:
                host = room["peers"].get(1)
                if host is not None:
                    await send_json(host, {"op": "peer_out", "id": me})


def health(connection, request):
    if request.path != "/ws":
        return connection.respond(http.HTTPStatus.OK, "vepxis relay ok, %d rooms\n" % len(rooms))
    return None


async def main():
    port = int(os.environ.get("PORT", "8080"))
    async with serve(handler, "0.0.0.0", port, process_request=health,
                     max_size=2**22, ping_interval=20, ping_timeout=40) as server:
        print("vepxis relay on :%d" % port, flush=True)
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
