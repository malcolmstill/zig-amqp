import xml.etree.ElementTree as Tree
import sys

def generate(file):
    print(f'const std = @import("std");')
    print(f'const Connection = @import("connection.zig").Connection;')

    tree = Tree.parse(file)
    amqp = tree.getroot()
    if amqp.tag == "amqp":
        print("// amqp")
        for child in amqp:
            if child.tag == "constant":
                print(f"const {nameClean(child)}: u16 = {child.attrib['value']};")
            if child.tag == "class":
                generate_class(child)

def generate_class(c):
    # print(f"pub const {nameClean(c)} = struct {{")
    print(f"pub const {nameCleanUpper(c)}_INDEX = {c.attrib['index']}; // CLASS")
    print(f"pub const {nameCleanCap(c)} = struct {{")
    for child in c:
        if child.tag == "method":
            is_client = False
            for method_child in child:
                if method_child.tag == 'chassis' and 'name' in method_child.attrib and method_child.attrib['name'] == 'server':
                    is_client = True
            if is_client:
                print(f"// METHOD =============================")
                print(f"pub const {nameCleanUpper(child)}_INDEX = {child.attrib['index']};")
                # Case 1: a client-initiated synchronous call
                # We send the initial call and await a given response
                if ('synchronous' in child.attrib) and (child.attrib['synchronous'] == '1'):
                    print(f"pub fn {nameClean(child)}_sync(conn: *Connection,")
                    for method_child in child:
                        if method_child.tag == 'field' and not ('reserved' in method_child.attrib and method_child.attrib['reserved'] == '1'):
                            print(f"{nameClean(method_child)}: {generateArg(method_child)}, ", end = '')
                    print(f") void {{")
                    # Send message
                    print(f"const n = try os.write(conn.file, conn.tx_buffer[0..]);")
                    print(f"while (true) {{ const message = try conn.dispatch(allocator, null); }}")
                    print(f"}}")
                else:
                    print(f"pub fn {nameClean(child)}(conn: *Connection) void {{}}")

    print(f"}};")

def generateArg(field):
    field_type = field.attrib['domain']
    if field_type == 'long':
        return 'u32'
    if field_type in ['short', 'class-id', 'method-id', 'reply-code']:
        return 'u16'
    if field_type in ['bit', 'no-ack', 'no-local', 'no-wait']:
        return 'bool'
    if field_type == 'queue-name':
        return '[128]u8'
    if field_type == 'path':
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