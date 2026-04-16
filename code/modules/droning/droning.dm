//Used to manage sending droning sounds to various clients

/// If combat mode is re-enabled within this time, resume the same track at the saved offset (see snapshot_combat_music_for_resume).
#define CMODE_MUSIC_RESUME_WINDOW (2 MINUTES)

SUBSYSTEM_DEF(droning)
	name = "Droning"
	flags = SS_NO_INIT|SS_NO_FIRE

/datum/controller/subsystem/droning/proc/snapshot_combat_music_for_resume(client/C)
	if(!C?.mob || !isliving(C.mob) || !C.mob.cmode)
		return
	C.cmode_music_stopped_at = world.time
	var/sound/picked
	for(var/sound/S in C.SoundQuery())
		if(S.channel != CHANNEL_BUZZ)
			continue
		if(C.droning_sound && S.file == C.droning_sound.file)
			picked = S
			break
		if(!picked)
			picked = S
	if(picked)
		C.cmode_music_saved_file = picked.file
		if(isnum(picked.offset) && picked.offset >= 0)
			C.cmode_music_saved_offset = picked.offset
		else
			C.cmode_music_saved_offset = 0
	else if(C.droning_sound?.file)
		C.cmode_music_saved_file = C.droning_sound.file
		C.cmode_music_saved_offset = 0
	else
		C.cmode_music_saved_file = null
		C.cmode_music_saved_offset = 0

/datum/controller/subsystem/droning/proc/area_entered(area/area_entered, client/entering)
	if(!area_entered || !entering)
		return
/*
	if(HAS_TRAIT(entering.mob, TRAIT_LEAN) && !area_entered.droning_sound)
		//just kill the previous droning sound
		kill_droning(entering)
		return
	if(HAS_TRAIT(entering.mob, TRAIT_BLOODARN) && !area_entered.droning_sound)
		//just kill the previous droning sound
		kill_droning(entering)
		return
*/
	var/list/last_droning = list()
	last_droning |= entering.last_droning_sound
	var/list/new_droning = list()
	new_droning |= area_entered.droning_sound_current

	if(HAS_TRAIT(entering.mob, TRAIT_SCHIZO_AMBIENCE))
		new_droning = list('sound/music/dreamer_is_still_asleep.ogg')

	//Same ambience, don't bother
	if(last_droning ~= new_droning)
		return
	play_area_sound(area_entered, entering)

/datum/controller/subsystem/droning/proc/play_area_sound(area/area_player, client/listener)
	if(!area_player || !listener)
		return
	
	if(SSticker.current_state >= GAME_STATE_FINISHED) //stop drones in round end
		return

	if(area_player.we_droning_here)

		if(!area_player.droning_sound)
			return
		var/used_sound

		if(GLOB.tod == "dawn")
			if(area_player.droning_sound_dawn)
				used_sound = area_player.droning_sound_dawn
			else
				used_sound = area_player.droning_sound

		if(GLOB.tod == "day")
			if(area_player.droning_sound)
				used_sound = area_player.droning_sound
			else
				used_sound = null

		if(GLOB.tod == "dusk")
			if(area_player.droning_sound_dusk)
				used_sound = area_player.droning_sound_dusk
			else
				used_sound = area_player.droning_sound

		if(GLOB.tod == "night")
			if(area_player.droning_sound_night)
				used_sound = area_player.droning_sound_night
			else
				used_sound = area_player.droning_sound

		if(HAS_TRAIT(listener.mob, TRAIT_SCHIZO_AMBIENCE))
			used_sound = list('sound/music/dreamer_is_still_asleep.ogg')
		else if(HAS_TRAIT(listener.mob, TRAIT_DRUQK))
			used_sound = list('sound/music/spice.ogg', 100)
		//our music for real
		area_player.droning_sound_current = used_sound
		//last phase!
		if(listener?.mob.cmode)
			last_phase(area_player, listener, shouldskip = TRUE)
		else
			last_phase(area_player, listener, shouldskip = FALSE)

/datum/controller/subsystem/droning/proc/play_combat_music(music = null, client/dreamer)
	if(!music || !dreamer)
		return

	if(!dreamer?.prefs.musicvol)
		kill_droning(dreamer)
		return

	var/frenq = 1

	if(HAS_TRAIT(dreamer.mob, TRAIT_DRUQK))
		frenq = -1

	if(ishuman(dreamer.mob))
		var/mob/living/carbon/human/H = dreamer.mob
		if(H.has_status_effect(/datum/status_effect/buff/moondust))
			frenq = 2
		if(H.has_status_effect(/datum/status_effect/buff/weed))
			frenq = 0.5

	// Kill whatever BYOND-native audio was playing (area ambience etc.)
	kill_droning(dreamer)

	var/list/tracks = islist(music) ? music : list(music)
	var/chosen_file = pick(tracks)
	var/start_offset = 0
	if(dreamer.cmode_music_stopped_at && (world.time - dreamer.cmode_music_stopped_at <= CMODE_MUSIC_RESUME_WINDOW) \
			&& dreamer.cmode_music_saved_file && (dreamer.cmode_music_saved_file in tracks))
		chosen_file = dreamer.cmode_music_saved_file
		start_offset = max(0, dreamer.cmode_music_saved_offset)

	var/target_vol = dreamer.prefs.musicvol * 1.2

	// BYOND native playback (tgui play_music only accepts http(s) URLs).
	var/sound/combat_music = sound(chosen_file, repeat = TRUE, wait = 0, channel = CHANNEL_BUZZ, volume = target_vol)
	combat_music.frequency = frenq
	if(!HAS_TRAIT(dreamer.mob, TRAIT_DRUQK))
		combat_music.pitch = 1 / combat_music.frequency
	if(start_offset > 0)
		combat_music.offset = start_offset
	SEND_SOUND(dreamer, combat_music)
	dreamer.droning_sound = combat_music
	dreamer.last_droning_sound = combat_music.file

/datum/controller/subsystem/droning/proc/last_phase(area/area_player, client/listener, shouldskip = FALSE)
	if(!area_player || !listener)
		return
	if(!listener?.droning_sound)
		shouldskip = TRUE
	if(listener?.mob.cmode)
		shouldskip = TRUE
	if(shouldskip)
		var/sound/droning = sound(pick(area_player.droning_sound_current), area_player.droning_repeat, area_player.droning_wait, area_player.droning_channel, listener?.prefs.musicvol)


		if(HAS_TRAIT(listener.mob, TRAIT_SCHIZO_AMBIENCE))
			droning.file = 'sound/music/dreamer_is_still_asleep.ogg'
		else if(HAS_TRAIT(listener.mob, TRAIT_DRUQK))
			droning.file = 'sound/music/spice.ogg'

		listener.droning_sound = droning
		listener.last_droning_sound = area_player.droning_sound
		SEND_SOUND(listener, droning)
	else
		var/sound/sound_killer = sound()
		sound_killer.channel = listener.droning_sound.channel
		sound_killer.volume = listener.prefs.musicvol
		while(sound_killer.volume > 0)
			if(sound_killer.volume <= 0)
				break
			sound_killer.volume = max(sound_killer.volume - 5, 0)
			sound_killer.status = SOUND_UPDATE
			SEND_SOUND(listener, sound_killer)
			sleep(1)
		listener.droning_sound = null
		listener.last_droning_sound = null
		var/sound/droning = sound(pick(area_player.droning_sound_current), area_player.droning_repeat, area_player.droning_wait, area_player.droning_channel, listener?.prefs.musicvol)

		if(HAS_TRAIT(listener.mob, TRAIT_SCHIZO_AMBIENCE))
			droning.file = 'sound/music/dreamer_is_still_asleep.ogg'
		else if(HAS_TRAIT(listener.mob, TRAIT_DRUQK))
			droning.file = 'sound/music/spice.ogg'

		listener.droning_sound = droning
		listener.last_droning_sound = area_player.droning_sound_current
		SEND_SOUND(listener, droning)

/datum/controller/subsystem/droning/proc/kill_droning(client/victim)
	if(!victim?.droning_sound)
		return
	var/sound/sound_killer = sound('sound/blank.ogg')
	sound_killer.channel = victim.droning_sound.channel
	SEND_SOUND(victim, sound_killer)
	victim.droning_sound = null
	victim.last_droning_sound = null

/datum/controller/subsystem/droning/proc/play_loop(area/area_entered, client/dreamer)
	if(!area_entered || !dreamer)
		return
	//kill the previous looping
	kill_loop(dreamer)

	if(!dreamer?.prefs.musicvol)
		return

	var/amb_sound_list = null
	if(area_entered.we_looping_here)
		if(GLOB.tod == "night")
			if(area_entered.ambientnight)
				amb_sound_list = area_entered.ambientnight
		else
			if(area_entered.ambientsounds)
				amb_sound_list = area_entered.ambientsounds

	if(!amb_sound_list)
		return
	var/sound/loop_sound = sound(pick(amb_sound_list), repeat = TRUE, wait = 0, channel = CHANNEL_MUSIC, volume = dreamer?.prefs.musicvol)
	SEND_SOUND(dreamer, loop_sound)
	dreamer.loop_sound = TRUE

/datum/controller/subsystem/droning/proc/kill_loop(client/victim)
	if(!victim?.loop_sound)
		return
	victim?.mob.stop_sound_channel(CHANNEL_MUSIC)
	victim?.loop_sound = FALSE

/datum/controller/subsystem/droning/proc/kill_rain(client/victim)
	if(!victim?.rain_sound)
		return
	victim?.mob.stop_sound_channel(CHANNEL_RAIN)
	victim?.rain_sound = FALSE

/datum/controller/subsystem/droning/proc/play_rain(area/area_entered, client/dreamer)
	if(!area_entered || !dreamer)
		return
	kill_rain(dreamer)

	if(!dreamer?.prefs.musicvol)
		return

	var/amb_sound_list = null
	if(area_entered.ambientrain)
		amb_sound_list = area_entered.ambientrain

	if(!amb_sound_list)
		return
	var/sound/loop_sound = sound(pick(amb_sound_list), repeat = TRUE, wait = 0, channel = CHANNEL_RAIN, volume = dreamer?.prefs.musicvol)
	SEND_SOUND(dreamer, loop_sound)
	dreamer.rain_sound = TRUE
