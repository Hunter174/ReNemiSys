class FactionManager:
    def __init__(self):
        self.factions = {}

    def create_faction(self, faction_type, faction_name):
        """Create a new faction of a specific type."""
        if faction_name not in self.factions:
            self.factions[faction_name] = faction_type(faction_name)
            print(f"Faction {faction_name} has been created!")
        else:
            print(f"Faction {faction_name} already exists!")

    def add_npc_to_faction(self, faction_name, npc):
        """Add an NPC to a specific faction."""
        faction = self.factions.get(faction_name)
        if faction:
            faction.add_member(npc)
        else:
            print(f"Faction {faction_name} does not exist!")

    def promote_npc_in_faction(self, faction_name, npc):
        """Promote an NPC within their faction."""
        faction = self.factions.get(faction_name)
        if faction:
            faction.promote_member(npc)
        else:
            print(f"Faction {faction_name} does not exist!")

    def demote_npc_in_faction(self, faction_name, npc):
        """Demote an NPC within their faction."""
        faction = self.factions.get(faction_name)
        if faction:
            faction.demote_member(npc)
        else:
            print(f"Faction {faction_name} does not exist!")

    def list_faction_members(self, faction_name):
        """List all members of a specific faction."""
        faction = self.factions.get(faction_name)
        if faction:
            return faction.list_members()
        else:
            print(f"Faction {faction_name} does not exist!")
            return []

    def faction_stats(self):
        """Print stats for all factions."""
        for faction, instance in self.factions.items():
            print(f"Faction: {faction}, Members: {len(instance.members)}")