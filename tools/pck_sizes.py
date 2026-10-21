"""What a Godot 4 pack holds, by the source file each entry was imported from.

    python3 tools/pck_sizes.py build.pck [needs.txt]

Prints the biggest folders; with tools/pack_needs.gd's list, also what in the
pack nothing reaches (the candidates for export_presets.cfg's exclude_filter).
"""
import os,struct,collections,re,json
def read_pck(P):
    f=open(P,"rb"); f.read(4)
    ver,ma,mi,pa=struct.unpack("<4I",f.read(16)); flags,base=struct.unpack("<IQ",f.read(12))
    diroff,=struct.unpack("<Q",f.read(8)); f.seek(diroff)
    n,=struct.unpack("<I",f.read(4)); out=[]
    for i in range(n):
        l,=struct.unpack("<I",f.read(4)); p=f.read(l).rstrip(b"\0").decode()
        off,sz=struct.unpack("<QQ",f.read(16)); f.read(16); fl,=struct.unpack("<I",f.read(4))
        out.append((p,off+base,sz))
    return f,out
def nm(p): return p[6:] if p.startswith("res://") else p
def by_source(P):
    f,files=read_pck(P)
    owner={}
    for p,o,s in files:
        if p.endswith(".import") or p.endswith(".remap"):
            f.seek(o); t=f.read(s).decode(errors="replace")
            for m in re.findall(r'"res://(\.godot/imported/[^"]+)"',t):
                owner[m]=nm(p).rsplit(".",1)[0]
    per=collections.Counter()
    for p,o,s in files:
        q=nm(p); per[owner.get(q,q)]+=s
    return per
def group(per,depth=2):
    agg=collections.Counter()
    for src,s in per.items():
        parts=src.split("/")
        d=depth+1 if parts[0] in ("unverified","assets") else depth
        k="/".join(parts[:d]) if len(parts)>d else src
        agg[k]+=s
    return agg


if __name__ == "__main__":
    import sys
    per = by_source(sys.argv[1])
    print("total %.0f MB" % (sum(per.values()) / 1e6))
    for k, v in group(per, 1).most_common(30):
        print("%8.1f MB  %s" % (v / 1e6, k))
    if len(sys.argv) > 2:
        need = set(l[6:] for l in open(sys.argv[2]).read().splitlines())
        idle = collections.Counter({k: v for k, v in per.items() if not k.startswith(".godot")
                and k != "project.binary" and k not in need and k.rsplit(".", 1)[0] not in need})
        print("\nnot reached: %.0f MB" % (sum(idle.values()) / 1e6))
        for k, v in group(idle, 1).most_common(30):
            print("%8.1f MB  %s" % (v / 1e6, k))
