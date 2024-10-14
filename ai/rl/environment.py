import numpy as np

class CombatEnvironment:
    def __init__(self):
        self.state = self.reset()
        self.action_space = [0, 1, 2]  # Example actions: 0: Attack, 1: Defend, 2: Flee
        self.state_space = np.array([100, 100])  # Example: Player and NPC health

    def reset(self):
        """Reset the environment to its initial state."""
        self.state = np.array([100, 100])  # Player and NPC start with full health
        return self.state

    def step(self, action):
        """Apply an action to the environment."""
        player_health, npc_health = self.state
        reward = 0
        done = False

        if action == 0:  # Attack
            npc_health -= 10
            reward = 10
        elif action == 1:  # Defend
            player_health -= 5
            reward = 5
        elif action == 2:  # Flee
            reward = -10
            done = True

        self.state = np.array([player_health, npc_health])

        if npc_health <= 0:
            done = True
            reward = 100  # Winning reward

        return self.state, reward, done

    def render(self):
        """Optional: Render the environment (text-based)."""
        print(f"Player Health: {self.state[0]}, NPC Health: {self.state[1]}")