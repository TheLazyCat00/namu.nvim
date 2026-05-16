-- Compatibility module for plugin managers that infer `main = "namu.nvim"`.
-- `require("namu.nvim")` maps to `lua/namu/nvim.lua`, so forward to `require("namu")`.
return require("namu")

