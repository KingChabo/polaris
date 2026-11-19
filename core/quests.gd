class_name Quests
extends Node
## Jobs people give you. One of each kind: delivery, clearing a place, collecting,
## exploring, investigating, hunting, and a choice that changes who trusts you.
##
## A quest is a list of steps. Step kinds:
##   give   - hand `items` to `npc`
##   kill   - everyone in `ids` is dead
##   places - every place in `ids` discovered
##   notes  - at least `n` documents read
##   talk   - speak to `npc`
##   choice - hand `item` to one of several people; each has its own outcome
##   flag   - a horror puzzle is solved (main.horror.flags[`id`])
## Main quests carry a "mode" (normal by default); side jobs run in both modes.

signal updated

const DEFS := {
	# ---------------------------------------------------------------- the main story
	# You were on the last bus out of Polaris. The army blew the tunnel behind it, and the
	# 31 passengers walked back to the village. Your sister Mirja was on that bus too; her
	# unsent postcard lies by the wreck. Each chapter starts by itself when the one before ends.
	"main_1": {"title": "The Last Bus", "type": "Story", "giver": "henrik", "main": true, "next": "main_2",
		"offer": "The bus never left the valley. The tunnel came down on it, and you walked back through the dark with the others. Mirja walked off towards the lake that same night and did not come back. Old Henrik says Tove in Eisgrund knows the valley better than anyone. Start there.",
		"steps": [{"kind": "places", "ids": ["settle"], "text": "Follow the lake road to Eisgrund"},
			{"kind": "talk", "npc": "tove", "text": "Ask Tove about Mirja",
				"say": "A girl with a red scarf? She came through last night, asking about the lights under the ice. I told her what I tell everyone: stay away from the Nordstern. She went anyway. Here — Arvid's key to the lower gate. If you mean to follow her, you will need it."}],
		"reward": {"coin": 30, "hot_tea": 1}, "rep": {"eisgrund": 5}},
	"main_2": {"title": "Something Digs Below", "type": "Story", "giver": "tove", "main": true, "next": "main_3",
		"offer": "The Nordstern mine is east of the crossroads, under the Stollenkopf. Arvid's men say the big cutter runs on its own and digs towards the lake. If Mirja went down there, so must you.",
		"steps": [{"kind": "places", "ids": ["mine"], "text": "Go to the Nordstern mine under the Stollenkopf"},
			{"kind": "kill", "ids": ["boss_machine"], "text": "Stop K-9 in the lower chamber of the mine"},
			{"kind": "talk", "npc": "tove", "text": "Tell Tove what you found in the mine",
				"say": "Mirja's scarf, in the machine's tracks? Then she got out — the drift by the office leads up to the road. She was going north, to the soldiers. Nobody comes back from the fort. Read Order 44 in the tunnel first: the Major wrote down where he keeps his keys."}],
		"reward": {"coin": 80, "medkit": 1}, "rep": {"eisgrund": 10, "village": 5}},
	"main_3": {"title": "Order 44", "type": "Story", "giver": "tove", "main": true, "next": "main_4",
		"offer": "The army closed the valley and then closed itself into Fort Nordwacht. Somewhere in their chain of keys is the way into Polaris-7, and that is where Mirja was going.",
		"steps": [{"kind": "read", "ids": ["n_tunnel_order"], "text": "Find Order 44 in the service room of the Polaris tunnel (Tove's crowbar opens the door)"},
			{"kind": "places", "ids": ["bunker1", "base"], "text": "Open shelter B-2 and reach Fort Nordwacht"},
			{"kind": "kill", "ids": ["boss_commander"], "text": "Defeat Oberst Falk in the fort yard"}],
		"reward": {"coin": 120}, "rep": {"village": 10}},
	"main_4": {"title": "Polaris-7", "type": "Story", "giver": "aurel", "main": true, "next": "main_5",
		"offer": "Falk is dead. The armoury holds the keycard of the research station across the Eisklamm. Whatever began there, Mirja wanted to see it with her own eyes.",
		"steps": [{"kind": "places", "ids": ["station"], "text": "Cross the Eisklamm to Research Station Polaris-7 (climb the ravine: hold jump and forward at the rock; the lever for the emergency span is on the far side)"},
			{"kind": "read", "ids": ["n_station_log", "n_station_beast"], "text": "Read Dr. Halvorsen's log and the field notes in the laboratory"},
			{"kind": "talk", "npc": "aurel", "text": "Bring what you learned to Father Aurel",
				"say": "Core 31. Ice that is not ice, that grew a spine in a tank. And it went home to the lake. Your sister left a note in my poor box this morning — she is alive, in Eisgrund, and she says the White One is calling her. Go. Take the flares. It is afraid of fire."}],
		"reward": {"flare": 6, "coin": 60}, "rep": {"village": 10}},
	"main_5": {"title": "The White One", "type": "Story", "giver": "aurel", "main": true, "card": "part_", "next": "main_6",
		"offer": "The thing from the lake has to be stopped before the aurora calls anyone else out onto the ice. When it falls, what is left of Core 31 will be in your hands — and somebody has to decide what happens to it.",
		"steps": [{"kind": "kill", "ids": ["boss_beast"], "text": "Face the White One far out on the lake ice (in summer the fishers' plank pier near Eisgrund runs out to its floe)"},
			{"kind": "choice", "item": "core_heart", "text": "Take the heart of Core 31 to Father Aurel, Tove or Pavel",
				"have_text": "You hold the heart of Core 31. Give it to Father Aurel (destroy it), Tove (return it to the lake) or sell it to Pavel",
				"options": {
					"aurel": {"label": "Let Father Aurel destroy the heart", "say": "Into the chapel stove, and the iron door shut. ...Listen. The ice has stopped singing.",
						"reward": {"coin": 50}, "rep": {"village": 20}, "outcome": "destroyed"},
					"tove": {"label": "Give the heart back to the lake with Tove", "say": "We will sink it through the deep hole, where it came from. The lake kept it for ten thousand years. It can keep it again.",
						"reward": {"coin": 50}, "rep": {"eisgrund": 20}, "outcome": "returned"},
					"pavel": {"label": "Sell the heart to Pavel (1500 Kronen)", "say": "One thousand five hundred, and I never saw you. There are men outside the valley who will pay ten times that.",
						"reward": {"coin": 1500}, "rep": {"village": -20, "eisgrund": -20}, "outcome": "sold"},
				}}],
		"reward": {}, "rep": {}},
	# ---------------------------------------------------------------- part two: the Vorland
	# The lake is quiet, but the valley is still shut. Beyond the tunnel lies a second valley
	# with a town that was told the Senke was dead, a deserter in a sawmill, and one helicopter.
	"main_6": {"title": "The Way Out", "type": "Story", "giver": "mirja", "main": true, "next": "main_7",
		"offer": "Mirja brought Arvid's last blasting charge up from the mine. The roof fall in the Polaris tunnel is fourteen metres of rubble, not the mountain the army said it was. Set the charge against it, stand well back, and walk out of the south portal.",
		"start_items": {"blasting_charge": 1},
		"steps": [{"kind": "places", "ids": ["gorge"], "text": "Blast the roof fall in the Polaris tunnel and leave by the south portal"},
			{"kind": "places", "ids": ["cordon"], "text": "Follow the gorge road down to the army cordon"},
			{"kind": "read", "ids": ["n_cordon_order"], "text": "Find out in the guard hut why nobody came for you"}],
		"reward": {"coin": 100, "medkit": 1}, "rep": {"village": 10}},
	"main_7": {"title": "Grauwasser", "type": "Story", "giver": "mirja", "main": true, "next": "main_8",
		"offer": "The cordon order says the Senke was written off: no survivors, no rescue. But the road goes on, and there are lights in the valley below. A town called Grauwasser.",
		"steps": [{"kind": "places", "ids": ["grauwasser"], "text": "Take the road south to the town of Grauwasser"},
			{"kind": "talk", "npc": "edda", "text": "Find the doctor in the Hotel Grauwasser",
				"say": "From Polaris? Alive? They told us the valley was a grave. Listen — I have thirty in the ward and the generator runs on fumes. A deserter, Hauptmann Reiss, holds the sawmill east of here and every litre of fuel in the Vorland. As long as he sits there, nobody leaves, and nobody gets better."},
			{"kind": "kill", "ids": ["boss_reiss"], "text": "Defeat Hauptmann Reiss at the Sägewerk Halden"},
			{"kind": "talk", "npc": "ragnar", "text": "Tell mayor Ragnar Halden the sawmill is free",
				"say": "My family's mill, and I thought I would never see it again. Then hear the rest. The radio mast is dead — one relay fuse. The army kept spares in the field hospital by the forest. Nobody who went there came back to tell us why it was abandoned in a single night."}],
		"reward": {"coin": 180, "fuel_can": 1}, "rep": {"grauwasser": 15}},
	"main_8": {"title": "The Dead Line", "type": "Story", "giver": "ragnar", "main": true, "next": "main_9",
		"offer": "The Hochfunk mast on the west ridge could reach the coast, if Lars had a relay fuse and fuel for the set. The fuse is in the abandoned army camp south-east of town.",
		"steps": [{"kind": "read", "ids": ["n_camp_triage"], "text": "Search the abandoned field hospital and read the triage notes"},
			{"kind": "give", "npc": "lars", "items": {"relay_fuse": 1, "fuel_can": 1}, "text": "Bring Lars at the Hochfunk mast the relay fuse and a can of fuel",
				"say": "Fuse in. Fuel in. ...Coast, this is Grauwasser, 3186, do you read. ...They read. They READ! No convoy before the thaw, they say — but if we have an aircraft, the pass is clear for one flight. One. Go and see Jorun at the airfield."},
			{"kind": "talk", "npc": "brandt", "text": "Ask Jorun Brandt at the airfield what the helicopter needs",
				"say": "One flight, they said? Then she needs a rotor hub and two cans. The spare hub left here on a supply sled two winters ago. They found the sled in the Steinbruch, in the old wolf den. The Grey Mother dens there. She is the size of a pony and she has never run from anything."}],
		"reward": {"coin": 150, "338": 12}, "rep": {"grauwasser": 15}},
	"main_9": {"title": "The Grey Mother", "type": "Story", "giver": "brandt", "main": true, "next": "main_10",
		"offer": "The rotor hub lies in the wolf den of the Steinbruch, south-east of the valley. The pack there follows one old she-wolf, white with frost.",
		"steps": [{"kind": "places", "ids": ["quarry"], "text": "Go to the Steinbruch, the old quarry in the south-east"},
			{"kind": "kill", "ids": ["boss_mother"], "text": "Kill the Grey Mother and take the rotor hub from her den"},
			{"kind": "give", "npc": "brandt", "items": {"rotor_hub": 1, "fuel_can": 2}, "text": "Bring Jorun Brandt the rotor hub and 2 cans of fuel",
				"say": "Give me an hour. ...There. She turns. Six seats, one flight, and the pass closes behind it. Here is the manifest — it is blank. I fly, but I will not be the one who writes the names. You opened the tunnel. You write them."}],
		"reward": {"flight_manifest": 1, "coin": 120}, "rep": {"grauwasser": 15}},
	"main_10": {"title": "Last Flight", "type": "Story", "giver": "brandt", "main": true, "ending": true,
		"offer": "One helicopter, six seats, one flight before the pass closes until the thaw. The blank manifest is in your pack.",
		"steps": [{"kind": "choice", "item": "flight_manifest", "text": "Decide who flies: give the manifest to Jorun Brandt, Dr. Edda Brandt or Ragnar Halden",
			"have_text": "You hold the blank manifest. Give it to Jorun (fly out with Mirja), Dr. Brandt (the sick fly) or Ragnar (keep the helicopter for the valleys)",
			"options": {
				"brandt": {"label": "Fly out with Mirja on the last flight", "say": "Two names. Yours and hers. Nobody here will blame you. Nobody here will forget it either. Strap in.",
					"reward": {"coin": 100}, "rep": {"grauwasser": -15, "village": -10}, "outcome": "flown"},
				"edda": {"label": "Give the six seats to the ward", "say": "The six worst. I know exactly who. You are staying, then? Good. I need somebody who can walk.",
					"reward": {"medkit": 3, "coin": 100}, "rep": {"grauwasser": 30, "village": 10}, "outcome": "ward"},
				"ragnar": {"label": "Keep the helicopter here as a lifeline for both valleys", "say": "No last flight. A hundred short ones, tunnel to town, town to mast, all winter. It is the harder way. It is the right one for a mayor to take.",
					"reward": {"coin": 300}, "rep": {"grauwasser": 20, "village": 20, "eisgrund": 20}, "outcome": "line"},
			}}],
		"reward": {}, "rep": {}},
	# ---------------------------------------------------------------- the horror story
	# Same valley, same bus, but the village is dark and empty. Everyone has hidden from the
	# Hollow, and each chapter is a puzzle that brings somebody back out.
	"h_1": {"title": "Nobody Home", "type": "Story", "giver": "henrik", "main": true, "mode": "horror", "next": "h_2",
		"offer": "The bus came back to Polaris. The lights did not. The market is empty, the doors are shut, and the carol on the loudspeakers is running slow.",
		"steps": [{"kind": "read", "ids": ["h_note_square"], "text": "Find out where everyone went (the big tree in the square)"}],
		"reward": {"flare": 2}, "rep": {}},
	"h_2": {"title": "The Fuse Box", "type": "Story", "giver": "henrik", "main": true, "mode": "horror", "next": "h_3",
		"offer": "If the lights come back on, the people can come out. The fuse box is behind the hotel; the fuses were taken to the station, the chapel and the west street.",
		"steps": [{"kind": "flag", "id": "power", "text": "Find three fuses and repair the fuse box behind the hotel"},
			{"kind": "talk", "npc": "henrik", "text": "Find Old Henrik in the hotel",
				"say": "You fixed the lights. God bless you. It came to the window every night, and I had nothing but the stove. Lena is still locked in her shop — she left a note here before she ran. Read it."}],
		"reward": {"coin": 40, "batteries": 2}, "rep": {"village": 10}},
	"h_3": {"title": "The Toymaker's Code", "type": "Story", "giver": "henrik", "main": true, "mode": "horror", "next": "h_4",
		"offer": "Lena locked herself in the back room of the toy shop behind a number lock. She painted the numbers somewhere she would see them every day.",
		"steps": [{"kind": "read", "ids": ["h_note_toys"], "text": "Read Lena's note in the hotel lobby"},
			{"kind": "flag", "id": "code", "text": "Find the four numbers by the loudspeakers and open the toy shop lock"},
			{"kind": "talk", "npc": "lena", "text": "Talk to Lena in her shop",
				"say": "You came. It stood outside the window, every night, not moving. Only when I blinked. Father Aurel is in the chapel — he said something about the bell and the children's music boxes. He was not making sense."}],
		"reward": {"flare": 3, "coin": 30}, "rep": {"village": 10}},
	"h_4": {"title": "Three Music Boxes", "type": "Story", "giver": "lena", "main": true, "mode": "horror", "next": "h_5",
		"offer": "Father Aurel has barred the chapel and will not come out until the right music plays.",
		"steps": [{"kind": "read", "ids": ["h_note_boxes"], "text": "Read the note on the chapel"},
			{"kind": "flag", "id": "boxes", "text": "Wind the three music boxes in the street in the right order"},
			{"kind": "talk", "npc": "aurel", "text": "Speak to Father Aurel in the chapel",
				"say": "The bell. You rang it. It cannot bear the bell, nor the light. Listen — do you hear it? Out in the forest, towards the lake. A child crying. Annika ran from Eisgrund when it came. Find her before it does."}],
		"reward": {"medkit": 1, "coin": 40}, "rep": {"village": 15}},
	"h_5": {"title": "Someone Is Crying", "type": "Story", "giver": "aurel", "main": true, "mode": "horror", "next": "h_6",
		"offer": "A child is crying somewhere in the forest towards the lake. Follow the sound.",
		"steps": [{"kind": "talk", "npc": "annika", "hidden": true, "text": "Follow the crying into the forest",
			"say": "Don't — oh. You are real. It stood at the door for so long. Grandmother Tove told us to light the three fires if it ever came, and nobody did. The fire baskets are still in Eisgrund. Please."}],
		"reward": {"firewood": 1}, "rep": {"eisgrund": 15}},
	"h_6": {"title": "Three Fires", "type": "Story", "giver": "annika", "main": true, "mode": "horror", "next": "h_7",
		"offer": "Tove in Eisgrund said: if it ever comes, light the three fires. Nobody did.",
		"steps": [{"kind": "flag", "id": "fires", "text": "Light the three fire baskets in Eisgrund with firewood"},
			{"kind": "talk", "npc": "tove", "text": "Talk to Tove in her cabin",
				"say": "Fire. Finally. The tall ones come from the White One, child — out on the lake, where the lights are. Kill it, and the fog goes with it. Mirja? She walked out onto the ice with her red scarf. I am sorry."}],
		"reward": {"flare": 6, "coin": 60}, "rep": {"eisgrund": 20}},
	"h_7": {"title": "The White One", "type": "Story", "giver": "tove", "main": true, "mode": "horror", "card": "h_part", "next": "h_8",
		"offer": "Everything that walks in the fog came from the thing on the lake. End it.",
		"steps": [{"kind": "kill", "ids": ["boss_beast"], "text": "Face the White One far out on the lake ice"}],
		"reward": {"coin": 100}, "rep": {"village": 20, "eisgrund": 20}},
	"h_8": {"title": "The Siren", "type": "Story", "giver": "tove", "main": true, "mode": "horror", "next": "h_9",
		"offer": "The White One is dead and the fog did not lift. It only moved. It poured through the tunnel into the next valley, and Mirja's hand is still cold. There is a blasting charge in your pack that was not there before.",
		"start_items": {"blasting_charge": 1},
		"steps": [{"kind": "places", "ids": ["cordon"], "text": "Blast the roof fall in the Polaris tunnel and follow the fog south to the cordon"},
			{"kind": "read", "ids": ["h_note_south"], "text": "Read what is nailed up at the army cordon"},
			{"kind": "places", "ids": ["grauwasser"], "text": "Go down into Grauwasser"},
			{"kind": "flag", "id": "siren", "text": "Pour 3 cans of fuel into the generator hut north of the square and start the siren"},
			{"kind": "talk", "npc": "ragnar", "text": "Find the mayor in the Gasthaus",
				"say": "The siren. Two winters it stood silent. They hate it — did you see them fold up? Lars went up to the mast to call the coast and never came down. He left a note on the door. The set has a number lock; he was afraid of what might use it."}],
		"reward": {"flare": 4, "coin": 60}, "rep": {"grauwasser": 15}},
	"h_9": {"title": "Dead Air", "type": "Story", "giver": "ragnar", "main": true, "mode": "horror", "next": "h_10",
		"offer": "The Hochfunk mast stands on the west ridge. Something has been answering on its frequency every night.",
		"steps": [{"kind": "read", "ids": ["h_note_mast"], "text": "Climb to the Hochfunk mast and read the note on the hut"},
			{"kind": "flag", "id": "radio", "text": "Find the frequency in the station log and key it into the radio set"},
			{"kind": "talk", "npc": "lars", "text": "Talk to Lars",
				"say": "You heard it too. It answered in my mother's voice. It said: come to the mill, it is warm at the mill. That is where they go when the siren drives them off. They hang in the rafters like coats. Four oil drums round the yard. Burn it."}],
		"reward": {"flare": 4, "firewood": 4}, "rep": {"grauwasser": 15}},
	"h_10": {"title": "The Nest", "type": "Story", "giver": "lars", "main": true, "mode": "horror", "ending": true, "end_as": "horror",
		"offer": "The Hollow nest in the Sägewerk Halden, east of town. Four oil drums stand round the yard. Each one needs firewood and a steady hand.",
		"steps": [{"kind": "read", "ids": ["h_note_mill"], "text": "Go to the sawmill and read what is nailed to the gate"},
			{"kind": "flag", "id": "nest", "text": "Light the four oil drums round the sawmill with firewood"}],
		"reward": {"coin": 200}, "rep": {"grauwasser": 30}},
	# ---------------------------------------------------------------- side jobs
	"parcel": {"title": "A Parcel for Eisgrund", "type": "Delivery", "giver": "marta",
		"offer": "Tove in Eisgrund has had nothing from us since the road closed. Would you carry a parcel down to the lake for me?",
		"start_items": {"parcel": 1},
		"steps": [{"kind": "give", "npc": "tove", "items": {"parcel": 1}, "text": "Bring Marta's parcel to Tove in Eisgrund",
			"say": "From Marta? Jam, wool, and a letter. So they have not forgotten us after all."}],
		"reward": {"coin": 60, "hot_tea": 2}, "rep": {"village": 8, "eisgrund": 12}},
	"station": {"title": "Otto's Station", "type": "Clear out", "giver": "otto",
		"offer": "Three of them sleep in my cable-car station. A pistol, a shotgun, and one with a long rifle on the roof side. Drive them out and the locker room is yours.",
		"steps": [{"kind": "kill", "ids": ["raider_1", "raider_2", "raider_7"], "text": "Clear the raiders out of the cable-car station"},
			{"kind": "talk", "npc": "otto", "text": "Tell Otto the station is free", "say": "Gone? All three? Thirty years I oiled that motor. Maybe I will again."}],
		"reward": {"coin": 140, "556": 40}, "rep": {"village": 15, "raiders": -10}},
	"parts": {"title": "A New Heart for the Pickup", "type": "Collect", "giver": "jonas",
		"offer": "I can get the old carrier winch working, but I need metal and current. Six scrap and two batteries, and I'll make it worth your while.",
		"steps": [{"kind": "give", "npc": "jonas", "items": {"scrap": 6, "batteries": 2}, "text": "Bring Jonas 6 scrap metal and 2 batteries",
			"say": "That will do nicely. Here — bolt this tank on, you'll get twice as far."}],
		"reward": {"aux_tank": 1, "coin": 40}, "rep": {"village": 8}},
	"survey": {"title": "Eyes on the Senke", "type": "Explore", "giver": "mikkel",
		"offer": "Nobody here has been past the lake since autumn. Go and look for us: the lookout tower, the Eisklamm bridge and the road tunnel. Tell me what still stands.",
		"steps": [{"kind": "places", "ids": ["tower", "bridge", "tunnel"], "text": "Find the Seeblick tower, the Eisklamm bridge and the Polaris tunnel"},
			{"kind": "talk", "npc": "mikkel", "text": "Report to Mikkel in Eisgrund", "say": "Bridge down, tunnel shut. So it is the ice road or nothing. Take these, you have earned a way through fences."}],
		"reward": {"bolt_cutters": 1, "coin": 80}, "rep": {"eisgrund": 12}},
	"truth": {"title": "What Happened at Polaris-7", "type": "Investigate", "giver": "aurel",
		"offer": "People come to me with half a story each. The station, the mine, the soldiers. Read what was written down — five papers would be a beginning — and tell me the truth of it.",
		"steps": [{"kind": "notes", "n": 5, "text": "Read 5 documents about what happened in the valley"},
			{"kind": "talk", "npc": "aurel", "text": "Tell Father Aurel what you found", "say": "So they knew, and they locked the doors. I will pray for them anyway. Take this; you will need it sooner than I."}],
		"reward": {"medkit": 2, "coin": 50}, "rep": {"village": 10}},
	"wolves": {"title": "The Pack in the South Wood", "type": "Hunt", "giver": "annika",
		"offer": "Three wolves come to the drying racks every night now. They sleep in the wood south-east of here. I can not leave the fish. Will you?",
		"steps": [{"kind": "kill", "ids": ["wolf_b_0", "wolf_b_1", "wolf_b_2"], "text": "Kill the three wolves in the wood south-east of Eisgrund"},
			{"kind": "talk", "npc": "annika", "text": "Tell Annika the pack is gone", "say": "All three? Grandmother will say you are half wolf yourself. This was my father's."}],
		"reward": {"fur_hood": 1, "coin": 70}, "rep": {"eisgrund": 14}},
	"pelts": {"title": "Pelts for the Ward", "type": "Collect", "giver": "sigrid",
		"offer": "The ward has thirty beds and nine blankets. Bring me five wolf pelts and I will have them sewn by morning.",
		"steps": [{"kind": "give", "npc": "sigrid", "items": {"wolf_pelt": 5}, "text": "Bring Sigrid 5 wolf pelts",
			"say": "Clean cuts, too. The doctor will know who to thank. Take this — it was my brother's, and he hunts no more."}],
		"reward": {"marksman_rifle": 1, "762": 20, "coin": 90}, "rep": {"grauwasser": 12}},
	"letter": {"title": "A Letter for the Einödhof", "type": "Delivery", "giver": "edda",
		"offer": "One of my patients died in the autumn with a letter in his coat. It is addressed to Oda at the Einödhof, the red barn south-west of town. She still thinks he is coming home.",
		"start_items": {"dead_letter": 1},
		"steps": [{"kind": "give", "npc": "oda", "items": {"dead_letter": 1}, "text": "Carry the letter to Oda at the Einödhof",
			"say": "His hand. ...Thank you for walking all this way to break an old woman's heart. No — I mean it. Thank you. Not knowing was worse."}],
		"reward": {"coin": 60, "canned_food": 3}, "rep": {"grauwasser": 12}},
	"flags": {"title": "Red Flags on the Road", "type": "Clear out", "giver": "ragnar",
		"offer": "Reiss's men keep two camps on our roads, one by the junction wood and one south of the mill. As long as their flags fly, no cart leaves town.",
		"steps": [{"kind": "kill", "ids": ["southcamp_0_0", "southcamp_0_1", "southcamp_0_2", "southcamp_0_3", "southcamp_1_0", "southcamp_1_1", "southcamp_1_2", "southcamp_1_3", "southcamp_1_4"], "text": "Clear both Red Flag camps in the Vorland"},
			{"kind": "talk", "npc": "ragnar", "text": "Tell Ragnar the roads are open", "say": "Both? Then the carts roll tomorrow. The town pays its debts."}],
		"reward": {"coin": 200, "762": 30}, "rep": {"grauwasser": 18, "raiders": -10}},
	"vorland": {"title": "The Whole Vorland", "type": "Explore", "giver": "lars",
		"offer": "My map ends where the army drew a line. Walk it for me: the airfield, the quarry, the field hospital and the Einödhof. Tell me what is still standing.",
		"steps": [{"kind": "places", "ids": ["strip", "quarry", "camp", "farm"], "text": "Find the airfield, the Steinbruch, the field hospital and the Einödhof"},
			{"kind": "talk", "npc": "lars", "text": "Report to Lars at the Hochfunk mast", "say": "Four more pins in the map. With the mast and a map, we are a country again."}],
		"reward": {"scope": 1, "coin": 90}, "rep": {"grauwasser": 12}},
	"ash": {"title": "What the Ash Is", "type": "Investigate", "giver": "edda",
		"offer": "The army notes speak of a grey ash in the lungs of the men who came back from the Senke cordon. If you find three more papers down here, I may understand what I am treating.",
		"steps": [{"kind": "read", "ids": ["n_gw_notice", "n_mill_ledger", "n_quarry_den"], "text": "Read the town notice, the sawmill ledger and the note in the quarry den"},
			{"kind": "talk", "npc": "edda", "text": "Bring Dr. Brandt what you read", "say": "So it came out of the lake with the meltwater, long before the tunnel fell. Then it is in all of us, a little. Well. Then we treat all of us."}],
		"reward": {"medkit": 2, "painkillers": 2}, "rep": {"grauwasser": 12}},
	"crate": {"title": "The Antibiotics", "type": "Choice", "giver": "ilse",
		"offer": "The army left a crate of antibiotics in shelter B-5, out in the south meadows — a crowbar gets you in. One crate. The village has sick children, Eisgrund has frostbite gone bad, and Pavel would pay a fortune. Bring it back and decide who gets it. I know what I would do.",
		"place_item": ["bunker2", "medicine_crate"],
		"steps": [{"kind": "choice", "item": "medicine_crate", "text": "Fetch the antibiotics from shelter B-5, then give them to Father Aurel, to Tove, or sell them to Pavel",
			"have_text": "You have the antibiotics. Give them to Father Aurel, to Tove, or sell them to Pavel",
			"options": {
				"aurel": {"label": "Give the antibiotics to the village", "say": "For the children. You could have sold this. I will see that everyone knows who brought it.",
					"reward": {"coin": 30}, "rep": {"village": 25, "eisgrund": -8}, "outcome": "village"},
				"tove": {"label": "Give the antibiotics to Eisgrund", "say": "Three of ours would have lost their feet. The village will not thank you. We will.",
					"reward": {"rope": 1, "338": 10}, "rep": {"eisgrund": 25, "village": -8}, "outcome": "eisgrund"},
				"pavel": {"label": "Sell the antibiotics to Pavel (400 Kronen)", "say": "Now that is business. Don't tell the priest where I got it.",
					"reward": {"coin": 400}, "rep": {"village": -15, "eisgrund": -10}, "outcome": "sold"},
			}}],
		"reward": {}, "rep": {}},
}

var main: Node
var state := {}       # id -> {"s": "active" / "done", "step": int, "outcome": String}
var _t := 0.0


func status(id: String) -> String:
	return str((state.get(id, {}) as Dictionary).get("s", "none"))


func outcome(id: String) -> String:
	return str((state.get(id, {}) as Dictionary).get("outcome", ""))


func _step(id: String) -> Dictionary:
	var q: Dictionary = DEFS[id]
	var i := int((state[id] as Dictionary).get("step", 0))
	var steps: Array = q["steps"]
	return steps[i] if i < steps.size() else {}


func active() -> Array:
	var out := []
	for id in DEFS:
		if status(id) == "active":
			out.append(id)
	return out


## Whether a quest belongs to the game being played (story chapters belong to one mode).
static func in_mode(id: String) -> bool:
	var q: Dictionary = DEFS[id]
	if GameMode.horror():
		# the horror night is only the horror story: no deliveries, hunts or odd jobs
		return q.get("main", false) and str(q.get("mode", "normal")) == "horror"
	return not q.get("main", false) or str(q.get("mode", "normal")) == GameMode.mode


static func first_chapter() -> String:
	return "h_1" if GameMode.horror() else "main_1"


func done_count() -> int:
	var n := 0
	for id in DEFS:
		if status(id) == "done":
			n += 1
	return n


func mode_count() -> int:
	var n := 0
	for id in DEFS:
		if in_mode(id):
			n += 1
	return n


## What the current step asks for, with progress where there is some.
func objective(id: String) -> String:
	if status(id) != "active":
		return ""
	var st := _step(id)
	var text := str(st.get("text", ""))
	match str(st.get("kind", "")):
		"kill":
			var ids: Array = st["ids"]
			text += "  (%d/%d)" % [_dead(ids), ids.size()]
		"places":
			var ids: Array = st["ids"]
			if ids.size() > 1:
				text += "  (%d/%d)" % [_found(ids), ids.size()]
		"notes":
			text += "  (%d/%d)" % [mini(main.reader.found.size(), int(st["n"])), int(st["n"])]
		"read":
			var ids: Array = st["ids"]
			if ids.size() > 1:
				text += "  (%d/%d)" % [_read(ids), ids.size()]
		"choice":
			if main.player.inv.count(str(st["item"])) > 0:
				text = str(st.get("have_text", text))
		"flag":
			if main.get("horror"):
				text += main.horror.progress(str(st["id"]))
	return text


## The quest the HUD shows: the one taken most recently.
func tracked() -> Array:
	var a := active()
	if a.is_empty():
		return []
	var id: String = a[a.size() - 1]
	var best := -1
	for q in a:
		var o := int((state[q] as Dictionary).get("order", 0))
		if o > best:
			best = o
			id = q
	return [str(DEFS[id]["title"]), objective(id)]


func _dead(ids: Array) -> int:
	var n := 0
	for i in ids:
		if str(i) in main.enemies.dead:
			n += 1
	return n


func _read(ids: Array) -> int:
	var n := 0
	for i in ids:
		if str(i) in main.reader.found:
			n += 1
	return n


## The story chapter that is running now, or "" before it starts / after the end.
func main_quest() -> String:
	for id in active():
		if DEFS[id].get("main", false):
			return id
	return ""


## Where the current step of a quest wants you to go, or Vector3.INF if nowhere in particular.
func target(id: String) -> Vector3:
	if status(id) != "active":
		return Vector3.INF
	var st := _step(id)
	if st.get("hidden", false):
		return Vector3.INF
	match str(st.get("kind", "")):
		"flag":
			if main.get("horror"):
				return main.horror.target_of(str(st["id"]))
		"places":
			for s in main.places.spots:
				if not str(s["id"]) in main.places.found and str(s["id"]) in st["ids"]:
					return s["pos"]
		"kill":
			for e in main.bosses.get_children():
				if e is Enemy and str(e.get("id")) in st["ids"] and not str(e.get("id")) in main.enemies.dead:
					return (e as Node3D).global_position
			for e in main.enemies.get_children():
				if e is Enemy and str(e.get("id")) in st["ids"] and not str(e.get("id")) in main.enemies.dead:
					return (e as Node3D).global_position
		"read":
			for n in get_tree().get_nodes_in_group("note"):
				if str(n.get("id")) in st["ids"] and not str(n.get("id")) in main.reader.found:
					return (n as Node3D).global_position
		"talk", "give":
			for n in main.people.list:
				if n.id == str(st["npc"]):
					return n.global_position
		"choice":
			if main.player.inv.count(str(st["item"])) > 0:
				return Vector3.INF
	return Vector3.INF


func _found(ids: Array) -> int:
	var n := 0
	for i in ids:
		if str(i) in main.places.found:
			n += 1
	return n


## What this person can do for your quests right now: rows of [label, action].
func options(npc: String) -> Array:
	var out := []
	var inv: Inventory = main.player.inv
	for id in DEFS:
		var q: Dictionary = DEFS[id]
		match status(id):
			"none":
				if str(q["giver"]) == npc and not q.get("main", false):
					out.append(["%s:  %s" % [str(q["type"]).to_upper(), q["title"]], "offer:" + id])
			"active":
				var st := _step(id)
				match str(st.get("kind", "")):
					"give":
						if str(st["npc"]) == npc:
							out.append(["Hand over: " + _list(st["items"]) + ("" if _has(inv, st["items"]) else "  (you lack some)"), "give:" + id])
					"talk":
						if str(st["npc"]) == npc:
							out.append([str(st["text"]), "talk:" + id])
					"choice":
						var opts: Dictionary = st["options"]
						if opts.has(npc) and inv.count(str(st["item"])) > 0:
							out.append([str(opts[npc]["label"]), "choose:" + id])
	return out


func _has(inv: Inventory, items: Dictionary) -> bool:
	for i in items:
		if inv.count(str(i)) < int(items[i]):
			return false
	return true


func _list(items: Dictionary) -> String:
	var parts: Array[String] = []
	for i in items:
		parts.append("%d × %s" % [int(items[i]), Items.name_of(str(i))] if int(items[i]) > 1 else Items.name_of(str(i)))
	return ", ".join(parts)


## The offer text for a quest (shown before you accept).
func offer_text(id: String) -> String:
	return str(DEFS[id]["offer"])


func accept(id: String) -> void:
	if status(id) != "none":
		return
	var q: Dictionary = DEFS[id]
	state[id] = {"s": "active", "step": 0, "outcome": "", "order": state.size()}
	for i in q.get("start_items", {}):
		main.player.inv.add(str(i), int(q["start_items"][i]))
	if q.has("place_item"):
		var pi: Array = q["place_item"]
		for n in get_tree().get_nodes_in_group("loot"):
			var box: LootBox = n
			if box.id == str(pi[0]):
				box.items[str(pi[1])] = 1
	main.hud.banner("NEW JOB  ·  " + str(q["type"]).to_upper(), str(q["title"]))
	_check(id)
	updated.emit()


## Runs an option from options(). Returns what the person says.
func act(action: String, npc: String) -> String:
	var parts := action.split(":")
	var id := parts[1]
	var inv: Inventory = main.player.inv
	match parts[0]:
		"offer":
			accept(id)
			return "Good. I will be here."
		"give":
			var st := _step(id)
			if not _has(inv, st["items"]):
				return "That is not all of it. I need " + _list(st["items"]) + "."
			for i in st["items"]:
				inv.remove(str(i), int(st["items"][i]))
			_advance(id)
			return str(st.get("say", "Thank you."))
		"talk":
			var st := _step(id)
			_advance(id)
			return str(st.get("say", "Good."))
		"choose":
			var st := _step(id)
			var o: Dictionary = st["options"][npc]
			inv.remove(str(st["item"]), 1)
			(state[id] as Dictionary)["outcome"] = str(o["outcome"])
			_pay(o.get("reward", {}), o.get("rep", {}))
			_advance(id)
			return str(o["say"])
	return ""


func _advance(id: String) -> void:
	var q: Dictionary = DEFS[id]
	var s: Dictionary = state[id]
	s["step"] = int(s["step"]) + 1
	if int(s["step"]) >= (q["steps"] as Array).size():
		s["s"] = "done"
		_pay(q.get("reward", {}), q.get("rep", {}))
		main.hud.banner("CHAPTER DONE" if q.get("main", false) else "JOB DONE", str(q["title"]))
		if q.has("next"):
			accept(str(q["next"]))
		if q.has("card") and main.get("story"):
			var key := str(q["card"])
			main.story.show_card(key + str(s.get("outcome", "")) if key.ends_with("_") else key)
		if q.get("ending", false) and main.get("story"):
			main.story.show_ending(str(q.get("end_as", s.get("outcome", ""))))
		if q.get("main", false) and not GameMode.creator():
			(func() -> void: SaveGame.autosave(main)).call_deferred()
	else:
		_check(id)
	updated.emit()


func _pay(reward: Dictionary, reps: Dictionary) -> void:
	var names: Array[String] = []
	for i in reward:
		main.player.inv.add(str(i), int(reward[i]))
		names.append("%d %s" % [int(reward[i]), Items.name_of(str(i))])
	if not names.is_empty():
		main.player.message.emit("Received: " + ", ".join(names))
	for f in reps:
		main.factions.add(str(f), int(reps[f]))


## Steps that finish by themselves (kills, places, documents).
func _check(id: String) -> void:
	if status(id) != "active":
		return
	var st := _step(id)
	var ok := false
	match str(st.get("kind", "")):
		"kill":
			ok = _dead(st["ids"]) >= (st["ids"] as Array).size()
		"places":
			ok = _found(st["ids"]) >= (st["ids"] as Array).size()
		"notes":
			ok = main.reader.found.size() >= int(st["n"])
		"read":
			ok = _read(st["ids"]) >= (st["ids"] as Array).size()
		"flag":
			ok = main.get("horror") != null and bool(main.horror.flags.get(str(st["id"]), false))
	if ok:
		main.player.message.emit("Done: " + str(st["text"]))
		_advance(id)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or main == null:
		return
	_t = 1.0
	for id in active():
		_check(id)
	_resume()
	if main.get("people"):
		main.people.update_story(self)
	if main.get("horror"):
		main.horror.update_story()


## An older save that ended where the story now goes on: start the next chapter.
func _resume() -> void:
	if main_quest() != "" or main.get("hud") == null:
		return
	for id in DEFS:
		var q: Dictionary = DEFS[id]
		if q.get("main", false) and in_mode(id) and status(id) == "done" and q.has("next") and status(str(q["next"])) == "none":
			accept(str(q["next"]))
			return


func to_dict() -> Dictionary:
	return state.duplicate(true)


func from_dict(d: Dictionary) -> void:
	state.clear()
	for id in d:
		if DEFS.has(str(id)):
			var s: Dictionary = d[id]
			state[str(id)] = {"s": str(s.get("s", "active")), "step": int(s.get("step", 0)), "outcome": str(s.get("outcome", "")), "order": int(s.get("order", 0))}
	updated.emit()
