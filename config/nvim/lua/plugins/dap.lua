local map = function(mode, lhs, rhs, opts)
  require("util.map").map(mode, lhs, rhs, opts)
end

return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "theHamsta/nvim-dap-virtual-text",
      "jay-babu/mason-nvim-dap.nvim",
      "williamboman/mason.nvim",
    },
    cmd = {
      "DapContinue", "DapToggleBreakpoint", "DapStepOver", "DapStepInto",
      "DapStepOut", "DapTerminate", "DapShowLog",
    },
    keys = {
      { "<leader>jb", function() require("dap").toggle_breakpoint() end, desc = "DAP: toggle breakpoint" },
      { "<leader>jB", function() require("dap").set_breakpoint(vim.fn.input("Condition: ")) end, desc = "DAP: conditional BP" },
      { "<leader>jc", function() require("dap").continue() end, desc = "DAP: continue" },
      { "<leader>jo", function() require("dap").step_over() end, desc = "DAP: step over" },
      { "<leader>ji", function() require("dap").step_into() end, desc = "DAP: step into" },
      { "<leader>jO", function() require("dap").step_out() end, desc = "DAP: step out" },
      { "<leader>jt", function() require("dap").terminate() end, desc = "DAP: terminate" },
      { "<leader>jv", function() require("dapui").toggle() end, desc = "DAP: UI toggle" },
      { "<leader>jr", function() require("dap").repl.toggle() end, desc = "DAP: REPL" },
    },
    config = function()
      local dap, dapui = require("dap"), require("dapui")

      require("dapui").setup()
      require("nvim-dap-virtual-text").setup({ commented = true })

      -- UI auto-open/close
      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

      -- Signs
      local signs = { Breakpoint = "", BreakpointCondition = "", LogPoint = "", Stopped = "", BreakpointRejected = "" }
      for name, text in pairs(signs) do
        vim.fn.sign_define("Dap" .. name, { text = text, texthl = "Diagnostic" .. (name:find("Stopped") and "Warn" or "Error") })
      end

      -- Mason-managed adapters
      require("mason-nvim-dap").setup({
        ensure_installed = { "php-debug-adapter", "node-debug2-adapter", "chrome-debug-adapter" },
        automatic_installation = true,
        handlers = {},
      })

      -- PHP / Xdebug (port 9003, path-mapped)
      dap.adapters.php = {
        type = "executable",
        command = "node",
        args = { vim.fn.stdpath("data") .. "/mason/packages/php-debug-adapter/extension/out/phpDebug.js" },
      }

      dap.configurations.php = {
        {
          type = "php",
          request = "launch",
          name = "Xdebug: listen",
          port = 9003,
          pathMappings = {
            ["/var/www/html"] = "${workspaceFolder}",
            ["/app"] = "${workspaceFolder}",
          },
        },
      }

      -- Node (launch + attach :9229)
      dap.adapters.node2 = {
        type = "executable",
        command = "node",
        args = { vim.fn.stdpath("data") .. "/mason/packages/node-debug2-adapter/out/src/nodeDebug.js" },
      }

      dap.configurations.javascript = {
        {
          name = "Launch current file (node)",
          type = "node2",
          request = "launch",
          program = "${file}",
          cwd = vim.fn.getcwd(),
          sourceMaps = true,
          protocol = "inspector",
          console = "integratedTerminal",
        },
        {
          name = "Attach to :9229",
          type = "node2",
          request = "attach",
          port = 9229,
        },
      }
      dap.configurations.typescript = dap.configurations.javascript

      -- Chrome
      dap.adapters.chrome = {
        type = "executable",
        command = "node",
        args = { vim.fn.stdpath("data") .. "/mason/packages/chrome-debug-adapter/out/src/chromeDebug.js" },
      }

      dap.configurations.javascriptreact = {
        {
          name = "Chrome: :9222",
          type = "chrome",
          request = "attach",
          port = 9222,
          webRoot = "${workspaceFolder}",
          sourceMaps = true,
        },
      }
      dap.configurations.typescriptreact = dap.configurations.javascriptreact
    end,
  },
}
