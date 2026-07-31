# Context
I am building a 3D Action-RPG game in Godot 4.x, set in a medieval fantasy world based on the epic poem "The Knight in the Panther's Skin". I am an experienced software developer using a terminal-based workflow.

# Current Task: Third-Person Placeholder Controller (Greyboxing)
The 3D artists are currently working on the Blender models (knights, armor, etc.). I need a robust placeholder character to test third-person movement and combat mechanics mechanics.

# Requirements
1. Base the player on `CharacterBody3D` with a simple `MeshInstance3D` (Capsule) as a placeholder.
2. Movement MUST be Third-Person: WASD movement should be relative to the camera's current rotation.
3. Camera Setup: Implement a `SpringArm3D` and `Camera3D` setup for a standard third-person follow camera, controlled by mouse movement.
4. Mechanics: Include gravity, jumping (Spacebar), and a placeholder function for a "dash" or "dodge roll" (Shift) which is crucial for this combat style.

# Output Request
1. The exact Node structure required for this Third-Person Player scene.
2. The complete, production-ready GDScript for the Player character.
3. Instructions on setting up the Input Map for these specific actions.