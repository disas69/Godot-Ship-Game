Use official Godot code style
Prefer simple solutions, but keep optimization in mind where needed
Use existing systems and patterns:
- AudioManager for playing audio
- VFXManager for spawning vfx
- ObjectPool for spawning many objects effectively
Don't check for null absolutely everything, only check and log warning where needed
