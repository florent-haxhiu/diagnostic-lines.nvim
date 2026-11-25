NVIM ?= nvim
FILE ?=

.PHONY: test deps clean

deps: deps/mini.test

deps/mini.test:
	@mkdir -p deps
	git clone --depth 1 https://github.com/echasnovski/mini.test deps/mini.test

test: deps
ifeq ($(FILE),)
	$(NVIM) --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run()" -c "cquit 1"
else
	$(NVIM) --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')" -c "cquit 1"
endif

clean:
	rm -rf deps
