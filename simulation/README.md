# Simulating boats: The Archipelago 
This folder is divided into two Godot projects: One for client-side mobile connection, and one for server-side graphics simulation. These should communicate with each other with _serverside authority_ handling the entire game state. Hell, we might not even need traditional game dev networking because of how wacky this project is.  Please check [godot_instructions.md](godot_instructions.md) for further instructions

## Goals
- Boats should follow routes 
- Boats should avoid collisions while staying on-route 
- Boats should be networked to allow mobile devices to interact with individual boats. 


## Dependencies 
- Godot 4.7 with .NET extension
