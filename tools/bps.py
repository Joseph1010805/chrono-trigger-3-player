import struct, zlib, sys
def num(b,i):
    d=0;s=1
    while True:
        x=b[i];i+=1;d+=(x&0x7f)*s
        if x&0x80: return d,i
        s<<=7;d+=s
def apply(src, patch):
    assert patch[:4]==b'BPS1'
    i=4; ss,i=num(patch,i); ts,i=num(patch,i); ms,i=num(patch,i); i+=ms
    out=bytearray(ts); o=0; sr=0; tr=0; end=len(patch)-12
    while i<end:
        d,i=num(patch,i); act=d&3; ln=(d>>2)+1
        if act==0: out[o:o+ln]=src[o:o+ln]; o+=ln
        elif act==1: out[o:o+ln]=patch[i:i+ln]; i+=ln; o+=ln
        else:
            d2,i=num(patch,i); off=(-1 if d2&1 else 1)*(d2>>1)
            if act==2:
                sr+=off
                out[o:o+ln]=src[sr:sr+ln]; sr+=ln; o+=ln
            else:
                tr+=off
                for k in range(ln): out[o]=out[tr]; o+=1; tr+=1
    sc,tc,pc=struct.unpack('<III',patch[-12:])
    assert zlib.crc32(src)==sc, 'source crc'
    assert zlib.crc32(out)==tc, 'target crc'
    return bytes(out)
if __name__=='__main__':
    s=open(sys.argv[1],'rb').read(); p=open(sys.argv[2],'rb').read()
    open(sys.argv[3],'wb').write(apply(s,p)); print('ok')
