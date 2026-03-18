-- Simple native text field test
print("native available:", native ~= nil)
print("native.newTextField available:", native and native.newTextField ~= nil)

if native and native.newTextField then
    print("Creating text field...")
    local ok, result = pcall(function()
        local field = native.newTextField(100, 100, 200, 40)
        print("Field created:", field ~= nil)
        if field then
            field.text = "test"
            print("Text set successfully")
        end
        return field
    end)
    if ok then
        print("SUCCESS")
    else
        print("FAILED:", result)
    end
else
    print("native.newTextField not available")
end
