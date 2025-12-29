# Entity Systems: Plants, Tools, & Items

## The Entity Component System
Entities are built using composition. Instead of a deep inheritance tree, we attach nodes (Components) to entities to give them behavior.

### Core Components
*   **GridOccupantComponent**: Automatically registers the entity with `GridState` when it enters the tree. This ensures the grid knows "There is a plant at (3, 4)".
*   **SaveComponent**: Handles serialization. It listens for save requests and packages the entity's state (e.g., `days_grown`) into a dictionary.
*   **RayCellComponent**: Used by the Player to determine which grid cell they are facing.

## Plants
**File:** `entities/plants/plant.gd`

Plants are dynamic entities that grow over time.

### PlantData (Resource)
The definition of a plant is a Resource (`PlantData`).
*   **Growth Stages**: How many stages (Seed -> Sprout -> Mature).
*   **Atlas Generation**: Includes a `@tool` script that automatically slices a sprite sheet into `SpriteFrames` for the animations. This simplifies the workflow for adding new crops.

### Growth Logic
1.  **Day Start**: `GameManager` triggers the day change.
2.  **Notification**: `GridState` notifies the Plant via `on_day_passed(is_wet)`.
3.  **State Machine**: The Plant's internal State Machine (`Seed`, `Growing`, `Mature`) decides if it should advance to the next stage based on water presence.

## Tools
**File:** `entities/tools/tool.gd`

The visual representation of the tool held by the player (The "HandTool").

### Visual Feedback
The `HandTool` handles the "Juice" of using a tool:
*   **Swish Animation**: Plays a sprite animation (slash, swipe) based on `ToolData.swish_type`.
*   **Orientation**: Smartly rotates and skews the animation sprite based on the player's facing direction (Front, Back, Left, Right) to fake 3D depth.

### ToolData
Defines the capabilities of a tool:
*   `energy_cost`: How much stamina to use.
*   `area_effect`: Dimensions of the effect (1x1, 3x3).
*   `tool_type`: Category (HOE, WATERING_CAN, AXE).

## TODO Alignment
The current codebase has some technical debt regarding interaction logic:

*   **Refactor Interaction**: Currently, tools often use "duck typing" (checking if a method exists) or hardcoded checks in the `ToolManager`.
    *   *Goal*: Move to `InteractableComponent`. Entities that can be chopped should have a `ChoppableComponent` rather than the Axe checking for `Tree` class.
*   **Standardize Saveable Interface**: We need to enforce `SaveComponent` usage to avoid the current mix of `get_save_state()` checks.

