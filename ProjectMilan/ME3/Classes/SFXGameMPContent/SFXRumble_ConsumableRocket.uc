Class SFXRumble_ConsumableRocket extends SFXRumble_Power;

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=ForceFeedbackWaveform Name=ForceFeedbackWaveform
        Samples = ({Duration = 0.300000012, LeftAmplitude = 200, RightAmplitude = 200, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}
                  )
    End Template
    MinDetonationRumbleDistance = 1000.0
    MaxDetonationRumbleDistance = 3000.0
    TheWaveForm = ForceFeedbackWaveform
}