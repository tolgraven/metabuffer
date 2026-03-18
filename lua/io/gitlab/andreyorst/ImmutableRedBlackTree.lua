local RED = 1
local BLACK = 0

--- Tree Node

local Node = {}

function Node:new (key, value)
    self.__index = self

    return setmetatable(
        { key = key, value = value, color = RED },
        self
    )
end

local swap_colors = function (node_a, node_b)
    local temp = node_a.color
    node_a.color = node_b.color
    node_b.color = temp
end

local swap_values = function (node_a, node_b)
    local key, value = node_a.key, node_a.value
    node_a.key, node_a.value = node_b.key, node_b.value
    node_b.key, node_b.value = key, value
end

local successor = function (node)
    local temp = node

    while temp.left do
        temp = temp.left
    end

    return temp
end

local find_replacement = function (node)
    if node.left and node.right then
        return successor(node.right)
    end

    if (not node.left) and (not node.right) then
        return nil
    end

    return node.left or node.right
end

function Node:copy ()
    local new_node = Node:new(self.key, self.value)
    new_node.color = self.color
    if self.left then
        new_node.left = self.left:copy()
    end
    if self.right then
        new_node.right = self.right:copy()
    end
    if new_node.left then
        new_node.left.parent = new_node
    end
    if new_node.right then
        new_node.right.parent = new_node
    end

    return setmetatable(new_node, getmetatable(self))
end

function Node:isOnLeft ()
    return self == self.parent.left
end

function Node:isOnLeft ()
    return self == self.parent.left
end

function Node:uncle ()
    if (not self.parent) or (not self.parent.parent) then
        return nil
    end

    if self.parent:isOnLeft() then
        return self.parent.parent.right
    else
        return self.parent.parent.left
end end

function Node:sibling ()
    if not self.parent then
        return nil
    end

    return self:isOnLeft() and self.parent.right or self.parent.left
end

function Node:moveDown (parent)
    if self.parent then
        if self:isOnLeft() then
            self.parent.left = parent
        else
            self.parent.right = parent
    end end
    parent.parent = self.parent
    self.parent = parent
end

function Node:hasRedChild ()
    return (self.left and self.left.color == RED) or
        (self.right and self.right.color == RED)
end

--- Red Black Tree helper functions

local type_order = {
    number = 1,
    boolean = 2,
    string = 3,
    table = 4,
    ["function"] = 5,
    userdata = 6,
    thread = 7
}

local compare_boolean = function (a, b)
    if a == b then
        return 0
    elseif a then
        return 1
    else
        return -1
end end

local compare_tables = function (a, b, compare)
    if #a < #b then
        return -1
    elseif #a > #b then
        return 1
    else
        local res = 0
        for i = 1, #a do
            if (res ~= 0) then break end
            res = compare(a[i], b[i])
        end
        return res
end end

local compare_tostring = function (a, b)
    if a == b then
        return 0
    elseif tostring(a) < tostring(b) then
        return -1
    else
        return 1
end end

local function default_compare (a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then
        return default_compare(type_order[type(a)], type_order[type(b)])
    end
    if ta == "boolean" then
        return compare_boolean(a, b)
    elseif ta == "table" then
        return compare_tables(a, b, default_compare)
    elseif ta == "function" or ta == "thread" then
        return compare_tostring(a, b)
    else
        if a < b then
            return -1
        elseif a > b then
            return 1
        else
            return 0
end end end

local copy = function (tree)
    return setmetatable(
        tree:new(tree.compare, tree.root and tree.root:copy()),
        getmetatable(tree)
    )
end

local rotate_left = function (tree, node)
    local parent = node.right

    if node == tree.root then
        tree.root = parent
    end

    node:moveDown(parent)

    node.right = parent.left

    if parent.left then
        parent.left.parent = node
    end

    parent.left = node
end

local rotate_right = function (tree, node)
    local parent = node.left

    if node == tree.root then
        tree.root = parent
    end

    node:moveDown(parent)

    node.left = parent.right

    if parent.right then
        parent.right.parent = node
    end

    parent.right = node
end

local function fix_red_red (tree, node)
    if node == tree.root then
        node.color = BLACK
        return
    end

    local parent = node.parent
    local grandparent = parent.parent
    local uncle = node:uncle()

    if parent.color ~= BLACK then
        if uncle and uncle.color == RED then
            parent.color = BLACK
            uncle.color = BLACK
            grandparent.color = RED
            fix_red_red(tree, grandparent)
        else
            if parent:isOnLeft() then
                if node:isOnLeft() then
                    swap_colors(parent, grandparent)
                else
                    rotate_left(tree, parent)
                    swap_colors(node, grandparent)
                end
                rotate_right(tree, grandparent)
            else
                if node:isOnLeft() then
                    rotate_right(tree, parent)
                    swap_colors(node, grandparent)
                else
                    swap_colors(parent, grandparent)
                end
                rotate_left(tree, grandparent)
end end end end

local function fix_black_black (tree, node)
    if node == tree.root then
        return
    end

    local sibling = node:sibling()
    local parent = node.parent

    if not sibling then
        fix_black_black(tree, parent)
    else
        if sibling.color == RED then
            parent.color = RED
            sibling.color = BLACK

            if sibling:isOnLeft() then
                rotate_right(tree, parent)
            else
                rotate_left(tree, parent)
            end

            fix_black_black(tree, node)
        else
            if sibling:hasRedChild() then
                if sibling.left and sibling.left.color == RED then
                    if sibling:isOnLeft() then
                        sibling.left.color = sibling.color
                        sibling.color = parent.color
                        rotate_right(tree, parent)
                    else
                        sibling.left.color = parent.color
                        rotate_right(tree, sibling)
                        rotate_left(tree, parent)
                    end
                else
                    if sibling:isOnLeft() then
                        sibling.right.color = parent.color
                        rotate_left(tree, sibling)
                        rotate_right(tree, parent)
                    else
                        sibling.right.color = sibling.color
                        sibling.color = parent.color
                        rotate_left(tree, parent)
                end end
                parent.color = BLACK
            else
                sibling.color = RED
                if parent.color == BLACK then
                    fix_black_black(tree, parent)
                else
                    parent.color = BLACK
end end end end end

local function delete_node (tree, node)
    local replacement = find_replacement(node)
    local uv_black = (not replacement or replacement.color == BLACK) and (node.color == BLACK)
    local parent = node.parent

    if not replacement then
        if node == tree.root then
            tree.root = nil
        else
            if uv_black then
                fix_black_black(tree, node)
            elseif node:sibling() then
                node:sibling().color = RED
            end

            if node:isOnLeft() then
                parent.left = nil
            else
                parent.right = nil
        end end

        return tree
    end

    if (not node.left) or (not node.right) then
        if node == tree.root then
            node.key = replacement.key
            node.value = replacement.value
            node.left = nil
            node.right = nil
        else
            if node:isOnLeft() then
                parent.left = replacement
            else
                parent.right = replacement
            end

            replacement.parent = parent

            if uv_black then
                fix_black_black(tree, replacement)
            else
                replacement.color = BLACK
        end end

        return tree
    end

    swap_values(replacement, node)
    return delete_node(tree, replacement)
end

local search = function (tree, key)
    local temp = tree.root
    while temp do
        if tree.compare(key, temp.key) == -1 then
            if not temp.left then
                break
            else
                temp = temp.left
            end
        elseif tree.compare(key, temp.key) == 0 then
            break
        else
            if not temp.right then
                break
            else
                temp = temp.right
    end end end

    return temp
end

local min_key = function(tree)
    local current = tree.root

    if current then
        while current.left do
            current = current.left
        end
        return current
    else
        return nil
end end

local max_key = function(tree)
    local current = tree.root

    if current then
        while current.right do
            current = current.right
        end
        return current
    else
        return nil
end end

local find_node = function (tree, key)
    local node = search(tree, key)

    if tree.compare(node.key, key) == 0 then
        return node
    end

    return nil
end

local find_next = function(tree, key)
    local next_node = nil
    local current = find_node(tree, key)

    while current do
        if (tree.compare(key, current.key) == -1) then
            next_node = current
            current = current.left
        elseif (tree.compare(key, current.key) == 1) then
            current = current.right
        elseif (tree.compare(key, max_key(tree).key) == 0) then
            return nil
        elseif current.right then
            local node = current.right

            while node.left do
                node = node.left
            end

            return node
        else
            while current.parent do
                if rawequal(current.parent.left, current) then
                    return current.parent
                else
                    current = current.parent
    end end end end

    if (next_node and next_node.key) then
        return next_node
    end

    return nil
end

local function tree_next(tree, key)
    if key == nil then
        local min = min_key(tree)
        if nil ~= min then
            return min.key, min.value
        else
            return nil
        end
    else
        local next_node = find_next(tree, key)
        if nil ~= next_node then
            return next_node.key, next_node.value
        else
            return nil
end end end

--- Copy on Write RedBlack Tree

local ImmutableRedBlackTree = {
    __call = function(self, key, not_found) return self:get(key, not_found) end,
    __pairs = function(self) return tree_next, self, nil end,
    __name = "ImmutableRedBlackTree"
}

function ImmutableRedBlackTree:new (compare, root)
    self.__index = self
    return setmetatable({ compare = compare or default_compare, root = root }, self)
end


-- TODO: make persistent by only copying the changed path to the node,
-- and rebalancing it. Invesitgate:
-- https://github.com/mikolalysenko/functional-red-black-tree/blob/master/rbtree.js
function ImmutableRedBlackTree:insert (key, value)
    local tree = copy(self)
    local new_node = Node:new(key, value)
    if not tree.root then
        new_node.color = BLACK
        tree.root = new_node
    else
        local node = search(tree, key)

        if self.compare(node.key, key) == 0 then
            node.value = value
            return tree
        end

        new_node.parent = node

        if self.compare(key, node.key) == -1 then
            node.left = new_node
        else
            node.right = new_node
        end

        fix_red_red(tree, new_node)
    end
    return tree
end

function ImmutableRedBlackTree:remove (key)
    if not self.root then
        return
    end

    local tree = copy(self)

    local v = search(tree, key)

    if self.compare(v.key, key) == 0 then
        delete_node(tree, v)
        return tree
    end

    return self
end

function ImmutableRedBlackTree:get (key, not_found)
    local node = search(self, key)

    if self.compare(node.key, key) == 0 then
        return node.value
    end

    return not_found
end

function ImmutableRedBlackTree:contains (key)
    local node = search(self, key)

    if self.compare(node.key, key) == 0 then
        return true
    end

    return false
end

function ImmutableRedBlackTree:inOrderIterator ()
    return tree_next, self, nil
end

function ImmutableRedBlackTree:StatefulLevelIterator ()
    local queue = {self.root}
    local level_next = function ()
        local next_node = table.remove(queue, 1)
        if nil ~= next_node then
            if next_node.left then
                queue[#queue+1] = next_node.left
            end
            if next_node.right then
                queue[#queue+1] = next_node.right
            end
            return next_node.key, next_node.value
        else
            return nil
    end end
    return level_next
end

return ImmutableRedBlackTree
