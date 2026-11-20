#!/usr/bin/env python3
"""Small dependency-free Z80 assembler for the instructions used by Tavli 48K.
Outputs BIN and a Spectrum TAP with auto-start BASIC loader.
The .asm remains compatible with normal Z80 assemblers such as Pasmo.
"""
import re, os, struct, sys, ast
from pathlib import Path
ROOT=Path(__file__).resolve().parent
SRC=ROOT/'tavli48k.asm'
ORIGIN=43000
REG8={'b':0,'c':1,'d':2,'e':3,'h':4,'l':5,'(hl)':6,'a':7}
REG16={'bc':0,'de':1,'hl':2,'sp':3}
COND={'nz':0,'z':1,'nc':2,'c':3,'po':4,'pe':5,'p':6,'m':7}
class AsmError(Exception): pass

def splitargs(s):
    out=[]; cur=''; quoted=False
    for c in s:
        if c in ("'",'"'): quoted=not quoted
        if c==',' and not quoted: out.append(cur.strip()); cur=''
        else: cur+=c
    if cur.strip(): out.append(cur.strip())
    return out

def expr(s, syms, passno):
    s=s.strip()
    s=re.sub(r'\$([0-9a-fA-F]+)',lambda m:str(int(m[1],16)),s)
    s=re.sub(r'(?<![\w])([0-9a-fA-F]+)h\b',lambda m:str(int(m[1],16)),s, flags=re.I)
    if len(s)==3 and s[0]=="'" and s[-1]=="'":return ord(s[1])
    def evaln(n):
        if isinstance(n,ast.Expression):return evaln(n.body)
        if isinstance(n,ast.Constant) and isinstance(n.value,int):return n.value
        if isinstance(n,ast.Name):
            if n.id.lower() in syms: return syms[n.id.lower()]
            if passno==1:return 0
            raise AsmError('unknown symbol '+n.id)
        if isinstance(n,ast.BinOp):
            a,b=evaln(n.left),evaln(n.right)
            if isinstance(n.op,ast.Add):return a+b
            if isinstance(n.op,ast.Sub):return a-b
            if isinstance(n.op,ast.Mult):return a*b
            if isinstance(n.op,ast.LShift):return a<<b
            if isinstance(n.op,ast.RShift):return a>>b
            if isinstance(n.op,ast.BitAnd):return a&b
            if isinstance(n.op,ast.BitOr):return a|b
        if isinstance(n,ast.UnaryOp):
            if isinstance(n.op,ast.USub):return -evaln(n.operand)
            if isinstance(n.op,ast.UAdd):return evaln(n.operand)
        raise AsmError('unsupported expression: '+s)
    try:return evaln(ast.parse(s,mode='eval'))
    except (SyntaxError,ValueError) as e:raise AsmError(f'bad expression {s}: {e}')

def word(n):return [n&255,(n>>8)&255]
def opencode(m,ars,pc,syms,p):
    x=ars; one=x[0].lower() if x else ''; two=x[1].lower() if len(x)>1 else ''
    val=lambda e:expr(e,syms,p)
    addr=lambda e:word(val(e))
    def disp(e, length):
        offset=val(e)-(pc+length)
        if p==2 and not -128<=offset<=127: raise AsmError(f'relative branch {offset} out of range')
        return offset&255
    if m=='nop':return [0]
    if m=='halt':return [0x76]
    if m=='ei':return [0xfb]
    if m=='di':return [0xf3]
    if m=='ldir':return [0xed,0xb0]
    if m=='cpl':return [0x2f]
    if m=='scf':return [0x37]
    if m=='ccf':return [0x3f]
    if m=='rrca':return [0x0f]
    if m=='rlca':return [0x07]
    if m=='rra':return [0x1f]
    if m=='rla':return [0x17]
    if m=='ex':
        if x==['de','hl']:return [0xeb]
        raise AsmError('EX')
    if m=='rst':
        a=val(one)
        if a%8 or a>56:raise AsmError('RST')
        return [0xc7+a]
    if m=='ret':
        if not x:return [0xc9]
        if one in COND:return [0xc0+8*COND[one]]
        raise AsmError('RET')
    if m in ('push','pop'):
        rr={'bc':0,'de':1,'hl':2,'af':3}
        if one not in rr: raise AsmError(m)
        return [ (0xc5 if m=='push' else 0xc1)+16*rr[one]]
    if m in ('jp','call','jr'):
        if m=='jr':
            if len(x)==1:return [0x18,disp(one,2)]
            if one not in ('nz','z','nc','c'):raise AsmError('JR condition')
            return [0x20+8*COND[one],disp(two,2)]
        if len(x)==1:return [0xc3 if m=='jp' else 0xcd]+addr(one)
        return [(0xc2 if m=='jp' else 0xc4)+8*COND[one]]+addr(two)
    if m=='djnz':return [0x10,disp(one,2)]
    if m=='in':
        if x==['a','(c)']:return [0xed,0x78]
        raise AsmError('IN')
    if m=='out':
        if x==['(c)','a']:return [0xed,0x79]
        if len(x)==2 and x[1]=='a' and x[0].startswith('(') and x[0].endswith(')'):
            return [0xd3,val(x[0][1:-1])&255]
        raise AsmError('OUT')
    if m=='ld':
        if len(x)!=2:raise AsmError('LD args')
        if one in REG8 and two in REG8:return [0x40+8*REG8[one]+REG8[two]]
        if one in REG8 and two not in ('(bc)','(de)') and not (two.startswith('(') and two.endswith(')')):
            return [0x06+8*REG8[one],val(two)&255]
        if one in REG16 and not two.startswith('('):return [0x01+16*REG16[one]]+addr(two)
        if one in ('ix','iy') and not two.startswith('('):return [0xdd if one=='ix' else 0xfd,0x21]+addr(two)
        if one=='a' and two=='(bc)':return [0x0a]
        if one=='a' and two=='(de)':return [0x1a]
        if one=='(bc)' and two=='a':return [0x02]
        if one=='(de)' and two=='a':return [0x12]
        if one=='a' and two.startswith('(') and two.endswith(')'):return [0x3a]+addr(two[1:-1])
        if two=='a' and one.startswith('(') and one.endswith(')'):return [0x32]+addr(one[1:-1])
        if one=='hl' and two.startswith('(') and two.endswith(')'):return [0x2a]+addr(two[1:-1])
        if two=='hl' and one.startswith('(') and one.endswith(')'):return [0x22]+addr(one[1:-1])
        if one in ('bc','de','sp') and two.startswith('(') and two.endswith(')'):
            return [0xed,0x4b+0x10*REG16[one]]+addr(two[1:-1])
        if two in ('bc','de','sp') and one.startswith('(') and one.endswith(')'):
            return [0xed,0x43+0x10*REG16[two]]+addr(one[1:-1])
        raise AsmError(f'LD {x}')
    if m in ('inc','dec'):
        if one in REG8:return [(0x04 if m=='inc' else 0x05)+8*REG8[one]]
        if one in REG16:return [(0x03 if m=='inc' else 0x0b)+16*REG16[one]]
        raise AsmError('INC/DEC')
    if m in ('and','or','xor','cp','sub','add','adc','sbc'):
        if m=='add' and one=='hl' and two in REG16:return [0x09+16*REG16[two]]
        if m in ('add','adc','sbc'):
            if one!='a':raise AsmError('arithmetic requires A')
            one=two
        base={'add':0x80,'adc':0x88,'sub':0x90,'sbc':0x98,'and':0xa0,'xor':0xa8,'or':0xb0,'cp':0xb8}[m]
        imm={'add':0xc6,'adc':0xce,'sub':0xd6,'sbc':0xde,'and':0xe6,'xor':0xee,'or':0xf6,'cp':0xfe}[m]
        if one in REG8:return [base+REG8[one]]
        return [imm,val(one)&255]
    if m in ('sla','sra','srl','rr','rl','rrc','rlc'):
        base={'rlc':0,'rrc':8,'rl':16,'rr':24,'sla':32,'sra':40,'srl':56}[m]
        return [0xcb,base+REG8[one]]
    if m in ('bit','set','res'):
        base={'bit':0x40,'res':0x80,'set':0xc0}[m]
        return [0xcb,base+8*val(one)+REG8[two]]
    raise AsmError('unknown instruction '+m)

def parse(path):
    rows=[]
    for fn in [path]:
        for number,s in enumerate(Path(fn).read_text().splitlines(),1):
            s=s.split(';')[0].strip()
            if not s:continue
            rows.append((number,s))
    return rows

def assemble():
    rows=parse(SRC)
    syms={}
    output=bytearray()
    for passno in (1,2):
        pc=ORIGIN
        if passno==2:output.clear()
        for lineno,line in rows:
            try:
                labelmatch=re.match(r'^([A-Za-z_][\w]*):',line)
                if labelmatch:
                    label=labelmatch[1]
                    line=line[labelmatch.end():]
                    if passno==1:
                        if label.strip().lower() in syms:raise AsmError('duplicate label '+label)
                        syms[label.strip().lower()]=pc
                    line=line.strip()
                    if not line:continue
                match=re.match(r'^([A-Za-z_][\w]*)\s+equ\s+(.+)$',line,re.I)
                if match:
                    if passno==1:syms[match[1].lower()]=expr(match[2],syms,passno)
                    continue
                parts=line.split(None,1)
                m=parts[0].lower()
                arg=parts[1].strip() if len(parts)>1 else ''
                if m=='org':
                    v=expr(arg,syms,passno)
                    if v!=ORIGIN:raise AsmError('only ORG 43000 supported')
                    pc=v;continue
                if m=='end':break
                if m=='incbin':
                    v=(ROOT/arg.strip('"\'')).read_bytes()
                elif m=='db':
                    v=[]
                    for a in splitargs(arg):
                        if a.startswith('"') and a.endswith('"'):
                            v+=list(a[1:-1].encode('ascii'))
                        else:v.append(expr(a,syms,passno)&255)
                elif m=='dw':
                    v=[]
                    for a in splitargs(arg):v+=word(expr(a,syms,passno))
                elif m=='ds':
                    a=splitargs(arg);v=[expr(a[1],syms,passno)&255 if len(a)>1 else 0]*expr(a[0],syms,passno)
                else:v=opencode(m,splitargs(arg.lower()),pc,syms,passno)
                pc+=len(v)
                if passno==2:output.extend(v)
            except Exception as err:raise AsmError(f'line {lineno}: {line}\n{err}') from err
    if len(output)>0x7f00:raise AsmError('Code too big for 48K segment')
    return output,syms

def tapblock(flag,content):
    b=bytes([flag])+content
    checksum=0
    for x in b:checksum^=x
    raw=b+bytes([checksum])
    return struct.pack('<H',len(raw))+raw

def make_tap(payload):
    # tokenized Spectrum BASIC: 10 CLEAR 32767 : LOAD "" CODE : RANDOMIZE USR 32768
    # 253 CLEAR, 239 LOAD, 175 CODE, 249 RANDOMIZE, 192 USR
    # encoded BASIC number: 14 + 5 bytes numeric constant.
    def num(n):return str(n).encode('ascii')+bytes([14,0,0,n&255,(n>>8)&255,0])
    program=bytes([253,32])+num(32767)+bytes([ord(':'),239,32,34,34,32,175,ord(':'),249,32,192,32])+num(32768)+bytes([13])
    line=struct.pack('>H',10)+struct.pack('<H',len(program))+program
    head_bas=bytes([0])+b'TAVLI48K  '.ljust(10,b' ')+struct.pack('<H',len(line))+struct.pack('<H',10)+struct.pack('<H',len(line))
    head_code=bytes([3])+b'TAVLI-CODE'.ljust(10,b' ')+struct.pack('<H',len(payload))+struct.pack('<H',ORIGIN)+struct.pack('<H',0x8000)
    return tapblock(0,head_bas)+tapblock(255,line)+tapblock(0,head_code)+tapblock(255,payload)

if __name__=='__main__':
    try:
        data,sym=assemble()
        (ROOT/'tavli48k.bin').write_bytes(data)
        (ROOT/'tavli48k.tap').write_bytes(make_tap(data))
        (ROOT/'symbols.txt').write_text(''.join(f'{k:26s} {v:04X}\n' for k,v in sym.items()))
        print(f'Assembled {len(data):,} bytes at 0x{ORIGIN:04X}; end 0x{ORIGIN+len(data):04X}; TAP created')
    except Exception as e:
        print(e,file=sys.stderr);sys.exit(1)
