class screens.MPReinforcementsReveal.CardAnimation extends com.SFXMovieClip
{
   var CardClip;
   var CardClipDescription;
   var CardClipIsNew;
   var CardClipIsBanner;
   var CardClipTextureRef;
   var CardClipTitle;
   var CardClipType;
   var CardClipTypeText;
   var MakeDelegate;
   var gotoAndPlay;
   var gotoAndStop;
   var nCurrentStep = 0;
   static var StepForwardFrames = new Array("initial","step1","step2","step3","step4","step5","step6","step7","step8");
   static var FullFrames = new Array("initial","step1Full","step2Full","step3Full","step4Full","step5Full","step6Full","step7Full");
   static var StepBackFrames = new Array("stepBack1","stepBack2","stepBack3","stepBack4","stepBack5","stepBack6","stepBack7","stepBack8");
   static var CENTER_STEP = 4;
   var m_FinishAnimationCallback = null;
   function CardAnimation()
   {
      super();
      this.CardClip.onLoad = this.MakeDelegate(this.OnCardClipLoad);
   }
   static function GetMaxAnimationSteps()
   {
      return screens.MPReinforcementsReveal.CardAnimation.StepForwardFrames.length;
   }
   function GetCurrentAnimationStep()
   {
      return this.nCurrentStep;
   }
   function OnCardClipLoad()
   {
      this.CardClip.SetCardData(this.CardClipTitle,this.CardClipDescription,this.CardClipTextureRef,this.CardClipTypeText,this.CardClipType,this.CardClipIsNew,this.CardClipIsBanner);
      this.gotoAndStop(screens.MPReinforcementsReveal.CardAnimation.FullFrames[this.nCurrentStep]);
   }
   function SetCardData(TitleText, DescriptionText, TextureRef, TypeText, CardType, IsNew, nInitialStep, IsBanner)
   {
      this.nCurrentStep = nInitialStep;
      this.CardClipTitle = TitleText;
      this.CardClipDescription = DescriptionText;
      this.CardClipTextureRef = TextureRef;
      this.CardClipType = CardType;
      this.CardClipTypeText = TypeText;
      this.CardClipIsNew = IsNew;
      this.CardClipIsBanner = IsBanner == true;
   }
   function SetFinishAnimationCallback(Callback)
   {
      this.m_FinishAnimationCallback = Callback;
   }
   function FinishAnimation()
   {
      if(this.m_FinishAnimationCallback != null)
      {
         this.m_FinishAnimationCallback();
      }
   }
   function MoveForward()
   {
      if(this.nCurrentStep < screens.MPReinforcementsReveal.CardAnimation.StepForwardFrames.length - 1)
      {
         this.nCurrentStep = this.nCurrentStep + 1;
         this.gotoAndPlay(screens.MPReinforcementsReveal.CardAnimation.StepForwardFrames[this.nCurrentStep]);
      }
   }
   function MoveBack()
   {
      if(this.nCurrentStep > 0)
      {
         this.nCurrentStep = this.nCurrentStep - 1;
         this.gotoAndPlay(screens.MPReinforcementsReveal.CardAnimation.StepBackFrames[this.nCurrentStep]);
      }
   }
}
