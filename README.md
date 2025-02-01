# a-networked-2D-godot-game

A lightweight multiplayer game template built with Godot 4, perfect for getting started with networked games. Includes player synchronization, latency monitoring, and a basic physics-based movement system.

## Features

- Drop-in multiplayer support with host/join functionality
- Smooth player movement with client-side prediction
- Network quality monitoring and ping display
- Automatic player spawning and cleanup
- Fun random player nicknames
- LAN/local network support

## Getting Started

1. Clone the repository
2. Open the project in Godot 4
3. Run the game
4. Click "Host Game" to start a server
5. In another instance, click "Join Game" and enter the host's IP (or leave blank for localhost)

## How it Works

The framework handles the tricky parts of multiplayer game development:

- Server manages authoritative game state
- Clients use interpolation for smooth movement
- Built-in latency compensation
- Automatic peer discovery and connection management

## Network Settings

By default, the game runs on port 9999. You can modify network settings in `game_manager.gd`:

- Tick rate (default: 30 Hz)
- Interpolation delay (100ms)
- Ping interval (1 second)

## Contributing

Feel free to open issues or submit pull requests! The code is well-documented and modular, making it easy to extend or modify.

## License

MIT License - feel free to use this as a starting point for your own multiplayer games.

---

Built with 💚 using Godot 4
