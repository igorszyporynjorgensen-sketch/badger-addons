---@meta
-- Dev-only type stubs so lua-language-server recognizes the busted test DSL (describe / it /
-- assert.*) in *_spec.lua files. NOT runtime code, NOT shipped, NOT linted — this dir sits outside
-- every Nx project, so stylua/luacheck/busted never touch it. Referenced by .luarc.json
-- (workspace.library). See WO-005-IJ.

function describe(name, fn) end
function it(name, fn) end
function before_each(fn) end
function after_each(fn) end
function setup(fn) end
function teardown(fn) end
function pending(name, fn) end
function finally(fn) end
function spy(target) end
function stub(object, key) end
function mock(object, useStub) end

---luassert — busted replaces the built-in `assert` with a callable table carrying matcher methods.
---@class luassert
---@overload fun(value: any, message?: any): any
local luassert = {}

function luassert.same(expected, actual, message) end
function luassert.equal(expected, actual, message) end
function luassert.equals(expected, actual, message) end
function luassert.is_true(value, message) end
function luassert.is_false(value, message) end
function luassert.is_truthy(value, message) end
function luassert.is_falsy(value, message) end
function luassert.is_nil(value, message) end
function luassert.is_not_nil(value, message) end
function luassert.is_table(value, message) end
function luassert.is_function(value, message) end
function luassert.is_string(value, message) end
function luassert.is_number(value, message) end
function luassert.is_boolean(value, message) end
function luassert.has_error(fn, expected) end
function luassert.error(fn, expected) end

assert = luassert
