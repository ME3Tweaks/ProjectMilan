class screens.MPReinforcementsReveal.Card extends com.SFXMovieClip
{
   var CardTypeText;
   var Description;
   var ImageLoader;
   var NewShimmer;
   var Title;
   var gotoAndStop;
   var m_CardType = screens.MPReinforcementsReveal.Card.CARD_TYPE_COMMON;
   static var CARD_TYPE_COMMON = 0;
   static var CARD_TYPE_UNCOMMON = 1;
   static var CARD_TYPE_RARE = 2;
   static var CARD_TYPE_ULTRARARE = 3;
   static var CommonFrame = "common";
   static var UncommonFrame = "uncommon";
   static var RareFrame = "rare";
   static var UltraRareFrame = "ultrarare";
   function Card()
   {
      super();
   }
   function SetCardData(TitleText, DescriptionText, ItemTextureRef, TypeText, CardType, IsNew, IsBanner)
   {
      this.Title.textAutoSize = "shrink";
      this.Title.text = TitleText;
      this.Description.text = DescriptionText;
      // Reset both layouts: a reused card must not retain banner geometry.
      this.ImageLoader._x = IsBanner == true ? 54 : 122.5;
      this.ImageLoader._y = IsBanner == true ? 124 : 106.95;
      this.ImageLoader.Width = IsBanner == true ? 414 : 278.05;
      this.ImageLoader.Height = IsBanner == true ? 103.5 : 139.65;
      this.ImageLoader.PreserveAspectRatio = true;
      this.ImageLoader.RegistrationPoint = IsBanner == true ? 0 : 1;
      this.ImageLoader.HAlign = IsBanner == true ? 1 : 0;
      this.ImageLoader.VAlign = IsBanner == true ? 1 : 0;
      this.ImageLoader.Async = true;
      this.ImageLoader.ResourceString = ItemTextureRef;
      // A new async request must size itself after the image loads. Only resize
      // an already loaded resource here (the same-image path does not reload).
      if(!this.ImageLoader.IsLoading && this.ImageLoader.mcResource._width > 0 && this.ImageLoader.mcResource._height > 0)
      {
         this.ImageLoader.sizeAndPosition();
      }
      this.CardTypeText.text = TypeText;
      this.NewShimmer._visible = IsNew;
      if(CardType == screens.MPReinforcementsReveal.Card.CARD_TYPE_COMMON)
      {
         this.gotoAndStop(screens.MPReinforcementsReveal.Card.CommonFrame);
      }
      else if(CardType == screens.MPReinforcementsReveal.Card.CARD_TYPE_UNCOMMON)
      {
         this.gotoAndStop(screens.MPReinforcementsReveal.Card.UncommonFrame);
      }
      else if(CardType == screens.MPReinforcementsReveal.Card.CARD_TYPE_RARE)
      {
         this.gotoAndStop(screens.MPReinforcementsReveal.Card.RareFrame);
      }
      else if(CardType == screens.MPReinforcementsReveal.Card.CARD_TYPE_ULTRARARE)
      {
         this.gotoAndStop(screens.MPReinforcementsReveal.Card.UltraRareFrame);
      }
   }
}
