// MILAN CHANGE - Mgamerz - 2026-10-10
// The value text comes from script (localized), and a change callback lets the panel enable/disable dependent rows.
class com.bioware.masseffect.controls.EA.EARadio extends com.bioware.masseffect.controls.EA.EANetworkControl
{
   var m_RadioText;
   var m_bYesNo;
   var m_labelTxt;
   var mcLeftArrow;
   var mcRightArrow;
   var m_srYes = "$346148";
   var m_srNo = "$346149";
   var m_ChangeObject = null;
   var m_ChangeFunction = null;
   function EARadio()
   {
      super();
   }
   function onLoad()
   {
      super.onLoad();
      this.m_labelTxt.textAutoSize = "shrink";
   }
   function OnInputLeft()
   {
      this.YesNo = false;
   }
   function OnInputRight()
   {
      this.YesNo = true;
   }
   function Execute()
   {
      this.YesNo = !this.YesNo;
      _global.SFX.PlayGUISound("EANetworkOnExecute");
   }
   function SetOptionText(sYes, sNo)
   {
      this.m_srYes = sYes;
      this.m_srNo = sNo;
      this.YesNo = this.m_bYesNo == true;
   }
   function RegisterChangeFunction(p_obj, p_function)
   {
      this.m_ChangeObject = p_obj;
      this.m_ChangeFunction = p_function;
   }
   function set YesNo(bVal)
   {
      if(bVal)
      {
         this.m_RadioText.text = this.m_srYes;
         this.mcLeftArrow._visible = true;
         this.mcRightArrow._visible = false;
      }
      else
      {
         this.m_RadioText.text = this.m_srNo;
         this.mcLeftArrow._visible = false;
         this.mcRightArrow._visible = true;
      }
      this.m_bYesNo = bVal;
      if(this.m_ChangeFunction != null)
      {
         this.m_ChangeFunction.call(this.m_ChangeObject,bVal);
      }
   }
   function get YesNo()
   {
      return this.m_bYesNo;
   }
}
