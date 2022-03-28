--------------------------------------------------------------------------------------
--
-- > Create a new class structure using:
-- ClassNameA = Object:Extend("ClassNameA")
--
--
-- > Define the class constructor:
-- function ClassNameA:constructor()
--   local newInstance = {
--     -- fields
--   }
--   return newInstance;
-- end;
--
--
-- > Extend an existing class:
-- ClassNameB = ClassNameA:Extend("ClassNameB")
--
-- function ClassNameB:constructor()
--   local newInstance = {
--     -- fields
--   }
--   return newInstance, self.super();  <--- Second argument is the parent instance - can be the super constructor call.
-- end;
--
--
-- > User-defined meta methods:
-- ClassNameA = Object:Extend("ClassNameA", {
--   __tostring? = function(self) return self.value end;  <--- By default, __string will return "[object: ClassName]".
--   __concat? = function(prefix, self) return string.format("%s%s", prefix, tostring(self)) end;  <--- By default, __concat will call __tostring on the object.
-- })
--
--------------------------------------------------------------------------------------

---@class Object @The base class that sets the framework for extending classes.
local _Object = {};

-- A metatable factory for new classes and class instances.
local Object_MetaFactory = {};

---@class Object_UserMeta
---@field __tostring? function
---@field __concat? function

---Extend a class. (Static Method)
---@param self Object @The class to extend from.
---@param type string @The new class name.
---@param meta? Object_UserMeta @The custom metamethods for the class.
---@return Object @A new class table of your type, extending the parent class.
function _Object:Extend(type, meta)
    if (self:isInstance()) then error("Extending an instance of a class is not supposed by this function. Extend from classes only.") end;
    return setmetatable({ super = self }, Object_MetaFactory.createClass(self, type, meta))
end;

---Check if the table object is in the context of a class.
---@return boolean @Returns true if the table object is in class context; false if instance context.
function _Object:isClass()
    return getmetatable(self).__class == nil;
end

---Check if the table object is in the context of a class instance.
---@return boolean @Returns true if the table object is in class instance context; false if class context.
function _Object:isInstance()
    return not self:isClass();
end

---Check if this object is an instance of the specified class. (Instance Method)
---@param class Object
---@return boolean
function _Object:instanceOf(class)
    local meta = getmetatable(self);
    while meta do
        if (meta["__type"] and (meta.__type == getmetatable(class).__type)) then return true end;
---@diagnostic disable-next-line: undefined-field
        meta = getmetatable(self.super);
    end
    return false;
end;

---Get the parent class of this instance. (Instance Method)
---@param self Object
---@return Object
function _Object:class()
    return getmetatable(self).__class;
end;

---Get the object type name. (Instance Method)
---@param self Object
---@return string
function _Object:type()
    return getmetatable(self).__type;
end;

local globalMethods = {

    Extend = _Object.Extend; -- Class Method
    instanceOf = _Object.instanceOf; -- Instance Method
    class = _Object.class; -- Instance Method
    type = _Object.type; -- Instance Method
}

local Object_BaseMeta = {
    __tostring = function(self) return string.format("[object: %s]", getmetatable(self).__type) end;
    __concat = function(prefix, self) return string.format("%s%s", prefix, tostring(self)) end;
    __index = globalMethods;
    __type = "Object";
};
setmetatable(_Object, Object_BaseMeta);

-- Handle calls for __tostring on a class or instance of a class.
---@param tableObject Object
---@param userMeta? Object_UserMeta
---@return string
local function objectToString(tableObject, userMeta)
    userMeta = userMeta or {};
    if (tableObject:isClass()) then return string.format("[object: %s]", getmetatable(tableObject).__type) end; -- Is in a class context - return __type.
    return (userMeta["__tostring"]) and userMeta.__tostring(tableObject) or string.format("[object: %s]", getmetatable(tableObject).__type); -- Is in an instance context - call user-defined __tostring.
end;

---Handle calls for __tostring on a class or instance of a class.
---@param prefix string
---@param tableObject Object
---@param userMeta? Object_UserMeta
---@return string
local function objectConcat(prefix, tableObject, userMeta)
    userMeta = userMeta or {};
    if (tableObject:isClass()) then return string.format("%s%s", prefix, tostring(tableObject)) end; -- Is in a class context - return tostring() on the called on the class.
    return (userMeta["__concat"]) and userMeta.__concat(prefix, tableObject) or string.format("%s%s", prefix, tostring(tableObject)); -- Is in an instance context - call user-defined __tostring.
end;

---Create the metatable for the new class.
---@param parentClass Object @The parent class this class is extending from.
---@param classType string @The name & type of the new class.
---@param userMeta? Object_UserMeta @User-defined meta methods.
---@return Object
function Object_MetaFactory.createClass(parentClass, classType, userMeta)
    userMeta = userMeta or {};
    return {
        __tostring = function(self) return objectToString(self, userMeta) end;
        __concat = function(prefix, object) return objectConcat(prefix, object, userMeta) end;
        __index = parentClass;
        __userMeta = userMeta;
        __type = classType;
        __call = function(self, ...)
            local newObject, parentObject;
            if (self['constructor']) then newObject, parentObject = self:constructor(...) end;
            local newObjectMeta = Object_MetaFactory.createClassInstance(self, parentObject);

            if (not newObject) then return setmetatable({ super = (parentObject) and parentObject or nil , ...}, newObjectMeta) end; -- Constructor was called, but has not been defined. Return {...} and assign super if parentObject is not nil.
            if (newObject) then
                newObject.super = parentObject or nil;
                newObjectMeta.__index = parentObject or newObjectMeta.__index;
                return (parentObject) and setmetatable(newObject, newObjectMeta) or setmetatable(newObject, newObjectMeta); -- Parent object was nil, or not a table. Assign the default metatable.
            end;
        end;
    };
end;

---Create a metatable for a new instance of our class.
---@param class Object @The class that the instance is being created from. (E.g. Class: Vehicle)
---@param parentInstance any @An instance of another class to extend. (E.g. Instance of class Car extending Vehicle: toyota)
---@return Object
function Object_MetaFactory.createClassInstance(class, parentInstance)
    local classMeta, parentClassMeta = getmetatable(class), (parentInstance and getmetatable(parentInstance:class()) or nil);

    return {

        -- Check if the class has a user-defined meta method. If it doesn't, inherit from the extended class.
        __tostring = (parentClassMeta) and ((classMeta.__userMeta["__tostring"]) and classMeta.__tostring or parentClassMeta.__tostring) or classMeta.__tostring;
        __concat = (parentClassMeta) and ((classMeta.__userMeta["__concat"]) and classMeta.__concat or parentClassMeta.__concat) or classMeta.__concat;

        __index = parentInstance or class;

        __class = class;
        __type = getmetatable(class).__type;
    };
end

local ClassStructure = _Object;
return ClassStructure;