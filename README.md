# ReNemiSys

## Introduction

**ReNemiSys** is an innovative game project that blends reinforcement learning (RL) and a nemesis system inspired by the AI architecture seen in *Shadow of Mordor* and the looping narrative structure from the anime *Re:Zero*. The core idea is to create a dynamic, evolving hierarchy of NPC enemies who learn and adapt to the player’s strategies, growing stronger after each encounter. Through the use of RL, the NPCs will become increasingly intelligent and challenging, remembering past interactions and evolving both in terms of skill and behavior.

This project is focused on building robust game logic, leveraging cutting-edge AI to ensure that no two encounters are the same. The nemesis system will ensure NPCs are not static but instead adapt, evolve, and seek revenge in future encounters, providing an ongoing and evolving challenge for the player.

## Project Goals

The goals of **ReNemiSys** include:
1. **Dynamic Nemesis System**: Implement a nemesis hierarchy where NPCs evolve based on interactions with the player. NPCs will move up in rank, develop new strengths, and remember past encounters.
2. **Reinforcement Learning (RL)-Driven NPCs**: Use RL algorithms to drive the decision-making and combat behaviors of nemesis characters. Each NPC will learn and adapt to the player's strategies, becoming more formidable over time.
3. **Looping Progression Inspired by *Re:Zero***: Introduce a game loop mechanic where, after key events (like player death or major defeats), the game resets. NPCs and the nemesis hierarchy will retain memories of past encounters, allowing them to evolve and adapt with each loop.
4. **Adaptive Combat System**: Develop an RL-based combat system where NPCs learn from each battle with the player, modifying their tactics, moves, and approaches based on prior encounters.
5. **Hierarchy and Faction Management**: Build a hierarchical structure where NPCs belong to factions and ranks, with promotions and demotions occurring based on in-game events. The hierarchy dynamically reshuffles based on player interactions.
6. **Scalable AI and Learning**: Ensure that the AI and learning processes are scalable, allowing for increasingly complex and strategic behaviors in the nemesis characters as they evolve through multiple loops.

## Key Features
- **Evolving Nemesis System**: NPCs will not only get stronger, but they will develop new behaviors and traits over time, making them more dangerous with every encounter.
- **Memory of Past Encounters**: NPCs will remember how the player defeated them and use that information to adapt their strategies in future battles.
- **Reinforcement Learning for Combat**: Using RL, the combat AI will learn from each interaction, ensuring that NPCs dynamically adjust their combat style.
- **Procedural Hierarchy**: As the player defeats enemies, the NPCs evolve, promoting within the nemesis hierarchy, which changes the power dynamics of the world.

## Tech Stack
- **Godot Engine**: Lightweight game engine to focus on core game logic and prototyping.
- **Python (PyTorch, Stable-Baselines3)**: For reinforcement learning, using state-of-the-art libraries to train NPCs.
- **SQLite/JSON**: For storing NPC data and tracking their evolution and hierarchy.
- **Flask/FastAPI**: Optional backend to serve RL models and nemesis state if separated from the game logic.

## Development Roadmap
1. **Phase 1**: Prototype the core game loop and nemesis evolution system.
2. **Phase 2**: Integrate reinforcement learning into NPC combat behavior.
3. **Phase 3**: Build out the hierarchy and faction management system to handle nemesis promotions and demotions.
4. **Phase 4**: Test, balance, and refine AI behaviors to ensure fair and challenging gameplay.
5. **Phase 5**: Add additional features, polish, and expand the game world.

## How to Get Started
- TBD
