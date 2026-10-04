class screens.options.DropDown extends screens.options.BaseMenuItem
{
   var _data;
   var _enabled;
   var _parent;
   var _selectedIndex;
   var a_mc_Options_Enabled_State;
   var dispatchEvent;
   var dropBtn;
   var dropDown;
   var mcHeight;
   var mcScrollBar;
   var mc_ClickWall;
   var menuItems;
   var optionSelectedText;
   var scrollBar;
   var selectedMC;
   var swapDepths;
   static var SPACING = 350;
   var DECAY = 4;
   var num_VisibleOptions = 0;
   var num_ScrollIndex = 0;
   var num_HighlightedOption = 0;
   var sz_DropDownLibCellName = "Dropdown Selection list";
   var func_onRollOut = undefined;
   var num_RollOutIndex = 0;
   var func_onRollOver = undefined;
   var num_RollOverIndex = 0;
   var bActive = false;
   var bufferSpace = 5;
   function DropDown()
   {
      super();
   }
   function SetOnRollOverFunc(func, nIndex)
   {
      this.func_onRollOver = func;
      this.num_RollOverIndex = nIndex;
   }
   function SetOnRollOutFunc(func, nIndex)
   {
      this.func_onRollOut = func;
      this.num_RollOutIndex = nIndex;
   }
   function init()
   {
      this.selectedMC = this.dropDown.selected;
      this.dropBtn = this.dropDown.dropBtn;
      this.optionSelectedText = this.dropDown.optionSelectedText;
      var owner = this;
      this.dropBtn.onPress = function()
      {
      };
      this.dropBtn.onRollOver = function()
      {
         owner.dropDown.dropBtn.gotoAndPlay("Grow");
         if(owner.func_onRollOver != undefined)
         {
            owner.func_onRollOver(owner.num_RollOverIndex);
         }
      };
      this.dropBtn.onRollOut = this.dropBtn.onDragOut = function()
      {
         owner.dropDown.dropBtn.gotoAndPlay("shrink");
      };
      this.dropBtn.tabEnabled = false;
      this.a_mc_Options_Enabled_State = new Array();
      var _loc3_ = 0;
      while(_loc3_ < this._data.control.children.length)
      {
         this.a_mc_Options_Enabled_State[_loc3_] = true;
         _loc3_ = _loc3_ + 1;
      }
      this.menuItems = [];
      this.selectedIndex = this._data.control.defaultValue;
      super.init();
   }
   function OpenDropPanel()
   {
      this.bActive = true;
      this.dropDown.gotoAndStop("in");
      this.KillDropOptions();
      var _loc6_;
      var _loc10_;
      var _loc8_;
      var _loc9_;
      var _loc7_;
      var _loc11_;
      var _loc5_;
      var _loc4_;
      var _loc3_;
      if(!this.menuItems.length)
      {
         var owner = this;
         this.mc_ClickWall = this.dropDown._parent._parent._parent._parent.attachMovie("ClickWall","ClickWall",this.dropDown._parent._parent._parent._parent._parent.getNextHighestDepth());
         this.mc_ClickWall._width = Stage.width + this.bufferSpace;
         this.mc_ClickWall._height = Stage.height + this.bufferSpace;
         this.mc_ClickWall._x = Stage.width / 2;
         this.mc_ClickWall._y = Stage.height / 2;
         _loc6_ = 100;
         _loc10_ = 120;
         _loc8_ = 100;
         _loc9_ = Stage.width / Stage.height;
         if(_loc9_ >= 1.7)
         {
            _loc6_ = _loc10_;
         }
         else
         {
            _loc6_ = _loc8_;
         }
         this.mc_ClickWall._xscale = this.mc_ClickWall._yscale = _loc6_;
         this.mc_ClickWall.onPress = function()
         {
            owner.CloseDropPanel();
         };
         this.swapDepths(this._parent.getNextHighestDepth());
         this.menuItems = Array(this._data.control.children.length);
         _loc7_ = {x:this.dropDown.selected._x,y:this.dropDown.selected._y + this.dropDown.selected._height / 2 + this.bufferSpace};
         this.dropDown.selected.localToGlobal(_loc7_);
         _loc11_ = _loc7_.y;
         _loc5_ = _loc11_;
         _loc4_ = 0;
         while(_loc4_ < this._data.control.children.length)
         {
            _loc3_ = this.dropDown._parent._parent._parent._parent._parent.attachMovie(this.sz_DropDownLibCellName,"SubOption" + _loc4_,_root.getNextHighestDepth());
            _loc3_._xscale = _loc3_._yscale = _loc6_;
            _loc3_._y = _loc5_;
            _loc3_._x = _loc7_.x;
            _loc3_.optionText.labelTxt.text = this._data.control.children[_loc4_].label;
            this.SetupOptionButtons(_loc3_,_loc4_);
            this.menuItems[_loc4_] = _loc3_;
            if(!this.mcHeight)
            {
               this.mcHeight = _loc3_._height;
            }
            _loc5_ += this.mcHeight;
            if(this.num_VisibleOptions < 10)
            {
               this.num_VisibleOptions = this.num_VisibleOptions + 1;
            }
            _loc4_ = _loc4_ + 1;
         }
      }
      else
      {
         this.num_ScrollIndex = 0;
         this.mc_ClickWall._visible = true;
      }
      if(this.selectedIndex + 1 > this.num_VisibleOptions)
      {
         this.num_ScrollIndex = this.selectedIndex + 1 - this.num_VisibleOptions;
      }
      this.CreateScrollBar();
      this.UpdateList();
      this.HighlightOption(this.selectedIndex,true);
   }
   function KillDropOptions()
   {
      var _loc2_;
      if(this.menuItems.length)
      {
         _loc2_ = 0;
         while(_loc2_ < this.menuItems.length)
         {
            this.menuItems[_loc2_]._visible = false;
            _loc2_ = _loc2_ + 1;
         }
      }
      this.mc_ClickWall._visible = false;
   }
   function SetupOptionButtons(mc, nIndex)
   {
      var owner = this;
      if(this.a_mc_Options_Enabled_State[nIndex])
      {
         mc.onRollOver = function()
         {
            owner.HighlightOption(nIndex,true);
         };
         mc.onRollOut = mc.onDragOut = function()
         {
         };
         mc.onPress = function()
         {
            owner.SetSelectedOption(nIndex);
            owner.CloseDropPanel();
         };
         mc.onEnterFrame = function()
         {
            if(nIndex == owner.selectedIndex)
            {
               mc.gotoAndStop("selected");
            }
            else if(nIndex == owner.num_HighlightedOption)
            {
               if(mc._currentframe == 1 || mc._currentframe > 11)
               {
                  mc.gotoAndPlay("grow");
               }
            }
            else if(mc._currentframe > 1 && mc._currentframe <= 10)
            {
               mc.gotoAndPlay("shrink");
            }
            else
            {
               mc.gotoAndStop("1");
            }
         };
      }
      else
      {
         mc.gotoAndStop("Disabled");
      }
   }
   function CreateScrollBar()
   {
      if(this.num_VisibleOptions >= this.menuItems.length)
      {
         return undefined;
      }
      var _loc2_ = {x:this.dropDown.selected._x,y:this.dropDown.selected._y + this.dropDown.selected._height / 2 + this.bufferSpace};
      this.dropDown.selected.localToGlobal(_loc2_);
      var _loc4_ = _loc2_.y;
      var _loc3_ = this.menuItems[0]._x + this.menuItems[0]._width;
      if(this.scrollBar != undefined)
      {
         delete this.scrollBar;
      }
      this.mcScrollBar = this.dropDown._parent._parent._parent._parent._parent.attachMovie("scrollbar","dropdownScrollbar",this.dropDown._parent._parent._parent._parent._parent.getNextHighestDepth());
      this.scrollBar = new com.PCScrollBar(this.mcScrollBar,this.mcScrollBar.bar,this.mcScrollBar.sliderNew,this.mcScrollBar.ResScrlUp,this.mcScrollBar.ResScrlDown,this.mcScrollBar.scrollbarVisibleBg,false);
      this.mcScrollBar._x = _loc3_;
      this.mcScrollBar._y = _loc4_;
      this.mcScrollBar._height = this.num_VisibleOptions * this.mcHeight;
      this.mcScrollBar.tabEnabled = false;
      this.mcScrollBar.tabChildren = false;
      if(this.scrollBar.onScroll == undefined)
      {
         var supervisor = this;
         this.scrollBar.onScroll = function()
         {
            supervisor.scrollFunction();
         };
      }
      this.recalcScrollBar();
   }
   function scrollFunction()
   {
      if(this.scrollBar != undefined)
      {
         if(this.scrollBar.discreteScrolling)
         {
            this.moveTo(this.scrollBar.getCurrentStep());
         }
         else
         {
            this.moveToPercent(this.scrollBar.getCurrentPercent());
         }
      }
      this.UpdateList();
   }
   function recalcScrollBar()
   {
      var _loc2_;
      if(this.scrollBar != undefined)
      {
         _loc2_ = this;
         this.scrollBar.setSteps(_loc2_.menuItems.length - _loc2_.num_VisibleOptions + 1,_loc2_.num_VisibleOptions,true,true);
         this.repositionScrollBar();
      }
   }
   function repositionScrollBar()
   {
      if(this.scrollBar != undefined)
      {
         if(this.num_ScrollIndex > -1)
         {
            this.scrollBar.setPositionStep(this.num_ScrollIndex);
         }
      }
   }
   function moveTo(index)
   {
      if(index > this.menuItems.length - this.num_VisibleOptions)
      {
         return undefined;
      }
      this.num_ScrollIndex = index;
   }
   function moveToPercent(percent)
   {
      if(percent < 0)
      {
         percent = 0;
      }
      if(percent > 100)
      {
         percent = 100;
      }
      this.moveTo(Math.round(percent / 100 * (this.menuItems.length - this.num_VisibleOptions)));
   }
   function MoveScrollBar(Dir)
   {
      if(Dir > 0)
      {
         this.scrollBar.doScrollDown();
      }
      else
      {
         this.scrollBar.doScrollUp();
      }
   }
   function OnMouseWheelInput(Dir)
   {
      this.MoveScrollBar(-1 * Dir);
   }
   function SetSelectedOption(nIndex)
   {
      this.selectedIndex = nIndex;
      this.onSettingChange();
   }
   function CloseDropPanel()
   {
      this.dropDown.gotoAndStop("normal");
      this.KillDropOptions();
      this.mcScrollBar._visible = false;
      this.bActive = false;
   }
   function UpdateList()
   {
      var _loc2_;
      if(this._data.control.children.length <= this.num_VisibleOptions)
      {
         _loc2_ = 0;
         while(_loc2_ < this._data.control.children.length)
         {
            this.menuItems[_loc2_]._visible = true;
            _loc2_ = _loc2_ + 1;
         }
         return undefined;
      }
      _loc2_ = 0;
      while(_loc2_ < this._data.control.children.length)
      {
         this.menuItems[_loc2_]._visible = false;
         _loc2_ = _loc2_ + 1;
      }
      var _loc4_ = {x:this.dropDown.selected._x,y:this.dropDown.selected._y + this.dropDown.selected._height / 2 + this.bufferSpace};
      this.dropDown.selected.localToGlobal(_loc4_);
      var _loc5_ = _loc4_.y;
      var _loc3_ = _loc5_;
      _loc2_ = this.num_ScrollIndex;
      while(_loc2_ < this.num_ScrollIndex + this.num_VisibleOptions)
      {
         this.menuItems[_loc2_]._y = _loc3_;
         this.menuItems[_loc2_]._visible = true;
         _loc3_ += this.mcHeight;
         _loc2_ = _loc2_ + 1;
      }
   }
   function HighlightOption(nIndex, bForce)
   {
      this.num_HighlightedOption = nIndex;
   }
   function onSettingChange()
   {
      this.dispatchEvent({type:"onSettingChange",story:this._data.control.children[this.selectedIndex].story,numerator:this.selectedIndex,denominator:this._data.control.children.length - 1,optionId:this._data.optionId,adjustingControl:true});
   }
   function set selectedIndex(p_index)
   {
      this._selectedIndex = p_index;
      this._data.control.defaultValue = this._selectedIndex;
      this.dropDown.optionSelectedText.labelTxt.text = this._data.control.children[p_index].label;
   }
   function set active(p_enabled)
   {
      super.active = p_enabled;
      if(!this.loaded)
      {
         return;
      }
      var _loc3_ = new Color(this.dropBtn);
      _loc3_.setRGB(!p_enabled ? screens.options.BaseMenuItem.INACTIVE_COLOR : screens.options.BaseMenuItem.ACTIVE_COLOR);
      _loc3_ = new Color(this.selectedMC);
      _loc3_.setRGB(!p_enabled ? screens.options.BaseMenuItem.INACTIVE_COLOR : screens.options.BaseMenuItem.ACTIVE_COLOR);
      _loc3_ = new Color(this.optionSelectedText);
      _loc3_.setRGB(!p_enabled ? screens.options.BaseMenuItem.INACTIVE_COLOR : screens.options.BaseMenuItem.ACTIVE_COLOR);
      if(p_enabled)
      {
         this.onSettingChange();
      }
   }
   function get selectedIndex()
   {
      return this._selectedIndex;
   }
   function get active()
   {
      return this._enabled;
   }
   function ShiftSelection(Distance)
   {
      var _loc2_ = this.selectedIndex + Distance;
      if(_loc2_ < 0)
      {
         _loc2_ = 0;
      }
      else if(_loc2_ > this.menuItems.length - 1)
      {
         _loc2_ = this.menuItems.length - 1;
      }
      if(_loc2_ != this.selectedIndex && this.a_mc_Options_Enabled_State[_loc2_])
      {
         this.SetSelectedOption(_loc2_);
      }
   }
   function execEnter()
   {
      if(!this.bActive)
      {
         this.OpenDropPanel();
      }
      else
      {
         this.SetSelectedOption(this.num_HighlightedOption);
         this.CloseDropPanel();
      }
   }
   function execEscape()
   {
      this.CloseDropPanel();
      this.bActive = false;
   }
   function execUp()
   {
      if(this.bActive)
      {
         if(this.num_HighlightedOption > 0 && this.a_mc_Options_Enabled_State[this.num_HighlightedOption - 1])
         {
            if(this.num_HighlightedOption - 1 < this.num_ScrollIndex && this.num_ScrollIndex > 0)
            {
               this.num_ScrollIndex -= 1;
               this.MoveScrollBar(-1);
               this.UpdateList();
            }
            this.HighlightOption(this.num_HighlightedOption - 1);
         }
      }
   }
   function execDown()
   {
      if(this.bActive)
      {
         if(this.num_HighlightedOption < this.menuItems.length - 1 && this.a_mc_Options_Enabled_State[this.num_HighlightedOption + 1])
         {
            if(this.num_HighlightedOption + 1 > this.num_VisibleOptions + this.num_ScrollIndex - 1)
            {
               this.num_ScrollIndex += 1;
               this.MoveScrollBar(1);
               this.UpdateList();
            }
            this.HighlightOption(this.num_HighlightedOption + 1);
         }
      }
   }
   function execLeft()
   {
   }
   function execRight()
   {
   }
   function increaseSetting()
   {
      this.execRight();
   }
   function decreaseSetting()
   {
      this.execLeft();
   }
   function onPress()
   {
      if(!_global.DissabledInput)
      {
         if(this.dropBtn._visible && this.dropBtn.hitTest(_root._xmouse,_root._ymouse,true))
         {
            this.OpenDropPanel();
         }
         else if(this.mc_ClickWall._visible && this.mc_ClickWall.hitTest(_root._xmouse,_root._ymouse,true))
         {
            this.CloseDropPanel();
         }
         else
         {
            super.onPress();
         }
      }
   }
}
