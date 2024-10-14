from abc import ABC, abstractmethod

class Faction(ABC):
    def __init__(self, name):
        self.name = name
        self.members = []

    @abstractmethod
    def add_member(self, npc):
        """Add an NPC to the faction."""
        pass

    @abstractmethod
    def remove_member(self, npc):
        """Remove an NPC from the faction."""
        pass

    @abstractmethod
    def promote_member(self, npc):
        """Promote an NPC in the faction."""
        pass

    @abstractmethod
    def demote_member(self, npc):
        """Demote an NPC in the faction."""
        pass

    def list_members(self):
        """List all members in the faction."""
        return [npc.name for npc in self.members]
