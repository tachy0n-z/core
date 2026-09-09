return table.freeze{
    -- e.g. FakeHealth = 100
    -- WARNING: no nested tables; they do not replicate to clients!
    -- ANOTHER WARNING: numeric keys are risky, prefer string-keys!
}