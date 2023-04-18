del wudebug.exe
tasm /m9 sdebug.asm
tasm /m9 main.asm
tasm /m9 slib.asm
tlink32 -Sc:10000 main disasm insnsd sync slib sdebug
ren main.exe wudebug.exe
stubit -m_float wudebug.exe
