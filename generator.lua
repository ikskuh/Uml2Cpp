local input = io.open("example.txt", "r")

-- trim whitespace from both ends of string
local function trim(s)
	if s == nil then return nil end
	return s:find'^%s*$' and '' or s:match'^%s*(.*%S)'
end

local function tablelength(T)
	if T == nil then return 0 end
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

local function readLine()
	local str = trim(input:read("*line"))
	if str == nil then return nil end
	local comments = { }
	local index = 1
	while str == "" or string.match(str, "(%%%%)") ~= nil do
		local head, comment = string.match(str, "(%%%%)(.*)")
		if head ~= nil then
			comments[index] = trim(comment)
			index = index + 1
		end
		str = trim(input:read("*line"))
		if str == nil then return nil end
	end
	return str, comments
end

local line, currentComment = readLine()
while true do
	if line == nil then
		break
	end
	
	local className, baseClass = string.match(line, "(%w+) ?:? ?(%w*)")
	local classComment = currentComment
	if baseClass == "" then baseClass = nil end
	if className == nil then error("fail" .. line) end 
	
	print(className)
	
	local methods = { }
	while true do
		line, currentComment = readLine()
		if line == nil then
			break
		end		
		
		-- + loadFile(fileName : QString) : HDF5File
		local vis, name, args, ret = string.match(line, "%s*(+?-?#?) (%w+)%((.*)%) ?:? ?(.*)")
		
		if vis == nil then
			break
		end
		local argTable = { }
		
		for n,t in string.gmatch(args, "(%w+) ?: ?(%w+)") do
			argTable[n] = t
		end
		
		methods[name] = {
			name = name,
			visibility = vis,
			returnValue = ret,
			args = argTable,
			comments = currentComment
		}
	end
	
	table.sort(methods, function (a, b) return a.visibility < b.visibility end)
	
	local header = io.open("src/"..className..".hpp", "w")
	local source = io.open("src/"..className..".cpp", "w")
	
	if header == nil then
		print("!",className,"!");
		error("Header file could not be created.")
	end
	
	header:write("#pragma once\n")
	header:write("\n")
	header:write("#include <QObject>\n")
	header:write("\n")
	header:write("namespace voxie {\n")
	header:write("\tnamespace gui {\n")	
	
	if tablelength(classComment) > 0 then
		header:write("\n")
		header:write("\t/**\n")
		for i,v in pairs(classComment) do
			header:write("\t * " .. v .. "\n")
		end
		header:write("\t */\n")
	end
	
	header:write("\tclass "..className.." : public ".. (baseClass or "QObject") .." {\n")
	header:write("\t\tQ_OBJECT\n");
	header:write("\tpublic:\n");
	header:write("\t\t"..className.."();\n");
	header:write("\t\t~"..className.."();\n");
	header:write("\n");
	
	local currentVis = "+"
	for _, method in pairs(methods) do
		if currentVis ~= method.visibility then
			currentVis = method.visibility
			if currentVis == "+" then
				header:write("\tpublic:\n")
			elseif currentVis == "-" then
				header:write("\tprivate:\n")
			elseif currentVis == "#" then
				header:write("\tprotected:\n")
			else
				error("failed")
			end
		end
		
		if tablelength(method.comments) > 0 then
			header:write("\n")
			header:write("\t\t/**\n")
			for i,v in pairs(method.comments) do
				header:write("\t\t * " .. v .. "\n")
			end
			header:write("\t\t */\n")
		end
		
		header:write("\t\tQ_INVOKABLE ")
		if method.returnValue ~= nil and method.returnValue ~= "" then
			header:write(method.returnValue)
		else
			header:write("void")
		end
		header:write(" ")
		header:write(method.name)
		header:write("(")
		
		local last = nil
		for n, t in pairs(method.args) do
			if last ~= nil then
				header:write(", ")
			end
			header:write(t .. " " .. n)
			last = n
		end
		
		header:write(");\n")
	end
	
	header:write("\t}\n}\n")
	
	source:write("#include <"..className..".hpp>\n")
	source:write("\n")
	source:write("using namespace voxie::gui;\n")
	source:write("\n")
	source:write(className.."::"..className.."()\n")
	source:write("{\n")
	source:write("}\n")
	source:write("\n")
	source:write(className.."::~"..className.."()\n")
	source:write("{\n")
	source:write("}\n")
	source:write("\n")
	
	for _, method in pairs(methods) do
		if method.returnValue ~= nil and method.returnValue ~= "" then
			source:write(method.returnValue)
		else
			source:write("void")
		end
		source:write(" ")
		source:write(className)
		source:write("::")
		source:write(method.name)
		source:write("(")
		
		local last = nil
		for n, t in pairs(method.args) do
			if last ~= nil then
				source:write(", ")
			end
			source:write(t .. " " .. n)
			last = n
		end
		
		source:write(")\n")
		source:write("{\n")
		source:write("}\n")
		source:write("\n")
	end
	
	header:close()
	source:close()

end

input:close()