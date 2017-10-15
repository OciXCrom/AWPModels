#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#define PLUGIN_VERSION "1.3.1"
#define MAX_SNIPERS 30
#define DEFAULT_V "models/v_awp.mdl"
#define DEFAULT_P "models/p_awp.mdl"

enum _:Info
{
	Name[32],
	VModel[128],
	PModel[128],
	Flag
}

new g_eSnipers[MAX_SNIPERS][Info]
new g_iSnipersNum
new g_iSniper[33]
new bool:g_bFirstTime[33]
new g_iSayText
new g_pAtSpawn

public plugin_init()
{
	register_plugin("AWP Models", PLUGIN_VERSION, "OciXCrom")
	register_cvar("CRXAWPModels", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	register_dictionary("AWPModels.txt")
	
	register_event("CurWeapon", "OnSelectAWP", "be", "1=1", "2=18")
	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", 1)
	
	register_clcmd("say /awp", "ShowMenu")
	register_clcmd("say_team /awp", "ShowMenu")
	
	g_pAtSpawn = register_cvar("am_open_at_spawn", "0")
	g_iSayText = get_user_msgid("SayText")
}

public plugin_precache()
	ReadFile()

ReadFile()
{
	new szConfigsName[256], szFilename[256]
	get_configsdir(szConfigsName, charsmax(szConfigsName))
	formatex(szFilename, charsmax(szFilename), "%s/AWPModels.ini", szConfigsName)
	new iFilePointer = fopen(szFilename, "rt")
	
	if(iFilePointer)
	{
		new szData[300], szFlag[2]
		
		while(!feof(iFilePointer))
		{
			fgets(iFilePointer, szData, charsmax(szData))
			trim(szData)
			
			switch(szData[0])
			{
				case EOS, ';': continue
				default:
				{
					parse(szData, g_eSnipers[g_iSnipersNum][Name], charsmax(g_eSnipers[][Name]),	g_eSnipers[g_iSnipersNum][VModel], charsmax(g_eSnipers[][VModel]),
					g_eSnipers[g_iSnipersNum][PModel], charsmax(g_eSnipers[][PModel]), szFlag, charsmax(szFlag))
					
					if(!is_blank(g_eSnipers[g_iSnipersNum][VModel]))
						precache_model(g_eSnipers[g_iSnipersNum][VModel])
						
					if(!is_blank(g_eSnipers[g_iSnipersNum][PModel]))
						precache_model(g_eSnipers[g_iSnipersNum][PModel])
						
					g_eSnipers[g_iSnipersNum][Flag] = is_blank(szFlag) ? ADMIN_ALL : read_flags(szFlag)
						
					szFlag[0] = EOS
					g_iSnipersNum++
				}
			}
		}
		
		fclose(iFilePointer)
	}
}

public ShowMenu(id)
{
	new szTitle[128]
	formatex(szTitle, charsmax(szTitle), "%L", id, "AM_MENU_TITLE")
	
	new iMenu = menu_create(szTitle, "MenuHandler")
	
	for(new iFlags = get_user_flags(id), i; i < g_iSnipersNum; i++)
	{
		if(g_eSnipers[i][Flag] == ADMIN_ALL || iFlags & g_eSnipers[i][Flag])
			menu_additem(iMenu, formatin("%s %s", g_eSnipers[i][Name], g_iSniper[id] == i ? formatin("%L", id, "AM_MENU_SELECTED") : formatin("")))
		else
			menu_additem(iMenu, formatin("%s %L", g_eSnipers[i][Name], id, "AM_MENU_VIP_ONLY"), .paccess = g_eSnipers[i][Flag])
	}
	
	if(menu_pages(iMenu) > 1)
		menu_setprop(iMenu, MPROP_TITLE, formatin("%s%L", szTitle, id, "AM_MENU_TITLE_PAGE"))
		
	menu_display(id, iMenu)
	return PLUGIN_HANDLED
}

public MenuHandler(id, iMenu, iItem)
{
	if(iItem != MENU_EXIT)
	{
		if(g_iSniper[id] == iItem)
			ColorChat(id, "%L", id, "AM_CHAT_ALREADY")
		else
		{
			g_iSniper[id] = iItem
			
			if(is_user_alive(id) && get_user_weapon(id) == CSW_AWP)
				OnSelectAWP(id)
			
			ColorChat(id, "%L", id, "AM_CHAT_SELECTED", g_eSnipers[iItem][Name])
		}
	}
	
	menu_destroy(iMenu)
	return PLUGIN_HANDLED
}

public client_putinserver(id)
{
	g_bFirstTime[id] = true
	g_iSniper[id] = 0
}

public OnPlayerSpawn(id)
{
	if(is_user_alive(id) && get_pcvar_num(g_pAtSpawn) && g_iSniper[id] == 0 && g_bFirstTime[id])
	{
		g_bFirstTime[id] = false
		ShowMenu(id)
	}
}

public OnSelectAWP(id)
{
	if(is_blank(g_eSnipers[g_iSniper[id]][VModel]))
		set_pev(id, pev_viewmodel2, DEFAULT_V)
	else set_pev(id, pev_viewmodel2, g_eSnipers[g_iSniper[id]][VModel])
	
	if(is_blank(g_eSnipers[g_iSniper[id]][PModel]))
		set_pev(id, pev_weaponmodel2, DEFAULT_P)
	else set_pev(id, pev_weaponmodel2, g_eSnipers[g_iSniper[id]][PModel])
}

bool:is_blank(szString[])
	return szString[0] == EOS
	
ColorChat(const id, const szInput[], any:...)
{
	new iPlayers[32], iCount = 1
	static szMessage[191]
	vformat(szMessage, charsmax(szMessage), szInput, 3)
	format(szMessage[0], charsmax(szMessage), "%L %s", id ? id : LANG_PLAYER, "AM_CHAT_PREFIX", szMessage)
	
	replace_all(szMessage, charsmax(szMessage), "!g", "^4")
	replace_all(szMessage, charsmax(szMessage), "!n", "^1")
	replace_all(szMessage, charsmax(szMessage), "!t", "^3")
	
	if(id)
		iPlayers[0] = id
	else
		get_players(iPlayers, iCount, "ch")
	
	for(new i; i < iCount; i++)
	{
		if(is_user_connected(iPlayers[i]))
		{
			message_begin(MSG_ONE_UNRELIABLE, g_iSayText, _, iPlayers[i])
			write_byte(iPlayers[i])
			write_string(szMessage)
			message_end()
		}
	}
}

#if !defined MAX_FMT_LENTH
	#define MAX_FMT_LENGTH 256
#endif

#if !defined __vformat_allower
	#define __vformat_allower __vformat_allower_
	
	__vformat_allower_()
	{
		vformat("", 0, "", 0)
	}
#endif

formatin(const format[], any:...)
{
	static formatted[MAX_FMT_LENGTH]
	#emit PUSH.C 0x2
	#emit PUSH.S format
	const FORMATTED_CHARSMAX = charsmax(formatted)
	#emit PUSH.C FORMATTED_CHARSMAX
	#emit LOAD.S.PRI 0x8 // Get size of arguments (count of arguments multiply by sizeof(cell))
	#emit ADDR.ALT 0xC // This is the pointer to first argument
	#emit ADD // Now in PRI we have the pointer to hidden return argument
	#emit LOAD.I // Now in PRI we have the pointer to return buffer
	#emit PUSH.PRI
	#emit PUSH.C 0x10
	#emit SYSREQ.C vformat
	#emit STACK 0x14
	#emit RETN // Don't execute the code for copy return generated by compiler
	__vformat_allower()
	return formatted
}