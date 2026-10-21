# Vepxis relay

Lets games in different homes play together: one hosts and gets a 5-letter
code, the others join with it. Every game keeps one WebSocket here and the
relay forwards their packets (it understands nothing of the game).

    pip install -r requirements.txt
    PORT=8080 python server.py        # ws://host:8080/ws ; GET / -> health

Docker: `docker build -t vepxis-relay . && docker run -p 8080:8080 vepxis-relay`.
The game's address for it is `Net.RELAY_URL` (`--relay <url>` overrides it
for a test).
