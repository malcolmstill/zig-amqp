from __future__ import print_function
import xml.etree.ElementTree as Tree
import sys

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

AMQP_TO_ZIG = {
        'longstr': "[]const u8",
        'bit': "bool",
        'longlong': "u64",
        'short': "u16",
        'table': "Table",
        'long': "u32",
        'octet': "u8",
        'timestamp': "[]const u8",
        'shortstr': "[]const u8"
    }


AMQP_ARG_TO_ZIG = {
        'longstr': "[]const u8",
        'bit': "bool",
        'longlong': "u64",
        'short': "u16",
        'table': "?*Table",
        'long': "u32",
        'octet': "u8",
        'timestamp': "[]const u8",
        'shortstr': "[]const u8"
    }

RESERVED = {
        'longstr': '""',
        'bit': "false",
        'longlong': "0",
        'short': "0",
        'table': "NOWAY",
        'long': "0",
        'octet': "0",
        'timestamp': '"',
        'shortstr': '""'
    }

WRITES = {
        'longstr': 'writeLongString',
        'bit': "NOWAY",
        'longlong': "writeU64",
        'short': "writeU16",
        'table': "writeTable",
        'long': "writeU32",
        'octet': "writeU8",
        'timestamp': 'writeShortString',
        'shortstr': 'writeShortString'
    }

READS = {
        'longstr': 'readLongString',
        'bit': "NOWAY",
        'longlong': "readU64",
        'short': "readU16",
        'table': "readTable",
        'long': "readU32",
        'octet': "readU8",
        'timestamp': 'readShortString',
        'shortstr': 'readShortString'
    }    

CONSTNESS = {
        'longstr': 'const',
        'bit': "const",
        'longlong': "const",
        'short': "const",
        'table': "var",
        'long': "const",
        'octet': "const",
        'timestamp': 'const',
        'shortstr': 'const'
    }    

BITFIELD_TYPES = ['bit', 'no-ack', 'no-local', 'no-wait', 'redelivered']

def buildAMQP(amqp):
    constants = {}
    domains = {}
    classes = {}
    for child in amqp:
        if child.tag == "constant":
            constant = buildConstant(child)
            constants[constant['name']] = constant
        if child.tag == "domain":
            domain = buildDomain(child)
            domains[domain['name']] = domain            
        if child.tag == "class":
            klass = buildClass(child)
            classes[klass['name']] = klass

    return {
        'constants': constants,
        'domains': domains,
        'classes': classes
    }

def buildConstant(constant):
    name = constant.attrib['name']
    return {
        'name': name,
        'value': constant.attrib['value']
    }

def buildDomain(domain):
    return {
        'name': domain.attrib['name'],
        'type': domain.attrib['type']
    }

def buildClass(klass):
    methods = {}

    for child in klass:
        if child.tag == "method":
            method = buildMethod(child)
            methods[method['name']] = method

    return {
        'name': klass.attrib['name'],
        'handler': klass.attrib['handler'],
        'index': klass.attrib['index'],
        'methods': methods
    }    

def buildMethod(method):
    fields = {}
    has_response = False
    response = None
    received_by_client = False
    received_by_server = False

    for child in method:
        if child.tag == 'response':
            has_response = True
            response = child.attrib['name']
        if child.tag == 'chassis':
            if child.attrib['name'] == 'client':
                received_by_client = True
            if child.attrib['name'] == 'server':
                received_by_server = True   
        if child.tag == 'field':
            field = buildField(child)
            fields[field['name']] = field             

    return {
        'name': method.attrib['name'],
        'synchronous': 'synchronous' in method.attrib and method.attrib['synchronous'] == '1',
        'index': method.attrib['index'],
        'has_response': has_response,
        'response': response,
        'received_by_client': received_by_client,
        'received_by_server': received_by_server,
        'fields': fields
    }

def buildField(field):
    reserved = False
    if 'reserved' in field.attrib and field.attrib['reserved'] == '1':
        reserved = True

    domain = None
    if 'domain' in field.attrib:
        domain = field.attrib['domain']

    Type = None
    if 'type' in field.attrib:
        Type = field.attrib['type']   

    d = None
    if domain is not None:
        d = domain

    if Type is not None:
        d = Type

    return {
        'name': field.attrib['name'],
        'domain': d,
        'reserved': reserved
    }

def generate(file):
    print(f'const std = @import("std");')
    print(f'const fs = std.fs;')
    print(f'const Connector = @import("connector.zig").Connector;')
    print(f'const ClassMethod = @import("connector.zig").ClassMethod;')
    print(f'const WireBuffer = @import("wire.zig").WireBuffer;')
    print(f'const Table = @import("table.zig").Table;')

    tree = Tree.parse(file)
    amqp = tree.getroot()
    if amqp.tag == "amqp":
        parsed = buildAMQP(amqp)
        generateConstants(parsed)
        generateClasses(parsed)

def generateConstants(parsed):
    print(f"")
    for constant_name, constant in parsed['constants'].items():
        print(f"pub const {nameCleanUpper(constant_name)} = {constant['value']};")

def generateClasses(parsed):
    for class_name, klass in parsed['classes'].items():
        print(f"")
        print(f"// {class_name}")
        print(f"pub const {nameCleanCap(class_name)} = struct {{")
        print(f"pub const {nameCleanUpper(class_name)}_CLASS = {klass['index']};")
        for method_name, method in klass['methods'].items():
            print(f"")
            print(f"// {method_name}")
            generateReturnType(parsed, class_name, method)
            generateMethodFunction(parsed, class_name, method)
        print(f"}};")

def generateReturnType(parsed, class_name, method):
    response_name = method['name']

    print(f"")
    print(f"pub const {nameCleanCamel(response_name)} = struct {{")
    for field_name, field in method['fields'].items():
        print(f"{nameClean(field_name)}: {AMQP_TO_ZIG[typeLookup(parsed, field['domain'])]},")
    print(f"}};")

def typeLookup(parsed, domain):
    domains = parsed['domains']
    return domains[domain]['type']

def generateMethodFunction(parsed, class_name, method):
    print(f"pub const {nameCleanUpper(method['name'])}_METHOD = {method['index']};")
    if method['synchronous'] and method['has_response']:
        # 1. We intiate a call, we then wait upon an expected synchronous response
        generateSynchronousMethodFunction(parsed, class_name, method)
    else:
        generateAsynchronousMethodFunction(parsed, class_name, method)

    generateAwaitMethod(parsed, class_name, method)

def generateSynchronousMethodFunction(parsed, class_name, method):
    method_name = method['name']
    klass_upper = nameCleanUpper(class_name)
    klass_cap = nameCleanCap(class_name)

    print(f"pub fn {nameCleanSnake(method_name)}Sync(conn: *Connector,")
    # Write out function args
    for field_name, field in method['fields'].items():
        if not field['reserved']:
            print(f"{nameClean(field_name)}: {AMQP_ARG_TO_ZIG[typeLookup(parsed, field['domain'])]}, ", end = '')
    print(f") !{nameCleanCamel(method['response'])} {{")
    # Send message
    print(f"conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);")
    print(f"conn.tx_buffer.writeMethodHeader({klass_upper}_CLASS, {nameCleanUpper(method_name)}_METHOD);")
    # Generate writes
    bit_field_count = 0
    for field_name, field in method['fields'].items():
        if field['reserved']:
            print(f"const {nameClean(field['name'])} = {RESERVED[typeLookup(parsed, field['domain'])]};")
        # What we do depends on the field type
        if typeLookup(parsed, field['domain']) == "bit":
            if bit_field_count % 8 == 0:
                print(f"var bitset{bit_field_count//8}: u8 = 0; const _bit: u8 = 1;")
            print(f"if ({nameClean(field['name'])}) bitset{bit_field_count//8} |= (_bit << {bit_field_count}) else bitset{bit_field_count//8} &= ~(_bit << {bit_field_count});")               
            bit_field_count += 1
        else:
            if bit_field_count > 0:
                print(f"conn.tx_buffer.writeU8(bitset{bit_field_count//8});")  
            bit_field_count = 0
            print(f"conn.tx_buffer.{WRITES[typeLookup(parsed, field['domain'])]}({nameClean(field['name'])});")

    if bit_field_count > 0:
        print(f"conn.tx_buffer.writeU8(bitset{bit_field_count//8});")                
    # Send message
    print(f"conn.tx_buffer.updateFrameLength();")
    print(f"const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());")
    print(f"conn.tx_buffer.reset();")
    print(f"if (std.builtin.mode == .Debug) std.debug.warn(\"{klass_cap}.{nameCleanCap(method_name)} ->\\n\", .{{}});")

    print(f"return await{nameCleanCamel(method['response'])}(conn);")
    print(f"}}")

def generateAwaitMethod(parsed, class_name, method):
    class_name_upper = nameCleanUpper(class_name)
    class_name_cap = nameCleanCap(class_name)

    bit_field_count = 0
    method_name = nameClean(method['name'])
    method_name_cap = nameCleanCap(method['name'])
    # index = method['index']
    # class_index = parsed['classes'][class_name]['index']
    print(f"\n// {method_name}")
    print(f"pub fn await{nameCleanCamel(method['name'])}(conn: *Connector) !{nameCleanCamel(method['name'])} {{")
    # print(f"const {method_name} = {class_name_upper}_IMPL.{method_name} orelse return error.MethodNotImplemented;")


    print(f"while (true) {{")
    print(f"while (conn.rx_buffer.frameReady()) {{")
    print(f"const frame_header = try conn.getFrameHeader();")

    print(f"switch (frame_header.@\"type\") {{")
    print(f"    .Method => {{")
    print(f"const method_header = try conn.rx_buffer.readMethodHeader();")

    print(f"if (method_header.class == {class_name_upper}_CLASS and method_header.method == {nameCleanUpper(method['name'])}_METHOD) {{")

    for field_name, field in method['fields'].items():
        Type = typeLookup(parsed, field['domain'])
        if Type == "bit":
            if bit_field_count % 8 == 0:
                print(f"const bitset{bit_field_count//8} = conn.rx_buffer.readU8();")
            print(f"{CONSTNESS[Type]} {nameClean(field_name)} = if (bitset{bit_field_count//8} & (1 << {bit_field_count}) == 0) true else false;")
            bit_field_count += 1
        else:
            bit_field_count = 0
            print(f"{CONSTNESS[Type]} {nameClean(field_name)} = conn.rx_buffer.{READS[Type]}(); ")

    print(f"try conn.rx_buffer.readEOF();")
    print(f"if (std.builtin.mode == .Debug) std.debug.warn(\"\\t<- {class_name_cap}.{method_name_cap}\\n\", .{{}});")

    print(f"return {nameCleanCamel(method['name'])} {{")
    for field_name, field in method['fields'].items():
        Type = typeLookup(parsed, field['domain'])
        if Type == 'Table':
            print(f".{nameClean(field_name)} = &{nameClean(field_name)},")
        else:
            print(f".{nameClean(field_name)} = {nameClean(field_name)},")
    print(f"}};")

    # End if:
    print(f"}} else {{")
    print(f"if (method_header.class == {parsed['classes']['connection']['index']} and method_header.method == {parsed['classes']['connection']['methods']['close']['index']}) {{")
    print(f"try Connection.closeOkAsync(conn);")
    print(f"return error.ConnectionClose;")
    print(f"}}")

    print(f"if (method_header.class == {parsed['classes']['channel']['index']} and method_header.method == {parsed['classes']['channel']['methods']['close']['index']}) {{")
    print(f"try Channel.closeOkAsync(conn);")
    print(f"}}")

    print(f"return error.ImplementAsyncHandle;")
    # End else:
    print(f"}}")


    print(f"}},")

    print(f".Heartbeat => {{")
    print(f"if (std.builtin.mode == .Debug) std.debug.warn(\"Got heartbeat\\n\", .{{}});")
    print(f"                try conn.rx_buffer.readEOF();")
    print(f"            }}, ")
    print(f"            .Header => {{ _ = try conn.rx_buffer.readHeader(frame_header.size); }},")
    print(f"            .Body => {{ _ = try conn.rx_buffer.readBody(frame_header.size); }},")
    print(f"        }}")
    # End while(frameReady)
    print(f"}}")
    # End while(true)
    print(f"}}")
    print(f"unreachable;")
    print(f"}}")

def generateAsynchronousMethodFunction(parsed, class_name, method):
    method_name = nameCleanUpper(method['name'])
    klass_upper = nameCleanUpper(class_name)
    klass_cap = nameCleanCap(class_name)

    print(f"pub fn {nameCleanSnake(method['name'])}Async(conn: *Connector,")
    # Write out function args
    for field_name, field in method['fields'].items():
        if not field['reserved']:
            print(f"{nameClean(field_name)}: {AMQP_ARG_TO_ZIG[typeLookup(parsed, field['domain'])]}, ", end = '')
    print(f") !void {{")
    # Send message
    print(f"conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);")
    print(f"conn.tx_buffer.writeMethodHeader({klass_upper}_CLASS, {klass_cap}.{nameCleanUpper(method_name)}_METHOD);")
    # Generate writes
    bit_field_count = 0
    for field_name, field in method['fields'].items():
        if field['reserved']:
            print(f"const {nameClean(field['name'])} = {RESERVED[typeLookup(parsed, field['domain'])]};")
        # What we do depends on the field type
        if typeLookup(parsed, field['domain']) == "bit":
            if bit_field_count % 8 == 0:
                print(f"var bitset{bit_field_count//8}: u8 = 0; const _bit: u8 = 1;")
            print(f"if ({nameClean(field['name'])}) bitset{bit_field_count//8} |= (_bit << {bit_field_count}) else bitset{bit_field_count//8} &= ~(_bit << {bit_field_count});")               
            bit_field_count += 1
        else:
            if bit_field_count > 0:
                print(f"conn.tx_buffer.writeU8(bitset{bit_field_count//8});")  
            bit_field_count = 0
            print(f"conn.tx_buffer.{WRITES[typeLookup(parsed, field['domain'])]}({nameClean(field['name'])});")

    if bit_field_count > 0:
        print(f"conn.tx_buffer.writeU8(bitset{bit_field_count//8});")                
    # Send message
    print(f"conn.tx_buffer.updateFrameLength();")
    print(f"const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());")
    print(f"conn.tx_buffer.reset();")
    print(f"if (std.builtin.mode == .Debug) std.debug.warn(\"{klass_cap}.{nameCleanCap(method_name)} ->\\n\", .{{}});")
    print(f"}}")

def nameClean(name):
    name = name.replace('-', '_')

    if name == "return":
        return "@\"return\""
    if name == "type":
        return "tipe"        
    return name

def nameCleanUpper(name):
    name = name.replace('-', '_').upper()    
    return name

def nameCleanCap(name):
    name = name.replace('-', '_').capitalize()    
    return name

def nameCleanCamel(name):
    name = ''.join([x.capitalize() for x in name.split('-')])
    return name

def nameCleanSnake(name):
    return ''.join([x if i == 0 else x.capitalize() for i, x in enumerate(name.split('-'))])


generate(sys.argv[1])