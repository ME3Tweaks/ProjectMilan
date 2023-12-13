class com.SFXScreen extends com.SFXMovieClip
{
    static var ScreenLayout;
    static var IsMPClient;
    static var HD_WIDTH = 1280;
    static var HD_HEIGHT = 720;
    static var c_RegisteredCallback_HandleInputConfigurations_func = null;
    static var c_RegisteredCallback_HandleInputConfigurations_obj = null;
    static var c_ResizeListener = null;
    static var c_RegisteredCallback_OnStageResize = null;
    function SFXScreen()
    {
        super();
    }
    static function RegisterCallback_HandleInputConfigurations(i_obj, i_func)
    {
        com.SFXScreen.c_RegisteredCallback_HandleInputConfigurations_func = i_func;
        com.SFXScreen.c_RegisteredCallback_HandleInputConfigurations_obj = i_obj;
    }
    static function HandleInputConfigurations(bMenuAdvanceSwapped, bStickSouthpaw, bTriggerSouthpaw, bTriggersShouldersSwapped)
    {
        if(com.SFXScreen.c_RegisteredCallback_HandleInputConfigurations_func != null)
        {
            var _loc6_ = com.SFXScreen.c_RegisteredCallback_HandleInputConfigurations_obj != null ? com.SFXScreen.c_RegisteredCallback_HandleInputConfigurations_obj : _root;
            com.SFXScreen.c_RegisteredCallback_HandleInputConfigurations_func.call(_loc6_,bMenuAdvanceSwapped,bStickSouthpaw,bTriggerSouthpaw,bTriggersShouldersSwapped);
        }
    }
    static function PrepareScreen(sScaleMode)
    {
        _global.gfxExtensions = true;
        sScaleMode = sScaleMode != undefined ? sScaleMode : "showAll";
        if(_global.SFX != undefined)
        {
            _global.SFX.SetScaleMode(sScaleMode);
        }
        else
        {
            Stage.scaleMode = sScaleMode;
        }
    }
    function onLoad()
    {
        com.SFXScreen.PrepareScreen();
        com.SFXScreen.RegisterCallback_HandleInputConfigurations(this,this.OnHandleInputConfigurations);
        com.SFXScreen.ScreenLayout = Number(flash.external.ExternalInterface.call("GetScreenLayout"));
        com.SFXScreen.IsMPClient = _global.SFX.IsMPClient;
        _root.PrintMovieHierarchy = com.Utilities.PrintMovieHierarchy;
    }
    function OnHandleInputConfigurations(bMenuAdvanceSwapped, bStickSouthpaw, bTriggerSouthpaw, bTriggersShouldersSwapped)
    {
    }
    static function GetVisibleRect()
    {
        if(Stage.visibleRect == undefined)
        {
            return new flash.geom.Rectangle(0,0,Stage.width,Stage.height);
        }
        return Stage.visibleRect;
    }
    static function GetSafeRect()
    {
        if(Stage.safeRect == undefined)
        {
            return new flash.geom.Rectangle(0,0,Stage.width,Stage.height);
        }
        return Stage.safeRect;
    }
    static function GetOriginalRect()
    {
        if(Stage.originalRect == undefined)
        {
            Stage.originalRect = new flash.geom.Rectangle(0,0,Stage.width,Stage.height);
        }
        return Stage.originalRect;
    }
    static function CheckedScaleUpdate()
    {
        if(Stage.scaleMode == "noScale")
        {
            if(_global.SFX == undefined)
            {
                return false;
            }
            Stage.align = "TL";
            var _loc2_ = _global.SFX.GetViewport();
            var _loc3_ = com.SFXScreen.GetOriginalRect();
            var _loc4_ = 1.0001;
            if(_loc2_.width < _loc3_.width)
            {
                _loc4_ = _loc3_.width / _loc2_.width;
            }
            return _global.SFX.SetMovieScale(_loc4_);
        }
        return false;
    }
    static function set OnResize(callback)
    {
        com.SFXScreen.c_RegisteredCallback_OnStageResize = callback;
        if(com.SFXScreen.c_ResizeListener == null)
        {
            com.SFXScreen.c_ResizeListener = new Object();
            com.SFXScreen.c_ResizeListener.onResize = function()
            {
                if(com.SFXScreen.c_RegisteredCallback_OnStageResize != null)
                {
                    com.SFXScreen.c_RegisteredCallback_OnStageResize();
                }
            };
            Stage.addListener(com.SFXScreen.c_ResizeListener);
        }
    }
    static function get OnResize()
    {
        return com.SFXScreen.c_RegisteredCallback_OnStageResize;
    }
    static function GetPlatformLayout()
    {
        if(_global.SFX == undefined)
        {
            trace("SFXScreen::GetPlatformLayout: Failed to find SFX Object (Ignore this message during .swf publishing)");
            return com.XPlatform.PC;
        }
        return _global.SFX.PlatformLayout;
    }
    static function PlayGUISound(sSound)
    {
        if(_global.SFX == undefined)
        {
            trace("SFXScreen::PlayGUISound: Failed to find SFX Object (Ignore this message during .swf publishing)");
            return undefined;
        }
        _global.SFX.PlayGUISound(sSound);
    }
    static function PlayGUIError()
    {
        _global.SFX.PlayGUIError();
    }
    static function IsConsoleLayout()
    {
        var _loc1_ = com.SFXScreen.GetPlatformLayout();
        return _loc1_ == com.XPlatform.XBox || _loc1_ == com.XPlatform.PS3;
    }
    static function ObjectToArray(objectWithArrayMembers)
    {
        var _loc2_ = new Array(objectWithArrayMembers.length);
        var _loc3_ = 0;
        while(_loc3_ < objectWithArrayMembers.length)
        {
            _loc2_[_loc3_] = objectWithArrayMembers[_loc3_];
            _loc3_ += 1;
        }
        return _loc2_;
    }
    static function IsHD()
    {
        var _loc2_ = _global.SFX.GetViewport();
        return _loc2_.width / _loc2_.height == com.SFXScreen.HD_WIDTH / com.SFXScreen.HD_HEIGHT && _loc2_.width >= com.SFXScreen.HD_WIDTH;
    }
    static function RegisterForTriggerStateUpdate(oFunc)
    {
        if(_global.SFX.TriggerUpdateCallbacks == undefined)
        {
            _global.SFX.TriggerUpdateCallbacks = new Object();
            _global.SFX.TriggerUpdateCallbacks.aRegistrants = new Array();
            _global.SFX.TriggerUpdateCallbacks.Call = function()
            {
                var _loc2_ = 0;
                while(_loc2_ < _global.SFX.TriggerUpdateCallbacks.aRegistrants.length)
                {
                    _global.SFX.TriggerUpdateCallbacks.aRegistrants[_loc2_].call();
                    _loc2_ += 1;
                }
            };
        }
        var _loc3_ = 0;
        while(_loc3_ < _global.SFX.TriggerUpdateCallbacks.aRegistrants.length)
        {
            if(_global.SFX.TriggerUpdateCallbacks.aRegistrants[_loc3_] == oFunc)
            {
                return undefined;
            }
            _loc3_ += 1;
        }
        _global.SFX.TriggerUpdateCallbacks.aRegistrants.push(oFunc);
    }
    static function UnregisterFromTriggerStateUpdate(oFunc)
    {
        if(_global.SFX.aTriggerUpdateCallbacks == undefined)
        {
            return undefined;
        }
        var _loc3_ = 0;
        while(_loc3_ < _global.SFX.TriggerUpdateCallbacks.aRegistrants.length)
        {
            if(_global.SFX.TriggerUpdateCallbacks.aRegistrants[_loc3_] == oFunc)
            {
                _global.SFX.TriggerUpdateCallbacks.aRegistrants.splice(_loc3_,1);
                return undefined;
            }
            _loc3_ += 1;
        }
    }
}
