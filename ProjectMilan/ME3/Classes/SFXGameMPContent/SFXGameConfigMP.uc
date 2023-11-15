Class SFXGameConfigMP extends SFXGameConfig
    config(Game);

// Variables
var array<Object> ForceLoadedArchetypes;
var config float ScoreToXPMultiplier;
var config bool ShowMPProgressionScreens;
var config bool DisableDroppedAmmo;

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    ScoreToXPMultiplier = 1.0
    LevelRewards = ({Level = 1, ExperienceRequired = 0, TalentReward = 2, HenchmanTalentReward = 0}, 
                    {Level = 2, ExperienceRequired = 12500, TalentReward = 3, HenchmanTalentReward = 0}, 
                    {Level = 3, ExperienceRequired = 37500, TalentReward = 3, HenchmanTalentReward = 0}, 
                    {Level = 4, ExperienceRequired = 62500, TalentReward = 3, HenchmanTalentReward = 0}, 
                    {Level = 5, ExperienceRequired = 100000, TalentReward = 3, HenchmanTalentReward = 0}, 
                    {Level = 6, ExperienceRequired = 150000, TalentReward = 3, HenchmanTalentReward = 0}, 
                    {Level = 7, ExperienceRequired = 200000, TalentReward = 3, HenchmanTalentReward = 0}, 
                    {Level = 8, ExperienceRequired = 250000, TalentReward = 4, HenchmanTalentReward = 0}, 
                    {Level = 9, ExperienceRequired = 312500, TalentReward = 4, HenchmanTalentReward = 0}, 
                    {Level = 10, ExperienceRequired = 375000, TalentReward = 4, HenchmanTalentReward = 0}, 
                    {Level = 11, ExperienceRequired = 437500, TalentReward = 4, HenchmanTalentReward = 0}, 
                    {Level = 12, ExperienceRequired = 500000, TalentReward = 4, HenchmanTalentReward = 0}, 
                    {Level = 13, ExperienceRequired = 625000, TalentReward = 5, HenchmanTalentReward = 0}, 
                    {Level = 14, ExperienceRequired = 750000, TalentReward = 5, HenchmanTalentReward = 0}, 
                    {Level = 15, ExperienceRequired = 875000, TalentReward = 5, HenchmanTalentReward = 0}, 
                    {Level = 16, ExperienceRequired = 1000000, TalentReward = 5, HenchmanTalentReward = 0}, 
                    {Level = 17, ExperienceRequired = 1250000, TalentReward = 6, HenchmanTalentReward = 0}, 
                    {Level = 18, ExperienceRequired = 1500000, TalentReward = 6, HenchmanTalentReward = 0}, 
                    {Level = 19, ExperienceRequired = 2000000, TalentReward = 6, HenchmanTalentReward = 0}, 
                    {Level = 20, ExperienceRequired = 2500000, TalentReward = 6, HenchmanTalentReward = 0}
                   )
    MaxPlayerExperience = 13000000
    DroppedWeaponLifespan = 90.0
    ScoreEnabled = TRUE
}