---@class ClassObject
---@field super nil|table:ClassObject @Class Context: The super class that this class extends from.  |  Instance Contenxt: The parent instance that this instance inherits from.
---@field class nil|table:ClassObject @The class that this instance has been created from. Only available in instance context.
local ClassObject = {};

do

    local ClassObject_MetaFactory = {};

    -- Global Functions -------------------------------------

    function ClassObject:Extend(className, meta)
        meta = meta or {};
        return setmetatable({}, ClassObject_MetaFactory.createClass(self, className, meta));
    end;

    function ClassObject:type()
        return getmetatable(self).__type;
    end;

    function ClassObject:isClass()
        return self.class ~= nil;
    end;

    function ClassObject:isInstance()
        return not self:isClass();
    end;

    function ClassObject:instanceOf(class)
        local super = self;
        while super do
            if (getmetatable(super)['__type'] and (getmetatable(super)['__type'] == getmetatable(class).__type)) then return true end;
            super = super.super;
        end
        return false;
    end;

    ----------------------------------------------------------


    local ClassObject_BaseMeta = {
        __type = "Object";
        __userMeta = {
            __tostring = function(object) return string.format("[object %s]", object:type()) end;
            __concat = function(prefix, object) return string.format("%s%s", prefix, tostring(object)) end;
        };
    };
    setmetatable(ClassObject, ClassObject_BaseMeta);

    ---Create the meta table for a new class.
    ---@return table
    function ClassObject_MetaFactory.createClass(parentClass, className, userMeta)

        local __userMeta = setmetatable(userMeta or {}, { __index = getmetatable(parentClass).__userMeta });
        local __index = setmetatable({ super = parentClass }, { __index = parentClass }); -- Define the field 'super' as a reference to the parentClass.

        local __call = function(class, ...)
            local newInstance, parentInstance
            if (class['constructor']) then newInstance, parentInstance = class:constructor(...) end;

            if (newInstance == nil) then error(string.format("No constructor defined for class '%s', or the return value was nil.", class:type())) end; -- If the class constructor is undefined or returns nil, throw an error.
            if (type(newInstance) ~= 'table') then error(string.format("The constructor for class '%s' must return a table value. Actual type: '%s'.", class:type(), type(newInstance))) end; -- If the class constructor returned a non-table value.

            if (parentInstance == nil) then
                if (class.super ~= ClassObject) then parentInstance = class.super and class.super(...) or nil end; -- No parent was defined. Call super() if it exists, unless it's our base - ClassObject.
            else
                if (type(parentInstance) ~= 'table') then error(string.format("The constructor for class '%s' must return a table value or nil as its parent instance. Actual type: '%s'.", class:type(), type(parentInstance))) end; -- If the class constructor returned a non-table value as the parent instance.
                parentInstance = parentInstance;
            end;
            local newInstanceMeta = ClassObject_MetaFactory.createClassInstance(class, parentInstance);

            return setmetatable(newInstance, newInstanceMeta);
        end;

        return {
            __type = className;
            __userMeta = __userMeta;
            __index = __index; -- Lookup any missing fields in the parent class.
            __call = __call;

            -- Just use the base tostring/concat methods for classes because I'm too lazy to make something special for class/instance calls.
            __tostring = ClassObject_BaseMeta.__userMeta.__tostring;
            __concat = ClassObject_BaseMeta.__userMeta.__concat;

        };
    end;

    ---Create the meta table for a new instance of a class.
    ---@return table
    function ClassObject_MetaFactory.createClassInstance(parentClass, parentInstance)

        local __index = setmetatable({ class = parentClass; super = parentInstance }, { __index = function(instance, key)
            if (rawget(parentClass, key)) then return parentClass[key] end; -- First check the class of the instance for the indexed key.

            --Go up the chain of inherited instance tables to find the indexed key. Only pull from the class of the inherited instance if the indexed key is a function.
            local super = parentInstance
            while super do
                if (rawget(super, key)) then return rawget(super, key) end;
                if (rawget(super.class, key) and type(rawget(super.class, key)) == "function") then return rawget(super.class, key) end;
                super = super.super or nil;
            end;

            return ClassObject[key]; -- No such inherited field was found. Check the glocal methods.
        end});

        return {
            __type = getmetatable(parentClass).__type;
            __index = __index;

            __tostring = getmetatable(parentClass).__userMeta.__tostring;
            __concat = getmetatable(parentClass).__userMeta.__concat;
        };
    end;


end;

---@type ClassObject;
local ClassStructure = ClassObject;
return ClassStructure;