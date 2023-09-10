--[[
	Poor checksum function inspired by BSD checksum.
	https://en.wikipedia.org/wiki/BSD_checksum
	Each step, the buffer is rotated left by seven bits
	and then the new byte is added. Any overflow is discarded.
]]--

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
