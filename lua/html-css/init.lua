local Source = {}
local cmp_config = require("cmp.config")
local utils = require("html-css.utils")

---@param file_extensions string[]
---@return string[]
local get_cwd_files = function(file_extensions)
	---@type string[]
	local stylesheet_paths = {}
	for _, ft in ipairs(file_extensions) do
		vim.tbl_extend(
			"error",
			stylesheet_paths,
			vim.split(vim.fn.globpath(vim.fn.getcwd(), "**/*." .. ft), "\n")
		)
	end
	return stylesheet_paths
end

-- TODO: set up file event watcher to update this regularly

function Source:before_init()
	local files_to_load = self.user_config.option.style_sheets or {}
	local css_file_extensions = self.user_config.option.css_file_extensions
		or { "css", "sass", "scss", "less" }

	if self.user_config.option.should_load_cwd_files then
		vim.tbl_extend("error", files_to_load, get_cwd_files(css_file_extensions))
	end

	local style_sheets_classes = require("html-css.style_sheets").init(files_to_load)
	if not style_sheets_classes then
		vim.notify("nvim-html-css can't find style_sheets config.", vim.log.levels.ERROR)
		return
	end

	vim.notify("Your remote styles get set, you can use them.")
	for _, class in ipairs(style_sheets_classes) do
		table.insert(self.items, class)
	end
end

function Source:setup()
	require("cmp").register_source(self.source_name, Source)
end

function Source:new()
	self.source_name = "html-css"
	self.cache = {}
	self.items = {}

	-- reading user config
	self.user_config = cmp_config.get_source_config(self.source_name) or {}
	self.user_config.option = self.user_config.option or {}

	self:before_init() -- init the plugin on start

	return self
end

function Source:is_available()
	if not next(self.user_config.option) then
		return false
	end

	if not vim.tbl_contains(self.user_config.option.file_types, vim.bo.filetype) then
		return false
	end

	local line = vim.api.nvim_get_current_line()

	if line:match('class%s-=%s-".-"') or line:match('className%s-=%s-".-"') then
		local cursor_pos = vim.api.nvim_win_get_cursor(0)
		local class_start_pos, class_end_pos = line:find('class%s-=%s-".-"')
		local className_start_pos, className_end_pos = line:find('className%s-=%s-".-"')

		if
			(
				class_start_pos
				and class_end_pos
				and cursor_pos[2] > class_start_pos
				and cursor_pos[2] <= class_end_pos
			)
			or (
				className_start_pos
				and className_end_pos
				and cursor_pos[2] > className_start_pos
				and cursor_pos[2] <= className_end_pos
			)
		then
			return true
		else
			return false
		end
	end
end

function Source:complete(_, callback)
	if self.cache.items ~= nil then
		local items = utils.remove_duplicate_tables_by_label(self.cache.items)
		callback({ items = items, isIncomplete = false })
	else
		self:before_init()
		local items = utils.remove_duplicate_tables_by_label(self.items)
		callback({ items = items, isIncomplete = false })
		self.cache.items = self.items
	end
end

return Source:new()
