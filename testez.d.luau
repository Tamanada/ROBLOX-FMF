-- testez.d.luau — TestEZ global declarations for luau-lsp analysis.
-- TestEZ injects these into spec environments at runtime; declaring them
-- here lets `luau-lsp analyze` typecheck tests/*.spec.luau.

declare function afterAll(callback: () -> ()): ()
declare function afterEach(callback: () -> ()): ()
declare function beforeAll(callback: () -> ()): ()
declare function beforeEach(callback: () -> ()): ()
declare function describe(phrase: string, callback: () -> ()): ()
declare function describeFOCUS(phrase: string, callback: () -> ()): ()
declare function describeSKIP(phrase: string, callback: () -> ()): ()
declare function expect(value: any): any
declare function FIXME(optionalMessage: string?): ()
declare function FOCUS(): ()
declare function it(phrase: string, callback: () -> ()): ()
declare function itFOCUS(phrase: string, callback: () -> ()): ()
declare function itFIXME(phrase: string, callback: () -> ()): ()
declare function itSKIP(phrase: string, callback: () -> ()): ()
declare function SKIP(): ()
