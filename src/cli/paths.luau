--!strict
--!optimize 2
--!native

local fs = require("@std/fs")

local paths = {}

function paths.parentDirectory(path: string): string?
	for i = #path, 1, -1 do
		if string.sub(path, i, i) == "/" then
			if i == 1 then
				return "/"
			end

			return string.sub(path, 1, i - 1)
		end
	end

	return nil
end

local function endsWith(value: string, suffix: string): boolean
	return #value >= #suffix and string.sub(value, #value - #suffix + 1) == suffix
end

function paths.join(root: string, path: string): string
	if root == "" or root == "." then
		return path
	end

	if root == "/" then
		return "/" .. path
	end

	if endsWith(root, "/") then
		return root .. path
	end

	return root .. "/" .. path
end

function paths.projectRootFromScript(scriptPath: string?): string
	if not scriptPath then
		return "."
	end

	local scriptDirectory = paths.parentDirectory(scriptPath)
	if not scriptDirectory then
		return "."
	end

	if scriptDirectory == "src" then
		return "."
	end

	if endsWith(scriptDirectory, "/src") then
		return paths.parentDirectory(scriptDirectory) or "."
	end

	return "."
end

function paths.resolveProjectPath(projectRoot: string, path: string): string
	local projectPath = paths.join(projectRoot, path)
	if fs.exists(projectPath) then
		return projectPath
	end

	if fs.exists(path) then
		return path
	end

	local parentPath = paths.join("..", path)
	if fs.exists(parentPath) then
		return parentPath
	end

	return projectPath
end

function paths.ensureParentDirectory(path: string)
	local parent = paths.parentDirectory(path)
	if parent and parent ~= "/" then
		fs.createDirectory(parent, { makeParents = true })
	end
end

return paths
