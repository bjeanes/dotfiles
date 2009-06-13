function cdgem --description 'cd to a gems directory'
	cd (dirname (gem which $argv)[2])

end
