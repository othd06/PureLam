
import std/osproc
import std/json
import std/cmdline
import std/streams

assert(paramCount() == 1, "Intended use: PureLamTest <path-to-test-file>")

var
    repl = startProcess(
        command = "./PureLam",
        args = @["repl"],
        options = {poUsePath}
    )
    all_passed: bool = true
let
    tests: JsonNode = parseJson(readFile(commandLineParams()[0]))
assert(tests.kind == JArray, "Test file must be an array of JSON objects with fields \"Name\", \"Run\", and \"Expect\"")
proc writeRepl(line: string) {.inline.} =
    repl.inputStream().writeLine(line)
    repl.inputStream().flush()
proc readRepl(): string {.inline.} =
    repl.outputStream().readLine()
assert(readRepl() == "PureLam REPL Interface:")
for i in 0..<tests.len:
    let test = tests[i]
    if test.kind == JString and test.getStr() == "reset":
        writeRepl("quit")
        discard repl.waitForExit()
        repl.close()
        repl = startProcess(
            command = "./PureLam",
            args = @["repl"],
            options = {poUsePath}
        )
        assert(readRepl() == "PureLam REPL Interface:")
        continue
    assert(test.kind == JObject)
    writeRepl(test["Run"].getStr())
    let result = readRepl()
    if result == test["Expect"].getStr():
        echo("PASSED: " & test["Name"].getStr())
    else:
        echo("FAILED: " & test["Name"].getStr())
        echo("    Expected: " & test["Expect"].getStr())
        echo("    Got: " & result)
        all_passed = false
        break #since the internal state of the interpreter may be not what is expected going forward we just break at this point and solve bugs one by one

if all_passed: echo("ALL TESTS PASSED")    

writeRepl("quit")
discard repl.waitForExit()
repl.close()