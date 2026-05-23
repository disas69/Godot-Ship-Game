Use official Godot code style
Prefer simple solutions, but keep optimization in mind where needed
Use existing systems and patterns:
- AudioManager for playing audio
- VFXManager for spawning vfx
- ObjectPool for spawning many objects effectively
Use Node's actual type when it's known instead of using base Node methods such as set, connect, etc.
Don't check for null absolutely everything, only check and log warning where needed
