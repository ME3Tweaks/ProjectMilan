// MILAN CHANGE - Mgamerz - 2026-10-10
// SDK movie edit: clone ArrowRightContainer (318) as character 1000 and its
// 57-frame contents (317) as character 1001. Remove only the cloned contents'
// depth-1 page background strip. Retain its button, pulse, and stick-icon clips.
// Add export linkage MilanPlayerScrollArrow and this DoInitAction registration.
// The original horizontal arrow symbols and their timelines are unchanged.
Object.registerClass("MilanPlayerScrollArrow",screens.MPNewLobby.LargeArrowButton);
// END MILAN CHANGE
