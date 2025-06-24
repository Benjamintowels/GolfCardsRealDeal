
extends BaseObstacle

var blocks_movement := true  # Trees block by default; water might not

func blocks(): 
	return blocks_movement
