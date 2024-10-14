class NPC:
    def __init__(self, name, level=1):
        self.name = name
        self.level = level
        self.traits = {
            "strength": 10,
            "speed": 5,
            "intelligence": 5,
            "agility": 5
        }
        self.memory = []

    def evolve(self, encounters):
        """Evolves NPC based on past encounters."""
        for encounter in encounters:
            self.memory.append(encounter)
            # Example evolution logic based on past encounters
            if encounter == "lost_fight":
                self.traits["strength"] += 2
            elif encounter == "won_fight":
                self.traits["intelligence"] += 2

    def display_stats(self):
        """Print NPC's current stats."""
        print(f"NPC {self.name} Stats: {self.traits}")

    def remember_encounters(self):
        """Displays NPC's memory of encounters."""
        print(f"Memory of {self.name}: {self.memory}")
