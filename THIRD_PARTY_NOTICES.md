# Third-Party Notices

This document lists third-party libraries and code included in the Aardrune project, along with their licenses and attribution information.

---

## CBOR (Concise Binary Object Representation)

**Files:**
- `aardrune/cbor.lua`
- `aardrune/cbor.bignum.lua`

**Author:** Zash  
**Homepage:** https://www.zash.se/lua-cbor.html  
**LuaRocks:** https://luarocks.org/modules/zash/lua-cbor  
**License:** MIT License  

**Description:**  
Pure Lua implementation of CBOR (RFC 7049), a compact data serialization format. This library provides encoding and decoding of CBOR data structures for data persistence in the mob database, GMCP mapper, and equipment tracking modules.

**Used By:**
- `robbo_mobdb.lua` - Mobile database serialization
- `robbo_gmcp_mapper.lua` - Room/exit data persistence
- `robbo_equipment.lua` - Equipment tracking data

**License Text:**

```
MIT License

Copyright (c) <year> Zash

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

*Note: The exact copyright year should be verified from the original source.*

---

## RFC 7049 - CBOR Specification

**Standard:** RFC 7049  
**Title:** Concise Binary Object Representation (CBOR)  
**Authors:** C. Bormann, P. Hoffman  
**Organization:** Internet Engineering Task Force (IETF)  
**Published:** October 2013  
**Status:** Proposed Standard (now obsoleted by RFC 8949)  
**URL:** https://tools.ietf.org/html/rfc7049  

**Description:**  
The CBOR library implements the data format specified in RFC 7049. This RFC defines a data format that can encode common data types in a compact binary representation.

**License:**  
RFC documents are governed by the IETF Trust's Legal Provisions Relating to IETF Documents. See https://trustee.ietf.org/license-info for details.

---

## Serialize Library (MUSHclient)

**Files:**
- `aardrune/serialize.lua`

**Author:** Nick Gammon  
**Source:** http://www.gammon.com.au/forum/?id=4960  
**License:** Free to use, modify, and distribute  

**Description:**  
Lua table serialization library from MUSHclient. Converts Lua tables to executable code strings and vice versa. Used for simple data persistence where CBOR is not needed. Based on examples from "Programming in Lua" chapter 12.1.2.

**Used By:**
- `robbo_common.lua` - Activity state persistence, debug output

**Note:**  
This is a well-known utility library from the MUSHclient community. No formal license file exists, but Nick Gammon has made it freely available for use.

---

## Rune MUD Client

**Project:** Rune MUD Client  
**URL:** https://www.runeclient.com/  

**Description:**  
Aardrune is designed as an add-on module suite for the Rune MUD client. Rune provides the scripting API and execution environment that makes these modules possible.

**Note:**  
Rune itself is commercial software. These add-on modules are separate works created by the community.

---

## Aardwolf MUD

**Project:** Aardwolf MUD  
**URL:** http://www.aardwolf.com/  

**Description:**  
While not directly included in this codebase, Aardrune is primarily designed for use with Aardwolf MUD. Many features leverage Aardwolf-specific GMCP extensions and color codes.

---

## Adding New Third-Party Code

When adding new third-party libraries to this project:

1. **Verify license compatibility** - Ensure the license allows inclusion in this project
2. **Add entry to this file** - Document author, license, and usage
3. **Include license text** - Add full license text when required
4. **Preserve headers** - Keep original copyright/license headers in source files
5. **Update README.md** - Mention the new dependency in the appropriate section

Example template:

```markdown
## Library Name

**Files:**
- `path/to/library.lua`

**Author:** Author Name  
**Homepage:** URL  
**License:** License Type  

**Description:**  
Brief description of what the library does.

**Used By:**
- List of modules that depend on this library

**License Text:**
[Include full license if required]
```

---

**Last Updated:** 2026-11-07  
**Maintained By:** Project maintainers
