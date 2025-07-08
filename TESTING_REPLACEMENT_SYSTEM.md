# Testing the Replacement System

## Quick Test Instructions

### Method 1: Test Within Course1.tscn (Recommended)

1. **Open Course1.tscn** in Godot
2. **Add the test script** as a child node:
   - Right-click on the root node
   - Add Child Node → Node
   - Attach the script `test_replacement_system.gd`
3. **Run the scene** (F5)
4. **Check the console output** for test results

### Method 2: Manual Testing

1. **Start a new game** (run Course1.tscn)
2. **Fill your bag** with items:
   - Complete holes to get rewards
   - Visit the shop to buy items
   - Keep adding items until the bag is full
3. **Try to add more items**:
   - Complete another hole and try to select a reward
   - Visit the shop and try to purchase an item
   - The replacement dialog should appear

## Expected Behavior

### When Bag is Full:
- **Reward Selection**: Shows replacement dialog instead of adding item directly
- **Shop Purchase**: Shows replacement dialog instead of completing purchase
- **Suitcase**: Shows replacement dialog when opening suitcases

### Replacement Process:
1. Dialog appears explaining the replacement process
2. Bag inventory opens in replacement mode
3. Click on an item to replace
4. Confirmation dialog shows old vs new item
5. Confirm replacement to complete the process

## Debug Information

The test script will show:
- Current bag level and slot counts
- Number of items in each category
- Whether slots are available for new items
- Whether replacement system would trigger

## Troubleshooting

### "Bag not found" Error:
- Make sure you're running within Course1.tscn
- Check that UILayer/Bag exists in the scene

### "Managers not found" Error:
- Ensure EquipmentManager, CurrentDeckManager, and DeckManager are present
- These are created automatically when Course1.tscn loads

### Test not working:
- Verify you're in the correct scene context
- Check that all required nodes are present
- Look for any error messages in the console 