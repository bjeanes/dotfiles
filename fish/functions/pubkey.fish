function pubkey --description 'copy ssh keys to clipboard'
	cat ~/.ssh/*.pub | pbcopy

end
