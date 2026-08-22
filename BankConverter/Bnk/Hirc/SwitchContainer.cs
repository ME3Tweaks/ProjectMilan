namespace BankConverter.Bnk.Hirc;

public sealed class SwitchPackage
{
    public uint SwitchId;
    public List<uint> NodeIds = new();
}

public sealed class SwitchNodeParams
{
    public uint NodeId;
    public bool IsFirstOnly, ContinuePlayback;
    public byte OnSwitchMode;
    public int FadeOutTime, FadeInTime;
}

/// <summary>CAkSwitchCntr / eHircType 0x06.</summary>
public sealed class SwitchContainer
{
    public uint Id;
    public NodeBaseParams NodeBase = null!;
    public byte GroupType;
    public uint GroupId, DefaultSwitch;
    public bool IsContinuousValidation;
    public List<uint> ChildIds = new();
    public List<SwitchPackage> SwitchList = new();
    public List<SwitchNodeParams> Params = new();

    public static SwitchContainer ReadV56(BankReader r)
    {
        var c = new SwitchContainer { Id = r.U32() };
        c.NodeBase = NodeBaseParams.ReadV56(r);

        c.GroupType = (byte)r.U32();
        c.GroupId = r.U32();
        c.DefaultSwitch = r.U32();
        c.IsContinuousValidation = r.U8() != 0;

        var childCount = r.U32();
        for (var i = 0; i < childCount; i++) c.ChildIds.Add(r.U32());

        var groupCount = r.U32();
        for (var i = 0; i < groupCount; i++)
        {
            var pkg = new SwitchPackage { SwitchId = r.U32() };
            var itemCount = r.U32();
            for (var j = 0; j < itemCount; j++) pkg.NodeIds.Add(r.U32());
            c.SwitchList.Add(pkg);
        }

        var paramCount = r.U32();
        for (var i = 0; i < paramCount; i++)
        {
            var p = new SwitchNodeParams { NodeId = r.U32() };
            p.IsFirstOnly = r.U8() != 0;
            p.ContinuePlayback = r.U8() != 0;
            p.OnSwitchMode = (byte)r.U32();
            p.FadeOutTime = r.S32();
            p.FadeInTime = r.S32();
            c.Params.Add(p);
        }

        return c;
    }

    public byte[] WriteV134(Func<uint, uint> remapBusId)
    {
        var w = new BankWriter();
        w.U32(Id);
        NodeBase.WriteV134(w, remapBusId);

        w.U8(GroupType);
        w.U32(GroupId);
        w.U32(DefaultSwitch);
        w.U8((byte)(IsContinuousValidation ? 1 : 0));

        w.U32((uint)ChildIds.Count);
        foreach (var id in ChildIds) w.U32(id);

        w.U32((uint)SwitchList.Count);
        foreach (var pkg in SwitchList)
        {
            w.U32(pkg.SwitchId);
            w.U32((uint)pkg.NodeIds.Count);
            foreach (var id in pkg.NodeIds) w.U32(id);
        }

        w.U32((uint)Params.Count);
        foreach (var p in Params)
        {
            w.U32(p.NodeId);
            byte bits1 = 0;
            if (p.IsFirstOnly) bits1 |= 1 << 0;
            if (p.ContinuePlayback) bits1 |= 1 << 1;
            w.U8(bits1);
            w.U8((byte)(p.OnSwitchMode & 0x7));
            w.S32(p.FadeOutTime);
            w.S32(p.FadeInTime);
        }

        return w.ToArray();
    }
}
