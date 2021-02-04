

function ksum (buffer, n)
	buffer = (buffer << 7) | (buffer >> 32-7)
	buffer = buffer + n
	buffer = buffer & 0xffffffff
	return buffer
end

function ksum_text (text)
	local buffer = 0
	for i = 1, text:len() do
		buffer = ksum(buffer, text:byte(i))
	end
	return buffer
end

