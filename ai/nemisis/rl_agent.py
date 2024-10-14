import numpy as np

class RLAgent:
    def __init__(self, state_size, action_size):
        self.state_size = state_size
        self.action_size = action_size
        self.q_table = np.zeros((state_size, action_size))
        self.learning_rate = 0.1
        self.discount_factor = 0.95
        self.epsilon = 1.0  # Exploration rate

    def choose_action(self, state):
        """Choose an action using epsilon-greedy."""
        if np.random.rand() <= self.epsilon:
            return np.random.randint(self.action_size)  # Random action
        else:
            return np.argmax(self.q_table[state])  # Best known action

    def learn(self, state, action, reward, next_state):
        """Update Q-table with new knowledge."""
        best_next_action = np.argmax(self.q_table[next_state])
        q_value = self.q_table[state, action]
        new_q_value = (1 - self.learning_rate) * q_value + \
                      self.learning_rate * (reward + self.discount_factor * self.q_table[next_state, best_next_action])
        self.q_table[state, action] = new_q_value

        # Optionally decay exploration rate
        if self.epsilon > 0.01:
            self.epsilon *= 0.995
