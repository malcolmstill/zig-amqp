import xml.etree.ElementTree as Tree
import sys

def generate(file):
    print(f'const std = @import("std");')
    print(f'const Wire = @import("connection.zig").Wire;')

    tree = Tree.parse(file)
    amqp = tree.getroot()
    if amqp.tag == "amqp":
        print("// amqp")
        generateLookup(amqp)
        generateIsSyncrhonous(amqp)
        for child in amqp:
            if child.tag == "constant":
                print(f"const {nameClean(child)}: u16 = {child.attrib['value']};")
            if child.tag == "class":
                generateInterface(child)
                generateImplementation(child)
                generateClass(child)

def generateLookup(amqp):
    print(f"pub fn dispatchCallback(class_id: u16, method_id: u16) !void {{")
    print(f"switch (class_id) {{")
    for child in amqp:
        if child.tag == "class":
            klass = child
            index = klass.attrib['index']
            print(f"// {klass.attrib['name']}")
            print(f"{index} => {{")
            generateLookupMethod(klass)
            print(f"}},")
    print(f"else => return error.UnknownClass}}")
    print(f"}}")

def generateLookupMethod(klass):
    print(f"switch (method_id) {{")
    class_name_upper = nameCleanUpper(klass)
    for child in klass:
        if child.tag == "method":
            method = child
            method_name = nameClean(method)
            index = method.attrib['index']
            print(f"// {method_name}")
            print(f"{index} => {{")
            print(f"const {method_name} = {class_name_upper}_IMPLEMENTATION.{method_name} orelse return error.MethodNotImplemented;")
            print(f"try {method_name}();")
            print(f"}},")
    print(f"else => return error.UnknownMethod, ")            
    print(f"}}")

def generateIsSyncrhonous(amqp):
    print(f"pub fn isSynchronous(class_id: u16, method_id: u16) !bool {{")
    print(f"switch (class_id) {{")
    for child in amqp:
        if child.tag == "class":
            klass = child
            index = klass.attrib['index']
            print(f"// {klass.attrib['name']}")
            print(f"{index} => {{")
            generateIsSyncrhonousMethod(klass)
            print(f"}},")
    print(f"else => return error.UnknownClass}}")
    print(f"}}")

def generateIsSyncrhonousMethod(method):
    print(f"switch (method_id) {{")
    class_name_upper = nameCleanUpper(method)
    for child in method:
        if child.tag == "method":
            method = child
            method_name = nameClean(method)
            is_synchronous = 'synchronous' in method.attrib and method.attrib['synchronous'] == '1'
            index = method.attrib['index']
            print(f"// {method_name}")
            print(f"{index} => {{")
            if is_synchronous:
                print(f"return true;")
            else:
                print(f"return false;")
            print(f"}},")
    print(f"else => return error.UnknownMethod, ")            
    print(f"}}")

def generateInterface(klass):
    class_name = nameClean(klass)
    print(f"pub const {class_name}_interface = struct {{")
    for child in klass:
        if child.tag == "method":
            method = child
            generateInterfaceMethod(method)
    print(f"}};\n")

def generateInterfaceMethod(method):
    method_name = nameClean(method)
    print(f"{method_name}: ?fn() anyerror!void,")

def generateImplementation(klass):
    class_name_upper = nameCleanUpper(klass)
    class_name = nameClean(klass)
    print(f"pub var {class_name_upper}_IMPLEMENTATION = {class_name}_interface {{")
    for child in klass:
        if child.tag == 'method':
            method = child
            method_name = nameClean(method)
            print(f".{method_name} = null,")
    print(f"}};\n")

def generateClass(c):
    # print(f"pub const {nameClean(c)} = struct {{")
    print(f"pub const {nameCleanUpper(c)}_INDEX = {c.attrib['index']}; // CLASS")
    print(f"pub const {nameCleanCap(c)} = struct {{")
    print(f"conn: *Wire,")
    print(f"const Self = @This();")
    for child in c:
        if child.tag == "method":
            if isClientInitiatedRequest(child):
                generateClientInitiatedRequest(child)

    print(f"}};")

def isClientInitiatedRequest(method):
    isRequestSentToServer = False
    expectsResponse = False
    for child in method:
        if child.tag == 'chassis' and 'name' in child.attrib and child.attrib['name'] == 'server':
            isRequestSentToServer = True
        if child.tag == 'response':
            expectsResponse = True
    return isRequestSentToServer and expectsResponse

def generateClientInitiatedRequest(method):
    print(f"// METHOD =============================")
    print(f"pub const {nameCleanUpper(method)}_INDEX = {method.attrib['index']};")
    print(f"pub fn {nameClean(method)}_sync(self: *Self,")
    for method_child in method:
        if method_child.tag == 'field' and not ('reserved' in method_child.attrib and method_child.attrib['reserved'] == '1'):
            print(f"{nameClean(method_child)}: {generateArg(method_child)}, ", end = '')
    print(f") void {{")
    # Send message
    print(f"const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);")
    print(f"while (true) {{ const message = try self.conn.dispatch(allocator, null); }}")
    print(f"}}")

def generateArg(field):
    field_type = field.attrib['domain']
    if field_type == 'long':
        return 'u32'
    if field_type in ['short', 'class-id', 'method-id', 'reply-code']:
        return 'u16'
    if field_type in ['bit', 'no-ack', 'no-local', 'no-wait']:
        return 'bool'
    if field_type in ['queue-name', 'exchange-name']:
        return '[128]u8'
    if field_type in ['path', 'shortstr']:
        return '?[128]u8'        
    if field_type in ['consumer-tag', 'reply-text']:
        return '[]u8'              
    return 'void'

def nameClean(tag):
    name = tag.attrib['name'].replace('-', '_')

    if name == "return":
        return "@\"return\""
    if name == "type":
        return "@\"type\""        
    return name

def nameCleanUpper(tag):
    name = tag.attrib['name'].replace('-', '_').upper()    
    return name

def nameCleanCap(tag):
    name = tag.attrib['name'].replace('-', '_').capitalize()    
    return name       

generate(sys.argv[1])