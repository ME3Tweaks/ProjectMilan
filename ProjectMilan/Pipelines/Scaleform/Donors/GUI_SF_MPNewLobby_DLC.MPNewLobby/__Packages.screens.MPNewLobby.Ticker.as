class screens.MPNewLobby.Ticker extends com.SFXMovieClip
{
    var attachMovie;
    var getNextHighestDepth;
    var m_aClips;
    var m_aOldTickerData;
    var ScrollIntervalId = 0;
    var SCROLL_DELAY = 4000;
    function Ticker()
    {
        super();
    }
    function SetTickerData(aNewTickerData)
    {
        var _loc6_ = false;
        if(this.m_aOldTickerData.length != aNewTickerData.length)
        {
            _loc6_ = true;
        }
        var _loc4_ = 0;
        while(_loc4_ < aNewTickerData.length && !_loc6_)
        {
            if(this.m_aOldTickerData[_loc4_].Type != aNewTickerData[_loc4_].Type || this.m_aOldTickerData[_loc4_].Value != aNewTickerData[_loc4_].Value)
            {
                _loc6_ = true;
            }
            _loc4_ += 1;
        }
        if(!_loc6_)
        {
            return undefined;
        }
        this.m_aOldTickerData = aNewTickerData;
        var _loc5_;
        if(this.m_aClips == null)
        {
            this.m_aClips = new Array();
        }
        else
        {
            _loc5_ = 0;
            while(_loc5_ < this.m_aClips.length)
            {
                if(this.m_aClips[_loc5_] != null)
                {
                    this.m_aClips[_loc5_].removeMovieClip();
                }
                _loc5_ += 1;
            }
            this.m_aClips.length = 0;
        }
        _loc4_ = 0;
        var _loc3_;
        while(_loc4_ < aNewTickerData.length)
        {
            if(aNewTickerData[_loc4_].Value > 0)
            {
                _loc3_ = this.attachMovie("TickerAnim","Clip" + this.m_aClips.length,this.getNextHighestDepth());
                _loc3_.gotoAndStop("HideComplete");
                _loc3_.Plate.gotoAndStop(aNewTickerData[_loc4_].Type);
                _loc3_.Plate.Value.text = aNewTickerData[_loc4_].Value;
                _loc3_.Plate.Value.textAutoSize = "shrink";
                this.m_aClips.push(_loc3_);
            }
            _loc4_ += 1;
        }
        this.m_aClips[0].gotoAndStop("RevealComplete");
        if(this.m_aClips.length > 1)
        {
            this.UpdateScroll(true,0);
        }
    }
    function UpdateScroll(bStartNewScroll, nCurrentClip)
    {
        if(this.ScrollIntervalId > 0)
        {
            clearInterval(this.ScrollIntervalId);
            if(!bStartNewScroll)
            {
                this.m_aClips[nCurrentClip].gotoAndPlay("Hide");
                nCurrentClip += 1;
                nCurrentClip %= this.m_aClips.length;
                this.m_aClips[nCurrentClip].gotoAndPlay("Reveal");
            }
        }
        this.ScrollIntervalId = setInterval(this,"UpdateScroll",this.SCROLL_DELAY,false,nCurrentClip);
    }
}
