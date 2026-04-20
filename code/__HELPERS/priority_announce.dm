/proc/priority_announce(text, title = "", sound, type , mob/living/sender = null, mob/living/receiver = null)
	if(!text)
		return

	var/announcement = ""
	if (title && length(title) > 0)
		announcement += "<h1 class='alert'>[title]</h1>"
	announcement += "<br><span class='alert'>[STRIP_HTML_SIMPLE(text, MAX_MESSAGE_LEN)]</span>"

	if (sender)
		sender.log_talk(text, LOG_SAY, tag="priority announcement")
		message_admins("[ADMIN_LOOKUPFLW(sender)] has made a priority announcement.")

	var/s = sound ? sound(sound) : null
	var/n = 0
	for(var/mob/M as anything in GLOB.player_list)
		if(++n % 12 == 0)
			CHECK_TICK
		if (!M.can_hear())
			continue
		if (receiver && !(istype(M, receiver) || (sender && M == sender)))
			continue

		to_chat(M, announcement)
		if (M.client?.prefs.toggles & SOUND_ANNOUNCEMENTS)
			if (s)
				M.playsound_local(M, s, 100)

/proc/minor_announce(message, title = "", alert = TRUE)
	if(!message)
		return

	var/n = 0
	for(var/mob/M as anything in GLOB.player_list)
		if(++n % 12 == 0)
			CHECK_TICK
		if(M.can_hear())
			to_chat(M, "<span class='big bold'><span style='color: purple;'>[html_encode(title)]</span><BR>[html_encode(message)]</span><BR>")
			if(alert && (M.client?.prefs.toggles & SOUND_ANNOUNCEMENTS))
				M.playsound_local(M, 'sound/misc/alert.ogg', 100)
