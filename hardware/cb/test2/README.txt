This second testbench tries to request the creation of the same new connection
twice in a row. 

The expected results is that :
	- the first connection request goes through and the ID 120 is returned. 
	- the second connection doesn't go through and an ERR_FOUND is
	  returned.
