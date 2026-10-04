-- Small strict JSON reader; never executes mod library contents as Lua.
local M = {}
M.null = {}
function M.decode(source)
    local pos = 1
    local parse
    local function ws() local _, last = source:find("^[ \t\r\n]*", pos); pos = (last or pos-1)+1 end
    local function string_value()
        assert(source:sub(pos,pos)=='"', "Expected JSON string")
        pos=pos+1
        local out={}
        while pos<=#source do
            local ch=source:sub(pos,pos);pos=pos+1
            if ch=='"' then return table.concat(out) end
            if ch=='\\' then
                local escape=source:sub(pos,pos);pos=pos+1
                local escapes={['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
                if escape=='u' then
                    local hex=source:sub(pos,pos+3);assert(hex:match('^%x%x%x%x$'),'Invalid JSON Unicode escape');pos=pos+4
                    local code=tonumber(hex,16)
                    if code>=0xD800 and code<=0xDBFF then
                        assert(source:sub(pos,pos+1)=='\\u','Missing low surrogate');pos=pos+2
                        local lowhex=source:sub(pos,pos+3);assert(lowhex:match('^%x%x%x%x$'),'Invalid low surrogate');pos=pos+4
                        local low=tonumber(lowhex,16);assert(low>=0xDC00 and low<=0xDFFF,'Invalid low surrogate')
                        code=0x10000+(code-0xD800)*0x400+low-0xDC00
                    elseif code>=0xDC00 and code<=0xDFFF then error('Unexpected low surrogate') end
                    out[#out+1]=utf8.char(code)
                else assert(escapes[escape],'Invalid JSON escape');out[#out+1]=escapes[escape] end
            else assert(ch:byte()>=32,'JSON control character');out[#out+1]=ch end
        end
        error('Unterminated JSON string')
    end
    parse=function(depth)
        assert(depth<64,'JSON nesting limit');ws()
        local ch=source:sub(pos,pos)
        if ch=='"' then return string_value() end
        if ch=='[' or ch=='{' then
            pos=pos+1;ws();local result={};local ending=ch=='[' and ']' or '}'
            if source:sub(pos,pos)==ending then pos=pos+1;return result end
            while true do
                if ch=='{' then
                    local key=string_value();ws();assert(source:sub(pos,pos)==':','Missing JSON colon');pos=pos+1
                    assert(result[key]==nil,'Duplicate JSON key');result[key]=parse(depth+1)
                else result[#result+1]=parse(depth+1) end
                ws();local delimiter=source:sub(pos,pos);pos=pos+1
                if delimiter==ending then return result end
                assert(delimiter==',','Missing JSON separator');ws()
            end
        end
        for literal,value in pairs({['true']=true,['false']=false,['null']=M.null}) do
            if source:sub(pos,pos+#literal-1)==literal then pos=pos+#literal;return value end
        end
        local token=source:match('^-?%d+%.?%d*[eE]?[+-]?%d*',pos)
        assert(token and tonumber(token),'Invalid JSON value');pos=pos+#token;return tonumber(token)
    end
    if source:sub(1,3)=='\239\187\191' then pos=4 end
    local result=parse(0);ws();assert(pos>#source,'Trailing JSON content');return result
end
return M
