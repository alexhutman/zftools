class ChainedList:
    
    def __init__(self):
    	self.dict_for_items = {};
    
    def __contains__(self, item_to_check):
        return item_to_check in self.dict_for_items
    
    def add_with_parent_and_edge(self, new_item, parent_of_item, edge):
        if new_item not in self:
            # add the item to the dict and store its parent/edge
            self.dict_for_items.update([(new_item, (parent_of_item, edge))])
        else:
            # throw error if item is not currently stored
            raise ValueError('ChainedList: Tried to store item that was stored alreadyS')
            return
        
    def get_parent(self, item):
        if item in self:
        	item_parent_and_edge_tuple = self.dict_for_items.get(item)
        	return item_parent_and_edge_tuple
        else:
            # throw error if item is not currently stored
            raise ValueError('ChainedList: Asked for parent of item that was not stored')
            return None
