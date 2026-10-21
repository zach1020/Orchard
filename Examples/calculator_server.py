#!/usr/bin/env python3
"""Small, dependency-free MCP stdio server for testing Orchard."""
import json
import sys

for line in sys.stdin:
    try:
        request = json.loads(line)
        if "id" not in request:
            continue
        method = request.get("method")
        if method == "initialize":
            result = {"protocolVersion": request.get("params", {}).get("protocolVersion", "2025-11-25"), "capabilities": {"tools": {}}, "serverInfo": {"name": "orchard-demo", "version": "1.0"}}
        elif method == "tools/list":
            result = {"tools": [{"name": "multiply_numbers", "description": "Multiply two numbers using the demo MCP server.", "inputSchema": {"type": "object", "properties": {"a": {"type": "number"}, "b": {"type": "number"}}, "required": ["a", "b"]}}]}
        elif method == "tools/call":
            params = request.get("params", {})
            if params.get("name") != "multiply_numbers":
                raise ValueError("Unknown tool")
            args = params.get("arguments", {})
            result = {"content": [{"type": "text", "text": str(float(args["a"]) * float(args["b"]))}], "isError": False}
        elif method == "ping":
            result = {}
        else:
            raise ValueError("Unsupported method")
        print(json.dumps({"jsonrpc": "2.0", "id": request["id"], "result": result}), flush=True)
    except Exception as error:
        print(json.dumps({"jsonrpc": "2.0", "id": request.get("id"), "error": {"code": -32602, "message": str(error)}}), flush=True)
