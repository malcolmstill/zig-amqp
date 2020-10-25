import xml.etree.ElementTree as Tree
import sys

def generate(file):
    print(f'const std = @import("std");')

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
    print(f"pub const {nameCleanUpper(c)} = {c.attrib['index']}; // CLASS")
    for child in c:
        if child.tag == "method":
            # print(f"pub fn {nameClean(child)}() void {{}}")
            print(f"pub const {nameCleanUpper(child)} = {child.attrib['index']}; // METHOD")

    # print(f"}};")

def nameClean(tag):
    name = tag.attrib['name'].replace('-', '_')

    if name == "return":
        return "@\"return\""
    return name

def nameCleanUpper(tag):
    name = tag.attrib['name'].replace('-', '_').upper()

    if name == "return":
        return "@\"return\""
    return name    

generate(sys.argv[1])