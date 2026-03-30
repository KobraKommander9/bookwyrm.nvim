local M = {}

--- Defines all Bookwyrm highlight groups with sensible defaults.
--- Users can override these in their colorscheme or after `setup()`.
function M.setup()
	-- Computed metadata header
	vim.api.nvim_set_hl(0, "BookwyrmMeta", { link = "Comment", default = true })

	-- Wiki-links
	vim.api.nvim_set_hl(0, "BookwyrmLink", { link = "Underlined", default = true })
	vim.api.nvim_set_hl(0, "BookwyrmLinkValid", { underline = true, fg = "#7aa2f7", default = true })
	vim.api.nvim_set_hl(0, "BookwyrmLinkBroken", { underline = true, fg = "#f7768e", default = true })

	-- Frontmatter
	vim.api.nvim_set_hl(0, "BookwyrmFrontmatterDelim", { link = "Comment", default = true })
	vim.api.nvim_set_hl(0, "BookwyrmFrontmatterKey", { bold = true, fg = "#bb9af7", default = true })

	-- Tags
	vim.api.nvim_set_hl(0, "BookwyrmTag", { bg = "#2d3f76", fg = "#7aa2f7", default = true })

	-- Headings (H1 brightest → H6 muted)
	vim.api.nvim_set_hl(0, "BookwyrmH1", { bold = true, fg = "#f7768e", default = true })
	vim.api.nvim_set_hl(0, "BookwyrmH2", { bold = true, fg = "#ff9e64", default = true })
	vim.api.nvim_set_hl(0, "BookwyrmH3", { fg = "#e0af68", default = true })
	vim.api.nvim_set_hl(0, "BookwyrmH4", { fg = "#9ece6a", default = true })
	vim.api.nvim_set_hl(0, "BookwyrmH5", { fg = "#73daca", default = true })
	vim.api.nvim_set_hl(0, "BookwyrmH6", { fg = "#565f89", default = true })
	vim.api.nvim_set_hl(0, "BookwyrmH1Rule", { fg = "#f7768e", default = true })

	-- Backlinks / graph hints
	vim.api.nvim_set_hl(0, "BookwyrmBacklinkCount", { link = "Comment", default = true })
	vim.api.nvim_set_hl(0, "BookwyrmOrphan", { link = "Comment", default = true })

	-- Timestamps
	vim.api.nvim_set_hl(0, "BookwyrmTimestamp", { link = "Comment", default = true })

	-- Tasks
	vim.api.nvim_set_hl(0, "BookwyrmTaskDone", { strikethrough = true, fg = "#565f89", default = true })

	-- Code blocks
	vim.api.nvim_set_hl(0, "BookwyrmCodeBlock", { bg = "#16161e", default = true })
	vim.api.nvim_set_hl(0, "BookwyrmCodeLang", { link = "Comment", default = true })
end

return M
