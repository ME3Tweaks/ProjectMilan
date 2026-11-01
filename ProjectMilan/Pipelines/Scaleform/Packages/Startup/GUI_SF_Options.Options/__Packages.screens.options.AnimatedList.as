class screens.options.AnimatedList extends com.bioware.masseffect.controls.FocusControl
{
   var _data;
   var _selectedIndex;
   var createEmptyMovieClip;
   var dispatchEvent;
   var localToGlobal;
   var m_bHasDataSwapped;
   var menuHolder;
   var menuTween;
   var rawChildren;
   var scrollBar;
   var scrollBarMC;
   var selectedItem;
   var selectionBar;
   var storyTxt;
   var DECAY = 3;
   var TRACKING = 37;
   var FadeTracking = screens.options.AnimatedList.prototype.TRACKING;
   var NUM_VISIBLE = 9;
   var FADE_ITEMS = true;
   var _scrollbarVisibleOveride = false;
   var _scrollbarVisibleOverideValue = false;
   var onListScrollFunction = undefined;
   var initted = false;
   var loaded = false;
   var _previousValues = [];
   var m_counter = 0;
   var _topVisibleElementIndex = 0;
   var LIST_X_OFFSET = 15;
   function AnimatedList()
   {
      super();
      this.menuTween.END_POS = this.LIST_X_OFFSET;
      mx.events.EventDispatcher.initialize(this);
   }
   function onLoad()
   {
      this.configUI();
      this.GiveFocus();
   }
   function updateView(p_event)
   {
      this.rawChildren = [];
      if(this.menuHolder)
      {
         this.menuHolder.removeMovieClip();
      }
      this.menuHolder = this.createEmptyMovieClip("menuHolder",1);
      this._topVisibleElementIndex = 0;
      this.selectionBar = screens.options.SelectionBar(this.menuHolder.attachMovie("SelectionBar","selectionBar",this.menuHolder.getNextHighestDepth()));
      if(this.selectionBar)
      {
         this.selectionBar._x = this.LIST_X_OFFSET;
         this.selectionBar.spacing = this.TRACKING;
         this.selectionBar.barPosition = 0;
      }
      this.m_counter = this._data.length;
      this.menuTween.init();
      var _loc3_ = 0;
      var _loc2_;
      while(_loc3_ < this.m_counter)
      {
         _loc2_ = screens.options.BaseMenuItem(this.menuHolder.attachMovie(this._data[_loc3_].type,"menuItem_" + _loc3_,this.menuHolder.getNextHighestDepth()));
         _loc2_.addEventListener("onSettingChange",mx.utils.Delegate.create(this,this.bubbleEvent));
         _loc2_.addEventListener("SFXMenuItem_onRollOver",mx.utils.Delegate.create(this,this.bubbleEvent));
         _loc2_.addEventListener("SFXMenuItem_onRelease",mx.utils.Delegate.create(this,this.bubbleEvent));
         _loc2_.addEventListener("CapturingBind",mx.utils.Delegate.create(this,this.bubbleEvent));
         _loc2_.addEventListener("SFXMenuItem_onLeftArrowPress",mx.utils.Delegate.create(this,this.bubbleEvent));
         _loc2_.addEventListener("SFXMenuItem_onRightArrowPress",mx.utils.Delegate.create(this,this.bubbleEvent));
         _loc2_.nIndex = _loc3_;
         _loc2_._alpha = 0;
         _loc2_._y = _loc3_ * this.TRACKING;
         _loc2_._x = this.menuTween.START_POS;
         _loc2_.data = this._data[_loc3_];
         _loc2_.active = this.selectedIndex == _loc3_;
         this.menuTween.registerClip(_loc2_);
         this.rawChildren.push(_loc2_);
         if(_loc3_ > this.NUM_VISIBLE - 1)
         {
            _loc2_.menuTweenAnimateAlpha = false;
         }
         _loc3_ = _loc3_ + 1;
      }
      this.recalcScrollBar();
      this.recalcScrollbarVisibility();
      if(this.selectedIndex >= this.m_counter)
      {
         this.selectedIndex = this.m_counter - 1;
      }
      this.menuTween.animateIn();
      this.dispatchEvent({type:"onChange"});
   }
   function configUI()
   {
      this.menuTween.addEventListener("onMenuOutStart",mx.utils.Delegate.create(this,this.bubbleEvent));
      this.menuTween.addEventListener("onMenuOutEnd",mx.utils.Delegate.create(this,this.updateView));
      this.menuTween.addEventListener("onMenuInStart",mx.utils.Delegate.create(this,this.bubbleEvent));
      this.menuTween.addEventListener("onMenuInEnd",mx.utils.Delegate.create(this,this.menuVisible));
      this.loaded = true;
      if(this._data != undefined)
      {
         this.updateView();
      }
   }
   function set dataProvider(p_data)
   {
      if(this._data != undefined)
      {
         this.fadeOut(this.selectionBar);
         this.menuTween.animateOut();
         this._data = p_data;
      }
      else
      {
         this._data = p_data;
         this.updateView();
      }
      this.m_bHasDataSwapped = true;
      this.backUpValues(p_data);
   }
   function SetSingleOption(optionId, option)
   {
      var _loc2_ = 0;
      while(_loc2_ < this._data.length)
      {
         if(this._data[_loc2_].optionId == optionId)
         {
            this._data[_loc2_] = option;
         }
         _loc2_ = _loc2_ + 1;
      }
      _loc2_ = 0;
      while(_loc2_ < this.rawChildren.length)
      {
         if(this.rawChildren[_loc2_].optionId == optionId)
         {
            this.rawChildren[_loc2_].data = option;
         }
         _loc2_ = _loc2_ + 1;
      }
   }
   function setOptionActive(optionID, bIsActive)
   {
      var _loc2_ = this.GetOptionIndex(optionID);
      if(_loc2_ > -1)
      {
         this.rawChildren[_loc2_].setEnabled(bIsActive);
      }
   }
   function set selectedIndex(p_index)
   {
      this.SelectIndex(p_index,true);
   }
   // Mouse hover selects rows at their animated positions without moving the scroll target.
   // Keyboard/controller navigation still reveals the selected row at the nearest edge.
   function SelectIndex(p_index, p_reveal)
   {
      if(isNaN(p_index) || p_index < 0 || p_index >= this.m_counter)
      {
         return undefined;
      }
      var _loc2_ = p_index - this._selectedIndex;
      if(_loc2_ != 0 || this.m_bHasDataSwapped)
      {
         this.selectedItem.active = false;
         this._selectedIndex = p_index;
         this.selectionBar.barPosition = this._selectedIndex;
         this.selectedItem = this.rawChildren[p_index];
         this.selectedItem.active = true;
         if(p_reveal && !this.IsIndexVisible(p_index))
         {
            if(p_index < this.topVisibleElementIndex)
            {
               this.topVisibleElementIndex = p_index;
            }
            else
            {
               this.topVisibleElementIndex = p_index - this.NUM_VISIBLE + 1;
            }
         }
         this.repositionScrollBar();
      }
      this.m_bHasDataSwapped = false;
   }
   function IsIndexVisible(p_index)
   {
      var _loc2_ = true;
      if(p_index < this.topVisibleElementIndex || p_index > this.topVisibleElementIndex + this.NUM_VISIBLE - 1)
      {
         _loc2_ = false;
      }
      return _loc2_;
   }
   function GetOptionIndex(nOptionId)
   {
      var _loc2_ = 0;
      while(_loc2_ < this.rawChildren.length)
      {
         if(this.rawChildren[_loc2_].optionId == nOptionId)
         {
            return _loc2_;
         }
         _loc2_ = _loc2_ + 1;
      }
      return -1;
   }
   function SetItemValue(nItemIndex, nValue)
   {
      if(nItemIndex >= 0 && nItemIndex < this.rawChildren.length && this.rawChildren[nItemIndex] != undefined)
      {
         this.rawChildren[nItemIndex].selectedIndex = nValue;
      }
   }
   function GetItemValue(nItemIndex)
   {
      if(nItemIndex >= 0 && nItemIndex < this.rawChildren.length && this.rawChildren[nItemIndex] != undefined)
      {
         return this.rawChildren[nItemIndex].selectedIndex;
      }
   }
   function get selectedIndex()
   {
      return this._selectedIndex;
   }
   function get dataProvider()
   {
      return this._data;
   }
   function setStory(p_story)
   {
      this.storyTxt.text = p_story;
   }
   function SFXMenuItem_onRollOverHandler()
   {
   }
   function onSettingChangeHandler()
   {
   }
   function SFXMenuItem_onLeftArrowPressHandler()
   {
   }
   function SFXMenuItem_onRightArrowPressHandler()
   {
   }
   function onMenuInStartHandler()
   {
   }
   function onMenuInEndHandler()
   {
   }
   function onMenuOutStartHandler()
   {
   }
   function onMenuOutEndHandler()
   {
   }
   function bubbleEvent(p_event)
   {
      this.dispatchEvent(p_event);
   }
   function menuVisible(p_event)
   {
      this.selectedItem.setActive(true,false);
      this.dispatchEvent(p_event);
   }
   function fadeOut(p_target)
   {
      p_target._alpha = 0;
   }
   function fadeIn(p_target)
   {
      p_target._alpha = 100;
   }
   function backUpValues(p_dataStruct)
   {
      this._previousValues = [];
      var _loc4_ = p_dataStruct.length;
      var _loc2_ = 0;
      var _loc3_;
      while(_loc2_ < _loc4_)
      {
         _loc3_ = p_dataStruct[_loc2_].control.defaultValue;
         this._previousValues.push(_loc3_);
         _loc2_ = _loc2_ + 1;
      }
   }
   function setRawData(p_dataStruct)
   {
      this._previousValues = [];
      if(this._data != undefined)
      {
         this.backUpValues(this._data);
      }
      this._data = p_dataStruct;
   }
   function restoreValues(p_dataStruct)
   {
      var _loc4_ = this._previousValues.length;
      var _loc2_ = 0;
      var _loc3_;
      while(_loc2_ < _loc4_)
      {
         _loc3_ = this._previousValues[_loc2_];
         p_dataStruct[_loc2_].control.defaultValue = _loc3_;
         _loc2_ = _loc2_ + 1;
      }
   }
   function restoreSubmenuValuesFromBackup()
   {
      this.restoreValues(this._data);
   }
   function fadeInSelectionBar(p_event)
   {
      this.fadeIn(this.selectionBar);
   }
   function UpdateControllerBindEntry(p_Bind1, p_Bind2)
   {
      var _loc2_ = screens.options.ControlBindingsListItem(this.selectedItem);
      if(_loc2_ != null || _loc2_ != undefined)
      {
         _loc2_.BindKey1 = p_Bind1;
         _loc2_.BindKey2 = p_Bind2;
      }
      this.dispatchEvent({type:"CapturingBindCompleted",target:this});
   }
   function UpdateControllerBindEntryByIndex(p_Index, p_Bind1, p_Bind2)
   {
      var _loc2_ = screens.options.ControlBindingsListItem(this.rawChildren[p_Index]);
      if(_loc2_ != null || _loc2_ != undefined)
      {
         _loc2_.BindKey1 = p_Bind1;
         _loc2_.BindKey2 = p_Bind2;
      }
   }
   function isListAnimating()
   {
      return this.menuHolder.onEnterFrame != undefined && this.menuHolder.onEnterFrame != null;
   }
   function animateList()
   {
      delete this.menuHolder.onEnterFrame;
      this.menuHolder.onEnterFrame = mx.utils.Delegate.create(this,this.moveList);
   }
   function moveList()
   {
      if(Stage.width / Stage.height >= 1.7)
      {
         this.FadeTracking = this.TRACKING;
      }
      else
      {
         this.FadeTracking = this.TRACKING;
      }
      var _loc15_ = - this._topVisibleElementIndex * this.FadeTracking;
      var _loc3_;
      var _loc18_ = 0;
      var _loc4_ = 0;
      var _loc17_ = 1;
      var _loc16_ = 0;
      var _loc2_ = {x:0,y:0};
      var _loc10_ = {x:0,y:0};
      var _loc6_ = 100;
      var _loc11_ = 0;
      var _loc5_ = 0;
      var _loc7_ = false;
      this.localToGlobal(_loc10_);
      _loc16_ = (_loc15_ - this.menuHolder._y) / this.DECAY;
      this.menuHolder._y += _loc16_;
      if(Math.abs(_loc15_ - this.menuHolder._y) < 1)
      {
         this.menuHolder._y = _loc15_;
         this.menuHolder.onEnterFrame = null;
         delete this.menuHolder.onEnterFrame;
      }
      _loc11_ = _loc10_.y + this.FadeTracking * this.NUM_VISIBLE;
      var _loc12_ = this.FadeTracking * 0.75;
      var _loc14_ = _loc10_.y - _loc12_;
      var _loc13_ = _loc11_ + _loc12_;
      _loc4_ = 0;
      var _loc8_;
      var _loc9_;
      while(_loc4_ < this.m_counter)
      {
         _loc7_ = false;
         _loc3_ = this.rawChildren[_loc4_];
         _loc2_.x = 0;
         _loc2_.y = 0;
         _loc3_.localToGlobal(_loc2_);
         _loc5_ = _loc2_.y + this.FadeTracking;
         if(_loc2_.y < _loc10_.y && _loc2_.y > _loc14_)
         {
            _loc8_ = Math.abs(_loc2_.y - _loc10_.y);
            _loc6_ = 100 - Math.round(_loc8_ / _loc12_ * 100);
         }
         else if(_loc5_ > _loc11_ && _loc5_ < _loc13_)
         {
            _loc9_ = Math.abs(_loc5_ - _loc11_);
            _loc6_ = 100 - Math.round(_loc9_ / _loc12_ * 100);
         }
         else if(_loc5_ > _loc13_ || _loc2_.y < _loc14_)
         {
            _loc6_ = 0;
         }
         else
         {
            _loc6_ = 100;
            _loc7_ = true;
         }
         if(this.FADE_ITEMS)
         {
            _loc3_._alpha = _loc6_;
            if(this.selectionBar.barPosition == _loc4_)
            {
               this.selectionBar._alpha = _loc3_._alpha;
            }
         }
         _loc3_.enabled = _loc7_;
         _loc3_.menuTweenAnimateAlpha = _loc7_;
         _loc4_ = _loc4_ + 1;
      }
   }
   function get topVisibleElementIndex()
   {
      return this._topVisibleElementIndex;
   }
   function set topVisibleElementIndex(p_index)
   {
      // Every caller shares these bounds, including selection and short/empty pages.
      if(isNaN(p_index))
      {
         p_index = 0;
      }
      p_index = Math.max(0,Math.min(p_index,Math.max(0,this.m_counter - this.NUM_VISIBLE)));
      if(p_index != this._topVisibleElementIndex)
      {
         this._topVisibleElementIndex = p_index;
         this.animateList();
      }
   }
   function set scrollbarVisibleOveride(i_val)
   {
      this._scrollbarVisibleOveride = i_val;
   }
   function get scrollbarVisibleOveride()
   {
      return this._scrollbarVisibleOveride;
   }
   function set scrollbarVisibleOverideValue(i_val)
   {
      this._scrollbarVisibleOverideValue = i_val;
   }
   function get scrollbarVisibleOverideValue()
   {
      return this._scrollbarVisibleOverideValue;
   }
   function recalcScrollbarVisibility()
   {
      if(this.scrollBar != undefined)
      {
         this.scrollBar._visible = this.m_counter > this.NUM_VISIBLE;
         if(this._scrollbarVisibleOveride)
         {
            this.scrollBar._visible = this._scrollbarVisibleOverideValue;
         }
      }
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
   function setupScrollBar(mcScrollBar)
   {
      if(this.scrollBar != undefined)
      {
         delete this.scrollBar;
      }
      this.scrollBarMC = mcScrollBar;
      this.scrollBar = new com.PCScrollBar(mcScrollBar,mcScrollBar.bar,mcScrollBar.sliderNew,mcScrollBar.ResScrlUp,mcScrollBar.ResScrlDown,mcScrollBar.scrollbarVisibleBg,false);
      mcScrollBar.tabEnabled = false;
      mcScrollBar.tabChildren = false;
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
   function recalcScrollBar()
   {
      var _loc2_;
      if(this.scrollBar != undefined)
      {
         _loc2_ = this;
         this.scrollBar.setSteps(this.m_counter - this.NUM_VISIBLE + 1,this.NUM_VISIBLE,true,true);
         this.repositionScrollBar();
      }
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
      if(this.onListScrollFunction != undefined)
      {
         this.onListScrollFunction.call(this);
      }
   }
   function repositionScrollBar()
   {
      if(this.scrollBar != undefined)
      {
         if(this._topVisibleElementIndex > -1)
         {
            this.scrollBar.setPositionStep(this._topVisibleElementIndex);
         }
      }
   }
   function moveTo(index)
   {
      if(index > this.m_counter - this.NUM_VISIBLE)
      {
         return undefined;
      }
      this.topVisibleElementIndex = index;
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
      this.moveTo(Math.round(percent / 100 * (this.m_counter - this.NUM_VISIBLE)));
   }
   function OnMouseWheelInput(Dir)
   {
      if(this.dataProvider[this.selectedIndex].type.indexOf("DropDown") != -1 && this.selectedItem.bActive)
      {
         this.selectedItem.OnMouseWheelInput(Dir);
      }
      else
      {
         this.MoveScrollBar(-1 * Dir);
      }
   }
   function SetSelectionBarVisibility(Visible)
   {
      this.selectionBar._visible = Visible;
   }
}
